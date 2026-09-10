// ========================================
// Model Exec — 纯模型执行器（目标形状 = 生成器产物 model_exec.mbt）
// model_execute 是规格（specification），不是被测实现：
// 臂结构与 [[transitions]] 一一对应；纯模型与真实引擎的语义漂移
// 由属性测试的双执行比较兜底（postcondition，见 nquads_quicktest.mbt）。
// ========================================

///|
/// 发射四元组所需的槽位检查（EmitQuad 前置）
fn quad_ready(model : Model) -> Bool {
  model.subject is Some(_) &&
  model.predicate is Some(_) &&
  model.object is Some(_)
}

///|
/// 从槽位取出四元组（调用前 quad_ready 必须为真）
fn take_quad(model : Model) -> Quad {
  {
    subject: model.subject.unwrap(),
    predicate: model.predicate.unwrap(),
    object: model.object.unwrap(),
    graph: model.graph,
  }
}

///|
/// 纯模型执行: (Model, Command) -> (Model, Response)
/// 兜底 (_, _) => Error(0) 对应引擎的 UnexpectedEvent（未定义转移）
fn model_execute(model : Model, cmd : Command) -> (Model, Response) {
  match (model.state, cmd) {
    // --- ExpectSubject ---
    (ExpectSubject, Iri(reference)) => (set_subject(model, reference), Continue)
    (ExpectSubject, BlankNode(reference)) =>
      (set_subject(model, reference), Continue)
    // --- ExpectPredicate ---
    (ExpectPredicate, Iri(reference)) =>
      (set_predicate(model, reference), Continue)
    // --- ExpectObject ---
    (ExpectObject, Iri(reference)) => (set_object(model, reference), Continue)
    (ExpectObject, BlankNode(reference)) =>
      (set_object(model, reference), Continue)
    (ExpectObject, Literal(reference)) =>
      (set_object(model, reference), Continue)
    (ExpectObject, TripleTerm(reference)) =>
      (set_object(model, reference), Continue)
    // --- ExpectDotOrGraph ---
    (ExpectDotOrGraph, Iri(reference)) =>
      (set_graph(model, reference), Continue)
    (ExpectDotOrGraph, BlankNode(reference)) =>
      (set_graph(model, reference), Continue)
    (ExpectDotOrGraph, Dot) => emit_all(model, ExpectSubject)
    (ExpectDotOrGraph, Comma) => emit_object(model, ExpectObject)
    (ExpectDotOrGraph, Semicolon) => emit_predobj(model, ExpectPredicate)
    (ExpectDotOrGraph, Unknown) => emit_all(model, ExpectSubject)
    // --- ExpectDot ---
    (ExpectDot, Dot) => emit_all(model, ExpectSubject)
    // 兜底: 非法转移（valid 已过滤，防御性保留）
    (_, _) => (model, Error(0))
  }
}

///|
/// 槽位更新辅助: subject（引擎 action set_subject）
fn set_subject(model : Model, reference : @qcs.Ref[RefId]) -> Model {
  // 符号期引用无法解析具体值：槽位保持，状态照常推进
  let subject = match ref_id(reference) {
    Some(id) => Some(id)
    None => model.subject
  }
  { ..model, state: ExpectPredicate, subject, }
}

///|
/// 槽位更新辅助: predicate（引擎 action set_predicate）
fn set_predicate(model : Model, reference : @qcs.Ref[RefId]) -> Model {
  let predicate = match ref_id(reference) {
    Some(id) => Some(id)
    None => model.predicate
  }
  { ..model, state: ExpectObject, predicate, }
}

///|
/// 槽位更新辅助: object（引擎 action set_object）
fn set_object(model : Model, reference : @qcs.Ref[RefId]) -> Model {
  let object = match ref_id(reference) {
    Some(id) => Some(id)
    None => model.object
  }
  { ..model, state: ExpectDotOrGraph, object, }
}

///|
/// 槽位更新辅助: graph（引擎 action set_graph）
fn set_graph(model : Model, reference : @qcs.Ref[RefId]) -> Model {
  let graph = match ref_id(reference) {
    Some(id) => Some(id)
    None => model.graph
  }
  { ..model, state: ExpectDot, graph, }
}

///|
/// 发射四元组: 槽位齐全 → EmitQuad 并按 All 清槽（引擎 ResetScope::All）
fn emit_all(model : Model, to : ModelState) -> (Model, Response) {
  if quad_ready(model) {
    let quad = take_quad(model)
    (
      { state: to, subject: None, predicate: None, object: None, graph: None, },
      EmitQuad(quad),
    )
  } else {
    (model, Error(1)) // 不完整三元组
  }
}

///|
/// 发射四元组: 槽位齐全 → EmitQuad 并按 Object 清槽（引擎 ResetScope::Object）
fn emit_object(model : Model, to : ModelState) -> (Model, Response) {
  if quad_ready(model) {
    let quad = take_quad(model)
    ({ ..model, state: to, object: None, }, EmitQuad(quad))
  } else {
    (model, Error(1))
  }
}

///|
/// 发射四元组: 槽位齐全 → EmitQuad 并按 PredObj 清槽（引擎 ResetScope::PredObj）
fn emit_predobj(model : Model, to : ModelState) -> (Model, Response) {
  if quad_ready(model) {
    let quad = take_quad(model)
    ({ ..model, state: to, predicate: None, object: None, }, EmitQuad(quad))
  } else {
    (model, Error(1))
  }
}

///|
/// 模型推进（quickcheck_statemachine transition_symbolic/concrete 接口形态）
/// 非法/错误响应不推进模型
fn transition(model : Model, command : Command, response : Response) -> Model {
  match response {
    Error(_) => model
    _ => model_execute(model, command).0
  }
}

///|
test "nquads quick machine model oracle" {
  // Iri(p) Iri(o) Iri(g) Dot -> 一条默认图三元组 + 一条带图名四元组
  let mut model = model_empty()
  let script : Array[Command] = [
    Iri(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Literal(Concrete({ id: 3, })),
    Dot,
    Iri(Concrete({ id: 4, })),
    Iri(Concrete({ id: 5, })),
    Iri(Concrete({ id: 6, })),
    Iri(Concrete({ id: 7, })),
    Dot,
  ]
  let emitted : Array[Quad] = []
  for command in script {
    let (next_model, response) = model_execute(model, command)
    match response {
      EmitQuad(quad) => emitted.push(quad)
      _ => ()
    }
    model = next_model
  }
  assert_eq(emitted.length(), 2)
  assert_eq(emitted[0], {
    subject: { id: 1, },
    predicate: { id: 2, },
    object: { id: 3, },
    graph: None,
  })
  assert_eq(emitted[1], {
    subject: { id: 4, },
    predicate: { id: 5, },
    object: { id: 6, },
    graph: Some({ id: 7, }),
  })
  // 非法转移：模型不推进且报 Error(0)
  let (after_error, response) = model_execute(
    model,
    Literal(Concrete({ id: 8, })),
  )
  assert_eq(response, Error(0))
  assert_eq(after_error, model)
}
