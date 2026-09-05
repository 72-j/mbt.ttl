// ===== 用户补充：Actions 实现（mutable 契约，与 trig Hooks 同构） =====
// 口径（与 n3.mbt 头注 / trig actions.mbt 同宪法）：
//   - action 只写槽位/账本，返回意图；永不重置 ctx，也拿不到数据视图
//   - 与 trig 的语义差全部落在本文件（表形状同源，ADR-003a）：
//     ① 集合族五动作：单一 BNode、不发链 quad、pred_kind 恒 Normal——
//        元素只记账入帧（prev_node/node_seq），statement quad 由外层收口
//        EmitQuad 时经 pop 落位携带集合 BNode；
//     ② 空集合 `( )` = rdf:nil 标记（Span(open.0, 0) 零长 span，物化层识别）
//        —— nil 特判在 pop_bnode_prop（域层 list_nil doc 钉死的口径）；
//     ③ 无 EnterGraph/ExitGraph/ListStep：N3 无图块，集合无链推进意图。

///|
/// Actions 的缺省实现载体（单载体：step 的 actions 面）
pub struct Hooks {}

///|
pub fn Hooks::new() -> Hooks {
  Hooks::{ }
}

///|
impl N3Actions for Hooks with fn set_subject(
  _self : Hooks,
  ctx : N3Context,
  payload : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.subject = Some(payload)
  Ok(N3Effect::Continue)
}

///|
impl N3Actions for Hooks with fn set_predicate(
  _self : Hooks,
  ctx : N3Context,
  payload : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.predicate = Some(payload)
  Ok(N3Effect::Continue)
}

///|
impl N3Actions for Hooks with fn set_object(
  _self : Hooks,
  ctx : N3Context,
  payload : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.object = Some(payload)
  Ok(N3Effect::Continue)
}

///|
impl N3Actions for Hooks with fn set_prefix_name(
  _self : Hooks,
  ctx : N3Context,
  payload : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.prefix_name = Some(payload)
  Ok(N3Effect::Continue)
}

///|
impl N3Actions for Hooks with fn declare_prefix(
  _self : Hooks,
  ctx : N3Context,
  iri : Span,
) -> Result[N3Effect, N3ActionError] {
  // 前缀名在 ctx.prefix_name 中转槽位（@prefix/@base 两段式的落地动作；
  // SPARQL 风格同槽，directive_at 只记风格不分支）
  match ctx.prefix_name {
    Some(name) => {
      ctx.prefixes.push((name, iri))
      ctx.prefix_name = None
      Ok(N3Effect::Continue)
    }
    None =>
      // 表保证先 set_prefix_name 再 declare_prefix；此分支为防御位
      Err(N3ActionError::BusinessFailed("Prefix name missing"))
  }
}

///|
impl N3Actions for Hooks with fn set_base(
  _self : Hooks,
  ctx : N3Context,
  iri : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.base = Some(iri)
  // base 链：append-only（物化层按 bver 折叠出该 quad 的生效 base）；
  // ctx.base 单槽保留 = 最新声明（与 trig ★1 同口径）
  ctx.bases.push(iri)
  Ok(N3Effect::Continue)
}

///|
/// 区域栈：压栈 action——外层槽位快照入帧（s/p/g + ret_state；ret_state 是
/// 开括号转移行定夺的决策，帧只携带），fresh 节点占 s 槽，谓词清空。
/// `[]` 主/宾两位共用本动作（as_subject 定弹栈落位）。
impl N3Actions for Hooks with fn open_bnode_prop(
  _self : Hooks,
  ctx : N3Context,
  open_span : Span,
  as_subject : Bool,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
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
  Ok(N3Effect::Continue)
}

///|
/// 区域栈：弹栈 action——恢复外层 s/p/g，区域身份落入目标槽（as_subject 定槽位），
/// 返回状态兑现帧携带的决策（state 由表间接管理的唯一例外）。
/// Bnp 帧与 Collection 帧共用本动作；目标裁决：
///   - 空集合（Collection 且 node_seq==0）：rdf:nil 标记 Span(open.0, 0)
///     （零长 span = 物化层 rdf:nil 识别位；ADR-003a"无 rdf:nil 发射"指不发
///     rest 链尾 quad，值位 nil 标记保留）
///   - 非空集合：单一 BNode = fr.open_span（开括号即身份，ADR-003a 不展开链）
///   - `[]`：fresh BNode = fr.open_span
/// 序上恒在 EmitQuad 之后：emit 先 snapshot 后收拾，恢复值取自帧不受 PredObj 收拾波及
impl N3Actions for Hooks with fn pop_bnode_prop(
  _self : Hooks,
  ctx : N3Context,
) -> Result[N3Effect, N3ActionError] {
  match ctx.slot_stack.pop() {
    Some(fr) => {
      ctx.subject = fr.subject
      ctx.predicate = fr.predicate
      ctx.graph = fr.graph
      let target = if fr.typ is SlotType::Collection && fr.node_seq == 0 {
        // 空集合收口：无元素 = rdf:nil（Span(open.0, 0) 长度 0 标记，物化层识别）
        (fr.open_span.0, 0)
      } else {
        // `[]` fresh / 非空集合单一 BNode：开括号 span 即身份（ADR-003a）
        fr.open_span
      }
      if fr.as_subject {
        ctx.subject = Some(target)
      } else {
        ctx.object = Some(target)
      }
      ctx.state = fr.ret_state
      Ok(N3Effect::Continue)
    }
    None =>
      // 表只在区域状态发 PopBnp，空栈不可达；防御位
      Err(N3ActionError::BusinessFailed("Slot stack underflow"))
  }
}

///|
/// 集合区域栈：开集合 action——Collection 帧压栈，外层 s/p/g 快照入帧。
/// 与 trig 的差异：s 槽即刻落单一 BNode（ADR-003a：开括号即身份，非 trig 链头
/// TBD 的 None）——元素不入 s 槽，记账走帧字段（见 list_first）。
impl N3Actions for Hooks with fn open_collection(
  _self : Hooks,
  ctx : N3Context,
  open_span : Span,
  as_subject : Bool,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  ctx.slot_stack.push({
    typ: SlotType::Collection,
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
  Ok(N3Effect::Continue)
}

///|
/// OpenSlot 意图兑现 action（嵌套元素开帧，`[`/`(` 作集合元素）：按 typ 压对应帧。
/// as_subject 恒 false（嵌套开帧只发生元素位，主位开帧走直连行）
impl N3Actions for Hooks with fn open_slot(
  self : Hooks,
  ctx : N3Context,
  open_span : Span,
  typ : SlotType,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  match typ {
    SlotType::BnodeProp =>
      N3Actions::open_bnode_prop(self, ctx, open_span, false, ret_state)
    SlotType::Collection =>
      N3Actions::open_collection(self, ctx, open_span, false, ret_state)
    SlotType::Formula =>
      // N3 公式 Step 5（ADR-002）接表；表外形态，防御位
      Err(N3ActionError::BusinessFailed("Formula slot not supported"))
  }
}

///|
/// 集合区域栈顶帧（表保证区域状态只在有帧时可达；空栈 = 组装层契约破坏，防御位）
fn list_top(ctx : N3Context) -> Result[Slot, N3ActionError] {
  if ctx.slot_stack.length() == 0 {
    return Err(N3ActionError::BusinessFailed("Slot stack underflow"))
  }
  Ok(ctx.slot_stack[ctx.slot_stack.length() - 1])
}

///|
/// 首元素（ADR-003a）：记账入帧（node_seq 0→1，prev_node 存元素 span），
/// 不发链 quad、不动 ctx 槽位、pred_kind 恒 Normal。
/// statement 语义 = 外层收口经 pop 落位单一 BNode；元素暂存帧中（003b/后续
/// ADR 升级时免重布线）。
impl N3Actions for Hooks with fn list_first(
  _self : Hooks,
  ctx : N3Context,
  elem : Span,
) -> Result[N3Effect, N3ActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.node_seq = 1
  fr.prev_node = Some(elem)
  Ok(N3Effect::Continue)
}

///|
/// 首元素为嵌套结构（`[`/`(`）：记账同 list_first → OpenSlot 兑现开帧
///（N3 无链发射，trig 的 EmitQuad 先行序在此退化为裸 OpenSlot）
impl N3Actions for Hooks with fn list_first_nested(
  _self : Hooks,
  ctx : N3Context,
  elem : Span,
  typ : SlotType,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.node_seq = 1
  fr.prev_node = Some(elem)
  Ok(N3Effect::OpenSlot(elem, typ, ret_state))
}

///|
/// 后续元素（ADR-003a）：记账入帧（node_seq +1，prev_node 换新），
/// 不发 rest 链、不动 ctx 槽位。
impl N3Actions for Hooks with fn list_next(
  _self : Hooks,
  ctx : N3Context,
  elem : Span,
) -> Result[N3Effect, N3ActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.node_seq = fr.node_seq + 1
  fr.prev_node = Some(elem)
  Ok(N3Effect::Continue)
}

///|
/// 后续元素为嵌套结构：记账同 list_next → OpenSlot 兑现开帧
impl N3Actions for Hooks with fn list_next_nested(
  _self : Hooks,
  ctx : N3Context,
  elem : Span,
  typ : SlotType,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.node_seq = fr.node_seq + 1
  fr.prev_node = Some(elem)
  Ok(N3Effect::OpenSlot(elem, typ, ret_state))
}

///|
/// 集合收口（尾元素后 `)`，ADR-003a）：无 rdf:rest rdf:nil 尾 quad（trig 的
/// 发射臂退役）——弹栈交 PopBnp，落位（非空 = 单一 BNode / 空 = nil 标记）
/// 与返回状态兑现在 pop_bnode_prop。
impl N3Actions for Hooks with fn list_nil(
  _self : Hooks,
  ctx : N3Context,
) -> Result[N3Effect, N3ActionError] {
  let _ = ctx // 槽位不动：决策全在 pop（帧携带）；保留形参对齐 trait 形状
  Ok(N3Effect::PopBnp)
}
