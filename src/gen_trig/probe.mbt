// ===== 用户部分：测试驱动面（probe）=====
// P4.2（2026-09-14）：给跨包 quicktest 一个**窄入口**——喂一个 TrigEvent，回一档归一化响应。
//
// 为什么不是"把 internals 全开 pub"：trig 的 Context/Effect 传递依赖用户层类型
// （SlotType/Slot/PredKind），全开面既污染公共面、又会让 public-depends-on-private 复现。
// 本 probe 复用**引擎真件**（`TrigActionsImpl` + handler 钩子 + `interpret`），
// 只暴露一对入出类型 + 两个方法：
//   pub(all) enum TrigProbeResponse { Continue | EmitQuad(TrigPendingQuad) | Done | Failed(TrigActionError) }
//   pub struct TrigProbe { priv … }   /  pub fn TrigProbe::new() / pub fn TrigProbe::step(event)
//
// 与引擎主循环（`TrigEngine::next`）同机械的三点，缺一不可：
//   ① 队列优先排空（Sequence 内多条 EmitQuad 逐条回吐）；
//   ② `step` 后走 `interpret`（效果语义唯一解释器，T11 口径）；
//   ③ handler 钩子委托真 Actions（壳旗/收口旗结算在 snapshot 覆盖里）。

///|
/// probe 响应：只有四档（快照即"这一次 step 产出的 pending quad"）
pub(all) enum TrigProbeResponse {
  Continue
  EmitQuad(TrigPendingQuad)
  Done
  Failed(TrigActionError) // 错误原样上抛，归一化（错误码）由适配层负责
}

///|
/// probe 的 handler：钩子与 `impl TrigEffectHandler for TrigEngine` 同构（薄委托真 Actions）
priv struct TrigProbeHandler {
  actions : TrigActionsImpl
  ctx : TrigContext
}

///|
impl TrigEffectHandler for TrigProbeHandler with fn snapshot(
  _self : TrigProbeHandler,
  ctx : TrigContext,
) -> TrigPendingQuad {
  // 与引擎覆盖一致：壳旗结算 + 收口旗消费
  let pending = ctx.settle_shell(ctx.snapshot())
  ctx.settle_annotation()
  pending
}

///|
impl TrigEffectHandler for TrigProbeHandler with fn on_exit_graph(
  self : TrigProbeHandler,
) -> Unit {
  let _ = TrigActions::exit_graph(self.actions, self.ctx)
}

///|
impl TrigEffectHandler for TrigProbeHandler with fn on_pop_bnp(
  self : TrigProbeHandler,
  ctx : TrigContext,
) -> Unit {
  let _ = TrigActions::pop_bnode_prop(self.actions, ctx)
}

///|
impl TrigEffectHandler for TrigProbeHandler with fn on_list_step(
  self : TrigProbeHandler,
  ctx : TrigContext,
  elem : Span,
) -> Unit {
  let _ = TrigActions::list_step(self.actions, ctx, elem)
}

///|
impl TrigEffectHandler for TrigProbeHandler with fn on_open_slot(
  self : TrigProbeHandler,
  ctx : TrigContext,
  span : Span,
  typ : SlotType,
  ret_state : TrigState,
) -> Unit {
  let _ = TrigActions::open_slot(self.actions, ctx, span, typ, ret_state)
}

///|
/// 测试驱动把手：持有 ctx（状态跨事件保持）+ handler（真 Actions + 真 interpret）
pub struct TrigProbe {
  priv ctx : TrigContext
  priv handler : TrigProbeHandler
}

///|
pub fn TrigProbe::new() -> TrigProbe {
  let ctx = TrigContext::new()
  { ctx, handler: { actions: TrigActionsImpl::new(), ctx, } }
}

///|
/// 单步驱动：喂一个事件 → 一档响应（队列排空 / step / interpret 三步与引擎同序）
pub fn TrigProbe::step(
  self : TrigProbe,
  event : TrigEvent,
) -> TrigProbeResponse {
  if self.ctx.emit_queue.length() > 0 {
    return EmitQuad(self.ctx.emit_queue.remove(0))
  }
  match step(self.ctx, event, self.handler.actions) {
    Ok(effect) =>
      match TrigEffectHandler::interpret(self.handler, self.ctx, effect) {
        KeepGoing => Continue
        YieldQuad(quad) => EmitQuad(quad)
        Stop => Done
      }
    Err(error) => Failed(error)
  }
}

///|
/// 冒烟：一条完整语句 Iri Iri Iri Dot ⇒ Continue ×3 + EmitQuad（四槽齐全）
test "probe: 事件驱动一条三元组" {
  let probe = TrigProbe::new()
  let subject = TrigEvent::TrigIri((0, 3))
  let predicate = TrigEvent::TrigIri((4, 3))
  let object_ = TrigEvent::TrigIri((8, 3))
  assert_true(probe.step(subject) is Continue)
  assert_true(probe.step(predicate) is Continue)
  assert_true(probe.step(object_) is Continue)
  match probe.step(TrigEvent::TrigDot) {
    EmitQuad(quad) => {
      assert_true(quad.subj is Some(_))
      assert_true(quad.pred is Some(_))
      assert_true(quad.obj is Some(_))
      assert_true(quad.graph is None)
    }
    _ => assert_true(false)
  }
  // 未定义转移：ExpectSubject 位喂 Dot ⇒ UnexpectedEvent（错误原样上抛）
  match probe.step(TrigEvent::TrigDot) {
    Failed(TrigActionError::UnexpectedEvent(_, _)) => ()
    _ => assert_true(false)
  }
}
