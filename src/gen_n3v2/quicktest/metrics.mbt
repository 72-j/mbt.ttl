// ========================================
// Metrics — 枚举件 + 全臂冒烟门（**手维护层**；对齐 trig quicktest 的 metrics.mbt 角色）
// ========================================
// 定位（src/ttl/todo.md §C 役 14 的第一步可跑件）：先给「全状态 / 全命令」枚举与全臂冒烟，
// 覆盖率门（路径驱动）/结构钉子/引擎侧普查按 trig P4.3 形态在其上继续搭。
// 纪律：枚举是**手工维护**的数据面——IR（n3_fsm.toml）变了这里必须同笔改，数字门会替你把关。

///|
/// 全部状态（源 [[states]]，55 个；R-18 同源刷新 +BnpExpectIdNode/+BnpIdAfterClose）
fn all_states() -> Array[ModelState] {
  [
    ExpectSubject,
    ExpectPredicate,
    ExpectObject,
    ExpectDotOrGraph,
    ExpectDirectiveKind,
    ExpectPrefixName,
    ExpectPrefixIri,
    ExpectBaseIri,
    ExpectVersionLiteral,
    ExpectDirectiveEnd,
    ExpectKeywordsList,
    ExpectVerbOrEnd,
    ExpectVerbOrDot,
    ExpectVerbRequired,
    ExpectTildeEnd,
    AnnotExpectVerb,
    AnnotExpectVerbTail,
    AnnotExpectObject,
    AnnotExpectEnd,
    BnpExpectPredicate,
    BnpExpectIdNode,
    BnpExpectObject,
    BnpAfterObject,
    BnpIdAfterClose,
    ListExpectElemOrEnd,
    ListAfterElem,
    FormulaExpectSubject,
    FormulaExpectPredicate,
    FormulaExpectObject,
    FormulaAfterObject,
    PathExpectVerb,
    PathAfterStep,
    FormulaPathExpectVerb,
    FormulaPathAfterStep,
    ExpectIsProp,
    ExpectIsOf,
    BnpExpectIsProp,
    BnpExpectIsOf,
    FormulaExpectIsProp,
    FormulaExpectIsOf,
    QuantExpectVar,
    QuantExpectVarOrDot,
    FormulaDirectiveKind,
    FormulaQuantExpectVar,
    FormulaQuantExpectVarOrDot,
    SubjTrailExpectVerb,
    SubjTrailAfterStep,
    SubjTrailVerbDone,
    SubjTrailExpectVerbFormula,
    SubjTrailAfterStepFormula,
    SubjTrailVerbDoneFormula,
    ListPathExpectVerb,
    ListPathAfterStep,
    ObjTrailExpectVerb,
    ObjTrailAfterStep,
  ]
}

///|
/// 全部命令（源 weights 表 41 个事件；`@qcs.Ref` 统一取 `Concrete(id = 1)`）
fn all_commands() -> Array[Command] {
  let reference : @qcs.Ref[RefId] = Concrete({ id: 1, })
  [
    Iri(reference),
    BlankNode(reference),
    Literal(reference),
    PrefName(reference),
    TripleTerm(reference),
    BracketTripleTerm(reference),
    KeywordA(reference),
    Variable(reference),
    KeywordX(reference),
    Equals(reference),
    Is,
    Of,
    Has,
    At,
    PrefixKw,
    BaseKw,
    VersionKw,
    Tilde,
    AnnotStart,
    AnnotEnd,
    ForAllKw,
    ForSomeKw,
    KeywordsKw,
    Comma,
    Semicolon,
    Dot,
    Lbrace(reference),
    Rbrace,
    Lbracket(reference),
    Rbracket,
    Lparen(reference),
    Rparen,
    Anon(reference),
    Bang(reference),
    Caret(reference),
    Implies(reference),
    ImpliedBy(reference),
    Unknown(reference),
    Id,
    Invert,
    EOF,
  ]
}

///|
/// 空槽模型（只定状态）：普查 / 冒烟的统一起点
fn blank_model(state : ModelState) -> Model {
  { ..model_empty(), state, }
}

///|
/// **全臂冒烟门**：55 状态 × 41 命令，每对都跑一次 `model_execute`。
/// 判据两条：
///   ① 对数守恒（55 × 41 = 2255）——防枚举漏项；
///   ② 合法对 = **384**（= `valid.mbt` 真行数 = Meta 全表 = 在库臂数；R-18 后
///     53/376 → 55/384，全表有效无裁行）——结构钉子：臂表漂了这里就红。
/// 本门只证"每条臂都能执行一次"（覆盖率用途），**不**替代随机门/锚点门的语义对拍。
test "n3v2 全臂冒烟：55×41 全对 + 合法对 384（臂表结构钉）" {
  let mut pairs = 0
  let mut legal = 0
  for state in all_states() {
    for command in all_commands() {
      let model = blank_model(state)
      let _ = model_execute(model, command)
      pairs = pairs + 1
      if valid(model, command) {
        legal = legal + 1
      }
    }
  }
  assert_eq(pairs, 55 * 41)
  assert_eq(legal, 384)
}

///|
/// **权重表钉子**：41 名逐条等值 + 表外名回落 1。
/// 权重决定随机门的分布（属判据面）⇒ 改表即红，必须与
/// `src/quick_machine/quick_machine_n3.toml` 的 `[business.weights]` 同笔说明。
test "n3v2 权重表逐名等值（41 名全量 + 默认档）" {
  let expected : Array[(String, Int)] = [
    ("At", 1),
    ("Is", 0),
    ("Of", 0),
    ("Dot", 3),
    ("EOF", 0),
    ("Has", 0),
    ("Iri", 3),
    ("Anon", 0),
    ("Bang", 0),
    ("Caret", 0),
    ("Comma", 1),
    ("Tilde", 1),
    ("BaseKw", 1),
    ("Equals", 1),
    ("Lbrace", 0),
    ("Lparen", 0),
    ("Rbrace", 0),
    ("Rparen", 0),
    ("Implies", 0),
    ("Literal", 3),
    ("Unknown", 0),
    // R-18 后 Id/Invert 行落地 ⇒ 排除理由改为 R-17 值级缺口，仍显式 0（未列默认 1 陷阱）
    ("Id", 0),
    ("Invert", 0),
    ("AnnotEnd", 0),
    ("ForAllKw", 0),
    ("KeywordA", 0),
    ("KeywordX", 0),
    ("Lbracket", 0),
    ("PrefName", 2),
    ("PrefixKw", 1),
    ("Rbracket", 0),
    ("Variable", 0),
    ("BlankNode", 2),
    ("ForSomeKw", 0),
    ("ImpliedBy", 0),
    ("Semicolon", 1),
    ("VersionKw", 0),
    ("AnnotStart", 0),
    ("KeywordsKw", 0),
    ("TripleTerm", 0),
    ("BracketTripleTerm", 0),
  ]
  // 权重表全量 = 命令枚举全量（两条清单漂了就红）
  assert_eq(expected.length(), 41)
  assert_eq(all_commands().length(), expected.length())
  for case in expected {
    let (name, weight) = case
    assert_eq(command_weight(name), weight)
  }
  // 顺带钉住"枚举名 ⊆ 权重表名"（名字拼错/漏项即红）
  let declared = expected.map(fn(pair) { pair.0 })
  for command in all_commands() {
    assert_true(declared.contains(command_name(command)))
  }
  assert_eq(command_weight("NotDeclared"), 1)
}

///|
/// 沿路径推状态（只走模型；定位用）
fn path_end_state(path : Array[Command]) -> ModelState {
  let mut state = ExpectSubject
  for command in path {
    let (next, _) = model_execute(blank_model(state), command)
    state = next.state
  }
  state
}

///|
/// 状态名（账与报告用；生成件只产了 `command_name`，状态名是手维护件）
fn state_name(state : ModelState) -> String {
  match state {
    ExpectSubject => "ExpectSubject"
    ExpectPredicate => "ExpectPredicate"
    ExpectObject => "ExpectObject"
    ExpectDotOrGraph => "ExpectDotOrGraph"
    ExpectDirectiveKind => "ExpectDirectiveKind"
    ExpectPrefixName => "ExpectPrefixName"
    ExpectPrefixIri => "ExpectPrefixIri"
    ExpectBaseIri => "ExpectBaseIri"
    ExpectVersionLiteral => "ExpectVersionLiteral"
    ExpectDirectiveEnd => "ExpectDirectiveEnd"
    ExpectKeywordsList => "ExpectKeywordsList"
    ExpectVerbOrEnd => "ExpectVerbOrEnd"
    ExpectVerbOrDot => "ExpectVerbOrDot"
    ExpectVerbRequired => "ExpectVerbRequired"
    ExpectTildeEnd => "ExpectTildeEnd"
    AnnotExpectVerb => "AnnotExpectVerb"
    AnnotExpectVerbTail => "AnnotExpectVerbTail"
    AnnotExpectObject => "AnnotExpectObject"
    AnnotExpectEnd => "AnnotExpectEnd"
    BnpExpectPredicate => "BnpExpectPredicate"
    BnpExpectIdNode => "BnpExpectIdNode"
    BnpExpectObject => "BnpExpectObject"
    BnpAfterObject => "BnpAfterObject"
    BnpIdAfterClose => "BnpIdAfterClose"
    ListExpectElemOrEnd => "ListExpectElemOrEnd"
    ListAfterElem => "ListAfterElem"
    FormulaExpectSubject => "FormulaExpectSubject"
    FormulaExpectPredicate => "FormulaExpectPredicate"
    FormulaExpectObject => "FormulaExpectObject"
    FormulaAfterObject => "FormulaAfterObject"
    PathExpectVerb => "PathExpectVerb"
    PathAfterStep => "PathAfterStep"
    FormulaPathExpectVerb => "FormulaPathExpectVerb"
    FormulaPathAfterStep => "FormulaPathAfterStep"
    ExpectIsProp => "ExpectIsProp"
    ExpectIsOf => "ExpectIsOf"
    BnpExpectIsProp => "BnpExpectIsProp"
    BnpExpectIsOf => "BnpExpectIsOf"
    FormulaExpectIsProp => "FormulaExpectIsProp"
    FormulaExpectIsOf => "FormulaExpectIsOf"
    QuantExpectVar => "QuantExpectVar"
    QuantExpectVarOrDot => "QuantExpectVarOrDot"
    FormulaDirectiveKind => "FormulaDirectiveKind"
    FormulaQuantExpectVar => "FormulaQuantExpectVar"
    FormulaQuantExpectVarOrDot => "FormulaQuantExpectVarOrDot"
    SubjTrailExpectVerb => "SubjTrailExpectVerb"
    SubjTrailAfterStep => "SubjTrailAfterStep"
    SubjTrailVerbDone => "SubjTrailVerbDone"
    SubjTrailExpectVerbFormula => "SubjTrailExpectVerbFormula"
    SubjTrailAfterStepFormula => "SubjTrailAfterStepFormula"
    SubjTrailVerbDoneFormula => "SubjTrailVerbDoneFormula"
    ListPathExpectVerb => "ListPathExpectVerb"
    ListPathAfterStep => "ListPathAfterStep"
    ObjTrailExpectVerb => "ObjTrailExpectVerb"
    ObjTrailAfterStep => "ObjTrailAfterStep"
  }
}

///|
/// 该命令名在**任意状态**上是否有出边（= "可达命令名"口径，与 `valid` 同源）
fn transition_expectation_is_anywhere(name : String) -> Bool {
  let mut hit = false
  for state in all_states() {
    for command in all_commands() {
      if command_name(command) == name && valid(blank_model(state), command) {
        hit = true
      }
    }
  }
  hit
}

///|
/// **P5.6 记账（第一版：先要可达，再谈最短）**：每个可达命令名一条**从初始状态可达**的见证路径。
/// 同源口径：起点 = `ExpectSubject`（IR 的 is_initial）；边 = `valid`（= `[[transitions]]` 派生）；
/// 下一态**跑模型**取；命令名归一 = `command_name`。
/// **纪律**：覆盖率门的名单必须由本函数派生，不许在门里手抄（trig P4.3 的教训）。
/// 注意：本函数只走表（纯结构），返回的路径**尚未**经引擎验证 ⇒ 下一步必须逐条起跑验证。
fn reachable_witness_paths() -> Array[(String, Array[Command])] {
  let found : Array[(String, Array[Command])] = []
  let queue : Array[Array[Command]] = [[]]
  let seen : Array[ModelState] = [ExpectSubject]
  while queue.length() > 0 {
    let path = queue.remove(0)
    let state = path_end_state(path)
    for command in all_commands() {
      if valid(blank_model(state), command) {
        let (next_model, _) = model_execute(blank_model(state), command)
        let next_state = next_model.state
        let new_path = path.copy()
        new_path.push(command)
        let name = command_name(command)
        if !found.any(fn(pair) { pair.0 == name }) {
          found.push((name, new_path))
        }
        if !seen.contains(next_state) {
          seen.push(next_state)
          queue.push(new_path)
        }
      }
    }
  }
  found
}

///|
/// P5.6 账·存在性（先要可达，再谈最短）：表上"有出边"的每个命令名都必须有见证路径。
test "n3v2 P5.6 账·存在性: 每个可达命令名都有见证路径" {
  let witnesses = reachable_witness_paths()
  let names = witnesses.map(fn(pair) { pair.0 })
  for command in all_commands() {
    let name = command_name(command)
    if transition_expectation_is_anywhere(name) {
      assert_true(names.contains(name))
    }
  }
  debug(
    "n3v2 P5.6 见证路径账（\{witnesses.length()} 名 / 命令名共 \{all_commands().length()}）：",
  )
  for pair in witnesses {
    debug(
      "  \{pair.0} ← \{pair.1.map(fn(c) { command_name(c) }).join(" → ")}",
    )
  }
}

///|
/// P5.6 账·逐条起跑验证（**覆盖率门的前置**）：每条见证路径独立起跑（新 probe + 新模型），
/// 逐步比对「模型预测 ⟷ 引擎响应」。任何一条分道都说明该路径还不能当门的用例。
test "n3v2 P5.6 账·逐条起跑验证: 见证路径独立复位 + 引擎⟷模型逐步一致" {
  let mut verified = 0
  let mismatched : Array[String] = []
  for pair in reachable_witness_paths() {
    let (name, path) = pair
    let system = system_init()
    let mut model = model_empty()
    let mut ok = true
    for command in path {
      let (next, expected) = model_execute(model, command)
      let actual = run_command(command, system)
      if actual != expected {
        ok = false
      }
      model = next
    }
    if ok {
      verified = verified + 1
    } else {
      mismatched.push(name)
    }
  }
  debug(
    "n3v2 P5.6 逐条起跑：通过 \{verified} 名；分道 \{mismatched.length()} 名",
  )
  for name in mismatched {
    debug("  分道：\{name}")
  }
  assert_eq(mismatched, [])
}

///|
/// 覆盖率门的**逐路径用例配置**：一条见证路径 = 一个用例，只扛**它自己那一个**命令名。
/// 依据：qcs 覆盖判据是**逐用例**的（`CoverageFailed(missing_command_names=…)`）——
/// 38 条路径塞进一个用例会互相污染状态，故必须一条一路径（天然满足"独立起跑 + 干净复位"）。
fn path_coverage_config(path : Array[Command], name : String) -> @qcs.RunConfig {
  {
    ..quick_run_config(),
    cases: 1,
    max_commands: path.length(),
    required_labels: [],
    required_command_names: [name],
  }
}

///|
/// **P5.6 覆盖率门（路径驱动 + 逐条独立复位）**：每条见证路径新开一次 `check`；
/// 返回**失败的命令名**清单（空 = 门全绿）。名单由 `reachable_witness_paths()` 派生，**不手抄**。
/// 覆盖判据本身只证"该命令名被这条脚本走到"；语义仍由 `check` 内的「模型 ≡ 引擎」比对承担。
fn run_path_coverage_gate() -> Array[String] {
  let failed : Array[String] = []
  for pair in reachable_witness_paths() {
    let (name, path) = pair
    match
      @qcs.check(
        quick_state_machine(script=Some(path)),
        config=path_coverage_config(path, name),
      ) {
      Ok(_) => ()
      Err(_) => failed.push(name)
    }
  }
  failed
}

///|
/// P5.6 覆盖率门（开启）：38 条见证路径各自一个用例、独立起跑；失败以"具体命令名清单"落地。
test "n3v2 P5.6 覆盖率门（路径驱动，逐条独立复位）" {
  assert_eq(run_path_coverage_gate(), [])
}

///|
/// 结构钉子用的可达状态集（BFS，边口径同上）
fn reachable_states() -> Array[ModelState] {
  let seen : Array[ModelState] = [ExpectSubject]
  let queue : Array[Array[Command]] = [[]]
  while queue.length() > 0 {
    let path = queue.remove(0)
    // 槽感知扩展（役 7 翻案修正，2026-09-18）：原版用 blank_model(state)（无帧无槽）
    // 扩展 ⇒ ret_state 帧弹回类入口（ExpectVerbRequired，model_exec:66/78 唯一入口）
    // 永远探不到 ⇒ 欠数 52。改用真路径模型（帧栈在位）⇒ 53/53 全可达。
    let model = path_end_model(path)
    for command in all_commands() {
      if valid(model, command) {
        let (next_model, _) = model_execute(model, command)
        let next_state = next_model.state
        if !seen.contains(next_state) {
          seen.push(next_state)
          let new_path = path.copy()
          new_path.push(command)
          queue.push(new_path)
        }
      }
    }
  }
  seen
}

///|
/// **结构钉子**（先记事实，不美化）：可达状态数 / 可达命令名数 / 命令枚举总数。
/// 数字变化即红 ⇒ 改模型或改表必须同笔说明（新状态进/出视野是有意义的事件）。
test "n3v2 结构钉子: 可达状态 / 可达命令名 / 死态" {
  let states = reachable_states()
  let witnesses = reachable_witness_paths()
  // 数字钉死（漂了先看上面的"不可达/无出边"两行）：改模型或改表必须同笔说明
  // 【52 → 53 翻案（役 7，2026-09-18）】：原 52 是 blank_model 槽盲扩展的 artifact
  // ——ExpectVerbRequired 唯一入口 = frame_push 的 ret_state 帧弹回（model_exec:66/78），
  // 槽盲探不到。槽感知后 53/53 全可达（"不可达"清单应为空）。
  // 【53 → 54（R-18，2026-09-18）】：+BnpExpectIdNode（入口 = BnpExpectPredicate+Id 表行）
  // 可达；**BnpIdAfterClose 死态（54/55）**：其唯一入边不在表上——引擎运行时
  // set_id_subject 的 as_subject 特例改写帧 ret_state（actions.mbt:200），与
  // ExpectVerbRequired 帧弹回同族；模型未识别 set_id_subject（R-17 浅半，TODO(P0)）
  // 故探不到 = 债点计入普查，清偿后即 55/55。
  assert_eq(states.length(), 54)
  assert_eq(witnesses.length(), 40)
  debug(
    "n3v2 结构钉：可达状态 \{states.length()}/\{all_states().length()}；可达命令名 \{witnesses.length()}/\{all_commands().length()}",
  )
  // 记账而不美化：不可达的状态名与"表上无出边"的命令名都打出来（数字漂了先看这里）
  for state in all_states() {
    if !states.contains(state) {
      debug("  不可达状态：\{state_name(state)}")
    }
  }
  for command in all_commands() {
    if !transition_expectation_is_anywhere(command_name(command)) {
      debug("  表上无出边的命令名：\{command_name(command)}")
    }
  }
  // 无死态：每个可达状态至少有一条合法出边（否则运行期必然 Deadlock）
  for state in states {
    let mut has_edge = false
    for command in all_commands() {
      if valid(blank_model(state), command) {
        has_edge = true
      }
    }
    assert_true(has_edge)
  }
}

///|
/// **多种子随机门**（役 14 step 4；对齐 trig 役 3 / nquads `runner.mbt:248` 模板）：
/// 主门只跑 `seed = 12345`（一条轨迹上的等价）；本门补**探索面上的等价**——
/// 判据与主门同规，种子只改路径、不改判定。
test "n3v2 随机门多种子稳定（1 / 2026）" {
  for seed in [1UL, 2026UL] {
    let config : @qcs.RunConfig = { ..quick_run_config(), seed, }
    match run_random_check(config~) {
      Ok(report) => assert_eq(report.cases_run, config.cases)
      Err(failure) =>
        fail(
          "seed \{seed} random check failed: \{@qcs.format_failure(failure)}",
        )
    }
  }
}
// ===== 役 7：引擎侧独立转移普查（2026-09-18）=====

///|
/// 穷尽桥（引擎态 → 模型态）：**引擎加/删状态而桥没跟上 ⇒ 编译不过**（trig 役 7
/// 同铁律）。沿革（R-18 清偿，2026-09-18）：`BnpExpectIdNode`/`BnpIdAfterClose`
/// 两臂原为 `None`（stale IR 无模型对应，役 7 记录在案）——IR 同源刷新后模型
/// 镜像了两态，改 `Some`，普查门分母同笔收紧（53→55 态）。
fn model_state_of_engine(state : @n3.N3State) -> ModelState? {
  match state {
    @n3.N3ExpectSubject => Some(ExpectSubject)
    @n3.N3ExpectPredicate => Some(ExpectPredicate)
    @n3.N3ExpectObject => Some(ExpectObject)
    @n3.N3ExpectDotOrGraph => Some(ExpectDotOrGraph)
    @n3.N3ExpectDirectiveKind => Some(ExpectDirectiveKind)
    @n3.N3ExpectPrefixName => Some(ExpectPrefixName)
    @n3.N3ExpectPrefixIri => Some(ExpectPrefixIri)
    @n3.N3ExpectBaseIri => Some(ExpectBaseIri)
    @n3.N3ExpectVersionLiteral => Some(ExpectVersionLiteral)
    @n3.N3ExpectDirectiveEnd => Some(ExpectDirectiveEnd)
    @n3.N3ExpectKeywordsList => Some(ExpectKeywordsList)
    @n3.N3ExpectVerbOrEnd => Some(ExpectVerbOrEnd)
    @n3.N3ExpectVerbOrDot => Some(ExpectVerbOrDot)
    @n3.N3ExpectVerbRequired => Some(ExpectVerbRequired)
    @n3.N3ExpectTildeEnd => Some(ExpectTildeEnd)
    @n3.N3AnnotExpectVerb => Some(AnnotExpectVerb)
    @n3.N3AnnotExpectVerbTail => Some(AnnotExpectVerbTail)
    @n3.N3AnnotExpectObject => Some(AnnotExpectObject)
    @n3.N3AnnotExpectEnd => Some(AnnotExpectEnd)
    @n3.N3BnpExpectPredicate => Some(BnpExpectPredicate)
    @n3.N3BnpExpectIdNode => Some(BnpExpectIdNode) // R-18 收编（沿革见函数头）
    @n3.N3BnpExpectObject => Some(BnpExpectObject)
    @n3.N3BnpAfterObject => Some(BnpAfterObject)
    @n3.N3BnpIdAfterClose => Some(BnpIdAfterClose) // R-18 收编（沿革见函数头）
    @n3.N3ListExpectElemOrEnd => Some(ListExpectElemOrEnd)
    @n3.N3ListAfterElem => Some(ListAfterElem)
    @n3.N3FormulaExpectSubject => Some(FormulaExpectSubject)
    @n3.N3FormulaExpectPredicate => Some(FormulaExpectPredicate)
    @n3.N3FormulaExpectObject => Some(FormulaExpectObject)
    @n3.N3FormulaAfterObject => Some(FormulaAfterObject)
    @n3.N3PathExpectVerb => Some(PathExpectVerb)
    @n3.N3PathAfterStep => Some(PathAfterStep)
    @n3.N3FormulaPathExpectVerb => Some(FormulaPathExpectVerb)
    @n3.N3FormulaPathAfterStep => Some(FormulaPathAfterStep)
    @n3.N3ExpectIsProp => Some(ExpectIsProp)
    @n3.N3ExpectIsOf => Some(ExpectIsOf)
    @n3.N3BnpExpectIsProp => Some(BnpExpectIsProp)
    @n3.N3BnpExpectIsOf => Some(BnpExpectIsOf)
    @n3.N3FormulaExpectIsProp => Some(FormulaExpectIsProp)
    @n3.N3FormulaExpectIsOf => Some(FormulaExpectIsOf)
    @n3.N3QuantExpectVar => Some(QuantExpectVar)
    @n3.N3QuantExpectVarOrDot => Some(QuantExpectVarOrDot)
    @n3.N3FormulaDirectiveKind => Some(FormulaDirectiveKind)
    @n3.N3FormulaQuantExpectVar => Some(FormulaQuantExpectVar)
    @n3.N3FormulaQuantExpectVarOrDot => Some(FormulaQuantExpectVarOrDot)
    @n3.N3SubjTrailExpectVerb => Some(SubjTrailExpectVerb)
    @n3.N3SubjTrailAfterStep => Some(SubjTrailAfterStep)
    @n3.N3SubjTrailVerbDone => Some(SubjTrailVerbDone)
    @n3.N3SubjTrailExpectVerbFormula => Some(SubjTrailExpectVerbFormula)
    @n3.N3SubjTrailAfterStepFormula => Some(SubjTrailAfterStepFormula)
    @n3.N3SubjTrailVerbDoneFormula => Some(SubjTrailVerbDoneFormula)
    @n3.N3ListPathExpectVerb => Some(ListPathExpectVerb)
    @n3.N3ListPathAfterStep => Some(ListPathAfterStep)
    @n3.N3ObjTrailExpectVerb => Some(ObjTrailExpectVerb)
    @n3.N3ObjTrailAfterStep => Some(ObjTrailAfterStep)
  }
}

///|
/// 沿路径推模型（役 7 输入件；`path_end_state` 只给终态，普查要**整模型**好续步）
fn path_end_model(path : Array[Command]) -> Model {
  let mut model = model_empty()
  for command in path {
    let (next, _) = model_execute(model, command)
    model = next
  }
  model
}

///|
/// **状态见证路径账**（役 7 输入）：每个可达状态一条从初态可达的路径——普查要
/// "把引擎开到某状态"，需要的是**路**不是名单。与 `reachable_witness_paths()`
/// （按**命令名**记账，役 14）同边口径（边 = `valid`，下一态跑模型），差别只在记账键。
fn reachable_state_witness_paths() -> Array[(ModelState, Array[Command])] {
  let found : Array[(ModelState, Array[Command])] = [(ExpectSubject, [])]
  let queue : Array[Array[Command]] = [[]]
  while queue.length() > 0 {
    let path = queue.remove(0)
    let model = path_end_model(path)
    for command in all_commands() {
      if valid(model, command) {
        let (next, _) = model_execute(model, command)
        if !found.any(fn(pair) { pair.0 == next.state }) {
          let new_path = path.copy()
          new_path.push(command)
          found.push((next.state, new_path))
          queue.push(new_path)
        }
      }
    }
  }
  found
}

///|
/// **役 7：引擎侧独立转移普查**（trig 役 7 同门形，三处 n3 化裁剪）：
/// 对每个可达状态（沿状态见证路径开过去）逐条喂命令，比对「引擎归一响应 + 引擎
/// 状态 ⟷ 模型预测」；每对**新建 probe = 干净复位**；失败输出 (状态+命令) 清单。
/// 规模 = 54 可达态 × 41 命令 = **2214 对**（R-18 后 53×39=2067 → 54×41=2214：
/// +BnpExpectIdNode 见证态、+Id/Invert 词表——前提是槽感知可达性：ExpectVerbRequired
/// 靠 ret_state 帧弹回可达，blank_model 槽盲扩展漏之）。
///
/// **裁剪①（分层比对，n3 独有）**：正片事件（`command_weight > 0`，同源派生自
/// 业务面权重表）比「响应+状态」全量；排除片（权重 0）**只比状态**——其响应载荷
/// 缺口 = R-17 值级建模债（倒装/壳交换改 quad 内容、不改状态），不在此硬凑
/// （todo §6.2/§8.1）。R-17/R-18 清偿抬高权重后，本门自动收紧，无需改码。
///
/// **裁剪②（Option 桥）**：沿革（R-18 清偿，2026-09-18）——两枚切片态原桥返 None，
/// 同源刷新后桥已 `Some` 收编；Id/Invert 已入 41 命令词表，`BnpExpectIdNode` 入
/// 见证清单（54 态），`BnpIdAfterClose` 因入边是运行时帧改写仍不可达（结构钉子 54/55）。
///
/// **裁剪③（分类门）**：首跑实测 92 分道**全部**落在 6 个 trail/Path 态（尾随/路径
/// 深机械 = prev_node 帧扩展位，R-17 领土），干净领土零分道 ⇒ 门形分两向：
/// **违例**（干净领土分道 = 红线，必须空）+ **债点**（trail 族分道点 = R-17 可执行
/// 台账，数字钉死）。分道按**分道步的当前 (状态,命令)** 归类，非见证路径终点。
/// （trig 无此裁剪：34/34 全同步、无排除片、零分道。）
test "指标·引擎侧普查: 54 可达态 × 41 命令 = 2214 对，响应+状态分层一致" {
  let witnesses = reachable_state_witness_paths()
  assert_eq(witnesses.length(), 54)
  let violations : Array[String] = [] // 干净领土分道（红线，必须空）
  let debt_sites : Array[String] = [] // 深机械领土分道点（R-17 债台账，数字钉死）
  let mut pairs = 0
  for entry in witnesses {
    let (_, path) = entry
    for command in all_commands() {
      pairs = pairs + 1
      // 每对独立复位：新 probe（=新引擎）+ 新模型
      let system = system_init()
      let mut model = model_empty()
      // 起跑：逐「响应+状态」步比对（正片全量/排除片只比状态）；分道按**当前步的
      // (状态,命令)** 归类——trail 族 = 债点（R-17 台账），干净领土 = 违例（红线）
      for step_command in path {
        let (next_model, expected_step) = model_execute(model, step_command)
        let actual_step = run_command(step_command, system)
        let state_ok = model_state_of_engine(system.probe.state()) ==
          Some(next_model.state)
        let step_diverged = if command_weight(command_name(step_command)) > 0 {
          actual_step != expected_step || !state_ok
        } else {
          !state_ok
        }
        if step_diverged {
          classify_divergence(model.state, step_command, violations, debt_sites)
        }
        model = next_model
      }
      let (next_model, expected) = model_execute(model, command)
      let actual = run_command(command, system)
      let state_ok = model_state_of_engine(system.probe.state()) ==
        Some(next_model.state)
      let own_diverged = if command_weight(command_name(command)) > 0 {
        actual != expected || !state_ok
      } else {
        !state_ok
      }
      if own_diverged {
        classify_divergence(model.state, command, violations, debt_sites)
      }
    }
  }
  debug(
    "引擎侧普查：\{pairs} 对（\{witnesses.length()} 可达态 × \{all_commands().length()} 命令）；债点 \{debt_sites.length()}（R-17 台账）；违例 \{violations.length()}",
  )
  for m in debt_sites {
    debug("  债点：\{m}")
  }
  for v in violations {
    debug("  违例：\{v}")
  }
  // 债钉（R-17 债台账规模）：首跑实测 14（役 7，2026-09-18）——分道步全在
  // trail/Path 深机械（prev_node 帧扩展位 territory，R-17）：值级发射/载荷改写
  // （倒装、壳交换、formula 入口等）不在模型值域内，只比状态时这些步仍对得上、
  // 比响应即分道。数字变化即红 ⇒ 同笔说明；R-17 清偿后此数应收窄（收紧即修账）。
  // 【14 → 11（R-18 同笔，2026-09-18）】：v2 真相修正 stale 行三分道——
  // SubjTrailAfterStepFormula+PrefName 回位公式族（SubjTrailVerbDone →
  // SubjTrailVerbDoneFormula）等；深切片新增对（Id/Invert × bnp 族、
  // BnpExpectIdNode 见证）**零分道**（响应+状态全同步）。11 点仍全在 trail 族。
  // 【11 → 6（笔 3a 同笔，2026-09-18）】：path 三账入模型（path_src/pend/tail/fwd
  // 四字段）+ 六操作写槽真值（path_step/subj_trail/obj_trail/hop_tail/subj_end/
  // obj_close，fwd: 排布来源 + 帧顶写）→ 主位/宾位尾随收口值级同步：
  // SubjTrailAfterStep+Iri/PrefName、ObjTrailAfterStep×3 清账。余 6 点 =
  // SubjTrailAfterStepFormula×2 + ListPathAfterStep×4：
  //   · Formula×2 = R-03-3 链形分派残差——见证路走**谓词位 trail**（Lbrace→
  //     set_predicate→Bang→path_subj_trail），引擎 path_src := ctx.subject =
  //     None（公式内主语空）⇒ path_subj_end 走 None 分支（path_subj_object
  //     回装 + state 拨回，Continue 不发射）；分支条件 path_src 空否是**值**，
  //     行响应/状态静态，静态表行表达不了（spec §5 同 R-03-3），留 3b+ 立项。
  //   · ListPath×4 = 元素位（Frame.prev_node 帧扩展位），笔 3b 立项。
  // 【6 → 2（笔 3b 同笔，2026-09-19）】：Frame 扩展位**数据化**（`frame_slots`）+
  // 帧顶写/读助手按字段发 + 元素位词表补全（`list_first`/`list_next`/`*_nested` 写
  // `frame.prev_node=arg0`；`path_elem_trail` 读 `frame.prev_node`；`path_elem_hop`
  // 按 `path_hop_resolve` 真值改 `path_src=fresh`；`path_elem_end` 读 path 账 + 写 prev_node）
  // ⇒ ListPathAfterStep×4 值级同步（实测两侧同为 `Emit(s=1 p=1 o=1 g=-)`）。
  // 余 2 点 = SubjTrailAfterStepFormula×2（R-03-3 链形分派残差：分支条件是**值**
  // （path_src 空否），静态表行表达不了——留 3b+/3c 立项，见上）。
  assert_eq(debt_sites.length(), 2)
  // 红线：干净领土零分道（引擎⟷模型契约在深机械领土之外必须成立）
  assert_eq(violations, [])
}

///|
/// 深机械领土分类（trail 族）：`*Trail*`/`*Path*` 态 = 路径/尾随机械（prev_node
/// 帧扩展位 territory，R-17）。类取**全族**（宽于首跑实测的 6 态——同族同根，
/// 记账说明）。族内分道 = 债；族外分道 = 违例。
fn trail_state(state : ModelState) -> Bool {
  let name = state_name(state)
  name.contains("Trail") || name.contains("Path")
}

///|
/// 分道归类：债点去重入台账，违例即入红线清单
fn classify_divergence(
  state : ModelState,
  command : Command,
  violations : Array[String],
  debt_sites : Array[String],
) -> Unit {
  let site = "\{state_name(state)}+\{command_name(command)}"
  if trail_state(state) {
    if !debt_sites.contains(site) {
      debt_sites.push(site)
    }
  } else {
    violations.push(site)
  }
}
