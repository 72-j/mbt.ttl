// ===== 数据面门自证·trig 半边（役 A：白盒直调 + 负控，2026-09-20）=====
//
// 与 n3v2 `data_face_wbtest.mbt` 同规：直调包内私有函数点亮红-only 臂，
// 每条负控断言【确实红 + 理由文本逐字对得上】。trig 无倒装两槽 ⇒ 无
// `classify_face_expect`/`face_value_*`/`frame_address`；特有：
// `fwd:` 词条即口径缺口（fail-loud 臂）与清-读同槽序敏感臂（n3 已转读前值真判）。

///|
fn wb_ok_id(r : Result[RefId?, String]) -> Int? {
  match r {
    Ok(Some(v)) => Some(v.id)
    _ => None
  }
}

///|
fn wb_err(r : Result[RefId?, String]) -> String? {
  match r {
    Ok(_) => None
    Err(why) => Some(why)
  }
}

///|
fn wb_rid(id : Int) -> RefId {
  { id, }
}

///|
/// 合成槽位视图（trig 四槽即全部）
fn wb_view() -> SlotView {
  {
    subject: Some(wb_rid(1)),
    predicate: Some(wb_rid(2)),
    object: None,
    graph: Some(wb_rid(3)),
  }
}

///|
/// 合成帧顶（各 Span 位都给非平凡值）
fn wb_frame() -> FaceFrame {
  {
    open_span: wb_rid(20),
    subject: Some(wb_rid(21)),
    predicate: None,
    graph: Some(wb_rid(22)),
    prev_node: Some(wb_rid(23)),
  }
}

///|
fn wb_frames() -> Array[FaceFrame] {
  [wb_frame()]
}

///|
test "wb·parse：七列全落位 + 注释/空行跳过 + 列数≠7 跳过 + 头缺 + 跳过（TAB 所有权·消费侧）" {
  let text = "# format: v3\n\nA+B\tAct\tContinue\tsubject=ctx.subject\t-\t-\targs0=payload\nBADLINE\nNoPlus\tAct\tContinue\t-\t-\t-\t-\nC+D\tAct2\tPopBnp\tobject=none,graph=ctx.graph\t-\t-\t-\n"
  let rows = parse_data_face_rows(text)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].from, "A")
  assert_eq(rows[0].on, "B")
  assert_eq(rows[0].action, "Act")
  assert_eq(rows[0].returns, "Continue")
  assert_eq(rows[0].writes, ["subject=ctx.subject"])
  assert_eq(rows[0].args, ["args0=payload"])
  assert_eq(rows[1].from, "C")
  assert_eq(rows[1].on, "D")
  assert_eq(rows[1].returns, "PopBnp")
  assert_eq(rows[1].writes, ["object=none", "graph=ctx.graph"])
  assert_eq(rows[1].args, [])
  // 负控：字段含 TAB ⇒ 列数 > 7 ⇒ 整行跳过（§AN.12 所有权口径，行数钉子靠它红）
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
test "wb·slot 面：四槽在观测面内 + slot_get 未知名兜底 None" {
  let view = wb_view()
  for name in ["subject", "predicate", "object", "graph"] {
    assert_true(slot_in_view(name))
  }
  assert_false(slot_in_view("bogus"))
  assert_eq(wb_ok_id(Ok(slot_get(view, "subject"))), Some(1))
  assert_eq(wb_ok_id(Ok(slot_get(view, "predicate"))), Some(2))
  assert_eq(wb_ok_id(Ok(slot_get(view, "graph"))), Some(3))
  // object 现值 None；未知名兜底 None
  assert_eq(wb_ok_id(Ok(slot_get(view, "object"))), None)
  assert_eq(wb_ok_id(Ok(slot_get(view, "bogus"))), None)
}

///|
test "wb·frame_ref_field：Span 值域五位 + 非 RefId 位兜底 None" {
  let f = wb_frame()
  assert_eq(frame_ref_field(f, "open_span"), Some(wb_rid(20)))
  assert_eq(frame_ref_field(f, "prev_node"), Some(wb_rid(23)))
  assert_eq(frame_ref_field(f, "subject"), Some(wb_rid(21)))
  assert_eq(frame_ref_field(f, "predicate"), None)
  assert_eq(frame_ref_field(f, "graph"), Some(wb_rid(22)))
  assert_eq(frame_ref_field(f, "ret_state"), None)
  assert_eq(frame_ref_field(f, "bogus"), None)
}

///|
test "wb·df_ref_id_text：None/Some 渲染" {
  assert_eq(df_ref_id_text(None), "None")
  assert_eq(df_ref_id_text(Some(wb_rid(9))), "Some(9)")
}

///|
test "wb·classify：argN 按 args 列解引用全表（payload/none/keep/ctx./形态未解析/列不足）" {
  let view = wb_view()
  let frames = wb_frames()
  let payload = wb_rid(99)
  assert_eq(
    wb_ok_id(
      classify_write_source("subject", "arg0", view, frames, payload, [
        "payload",
      ]),
    ),
    Some(99),
  )
  assert_eq(
    wb_ok_id(
      classify_write_source("subject", "arg0", view, frames, payload, [
        "Some(payload)",
      ]),
    ),
    Some(99),
  )
  // args=none ⇒ 实参 None（不是合成载荷——§AN.5 裁定回灌）
  match
    classify_write_source("subject", "arg0", view, frames, payload, ["none"]) {
    Ok(None) => assert_true(true)
    _ => assert_false(true)
  }
  // keep = 行进前该槽值（缺省绑定的"无 span 事件"半）
  assert_eq(
    wb_ok_id(
      classify_write_source("subject", "arg0", view, frames, payload, ["keep"]),
    ),
    Some(1),
  )
  match
    classify_write_source("object", "arg0", view, frames, payload, ["keep"]) {
    Ok(None) => assert_true(true)
    _ => assert_false(true)
  }
  assert_eq(
    wb_ok_id(
      classify_write_source("subject", "arg0", view, frames, payload, [
        "ctx.graph",
      ]),
    ),
    Some(3),
  )
  // 负控①：args 列不足——确实红，理由文本对得上
  assert_eq(
    wb_err(
      classify_write_source("subject", "arg1", view, frames, payload, [
        "payload",
      ]),
    ),
    Some("arg1（args 列不足：payload）"),
  )
  // 负控②：绑定形态未解析——确实红，理由文本对得上
  assert_eq(
    wb_err(
      classify_write_source("subject", "arg0", view, frames, payload, [
        "state:Foo",
      ]),
    ),
    Some("arg0=「state:Foo」（形态未解析）"),
  )
}

///|
test "wb·classify：fwd:/nfwd: 词条即口径缺口（本方言无方向旗标槽，fail-loud）" {
  let view = wb_view()
  let frames = wb_frames()
  let payload = wb_rid(99)
  // 负控③：trig 无路径三账 ⇒ 条件式来源声明了读不了的旗——确实红且理由点名
  assert_eq(
    wb_err(
      classify_write_source(
        "subject",
        "fwd:ctx.subject|ctx.graph",
        view,
        frames,
        payload,
        [],
      ),
    ),
    Some(
      "fwd:ctx.subject|ctx.graph（条件式来源：本方言无方向旗标槽 ⇒ 口径缺口）",
    ),
  )
  assert_eq(
    wb_err(
      classify_write_source(
        "subject",
        "nfwd:none|ctx.subject",
        view,
        frames,
        payload,
        [],
      ),
    ),
    Some(
      "nfwd:none|ctx.subject（条件式来源：本方言无方向旗标槽 ⇒ 口径缺口）",
    ),
  )
}

///|
test "wb·classify：none/ctx./frame. 帧读 + 面外/非值域/帧栈空/首片不解析负控" {
  let view = wb_view()
  let frames = wb_frames()
  let payload = wb_rid(99)
  match classify_write_source("subject", "none", view, frames, payload, []) {
    Ok(None) => assert_true(true)
    _ => assert_false(true)
  }
  assert_eq(
    wb_ok_id(
      classify_write_source("subject", "ctx.predicate", view, frames, payload, []),
    ),
    Some(2),
  )
  assert_eq(
    wb_ok_id(
      classify_write_source(
        "subject",
        "frame.prev_node",
        view,
        frames,
        payload,
        [],
      ),
    ),
    Some(23),
  )
  assert_eq(
    wb_ok_id(
      classify_write_source(
        "subject",
        "frame.open_span",
        view,
        frames,
        payload,
        [],
      ),
    ),
    Some(20),
  )
  // 负控④：面外目标——确实红（`is_src` 属 n3 倒装面，trig 四槽观测面外）
  assert_eq(
    wb_err(classify_write_source("is_src", "none", view, frames, payload, [])),
    Some("is_src（槽在观测面外）"),
  )
  assert_eq(
    wb_err(classify_write_source("bogus", "none", view, frames, payload, [])),
    Some("bogus（槽在观测面外）"),
  )
  // 负控⑤：ctx. 面外——确实红
  assert_eq(
    wb_err(
      classify_write_source("subject", "ctx.bogus", view, frames, payload, []),
    ),
    Some("ctx.bogus（源槽在观测面外）"),
  )
  // 负控⑥：帧位非 Span 值域——确实红
  assert_eq(
    wb_err(
      classify_write_source(
        "subject",
        "frame.node_seq",
        view,
        frames,
        payload,
        [],
      ),
    ),
    Some("frame.node_seq（帧位非 Span 值域）"),
  )
  // 负控⑦：帧栈空——确实红
  assert_eq(
    wb_err(
      classify_write_source("subject", "frame.prev_node", view, [], payload, []),
    ),
    Some("frame.prev_node（帧栈空）"),
  )
  // 负控⑧：首片不解析——确实红
  assert_eq(
    wb_err(classify_write_source("subject", "bogus", view, frames, payload, [])),
    Some("bogus（首片不解析）"),
  )
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
test "wb·ledger_classes：四类分派（条件式/未解析两族进 arg 未解析类，余者落面外）" {
  let (off_face, order_sensitive, conditional, arg_unparsed) = ledger_classes([
    "A+B[a]·t：清-读同槽（subject；需读序数据）", "A+B[a]·t：fwd:x|y（条件式来源：本方言无方向旗标槽 ⇒ 口径缺口）",
    "A+B[a]·t：arg0=「x」（形态未解析）", "A+B[a]·t：arg0（args 列不足：）",
    "A+B[a]·t：ctx.bogus（源槽在观测面外）",
  ])
  assert_eq(off_face, 1)
  assert_eq(order_sensitive, 1)
  assert_eq(conditional, 1)
  assert_eq(arg_unparsed, 2)
}

///|
/// 对拍级负控（合成行）：清-读同槽 ⇒ 序敏感整行入册（确实红 + 理由文本）。
test "wb·对拍负控：清-读同槽 ⇒ 序敏感入册" {
  let row : DataFaceRow = {
    from: "ExpectObject",
    on: "Iri",
    action: "wb_probe",
    returns: "Continue",
    writes: ["subject=none", "object=ctx.subject"],
    args: [],
  }
  let (compared, incomparable, _unreachable, mismatches) = data_face_compare([
    row,
  ])
  // 序敏感行整行让位（不比不分道），理由点名槽位
  assert_eq(compared, 0)
  assert_eq(incomparable.length(), 1)
  assert_true(incomparable[0].contains("清-读同槽"))
  assert_true(incomparable[0].contains("subject"))
  assert_true(incomparable[0].contains("需读序数据"))
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
