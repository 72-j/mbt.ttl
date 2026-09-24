///|
/// 物化 Quad（P3 平化：类型已由 validate 探测，此处纯标注搬运——view 零拷贝。
/// kind 轴零箱（常量 tag），QuadEmit 本体 = 每 quad 唯一箱；错误臂只留主语位防御钉）
fn materialize_quad(quad : QuadSpan) -> Result[QuadEmit, ParseError] {
  // 谓语必须是 IRI——校验已在 validate_helper（严格模式）完成，物化层只搬运
  let s_kind : TermKind = match quad.subj_type {
    TermType::Iri => TermKind::Iri
    TermType::BNode => TermKind::BNode
    TermType::Literal =>
      return Err(ParseError::ValidationErr("Subject cannot be literal"))
    // 表只开宾语位 TripleTerm，主语位不可达；防御性报错钉住不变量
    TermType::TripleTerm =>
      return Err(ParseError::ValidationErr("Subject cannot be triple term"))
  }
  let o_kind : TermKind = match quad.obj_type {
    TermType::Iri => TermKind::Iri
    TermType::BNode => TermKind::BNode
    TermType::Literal => TermKind::Literal
    // 整段 span 原文持有：<<( ... )>> 字节保真，不递归拆解（拆解属下游语义层）
    TermType::TripleTerm => TermKind::TripleTerm
  }
  // 图名位：首字节探测（与 subj/obj 同一规则：`_`→BNode，否则 Iri）；
  // 缺省 = DefaultGraph 单例（g_view 取空视图占位，消费侧按 kind 门控不读）
  let g_kind : TermKind = if quad.graph is Some(g) {
    if g[0] == b'_' {
      TermKind::BNode
    } else {
      TermKind::Iri
    }
  } else {
    TermKind::DefaultGraph
  }
  let g_view : ArrayView[Byte] = if quad.graph is Some(g) {
    g
  } else {
    quad.pred[0:0]
  }
  Ok({
    s_kind,
    s_view: quad.subj,
    predicate: quad.pred,
    o_kind,
    o_view: quad.obj,
    g_kind,
    g_view,
  })
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
  assert_true(emits[0].g_kind is TermKind::BNode)
  assert_true(emits[1].g_kind is TermKind::DefaultGraph)
  // 全链路：序列化回原文，字节一致
  let s = Serializer::new(format=Quad)
  match s.serialize_all(emits) {
    Ok(out) => assert_eq(out, input)
    Err(_) => assert_true(false)
  }
}
