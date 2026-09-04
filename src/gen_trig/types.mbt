// ===== 用户部分：基础类型 =====
// 复用 @nquads 的共享词表（Span/PendingQuad/ResetScope/TermType/ParseError/Token/Lexermoon），
// 本包只保留 TriG 自身的输出形状 QuadSpan（纯 span 四元组）与 ErrOut 错误外观。
// todo：生成器回灌后 using 清单由 spec 的 imports 段生成。

///|
pub using @nquads {
  type Token,
  type Lexermoon,
  type ParseError,
  type Span,
  type TermType,
}

///|
/// 方言开关（用户补充面桩：生成契约不引用，引擎 loop 用）：
/// TriG = 超集；Turtle 禁图块区（Lbrace 走 Unknown 恢复路径）
pub(all) enum TrigDialect {
  TriG
  Turtle
} derive(Eq)

///|
/// 合成谓词标记（★3 集合链）：链节点 rdf:first/rdf:rest 谓词在数据中无字节，
/// 表在合成发射行把标记写 ctx.pred_kind，快照时随 quad 带出（快照即消费——
/// 读后归 Normal，恰覆盖一次发射），物化层据此合成词表 IRI。Normal = 原文谓词
pub(all) enum PredKind {
  Normal
  RDFFirst
  RDFRest
} derive(Eq)

///|
/// 已切片前的四元组（纯 span + 谓词标记；组装/验证在 SliceParser，与 nquads 分层一致）
pub(all) struct QuadSpan {
  s : Span
  p : Span
  o : Span
  g : Span? // 图名 span；None = 默认图
  pk : PredKind // 谓词来源：Normal=原文；RDFFirst/RDFRest=集合链合成（p 无字节）
  pver : Int // 前缀账本版本 = 发射时点账本长（物化层回扫上界——中途重声明不污染历史 quad）
  bver : Int // base 链版本 = 发射时点链长（物化层折叠得该 quad 生效 base）
}

///|
/// 栈帧类型（★3 `[]`/`()` 的 fresh 结构身份）：
/// BnodeProp = `[ ... ]` 属性列表；List = `( ... )` 集合（预埋，阶段3 接表）；
/// Formula = N3 `{ }` 公式（预埋未接）
pub(all) enum SlotType {
  BnodeProp
  List
  Formula
} derive(Eq)

///|
/// 外层槽位快照帧（ctx.slot_stack 元素，嵌套深度 = 栈长）：
///   open_span  = 开括号 token 自身 span——fresh bnode 身份（offset 全文档唯一；
///                不在 Span 内编码额外信息，物化层按 offset memo 出 `_:genid<N>`；
///                W3C 比对是图同构，标签只需文档内一致）
///   subject/predicate/graph = 进入时外层槽位快照（弹栈恢复用）
///   ret_state  = 返回状态：开括号转移行定夺（顶层/图块/嵌套层各写各的），
///                帧只是携带表已做的决策；pop 时兑现——state 由表管理的唯一例外
///   as_subject = fresh 节点落位：true=外层 s 槽（主位进入），false=外层 o 槽（宾位进入）
///   prev_node/node_seq = 集合链上一节点与节点序号（List 专用；BnodeProp 恒 None/0）
pub(all) struct Slot {
  typ : SlotType
  open_span : Span
  subject : Span?
  predicate : Span?
  graph : Span?
  ret_state : TrigState
  as_subject : Bool
  prev_node : Span?
  mut node_seq : Int
}

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
/// 按 span 安全切分数据（越界返回空视图）
pub fn slice_span(data : ArrayView[Byte], span : Span) -> ArrayView[Byte] {
  let (off, len) = span
  if off < 0 || len < 0 || off + len > data.length() {
    return data[0:0]
  }
  data[off:off + len]
}

///|
pub impl Show for TrigEvent with fn output(self : TrigEvent, logger : &Logger) -> Unit {
  match self {
    TrigEvent::TrigIri(span) => logger.write("IRI \{span}")
    TrigEvent::TrigBlankNode(span) => logger.write("BlankNode \{span}")
    TrigEvent::TrigLiteral(span) => logger.write("Literal \{span}")
    TrigEvent::TrigPrefName(span) => logger.write("PrefName \{span}")
    TrigEvent::TrigTripleTerm(span) => logger.write("TripleTerm \{span}")
    TrigEvent::TrigKeywordA(span) => logger.write("KeywordA \{span}")
    TrigEvent::TrigAt => logger.write("@")
    TrigEvent::TrigPrefixKw => logger.write("PrefixKw")
    TrigEvent::TrigBaseKw => logger.write("BaseKw")
    TrigEvent::TrigGraphKw => logger.write("GraphKw")
    TrigEvent::TrigComma => logger.write("Comma")
    TrigEvent::TrigSemicolon => logger.write("Semicolon")
    TrigEvent::TrigDot => logger.write("Dot")
    TrigEvent::TrigLbrace => logger.write("Lbrace")
    TrigEvent::TrigRbrace => logger.write("Rbrace")
    TrigEvent::TrigLbracket(span) => logger.write("Lbracket \{span}")
    TrigEvent::TrigAnon(span) => logger.write("Anon \{span}")
    TrigEvent::TrigRbracket => logger.write("Rbracket")
    TrigEvent::TrigLparen(span) => logger.write("Lparen \{span}")
    TrigEvent::TrigRparen => logger.write("Rparen")
    TrigEvent::TrigUnknown => logger.write("Unknown")
    TrigEvent::TrigEOF => logger.write("EOF")
    TrigEvent::TrigAnnotStart => logger.write("AnnotStart")
    TrigEvent::TrigAnnotEnd => logger.write("AnnotEnd")
    TrigEvent::TrigVersionKw => logger.write("VersionKw")
    TrigEvent::TrigTilde => logger.write("Tilde")
    TrigEvent::TrigBang => logger.write("Bang")
    TrigEvent::TrigCaret => logger.write("Caret")
    TrigEvent::TrigImplies => logger.write("Implies")
    TrigEvent::TrigImpliedBy => logger.write("ImpliedBy")
    TrigEvent::TrigForAllKw => logger.write("ForAllKw")
    TrigEvent::TrigForSomeKw => logger.write("ForSomeKw")
    TrigEvent::TrigKeywordsKw => logger.write("KeywordsKw")
    TrigEvent::TrigBracketTripleTerm(span) =>
      logger.write("BracketTripleTerm \{@debug.to_string(span)}")
  }
}
