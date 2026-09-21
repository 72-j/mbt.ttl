// ============================================================
// R-19 反例钉（模型侧）——役 2 阶段 0.2，2026-09-21
//
// **证伪对象**：「错误后模型 ⟷ 引擎同步」。引擎 driver 在 BusinessFailed 之后走
// `recover_cleanup`（slot_stack / pred_kind / is_src / 注解四件套）+ `consume_to_recover_point`
// （**吞事件**到 Dot ⇒ ExpectSubject + reset(All)；EOF ⇒ reset(SPO)）；模型只有 `refuse_when`
// （错误**当刻**的 state + 两账清），**没有恢复位**；探针 `step_all` 亦无恢复道（D2 前）。
//
// **实测轨迹**（反例输入 `<a> <b> ^<q>[ <r> <s> ] <t> <u> .` + 后继语句；探针 ⟷ 模型**逐步全同**）：
//   [0] Iri      probe=Continue @ExpectPredicate        | model 同
//   [1] Iri      probe=Continue @ExpectObject           | model 同
//   [2] Caret    probe=EmitQuad(0,4,8,-) @PathExpectVerb | model 同（路径跳边，墙前合法出账）
//   [3] Iri      probe=Continue @PathAfterStep          | model 同
//   [4] Lbracket probe=Error(1) @ExpectDotOrGraph       | model 同 ← **墙**（Reverse path cannot end …）
//   [5] Iri      probe=Error(0) @ExpectDotOrGraph       | model 同 ← **分道点**（真驱动此处零响应 = 吞事件）
//   [6] Iri … [7] Rbracket … [8] Iri … [9] Iri（同上，全在吞事件窗内）
//   [10] Dot     probe=EmitQuad(-,-,-,-) @ExpectSubject | model 同 ← 复位点（reset(All)）
//   [11..14] 后继语句照常出账（末步 EmitQuad(28,31,34,-)）
//
// **该红在哪一步 / 翻转点**：真驱动在 [5]–[9] **零响应**（吞事件，见 `../../engine_wbtest.mbt`
// "R-19: 反例固化" 三重实证），模型/探针却各给 `Error(0)` ⇒ 分道点 = **墙后第一个事件**。
// 2b 落地（模型加恢复位 + 探针面同扩，D2）后，[5]–[9] 必须变为**无响应**（吞事件）——
// 本钉的 [5]–[9] 断言即**翻转点**：改对了这段必红，同笔改成"无响应"断言。
// ============================================================

///|
/// 槽位紧凑标签（Quad 无 Show，按 RefId 逐槽手拼）
fn r19_slot(r : RefId?) -> String {
  match r {
    Some(x) => "\{x.id}"
    None => "-"
  }
}

///|
/// 四元组紧凑标签
fn r19_quad(q : Quad) -> String {
  "(\{r19_slot(q.subject)},\{r19_slot(q.predicate)},\{r19_slot(q.object)},\{r19_slot(q.graph)})"
}

///|
/// 响应紧凑标签（探针/模型两侧同用；断言与轨迹注释同源）
fn r19_resp(r : Response) -> String {
  match r {
    Continue => "Continue"
    EmitQuad(q) => "EmitQuad\{r19_quad(q)}"
    Done => "Done"
    Error(n) => "Error(\{n})"
    Batch(rs) => "Batch(\{rs.map(r19_resp).join(",")})"
  }
}

///|
/// 反例命令序列（对应文本 `<a> <b> ^<q>[ <r> <s> ] <t> <u> .` + 后继语句）：
/// `<a>`=Iri(0) `<b>`=Iri(4) `^<q>`=Caret(8) `[`=Lbracket(12) … `.`(第 10 号命令)
fn r19_script() -> Array[Command] {
  [
    Iri(Concrete({ id: 0, })),
    Iri(Concrete({ id: 4, })),
    Caret(Concrete({ id: 8, })),
    Iri(Concrete({ id: 11, })),
    Lbracket(Concrete({ id: 12, })),
    Iri(Concrete({ id: 14, })),
    Iri(Concrete({ id: 17, })),
    Rbracket,
    Iri(Concrete({ id: 20, })),
    Iri(Concrete({ id: 23, })),
    Dot,
    Iri(Concrete({ id: 28, })),
    Iri(Concrete({ id: 31, })),
    Iri(Concrete({ id: 34, })),
    Dot,
  ]
}

///|
/// **R-19 反例钉**：探针 ⟷ 模型逐步全同（当前口径）+ 分道点 / 复位点 / 翻转点写死。
test "R-19 反例钉：探针⟷模型逐步全同，分道点 = 墙后第一个事件" {
  let system = system_init()
  let mut model = model_empty()
  let responses : Array[Response] = []
  let states : Array[ModelState] = []
  for cmd in r19_script() {
    let engine_resp = run_command(cmd, system)
    let (next, expected) = model_execute(model, cmd)
    // 双执行逐步一致（**当前口径**：探针与模型同缺恢复位 ⇒ 随机门/普查门对恢复道无判别力）
    assert_eq(engine_resp, expected)
    responses.push(engine_resp)
    states.push(next.state)
    model = next
  }
  // ① 墙（命令序 4 = `[`）：业务错 + 归位 ExpectDotOrGraph
  assert_eq(r19_resp(responses[4]), "Error(1)")
  assert_eq(states[4], ExpectDotOrGraph)
  // ② **分道点**（命令序 5 = 墙后第一个事件 `<r>`）与吞事件窗 5–9：
  //    模型/探针各给 Error(0) 且停在 ExpectDotOrGraph；**真驱动此处零响应**。
  //    ⚠ 翻转点：2b 落地后本段改"无响应"断言（改对即红）。
  for k in [5, 6, 7, 8, 9] {
    assert_eq(r19_resp(responses[k]), "Error(0)")
    assert_eq(states[k], ExpectDotOrGraph)
  }
  // ③ 复位点（命令序 10 = `.`）：空槽发射 + 回 ExpectSubject（reset(All) 的可见面）
  assert_eq(
    responses[10],
    EmitQuad({ subject: None, predicate: None, object: None, graph: None, }),
  )
  assert_eq(states[10], ExpectSubject)
  // ④ 恢复后照常出账（命令序 14 = 后继语句的 `.`）
  assert_eq(
    responses[14],
    EmitQuad({
      subject: Some({ id: 28, }),
      predicate: Some({ id: 31, }),
      object: Some({ id: 34, }),
      graph: None,
    }),
  )
}
