// ===== 装配层（Assembly）：测试驱动面（probe）=====
// P5.2（2026-09-17）：给跨包 quicktest 一个**窄入口**——喂一个 N3Event，回一档归一化响应。
// 照 trig TrigProbe 复刻（P4.2 同构），三处 n3 化裁剪（P5.1 面清单定案）：
//   ① handler 只覆盖 `on_pop_bnp` + `on_open_slot` 两钩子（n3 无 exit_graph/list_step；
//      引擎覆盖面 engine.mbt:554/:563 同款）；
//   ② **snapshot 无需覆盖**——发射快照走 `take_pending`（engine.mbt:517），壳交换/倒装
//      交换/注解结算三件已内置，interpret 默认体直调；
//   ③ 面最小化：只开 `new`/`step_all`——trig 的 `step`（吞事件旧口径）与 `state`/
//      `stack_view`（P4.2e/h 量测遗产，quicktest 零引用）不开；`step_once` 为内部件。
//      【沿革（役 7 n3v2，2026-09-18）】`state` 本日开面（见下）：普查观测面（只读值
//      拷贝），非量测遗产复辟——trig 同名面在役 7 经变异实证后保留（「响应+状态」
//      比对的引擎侧读数，src/ttl/todo.md §N.1），n3 普查门同需求；回收条件见 state()。
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
/// 普查观测面（役 7 n3v2，2026-09-18 开面）：**只读值拷贝**——「响应 + 状态」比对的
/// 引擎侧读数。归一化（N3State → 模型态）的穷尽桥住消费侧（quicktest metrics 的
/// `model_state_of_engine`，priv 类型不可跨包——probe 只给读数，不做归一）。
/// 纪律：**不开 ctx**、不许普查门以外的用途扩面（量测遗产教训，trig §N.1 同规）。
/// **回收条件**：①普查门降级/撤销 ⇒ 本面同笔回收（trig `TrigProbe::state` 对称同规）；
/// ②更窄等价投影目前不存在——穷尽桥需要真枚举（String 化会让桥的编译期保证烂掉）；
/// ③存量面 `new`/`step_all` 不受影响（P5.2 最小面口径仍是基调，本面是记录在案的例外）。
pub fn N3Probe::state(self : N3Probe) -> N3State {
  self.ctx.state
}

///|
/// 槽位快照（**值级普查观测面**，役 ③b，2026-09-19 开面）：只读值拷贝，字段面 =
/// 生成面 `[type_mapping]` 的 `model_slots` + `fwd_slot` 的**镜像**（模型有的槽这里就有，
/// 模型没有的 ctx 字段——`prefixes`/`bases`/`kw_ledger`/`pred_kind`/`slot_stack`/… ——**不开**）。
/// 缺口缘起：三表 `writes` 的值级条目（`object=arg0` / `path_pend=none` /
/// `subject=fwd:ctx.path_src|ctx.path_tail` …）此前只能靠人从 `actions.mbt` 抄——
/// 静态解析必成纸（48 个 action 里 29 个含难解析写）；本面让 quicktest 能**逐对读引擎真槽位**，
/// 与模型槽位比对（见 `quicktest/metrics.mbt` 值级普查门）。
/// 归一化（`Span` → 模型引用值）住消费侧，与 `state()` 同规：probe 只给读数，不做归一。
/// 纪律与**回收条件**（同 §N.1 / `state()`）：①值级普查门降级或撤销 ⇒ 本面同笔回收；
/// ②更窄等价投影不存在（8 位已是最窄——少一位即漏一类写槽；String 化会烂掉消费侧
/// 穷尽桥的编译期保证）；③存量面 `new`/`step_all`/`state` 不动，P5.2 最小面口径仍是基调。
pub(all) struct N3SlotSnapshot {
  subject : Span?
  predicate : Span?
  object : Span?
  graph : Span?
  path_src : Span?
  path_pend : Span?
  path_tail : Span?
  path_fwd : Bool
}

///|
pub fn N3Probe::slots(self : N3Probe) -> N3SlotSnapshot {
  {
    subject: self.ctx.subject,
    predicate: self.ctx.predicate,
    object: self.ctx.object,
    graph: self.ctx.graph,
    path_src: self.ctx.path_src,
    path_pend: self.ctx.path_pend,
    path_tail: self.ctx.path_tail,
    path_fwd: self.ctx.path_fwd,
  }
}

///|
/// **帧面视图**（*帧栈观测面*，§AN.13，2026-09-19 开面）：`ctx.slot_stack` 单帧的
/// **只读值拷贝**。字段面 = 引擎 `Slot` 各字段（三槽快照 / `open_span` / `ret_state` /
/// `as_subject` / `as_pred` / `prev_node` / `node_seq`）+ 一个**派生位** `is_formula`
/// （= `typ is SlotType::Formula`；引擎**不存**该旗——它是生成器按行实参推的，
/// 与模型侧 `frame.is_formula` 同义）。
/// 缺口缘起：三表 `writes` 里 `frame.*` 条目（`frame.prev_node=arg0` /
/// `frame.as_pred=true` / `frame.ret_state=…`）与**弹帧恢复**（`PopBnp` 把帧存的三槽写回）
/// 此前全记"面外"——静态解析必成纸，本面让 quicktest 能**读引擎真帧**。
/// 沿革：trig 的 `stack_view`（P4.2h 量测遗产）在役 2 因**零引用**删除；本面是同族**复活**，
/// 但带**常驻消费者**（数据面值级对拍门 `quicktest/data_face.mbt`）。
/// 纪律与**回收条件**（同 §N.1 / `state()` / `slots()`）：①数据面帧面消费门降级或撤销 ⇒
/// 本面**同笔回收**；②更窄等价投影不存在（帧是**栈**，不给栈序/栈顶即无法判"弹帧恢复"
/// 这类跨步语义）；③存量面 `new`/`step_all`/`state`/`slots` 不动。
pub(all) struct N3FrameView {
  is_formula : Bool // 派生：`typ is SlotType::Formula`（公式帧不占 s 槽的引擎依据）
  open_span : Span
  subject : Span?
  predicate : Span?
  graph : Span?
  ret_state : N3State
  as_subject : Bool
  as_pred : Bool
  prev_node : Span?
  node_seq : Int
}

///|
/// 帧栈只读读数：**自底向上**（数组序 = 压栈序，栈顶 = 末元素）。
pub fn N3Probe::frames(self : N3Probe) -> Array[N3FrameView] {
  let out : Array[N3FrameView] = []
  for frame in self.ctx.slot_stack {
    out.push({
      is_formula: frame.typ is SlotType::Formula,
      open_span: frame.open_span,
      subject: frame.subject,
      predicate: frame.predicate,
      graph: frame.graph,
      ret_state: frame.ret_state,
      as_subject: frame.as_subject,
      as_pred: frame.as_pred,
      prev_node: frame.prev_node,
      node_seq: frame.node_seq,
    })
  }
  out
}

///|
/// **倒装账本位读数**（`[type_mapping].inversion` 两槽，与 `frames()` 同笔开面、同纪律同回收）：
/// `is_src` = 交换键（`is_of`/`<-` 落键的入账主语 span），`is_depth` = 结算界（落键时刻栈深）。
pub(all) struct N3InversionView {
  is_src : Span?
  is_depth : Int
}

///|
pub fn N3Probe::inversion(self : N3Probe) -> N3InversionView {
  { is_src: self.ctx.is_src, is_depth: self.ctx.is_depth, }
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

///|
/// 观测面自证：`state()` 只读、随转移推进（普查门的读数语义）——
/// 初态主语位，一步 Iri 后谓词位。
test "probe: state() 观测面只读随转移" {
  let probe = N3Probe::new()
  assert_true(probe.state() is N3State::N3ExpectSubject)
  let _ = probe.step_all(N3Event::N3Iri((0, 3)))
  assert_true(probe.state() is N3State::N3ExpectPredicate)
}

///|
/// 观测面自证（**值级**）：`slots()` 只读、随转移逐槽落位——两枚 Iri 落 subject/predicate；
/// 宾位路径入口 `!`（`path_obj_trail`）落 object/path_src/path_tail 并立 `path_fwd`；
/// 押步（`path_step`）只动 `path_pend`。这正是三表 `writes` 的**读数面**：
/// 没这条自证，"值级对拍"两边的读法就不独立（同 `state()` 的自证口径）。
test "probe: slots() 观测面只读随转移（值级读数自证）" {
  let probe = N3Probe::new()
  let s0 = probe.slots()
  assert_true(s0.subject is None)
  assert_true(s0.predicate is None)
  assert_true(s0.path_src is None)
  assert_true(s0.path_pend is None)
  assert_true(s0.path_tail is None)
  assert_true(s0.path_fwd == false)
  // 只读性：不喂事件再取一次，读数不变
  let s0_again = probe.slots()
  assert_true(s0_again.subject is None)
  assert_true(s0_again.path_fwd == false)
  let _ = probe.step_all(N3Event::N3Iri((0, 2))) // :a
  assert_eq(probe.slots().subject, Some((0, 2)))
  assert_true(probe.slots().predicate is None)
  let _ = probe.step_all(N3Event::N3PrefName((3, 2))) // :p
  assert_eq(probe.slots().predicate, Some((3, 2)))
  let _ = probe.step_all(N3Event::N3Iri((6, 2))) // :o
  assert_eq(probe.slots().object, Some((6, 2)))
  // 宾位尾随入口 `!`：path_obj_trail——object := op、path_src := 旧 object、path_tail := op、
  // path_pend 清、path_fwd 立（s/p 槽不动，帧快照另存）
  let _ = probe.step_all(N3Event::N3Bang((9, 1)))
  let s1 = probe.slots()
  assert_eq(s1.subject, Some((0, 2)))
  assert_eq(s1.predicate, Some((3, 2)))
  assert_eq(s1.object, Some((9, 1)))
  assert_eq(s1.path_src, Some((6, 2)))
  assert_eq(s1.path_tail, Some((9, 1)))
  assert_true(s1.path_pend is None)
  assert_true(s1.path_fwd)
  // 押步（ObjTrailExpectVerb + PrefName ⇒ path_step）：只动 path_pend，tail/src 不动
  let _ = probe.step_all(N3Event::N3PrefName((11, 2)))
  let s2 = probe.slots()
  assert_eq(s2.path_pend, Some((11, 2)))
  assert_eq(s2.path_tail, Some((9, 1)))
  assert_eq(s2.path_src, Some((6, 2)))
}
