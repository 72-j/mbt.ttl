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
  { ctx, handler: { actions: TrigActionsImpl::new(), ctx, }, }
}

///|
/// 当前引擎状态（P4.2e：逐步对照"引擎状态 ⟺ 模型状态"用）
pub fn TrigProbe::state(self : TrigProbe) -> TrigState {
  self.ctx.state
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

///|
/// P4.2h 前提钉子：**多发射回吐顺序确定性**（③ 改 harness 返 `Array[Response]` 的生死前提）。
/// 引擎事实（`trig.mbt:1334` 的 `Sequence` 分支 + `engine.mbt:368` 的 loop 顶部排空）：
///   ① `Sequence` 逐条 `ctx.emit_queue.push(ctx.snapshot())` ⇒ **入队即快照**（后续 ctx 变更不回头改写）；
///   ② 排空用 `remove(0)` ⇒ **FIFO**，回吐顺序 = Sequence 书写顺序；
///   ③ 队首与本步 `YieldQuad` 同源 ⇒ "本步即时响应 + 队列余量"拼起来仍是书写顺序，**无重排**。
/// 同时钉住一条**必须消掉的差异**：probe 的 `step(event)` 在排空时**吞掉入参事件**
/// （引擎的 pull 循环不会——事件来自 lexer，排空时不 pull 即"事件流不丢不重"）。
/// ⇒ ③ 落地时 probe 要改成"先排空、**再处理同一入参**"，一条命令 → `Array[Response]`。
test "probe: 多发射回吐顺序 = 书写顺序（FIFO + 入队即快照 + 排空吞事件）" {
  let probe = TrigProbe::new()
  // Lparen(0,1) 开集合帧 ⇒ Iri(2,1) list_first（单发射）⇒ Iri(4,1) list_next（序列两发射）
  match probe.step(TrigEvent::TrigLparen((0, 1))) {
    Continue => ()
    _ => assert_true(false)
  }
  match probe.step(TrigEvent::TrigIri((2, 1))) {
    EmitQuad(p) => {
      assert_eq(p.subj, Some((0, 1))) // list_first：subject = open_span
      assert_eq(p.obj, Some((2, 1))) // object = elem（载荷）
    }
    _ => assert_true(false)
  }
  // 第 3 步 = list_next 的**第一枚**（object = 合成节点 `(open_span.0, node_seq+1)`）
  match probe.step(TrigEvent::TrigIri((4, 1))) {
    EmitQuad(p) => {
      assert_eq(p.subj, Some((0, 1)))
      assert_eq(p.obj, Some((0, 2)))
    }
    _ => assert_true(false)
  }
  // 第 4 步喂 Rparen：返回的仍是**队列余量**（list_next 第二枚：ListStep 后的 subject/object）
  // ⇒ 顺序确定（FIFO）+ 入队即快照（两枚值不同）；**但入参 Rparen 被吞**（下面第 5 步才轮到它）
  match probe.step(TrigEvent::TrigRparen) {
    EmitQuad(p) => {
      assert_eq(p.subj, Some((0, 2)))
      assert_eq(p.obj, Some((4, 1)))
    }
    _ => assert_true(false)
  }
  // 第 5 步再喂 Rparen：这次才真正处理（list_nil ⇒ 发射空表节点）
  match probe.step(TrigEvent::TrigRparen) {
    EmitQuad(p) => assert_eq(p.obj, Some((0, 0))) // 空表 `(open_span.0, 0)` ⇒ RefId = open_span.0
    _ => assert_true(false)
  }
}
