// ===== 数据面 ⟷ 引擎：值级对拍（子仓半边，2026-09-19）=====
//
// 三段链：`quick_machine_n3_gen.toml [actions]` ⟷ 快照 `actions_truth.gen`（**外仓**金样）
//         ⟷ 引擎真件（**本文件**）。
// 与 R-20 值级普查（`metrics.mbt`：模型 ⟷ 引擎）**分开记账**：本文件管"数据面（TOML 投影）⟷ 引擎"。
//
// 口径（首片，写死）：只比**可解析写槽**——来源 ∈ {`none`（置空）、`arg0`（取本命令载荷）、
// `ctx.<槽>`（保持）}；其余（`fwd:`/`nfwd:` 条件式、`frame.*` 面外、`to`/裸布尔）逐行入**不可比台账**。
// 行集合 = 快照行 ∩ 可达态；不可比行、不可达行都**逐名在册**（条数钉死，新冒即红）。

///|
/// 发射 scope → 被清的槽（引擎 `ResetScope` 口径：`Object` / `PredObj` / `SPO` / `All`）。
/// 债点裁定（2026-09-19）：`path_subj_end` 8 行实测 post 槽为 None 而 action 明确写了值 ⇒
/// 根因 = **发射即清槽**（`EmitQuad(SPO)` 之后 loop 按 scope 复位），首片漏了这一步。
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
/// 数据面快照行
priv struct DataFaceRow {
  from : String
  on : String
  action : String
  returns : String
  writes : Array[String]
  args : Array[String]
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
    // `args` 列（快照第 7 列）：`argN` 写槽来源**必须**靠它解引用（trig §AN.5 裁定教训回灌）
    let args_raw = if parts.length() > 6 { parts[6].to_owned() } else { "-" }
    let args : Array[String] = if args_raw == "-" {
      []
    } else {
      args_raw.split(",").to_array().map(fn(s) { s.to_owned() })
    }
    rows.push({
      from: head[0].to_owned(),
      on: head[1].to_owned(),
      action: parts[1].to_owned(),
      returns: parts[2].to_owned(),
      writes,
      args,
    })
  }
  rows
}

///|
/// 槽位名是否落在 `SlotView` 的可观测面内（首片只到 8 槽）
fn slot_in_view(name : String) -> Bool {
  [
    "subject", "predicate", "object", "graph", "path_src", "path_pend", "path_tail",
    "path_fwd",
  ].contains(name)
}

///|
/// 取 `SlotView` 的某槽现值（观测面内 8 槽）
fn slot_get(view : SlotView, target : String) -> RefId? {
  match target {
    "subject" => view.subject
    "predicate" => view.predicate
    "object" => view.object
    "graph" => view.graph
    "path_src" => view.path_src
    "path_pend" => view.path_pend
    "path_tail" => view.path_tail
    _ => None
  }
}

///|
/// 写项来源解析：`Ok(期望值)` = 可比；`Err(理由)` = 不可比（入册）
fn classify_write_source(
  target : String,
  source : String,
  before : SlotView,
  payload : RefId,
  args : Array[String],
) -> Result[RefId?, String] {
  if !slot_in_view(target) {
    return Err("\{target}（槽在观测面外）")
  }
  if source == "none" {
    return Ok(None)
  }
  // `argN` 按该行 args 列解引用（trig §AN.5：args=none ⇒ 实参 None，不是合成载荷）
  let arg_index : Int? = match source {
    "arg0" => Some(0)
    "arg1" => Some(1)
    "arg2" => Some(2)
    "arg3" => Some(3)
    _ => None
  }
  match arg_index {
    Some(index) => {
      if index >= args.length() {
        return Err("\{source}（args 列不足：\{(args.join(","))}）")
      }
      let bound = args[index]
      if bound == "payload" || bound == "Some(payload)" {
        return Ok(Some(payload))
      }
      if bound == "none" {
        return Ok(None)
      }
      for
        other in [
          "subject", "predicate", "object", "graph", "path_src", "path_pend", "path_tail",
        ] {
        if bound == "ctx." + other {
          return Ok(slot_get(before, other))
        }
      }
      return Err("arg\{index}=「\{bound}」（形态未解析）")
    }
    None => ()
  }
  for
    other in [
      "subject", "predicate", "object", "graph", "path_src", "path_pend", "path_tail",
    ] {
    if source == "ctx." + other {
      return Ok(slot_get(before, other))
    }
  }
  if source.has_prefix("ctx.") {
    return Err("\{source}（源槽在观测面外/bool 槽）")
  }
  Err("\{source}（首片不解析）")
}

///|
/// 响应短文本（判据消息用）
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
    // ① 该 from 态的见证路径
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
    // ② 该事件的命令样本（载荷 = 1 ⇒ `arg0` 期望值 = 1）
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
    // ③ 复现见证路径 → 引擎槽位前值
    let system = system_init()
    for step in witness {
      ignore(run_command(step, system))
    }
    let before = slot_view_of_engine(system.probe.slots())
    // 序敏感（**证伪留档**，2026-09-19 第二笔）：曾按"TOML 写序依次应用"建模（`x=ctx.S` 取此刻 S），
    // 一开即 **53 处分道**（例：`SubjTrailVerbDone+Iri·subject 期望 None 实得 Some(1)`）⇒
    // **TOML 写序 ≠ 引擎读序**（引擎多在清槽前把值读进局部变量，如 `actions.mbt:723-741`）。
    // ⇒ 该假设**回退**；清-读同槽行整行入册（理由 `需读序数据`），下一片给数据面加 `reads`/读序键再判。
    // **分派族**（按 `SlotType` 分派，§AN.9）：`args` 含 `SlotType::` 或 `returns` 含 `OpenSlot`
    // ——**§AN.11 已转真判**：数据面加了 `when_slot_type` 臂（外仓 `[actions]` 按行实参
    // `SlotType::<typ>` 选臂、同目标槽覆盖基础 `writes`），快照的 `writes` 列即**该 typ 下
    // 的最终写槽** ⇒ 本门不再整行跳过（12 行入 `compared`）。今后若某 action 真按 SlotType
    // 分派却没声明臂，会以**分道**浮出（比静默跳过强）。
    // 注：**清-读同槽（60 行）自本笔起不再整行跳过**——门按"读前值"判（§AN.9 第一步）。
    // 弹帧恢复（§AN.9 第一步实测 1 行）：`PopBnp` 把帧里保存的 subject/predicate/graph 写回，
    // 而帧内容不在 `SlotView` 面内 ⇒ 含"读这三槽"的弹帧行整行入册（面外：帧）。
    let mut pop_restore = false
    if row.returns.contains("PopBnp") {
      for item in row.writes {
        let pair = item.split("=").to_array()
        if pair.length() == 2 {
          let src = pair[1]
          if src == "ctx.subject" ||
            src == "ctx.predicate" ||
            src == "ctx.graph" {
            pop_restore = true
          }
        }
      }
    }
    if pop_restore {
      incomparable.push("\{key}：弹帧恢复槽位（帧内容面外）")
      continue
    }
    // ④ **逐项**解析期望：可比项照比，不可比项只把**该项**入册。
    // 负控①实测教训：整行入册会让"行内可比槽"也失去判据（改 `subject=none` 竟不红）⇒ 降为逐项。
    let expected_items : Array[(String, RefId?)] = []
    for item in row.writes {
      let pair = item.split("=").to_array()
      if pair.length() != 2 {
        incomparable.push("\{key}：\{item}（非 tgt=src 形）")
        continue
      }
      // 弹帧恢复**覆盖**三槽（帧内容面外）：含 `PopBnp` 的行，subject/predicate/graph 不可比，
      // 其余槽（path_*）照比（§AN.9 第一步实测 1 行：path_obj_close·predicate）。
      let raw_target = pair[0].to_owned()
      if row.returns.contains("PopBnp") &&
        (
          raw_target == "subject" ||
          raw_target == "predicate" ||
          raw_target == "graph"
        ) {
        incomparable.push(
          "\{key}·\{raw_target}：弹帧恢复覆盖（帧内容面外）",
        )
        continue
      }
      match
        classify_write_source(
          pair[0].to_owned(),
          pair[1].to_owned(),
          before,
          payload,
          row.args,
        ) {
        Ok(value) => expected_items.push((pair[0].to_owned(), value))
        Err(why) => incomparable.push("\{key}·\{pair[0]}：\{why}")
      }
    }
    // ⑤ 引擎步后逐槽比对
    let response = run_command(cmd, system)
    let actual = slot_view_of_engine(system.probe.slots())
    // 发射 scope 复位（债点裁定的结论）：EmitQuad(<Scope>) 之后 loop 按 scope 清槽 ⇒
    // 期望值 = 写槽后**再**按 scope 置 None。
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
          "\{key}·\{target}：期望 \{ref_id_text(expected_value)} 实得 \{ref_id_text(got)}（响应 \{response_short(response)}）",
        )
      }
    }
    compared = compared + 1
  }
  (compared, incomparable, unreachable_rows, mismatches)
}

///|
/// **数据面 ⟷ 引擎 值级对拍（首片）**：可比行逐槽等值；不可比/不可达行**逐名在册**（条数钉死）。
async test "数据面⟷引擎·值级对拍（首片）：可比行逐槽等值 + 台账钉死" {
  let snapshot = @fs.read_file("src/gen_n3v2/quicktest/actions_truth.gen").text()
  let rows = parse_data_face_rows(snapshot)
  assert_eq(rows.length(), 314)
  let (compared, incomparable, unreachable_rows, mismatches) = data_face_compare(
    rows,
  )
  debug(
    "数据面⟷引擎：行 \{rows.length()}，可比 \{compared}，不可比 \{incomparable.length()}，不可达 \{unreachable_rows.length()}，分道 \{mismatches.length()}",
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
  // 分道分两档（仓库口径：违例必须空、债点逐名在册）：
  //   **债点**（首片待裁定，8 行）：`path_subj_end` 的**无条件 predicate 项**——TOML 期望 Some(载荷)，
  //   引擎留 None（响应 EmitQuad/Continue 均有）。与"清-读同槽"同族嫌疑（序敏感），但整行未命中该模式，
  //   故按债点入册、**不**并入序敏感类；下一片用定向探针裁定"真分歧 vs 序敏感"。
  // **债点台账（2026-09-19 定向裁定后归零）**：首跑 8 行 `path_subj_end·predicate`
  // （`SubjTrailAfterStep{,Formula}+{Iri,KeywordA,KeywordX,PrefName}`）经定向探针查明 =
  // **发射即清槽**（`EmitQuad(SPO)` 后 loop 按 scope 复位）未建模 ⇒ 已折进期望（`scope_reset_slots`），
  // 8 行转真判且全绿。此后新冒分道一律按违例处理（债点清单保持空）。
  let debt_keys : Array[String] = []
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
  debug(
    "  分道：债点 \{debt_hits}（首片待裁定）/ 违例 \{violations.length()}",
  )
  assert_eq(violations, [])
  assert_eq(debt_hits, 0)
  // 台账**按类钉死**（首跑回填；任一类数字变化即红——比"只钉总数"强，能抓类间搬家）
  // 槽/源在观测面外（frame.* / is_src / is_depth / 帧内容）。**§AN.11 后 83 → 77**：
  // 12 行分派族不再整行入册（转真判），其中 6 行 list_*_nested 的 `frame.prev_node=arg0`
  // 由"整行一条"降为"逐项一条"（-12 +6）。
  let mut off_face = 0
  let mut order_sensitive = 0 // 清-读同槽（需读序数据）
  let mut conditional = 0 // 条件式来源（fwd:/nfwd:）
  let mut arg_unparsed = 0 // `argN` 指向未解析形态（state:X / 布尔 / SlotType::…）——args 列化后单列
  for site in incomparable {
    if site.contains("清-读同槽") {
      order_sensitive = order_sensitive + 1
    } else if site.contains("fwd:") || site.contains("nfwd:") {
      conditional = conditional + 1
    } else if site.contains("形态未解析") ||
      site.contains("args 列不足") {
      arg_unparsed = arg_unparsed + 1
    } else {
      off_face = off_face + 1
    }
  }
  debug(
    "  台账：面外 \{off_face} / 序敏感 \{order_sensitive} / 条件式 \{conditional} / arg未解析 \{arg_unparsed} / 不可达 \{unreachable_rows.length()}",
  )
  assert_eq(unreachable_rows.length(), 0)
  assert_eq(off_face, 77)
  assert_eq(order_sensitive, 0)
  assert_eq(conditional, 52)
  assert_eq(arg_unparsed, 66)
}
