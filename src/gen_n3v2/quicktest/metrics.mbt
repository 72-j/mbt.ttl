// ========================================
// Metrics — 枚举件 + 全臂冒烟门（**手维护层**；对齐 trig quicktest 的 metrics.mbt 角色）
// ========================================
// 定位（src/ttl/todo.md §C 役 14 的第一步可跑件）：先给「全状态 / 全命令」枚举与全臂冒烟，
// 覆盖率门（路径驱动）/结构钉子/引擎侧普查按 trig P4.3 形态在其上继续搭。
// 纪律：枚举是**手工维护**的数据面——IR（n3_fsm.toml）变了这里必须同笔改，数字门会替你把关。

///|
/// 全部状态（源 [[states]]，53 个）
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
    BnpExpectObject,
    BnpAfterObject,
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
/// 全部命令（源 weights 表 39 个事件；`@qcs.Ref` 统一取 `Concrete(id = 1)`）
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
    EOF,
  ]
}

///|
/// 空槽模型（只定状态）：普查 / 冒烟的统一起点
fn blank_model(state : ModelState) -> Model {
  { ..model_empty(), state, }
}

///|
/// **全臂冒烟门**：53 状态 × 39 命令，每对都跑一次 `model_execute`。
/// 判据两条：
///   ① 对数守恒（53 × 39 = 2067）——防枚举漏项；
///   ② 合法对 = **376**（= `valid.mbt` 真行数 = 在库臂数）——结构钉子：臂表漂了这里就红。
/// 本门只证"每条臂都能执行一次"（覆盖率用途），**不**替代随机门/锚点门的语义对拍。
test "n3v2 全臂冒烟：53×39 全对 + 合法对 376（臂表结构钉）" {
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
  assert_eq(pairs, 53 * 39)
  assert_eq(legal, 376)
}

///|
/// **权重表钉子**：39 名逐条等值 + 表外名回落 1。
/// 权重决定随机门的分布（属判据面）⇒ 改表即红，必须与
/// `src/quick_machine/quick_machine_n3.toml` 的 `[business.weights]` 同笔说明。
test "n3v2 权重表逐名等值（39 名全量 + 默认档）" {
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
  assert_eq(expected.length(), 39)
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
    BnpExpectObject => "BnpExpectObject"
    BnpAfterObject => "BnpAfterObject"
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
    let state = path_end_state(path)
    for command in all_commands() {
      if valid(blank_model(state), command) {
        let (next_model, _) = model_execute(blank_model(state), command)
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
  assert_eq(states.length(), 52)
  assert_eq(witnesses.length(), 38)
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
