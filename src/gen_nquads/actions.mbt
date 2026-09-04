// ===== 用户部分：Actions 与 Effect 回调（mutable 契约） =====
// 参考手写版 src/moon_ttl/src/parser_nquads.mbt 的 step 各分支语义：
//   set_subject  ← (ExpectSubject, Iri|BlankNode) => pending.subj = span
//   set_predicate← (ExpectPredicate, Iri)         => pending.pred = span
//   set_object   ← (ExpectObject, Iri|Literal|BlankNode) => pending.obj = span
//   set_graph    ← (ExpectDotOrGraph, Iri)        => pending.graph = span
// 口径（与 nquads.mbt 头注一致）：
//   - action 只写槽位，返回 Continue；永不重置 ctx，也拿不到数据视图
//     （切 span 组装、粒度重置都是引擎 loop 的独占机械）
//   - 错误不经 action/effect：表未列举的组合走 UnexpectedEvent 兜底，
//     由 loop 的 record_error 统一登记
// 单载体双 trait：Hooks 同时实现 NQuadsActions + NQuadsEffectHandler，
// 引擎只持有一个实例，避免第二泛型轴。

///|
/// Actions / Effect 回调的缺省实现载体
pub struct Hooks {}

///|
pub fn Hooks::new() -> Hooks {
  Hooks::{ }
}

///|
impl NQuadsActions for Hooks with fn set_subject(
  _self : Hooks,
  ctx : NQuadsContext,
  payload : Span,
) -> Result[NQuadsEffect, NQuadsActionError] {
  ctx.subject = Some(payload)
  Ok(NQuadsEffect::Continue)
}

///|
impl NQuadsActions for Hooks with fn set_predicate(
  _self : Hooks,
  ctx : NQuadsContext,
  payload : Span,
) -> Result[NQuadsEffect, NQuadsActionError] {
  ctx.predicate = Some(payload)
  Ok(NQuadsEffect::Continue)
}

///|
impl NQuadsActions for Hooks with fn set_object(
  _self : Hooks,
  ctx : NQuadsContext,
  payload : Span,
) -> Result[NQuadsEffect, NQuadsActionError] {
  ctx.object = Some(payload)
  Ok(NQuadsEffect::Continue)
}

///|
impl NQuadsActions for Hooks with fn set_graph(
  _self : Hooks,
  ctx : NQuadsContext,
  payload : Span,
) -> Result[NQuadsEffect, NQuadsActionError] {
  ctx.graph = Some(payload)
  Ok(NQuadsEffect::Continue)
}
