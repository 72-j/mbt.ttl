// ========================================
// System - 真实执行适配层（N3 quicktest / **手维护实例**，P5.4）
// FSM: n3_parser | Config: n3_quick_machine
// ========================================
// 口径（照 trig P4.2b 定案）：本文件**不再**重写引擎 47 个 action —— 那等于把
// `gen_n3v2/actions.mbt` 抄一遍，语义漂移无从保证。改为调**同包窄驱动面**
// `@n3.N3Probe`（P5.2 落地）：
//   Probe 内部复用引擎真件：真 `N3ActionsImpl` + 真 handler 钩子（on_pop_bnp /
//   on_open_slot 薄委托）+ 真 `interpret`（唯一解释器，役22 口径），三步序与
//   `N3Engine::next` 同构（队列优先排空 → step → interpret）。
//   snapshot 不覆盖——`take_pending`（engine.mbt:517）内置壳/倒装/注解三结算。
//
// 映射：Command → N3Event（引用编码进 Span）；N3ProbeResponse → Response（四档）；
//       N3PendingQuad（引擎快照）→ Quad（模型四槽）。
// 错误归一化：UnexpectedEvent → Error(0)，BusinessFailed → Error(1)。
//
// ⚠️ 本目录是**手维护实例**：生成器 `quick` 只做 bootstrap，不再覆盖（trig 同款双层）。

// >>> EVIDENCE（P5.5 钉子①：证据注释留位——生成/物化不得覆盖本区间，守卫测试按标记校验）
// 本实例的领域证据 = probe 批接线（P5.4）：Command→N3Event 映射、N3PendingQuad→Quad
// 快照照抄、错误归一化 0/1；值锚点（期望值字面量）属 anchors.mbt，本方言待 P5.5 第二笔铺设。
// <<< EVIDENCE

///|
/// RefId → 引擎 Span（id 编码进 start/end，可逆；Span = (Int, Int) 元组）
fn span_from(id : RefId) -> @n3.Span {
  (id.id, id.id)
}

///|
/// 引擎 Span → RefId（解码 start）
fn ref_id_of(span : @n3.Span) -> RefId {
  { id: span.0, }
}

///|
/// 执行期引用必为 Concrete；防御性兜底 id = 0
fn concrete_id(reference : @qcs.Ref[RefId]) -> RefId {
  match reference {
    Concrete(id) => id
    Symbolic(_) => { id: 0, }
  }
}

///|
/// Command → 引擎 Event（引用编码进 Span）
fn command_to_event(command : Command) -> @n3.N3Event {
  match command {
    Iri(r) => N3Iri(span_from(concrete_id(r)))
    BlankNode(r) => N3BlankNode(span_from(concrete_id(r)))
    Literal(r) => N3Literal(span_from(concrete_id(r)), None)
    PrefName(r) => N3PrefName(span_from(concrete_id(r)))
    TripleTerm(r) => N3TripleTerm(span_from(concrete_id(r)))
    BracketTripleTerm(r) => N3BracketTripleTerm(span_from(concrete_id(r)))
    KeywordA(r) => N3KeywordA(span_from(concrete_id(r)))
    Variable(r) => N3Variable(span_from(concrete_id(r)))
    KeywordX(r) => N3KeywordX(span_from(concrete_id(r)))
    Equals(r) => N3Equals(span_from(concrete_id(r)))
    Is => N3Is
    Of => N3Of
    Has => N3Has
    At => N3At
    PrefixKw => N3PrefixKw
    BaseKw => N3BaseKw
    VersionKw => N3VersionKw
    Tilde => N3Tilde
    AnnotStart => N3AnnotStart
    AnnotEnd => N3AnnotEnd
    ForAllKw => N3ForAllKw
    ForSomeKw => N3ForSomeKw
    KeywordsKw => N3KeywordsKw
    Comma => N3Comma
    Semicolon => N3Semicolon
    Dot => N3Dot
    Lbrace(r) => N3Lbrace(span_from(concrete_id(r)))
    Rbrace => N3Rbrace
    Lbracket(r) => N3Lbracket(span_from(concrete_id(r)))
    Rbracket => N3Rbracket
    Lparen(r) => N3Lparen(span_from(concrete_id(r)))
    Rparen => N3Rparen
    Anon(r) => N3Anon(span_from(concrete_id(r)))
    Bang(r) => N3Bang(span_from(concrete_id(r)))
    Caret(r) => N3Caret(span_from(concrete_id(r)))
    Implies(r) => N3Implies(span_from(concrete_id(r)))
    ImpliedBy(r) => N3ImpliedBy(span_from(concrete_id(r)))
    Unknown(r) => N3Unknown(span_from(concrete_id(r)))
    EOF => N3EOF
  }
}

///|
/// 引擎快照 → Quad（四槽**照抄**，槽位可空——快照档 ADR-QM-009）
/// 与 `model_exec.take_quad` 同机械：模型侧怎么交出快照，适配层就怎么读引擎快照，
/// 缺槽不在这一层拒绝（领域解释在组装层 `parser_slice.assemble`）。
fn quad_from_pending(pending : @n3.N3PendingQuad) -> Quad {
  {
    subject: pending.subj.map(ref_id_of),
    predicate: pending.pred.map(ref_id_of),
    object: pending.obj.map(ref_id_of),
    graph: pending.graph.map(ref_id_of),
  }
}

///|
/// System: 被测系统（probe 持引擎真 ctx，跨命令保持）
priv struct System {
  probe : @n3.N3Probe
}

///|
fn system_init() -> System {
  { probe: @n3.N3Probe::new(), }
}

///|
/// 真实执行: Command → Event → `step_all` → Response（错误归一化）
/// P4.2h ③ 同口径：走 `step_all`——**排空残留 ⇒ 处理本事件 ⇒ 收本事件余量**，
/// 一条命令拿到"它自己的"有序响应批（不吞入参事件）。
fn run_command(command : Command, system : System) -> Response {
  let event = command_to_event(command)
  let batch = system.probe.step_all(event)
  let responses = batch.map(fn(response) {
    probe_response_to_response(response)
  })
  if responses.length() == 1 {
    responses[0]
  } else {
    Batch(responses)
  }
}

///|
/// 单档 probe 响应 → 归一化 Response（批的每个元素复用本函数）
fn probe_response_to_response(response : @n3.N3ProbeResponse) -> Response {
  match response {
    @n3.N3ProbeResponse::Continue => Continue
    @n3.N3ProbeResponse::EmitQuad(pending) =>
      EmitQuad(quad_from_pending(pending)) // 快照照抄（槽位可空，ADR-QM-009）
    @n3.N3ProbeResponse::Done => Done
    @n3.N3ProbeResponse::Failed(error) =>
      match error {
        @n3.N3ActionError::UnexpectedEvent(_, _) => Error(0)
        @n3.N3ActionError::BusinessFailed(_) => Error(1)
      }
  }
}

///|
/// 冒烟：一条三元组 `:a :p :o .`——引擎逐步响应与纯模型预测一致
/// （与 probe.mbt 钉子①同脚本；IoRIE 等价口径：单发射命令批长 1）
test "n3 quick machine: 引擎与模型逐步一致（一条三元组）" {
  let system = system_init()
  let model = model_empty()
  let c1 = Iri(Concrete({ id: 0, }))
  let (model2, expected1) = model_execute(model, c1)
  assert_eq(run_command(c1, system), expected1)
  let c2 = Iri(Concrete({ id: 4, }))
  let (model3, expected2) = model_execute(model2, c2)
  assert_eq(run_command(c2, system), expected2)
  let c3 = Iri(Concrete({ id: 8, }))
  let (model4, expected3) = model_execute(model3, c3)
  assert_eq(run_command(c3, system), expected3)
  let (model5, expected4) = model_execute(model4, Dot)
  assert_eq(run_command(Dot, system), expected4)
  let _ = model5
}
