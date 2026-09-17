// ========================================
// System - 真实执行适配层（TriG quicktest / **手维护实例**，P4.2b）
// FSM: trig_parser | Config: trig_quick_machine
// ========================================
// 口径（P4.2b 定案）：本文件**不再**重写引擎 22 个 action —— 那等于把 `gen_trig/actions.mbt`
// 抄一遍，语义漂移无从保证。改为调**同包窄驱动面** `@trig.TrigProbe`（P4.2 落地）：
//   Probe 内部复用引擎真件：真 `TrigActionsImpl` + 真 handler 钩子（壳旗/收口旗结算）
//   + 真 `interpret`（唯一解释器，T11 口径），三步序与 `TrigEngine::next` 同构
//   （队列优先排空 → step → interpret）。
//
// 映射：Command → TrigEvent（引用编码进 Span）；TrigProbeResponse → Response（四档）；
//       TrigPendingQuad（引擎快照）→ Quad（模型四槽）。
// 错误归一化：UnexpectedEvent → Error(0)，BusinessFailed → Error(1)。
//
// ⚠️ 本目录是**手维护实例**：`materialize trig quicktest` 只在目录缺失时 bootstrap，不再覆盖。

///|
/// RefId → 引擎 Span（id 编码进 start/end，可逆；Span = (Int, Int) 元组）
fn span_from(id : RefId) -> @trig.Span {
  (id.id, id.id)
}

///|
/// 引擎 Span → RefId（解码 start）
fn ref_id_of(span : @trig.Span) -> RefId {
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
/// 引擎快照 → Quad（四槽**照抄**，槽位可空——快照档 ADR-QM-009）
/// 与 `model_exec.take_quad` 同机械：模型侧怎么交出快照，适配层就怎么读引擎快照，
/// 缺槽不在这一层拒绝（领域解释在组装层 `parser_slice.assemble`）。
fn quad_from_pending(pending : @trig.TrigPendingQuad) -> Quad {
  {
    subject: pending.subj.map(ref_id_of),
    predicate: pending.pred.map(ref_id_of),
    object: pending.obj.map(ref_id_of),
    graph: pending.graph.map(ref_id_of),
  }
}

///|
/// Command → 引擎 Event（引用编码进 Span）
fn command_to_event(command : Command) -> @trig.TrigEvent {
  match command {
    Iri(r) => TrigIri(span_from(concrete_id(r)))
    BlankNode(r) => TrigBlankNode(span_from(concrete_id(r)))
    Literal(r) => TrigLiteral(span_from(concrete_id(r)))
    PrefName(r) => TrigPrefName(span_from(concrete_id(r)))
    TripleTerm(r) => TrigTripleTerm(span_from(concrete_id(r)))
    BracketTripleTerm(r) => TrigBracketTripleTerm(span_from(concrete_id(r)))
    KeywordA(r) => TrigKeywordA(span_from(concrete_id(r)))
    At => TrigAt
    PrefixKw => TrigPrefixKw
    BaseKw => TrigBaseKw
    GraphKw => TrigGraphKw
    VersionKw => TrigVersionKw
    Tilde => TrigTilde
    AnnotStart => TrigAnnotStart
    AnnotEnd => TrigAnnotEnd
    Comma => TrigComma
    Semicolon => TrigSemicolon
    Dot => TrigDot
    Lbrace => TrigLbrace
    Rbrace => TrigRbrace
    Lbracket(r) => TrigLbracket(span_from(concrete_id(r)))
    Rbracket => TrigRbracket
    Lparen(r) => TrigLparen(span_from(concrete_id(r)))
    Rparen => TrigRparen
    Anon(r) => TrigAnon(span_from(concrete_id(r)))
    Bang => TrigBang
    Caret => TrigCaret
    Implies => TrigImplies
    ImpliedBy => TrigImpliedBy
    ForAllKw => TrigForAllKw
    ForSomeKw => TrigForSomeKw
    KeywordsKw => TrigKeywordsKw
    Unknown => TrigUnknown
    EOF => TrigEOF
  }
}

///|
/// System：被测系统（probe 持有引擎 ctx + 真 Actions + 真 interpret，跨命令保持）
struct System {
  probe : @trig.TrigProbe
}

///|
fn system_init() -> System {
  { probe: @trig.TrigProbe::new(), }
}

///|
/// 真实执行：Command → Event → probe.step（= step + interpret）→ Response（错误归一化）
fn run_command(command : Command, system : System) -> Response {
  let event = command_to_event(command)
  // P4.2h ③：走 `step_all`——**排空残留 ⇒ 处理本事件 ⇒ 收本事件余量**，
  // 一条命令拿到"它自己的"有序响应批（不再被上一命令的余量顶掉/吞掉入参事件）。
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
fn probe_response_to_response(response : @trig.TrigProbeResponse) -> Response {
  match response {
    @trig.TrigProbeResponse::Continue => Continue
    @trig.TrigProbeResponse::EmitQuad(pending) =>
      EmitQuad(quad_from_pending(pending)) // 快照照抄（槽位可空，ADR-QM-009）
    @trig.TrigProbeResponse::Done => Done
    @trig.TrigProbeResponse::Failed(error) =>
      match error {
        @trig.TrigActionError::UnexpectedEvent(_, _) => Error(0)
        @trig.TrigActionError::BusinessFailed(_) => Error(1)
      }
  }
}

///|
/// 冒烟：引擎实际响应与纯模型预测逐步一致（双执行比较的最小样本）
test "trig quick machine: 引擎与模型逐步一致（一条三元组）" {
  let system = system_init()
  let script : Array[Command] = [
    Iri(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Iri(Concrete({ id: 3, })),
    Dot,
  ]
  let mut model = model_empty()
  for command in script {
    let (next_model, expected) = model_execute(model, command)
    assert_eq(run_command(command, system), expected)
    model = next_model
  }
  // 未定义转移：引擎与模型的错误码一致
  assert_eq(run_command(Dot, system), Error(0))
}
