///|
pub type Span = (Int, Int)

///|
pub struct QuadSpan {
  subj : ArrayView[Byte]
  pred : ArrayView[Byte]
  obj : ArrayView[Byte]
  graph : ArrayView[Byte]?
  line : Int
  subj_type : TermType // 主语类型
  obj_type : TermType // 宾语类型  
  has_err : Bool // 是否有结构错误
} derive(Debug)

///|
pub impl Show for QuadSpan with fn output(self : QuadSpan, logger : &Logger) -> Unit {
  logger.write("QuadSpan")
  logger.write("{ ")
  logger.write("subj: ")
  logger.write(@utf8.decode_lossy(array_to_view(self.subj)))
  logger.write(", ")
  logger.write("pred: ")
  logger.write(@utf8.decode_lossy(array_to_view(self.pred)))
  logger.write(", ")
  logger.write("obj: ")
  logger.write(@utf8.decode_lossy(array_to_view(self.obj)))
  logger.write(", ")
  logger.write("graph: ")
  if self.graph is Some(graph) {
    logger.write(@utf8.decode_lossy(array_to_view(graph)))
  }
  logger.write(", ")
  logger.write("line: ")
  logger.write(self.line)
  logger.write(", ")
  logger.write("subj_type: ")
  logger.write(@debug.to_string(self.subj_type))
  logger.write(", ")
  logger.write("obj_type: ")
  logger.write(@debug.to_string(self.obj_type))
  logger.write("}")
}

///|
pub(all) enum TermType {
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
pub impl Show for TermType with fn output(self : TermType, logger : &Logger) -> Unit {
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
pub(all) enum Subject {
  Iri(ArrayView[Byte]) // <http://...>
  BNode(ArrayView[Byte]) // _:label
  PrefName(ArrayView[Byte]) // ex:name 或 :name
} derive(Debug, Eq)

///|
/// 宾语类型
pub(all) enum Object {
  Iri(ArrayView[Byte])
  BNode(ArrayView[Byte])
  Literal(ArrayView[Byte])
  PrefName(ArrayView[Byte])
} derive(Debug, Eq)

///|
/// Predicate = BytesView（只能是 IRI）
pub type Predicate = ArrayView[Byte]

///|
/// 图名
pub(all) enum GraphName {
  None // DefaultGraph
  Iri(ArrayView[Byte])
} derive(Debug, Eq)

///|
/// N-Quads Quad
pub(all) struct QuadEmit {
  subject : Subject
  predicate : Predicate
  object : Object
  graph : GraphName
  line : Int
} derive(Debug, Eq)

///|
pub impl Show for QuadEmit with fn output(self : QuadEmit, logger : &Logger) -> Unit {
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
pub impl Show for Subject with fn output(self : Subject, logger : &Logger) -> Unit {
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
pub impl Show for Object with fn output(self : Object, logger : &Logger) -> Unit {
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
