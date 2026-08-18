// ===== Model Executor - 纯模型执行器 =====
// quicktest.md 3.3: model_execute 是规格（specification），不是被测实现。
// 语义与 test_nquads.toml 转移表同源: 每个臂对应一条 [[transitions]] 规则。
// 纯模型与真实执行器（step）语义漂移 = 假阳性风险, 由属性测试双执行比较兜底。

///|
/// 构造完整三元组所需的槽位检查（EmitQuad 前置）
fn quad_ready(model : Model) -> Bool {
  model.subject is Some(_) &&
  model.predicate is Some(_) &&
  model.object is Some(_)
}

///|
/// 从槽位取出四元组（调用前 quad_ready 必须为真）
fn take_quad(model : Model) -> Quad {
  Quad::{
    subject: model.subject.unwrap(),
    predicate: model.predicate.unwrap(),
    object: model.object.unwrap(),
    graph: model.graph,
  }
}

///|
/// emit 后的模型: 进入 Complete 并清空槽位（下一条三元组从空槽开始）
fn after_emit(_model : Model) -> Model {
  { state: Complete, subject: None, predicate: None, object: None, graph: None }
}

///|
/// 纯模型执行: (Model, Command) -> (Model, Response)
/// 臂结构与转移表一一对应; 兜底 (_, _) => Error(0) 为非法转移
fn model_execute(model : Model, cmd : Command) -> (Model, Response) {
  match (model.state, cmd) {
    // --- ExpectSubject: 主语位 ---
    (ExpectSubject, Iri(r)) => (set_subject(model, r), Continue)
    (ExpectSubject, BlankNode(r)) => (set_subject(model, r), Continue)
    (ExpectSubject, PrefName(_)) => (model, SkipError)
    (ExpectSubject, Unknown) => (model, Continue)

    // --- ExpectPredicate: 谓语位（必须为 IRI）---
    (ExpectPredicate, Iri(r)) => (set_predicate(model, r), Continue)
    (ExpectPredicate, BlankNode(_)) => (model, SkipError)
    (ExpectPredicate, Literal(_)) => (model, SkipError)
    (ExpectPredicate, Dot) => (model, SkipError)

    // --- ExpectObject: 宾语位 ---
    (ExpectObject, Iri(r)) => (set_object(model, r), Continue)
    (ExpectObject, BlankNode(r)) => (set_object(model, r), Continue)
    (ExpectObject, Literal(r)) => (set_object(model, r), Continue)
    (ExpectObject, Dot) => (model, SkipError)

    // --- ExpectDotOrGraph: 收尾或图名 ---
    (ExpectDotOrGraph, Dot) => emit_or_error(model)
    (ExpectDotOrGraph, Iri(r)) => (set_graph(model, r), Continue)
    (ExpectDotOrGraph, PrefName(_)) => (model, SkipError)
    (ExpectDotOrGraph, Unknown) => emit_or_error(model)

    // --- ExpectDot: 图名之后必须收尾 ---
    (ExpectDot, Dot) => emit_or_error(model)
    (ExpectDot, Iri(_)) => (model, SkipError)

    // --- Complete: 下一条三元组或结束 ---
    (Complete, Iri(r)) => (set_subject(model, r), Continue)
    (Complete, BlankNode(r)) => (set_subject(model, r), Continue)
    (Complete, EOF) => (model, Done)

    // 兜底: 非法转移（valid 已过滤, 防御性保留）
    (_, _) => (model, Error(0))
  }
}

///|
/// 槽位更新辅助: 主语（进入谓语位）
fn set_subject(model : Model, r : @qcs.Ref[RefId]) -> Model {
  // 生成期 Symbolic 引用无法解析具体值: 槽位保持, 状态照常推进
  // （符号执行的值检查由 mock/transition 层承担）
  let subject = match ref_id(r) {
    Some(id) => Some(id)
    None => model.subject
  }
  { ..model, state: ExpectPredicate, subject }
}

///|
/// 槽位更新辅助: 谓语（进入宾语位）
fn set_predicate(model : Model, r : @qcs.Ref[RefId]) -> Model {
  let predicate = match ref_id(r) {
    Some(id) => Some(id)
    None => model.predicate
  }
  { ..model, state: ExpectObject, predicate }
}

///|
/// 槽位更新辅助: 宾语（进入点号/图名位）
fn set_object(model : Model, r : @qcs.Ref[RefId]) -> Model {
  let object = match ref_id(r) {
    Some(id) => Some(id)
    None => model.object
  }
  { ..model, state: ExpectDotOrGraph, object }
}

///|
/// 槽位更新辅助: 图名（进入图名后点号位）
fn set_graph(model : Model, r : @qcs.Ref[RefId]) -> Model {
  let graph = match ref_id(r) {
    Some(id) => Some(id)
    None => model.graph
  }
  { ..model, state: ExpectDot, graph }
}

///|
/// 发射四元组: 槽位齐全 → EmitQuad 并清空; 不齐 → Error(1)
fn emit_or_error(model : Model) -> (Model, Response) {
  if quad_ready(model) {
    (after_emit(model), EmitQuad(take_quad(model)))
  } else {
    (model, Error(1)) // 不完整三元组
  }
}

///|
/// 模型推进（quickcheck_statemachine transition_symbolic 接口形态）
/// 非法/错误响应不推进模型
fn transition(model : Model, command : Command, response : Response) -> Model {
  match response {
    Error(_) => model
    _ => model_execute(model, command).0
  }
}

///|
test {
  // 完整生命周期: s p o . → EmitQuad, 槽位清空, 进入 Complete
  let m0 = model_empty()
  let r = fn(id : Int) -> @qcs.Ref[RefId] { Concrete({ id, }) }
  let (m1, r1) = model_execute(m0, Iri(r(1)))
  assert_eq(r1, Continue)
  assert_eq(m1.state, ExpectPredicate)
  assert_eq(m1.subject, Some({ id: 1 }))

  let (m2, _) = model_execute(m1, Iri(r(2)))
  assert_eq(m2.state, ExpectObject)
  assert_eq(m2.predicate, Some({ id: 2 }))

  let (m3, _) = model_execute(m2, Literal(r(3)))
  assert_eq(m3.state, ExpectDotOrGraph)

  let (m4, r4) = model_execute(m3, Dot)
  assert_eq(
    r4,
    EmitQuad(Quad::{
      subject: { id: 1 },
      predicate: { id: 2 },
      object: { id: 3 },
      graph: None,
    }),
  )
  assert_eq(m4.state, Complete)
  assert_true(m4.subject is None) // 槽位清空
}

///|
test {
  // 谓语位非法词法: SkipError 且模型不动
  let m1 = { ..model_empty(), state: ExpectPredicate, subject: Some({ id: 1 }) }
  let (m2, resp) = model_execute(m1, Literal(Concrete({ id: 9 })))
  assert_eq(resp, SkipError)
  assert_eq(m2, m1) // 模型保持

  // 图名路径: ExpectDotOrGraph --Iri--> ExpectDot --Dot--> Complete
  let g0 = {
    ..model_empty(),
    state: ExpectDotOrGraph,
    subject: Some({ id: 1 }),
    predicate: Some({ id: 2 }),
    object: Some({ id: 3 }),
  }
  let (g1, gr1) = model_execute(g0, Iri(Concrete({ id: 4 })))
  assert_eq(gr1, Continue)
  assert_eq(g1.state, ExpectDot)
  assert_eq(g1.graph, Some({ id: 4 }))
  let (g2, gr2) = model_execute(g1, Dot)
  assert_eq(
    gr2,
    EmitQuad(Quad::{
      subject: { id: 1 },
      predicate: { id: 2 },
      object: { id: 3 },
      graph: Some({ id: 4 }),
    }),
  )
  assert_eq(g2.state, Complete)

  // EOF 收尾
  let (g3, gr3) = model_execute(g2, EOF)
  assert_eq(gr3, Done)
  assert_eq(g3.state, Complete)
}

///|
test {
  // 非法转移兜底 + transition 包装
  let m = model_empty()
  let (m_bad, resp_bad) = model_execute(m, EOF) // ExpectSubject 上 EOF 未定义
  assert_eq(resp_bad, Error(0))
  assert_eq(m_bad, m)

  // transition: 错误响应不推进
  let t_err = transition(m, EOF, Error(0))
  assert_eq(t_err, m)

  // transition: 正常推进
  let t_ok = transition(m, Iri(Concrete({ id: 1 })), Continue)
  assert_eq(t_ok.state, ExpectPredicate)
}
