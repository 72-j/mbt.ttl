///|
type Span = (Int, Int)

///|
enum TermType {
  Iri
  BNode
  Literal
  PrefName
  Unknown
} derive(Debug, Eq)

///|
// fn TermType::default() -> TermType {
//   Iri
// }

///|
impl Show for TermType with fn output(self : TermType, logger : &Logger) -> Unit {
  match self {
    Iri => logger.write("Iri")
    BNode => logger.write("BNode")
    PrefName => logger.write("PrefName")
    Literal => logger.write("Literal")
    Unknown => logger.write("Unknown")
  }
}

///|
/// 主语类型
enum Subject {
  Iri(ArrayView[Byte]) // <http://...>
  BNode(ArrayView[Byte]) // _:label
  PrefName(ArrayView[Byte]) // ex:name 或 :name
} derive(Debug, Eq)

///|
/// 宾语类型
enum Object {
  Iri(ArrayView[Byte])
  BNode(ArrayView[Byte])
  Literal(ArrayView[Byte])
  PrefName(ArrayView[Byte])
} derive(Debug, Eq)

///|
/// Predicate = BytesView（只能是 IRI）
type Predicate = ArrayView[Byte]

///|
/// 图名
enum GraphName {
  None // DefaultGraph
  Iri(ArrayView[Byte])
} derive(Debug, Eq)

///|
/// N-Quads Quad
struct QuadEmit {
  subject : Subject
  predicate : Predicate
  object : Object
  graph : GraphName
  // line : Int
} derive(Debug, Eq)

///|
impl Show for QuadEmit with fn output(self : QuadEmit, logger : &Logger) -> Unit {
  logger.write_string("Quad(")

  // 主语
  match self.subject {
    Subject::Iri(span) => {
      logger.write_char('<')
      logger.write_string("(\{span.length()})")
      logger.write_char('>')
    }
    Subject::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.length()})")
    }
    Subject::PrefName(span) => logger.write_string("(\{span.length()})")
  }

  logger.write_string(", ")

  // 谓语
  logger.write_string("(\{self.predicate.length()})")

  logger.write_string(", ")

  // 宾语
  match self.object {
    Object::Iri(span) => {
      logger.write_char('<')
      logger.write_string("(\{span.length()})")
      logger.write_char('>')
    }
    Object::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.length()})")
    }
    Object::Literal(span) | Object::PrefName(span) =>
      logger.write_string("(\{span.length()})")
  }

  // 图名 ← 这里可能没有输出
  match self.graph {
    GraphName::None => logger.write_string(", graph: None")
    GraphName::Iri(span) => {
      logger.write_string(", graph: <")
      logger.write_string("(\{span.length()})")
      logger.write_char('>')
    }
  }

  logger.write_char(')')
}

///|
impl Show for Subject with fn output(self : Subject, logger : &Logger) -> Unit {
  match self {
    Subject::Iri(span) => {
      logger.write_char('<')
      logger.write_string("(\{span.length()})")
      logger.write_char('>')
    }
    Subject::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.length()})")
    }
    Subject::PrefName(span) => logger.write_string("(\{span.length()})")
  }
}

///|
impl Show for Object with fn output(self : Object, logger : &Logger) -> Unit {
  match self {
    Object::Iri(span) => {
      logger.write_char('<')
      logger.write_string("(\{span.length()})")
      logger.write_char('>')
    }
    Object::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.length()})")
    }
    Object::Literal(span) => logger.write_string("(\{span.length()})")
    Object::PrefName(span) => logger.write_string("(\{span.length()})")
  }
}
