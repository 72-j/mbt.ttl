// ===== 用户部分：基础类型 =====
// 复用 @nquads 的共享词表（Token/Lexermoon/ParseError/Span/TermType），
// 本包保留 N3 自身的类型面：方言开关 / PredKind / IRIUpcastEvent / QuadSpan /
// SlotType / Slot / ErrOut 外观 / Show（Step 4 表役自 n3.mbt 手稿收编至此，
// 生成面归 n3.mbt——与 gen_trig/types.mbt 同布局）。

///|
pub using @nquads {
  type Token,
  type Lexermoon,
  type ParseError,
  type Span,
  type TermType,
}

///|
/// 方言开关（生成契约不引用，引擎 loop 用）：N3 = 默认扩展；RDF-star 暂不开放。
/// 所有权：手写面持有（n3_domain.toml 里 emit = false，生成器只记账不发射——
/// 与 PredKind 的生成器发射成对照，两栖开关在表）。
pub(all) enum N3Dialect {
  N3
  RDFStarOff
} derive(Eq)

///|
/// 谓词来源标记（管线同源快照槽，随 quad 带出）。
/// N3 按 ADR-003a：集合语法 ( ... ) 展开为单一 BNode，无合成链——恒 Normal；
/// RDFFirst/RDFRest 变体仅为 ADR-003b 显式链物化预留。
/// 布局与 trig ★3 四快照槽同源（pk/pver/bver/iver）。
// pub(all) enum PredKind {
//   Normal
//   RDFFirst
//   RDFRest
// } derive(Eq)

///|
/// IRI 版本提升标记（ADR-003b 显式链专用）：文档显式书写 rdf:first/rdf:rest
///（全 IRI 字节或前缀名）时 action 上报 upcast，ctx.iri_upcast 账本 +1，
/// 避免全文地毯搜索；物化器按槽位版本回扫前缀/Base 版本时同步提升对应内置
/// 动词版本，再执行全局回扫。集合语法 ( ... ) 走 003a 单一 BNode 路径，
/// 不经此机制、不 skolemize。
pub(all) enum IRIUpcastEvent {
  UpcastRDFRest
  UpcastRDFFirst
} derive(Eq)

///|
/// 已切片前的四元组（纯 span + 谓词标记 + IRI 版本；组装/验证在 SliceParser，
/// 与 nquads 分层一致）。
pub(all) struct QuadSpan {
  s : Span
  p : Span
  o : Span
  g : Span? // 图名 span；None = 默认图（N3 无图块，恒 None——字段保留为管线同源布局）。
  pk : PredKind // 谓词来源：Normal=原文；RDFFirst/RDFRest=显式链物化（ADR-003b）。
  pver : Int // 前缀账本版本 = 发射时点账本长（物化层回扫上界——中途重声明不污染历史 quad）。
  bver : Int // base 链版本 = 发射时点链长（物化层折叠得该 quad 生效 base）。
  iver : Int // IRI 版本 = 发射时点 upcast 账本长（ADR-003b 显式链专用；集合语法不经此槽）。
}

///|
/// 栈帧类型（`[]`/`()`/`{}` 的 fresh 结构身份）：
/// BnodeProp = `[ ... ]` 属性列表；
/// Collection = `( ... )` 集合语法 → 单一 BNode（ADR-003a：不展开
///             rdf:first/rest，不 skolemize）；
/// Formula = N3 `{ ... }` 公式（ADR-002：GraphTerm 保留，不断言为真）。
pub(all) enum SlotType {
  BnodeProp
  Collection
  Formula
} derive(Eq)

///|
/// 外层槽位快照帧（`ctx.slot_stack` 元素，嵌套深度 = 栈长）：
///   open_span = 开括号 token 自身 span——fresh bnode / 公式 / 集合身份；
///              offset 全文档唯一（小于 128 位索引号退化为 `_`；大于 128 位索引号转型 6 位回分，大于 2**32 退化为 `_`）。
///   subject/predicate/graph = 进入时外层槽位快照（弹栈恢复用）。
///   ret_state = 返回状态：开括号转移行定夺（顶层/嵌套层各写各的），
///               帧只是携带表已做的决策；pop 时兑现——state 由表管理的唯一例外。
///   as_subject = fresh 节点落位：true = 外层 s 槽（主位进入），false = 外层 o 槽（宾位进入）。
///   prev_node/node_seq = 集合链上一节点与节点序号（Collection 专用；BnodeProp/Formula 恒 None/0）。
pub(all) struct Slot {
  typ : SlotType
  open_span : Span
  subject : Span?
  predicate : Span?
  graph : Span?
  ret_state : N3State
  as_subject : Bool
  prev_node : Span?
  mut node_seq : Int
}

///|
/// NodeID 位址盖写：两路模运算，128 位为界；
///   >128 位：按 6 位段移位，最低位号 A=0，最高位号 z=25；精确分段映射。
///   <128 位：退化为 Lua 兼容短名 `_`；>2**32 退化为 `_`。
pub(all) enum SlotNodeId {
  SlotNodeId(Int)
}

///|
/// 规则侧标记（ADR-005：`=>` / `<=` 只作内置谓词标识保留，不推理）。
/// Body = 前件（`=>` 左侧 / `<=` 右侧）；Head = 后件，对偶。
pub(all) enum RuleSide {
  Body
  Head
} derive(Eq)

///|
pub impl ErrOut for ParseError with fn message(self : ParseError) -> String {
  match self {
    ParseError::ValidationErr(message) => message
    ParseError::StructSyntaxErr(message, _, _) => message
    ParseError::SyntaxErr(message, _) => message
    ParseError::IriErr(message) => message
  }
}

///|
pub impl ErrOut for ParseError with fn err_kind(self : ParseError) -> String {
  match self {
    ValidationErr(_) => "ValidationErr"
    ParseError::StructSyntaxErr(_, _, _) => "StructSyntaxErr"
    SyntaxErr(_, _) => "SyntaxErr"
    ParseError::IriErr(_) => "IriErr"
  }
}

///|
pub trait ErrOut {
  fn message(self : Self) -> String
  fn err_kind(self : Self) -> String
}

///|
/// 按 span 安全切分数据（越界返回空视图）。
pub fn slice_span(data : ArrayView[Byte], span : Span) -> ArrayView[Byte] {
  let (off, len) = span
  if off < 0 || len < 0 || off + len > data.length() {
    return data[0:0]
  }
  data[off:off + len]
}

///|
pub impl Show for N3Event with fn output(self : N3Event, logger : &Logger) -> Unit {
  match self {
    N3Event::N3Iri(span) => logger.write("IRI \{@debug.to_string(span)}")
    N3Event::N3BlankNode(span) =>
      logger.write("BlankNode \{@debug.to_string(span)}")
    N3Event::N3Literal(span, span2) =>
      logger.write(
        "Literal \{@debug.to_string(span)} lang=\{@debug.to_string(span2)}",
      )
    N3Event::N3PrefName(span) =>
      logger.write("PrefName \{@debug.to_string(span)}")
    N3Event::N3TripleTerm(span) =>
      logger.write("TripleTerm \{@debug.to_string(span)}")
    N3Event::N3BracketTripleTerm(span) =>
      logger.write("BracketTripleTerm \{@debug.to_string(span)}")
    N3Event::N3KeywordA(span) =>
      logger.write("KeywordA \{@debug.to_string(span)}")
    N3Event::N3Variable(span) =>
      logger.write("Variable \{@debug.to_string(span)}")
    N3Event::N3Equals => logger.write("Equals")
    N3Event::N3At => logger.write("@")
    N3Event::N3PrefixKw => logger.write("PrefixKw")
    N3Event::N3BaseKw => logger.write("BaseKw")
    N3Event::N3ForAllKw => logger.write("ForAllKw")
    N3Event::N3ForSomeKw => logger.write("ForSomeKw")
    N3Event::N3KeywordsKw => logger.write("KeywordsKw")
    N3Event::N3Comma => logger.write("Comma")
    N3Event::N3Semicolon => logger.write("Semicolon")
    N3Event::N3Dot => logger.write("Dot")
    N3Event::N3Lbrace => logger.write("Lbrace")
    N3Event::N3Rbrace => logger.write("Rbrace")
    N3Event::N3Lbracket(span) =>
      logger.write("Lbracket \{@debug.to_string(span)}")
    N3Event::N3Rbracket => logger.write("Rbracket")
    N3Event::N3Lparen(span) => logger.write("Lparen \{@debug.to_string(span)}")
    N3Event::N3Rparen => logger.write("Rparen")
    N3Event::N3Anon(span) => logger.write("Anon \{@debug.to_string(span)}")
    N3Event::N3Bang => logger.write("Bang")
    N3Event::N3Caret => logger.write("Caret")
    N3Event::N3Implies => logger.write("Implies")
    N3Event::N3ImpliedBy => logger.write("ImpliedBy")
    N3Event::N3Unknown => logger.write("Unknown")
    N3Event::N3EOF => logger.write("EOF")
  }
}
