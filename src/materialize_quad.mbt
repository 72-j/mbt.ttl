///|
/// 物化 Quad（批量优化）
pub fn materialize_quad(
  quad : QuadSpan,
  // data : ArrayView[Byte],
) -> Result[QuadEmit, ParserError] {

  // 物化
  let subject = match materialize_subject(quad.subj, quad.subj_type) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let predicate = match materialize_predicate(quad.pred) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let object = match materialize_object(quad.obj, quad.obj_type) {
    Ok(o) => o
    Err(e) => return Err(e)
  }

  // 图名（可选）

  let graph = match materialize_graph_name(quad.graph) {
    Ok(g) => g
    Err(e) => return Err(e)
  }
  Ok({ subject, predicate, object, graph, line: quad.line })
}

///|
/// 批量物化（优化：减少函数调用开销）
pub fn materialize_all(
  quads : Array[QuadSpan],
  // data : ArrayView[Byte],
) -> (Array[QuadEmit], Array[ParserError]) {
  let results = []
  let errors = []

  for quad in quads {
    match materialize_quad(quad) {
      Ok(q) => results.push(q)
      Err(e) => errors.push(e)
    }
  }

  (results, errors)
}

///|
fn materialize_subject(
  subject : ArrayView[Byte],
  t : TermType,
) -> Result[Subject, ParserError] {
  match t {
    TermType::Iri => Ok(Subject::Iri(subject))
    TermType::BNode => Ok(Subject::BNode(subject))
    TermType::PrefName =>
      Err(ParserError::ValidationErr("N-Quads does not support prefixed names"))
    TermType::Literal =>
      Err(ParserError::ValidationErr("Subject cannot be literal"))
    TermType::Unknown => Err(ParserError::ValidationErr("Invalid subject"))
  }
}

///|
fn materialize_object(
  object : ArrayView[Byte],
  t : TermType,
) -> Result[Object, ParserError] {
  match t {
    TermType::Iri => Ok(Object::Iri(object))
    TermType::BNode => Ok(Object::BNode(object))
    TermType::Literal => Ok(Object::Literal(object))
    TermType::PrefName =>
      Err(ParserError::ValidationErr("N-Quads does not support prefixed names"))
    TermType::Unknown => Err(ParserError::ValidationErr("Invalid object"))
  }
}

///|
fn materialize_predicate(
  predicate : ArrayView[Byte],
) -> Result[Predicate, ParserError] {
  // 谓语必须是 IRI，这里只做基本验证
  Ok(predicate)
}

///|
fn materialize_graph_name(
  graph : ArrayView[Byte]?,
) -> Result[GraphName, ParserError] {
  match graph {
    Some(g) => Ok(GraphName::Iri(g))
    None => Ok(GraphName::None)
  }
}

///|
fn[E] SliceParser::validate(
  self : SliceParser[E],
  pending : PendingQuad,
) -> Result[QuadSpan, ParserError] {
  // 提取 span 并切分 data
  let (subj_off, subj_len) = pending.subj
  let (pred_off, pred_len) = pending.pred
  let (obj_off, obj_len) = pending.obj

  // 边界检查
  if subj_off < 0 || subj_off + subj_len > self.data.length() {
    return Err(ParserError::SyntaxErr("Invalid subject span", pending.subj))
  }
  if pred_off < 0 || pred_off + pred_len > self.data.length() {
    return Err(ParserError::SyntaxErr("Invalid predicate span", pending.pred))
  }
  if obj_off < 0 || obj_off + obj_len > self.data.length() {
    return Err(ParserError::SyntaxErr("Invalid object span", pending.obj))
  }

  let subject = self.data[subj_off:subj_off + subj_len]
  let predicate = self.data[pred_off:pred_off + pred_len]
  let object = self.data[obj_off:obj_off + obj_len]

  // 检测主语和宾语的类型
  let subj_type = if subject[0] == b'_' {
    TermType::BNode
  } else {
    TermType::Iri
  }

  let obj_type = if object[0] == b'_' {
    TermType::BNode
  } else if object[0] == b'"' {
    TermType::Literal
  } else {
    TermType::Iri
  }
  // 严格模式：验证 IRI 格式
  if !self.lenient {
    // 验证 IRI
    if subj_type == TermType::Iri {
      match validate_iri(subject) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    if obj_type == TermType::Iri {
      match validate_iri(object) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    // 验证 BlankNode
    if subj_type == TermType::BNode {
      match validate_bnode(subject) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    if obj_type == TermType::BNode {
      match validate_bnode(object) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
  }
  // 图名
  let (g_off, g_len) = pending.graph

  let graph = if !pending.has_err ||
    (g_off >= 0 && g_off + g_len <= self.data.length()) {
    Some(self.data[g_off:g_off + g_len])
  } else {
    return Err(ParserError::SyntaxErr("Invalid graph span", pending.graph))
  }

  Ok({
    subj: subject,
    pred: predicate,
    obj: object,
    graph,
    line: pending.line,
    subj_type,
    obj_type,
    has_err: pending.has_err,
  })
}

///|
/// IRI 验证
fn validate_iri(iri : ArrayView[Byte]) -> Result[Unit, ParserError] {
  let len = iri.length()

  if len < 2 || iri[0] != b'<' || iri[len - 1] != b'>' {
    return Err(ParserError::SyntaxErr("IRI must be wrapped in <>", (0, len)))
  }

  if len == 2 {
    return Err(ParserError::SyntaxErr("IRI cannot be empty", (0, len)))
  }

  // 可选：验证协议
  let inner = iri[1:len - 1]
  let first = inner[0]

  if !(first == b'h' || first == b'f' || first == b'm' || first == b'/') {
    return Err(
      ParserError::SyntaxErr(
        "IRI must start with http://, https://, or ftp://",
        (1, inner.length()),
      ),
    )
  }

  Ok(())
}

///|
/// BNode 验证
fn validate_bnode(bnode : ArrayView[Byte]) -> Result[Unit, ParserError] {
  let len = bnode.length()

  if len < 3 || bnode[0] != b'_' || bnode[1] != b':' {
    return Err(
      ParserError::SyntaxErr("Blank node must start with _:", (0, len)),
    )
  }

  let first = bnode[2]
  if !((first >= b'a' && first <= b'z') ||
    (first >= b'A' && first <= b'Z') ||
    first == b'_') {
    return Err(
      ParserError::SyntaxErr(
        "Blank node label must start with letter or underscore",
        (2, 1),
      ),
    )
  }

  Ok(())
}
