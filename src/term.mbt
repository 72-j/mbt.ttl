///|
/// 主语类型
pub(all) enum Subject {
  Iri(Span) // <http://...>
  BNode(Span) // _:label
  PrefName(Span) // ex:name 或 :name
} derive(Debug, Eq)

///|
/// 宾语类型
pub(all) enum Object {
  Iri(Span)
  BNode(Span)
  Literal(Span)
  PrefName(Span)
} derive(Debug, Eq)

///|
/// Predicate = BytesView（只能是 IRI）
pub type Predicate = Span

///|
/// 图名
pub(all) enum GraphName {
  None // DefaultGraph
  Iri(Span)
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
      logger.write_string("(\{span.0}, \{span.1})")
      logger.write_char('>')
    }
    Subject::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.0}, \{span.1})")
    }
    Subject::PrefName(span) => logger.write_string("(\{span.0}, \{span.1})")
  }

  logger.write_string(", ")

  // 谓语
  logger.write_string("(\{self.predicate.0}, \{self.predicate.1})")

  logger.write_string(", ")

  // 宾语
  match self.object {
    Object::Iri(span) => {
      logger.write_char('<')
      logger.write_string("(\{span.0}, \{span.1})")
      logger.write_char('>')
    }
    Object::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.0}, \{span.1})")
    }
    Object::Literal(span) | Object::PrefName(span) =>
      logger.write_string("(\{span.0}, \{span.1})")
  }

  // 图名 ← 这里可能没有输出
  match self.graph_name {
    GraphName::None => logger.write_string(", graph: None")
    GraphName::Iri(span) => {
      logger.write_string(", graph: <")
      logger.write_string("(\{span.0}, \{span.1})")
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
      logger.write_string("(\{span.0}, \{span.1})")
      logger.write_char('>')
    }
    Subject::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.0}, \{span.1})")
    }
    Subject::PrefName(span) => logger.write_string("(\{span.0}, \{span.1})")
  }
}

///|
pub impl Show for Object with fn output(self : Object, logger : &Logger) -> Unit {
  match self {
    Object::Iri(span) => {
      logger.write_char('<')
      logger.write_string("(\{span.0}, \{span.1})")
      logger.write_char('>')
    }
    Object::BNode(span) => {
      logger.write_string("_:")
      logger.write_string("(\{span.0}, \{span.1})")
    }
    Object::Literal(span) => logger.write_string("(\{span.0}, \{span.1})")
    Object::PrefName(span) => logger.write_string("(\{span.0}, \{span.1})")
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
  self : Serializer,
  span : Span,
  buf : StringBuilder,
) -> Unit {
  let (offset, length) = span
  // let view = self.data[offset:offset + length]
  // buf.write_string(view.to_string())
  for i = offset; i < offset + length; i = i + 1 {
    buf.write_char(self.data[i].to_char())
  }
}

///|
fn Serializer::append_bnode_label(
  self : Serializer,
  span : Span,
  buf : StringBuilder,
) -> Unit {
  let (offset, length) = span
  let view = self.data[offset:offset + length]
  // 跳过前两个字符 _:
  let label = view[2:]
  // 直接写入整个标签
  for b in label {
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
    Subject::Iri(span) => self.append_span(span, buf)
    Subject::BNode(span) => {
      buf.write_string("_:")
      self.append_bnode_label(span, buf)
    }
    Subject::PrefName(span) => self.append_span(span, buf)
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
    Object::Iri(span) => self.append_span(span, buf)
    Object::BNode(span) => {
      buf.write_string("_:")
      self.append_bnode_label(span, buf)
    }
    Object::Literal(span) | Object::PrefName(span) =>
      self.append_span(span, buf)
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
    GraphName::Iri(span) => {
      buf.write_char(' ')
      self.append_span(span, buf)
    }
    GraphName::None => buf.write_string("")
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
    lexscan self.mode with longest {
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
