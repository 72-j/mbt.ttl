// ============================================================
// N-Triples / N-Quads 序列化器
// ============================================================

///|
/// N-Triples 序列化器
pub struct Serializer {
  data : ArrayView[Byte]
  mode : StringView
}

///|
/// 创建序列化器
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
/// 写入字节视图
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
/// 序列化主语
fn Serializer::append_subject(
  self : Serializer,
  subject : Subject,
  buf : StringBuilder,
) -> Unit {
  match subject {
    Subject::Iri(view) => self.append_span(view, buf)
    Subject::BNode(view) => {
      buf.write_string("_:")
      self.append_span(view[2:], buf) // 跳过 "_:" 前缀
    }
    Subject::PrefName(view) => self.append_span(view, buf)
  }
}

///|
/// 序列化宾语
fn Serializer::append_object(
  self : Serializer,
  object : Object,
  buf : StringBuilder,
) -> Unit {
  match object {
    Object::Iri(view) => self.append_span(view, buf)
    Object::BNode(view) => {
      buf.write_string("_:")
      self.append_span(view[2:], buf)
    }
    Object::Literal(view) => self.append_span(view, buf)
    Object::PrefName(view) => self.append_span(view, buf)
  }
}

///|
/// 序列化完整 Quad (包含图名)
fn Serializer::append_quad(
  self : Serializer,
  quad : QuadEmit,
  buf : StringBuilder,
) -> Unit {
  self.append_subject(quad.subject, buf)
  buf.write_char(' ')
  self.append_span(quad.predicate, buf)
  buf.write_char(' ')
  self.append_object(quad.object, buf)

  match quad.graph {
    GraphName::Iri(view) => {
      buf.write_char(' ')
      self.append_span(view, buf)
    }
    GraphName::None => ()
  }

  buf.write_string(" .\n")
}

///|
/// 序列化 Triple (忽略图名)
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
/// 批量序列化
pub fn Serializer::serialize_all(
  self : Serializer,
  quads : Array[QuadEmit],
) -> String {
  let buf = StringBuilder::new()
  for quad in quads {
    lexmatch self.mode with longest {
      re"^(?i:triple|Triple)$" => self.append_triple(quad, buf) // 三元组模式
      re"^(?i:quad|nquads|Quad|all)$" => self.append_quad(quad, buf) // 四元组模式
      re"^(?i:quadonly)$" =>
        match quad.graph {
          GraphName::Iri(_) => self.append_quad(quad, buf) // 仅有名图的
          GraphName::None => ()
        }
      _ => self.append_triple(quad, buf) // 默认三元组
    }
  }
  buf.to_string()
}
