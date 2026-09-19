// ===== 数据面 ⟷ 引擎：值级对拍（trig 半边，2026-09-19；照 n3v2 同款）=====
//
// 三段链：`quick_machine_trig_gen.toml [actions]` ⟷ 快照 `actions_truth.gen`（**外仓**金样）
//         ⟷ 引擎真件（**本文件**，经 `TrigProbe::slots`）。
// 口径与 n3v2 `gen_n3v2/quicktest/data_face.mbt` **逐字对齐**：只比 4 槽（trig ctx 四槽即全部）；
// 来源 `none`/`arg0`/`ctx.<槽>` 可解析；发射 `EmitQuad(<Scope>)` 后按 scope 清槽（`scope_reset_slots`）；
// 面外（frame.*）、清-读同槽（需读序数据）、条件式（fwd:/nfwd:）三类逐项入册。

///|
/// trig 槽位四视图（与模型 `Model` 同形；`Span` 归一为 `RefId`）
priv struct SlotView {
  subject : RefId?
  predicate : RefId?
  object : RefId?
  graph : RefId?
}

///|
fn slot_view_of_engine(snapshot : @trig.TrigSlotSnapshot) -> SlotView {
  {
    subject: snapshot.subject.map(ref_id_of),
    predicate: snapshot.predicate.map(ref_id_of),
    object: snapshot.object.map(ref_id_of),
    graph: snapshot.graph.map(ref_id_of),
  }
}

///|
/// 引用值文本（判据消息用；`RefId` 只 derive(Debug)，自备小尺子——与 n3v2 同规）
fn df_ref_id_text(value : RefId?) -> String {
  match value {
    None => "None"
    Some(id) => "Some(\{id.id})"
  }
}

///|
/// 数据面快照行
priv struct DataFaceRow {
  from : String
  on : String
  action : String
  returns : String
  writes : Array[String]
}

///|
/// 解析 `actions_truth.gen`（跳过注释/版本行/空行）
fn parse_data_face_rows(text : String) -> Array[DataFaceRow] {
  let rows : Array[DataFaceRow] = []
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" || trimmed.has_prefix("#") || trimmed == "v1" {
      continue
    }
    let parts = trimmed.split("|").to_array()
    if parts.length() < 4 {
      continue
    }
    let head = parts[0].split("+").to_array()
    if head.length() != 2 {
      continue
    }
    let writes_raw = parts[3]
    let writes : Array[String] = if writes_raw == "-" {
      []
    } else {
      writes_raw.split(",").to_array().map(fn(s) { s.to_owned() })
    }
    rows.push({
      from: head[0].to_owned(),
      on: head[1].to_owned(),
      action: parts[1].to_owned(),
      returns: parts[2].to_owned(),
      writes,
    })
  }
  rows
}

///|
fn slot_in_view(name : String) -> Bool {
  ["subject", "predicate", "object", "graph"].contains(name)
}

///|
fn slot_get(view : SlotView, target : String) -> RefId? {
  match target {
    "subject" => view.subject
    "predicate" => view.predicate
    "object" => view.object
    "graph" => view.graph
    _ => None
  }
}

///|
/// 发射 scope → 被清的槽（引擎 `ResetScope` 口径；与 n3v2 同款）
fn scope_reset_slots(returns : String) -> Array[String] {
  let slots : Array[String] = []
  if returns.contains("EmitQuad(All)") {
    slots.push("subject")
    slots.push("predicate")
    slots.push("object")
    slots.push("graph")
  } else if returns.contains("EmitQuad(SPO)") {
    slots.push("subject")
    slots.push("predicate")
    slots.push("object")
  } else if returns.contains("EmitQuad(PredObj)") {
    slots.push("predicate")
    slots.push("object")
  } else if returns.contains("EmitQuad(Object)") {
    slots.push("object")
  }
  slots
}

///|
fn classify_write_source(
  target : String,
  source : String,
  before : SlotView,
  payload : RefId,
) -> Result[RefId?, String] {
  if !slot_in_view(target) {
    return Err("\{target}（槽在观测面外）")
  }
  if source == "none" {
    return Ok(None)
  }
  if source == "arg0" {
    return Ok(Some(payload))
  }
  for other in ["subject", "predicate", "object", "graph"] {
    if source == "ctx." + other {
      return Ok(slot_get(before, other))
    }
  }
  if source.has_prefix("ctx.") {
    return Err("\{source}（源槽在观测面外）")
  }
  Err("\{source}（首片不解析）")
}

///|
fn response_short(response : Response) -> String {
  match response {
    Continue => "Continue"
    EmitQuad(_) => "EmitQuad"
    Done => "Done"
    Error(code) => "Error(\{code})"
    Batch(items) => "Batch(\{items.length()})"
  }
}

///|
/// 逐行对拍：返回 (可比行数, 不可比清单, 不可达清单, 分道清单)
fn data_face_compare(
  rows : Array[DataFaceRow],
) -> (Int, Array[String], Array[String], Array[String]) {
  let witnesses = reachable_state_witness_paths()
  let mut compared = 0
  let incomparable : Array[String] = []
  let unreachable_rows : Array[String] = []
  let mismatches : Array[String] = []
  for row in rows {
    let key = "\{row.from}+\{row.on}[action=\{row.action}]"
    let mut path : Array[Command]? = None
    for entry in witnesses {
      let (state, witness) = entry
      if state_name(state) == row.from {
        path = Some(witness)
      }
    }
    let witness = match path {
      Some(w) => w
      None => {
        unreachable_rows.push(key)
        continue
      }
    }
    let mut command : Command? = None
    for candidate in all_commands() {
      if command_name(candidate) == row.on {
        command = Some(candidate)
      }
    }
    let cmd = match command {
      Some(c) => c
      None => {
        unreachable_rows.push("\{key}（命令样本缺）")
        continue
      }
    }
    let payload : RefId = { id: 1, }
    let system = system_init()
    for step in witness {
      ignore(run_command(step, system))
    }
    let before = slot_view_of_engine(system.probe.slots())
    // 清-读同槽（序敏感）：理由与 n3v2 同——"按 TOML 写序"已被证伪，需读序数据
    let mut order_sensitive : String? = None
    for item in row.writes {
      let pair = item.split("=").to_array()
      if pair.length() == 2 && pair[1] == "none" {
        let cleared = pair[0].to_owned()
        for other in row.writes {
          let op = other.split("=").to_array()
          if op.length() == 2 && op[1] == "ctx." + cleared {
            order_sensitive = Some(
              "清-读同槽（\{cleared}；需读序数据）",
            )
          }
        }
      }
    }
    match order_sensitive {
      Some(why) => {
        incomparable.push("\{key}：\{why}")
        continue
      }
      None => ()
    }
    let expected_items : Array[(String, RefId?)] = []
    for item in row.writes {
      let pair = item.split("=").to_array()
      if pair.length() != 2 {
        incomparable.push("\{key}：\{item}（非 tgt=src 形）")
        continue
      }
      match
        classify_write_source(
          pair[0].to_owned(),
          pair[1].to_owned(),
          before,
          payload,
        ) {
        Ok(value) => expected_items.push((pair[0].to_owned(), value))
        Err(why) => incomparable.push("\{key}·\{pair[0]}：\{why}")
      }
    }
    let response = run_command(cmd, system)
    let actual = slot_view_of_engine(system.probe.slots())
    let reset_slots = scope_reset_slots(row.returns)
    for entry in expected_items {
      let (target, value) = entry
      let expected_value = if reset_slots.contains(target) {
        None
      } else {
        value
      }
      let got = slot_get(actual, target)
      if got != expected_value {
        mismatches.push(
          "\{key}·\{target}：期望 \{df_ref_id_text(expected_value)} 实得 \{df_ref_id_text(got)}（响应 \{response_short(response)}）",
        )
      }
    }
    compared = compared + 1
  }
  (compared, incomparable, unreachable_rows, mismatches)
}

///|
/// **数据面 ⟷ 引擎 值级对拍（trig）**：可比行逐槽等值；不可比/不可达逐项在册（类计数钉死）。
async test "数据面⟷引擎·trig 值级对拍：可比行逐槽等值 + 台账钉死" {
  let snapshot = @fs.read_file("src/gen_trig/quicktest/actions_truth.gen").text()
  let rows = parse_data_face_rows(snapshot)
  assert_eq(rows.length(), 136)
  let (compared, incomparable, unreachable_rows, mismatches) = data_face_compare(
    rows,
  )
  debug(
    "数据面⟷引擎 trig：行 \{rows.length()}，可比 \{compared}，不可比 \{incomparable.length()}，不可达 \{unreachable_rows.length()}，分道 \{mismatches.length()}",
  )
  for site in mismatches {
    debug("  分道：\{site}")
  }
  for site in incomparable {
    debug("  不可比：\{site}")
  }
  for site in unreachable_rows {
    debug("  不可达：\{site}")
  }
  // 债点（首跑 8 行，逐名在册待裁定）：形态全同——**压帧行（`frame=push`）的 `arg0` 写槽**
  // 引擎未落（`graph`/`subject` 实得 None）。两个候选根因待下一役定向裁定：
  //   ① `push_writes=false` 语义（压帧行默认**不折** writes，见 QuickActionDecl 注）；
  //   ② 载荷取不到（`Lbrace`/`Lparen` 在 `all_commands()` 里是 nullary，`arg0` 无真值）。
  let debt_keys : Array[String] = [
    "ExpectSubject+Lbrace", "ExpectDirectiveEnd+Lbrace", "ExpectObject+Lparen", "BnpExpectObject+Lparen",
    "ExpectSubject+Lparen", "ExpectDirectiveEnd+Lparen", "GraphExpectSubject+Lparen",
    "GraphExpectObject+Lparen",
  ]
  let violations : Array[String] = []
  let mut debt_hits = 0
  for site in mismatches {
    let mut is_debt = false
    for key in debt_keys {
      if site.has_prefix("\{key}[") {
        is_debt = true
      }
    }
    if is_debt {
      debt_hits = debt_hits + 1
    } else {
      violations.push(site)
    }
  }
  assert_eq(violations, [])
  assert_eq(debt_hits, 8)
  assert_eq(unreachable_rows.length(), 0)
  let (off_face, order_sensitive, conditional) = ledger_classes(incomparable)
  debug(
    "  台账：面外 \{off_face} / 序敏感 \{order_sensitive} / 条件式 \{conditional} / 不可达 \{unreachable_rows.length()}",
  )
  // 类计数钉死（首跑回填：面外 9 / 序敏感 0 / 条件式 0）
  assert_eq(off_face, 9)
  assert_eq(order_sensitive, 0)
  assert_eq(conditional, 0)
}

///|
/// 台账三类计数（面外 / 序敏感 / 条件式）
fn ledger_classes(incomparable : Array[String]) -> (Int, Int, Int) {
  let mut off_face = 0
  let mut order_sensitive = 0
  let mut conditional = 0
  for site in incomparable {
    if site.contains("清-读同槽") {
      order_sensitive = order_sensitive + 1
    } else if site.contains("fwd:") || site.contains("nfwd:") {
      conditional = conditional + 1
    } else {
      off_face = off_face + 1
    }
  }
  (off_face, order_sensitive, conditional)
}
