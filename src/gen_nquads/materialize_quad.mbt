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
  Ok({ subject, predicate, object, graph, })
}

///|
/// 批量物化：逐条搬运，错误逐条收集（与 parse_all 同口径）
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
    TermType::Literal =>
      Err(ParseError::ValidationErr("Subject cannot be literal"))
    // 表只开宾语位 TripleTerm，主语位不可达；防御性报错钉住不变量
    TermType::TripleTerm =>
      Err(ParseError::ValidationErr("Subject cannot be triple term"))
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
    // 整段 span 原文持有：<<( ... )>> 字节保真，不递归拆解（拆解属下游语义层）
    TermType::TripleTerm => Ok(Object::TripleTerm(object))
  }
}

///|
fn materialize_predicate(
  predicate : ArrayView[Byte],
) -> Result[Predicate, ParseError] {
  // 谓语必须是 IRI——校验已在 validate_helper（严格模式）完成，物化层只搬运
  Ok(predicate)
}

///|
fn materialize_graph_name(
  graph : ArrayView[Byte]?,
) -> Result[GraphName, ParseError] {
  match graph {
    Some(g) =>
      // 首字节探测（与 subj/obj 同一规则：`_`→BNode，否则 Iri）
      if g[0] == b'_' {
        Ok(GraphName::BNode(g))
      } else {
        Ok(GraphName::Iri(g))
      }
    None => Ok(GraphName::None)
  }
}

///|
test "物化: bnode 图名如实标注 + 全链路往返" {
  let input = "<http://e.org/s> <http://e.org/p> <http://e.org/o> _:g .\n<http://e.org/s2> <http://e.org/p2> \"中文\" .\n"
  let data = @utf8.encode(input).to_array()
  let (quads, errors) = nquads_parser(data)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  let (emits, merrs) = materialize_all(quads)
  assert_eq(merrs.length(), 0)
  assert_eq(emits.length(), 2)
  // bnode 图名 → BNode（模型不再谎报 Iri）
  assert_true(emits[0].graph is GraphName::BNode(_))
  assert_true(emits[1].graph is GraphName::None)
  // 全链路：序列化回原文，字节一致
  let s = Serializer::new(format=Quad)
  match s.serialize_all(emits) {
    Ok(out) => assert_eq(out, input)
    Err(_) => assert_true(false)
  }
}
