// ===== 用户部分：Actions 实现（mutable 契约，与 nquads Hooks 同构） =====
// 口径（与 trig.mbt 头注一致）：
//   - action 只写槽位/账本，返回意图；永不重置 ctx，也拿不到数据视图
//   - 命名在 nquads 词汇基础上追加：set_subject/predicate/object 原样，
//     指令/图块为 trig 新增

///|
/// Actions 的缺省实现载体（单载体：step 的 actions 面）
pub struct Hooks {}

///|
pub fn Hooks::new() -> Hooks {
  Hooks::{ }
}

///|
impl TrigActions for Hooks with fn set_subject(
  _self : Hooks,
  ctx : TrigContext,
  payload : Span,
) -> Result[TrigEffect, TrigActionError] {
  ctx.subject = Some(payload)
  Ok(TrigEffect::Continue)
}

///|
impl TrigActions for Hooks with fn set_predicate(
  _self : Hooks,
  ctx : TrigContext,
  payload : Span,
) -> Result[TrigEffect, TrigActionError] {
  ctx.predicate = Some(payload)
  Ok(TrigEffect::Continue)
}

///|
impl TrigActions for Hooks with fn set_object(
  _self : Hooks,
  ctx : TrigContext,
  payload : Span,
) -> Result[TrigEffect, TrigActionError] {
  ctx.object = Some(payload)
  Ok(TrigEffect::Continue)
}

///|
impl TrigActions for Hooks with fn set_prefix_name(
  _self : Hooks,
  ctx : TrigContext,
  payload : Span,
) -> Result[TrigEffect, TrigActionError] {
  ctx.prefix_name = Some(payload)
  Ok(TrigEffect::Continue)
}

///|
impl TrigActions for Hooks with fn declare_prefix(
  _self : Hooks,
  ctx : TrigContext,
  iri : Span,
) -> Result[TrigEffect, TrigActionError] {
  // 前缀名在 ctx.prefix_name 中转槽位（指令两段式的落地动作）
  match ctx.prefix_name {
    Some(name) => {
      ctx.prefixes.push((name, iri))
      ctx.prefix_name = None
      Ok(TrigEffect::Continue)
    }
    None =>
      // 表保证先 set_prefix_name 再 declare_prefix；此分支为防御位
      Err(TrigActionError::BusinessFailed("Prefix name missing"))
  }
}

///|
impl TrigActions for Hooks with fn set_base(
  _self : Hooks,
  ctx : TrigContext,
  iri : Span,
) -> Result[TrigEffect, TrigActionError] {
  ctx.base = Some(iri)
  // ★1 base 链：append-only（物化层按 bver 折叠出该 quad 的生效 base）；
  // ctx.base 单槽保留 = 最新声明（构造器不再读它，仅簿记兼容）
  ctx.bases.push(iri)
  Ok(TrigEffect::Continue)
}

///|
impl TrigActions for Hooks with fn enter_graph(
  _self : Hooks,
  ctx : TrigContext,
  label : Span?,
) -> Result[TrigEffect, TrigActionError] {
  // 参数绑定数据面：实参已在转移行 action_args 声明（none → None 默认图；
  // ctx.subject → pending 主语即图标签；Some(payload) → 带标签图块），
  // action 收到现成 label，不再嗅探事件形态
  // TriG 图块不嵌套（表结构禁止）：单槽位即栈，None=默认图
  ctx.graph = label
  Ok(TrigEffect::EnterGraph)
}

///|
impl TrigActions for Hooks with fn exit_graph(_self : Hooks, ctx : TrigContext) -> Result[
  TrigEffect,
  TrigActionError,
] {
  ctx.graph = None
  Ok(TrigEffect::ExitGraph)
}

///|
/// ★3 区域栈：压栈 action——外层槽位快照入帧（s/p/g + ret_state；ret_state 是
/// 开括号转移行定夺的决策，帧只携带），fresh 节点占 s 槽，谓词清空
///（宾位进入时外层 p 挂帧，弹栈恢复）。object 槽不动（进入位必为 None 缺口）
impl TrigActions for Hooks with fn open_bnode_prop(
  _self : Hooks,
  ctx : TrigContext,
  open_span : Span,
  as_subject : Bool,
  ret_state : TrigState,
) -> Result[TrigEffect, TrigActionError] {
  ctx.slot_stack.push({
    typ: SlotType::BnodeProp,
    open_span,
    subject: ctx.subject,
    predicate: ctx.predicate,
    graph: ctx.graph,
    ret_state,
    as_subject,
    prev_node: None,
    node_seq: 0,
  })
  ctx.subject = Some(open_span)
  ctx.predicate = None
  Ok(TrigEffect::Continue)
}

///|
/// ★3 区域栈：弹栈 action——恢复外层 s/p/g，fresh 节点落入目标槽
///（as_subject 定槽位），返回状态兑现帧携带的决策（state 由表间接管理的唯一例外）。
/// 序上恒在 EmitQuad 之后：emit 先 snapshot 后收拾，恢复值取自帧不受 PredObj 收拾波及
impl TrigActions for Hooks with fn pop_bnode_prop(
  _self : Hooks,
  ctx : TrigContext,
) -> Result[TrigEffect, TrigActionError] {
  match ctx.slot_stack.pop() {
    Some(fr) => {
      ctx.subject = fr.subject
      ctx.predicate = fr.predicate
      ctx.graph = fr.graph
      let target = if fr.typ is SlotType::List && fr.node_seq == 0 {
        // 空集合收口：无链节点 = rdf:nil（Span(open.0, 0) 长度 0 标记，物化层识别）
        (fr.open_span.0, 0)
      } else {
        // 非空集合头 = node0 = (open.0, 1) = fr.open_span 自身，天然落位
        fr.open_span
      }
      if fr.as_subject {
        ctx.subject = Some(target)
      } else {
        ctx.object = Some(target)
      }
      ctx.state = fr.ret_state
      Ok(TrigEffect::Continue)
    }
    None =>
      // 表只在区域状态发 PopBnp，空栈不可达；防御位
      Err(TrigActionError::BusinessFailed("Slot stack underflow"))
  }
}

///|
/// ★3 阶段3 `()` 集合：开集合 action——List 帧压栈，外层 s/p/g 快照入帧；
/// s 槽留空（链头未定：空集合 = rdf:nil，非空集合头 = node0，收口/pop 时裁决）
impl TrigActions for Hooks with fn open_collection(
  self : Hooks,
  ctx : TrigContext,
  open_span : Span,
  as_subject : Bool,
  ret_state : TrigState,
) -> Result[TrigEffect, TrigActionError] {
  ctx.slot_stack.push({
    typ: SlotType::List,
    open_span,
    subject: ctx.subject,
    predicate: ctx.predicate,
    graph: ctx.graph,
    ret_state,
    as_subject,
    prev_node: None,
    node_seq: 0,
  })
  ctx.subject = None
  ctx.predicate = None
  Ok(TrigEffect::Continue)
}

///|
/// OpenSlot 意图兑现 action（嵌套元素开帧，`[`/`(` 作集合元素）：按 typ 压对应帧。
/// as_subject 恒 false（嵌套开帧只发生元素位，主位开帧走直连行）
impl TrigActions for Hooks with fn open_slot(
  self : Hooks,
  ctx : TrigContext,
  open_span : Span,
  typ : SlotType,
  ret_state : TrigState,
) -> Result[TrigEffect, TrigActionError] {
  match typ {
    SlotType::BnodeProp =>
      self.open_bnode_prop(ctx, open_span, false, ret_state)
    SlotType::List => self.open_collection(ctx, open_span, false, ret_state)
    SlotType::Formula =>
      // N3 公式预埋未接表；表外形态，防御位
      Err(TrigActionError::BusinessFailed("Formula slot not supported"))
  }
}

///|
/// 集合区域栈顶帧（表保证区域状态只在有帧时可达；空栈 = 组装层契约破坏，防御位）
fn list_top(ctx : TrigContext) -> Result[Slot, TrigActionError] {
  if ctx.slot_stack.length() == 0 {
    return Err(TrigActionError::BusinessFailed("Slot stack underflow"))
  }
  Ok(ctx.slot_stack[ctx.slot_stack.length() - 1])
}

///|
/// 首元素 first 链发射：链头未建则建 node0 = (open.0, 1)；first 标记 + 元素落 o 槽。
/// EmitQuad(PredObj) 收拾后 s 槽保留链节点（下一元素 rest 链复用）
impl TrigActions for Hooks with fn list_first(
  self : Hooks,
  ctx : TrigContext,
  elem : Span,
) -> Result[TrigEffect, TrigActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  if fr.node_seq == 0 {
    ctx.subject = Some((fr.open_span.0, 1))
    fr.node_seq = 1
  }
  ctx.pred_kind = PredKind::RDFFirst
  ctx.object = Some(elem)
  Ok(TrigEffect::EmitQuad(ResetScope::PredObj))
}

///|
/// 首元素为嵌套结构（`[`/`(`）：first 链发射（o = 嵌套头 span，开括号即身份）→
/// OpenSlot 兑现开帧（发射在先——快照要拍到链节点，开帧覆写 s 在其后）
impl TrigActions for Hooks with fn list_first_nested(
  self : Hooks,
  ctx : TrigContext,
  elem : Span,
  typ : SlotType,
  ret_state : TrigState,
) -> Result[TrigEffect, TrigActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  if fr.node_seq == 0 {
    ctx.subject = Some((fr.open_span.0, 1))
    fr.node_seq = 1
  }
  ctx.pred_kind = PredKind::RDFFirst
  ctx.object = Some(elem)
  Ok(
    TrigEffect::Sequence([
      TrigEffect::EmitQuad(ResetScope::PredObj),
      TrigEffect::OpenSlot(elem, typ, ret_state),
    ]),
  )
}

///|
/// 后续元素：rest 链发射（当前节点 → 新节点 Span(open.0, node_seq+1)）→
/// ListStep 兑现（切新节点 + first 标记 + 元素落 o）→ 第二次发射（新节点 first 元素）
impl TrigActions for Hooks with fn list_next(
  self : Hooks,
  ctx : TrigContext,
  elem : Span,
) -> Result[TrigEffect, TrigActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  let next_node : Span = (fr.open_span.0, fr.node_seq + 1)
  ctx.pred_kind = PredKind::RDFRest
  ctx.object = Some(next_node)
  Ok(
    TrigEffect::Sequence([
      TrigEffect::EmitQuad(ResetScope::PredObj),
      TrigEffect::ListStep(elem),
      TrigEffect::EmitQuad(ResetScope::PredObj),
    ]),
  )
}

///|
/// 后续元素为嵌套结构：rest 链 → ListStep 切新节点 + first 标记落 o = 嵌套头 →
/// 第二次发射 → OpenSlot 开帧（四意图序）
impl TrigActions for Hooks with fn list_next_nested(
  self : Hooks,
  ctx : TrigContext,
  elem : Span,
  typ : SlotType,
  ret_state : TrigState,
) -> Result[TrigEffect, TrigActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  let next_node : Span = (fr.open_span.0, fr.node_seq + 1)
  ctx.pred_kind = PredKind::RDFRest
  ctx.object = Some(next_node)
  Ok(
    TrigEffect::Sequence([
      TrigEffect::EmitQuad(ResetScope::PredObj),
      TrigEffect::ListStep(elem),
      TrigEffect::EmitQuad(ResetScope::PredObj),
      TrigEffect::OpenSlot(elem, typ, ret_state),
    ]),
  )
}

///|
/// 集合收口（尾元素后 `)`）：尾节点 rdf:rest rdf:nil（标记 Span(open.0, 0)）→
/// pop（头节点 fr.open_span 落目标槽 + 返回状态兑现）
impl TrigActions for Hooks with fn list_nil(self : Hooks, ctx : TrigContext) -> Result[
  TrigEffect,
  TrigActionError,
] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  ctx.pred_kind = PredKind::RDFRest
  ctx.object = Some((fr.open_span.0, 0))
  Ok(
    TrigEffect::Sequence([
      TrigEffect::EmitQuad(ResetScope::PredObj),
      TrigEffect::PopBnp,
    ]),
  )
}

///|
/// ListStep 意图兑现 action：节点序号 +1，s 槽切新节点（Span(open.0, 新序号)），
/// first 标记 + 元素落 o 槽（供串列中第二次 EmitQuad 快照）
impl TrigActions for Hooks with fn list_step(
  self : Hooks,
  ctx : TrigContext,
  elem : Span,
) -> Result[TrigEffect, TrigActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.node_seq = fr.node_seq + 1
  ctx.subject = Some((fr.open_span.0, fr.node_seq))
  ctx.pred_kind = PredKind::RDFFirst
  ctx.object = Some(elem)
  Ok(TrigEffect::Continue)
}
