///|
pub impl Show for QuadSpan with fn output(self : QuadSpan, logger : &Logger) -> Unit {
  logger.write("QuadSpan")
  logger.write("{ ")
  logger.write("subj: ")
  logger.write(@utf8.decode_lossy(Bytes::from_array(self.subj)))
  logger.write(", ")
  logger.write("pred: ")
  logger.write(@utf8.decode_lossy(Bytes::from_array(self.pred)))
  logger.write(", ")
  logger.write("obj: ")
  logger.write(@utf8.decode_lossy(Bytes::from_array(self.obj)))
  logger.write(", ")
  logger.write("graph: ")
  if self.graph is Some(graph) {
    logger.write(@utf8.decode_lossy(Bytes::from_array(graph)))
  }
  // logger.write(", ")
  // logger.write("line: ")
  // logger.write(self.line)
  logger.write(", ")
  logger.write("subj_type: ")
  logger.write(@debug.to_string(self.subj_type))
  logger.write(", ")
  logger.write("obj_type: ")
  logger.write(@debug.to_string(self.obj_type))
  logger.write("}")
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend QuadSpan with Show::{output, to_string}

///|
pub impl Show for TermType with fn output(self : TermType, logger : &Logger) -> Unit {
  match self {
    Iri => logger.write("Iri")
    BNode => logger.write("BNode")
    Literal => logger.write("Literal")
    TripleTerm => logger.write("TripleTerm")
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TermType with Show::{output, to_string}

///|
/// 词项种类（P3 平化产物模型：Subject/Object/GraphName 三枚举并入单 kind 轴）。
/// 8 臂全常量构造子 = 立即 tag 零箱（同械先例 QuadSpan.subj_type : TermType）；
/// DefaultGraph 单例常量 = 原 GraphName::None（图名位缺省，非箱）
pub(all) enum TermKind {
  Iri // <http://...>
  BNode // _:label（blank node：label 作用域限本文档）
  PrefName // ex:name 或 :name（三物化器零构造：N3 侧展开落 arena IRI；
  // 序列化侧防御拒臂钉住不变量）
  TripleTerm // << s p o >>（RDF 1.2 引用三元组壳，整段原文持有，字节保真）
  Variable // ?x（N3 ADR-004：只记身份，名与位置即全部语义；
  // nquads/trig 方言不产出，序列化侧防御拒臂钉住）
  Literal // "x"@en/数值/布尔（N3 役10：verb ::= expression 主语位字面量；
  // nquads/trig 方言不产出，序列化侧防御拒臂钉住）
  Formula // { ... }（N3 ADR-002：GraphTerm 不透明不断言为真，整段原文持有；
  // nquads/trig 方言不产出，序列化侧防御拒臂钉住）
  DefaultGraph // 图名位缺省（W3C N-Quads 默认图；单例常量非箱）
} derive(Debug, Eq)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TermKind with Eq::{equal, not_equal}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TermKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Predicate = BytesView（只能是 IRI）
pub type Predicate = ArrayView[Byte]

///|
/// N-Quads Quad（P3 平化：kind+view 直挂，词项零箱——box 真值表见 todo.md §AP.19）。
/// view 有效性由 kind 门控：DefaultGraph 的 g_view、以及"位-种类"非法组合下的
/// view 值未定义，消费侧必须先判 kind 再读 view（DefaultGraph 臂不得触 view）
pub(all) struct QuadEmit {
  s_kind : TermKind
  s_view : ArrayView[Byte]
  predicate : Predicate
  o_kind : TermKind
  o_view : ArrayView[Byte]
  g_kind : TermKind
  g_view : ArrayView[Byte]
} derive(Debug, Eq)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend QuadEmit with Eq::{equal, not_equal}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend QuadEmit with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 词项展示（kind+view 对：与 QuadEmit Show 单词项臂同文本，金样迁移共用）
fn show_term_view(
  kind : TermKind,
  view : ArrayView[Byte],
  logger : &Logger,
) -> Unit {
  match kind {
    TermKind::Iri => {
      logger.write_char('<')
      logger.write_string("(\{view.length()})")
      logger.write_char('>')
    }
    TermKind::BNode => {
      logger.write_string("_:")
      logger.write_string("(\{view.length()})")
    }
    TermKind::PrefName => logger.write_string("(\{view.length()})")
    TermKind::TripleTerm => logger.write_string("(\{view.length()})")
    TermKind::Variable => logger.write_string("?\{view.length()}")
    TermKind::Literal => logger.write_string("(\{view.length()})")
    TermKind::Formula => logger.write_string("(\{view.length()})")
    // 位-种类非法组合（DefaultGraph 只许图名位）：调试面显式点名，不静默
    TermKind::DefaultGraph => logger.write_string("DefaultGraph")
  }
}

///|
pub impl Show for TermKind with fn output(self : TermKind, logger : &Logger) -> Unit {
  match self {
    Iri => logger.write("Iri")
    BNode => logger.write("BNode")
    PrefName => logger.write("PrefName")
    TripleTerm => logger.write("TripleTerm")
    Variable => logger.write("Variable")
    Literal => logger.write("Literal")
    Formula => logger.write("Formula")
    DefaultGraph => logger.write("DefaultGraph")
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TermKind with Show::{output, to_string}

///|
pub impl Show for QuadEmit with fn output(self : QuadEmit, logger : &Logger) -> Unit {
  logger.write_string("Quad(")

  // 主语
  show_term_view(self.s_kind, self.s_view, logger)

  logger.write_string(", ")

  // 谓语
  logger.write_string("(\{self.predicate.length()})")

  logger.write_string(", ")

  // 宾语
  show_term_view(self.o_kind, self.o_view, logger)

  // 图名 ← 这里可能没有输出
  match self.g_kind {
    TermKind::DefaultGraph => logger.write_string(", graph: None")
    TermKind::Iri => {
      logger.write_string(", graph: <")
      logger.write_string("(\{self.g_view.length()})")
      logger.write_char('>')
    }
    TermKind::BNode => {
      logger.write_string(", graph: _:")
      logger.write_string("(\{self.g_view.length()})")
    }
    // 位-种类非法组合（图名位只许 Iri/BNode/DefaultGraph）：调试面显式点名
    kind => logger.write_string(", graph: <invalid:\{Show::to_string(kind)}>")
  }

  logger.write_char(')')
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend QuadEmit with Show::{output, to_string}
