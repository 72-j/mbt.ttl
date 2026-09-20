// ===== 数据面门自证（役 A：白盒直调 + 负控，2026-09-20）=====
//
// 数据面（`data_face.mbt`）的判定臂里有一族"红-only"代码：不匹配时才走的消息渲染
// 与防御臂——平时测试全绿就走不到，正是 §6.4.1"假绿"最爱的角落。本文件**直调包内
// 私有函数**把它们点亮，每条负控都断言【确实红 + 理由文本逐字对得上】（§6.2）。
// 口径：`RefId` 只有 Debug 没有 Show ⇒ 判据用 `id` 解包探针，不 assert_eq 整块。

///|
/// `RefId` 解包探针：`Ok(Some(x))` → `Some(x.id)`；`Ok(None)`/`Err` 都落 `None`
/// （区分两者用 `wb_err`/直接 match，不靠本探针）。
fn wb_ok_id(r : Result[RefId?, String]) -> Int? {
  match r {
    Ok(Some(v)) => Some(v.id)
    _ => None
  }
}

///|
/// 错误文本探针：`Err(why)` → `Some(why)`，其余 `None`。
fn wb_err(r : Result[RefId?, String]) -> String? {
  match r {
    Ok(_) => None
    Err(why) => Some(why)
  }
}

///|
/// 期望值探针：`Ok(v)` 且与 `want` 同型等值 → true（跨型走 `face_value_eq` 的 `_ => false`）。
fn wb_face_is(r : Result[FaceValue, String], want : FaceValue) -> Bool {
  match r {
    Ok(v) => face_value_eq(v, want)
    Err(_) => false
  }
}

///|
fn wb_face_err(r : Result[FaceValue, String]) -> String? {
  match r {
    Ok(_) => None
    Err(why) => Some(why)
  }
}

///|
/// 目标位探针：`None`（无帧/未知位/非帧目标）→ true（`FaceValue` 无 Eq/Debug，不 assert_eq 整块）
fn wb_face_none(r : FaceValue?) -> Bool {
  match r {
    Some(_) => false
    None => true
  }
}

///|
fn wb_rid(id : Int) -> RefId {
  { id, }
}

///|
/// 合成槽位视图（8 槽全位；`path_fwd` 可翻）
fn wb_view(fwd : Bool) -> SlotView {
  {
    subject: Some(wb_rid(1)),
    predicate: Some(wb_rid(2)),
    object: None,
    graph: Some(wb_rid(3)),
    path_src: Some(wb_rid(4)),
    path_pend: None,
    path_tail: Some(wb_rid(5)),
    path_fwd: fwd,
  }
}

///|
/// 合成帧（各值域都给非平凡值）
fn wb_frame() -> FaceFrame {
  {
    is_formula: false,
    open_span: wb_rid(20),
    subject: Some(wb_rid(21)),
    predicate: None,
    graph: Some(wb_rid(22)),
    ret_state_name: "ExpectObject",
    as_subject: true,
    as_pred: false,
    prev_node: Some(wb_rid(23)),
    node_seq: 7,
  }
}

///|
/// 次顶帧（open_span 换值、subject 置空——验偏移寻址用）
fn wb_frame2() -> FaceFrame {
  { ..wb_frame(), open_span: wb_rid(30), subject: None, }
}

///|
fn wb_ledger() -> FaceLedger {
  { frames: [wb_frame()], is_src: Some(wb_rid(11)), is_depth: 1, }
}

///|
fn wb_ledger2() -> FaceLedger {
  { frames: [wb_frame(), wb_frame2()], is_src: None, is_depth: 2, }
}

///|
fn wb_ledger_empty() -> FaceLedger {
  { frames: [], is_src: None, is_depth: 0, }
}

///|
fn wb_payload() -> RefId {
  wb_rid(99)
}

///|
test "wb·parse：七列全落位 + 注释/空行跳过 + 列数≠7 跳过 + 头缺 + 跳过（TAB 所有权·消费侧）" {
  let text = "# format: v3\n\nA+B\tAct\tContinue\tsubject=ctx.subject,is_src=payload\t-\t-\targs0=payload\nBADLINE\nNoPlus\tAct\tContinue\t-\t-\t-\t-\nC+D\tAct2\tPopBnp\tobject=none\t-\t-\t-\n"
  let rows = parse_data_face_rows(text)
  // 七列行 2 条全落位；`BADLINE`（1 列）与 `NoPlus`（头缺 `+`）跳过——行数钉子正是靠这个红
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].from, "A")
  assert_eq(rows[0].on, "B")
  assert_eq(rows[0].action, "Act")
  assert_eq(rows[0].returns, "Continue")
  assert_eq(rows[0].writes, ["subject=ctx.subject", "is_src=payload"])
  assert_eq(rows[0].args, ["args0=payload"])
  assert_eq(rows[1].from, "C")
  assert_eq(rows[1].on, "D")
  assert_eq(rows[1].returns, "PopBnp")
  assert_eq(rows[1].writes, ["object=none"])
  assert_eq(rows[1].args, [])
  // 负控：字段含 TAB ⇒ 列数 > 7 ⇒ 整行跳过（不留静默截断；§AN.12 所有权口径）
  let over = parse_data_face_rows(
    "A+B\tAct\tContinue\tsubject=none\t-\t-\t-\tEXTRA\n",
  )
  assert_eq(over.length(), 0)
}

///|
test "wb·scope_reset_slots：四 scope 各自清槽 + 非发射行不清" {
  assert_eq(scope_reset_slots("EmitQuad(All)"), [
    "subject", "predicate", "object", "graph",
  ])
  assert_eq(scope_reset_slots("EmitQuad(SPO)"), [
    "subject", "predicate", "object",
  ])
  assert_eq(scope_reset_slots("EmitQuad(PredObj)"), ["predicate", "object"])
  assert_eq(scope_reset_slots("EmitQuad(Object)"), ["object"])
  assert_eq(scope_reset_slots("Continue"), [])
}

///|
test "wb·slot 面：八槽在观测面内 + slot_get 未知名兜底 None（含 bool 槽 path_fwd）" {
  let view = wb_view(true)
  for
    name in [
      "subject", "predicate", "object", "graph", "path_src", "path_pend", "path_tail",
      "path_fwd",
    ] {
    assert_true(slot_in_view(name))
  }
  assert_false(slot_in_view("bogus"))
  assert_eq(wb_ok_id(Ok(slot_get(view, "subject"))), Some(1))
  assert_eq(wb_ok_id(Ok(slot_get(view, "predicate"))), Some(2))
  assert_eq(wb_ok_id(Ok(slot_get(view, "graph"))), Some(3))
  assert_eq(wb_ok_id(Ok(slot_get(view, "path_src"))), Some(4))
  assert_eq(wb_ok_id(Ok(slot_get(view, "path_tail"))), Some(5))
  // `path_pend` 现值 None；`path_fwd` 是 bool 槽不在 `RefId?` 值域 ⇒ 兜底 None
  assert_eq(wb_ok_id(Ok(slot_get(view, "path_pend"))), None)
  assert_eq(wb_ok_id(Ok(slot_get(view, "path_fwd"))), None)
  assert_eq(wb_ok_id(Ok(slot_get(view, "bogus"))), None)
}

///|
test "wb·frame_address：top/below/legacy 三形 + 非帧目标 None" {
  assert_eq(frame_address("frame.top.subject"), Some((0, "subject")))
  assert_eq(frame_address("frame.below.open_span"), Some((1, "open_span")))
  // legacy 无地址形按帧顶读（容错用）
  assert_eq(frame_address("frame.graph"), Some((0, "graph")))
  assert_eq(frame_address("subject"), None)
  assert_eq(frame_address("is_src"), None)
}

///|
test "wb·frame_ref_field：Span 值域五位 + 非 RefId 位兜底 None" {
  let f = wb_frame()
  assert_eq(frame_ref_field(f, "open_span"), Some(wb_rid(20)))
  assert_eq(frame_ref_field(f, "prev_node"), Some(wb_rid(23)))
  assert_eq(frame_ref_field(f, "subject"), Some(wb_rid(21)))
  assert_eq(frame_ref_field(f, "predicate"), None)
  assert_eq(frame_ref_field(f, "graph"), Some(wb_rid(22)))
  // `ret_state`/`node_seq`/未知名都不在 `RefId?` 值域 ⇒ 兜底 None
  assert_eq(frame_ref_field(f, "ret_state"), None)
  assert_eq(frame_ref_field(f, "node_seq"), None)
  assert_eq(frame_ref_field(f, "bogus"), None)
}

///|
test "wb·face_value_eq：同型四对等值 + 跨型四对必 false（_ => false 臂）" {
  assert_true(face_value_eq(FRef(Some(wb_rid(7))), FRef(Some(wb_rid(7)))))
  assert_false(face_value_eq(FRef(Some(wb_rid(7))), FRef(None)))
  assert_true(face_value_eq(FBool(true), FBool(true)))
  assert_false(face_value_eq(FBool(true), FBool(false)))
  assert_true(face_value_eq(FInt(3), FInt(3)))
  assert_false(face_value_eq(FInt(3), FInt(4)))
  assert_true(face_value_eq(FState("ExpectObject"), FState("ExpectObject")))
  assert_false(face_value_eq(FState("A"), FState("B")))
  // 跨型：同字面不同型也必 false（态名 "3" ≠ FInt(3) 等）
  assert_false(face_value_eq(FRef(None), FBool(true)))
  assert_false(face_value_eq(FBool(false), FInt(0)))
  assert_false(face_value_eq(FInt(3), FState("3")))
  assert_false(face_value_eq(FState("x"), FRef(None)))
}

///|
test "wb·face_value_text：四型渲染逐臂" {
  assert_eq(face_value_text(FRef(None)), "None")
  assert_eq(face_value_text(FRef(Some(wb_rid(9)))), "Some(9)")
  assert_eq(face_value_text(FBool(true)), "true")
  assert_eq(face_value_text(FBool(false)), "false")
  assert_eq(face_value_text(FInt(42)), "42")
  assert_eq(face_value_text(FState("ExpectVerbOrEnd")), "ExpectVerbOrEnd")
}

///|
test "wb·resolve：argN 按 args 列解引用全表（payload/none/keep/ctx./形态未解析/列不足）" {
  let view = wb_view(true)
  let ledger = wb_ledger()
  let payload = wb_payload()
  // payload / Some(payload) 两种绑定写实
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "arg0", view, ledger, payload, ["payload"]),
    ),
    Some(99),
  )
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "arg0", view, ledger, payload, [
        "Some(payload)",
      ]),
    ),
    Some(99),
  )
  // args=none ⇒ 实参 None（不是合成载荷——trig §AN.5 裁定回灌）
  match
    resolve_span_source("subject", "arg0", view, ledger, payload, ["none"]) {
    Ok(None) => assert_true(true)
    _ => assert_false(true)
  }
  // keep = 行进前该槽值（缺省绑定的"无 span 事件"半）
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "arg0", view, ledger, payload, ["keep"]),
    ),
    Some(1),
  )
  // keep 在现值 None 的槽上 ⇒ Ok(None)
  match resolve_span_source("object", "arg0", view, ledger, payload, ["keep"]) {
    Ok(None) => assert_true(true)
    _ => assert_false(true)
  }
  // ctx.<槽> 绑定：读行进前值
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "arg0", view, ledger, payload, [
        "ctx.graph",
      ]),
    ),
    Some(3),
  )
  // 负控①：args 列不足——确实红，理由文本对得上（含 args 列回显）
  assert_eq(
    wb_err(
      resolve_span_source("subject", "arg1", view, ledger, payload, ["payload"]),
    ),
    Some("arg1（args 列不足：payload）"),
  )
  // 负控②：绑定形态未解析——确实红，理由文本对得上
  assert_eq(
    wb_err(
      resolve_span_source("subject", "arg0", view, ledger, payload, [
        "state:Foo",
      ]),
    ),
    Some("arg0=「state:Foo」（形态未解析）"),
  )
}

///|
test "wb·resolve：fwd:/nfwd: 按行进前旗二选一（递归）+ 缺 | 负控" {
  let payload = wb_payload()
  // path_fwd = true ⇒ fwd: 取前半（ctx.subject），nfwd: 取后半（ctx.graph）
  assert_eq(
    wb_ok_id(
      resolve_span_source(
        "subject",
        "fwd:ctx.subject|ctx.graph",
        wb_view(true),
        wb_ledger(),
        payload,
        [],
      ),
    ),
    Some(1),
  )
  // `nfwd:` 前缀只剥壳，选定逻辑与 `fwd:` 同轴（运行时 nfwd 行已在投影侧坍缩成定值）
  assert_eq(
    wb_ok_id(
      resolve_span_source(
        "subject",
        "nfwd:ctx.subject|ctx.graph",
        wb_view(true),
        wb_ledger(),
        payload,
        [],
      ),
    ),
    Some(1),
  )
  // path_fwd = false ⇒ 两式对调
  assert_eq(
    wb_ok_id(
      resolve_span_source(
        "subject",
        "fwd:ctx.subject|ctx.graph",
        wb_view(false),
        wb_ledger(),
        payload,
        [],
      ),
    ),
    Some(3),
  )
  // 递归半区还可再套条件式/词表（`none` 终点）
  match
    resolve_span_source(
      "subject",
      "nfwd:none|ctx.subject",
      wb_view(true),
      wb_ledger(),
      payload,
      [],
    ) {
    Ok(None) => assert_true(true)
    _ => assert_false(true)
  }
  // 负控：条件式缺 `|`——确实红，理由文本对得上
  assert_eq(
    wb_err(
      resolve_span_source(
        "subject",
        "fwd:ctx.subject",
        wb_view(true),
        wb_ledger(),
        payload,
        [],
      ),
    ),
    Some("fwd:ctx.subject（条件式缺 `|`）"),
  )
}

///|
test "wb·resolve：ctx. 直读七槽 + 面外/bool 槽负控 + frame. 帧读 + 非值域/帧栈空负控 + 首片不解析" {
  let view = wb_view(true)
  let payload = wb_payload()
  let ledger = wb_ledger()
  // 直读：七槽词表（path_pend 现值 None 也照读）
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "ctx.subject", view, ledger, payload, []),
    ),
    Some(1),
  )
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "ctx.predicate", view, ledger, payload, []),
    ),
    Some(2),
  )
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "ctx.graph", view, ledger, payload, []),
    ),
    Some(3),
  )
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "ctx.path_src", view, ledger, payload, []),
    ),
    Some(4),
  )
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "ctx.path_tail", view, ledger, payload, []),
    ),
    Some(5),
  )
  match
    resolve_span_source("subject", "ctx.path_pend", view, ledger, payload, []) {
    Ok(None) => assert_true(true)
    _ => assert_false(true)
  }
  // 负控③：面外/bool 槽——确实红，理由文本对得上
  assert_eq(
    wb_err(
      resolve_span_source("subject", "ctx.path_fwd", view, ledger, payload, []),
    ),
    Some("ctx.path_fwd（源槽在观测面外/bool 槽）"),
  )
  assert_eq(
    wb_err(
      resolve_span_source("subject", "ctx.bogus", view, ledger, payload, []),
    ),
    Some("ctx.bogus（源槽在观测面外/bool 槽）"),
  )
  // 帧读：按行进前帧顶
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "frame.prev_node", view, ledger, payload, []),
    ),
    Some(23),
  )
  assert_eq(
    wb_ok_id(
      resolve_span_source("subject", "frame.open_span", view, ledger, payload, []),
    ),
    Some(20),
  )
  // 负控④：帧位非 Span 值域——确实红
  assert_eq(
    wb_err(
      resolve_span_source("subject", "frame.node_seq", view, ledger, payload, []),
    ),
    Some("frame.node_seq（帧位非 Span 值域）"),
  )
  assert_eq(
    wb_err(
      resolve_span_source(
        "subject",
        "frame.is_formula",
        view,
        ledger,
        payload,
        [],
      ),
    ),
    Some("frame.is_formula（帧位非 Span 值域）"),
  )
  // 负控⑤：帧栈空——确实红
  assert_eq(
    wb_err(
      resolve_span_source(
        "subject",
        "frame.prev_node",
        view,
        wb_ledger_empty(),
        payload,
        [],
      ),
    ),
    Some("frame.prev_node（帧栈空）"),
  )
  // 负控⑥：首片不解析——确实红，理由文本对得上
  assert_eq(
    wb_err(resolve_span_source("subject", "bogus", view, ledger, payload, [])),
    Some("bogus（首片不解析）"),
  )
  assert_eq(
    wb_err(resolve_span_source("subject", "none", view, ledger, payload, [])),
    None,
  )
}

///|
test "wb·classify_write_source：面外目标负控（含 is_src 路由证词）" {
  // 面外目标：确实红。`is_src` 在对拍主链走 `classify_face_expect`；
  // 若误路由到本函数，此处就是红的（路由证词）。
  assert_eq(
    wb_err(
      classify_write_source(
        "is_src",
        "none",
        wb_view(true),
        wb_ledger(),
        wb_payload(),
        [],
      ),
    ),
    Some("is_src（槽在观测面外）"),
  )
  assert_eq(
    wb_err(
      classify_write_source(
        "bogus",
        "none",
        wb_view(true),
        wb_ledger(),
        wb_payload(),
        [],
      ),
    ),
    Some("bogus（槽在观测面外）"),
  )
  // 面内目标照常委托词表
  assert_eq(
    wb_ok_id(
      classify_write_source(
        "predicate",
        "ctx.predicate",
        wb_view(true),
        wb_ledger(),
        wb_payload(),
        [],
      ),
    ),
    Some(2),
  )
}

///|
test "wb·classify_face_expect：is_depth 门 / 倒装键委托 / 布尔位字面门 / ret_state / node_seq / 非帧目标" {
  let view = wb_view(true)
  let payload = wb_payload()
  // is_depth 只认 frames_len（值 = 行进前帧深）
  assert_true(
    wb_face_is(
      classify_face_expect(
        "is_depth",
        "frames_len",
        view,
        wb_ledger2(),
        payload,
        [],
      ),
      FInt(2),
    ),
  )
  // 负控⑦：is_depth 撞上别的来源——确实红，理由文本对得上
  assert_eq(
    wb_face_err(
      classify_face_expect("is_depth", "payload", view, wb_ledger(), payload, []),
    ),
    Some("payload（`is_depth` 只认 `frames_len`）"),
  )
  // is_src 委托来源词表（none / ctx. 两路）
  assert_true(
    wb_face_is(
      classify_face_expect("is_src", "none", view, wb_ledger(), payload, []),
      FRef(None),
    ),
  )
  assert_true(
    wb_face_is(
      classify_face_expect(
        "is_src",
        "ctx.subject",
        view,
        wb_ledger(),
        payload,
        [],
      ),
      FRef(Some(wb_rid(1))),
    ),
  )
  // 布尔帧位只认 true/false 字面（负控⑧：别的字面确实红）
  assert_true(
    wb_face_is(
      classify_face_expect(
        "frame.top.is_formula",
        "true",
        view,
        wb_ledger(),
        payload,
        [],
      ),
      FBool(true),
    ),
  )
  assert_true(
    wb_face_is(
      classify_face_expect(
        "frame.below.as_pred",
        "false",
        view,
        wb_ledger(),
        payload,
        [],
      ),
      FBool(false),
    ),
  )
  assert_eq(
    wb_face_err(
      classify_face_expect(
        "frame.top.as_subject",
        "yes",
        view,
        wb_ledger(),
        payload,
        [],
      ),
    ),
    Some("yes（布尔帧位只认 true/false 字面）"),
  )
  // ret_state：投影侧已写实成行目标态名
  assert_true(
    wb_face_is(
      classify_face_expect(
        "frame.top.ret_state",
        "ExpectObject",
        view,
        wb_ledger(),
        payload,
        [],
      ),
      FState("ExpectObject"),
    ),
  )
  // 负控⑨：node_seq 尚无可声明来源——确实红
  assert_eq(
    wb_face_err(
      classify_face_expect(
        "frame.top.node_seq",
        "0",
        view,
        wb_ledger(),
        payload,
        [],
      ),
    ),
    Some("0（node_seq 尚无可声明来源）"),
  )
  // 负控⑩：非帧面目标——确实红（槽位写不该路由进来）
  assert_eq(
    wb_face_err(
      classify_face_expect("subject", "none", view, wb_ledger(), payload, []),
    ),
    Some("subject（非帧面目标）"),
  )
  // Span 值域帧位落到来源词表
  assert_true(
    wb_face_is(
      classify_face_expect(
        "frame.top.open_span",
        "ctx.subject",
        view,
        wb_ledger(),
        payload,
        [],
      ),
      FRef(Some(wb_rid(1))),
    ),
  )
}

///|
test "wb·face_target_value：倒装两槽直读 + 偏移寻址（top/below）+ 栈深不足/未知位 None" {
  let ledger = wb_ledger()
  let ledger2 = wb_ledger2()
  assert_true(
    face_value_eq(
      face_target_value(ledger, "is_src").unwrap(),
      FRef(Some(wb_rid(11))),
    ),
  )
  assert_true(
    face_value_eq(face_target_value(ledger, "is_depth").unwrap(), FInt(1)),
  )
  // top = 栈顶（偏移 0）
  assert_true(
    face_value_eq(
      face_target_value(ledger2, "frame.top.open_span").unwrap(),
      FRef(Some(wb_rid(30))),
    ),
  )
  assert_true(
    face_value_eq(
      face_target_value(ledger2, "frame.top.subject").unwrap(),
      FRef(None),
    ),
  )
  assert_true(
    face_value_eq(
      face_target_value(ledger2, "frame.top.ret_state").unwrap(),
      FState("ExpectObject"),
    ),
  )
  assert_true(
    face_value_eq(
      face_target_value(ledger2, "frame.top.node_seq").unwrap(),
      FInt(7),
    ),
  )
  assert_true(
    face_value_eq(
      face_target_value(ledger2, "frame.top.is_formula").unwrap(),
      FBool(false),
    ),
  )
  // below = 次顶（偏移 1）——同一字段两张帧两个值
  assert_true(
    face_value_eq(
      face_target_value(ledger2, "frame.below.subject").unwrap(),
      FRef(Some(wb_rid(21))),
    ),
  )
  assert_true(
    face_value_eq(
      face_target_value(ledger2, "frame.below.open_span").unwrap(),
      FRef(Some(wb_rid(20))),
    ),
  )
  // 单帧账本上 below 就是栈深不足 ⇒ None（"（无帧）"理由的来源）
  assert_true(wb_face_none(face_target_value(ledger, "frame.below.subject")))
  assert_true(
    wb_face_none(face_target_value(wb_ledger_empty(), "frame.top.subject")),
  )
  // 未知位/非帧目标都 None
  assert_true(wb_face_none(face_target_value(ledger, "frame.top.bogus")))
  assert_true(wb_face_none(face_target_value(ledger, "bogus")))
}

///|
test "wb·response_short：五变体渲染" {
  assert_eq(response_short(Continue), "Continue")
  assert_eq(
    response_short(
      EmitQuad({ subject: None, predicate: None, object: None, graph: None, }),
    ),
    "EmitQuad",
  )
  assert_eq(response_short(Done), "Done")
  assert_eq(response_short(Error(42)), "Error(42)")
  assert_eq(response_short(Batch([Continue, Done])), "Batch(2)")
}

///|
/// 对拍级负控（合成行）：确实红 + 理由文本，锚的是 `data_face_compare` 的分派/防御臂。
test "wb·对拍负控：被弹帧写防御位如实入册（§AN.14 退步哨兵）" {
  let row : DataFaceRow = {
    from: "ExpectObject",
    on: "Iri",
    action: "wb_probe",
    returns: "Continue",
    writes: ["frame.popped.subject=none"],
    args: [],
  }
  let (compared, incomparable, _unreachable, mismatches) = data_face_compare([
    row,
  ])
  // 行本身可比（真态真命令），但防御位必须把它逐项入册且理由点名
  assert_eq(compared, 1)
  assert_eq(incomparable.length(), 1)
  assert_true(incomparable[0].contains("frame.popped.subject"))
  assert_true(incomparable[0].contains("被弹帧写未被投影剔除"))
  assert_eq(mismatches, [])
}

///|
test "wb·对拍负控：不可达态 / 缺命令样本 逐名入册" {
  let ghost : DataFaceRow = {
    from: "NoSuchState",
    on: "Iri",
    action: "wb_probe",
    returns: "Continue",
    writes: [],
    args: [],
  }
  let (c1, _i1, unreachable1, _m1) = data_face_compare([ghost])
  assert_eq(c1, 0)
  assert_eq(unreachable1, ["NoSuchState+Iri[action=wb_probe]"])
  let nocmd : DataFaceRow = {
    from: "ExpectObject",
    on: "NoSuchCmd",
    action: "wb_probe",
    returns: "Continue",
    writes: [],
    args: [],
  }
  let (c2, _i2, unreachable2, _m2) = data_face_compare([nocmd])
  assert_eq(c2, 0)
  assert_eq(unreachable2.length(), 1)
  assert_true(unreachable2[0].contains("ExpectObject+NoSuchCmd"))
  assert_true(unreachable2[0].contains("命令样本缺"))
}

///|
test "wb·对拍负控：帧深不足的期望 ⇒（无帧）理由文本" {
  // ExpectBaseIri 是起态（见证 = 空 ⇒ 引擎帧栈空）：below 寻址必然无帧，
  // 期望侧照常可解析（none）⇒ 分道理由就是「（无帧）」。
  let row : DataFaceRow = {
    from: "ExpectBaseIri",
    on: "Iri",
    action: "wb_probe",
    returns: "Continue",
    writes: ["frame.below.graph=none"],
    args: [],
  }
  let (compared, incomparable, _unreachable, mismatches) = data_face_compare([
    row,
  ])
  assert_eq(compared, 1)
  assert_eq(incomparable, [])
  assert_eq(mismatches.length(), 1)
  assert_true(mismatches[0].contains("frame.below.graph"))
  assert_true(mismatches[0].contains("（无帧）"))
}
