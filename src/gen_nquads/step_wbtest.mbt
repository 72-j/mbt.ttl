// ===== FSM 状态机单测（与词法器/引擎完全解耦） =====
// 只驱动生成的 step()：合成事件序列 → 断言状态转移、Effect 意图与槽位写入。
// 发射后的粒度重置由测试方按 loop 口径显式调用 ctx.reset(scope)，
// 借此同时验证 ResetScope 的"保留字段"语义（防错误重置）。

///|
/// 常用事件构造捷径
fn ev_iri(off : Int) -> NQuadsEvent {
  NQuadsEvent::NQuadsIri((off, 5))
}

///|
fn ev_bnode(off : Int) -> NQuadsEvent {
  NQuadsEvent::NQuadsBlankNode((off, 4))
}

///|
fn ev_lit(off : Int) -> NQuadsEvent {
  NQuadsEvent::NQuadsLiteral((off, 7))
}

///|
test "step: 单行 IRI 四元组 —— 主流转与发射意图" {
  let ctx = NQuadsContext::new()
  let h = Hooks::new()
  // <s> <p> <o> .
  match step(ctx, ev_iri(0), h) {
    Ok(NQuadsEffect::Continue) => ()
    _ => fail("expect Continue")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectPredicate)
  assert_true(ctx.subject is Some(_))
  match step(ctx, ev_iri(30), h) {
    Ok(NQuadsEffect::Continue) => ()
    _ => fail("expect Continue")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectObject)
  match step(ctx, ev_iri(60), h) {
    Ok(NQuadsEffect::Continue) => ()
    _ => fail("expect Continue")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectDotOrGraph)
  match step(ctx, NQuadsEvent::NQuadsDot, h) {
    Ok(NQuadsEffect::EmitQuad(ResetScope::All)) => ()
    _ => fail("expect EmitQuad(All)")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectSubject)
}

///|
test "step: bnode 主语 / literal 宾语路径" {
  let ctx = NQuadsContext::new()
  let h = Hooks::new()
  match step(ctx, ev_bnode(0), h) {
    Ok(NQuadsEffect::Continue) => ()
    _ => fail("expect Continue")
  }
  match step(ctx, ev_iri(20), h) {
    Ok(NQuadsEffect::Continue) => ()
    _ => fail("expect Continue")
  }
  match step(ctx, ev_lit(40), h) {
    Ok(NQuadsEffect::Continue) => ()
    _ => fail("expect Continue")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectDotOrGraph)
  assert_true(ctx.object is Some(_))
}

///|
test "step: graph 四元组 —— 图名转移 + ExpectDot 收口" {
  let ctx = NQuadsContext::new()
  let h = Hooks::new()
  let _ = step(ctx, ev_iri(0), h)
  let _ = step(ctx, ev_iri(30), h)
  let _ = step(ctx, ev_iri(60), h)
  // 第四个 Iri：图名
  match step(ctx, ev_iri(90), h) {
    Ok(NQuadsEffect::Continue) => ()
    _ => fail("graph Iri 应走 set_graph 并 Continue")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectDot)
  assert_true(ctx.graph is Some(_))
  match step(ctx, NQuadsEvent::NQuadsDot, h) {
    Ok(NQuadsEffect::EmitQuad(ResetScope::All)) => ()
    _ => fail("expect EmitQuad(All)")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectSubject)
}

///|
test "step: 逗号 = 发射 + 最小重置（保留 subject/predicate）" {
  let ctx = NQuadsContext::new()
  let h = Hooks::new()
  let _ = step(ctx, ev_iri(0), h)
  let _ = step(ctx, ev_iri(30), h)
  let _ = step(ctx, ev_iri(60), h)
  match step(ctx, NQuadsEvent::NQuadsComma, h) {
    Ok(NQuadsEffect::EmitQuad(ResetScope::Object)) => ()
    _ => fail("expect EmitQuad(Object)")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectObject)
  // 模拟 loop 的粒度重置，验证保留字段语义
  ctx.reset(ResetScope::Object)
  assert_true(ctx.subject is Some(_))
  assert_true(ctx.predicate is Some(_))
  assert_true(ctx.object is None)
}

///|
test "step: 分号 = 发射 + 中等重置（仅保留 subject）" {
  let ctx = NQuadsContext::new()
  let h = Hooks::new()
  let _ = step(ctx, ev_iri(0), h)
  let _ = step(ctx, ev_iri(30), h)
  let _ = step(ctx, ev_iri(60), h)
  match step(ctx, NQuadsEvent::NQuadsSemicolon, h) {
    Ok(NQuadsEffect::EmitQuad(ResetScope::PredObj)) => ()
    _ => fail("expect EmitQuad(PredObj)")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectPredicate)
  ctx.reset(ResetScope::PredObj)
  assert_true(ctx.subject is Some(_))
  assert_true(ctx.predicate is None)
  assert_true(ctx.object is None)
}

///|
test "step: Unknown 在宾语后宽容当句点" {
  let ctx = NQuadsContext::new()
  let h = Hooks::new()
  let _ = step(ctx, ev_iri(0), h)
  let _ = step(ctx, ev_iri(30), h)
  let _ = step(ctx, ev_iri(60), h)
  match step(ctx, NQuadsEvent::NQuadsUnknown, h) {
    Ok(NQuadsEffect::EmitQuad(ResetScope::All)) => ()
    _ => fail("expect EmitQuad(All)")
  }
  assert_true(ctx.state is NQuadsState::NQuadsExpectSubject)
}

///|
test "step: 非法组合一律 UnexpectedEvent" {
  let h = Hooks::new()
  let cases : Array[(NQuadsState, NQuadsEvent)] = [
    (NQuadsExpectSubject, NQuadsEvent::NQuadsDot),
    (NQuadsExpectSubject, NQuadsEvent::NQuadsComma),
    (NQuadsExpectPredicate, ev_bnode(0)),
    (NQuadsExpectPredicate, NQuadsEvent::NQuadsComma),
    (NQuadsExpectObject, NQuadsEvent::NQuadsDot),
    // (ExpectDotOrGraph, BlankNode) 已合法：bnode 可作图名（nq-syntax-bnode-01..06）
    (NQuadsExpectDot, NQuadsEvent::NQuadsComma),
  ]
  for c in cases {
    let ctx = NQuadsContext::new()
    ctx.state = c.0
    match step(ctx, c.1, h) {
      Err(NQuadsActionError::UnexpectedEvent(_, _)) => ()
      _ => fail("expect UnexpectedEvent")
    }
  }
}

///|
test "ctx: reset 保留字段矩阵与 has_pending" {
  let ctx = NQuadsContext::new()
  ctx.subject = Some((0, 1))
  ctx.predicate = Some((2, 1))
  ctx.object = Some((4, 1))
  ctx.graph = Some((6, 1))
  assert_true(ctx.has_pending())
  ctx.reset(ResetScope::Object)
  assert_true(ctx.graph is Some(_))
  ctx.reset(ResetScope::PredObj)
  assert_true(ctx.subject is Some(_))
  assert_true(ctx.predicate is None)
  ctx.reset(ResetScope::SPO)
  assert_true(ctx.graph is Some(_))
  assert_true(ctx.subject is None)
  assert_true(ctx.has_pending()) // graph 仍在
  ctx.reset(ResetScope::All)
  assert_false(ctx.has_pending())
}
