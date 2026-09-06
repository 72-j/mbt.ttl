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
  // 役5：KeywordA 活性随行旗标（引擎归位点置位）此刻兑现落 pk——Comma
  // 连发同谓词不再过 action，pk 快照直引保真；他谓词恒 Normal
  ctx.pred_kind = if ctx.kw_a_live { PredKind::KwA } else { PredKind::Normal }
  ctx.kw_a_live = false
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
    as_pred: false,
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
/// Bnp 帧与 Collection 帧共用本动作（Formula 帧同径：身份 = { span，无 nil 特判）；目标裁决：
///     （零长 span = 物化层 rdf:nil 识别位；ADR-003a"无 rdf:nil 发射"指不发
///     rest 链尾 quad，值位 nil 标记保留）
///   - 非空集合：单一 BNode = fr.open_span（开括号即身份，ADR-003a 不展开链）
///   - `[]`：fresh BNode = fr.open_span
/// 序上恒在 EmitQuad 之后：emit 先 snapshot 后收拾，恢复值取自帧不受 PredObj 收拾波及
impl N3Actions for Hooks with fn pop_bnode_prop(_self : Hooks, ctx : N3Context) -> Result[
  N3Effect,
  N3ActionError,
] {
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
      // 役10 三向：公式谓词位帧（as_pred）身份落 p 槽；主/宾位随 as_subject
      if fr.as_pred {
        ctx.predicate = Some(target)
      } else if fr.as_subject {
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
    as_pred: false,
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
      N3Actions::open_formula(self, ctx, open_span, false, ret_state)
  }
}

///|
/// 公式区域栈：开公式 action（ADR-002：不透明图项，内容不断言）——外层槽位
/// 快照入帧（s/p/g + ret_state；身份 = { span，pop 时按 as_subject 落位），
/// 内层从新主语起（s/p 清空——与 Bnp 占 s 槽的语义分野）。
impl N3Actions for Hooks with fn open_formula(
  _self : Hooks,
  ctx : N3Context,
  open_span : Span,
  as_subject : Bool,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  ctx.slot_stack.push({
    typ: SlotType::Formula,
    open_span,
    subject: ctx.subject,
    predicate: ctx.predicate,
    graph: ctx.graph,
    ret_state,
    as_subject,
    as_pred: false,
    prev_node: None,
    node_seq: 0,
  })
  ctx.subject = None
  ctx.predicate = None
  Ok(N3Effect::Continue)
}

///|
/// 公式收口 action：裸 PopBnp 意图（公式内容零发射；pop_bnode_prop 共享机械
/// 恢复外层槽位 + 身份落位 + 返回状态兑现——list_nil 同款形状）。

///|
/// 公式谓词位入口（役10）：帧携 as_pred——弹栈身份落外层谓词槽（bad-preds-formula
/// 正典 `:e { :f :g :h } :i .`）。入帧快照/内层清空与 open_formula 全同，仅
/// as_pred 置位；ret_state 由行定夺（各区宾态）。
impl N3Actions for Hooks with fn open_formula_pred(
  _self : Hooks,
  ctx : N3Context,
  open_span : Span,
  _as_subject : Bool,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  ctx.slot_stack.push({
    typ: SlotType::Formula,
    open_span,
    subject: ctx.subject,
    predicate: ctx.predicate,
    graph: ctx.graph,
    ret_state,
    as_subject: false,
    as_pred: true,
    prev_node: None,
    node_seq: 0,
  })
  ctx.subject = None
  ctx.predicate = None
  Ok(N3Effect::Continue)
}

///|
/// 区域栈：`[]` 谓词位入口（役11，anon-prop 正典）——同 open_formula_pred 教义，
/// 帧携 as_pred=true（pop 三向支役10 已建）；内容 = fresh 主语属性表
///（subject 装 fresh，同 open_bnode_prop），帧型 BnodeProp。
impl N3Actions for Hooks with fn open_bnode_pred(
  _self : Hooks,
  ctx : N3Context,
  open_span : Span,
  _as_subject : Bool,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  ctx.slot_stack.push({
    typ: SlotType::BnodeProp,
    open_span,
    subject: ctx.subject,
    predicate: ctx.predicate,
    graph: ctx.graph,
    ret_state,
    as_subject: false,
    as_pred: true,
    prev_node: None,
    node_seq: 0,
  })
  ctx.subject = Some(open_span)
  ctx.predicate = None
  Ok(N3Effect::Continue)
}

///|
impl N3Actions for Hooks with fn close_formula(_self : Hooks, ctx : N3Context) -> Result[
  N3Effect,
  N3ActionError,
] {
  let _ = ctx
  Ok(N3Effect::PopBnp)
}

// —— !/^ 路径区（ADR-006 + spec §4.7：跟随谓语；役3）——
// desugar = fresh 中间节点链：每操作符一个中间节点（身份 = 操作符 token
// span），中间跳急发 EmitQuad(SPO)，末跳只装 ctx 槽（发射交既有收口行
// Dot/Comma/Semicolon——零新发射语义）。方向旗标 path_fwd 随操作符事件
// 立起：path_fwd/path_bwd 立入口方向（基动词在场则急兑现基跳），
// path_hop_fwd/path_hop_bwd 兑现在押步并立下一步方向。

///|
/// 跳兑现共享机械：押步动词 × 当前源 × fresh（操作符 span）装槽后急发
/// EmitQuad(SPO)。方向 fwd = 正跳 (源, 动词, fresh)；反跳 (fresh, 动词, 源)。
/// 新鲜节点接棒为源；押步清账；旗标换新方向（hop_* 变体各立各的）。
fn path_hop_resolve(
  ctx : N3Context,
  fresh : Span,
  fwd : Bool,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  // 发射方向 = pend 边所属操作符（前一 op 定的旗标）；fwd 参数 = 本 op 方向，
  // 发射后才翻——!P^Q 链首边才不会被末 op 的 ^ 带反
  if ctx.path_fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(verb)
    ctx.object = Some(fresh)
  } else {
    ctx.subject = Some(fresh)
    ctx.predicate = Some(verb)
    ctx.object = Some(src)
  }
  ctx.path_src = Some(fresh)
  ctx.path_pend = None
  ctx.path_fwd = fwd
  Ok(N3Effect::EmitQuad(ResetScope::SPO))
}

///|
/// 路径入口 `!`：立正跳旗标。基动词在场（`S P!…`）= bang 证明非末跳，
/// 基跳急兑现（fresh = 操作符 span）；裸入口（`S !P O`）源 = 主语。
impl N3Actions for Hooks with fn path_fwd(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.path_fwd = true
  ctx.path_pend = None
  match ctx.predicate {
    Some(_) => {
      ctx.object = Some(op)
      ctx.path_src = Some(op)
      Ok(N3Effect::EmitQuad(ResetScope::SPO))
    }
    None => {
      ctx.path_src = ctx.subject
      Ok(N3Effect::Continue)
    }
  }
}

///|
/// 路径入口 `^`：立反跳旗标；基跳兑现同 path_fwd（基动词恒正跳——
/// `^` 只管辖它后面的步）。
impl N3Actions for Hooks with fn path_bwd(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.path_fwd = false
  ctx.path_pend = None
  match ctx.predicate {
    Some(_) => {
      ctx.object = Some(op)
      ctx.path_src = Some(op)
      Ok(N3Effect::EmitQuad(ResetScope::SPO))
    }
    None => {
      ctx.path_src = ctx.subject
      Ok(N3Effect::Continue)
    }
  }
}

///|
/// 路径步进：押步动词入账（方向取旗标；Iri/PrefName 两行落此）。
impl N3Actions for Hooks with fn path_step(
  _self : Hooks,
  ctx : N3Context,
  verb : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.path_pend = Some(verb)
  Ok(N3Effect::Continue)
}

///|
/// 路径中跳 `!`：押步急兑现（fresh = 本操作符 span），立正跳旗标。
impl N3Actions for Hooks with fn path_hop_fwd(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
) -> Result[N3Effect, N3ActionError] {
  path_hop_resolve(ctx, op, true)
}

///|
/// 路径中跳 `^`：押步急兑现，立反跳旗标。
impl N3Actions for Hooks with fn path_hop_bwd(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
) -> Result[N3Effect, N3ActionError] {
  path_hop_resolve(ctx, op, false)
}

///|
/// 路径末跳：终跳装 ctx 槽（正跳 (源,动词,宾) / 反跳 (宾,动词,源)），
/// 路径账清——发射交既有收口行（Dot → EmitQuad(SPO) / Comma → Object 粒度
/// / Semicolon → PredObj 粒度），延续位语义（`,` 每宾一发、`;` 换谓词）
/// 全部免费继承。
impl N3Actions for Hooks with fn path_end(
  _self : Hooks,
  ctx : N3Context,
  obj : Span,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  if ctx.path_fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(verb)
    ctx.object = Some(obj)
  } else {
    ctx.subject = Some(obj)
    ctx.predicate = Some(verb)
    ctx.object = Some(src)
  }
  ctx.path_src = None
  ctx.path_pend = None
  Ok(N3Effect::Continue)
}

///|
/// 路径末跳复合节点（`[`/`(`/`{`）：hop 先装 s/p（嵌套帧外快照携带——
/// pop 恢复后收口行发连接边 (源, 押步动词, fresh帧身份)），再借共享帧
/// 机械开嵌套（open_slot 按 typ 分派）。反跳拒：pop 机械 object 槽不帧管，
/// 反跳连接边 (fresh, 动词, 源) 无处落位——诚实报错非静默错装。
impl N3Actions for Hooks with fn path_end_nested(
  self : Hooks,
  ctx : N3Context,
  open_span : Span,
  typ : SlotType,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  if !ctx.path_fwd {
    // 拒绝落点：state 已随行进到嵌套态——原地拨回 ExpectDotOrGraph，
    // 后续流走 UnexpectedEvent 正规恢复（skip-to-Dot），不出垃圾内部
    // quad（BusinessFailed 本身不 resync，context 带病续跑）
    ctx.path_src = None
    ctx.path_pend = None
    ctx.state = N3ExpectDotOrGraph
    return Err(
      N3ActionError::BusinessFailed(
        "Reverse path cannot end at a composite node",
      ),
    )
  }
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  ctx.subject = Some(src)
  ctx.predicate = Some(verb)
  ctx.path_src = None
  ctx.path_pend = None
  N3Actions::open_slot(self, ctx, open_span, typ, ret_state)
}

// —— 尾随路径区（役14，B 桶）：主位/元素位/宾位路径贴前置节点——语料
// 16/16 全此形态，役3 裸入口谓词位读法（path_end 吞下一原子当终跳宾语）
// 语料零出现，入口行改道。desugar（F = 操作符 token span fresh，ADR-006
// 同教义；链账全字段化 path_src/path_pend/path_tail，statement 槽位不中途
// 占用——发射快照与回装分行动作过单效果墙）：
//   S !P verb O ≡ (S,P,F) . (F,verb,O)     S ^P verb O ≡ (F,P,S) . (F,verb,O)
//   (…, N!P, …) ≡ 边 (N,P,F)，元素 := F     obj 位 N!P ≡ (S,P,F) . (N,P,F)

///|
/// 尾随跳兑现共享机械：押步 × 链头源 × 尾 fresh 装槽急发 EmitQuad(SPO)，
/// 链头接棒为旧尾、尾换新 op span。主位/宾位中跳共用（元素位多一帧记账
/// 见 path_elem_hop）。
fn path_tail_hop_resolve(
  ctx : N3Context,
  fresh : Span,
  fwd : Bool,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  let tail = match ctx.path_tail {
    Some(tail) => tail
    None => return Err(N3ActionError::BusinessFailed("Path tail missing"))
  }
  if fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(verb)
    ctx.object = Some(tail)
  } else {
    ctx.subject = Some(tail)
    ctx.predicate = Some(verb)
    ctx.object = Some(src)
  }
  ctx.path_src = Some(tail)
  ctx.path_tail = Some(fresh)
  ctx.path_pend = None
  ctx.path_fwd = fwd
  Ok(N3Effect::EmitQuad(ResetScope::SPO))
}

///|
/// 主位尾随入口/首跳 `!`/`^`：源 = 主语槽（statement 主语 = 终跳 fresh，
/// path_subj_object 落位），尾 = 本操作符 span；主位槽不动。
impl N3Actions for Hooks with fn path_subj_trail(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
  fwd : Bool,
) -> Result[N3Effect, N3ActionError] {
  ctx.path_src = ctx.subject
  ctx.path_tail = Some(op)
  ctx.path_pend = None
  ctx.path_fwd = fwd
  Ok(N3Effect::Continue)
}

///|
/// 宾位尾随入口 `N!P`/`N^P`（`"v"^lang:eng` 形）：statement s/p 快照入帧
///（open_span = 尾 span——pop 落位 object := 尾白得），statement 宾位改尾；
/// 源 = 原宾位节点。
impl N3Actions for Hooks with fn path_obj_trail(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
  fwd : Bool,
) -> Result[N3Effect, N3ActionError] {
  let node = match ctx.object {
    Some(node) => node
    None => return Err(N3ActionError::BusinessFailed("Object missing"))
  }
  ctx.slot_stack.push({
    typ: SlotType::BnodeProp,
    open_span: op,
    subject: ctx.subject,
    predicate: ctx.predicate,
    graph: ctx.graph,
    ret_state: N3ExpectDotOrGraph,
    as_subject: false,
    as_pred: false,
    prev_node: None,
    node_seq: 0,
  })
  ctx.object = Some(op)
  ctx.path_src = Some(node)
  ctx.path_tail = Some(op)
  ctx.path_pend = None
  ctx.path_fwd = fwd
  Ok(N3Effect::Continue)
}

///|
/// 元素位尾随入口 `( N!P … )`：源 = 帧 prev_node（当前元素），元素随行改
/// 尾（若路径就此收口，元素 = 尾 fresh）。
impl N3Actions for Hooks with fn path_elem_trail(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
  fwd : Bool,
) -> Result[N3Effect, N3ActionError] {
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  let node = match fr.prev_node {
    Some(node) => node
    None => return Err(N3ActionError::BusinessFailed("List element missing"))
  }
  ctx.path_src = Some(node)
  ctx.path_tail = Some(op)
  ctx.path_pend = None
  ctx.path_fwd = fwd
  fr.prev_node = Some(op)
  Ok(N3Effect::Continue)
}

///|
/// 主位/宾位中跳 `!`/`^`：押步急兑现（共享机械）。
impl N3Actions for Hooks with fn path_hop_tail(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
  fwd : Bool,
) -> Result[N3Effect, N3ActionError] {
  path_tail_hop_resolve(ctx, op, fwd)
}

///|
/// 元素位中跳：共享兑现 + 帧 prev_node 随尾换新（元素恒 = 当前尾）。
impl N3Actions for Hooks with fn path_elem_hop(
  _self : Hooks,
  ctx : N3Context,
  op : Span,
  fwd : Bool,
) -> Result[N3Effect, N3ActionError] {
  let r = path_tail_hop_resolve(ctx, op, fwd)
  match list_top(ctx) {
    Ok(fr) => fr.prev_node = ctx.path_tail
    Err(_) => ()
  }
  r
}

///|
/// 主位尾跳收束（真谓词到位）：终跳边急发，真谓词押回账（path_subj_object
/// 落位）——发射与回装分行动作（单效果墙：EmitQuad 快照后收拾，回装值
/// 全在字段账不受波及）。
impl N3Actions for Hooks with fn path_subj_end(
  _self : Hooks,
  ctx : N3Context,
  verb : Span,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let step = match ctx.path_pend {
    Some(step) => step
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  let tail = match ctx.path_tail {
    Some(tail) => tail
    None => return Err(N3ActionError::BusinessFailed("Path tail missing"))
  }
  if ctx.path_fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(step)
    ctx.object = Some(tail)
  } else {
    ctx.subject = Some(tail)
    ctx.predicate = Some(step)
    ctx.object = Some(src)
  }
  ctx.path_pend = Some(verb)
  ctx.path_src = None
  Ok(N3Effect::EmitQuad(ResetScope::SPO))
}

///|
/// 主位尾随 statement 回装：主语 = 尾 fresh，谓词 = 押回的真谓词（pk 账
/// 兑现——`a` 缩写横跨尾跳保留活性），宾语 = 本原子；路径账清。
impl N3Actions for Hooks with fn path_subj_object(
  _self : Hooks,
  ctx : N3Context,
  obj : Span,
) -> Result[N3Effect, N3ActionError] {
  let tail = match ctx.path_tail {
    Some(tail) => tail
    None => return Err(N3ActionError::BusinessFailed("Path tail missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path verb missing"))
  }
  ctx.subject = Some(tail)
  ctx.predicate = Some(verb)
  ctx.pred_kind = if ctx.kw_a_live { PredKind::KwA } else { PredKind::Normal }
  ctx.kw_a_live = false
  ctx.object = Some(obj)
  ctx.path_tail = None
  ctx.path_pend = None
  Ok(N3Effect::Continue)
}

///|
/// 元素位尾跳后接下一元素：终跳边急发 + 元素记账（list_next 同体一体行动
/// 作——本原子即下一元素）。
impl N3Actions for Hooks with fn path_elem_end(
  _self : Hooks,
  ctx : N3Context,
  elem : Span,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  let tail = match ctx.path_tail {
    Some(tail) => tail
    None => return Err(N3ActionError::BusinessFailed("Path tail missing"))
  }
  if ctx.path_fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(verb)
    ctx.object = Some(tail)
  } else {
    ctx.subject = Some(tail)
    ctx.predicate = Some(verb)
    ctx.object = Some(src)
  }
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.node_seq = fr.node_seq + 1
  fr.prev_node = Some(elem)
  ctx.path_src = None
  ctx.path_tail = None
  ctx.path_pend = None
  Ok(N3Effect::EmitQuad(ResetScope::SPO))
}

///|
/// 元素位尾跳后接嵌套元素（`[`/`(`）：先开帧（open_slot 占 s 槽）后装边
/// 槽发射——序不可倒（开帧的 s/p 占位即被边快照覆写）。
impl N3Actions for Hooks with fn path_elem_end_nested(
  self : Hooks,
  ctx : N3Context,
  elem : Span,
  typ : SlotType,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  let tail = match ctx.path_tail {
    Some(tail) => tail
    None => return Err(N3ActionError::BusinessFailed("Path tail missing"))
  }
  match N3Actions::open_slot(self, ctx, elem, typ, ret_state) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  if ctx.path_fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(verb)
    ctx.object = Some(tail)
  } else {
    ctx.subject = Some(tail)
    ctx.predicate = Some(verb)
    ctx.object = Some(src)
  }
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.node_seq = fr.node_seq + 1
  fr.prev_node = Some(elem)
  ctx.path_src = None
  ctx.path_tail = None
  ctx.path_pend = None
  Ok(N3Effect::EmitQuad(ResetScope::SPO))
}

///|
/// 元素位尾跳收口（步后即 `)`）：终跳边急发 + 元素 := 尾 fresh，PopBnp 兑现
/// 收口——Sequence 序 = emit 先 snapshot 后收拾、帧恢复随其后（既有口径）。
impl N3Actions for Hooks with fn path_elem_close(
  _self : Hooks,
  ctx : N3Context,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  let tail = match ctx.path_tail {
    Some(tail) => tail
    None => return Err(N3ActionError::BusinessFailed("Path tail missing"))
  }
  if ctx.path_fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(verb)
    ctx.object = Some(tail)
  } else {
    ctx.subject = Some(tail)
    ctx.predicate = Some(verb)
    ctx.object = Some(src)
  }
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.prev_node = Some(tail)
  ctx.path_src = None
  ctx.path_tail = None
  ctx.path_pend = None
  Ok(N3Effect::Sequence([N3Effect::EmitQuad(ResetScope::SPO), N3Effect::PopBnp]))
}

///|
/// 宾位尾跳收口（Dot/Comma/Semicolon 到位）：终跳边急发，帧 ret_state 按
/// 收口事件改写（pop 兑现落位 object := 尾 + 返回状态）。
impl N3Actions for Hooks with fn path_obj_close(
  _self : Hooks,
  ctx : N3Context,
  ret_state : N3State,
) -> Result[N3Effect, N3ActionError] {
  let src = match ctx.path_src {
    Some(src) => src
    None => return Err(N3ActionError::BusinessFailed("Path source missing"))
  }
  let verb = match ctx.path_pend {
    Some(verb) => verb
    None => return Err(N3ActionError::BusinessFailed("Path step missing"))
  }
  let tail = match ctx.path_tail {
    Some(tail) => tail
    None => return Err(N3ActionError::BusinessFailed("Path tail missing"))
  }
  if ctx.path_fwd {
    ctx.subject = Some(src)
    ctx.predicate = Some(verb)
    ctx.object = Some(tail)
  } else {
    ctx.subject = Some(tail)
    ctx.predicate = Some(verb)
    ctx.object = Some(src)
  }
  let fr = match list_top(ctx) {
    Ok(fr) => fr
    Err(e) => return Err(e)
  }
  fr.ret_state = ret_state
  ctx.path_src = None
  ctx.path_tail = None
  ctx.path_pend = None
  Ok(N3Effect::Sequence([N3Effect::EmitQuad(ResetScope::SPO), N3Effect::PopBnp]))
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
impl N3Actions for Hooks with fn list_nil(_self : Hooks, ctx : N3Context) -> Result[
  N3Effect,
  N3ActionError,
] {
  let _ = ctx // 槽位不动：决策全在 pop（帧携带）；保留形参对齐 trait 形状
  Ok(N3Effect::PopBnp)
}

// —— @keywords 关键词声明（役5）：cwm 口径全量重置——台账跨语句存续
//（ResetScope 只触 s/p/o/g，不触台账；新 @keywords 入口即清账重声明）——

///|
/// @keywords 入口：清台账 + seen 置位（旧 listed 词即刻失格，含 `a`）
impl N3Actions for Hooks with fn kw_begin(_self : Hooks, ctx : N3Context) -> Result[
  N3Effect,
  N3ActionError,
] {
  ctx.kw_ledger.clear()
  ctx.kw_directive_seen = true
  Ok(N3Effect::Continue)
}

///|
/// @keywords 收词：词 span 入台账（listed 词主/谓/宾全位可用——引擎归位点
/// 嗅探 Unknown→KeywordX；`a` 复活 = 台账含 a，KeywordA 嗅探放行）
impl N3Actions for Hooks with fn declare_keyword(
  _self : Hooks,
  ctx : N3Context,
  word : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.kw_ledger.push(word)
  Ok(N3Effect::Continue)
}

// —— is/of 集合等价倒装（役6：`X is P of Y ≡ Y P X`）——
// grammar 序槽位（X 主 / P 谓 / Y 宾）不动，语义序出账全在引擎发射点互换
//（take_pending_quad）：is_src = 交换键（主语 token span，全局唯一），

///|
/// of 收倒装头：主语 token span 入 is_src 作交换键 + 槽深入 is_depth 定清账界
///（span 全局唯一 ⇒ 嵌套 bnp/集合内层 fresh 主语天然错键不换）
impl N3Actions for Hooks with fn is_of(_self : Hooks, ctx : N3Context) -> Result[
  N3Effect,
  N3ActionError,
] {
  ctx.is_src = ctx.subject
  ctx.is_depth = ctx.slot_stack.length()
  Ok(N3Effect::Continue)
}

// —— `=` 等同谓词（役7，ADR-005）：owl:sameAs 语法糖——役4 同构，操作符
// token 占谓词槽，语义身份在 pk；Comma 连发同谓词不过 action（pk 直引保真）——

///|
/// `=` 谓词：= token span 占谓词槽 + pk=SameAs（物化层展开 owl:sameAs）
impl N3Actions for Hooks with fn set_sameas(
  _self : Hooks,
  ctx : N3Context,
  payload : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.predicate = Some(payload)
  ctx.pred_kind = SameAs
  Ok(N3Effect::Continue)
}

///|
/// 注解开壳（役8）：抄录锚 s/o 入壳账（槽位不动、不发射不收拾——发射意图
/// 由动作返回值承载：主 quad 仍锚主语预发射，快照发生时壳账尚无旗 = 锚身出账）
impl N3Actions for Hooks with fn annot_open(_self : Hooks, ctx : N3Context) -> Result[
  N3Effect,
  N3ActionError,
] {
  ctx.annot_s = ctx.subject
  ctx.annot_o = ctx.object
  ctx.subj_shell = false
  ctx.annot_close = false
  // 主 quad 预发射（锚主语）：PredObj 粒度清 p/o、保 s——体区首动词前
  // 槽位无发射，annot_body_verb 才开旗
  Ok(N3Effect::EmitQuad(ResetScope::PredObj))
}

///|
/// 注解体动词（役8）：首动词开体区旗（交换在引擎发射点 take：键 = subj ==
/// annot_s），谓词槽位照 set_predicate 口径（kw_a_live 兑现落 pk）
impl N3Actions for Hooks with fn annot_body_verb(
  _self : Hooks,
  ctx : N3Context,
  payload : Span,
) -> Result[N3Effect, N3ActionError] {
  ctx.subj_shell = true
  ctx.predicate = Some(payload)
  ctx.pred_kind = if ctx.kw_a_live { PredKind::KwA } else { PredKind::Normal }
  ctx.kw_a_live = false
  Ok(N3Effect::Continue)
}

///|
/// 注解收口（役8）：置收口旗 + 返回末体 quad 发射——take 消费旗（壳交换先
/// 兑现在本 quad 上）后还原清账；槽位经 PredObj 粒度保锚主语，`;` 续锚直落
impl N3Actions for Hooks with fn annot_end(_self : Hooks, ctx : N3Context) -> Result[
  N3Effect,
  N3ActionError,
] {
  ctx.annot_close = true
  Ok(N3Effect::EmitQuad(ResetScope::PredObj))
}

///|
/// 注解静默收口（役8）：体尾分号后 |}——末体 quad 已随分号行出账（壳交换
/// 已兑现），直清壳账零发射
impl N3Actions for Hooks with fn annot_close_silent(
  _self : Hooks,
  ctx : N3Context,
) -> Result[N3Effect, N3ActionError] {
  ctx.annot_close = false
  ctx.subj_shell = false
  ctx.annot_s = None
  ctx.annot_o = None
  Ok(N3Effect::Continue)
}
