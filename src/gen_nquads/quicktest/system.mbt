// ========================================
// System — 真实执行适配层（手写版；目标形状 = 生成器产物 system.mbt）
// P0 人工补充点：真实调用方式与错误归一化（quick_machine.md §五）
//
// 被测系统 = 生成引擎的 step 驱动（src/gen_nquads/nquads.mbt）：
//   Command → Event → step(ctx, event, actions) → Effect → Response
// 槽位重置由本层按 ResetScope 执行，与引擎主循环（engine.mbt）同机械。
// 依赖：引擎 NQuadsActions 必须是 pub(open) trait 才能跨包实现
//       （生成器回灌项：trait 声明需产出 pub(open)）。
// ========================================

///|
/// 错误归一化码（源 [type_mapping].error_codes）：未定义转移 / action 业务失败
const UNDEFINED_TRANSITION_CODE : Int = 0

///|
const ACTION_FAILED_CODE : Int = 1

///|
/// RefId → 引擎 Span（id 编码进 start/end，可逆；Span = (Int, Int) 元组）
fn span_from(id : RefId) -> @nquads.Span {
  (id.id, id.id)
}

///|
/// 引擎 Span → RefId（解码 start）
fn ref_id_of(span : @nquads.Span) -> RefId {
  { id: span.0, }
}

///|
/// Command → 引擎 Event（引用编码进 Span）
fn command_to_event(command : Command) -> @nquads.NQuadsEvent {
  match command {
    Iri(reference) =>
      @nquads.NQuadsEvent::NQuadsIri(span_from(concrete_ref_id(reference)))
    BlankNode(reference) =>
      @nquads.NQuadsEvent::NQuadsBlankNode(
        span_from(concrete_ref_id(reference)),
      )
    Literal(reference) =>
      @nquads.NQuadsEvent::NQuadsLiteral(span_from(concrete_ref_id(reference)))
    PrefName(reference) =>
      @nquads.NQuadsEvent::NQuadsPrefName(span_from(concrete_ref_id(reference)))
    TripleTerm(reference) =>
      @nquads.NQuadsEvent::NQuadsTripleTerm(
        span_from(concrete_ref_id(reference)),
      )
    Comma => @nquads.NQuadsEvent::NQuadsComma
    Semicolon => @nquads.NQuadsEvent::NQuadsSemicolon
    Dot => @nquads.NQuadsEvent::NQuadsDot
    Unknown => @nquads.NQuadsEvent::NQuadsUnknown
    EOF => @nquads.NQuadsEvent::NQuadsEOF
  }
}

///|
/// 引擎 Actions 载体：槽位 ← 载荷，意图 Continue（与引擎 Hooks 的语义一致）
priv struct EngineActions {}

///|
impl NQuadsActions for EngineActions with fn set_subject(
  _self : EngineActions,
  ctx : @nquads.NQuadsContext,
  payload : @nquads.Span,
) -> Result[@nquads.NQuadsEffect, @nquads.NQuadsActionError] {
  ctx.subject = Some(payload)
  Ok(@nquads.NQuadsEffect::Continue)
}

///|
impl NQuadsActions for EngineActions with fn set_predicate(
  _self : EngineActions,
  ctx : @nquads.NQuadsContext,
  payload : @nquads.Span,
) -> Result[@nquads.NQuadsEffect, @nquads.NQuadsActionError] {
  ctx.predicate = Some(payload)
  Ok(@nquads.NQuadsEffect::Continue)
}

///|
impl NQuadsActions for EngineActions with fn set_object(
  _self : EngineActions,
  ctx : @nquads.NQuadsContext,
  payload : @nquads.Span,
) -> Result[@nquads.NQuadsEffect, @nquads.NQuadsActionError] {
  ctx.object = Some(payload)
  Ok(@nquads.NQuadsEffect::Continue)
}

///|
impl NQuadsActions for EngineActions with fn set_graph(
  _self : EngineActions,
  ctx : @nquads.NQuadsContext,
  payload : @nquads.Span,
) -> Result[@nquads.NQuadsEffect, @nquads.NQuadsActionError] {
  ctx.graph = Some(payload)
  Ok(@nquads.NQuadsEffect::Continue)
}

///|
/// 引擎 Context → Quad（槽位 Span 解码为引用；缺槽返回 None）
fn quad_from_ctx(ctx : @nquads.NQuadsContext) -> Quad? {
  match (ctx.subject, ctx.predicate, ctx.object) {
    (Some(subject), Some(predicate), Some(object)) =>
      Some({
        subject: ref_id_of(subject),
        predicate: ref_id_of(predicate),
        object: ref_id_of(object),
        graph: ctx.graph.map(ref_id_of),
      })
    _ => None
  }
}

///|
/// Effect → Response 归一化：EmitQuad 先取快照、再按 scope 粒度重置槽位
/// （与引擎主循环 engine.mbt 的发射点同机械；缺槽归到 action 失败码）
fn effect_to_response(
  effect : @nquads.NQuadsEffect,
  ctx : @nquads.NQuadsContext,
) -> Response {
  match effect {
    @nquads.NQuadsEffect::Continue => Continue
    @nquads.NQuadsEffect::EmitQuad(scope) =>
      match quad_from_ctx(ctx) {
        Some(quad) => {
          ctx.reset(scope)
          EmitQuad(quad)
        }
        None => Error(ACTION_FAILED_CODE)
      }
    @nquads.NQuadsEffect::Done => Done
  }
}

///|
/// System - 被测系统（引擎 Context 跨命令保持；Actions 无状态）
priv struct System {
  ctx : @nquads.NQuadsContext
  actions : EngineActions
}

///|
fn system_init() -> System {
  { ctx: @nquads.NQuadsContext::new(), actions: EngineActions::{ }, }
}

///|
/// 真实执行: Command → Event → step → Effect → Response（错误归一化）
fn run_command(command : Command, system : System) -> Response {
  let event = command_to_event(command)
  match @nquads.step(system.ctx, event, system.actions) {
    Ok(effect) => effect_to_response(effect, system.ctx)
    Err(error) =>
      match error {
        @nquads.NQuadsActionError::UnexpectedEvent(_, _) =>
          Error(UNDEFINED_TRANSITION_CODE)
        @nquads.NQuadsActionError::BusinessFailed(_) =>
          Error(ACTION_FAILED_CODE)
      }
  }
}

///|
test "nquads quick machine system drives engine" {
  // 引擎实际响应与纯模型预测逐步一致（双执行比较的手工冒烟）
  let system = system_init()
  let script : Array[Command] = [
    Iri(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Literal(Concrete({ id: 3, })),
    Dot,
  ]
  let mut model = model_empty()
  for command in script {
    let (next_model, expected) = model_execute(model, command)
    assert_eq(run_command(command, system), expected)
    model = next_model
  }
  // 未定义转移：引擎与模型的错误码一致
  assert_eq(run_command(EOF, system), Error(UNDEFINED_TRANSITION_CODE))
}
