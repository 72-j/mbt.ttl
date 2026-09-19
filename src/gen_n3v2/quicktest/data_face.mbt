// ===== 数据面 ⟷ 引擎：值级对拍（子仓半边，2026-09-19）=====
//
// 三段链：`quick_machine_n3_gen.toml [actions]` ⟷ 快照 `actions_truth.gen`（**外仓**金样）
//         ⟷ 引擎真件（**本文件**）。
// 与 R-20 值级普查（`metrics.mbt`：模型 ⟷ 引擎）**分开记账**：本文件管"数据面（TOML 投影）⟷ 引擎"。
//
// 口径（写死）：比**可解析写槽**——来源 ∈ {`none`（置空）、`argN`（按 `args` 列解引用，
// 缺省绑定已在投影侧写实为 `payload`/`keep`）、`ctx.<槽>`（读前值）、
// `fwd:`/`nfwd:`（按行进前方向旗二选一后递归）}；其余（`frame.*` 面内外、`to`/裸布尔）逐项入**不可比台账**。
// 台账**按类钉死**：面外 / 序敏感 / 条件式 / arg未解析（§AN.12 后两者已清零，仍是棘轮）。
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
    // 头只认注释（版本号在 `# format: vN` 注释里，§AN.14 起无裸版本行）
    if trimmed == "" || trimmed.has_prefix("#") {
      continue
    }
    // §AN.12 **列分隔符 = TAB**：v1 用 `|` 作分隔符，而笔 3a 起的写槽词表含 `fwd:a|b`
    // ⇒ 那些行被**静默截断**（`writes` 只到第一个 `|`，且 `frame`/`args` 列整体错位）。
    // 列数**恰 7**（不符即跳过 ⇒ 行数钉子会红，不留静默）。
    let parts = trimmed.split("\t").to_array()
    if parts.length() != 7 {
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
    let args_raw = parts[6].to_owned()
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
/// 帧顶字段读数（§AN.13 帧面）：`Span` → `RefId` 归一、引擎态 → **模型态名**
/// （经 `metrics.mbt` 的穷尽桥 `model_state_of_engine` + `state_name`；不可桥者记 `"?"`）。
priv struct FaceFrame {
  is_formula : Bool
  open_span : RefId
  subject : RefId?
  predicate : RefId?
  graph : RefId?
  ret_state_name : String
  as_subject : Bool
  as_pred : Bool
  prev_node : RefId?
  node_seq : Int
}

///|
/// **面外账本读数**（帧栈 + 倒装两槽）——与 `SlotView`（8 槽）分开的两个类型：
/// `SlotView` 供 R-20 普查做"模型 ⟷ 引擎"整块 `==`（加字段会污染那把尺子），
/// 本组只喂数据面门。
priv struct FaceLedger {
  frames : Array[FaceFrame] // 自底向上（栈顶 = 末元素）
  is_src : RefId?
  is_depth : Int
}

///|
fn face_ledger_of_engine(probe : @n3.N3Probe) -> FaceLedger {
  let frames : Array[FaceFrame] = []
  for frame in probe.frames() {
    frames.push({
      is_formula: frame.is_formula,
      open_span: ref_id_of(frame.open_span),
      subject: frame.subject.map(ref_id_of),
      predicate: frame.predicate.map(ref_id_of),
      graph: frame.graph.map(ref_id_of),
      ret_state_name: match model_state_of_engine(frame.ret_state) {
        Some(state) => state_name(state)
        None => "?"
      },
      as_subject: frame.as_subject,
      as_pred: frame.as_pred,
      prev_node: frame.prev_node.map(ref_id_of),
      node_seq: frame.node_seq,
    })
  }
  let inversion = probe.inversion()
  {
    frames,
    is_src: inversion.is_src.map(ref_id_of),
    is_depth: inversion.is_depth,
  }
}

///|
/// 帧面期望值：帧字段有四种值域（`RefId?` / `Bool` / `Int` / 态名）
priv enum FaceValue {
  FRef(RefId?)
  FBool(Bool)
  FInt(Int)
  FState(String)
}

///|
fn face_value_text(value : FaceValue) -> String {
  match value {
    FRef(v) => ref_id_text(v)
    FBool(v) => if v { "true" } else { "false" }
    FInt(v) => v.to_string()
    FState(v) => v
  }
}

///|
fn face_value_eq(a : FaceValue, b : FaceValue) -> Bool {
  match (a, b) {
    (FRef(x), FRef(y)) => x == y
    (FBool(x), FBool(y)) => x == y
    (FInt(x), FInt(y)) => x == y
    (FState(x), FState(y)) => x == y
    _ => false
  }
}

///|
/// 帧顶取字段（`RefId?` 值域那几位的读取口）
fn frame_ref_field(frame : FaceFrame, field : String) -> RefId? {
  match field {
    "open_span" => Some(frame.open_span)
    "prev_node" => frame.prev_node
    "subject" => frame.subject
    "predicate" => frame.predicate
    "graph" => frame.graph
    _ => None
  }
}

///|
/// 帧写地址解析（§AN.13 投影写实）：`frame.top.<位>` → 后态**帧顶**（偏移 0）；
/// `frame.below.<位>` → 后态**次顶**（偏移 1，效果通道压帧行的体写）；
/// `frame.<位>`（无地址老形）按帧顶读，容错用。
fn frame_address(target : String) -> (Int, String)? {
  if target.has_prefix("frame.top.") {
    Some((0, target[10:].to_owned()))
  } else if target.has_prefix("frame.below.") {
    Some((1, target[12:].to_owned()))
  } else if target.has_prefix("frame.") {
    Some((0, target[6:].to_owned()))
  } else {
    None
  }
}

///|
/// 帧面写项的**期望值**解析：左值域按字段定（布尔位 / 态位 / 栈深 / Span 值域），
/// 右值走与槽位同一张来源词表（含 `frame.<字段>` 读**行进前**帧顶）。
fn classify_face_expect(
  target : String,
  source : String,
  before_slots : SlotView,
  before : FaceLedger,
  payload : RefId,
  args : Array[String],
) -> Result[FaceValue, String] {
  if target == "is_depth" {
    if source == "frames_len" {
      return Ok(FInt(before.frames.length()))
    }
    return Err("\{source}（`is_depth` 只认 `frames_len`）")
  }
  // 倒装交换键（`is_of`/`<-` 落账）：与槽位同词表的 Span 来源
  if target == "is_src" {
    match
      resolve_span_source(target, source, before_slots, before, payload, args) {
      Ok(v) => return Ok(FRef(v))
      Err(why) => return Err(why)
    }
  }
  let field : String = match frame_address(target) {
    Some(pair) => pair.1
    None => return Err("\{target}（非帧面目标）")
  }
  if field == "is_formula" || field == "as_pred" || field == "as_subject" {
    if source == "true" {
      return Ok(FBool(true))
    }
    if source == "false" {
      return Ok(FBool(false))
    }
    return Err("\{source}（布尔帧位只认 true/false 字面）")
  }
  // `frame.ret_state`：投影侧已把 `to` 写实成**行目标态名**（§AN.13）
  if field == "ret_state" {
    return Ok(FState(source))
  }
  if field == "node_seq" {
    return Err("\{source}（node_seq 尚无可声明来源）")
  }
  match
    resolve_span_source(target, source, before_slots, before, payload, args) {
    Ok(v) => Ok(FRef(v))
    Err(why) => Err(why)
  }
}

///|
/// 面外账本**目标位当前值**（与期望值同值域）
fn face_target_value(ledger : FaceLedger, target : String) -> FaceValue? {
  if target == "is_src" {
    return Some(FRef(ledger.is_src))
  }
  if target == "is_depth" {
    return Some(FInt(ledger.is_depth))
  }
  match frame_address(target) {
    Some(pair) => {
      let (offset, field) = pair
      let depth = ledger.frames.length()
      if depth < offset + 1 {
        return None
      }
      let frame = ledger.frames[depth - 1 - offset]
      match field {
        "is_formula" => Some(FBool(frame.is_formula))
        "as_pred" => Some(FBool(frame.as_pred))
        "as_subject" => Some(FBool(frame.as_subject))
        "ret_state" => Some(FState(frame.ret_state_name))
        "node_seq" => Some(FInt(frame.node_seq))
        "open_span" | "prev_node" | "subject" | "predicate" | "graph" =>
          Some(FRef(frame_ref_field(frame, field)))
        _ => None
      }
    }
    None => None
  }
}

///|
/// **来源词表**解析（左值无关的那半）：`none` / `argN`（按 `args` 列解引用）/ `ctx.<槽>` /
/// `fwd:`/`nfwd:` 条件式 / `frame.<字段>`（读**行进前**帧顶）。`Ok(期望值)` = 可比。
fn resolve_span_source(
  target : String,
  source : String,
  before : SlotView,
  ledger : FaceLedger,
  payload : RefId,
  args : Array[String],
) -> Result[RefId?, String] {
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
      // §AN.12：`keep` = 方言缺省绑定的"**无 span 事件**"半——生成器渲染 `model.<目标槽>`
      // （保持既有槽）⇒ 期望值 = **行进前该槽值**。
      if bound == "keep" {
        return Ok(slot_get(before, target))
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
  // **条件式来源**（§AN.12）：`fwd:<a>|<b>` / `nfwd:<a>|<b>`——按**行进前方向旗**
  // （`SlotView.path_fwd`；旗标槽名是方言数据 `[type_mapping].fwd_slot`，n3 = `path_fwd`）
  // 二选一，选中的那一半**递归**按同一张词表解析。
  // 注：`nfwd:` 且该行有 `assign = path_fwd=<v>` 者，其"翻后旗"是**编译期常量**
  // ⇒ 已在投影侧（`actions_truth` 产出）坍缩成定值，快照里不会出现该形。
  if source.has_prefix("fwd:") || source.has_prefix("nfwd:") {
    let rest : String = if source.has_prefix("fwd:") {
      source[4:].to_owned()
    } else {
      source[5:].to_owned()
    }
    match rest.find("|") {
      Some(bar) => {
        let chosen : String = if before.path_fwd {
          rest[0:bar].to_owned()
        } else {
          rest[bar + 1:].to_owned()
        }
        return resolve_span_source(
          target, chosen, before, ledger, payload, args,
        )
      }
      None => return Err("\{source}（条件式缺 `|`）")
    }
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
  // 帧内来源（`frame.prev_node` 这类**读**）：§AN.13 帧面开面后按**行进前帧顶**取值
  // （读的是"压帧前那一刻"的帧顶，与引擎"先读后写"同序）。
  if source.has_prefix("frame.") {
    let field : String = source[6:].to_owned()
    if !["open_span", "prev_node", "subject", "predicate", "graph"].contains(
        field,
      ) {
      return Err("\{source}（帧位非 Span 值域）")
    }
    match ledger.frames.last() {
      Some(top) => return Ok(frame_ref_field(top, field))
      None => return Err("\{source}（帧栈空）")
    }
  }
  Err("\{source}（首片不解析）")
}

///|
/// 写项来源解析（**槽位**目标）：左值须在观测面内，右值走 `resolve_span_source`
fn classify_write_source(
  target : String,
  source : String,
  before : SlotView,
  ledger : FaceLedger,
  payload : RefId,
  args : Array[String],
) -> Result[RefId?, String] {
  if !slot_in_view(target) {
    return Err("\{target}（槽在观测面外）")
  }
  resolve_span_source(target, source, before, ledger, payload, args)
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
    // **面外账本**前值（§AN.13 帧面）：帧栈 + 倒装两槽——供 `frame.*` 读源、`is_src`/`is_depth`
    // 与帧写落位取值。
    let before_ledger = face_ledger_of_engine(system.probe)
    // §AN.14：弹帧行（`returns` 有 `PopBnp`）的 `writes` 已被投影换成**行终态**
    // （`pop_writes` 臂：弹帧恢复值 + 尾随 scope 收拾已折进声明）⇒ 下述 scope 复位**不再叠加**。
    let pop_row = row.returns.contains("PopBnp")
    // ④ **逐项**解析期望：可比项照比，不可比项只把**该项**入册。
    // 负控①实测教训：整行入册会让"行内可比槽"也失去判据（改 `subject=none` 竟不红）⇒ 降为逐项。
    let expected_items : Array[(String, RefId?)] = []
    let expected_faces : Array[(String, FaceValue)] = []
    for item in row.writes {
      let pair = item.split("=").to_array()
      if pair.length() != 2 {
        incomparable.push("\{key}：\{item}（非 tgt=src 形）")
        continue
      }
      let raw_target = pair[0].to_owned()
      // 防御位：被弹帧写（§AN.14 起**投影已剔**——被弹帧后态不存在 ⇒ 值级面不可读）。
      // 若仍冒头即投影退步（本支只为把它**如实入册**，不做静默跳过；台账钉死会红）。
      if raw_target.has_prefix("frame.popped.") {
        incomparable.push(
          "\{key}·\{raw_target}：被弹帧写未被投影剔除（§AN.14 退步）",
        )
        continue
      }
      // 面外账本目标位（`frame.<字段>` / `is_src` / `is_depth`）
      if raw_target.has_prefix("frame.") ||
        raw_target == "is_src" ||
        raw_target == "is_depth" {
        match
          classify_face_expect(
            raw_target,
            pair[1].to_owned(),
            before,
            before_ledger,
            payload,
            row.args,
          ) {
          Ok(value) => expected_faces.push((raw_target, value))
          Err(why) => incomparable.push("\{key}·\{raw_target}：\{why}")
        }
        continue
      }
      match
        classify_write_source(
          pair[0].to_owned(),
          pair[1].to_owned(),
          before,
          before_ledger,
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
    let after_ledger = face_ledger_of_engine(system.probe)
    // 发射 scope 复位（债点裁定的结论）：EmitQuad(<Scope>) 之后 loop 按 scope 清槽 ⇒
    // 期望值 = 写槽后**再**按 scope 置 None。**§AN.14**：弹帧行的声明已是**行终态**
    // （`pop_writes` 臂把弹帧恢复与尾随收拾一并写实）⇒ 本步跳过，免得二次清槽。
    let reset_slots : Array[String] = if pop_row {
      []
    } else {
      scope_reset_slots(row.returns)
    }
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
    // 面外账本逐位比对（帧顶 / 倒装两槽）
    for entry in expected_faces {
      let (target, want) = entry
      let got = face_target_value(after_ledger, target)
      let ok = match got {
        Some(actual_value) => face_value_eq(want, actual_value)
        None => false
      }
      if !ok {
        mismatches.push(
          "\{key}·\{target}：期望 \{face_value_text(want)} 实得 \{match got { Some(v) => face_value_text(v); None => "（无帧）" }}（响应 \{response_short(response)}）",
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
  // 台账**按类钉死**（首跑回填；任一类数字变化即红——比"只钉总数"强，能抓类间搬家）。
  // 沿革：83（§AN.10 末）→ 77（§AN.11）→ 81（§AN.12 修截断后如实露出）→ **0 面外（§AN.13 帧面开面）**：
  // 帧栈 + 倒装两槽进观测面 ⇒ 压帧落位/帧读/`is_src`/`is_depth` 全部转真判，
  // 只剩 **`pop_writes` 立项族 15 项**（弹帧行的"行终态"数据面尚无声明通道）。
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
  // **四类全零**（§AN.13 帧面 + §AN.14 终态臂）：观测面外已无成员，全部写槽皆有判据
  assert_eq(off_face, 0)
  assert_eq(order_sensitive, 0)
  // 条件式（fwd:/nfwd:）**清零**（§AN.12）：运行时旗读 + `nfwd:` 编译期坍缩
  assert_eq(conditional, 0)
  // `argN` 未解析形态**清零**（§AN.12）：缺省绑定写实（span 事件 ⇒ payload）后 76 项转真判
  assert_eq(arg_unparsed, 0)
}
