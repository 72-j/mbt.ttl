///|
/// 物化 Quad（批量优化）
pub fn materialize_quad(
  quad : QuadSpan,
  // data : ArrayView[Byte],
) -> Result[QuadEmit, ParseError] {

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
  Ok({ subject, predicate, object, graph })
}

///|
/// 批量物化（优化：减少函数调用开销）
pub fn materialize_all(
  quads : Array[QuadSpan],
  // data : ArrayView[Byte],
) -> (Array[QuadEmit], Array[ParseError]) {
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
) -> Result[Subject, ParseError] {
  match t {
    TermType::Iri => Ok(Subject::Iri(subject))
    TermType::BNode => Ok(Subject::BNode(subject))
    TermType::PrefName =>
      Err(ParseError::ValidationErr("N-Quads does not support prefixed names"))
    TermType::Literal =>
      Err(ParseError::ValidationErr("Subject cannot be literal"))
    TermType::Unknown => Err(ParseError::ValidationErr("Invalid subject"))
  }
}

///|
fn materialize_object(
  object : ArrayView[Byte],
  t : TermType,
) -> Result[Object, ParseError] {
  match t {
    TermType::Iri => Ok(Object::Iri(object))
    TermType::BNode => Ok(Object::BNode(object))
    TermType::Literal => Ok(Object::Literal(object))
    TermType::PrefName =>
      Err(ParseError::ValidationErr("N-Quads does not support prefixed names"))
    TermType::Unknown => Err(ParseError::ValidationErr("Invalid object"))
  }
}

///|
fn materialize_predicate(
  predicate : ArrayView[Byte],
) -> Result[Predicate, ParseError] {
  // 谓语必须是 IRI，这里只做基本验证
  Ok(predicate)
}

///|
fn materialize_graph_name(
  graph : ArrayView[Byte]?,
) -> Result[GraphName, ParseError] {
  match graph {
    Some(g) => Ok(GraphName::Iri(g))
    None => Ok(GraphName::None)
  }
}
