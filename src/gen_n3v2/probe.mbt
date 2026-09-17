// ===== 用户部分：测试驱动面（probe）=====
// P5.2（2026-09-17）：给跨包 quicktest 一个**窄入口**——喂一个 N3Event，回一档归一化响应。
// 照 trig TrigProbe 复刻（P4.2 同构），三处 n3 化裁剪（P5.1 面清单定案）：
//   ① handler 只覆盖 `on_pop_bnp` + `on_open_slot` 两钩子（n3 无 exit_graph/list_step；
//      引擎覆盖面 engine.mbt:554/:563 同款）；
//   ② **snapshot 无需覆盖**——发射快照走 `take_pending`（engine.mbt:517），壳交换/倒装
//      交换/注解结算三件已内置，interpret 默认体直调；
//   ③ 面最小化：只开 `new`/`step_all`——trig 的 `step`（吞事件旧口径）与 `state`/
//      `stack_view`（P4.2e/h 量测遗产，quicktest 零引用）不开；`step_once` 为内部件。
//
// 与引擎主循环（`N3Engine::next`）同机械的三点，缺一不可：
//   ① 队列优先排空（Sequence 多发逐条回吐——役18 path_obj_close 三发真实存在）；
//   ② `step` 后走 `interpret`（效果语义唯一解释器，役22 口径）；
//   ③ handler 钩子委托真 Actions（PopBnp/OpenSlot 兑现机械全在 action）。

///|
/// probe 响应：只有四档（快照即"这一次 step 产出的 pending quad"）
pub(all) enum N3ProbeResponse {
  Continue
  EmitQuad(N3PendingQuad)
  Done
  Failed(N3ActionError) // 错误原样上抛，归一化（错误码）由适配层负责
}

///|
/// probe 的 handler：checkpoints 与引擎同构（薄委托真 Actions）——ctx 由参数入钩子，不存储
priv struct N3ProbeHandler {
  actions : N3ActionsImpl
}

///|
impl N3EffectHandler for N3ProbeHandler with fn on_pop_bnp(
  self : N3ProbeHandler,
  ctx : N3Context,
) -> Unit {
  let _ = N3Actions::pop_bnode_prop(self.actions, ctx)
}

///|
impl N3EffectHandler for N3ProbeHandler with fn on_open_slot(
  self : N3ProbeHandler,
  ctx : N3Context,
  span : Span,
  typ : SlotType,
  ret_state : N3State,
) -> Unit {
  let _ = N3Actions::open_slot(self.actions, ctx, span, typ, ret_state)
}

///|
/// 测试驱动把手：持有 ctx（状态跨事件保持）+ handler（真 Actions + 真 interpret）
pub struct N3Probe {
  priv ctx : N3Context
  priv handler : N3ProbeHandler
}

///|
pub fn N3Probe::new() -> N3Probe {
  let ctx = N3Context::new()
  { ctx, handler: { actions: N3ActionsImpl::new(), }, }
}

///|
/// 单步驱动（**忽略发射队列**，内部件）：喂一个事件 → 一档响应（step / interpret 同引擎同序）。
/// `Sequence` 内的余量入 `ctx.emit_queue`（step_all 收尾排空）。
fn N3Probe::step_once(self : N3Probe, event : N3Event) -> N3ProbeResponse {
  match step(self.ctx, event, self.handler.actions) {
    Ok(effect) =>
      match N3EffectHandler::interpret(self.handler, self.ctx, effect) {
        KeepGoing => Continue
        YieldQuad(quad) => EmitQuad(quad)
        Stop => Done
      }
    Err(error) => Failed(error)
  }
}

///|
/// 一条命令的**完整响应批**（P4.2h ③ 同口径）：先排空残留 ⇒ 处理本事件 ⇒ 再收本事件的余量。
/// 三条口径：
///   ① 批内顺序 = **引擎发射顺序**（`Sequence` 书写顺序；入队即快照 + FIFO）；
///   ② **不吞入参事件**——队列排空不消费事件（引擎 pull 循环"事件流不丢不重"），
///      故 `step_all` 是"一条命令 ↔ 它自己的响应"的正确映射；
///   ③ 排空前置只是防御（正常调用下进批时队列为空）——与引擎 loop 顶部同形。
pub fn N3Probe::step_all(
  self : N3Probe,
  event : N3Event,
) -> Array[N3ProbeResponse] {
  let responses : Array[N3ProbeResponse] = []
  while self.ctx.emit_queue.length() > 0 {
    responses.push(EmitQuad(self.ctx.emit_queue.remove(0)))
  }
  responses.push(self.step_once(event))
  while self.ctx.emit_queue.length() > 0 {
    responses.push(EmitQuad(self.ctx.emit_queue.remove(0)))
  }
  responses
}

///|
/// 钉子①：一条完整语句 Iri Iri Iri Dot ⇒ Continue ×3 + EmitQuad（三槽齐、g 恒缺——
/// N3 无图块口径）；随后未定义转移（ExpectSubject 位喂 Dot）⇒ Failed 原样上抛。
test "probe: 事件驱动一条三元组" {
  let probe = N3Probe::new()
  let subject = N3Event::N3Iri((0, 3))
  let predicate = N3Event::N3Iri((4, 3))
  let object_ = N3Event::N3Iri((8, 3))
  let b1 = probe.step_all(subject)
  assert_eq(b1.length(), 1)
  assert_true(b1[0] is Continue)
  let b2 = probe.step_all(predicate)
  assert_eq(b2.length(), 1)
  assert_true(b2[0] is Continue)
  let b3 = probe.step_all(object_)
  assert_eq(b3.length(), 1)
  assert_true(b3[0] is Continue)
  match probe.step_all(N3Event::N3Dot)[0] {
    EmitQuad(quad) => {
      assert_eq(quad.subj, Some((0, 3)))
      assert_eq(quad.pred, Some((4, 3)))
      assert_eq(quad.obj, Some((8, 3)))
      assert_true(quad.graph is None)
    }
    _ => assert_true(false)
  }
  // 未定义转移：ExpectSubject 位喂 Dot ⇒ UnexpectedEvent（错误原样上抛）
  match probe.step_all(N3Event::N3Dot)[0] {
    Failed(N3ActionError::UnexpectedEvent(_, _)) => ()
    _ => assert_true(false)
  }
}

///|
/// 钉子②：宾位尾随路径多发射 → `step_all` **有序批**（一条命令 → 它自己的响应，
/// 不吞入参事件）。`:a :p :o !q .`——Bang 入帧（path_obj_trail）、PrefName 押步、
/// Dot 收口 = path_obj_close 三意图 `[EmitQuad(SPO), PopBnp, EmitQuad(SPO)]`
/// （役18 三发真实存在）：批内两枚按书写序 = 跳边 (o,q,尾) → pop 落位后的外层语句
/// (a,p,尾)（帧 open_span 改指尾、ret_state=ExpectSubject，Dot 行 to 态）。
test "probe: step_all 一条命令 → 有序响应批（path_obj_close 三发）" {
  let probe = N3Probe::new()
  assert_true(probe.step_all(N3Event::N3Iri((0, 2)))[0] is Continue) // :a
  assert_true(probe.step_all(N3Event::N3PrefName((3, 2)))[0] is Continue) // :p
  assert_true(probe.step_all(N3Event::N3Iri((6, 2)))[0] is Continue) // :o
  // Bang：入帧立链账（ExpectDotOrGraph + Bang → path_obj_trail），零发射
  assert_true(probe.step_all(N3Event::N3Bang((9, 1)))[0] is Continue)
  // PrefName：押步入账（ObjTrailExpectVerb + PrefName → path_step），零发射
  assert_true(probe.step_all(N3Event::N3PrefName((11, 2)))[0] is Continue)
  // Dot：三意图一发两枚——批内序 = Sequence 书写序
  let batch = probe.step_all(N3Event::N3Dot)
  assert_eq(batch.length(), 2)
  match batch[0] {
    EmitQuad(quad) => {
      // 第一枚：终跳边 (o, q, 尾=Bang span 9)
      assert_eq(quad.subj, Some((6, 2)))
      assert_eq(quad.pred, Some((11, 2)))
      assert_eq(quad.obj, Some((9, 1)))
    }
    _ => assert_true(false)
  }
  match batch[1] {
    EmitQuad(quad) => {
      // 第二枚：pop 落位后的外层语句 (a, p, 尾)——g 恒缺
      assert_eq(quad.subj, Some((0, 2)))
      assert_eq(quad.pred, Some((3, 2)))
      assert_eq(quad.obj, Some((9, 1)))
      assert_true(quad.graph is None)
    }
    _ => assert_true(false)
  }
}
