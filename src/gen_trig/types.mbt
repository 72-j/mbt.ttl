// ===== 装配层（Assembly）：基础类型 =====
// 复用 @nquads 的共享词表（Span/PendingQuad/ResetScope/TermType/ParseError/Token/Lexermoon/NQuadsEvent），
// 本包只保留 TriG 自身的输出形状 QuadSpan（纯 span 四元组）与 ErrOut 错误外观。
// todo：生成器回灌后 using 清单由 spec 的 imports 段生成。

///|
pub using @nquads {
  type Token,
  type Lexermoon,
  type NQuadsEvent,
  type ParseError,
  type Span,
  type TermType,
}

///|
/// **共享装配层件再导出**（T17 / C-T8）：纯函数面自 `gen_shared` 引入，本地调用点零改写。
/// 注：MoonBit 的 `using` 属**包级**作用域 ⇒ 每包只声明一次，且函数名**不加 `fn`**。
using @gs {
  at_style_kw,
  check_bnode_view,
  check_iri_view,
  deep_check_literal,
  deep_check_tt,
  eq_ignore_case,
  eq_lower,
  is_pn_local_esc,
  literal_body_end,
  slice_span,
  triple_term_inner_terms,
  view_has_scheme,
}

///|
/// 方言开关（装配层补充面桩：生成契约不引用，引擎 loop 用）：
/// TriG = 超集；Turtle 禁图块区（Lbrace 走 Unknown 恢复路径）；
/// **N3 = 役35 A1 新补档**（R-T13/C-T13）：当前**只开** `@keywords` 指令受理 +
/// 其后的 `a` 失效（降 PrefName）；**其余 N3 语法一律"未受理"**（仍按拒/恢复走，
/// 钉 6 防过度受理）。**套件**：N3 档**无 W3C 套件**（Turtle/TriG 套件不含 N3 档）⇒
/// 入册为覆盖缺口（面一侧）。口径依据：`@keywords` 在 Turtle/TriG 套件里是
/// `bad-n3-extras` **负例**（期望拒）⇒ 受理必须由档位表达（甲案，用户 2026-09-22 拍）。
pub(all) enum TrigDialect {
  TriG
  Turtle
  N3
} derive(Eq)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TrigDialect with Eq::{equal, not_equal}

///|
/// 合成谓词标记（★3 集合链）：链节点 rdf:first/rdf:rest 谓词在数据中无字节，
/// 表在合成发射行把标记写 ctx.pred_kind，快照时随 quad 带出（快照即消费——
/// 读后归 Normal，恰覆盖一次发射），物化层据此合成词表 IRI。Normal = 原文谓词
pub(all) enum PredKind {
  Normal
  RDFFirst
  RDFRest
  // 役35 A1（R-T13/C-T13）：谓词位 `a` **保留**为 turtle `rdf:type` 简写时的标记。
  // 与 n3v2 的 `PredKind::KwA` 同名同义（收敛：**判据落在产物可判的 pk 面**）。
  // 失效（N3 档 ∧ `@keywords` 已受理）时不置位 ⇒ 物化层按 PrefName 展开。
  KwA
} derive(Eq)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend PredKind with Eq::{equal, not_equal}

///|
/// 已切片前的四元组（纯 span + 谓词标记；组装/验证在 SliceParser，与 nquads 分层一致）
pub(all) struct QuadSpan {
  s : Span
  p : Span
  o : Span
  g : Span? // 图名 span；None = 默认图
  pk : PredKind // 谓词来源：Normal=原文；RDFFirst/RDFRest=集合链合成（p 无字节）
  prefix_version : Int // 前缀账本版本 = 发射时点账本长（物化层回扫上界——中途重声明不污染历史 quad）
  base_version : Int // base 链版本 = 发射时点链长（物化层折叠得该 quad 生效 base）
  subj_shell : Bool // 注解壳主语（役9）：true = s 为锚三元组原文 span，物化层合成 <<原文>> TT 壳。
}

///|
/// 栈帧类型（★3 `[]`/`()` 的 fresh 结构身份）：
/// BnodeProp = `[ ... ]` 属性列表；List = `( ... )` 集合（预埋，阶段3 接表）；
/// Formula = N3 `{ }` 公式（预埋未接）
///
/// P3（2026-09-14）：**pub(all)** —— 被生成件 `TrigEffect::OpenSlot(Span, SlotType, ...)`
/// 与 `TrigContext.slot_stack` 引用；`internals_priv = false` 下生成件发 `pub(all)`，
/// MoonBit 禁止"public definition depends on private type"，故此处必须同步放开
/// （契约面最小集：`SlotType` + `Slot`）。
pub(all) enum SlotType {
  BnodeProp
  List
  Formula
}

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
  ret_state : TrigState // 返回态：类型来自生成件（`internals_priv` 下为 priv）
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
pub impl Show for TrigEvent with fn output(self : TrigEvent, logger : &Logger) -> Unit {
  match self {
    TrigEvent::TrigIri(span) => logger.write("IRI \{@debug.to_string(span)}")
    TrigEvent::TrigBlankNode(span) =>
      logger.write("BlankNode \{@debug.to_string(span)}")
    TrigEvent::TrigLiteral(span) =>
      logger.write("Literal \{@debug.to_string(span)}")
    TrigEvent::TrigPrefName(span) =>
      logger.write("PrefName \{@debug.to_string(span)}")
    TrigEvent::TrigTripleTerm(span) =>
      logger.write("TripleTerm \{@debug.to_string(span)}")
    TrigEvent::TrigKeywordA(span) =>
      logger.write("KeywordA \{@debug.to_string(span)}")
    TrigEvent::TrigAt => logger.write("@")
    TrigEvent::TrigPrefixKw => logger.write("PrefixKw")
    TrigEvent::TrigBaseKw => logger.write("BaseKw")
    TrigEvent::TrigGraphKw => logger.write("GraphKw")
    TrigEvent::TrigComma => logger.write("Comma")
    TrigEvent::TrigSemicolon => logger.write("Semicolon")
    TrigEvent::TrigDot => logger.write("Dot")
    TrigEvent::TrigLbrace => logger.write("Lbrace")
    TrigEvent::TrigRbrace => logger.write("Rbrace")
    TrigEvent::TrigLbracket(span) =>
      logger.write("Lbracket \{@debug.to_string(span)}")
    TrigEvent::TrigAnon(span) => logger.write("Anon \{@debug.to_string(span)}")
    TrigEvent::TrigRbracket => logger.write("Rbracket")
    TrigEvent::TrigLparen(span) =>
      logger.write("Lparen " + @debug.to_string(span))
    TrigEvent::TrigRparen => logger.write("Rparen")
    TrigEvent::TrigUnknown(span) =>
      logger.write("Unknown " + @debug.to_string(span))
    TrigEvent::TrigKeywordX(span) =>
      logger.write("KeywordX " + @debug.to_string(span))
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

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TrigEvent with Show::{output, to_string}

// W18（2026-09-22 主仓半·二）：`ResetScope`/`TrigPendingQuad` 的提升已由**模板直产**
// （黄金门逐字节钉）——手写件条目删除防 [4056] 撞车。
