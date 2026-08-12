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
  graph_name : GraphName
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
  match self.graph_name {
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

///|
pub struct Serializer {
  data : ArrayView[Byte]
  mode : StringView
}

///|
pub fn Serializer::new(
  data : ArrayView[Byte],
  mode? : StringView = "triple",
) -> Serializer {
  { data, mode }
}

///|
/// 序列化单个 Quad
pub fn Serializer::serialize(self : Serializer, quad : QuadEmit) -> String {
  let buf = StringBuilder::new()
  self.append_quad(quad, buf)
  buf.to_string()
}

///|
fn Serializer::append_span(
  _self : Serializer,
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Unit {
  for b in view {
    buf.write_char(b.to_char())
  }
}

///|
/// 内联优化：主语序列化
fn Serializer::append_subject(
  self : Serializer,
  subject : Subject,
  buf : StringBuilder,
) -> Unit {
  match subject {
    Subject::Iri(view) => self.append_span(view, buf)
    Subject::BNode(view) => {
      buf.write_string("_:")
      // 跳过前两个字符 _:，直接写 label
      let label = view[2:]
      self.append_span(label, buf)
    }
    Subject::PrefName(view) => self.append_span(view, buf)
  }
}

///|
/// 内联优化：宾语序列化
fn Serializer::append_object(
  self : Serializer,
  object : Object,
  buf : StringBuilder,
) -> Unit {
  match object {
    Object::Iri(view) => self.append_span(view, buf)
    Object::BNode(view) => {
      buf.write_string("_:")
      let label = view[2:]
      self.append_span(label, buf)
    }
    Object::Literal(view) => self.append_span(view, buf)
    Object::PrefName(view) => self.append_span(view, buf)
  }
}

///|
/// 优化后的 Quad 序列化
fn Serializer::append_quad(
  self : Serializer,
  quad : QuadEmit,
  buf : StringBuilder,
) -> Unit {
  // 主语
  self.append_subject(quad.subject, buf)
  buf.write_char(' ')

  // 谓语
  self.append_span(quad.predicate, buf)
  buf.write_char(' ')

  // 宾语
  self.append_object(quad.object, buf)

  // 图名
  match quad.graph_name {
    GraphName::Iri(view) => {
      buf.write_char(' ')

      self.append_span(view, buf)
    }
    GraphName::None => ()
  }

  buf.write_string(" .\n")
}

///|
/// 序列化三元组（忽略图名）
fn Serializer::append_triple(
  self : Serializer,
  quad : QuadEmit,
  buf : StringBuilder,
) -> Unit {
  self.append_subject(quad.subject, buf)
  buf.write_char(' ')
  self.append_span(quad.predicate, buf)
  buf.write_char(' ')
  self.append_object(quad.object, buf)
  buf.write_string(" .\n")
}

///|
pub fn Serializer::serialize_all(
  self : Serializer,
  quads : Array[QuadEmit],
) -> String {
  let buf = StringBuilder::new()
  for quad in quads {
    lexmatch self.mode with longest {
      // 三元组模式
      re"^(?i:triple)$" => self.append_triple(quad, buf)

      // 四元组模式（包含图名）
      re"^(?i:quad|quads|all)$" => self.append_quad(quad, buf)

      // 只输出有图名的四元组
      re"^(?i:quadonly)$" =>
        match quad.graph_name {
          GraphName::Iri(_) => self.append_quad(quad, buf)
          GraphName::None => ()
        }

      // 默认三元组
      _ => self.append_triple(quad, buf)
    }
  }

  buf.to_string()
}
