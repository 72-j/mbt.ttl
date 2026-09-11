// ===== 用户部分：基础类型 =====
// 复用 @nquads 的共享词表（Token/Lexermoon/ParseError/Span/TermType），
// 本包保留 N3 自身的类型面：方言开关 / PredKind / QuadSpan /
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
/// 布局与 trig ★3 四快照槽同源（pk/prefix_version/base_version/iri_version）。枚举本体生成器发射（n3.mbt）。

///|
/// 已切片前的四元组（纯 span + 谓词标记 + IRI 版本；组装/验证在 SliceParser，
/// 与 nquads 分层一致）。
pub(all) struct QuadSpan {
  s : Span
  p : Span
  o : Span
  g : Span? // 图名 span；None = 默认图（N3 无图块，恒 None——字段保留为管线同源布局）。
  pk : PredKind // 谓词来源：Normal=原文；RDFFirst/RDFRest=显式链物化（ADR-003b）。
  prefix_version : Int // 前缀账本版本 = 发射时点账本长（物化层回扫上界——中途重声明不污染历史 quad）。
  base_version : Int // base 链版本 = 发射时点链长（物化层折叠得该 quad 生效 base）。
  iri_version : Int // IRI 版本 = 发射时点 upcast 账本长（ADR-003b 显式链专用；集合语法不经此槽）。
  subj_shell : Bool // 注解壳主语（役8）：true = s 为锚三元组原文 span，物化层合成 <<原文>> TT 壳。
}

///|
/// 栈帧类型（`[]`/`()`/`{}` 的 fresh 结构身份）：
/// BnodeProp = `[ ... ]` 属性列表；
/// Collection = `( ... )` 集合语法 → 单一 BNode（ADR-003a：不展开
///             rdf:first/rest，不 skolemize）；
/// Formula = N3 `{ ... }` 公式（ADR-002：GraphTerm 保留，不断言为真）。
priv enum SlotType {
  BnodeProp
  Collection
  Formula
}

///|
/// 外层槽位快照帧（`ctx.slot_stack` 元素，嵌套深度 = 栈长）：
///   open_span = 开括号 token 自身 span——fresh bnode / 公式 / 集合身份；
///              offset 全文档唯一（小于 128 位索引号退化为 `_`；大于 128 位索引号转型 6 位回分，大于 2**32 退化为 `_`）。
///   subject/predicate/graph = 进入时外层槽位快照（弹栈恢复用）。
///   ret_state = 返回状态：开括号转移行定夺（顶层/嵌套层各写各的），
///               帧只是携带表已做的决策；pop 时兑现——state 由表管理的唯一例外。
///               役14 宾位尾随收口按事件改写（path_obj_close：Dot/Comma/
///               Semicolon 各指各的归位态）——mut。
///   as_subject = fresh 节点落位：true = 外层 s 槽（主位进入），false = 外层 o 槽（宾位进入）。
///   as_pred = 役10 公式谓词位：true = 弹栈身份落外层 p 槽（谓词位进入，
///             open_formula_pred 专用；与 as_subject 互斥，pop 三向裁决）。
///   prev_node/node_seq = 集合链上一节点与节点序号（Collection 专用；BnodeProp/Formula 恒 None/0）。
priv struct Slot {
  typ : SlotType
  mut open_span : Span // 役18 宾位尾随收口：帧身份改指终尾（多跳链末节点），pop 落位外层语句宾位
  subject : Span?
  predicate : Span?
  graph : Span?
  mut ret_state : N3State
  as_subject : Bool
  as_pred : Bool
  mut prev_node : Span?
  mut node_seq : Int
  mut id_subject : Span? // 役16 B 桶：`[ id :X … ]` 语义主语（None = fresh 开括号身份；pop 时盖写落位）
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
/// 按 span 安全切分数据（越界返回空视图）。
fn slice_span(data : ArrayView[Byte], span : Span) -> ArrayView[Byte] {
  let (off, len) = span
  if off < 0 || len < 0 || off + len > data.length() {
    return data[0:0]
  }
  data[off:off + len]
}
