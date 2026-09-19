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
    ("Is", 1), // 【0 → 1（排除片转正，2026-09-19）】：IsProp 词行 = 既有 set_predicate 面（fsm_out 同源在册），零新增机械
    ("Of", 1), // 【0 → 1（排除片转正，2026-09-19）】：is_of 晋声明 action + 发射族倒装交换/结算（引擎 take_pending/settle_inversion 同形）
    ("Dot", 3),
    ("EOF", 0),
    ("Has", 1), // 【0 → 1（排除片转正，2026-09-19）】：六行原地 no-op（同态 Continue 无 action，现代口径 has 直读不倒装）；Is=0 下 ExpectIsProp 族不可达 ⇒ 零机械
    ("Iri", 3),
    ("Anon", 1), // 【0 → 1（Batch 2，2026-09-19）】：`[]` 合成单事件纯槽位写（lexer_adapter:359-375）
    // 【0 → 1（排除片转正 Batch 1 前半，2026-09-19）】：路径族**正向**放开——§V.4 两应舞；
    // 尾随跳发射旗 `nfwd:` 词表坍缩（path_hop_tail/path_verb_hop，引擎 :580/:791 参数旗）。
    // Caret/ImpliedBy 仍 0 = R-19（fwd 墙后 skip-to-Dot 恢复道模型无恢复位，双收缩反例实证）。
    ("Bang", 1),
    ("Caret", 0),
    ("Comma", 1),
    ("Tilde", 1),
    ("BaseKw", 1),
    ("Equals", 1),
    // 【0 → 1（笔 3c 下半·三，2026-09-19）】：公式族放开——as_pred 弹帧回写开通后
    // 谓位反例两侧同步（锚点⑤⑥值级钉死），随机门组合路径实测通过（Lbrace=2/Rbrace=2）。
    ("Lbrace", 1),
    ("Lparen", 1), // 【0 → 1（Batch 3，2026-09-19）】：集合族放开——path_elem_hop 四疑点反例定夺
    ("Rbrace", 1),
    ("Rparen", 1), // Batch 3 同笔：list_nil/path_elem_close 收口
    ("Implies", 1), // Batch 1 前半同笔（见 Bang 行注）
    ("Literal", 3),
    ("Unknown", 0),
    // R-18 后 Id/Invert 行落地 ⇒ 排除理由改为 R-17 值级缺口，仍显式 0（未列默认 1 陷阱）
    ("Id", 0),
    ("Invert", 0),
    ("AnnotEnd", 0),
    ("ForAllKw", 0),
    ("KeywordA", 1), // Batch 2：pk=引擎侧非模型槽 span 轴不可见（= SameAs 先例）；降级道需 @keywords（0 死）
    ("KeywordX", 0),
    // 【0 → 1（笔 3c 下半·四，2026-09-19）】：Bnp 族放开——as_pred 弹帧回写开通后
    // 谓位反例两侧同步双发（内 (59,4,5) + 外 (3,59,58)，锚点⑥值级钉死），组合面
    // 九案探针全绿（宾/主/嵌套/罩内谓位/逗号/bnp⊃formula/formula⊃formula/谓位公式⊃bnp）。
    ("Lbracket", 1),
    ("PrefName", 2),
    ("PrefixKw", 1),
    ("Rbracket", 1),
    ("Variable", 1), // Batch 2：`?x` 整词单 token 槽位装词 id
    ("BlankNode", 2),
    ("ForSomeKw", 0),
    ("ImpliedBy", 0), // R-19 恢复道（见 Bang 行注）
    ("Semicolon", 1),
    ("VersionKw", 0),
    ("AnnotStart", 0),
    ("KeywordsKw", 0),
    ("TripleTerm", 1), // Batch 2：`<< s p o >>` 整词单 token（lexer_mbt:315-345 平衡配对，gate_tt 验证层深验）——无内层事件道
    ("BracketTripleTerm", 1), // Batch 2：`<<( )>>` 括号壳整词（lexer_mbt:278-313）同上
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
/// **P5.6 可达覆盖账（分子必须来自执行记录）**：
///   分母 = `reachable_witness_paths()` 派生（起点初始态、边 = `valid`，不可达项不进分母）；
///   分子 = 各条见证路径**实际执行**后 `RunReport.command_distribution` 的并集
///          （**不是**路径声明覆盖了谁 —— 声明与执行脱钩就是假绿）；
///   缺口 = 分母 − 分子（逐名列出，清空即门绿）。
/// 逐条独立起跑（qcs 覆盖判定是逐用例的）；漂移（模型 ≠ 引擎）由 `assert_check` 直接抛。
/// 沿革：本函数取代旧 `run_path_coverage_gate()`（原只返回失败名、丢弃 `command_distribution`）。
fn reachable_coverage_account() -> (Array[String], Array[String], Array[String]) raise {
  let witnesses = reachable_witness_paths()
  let denominator = witnesses.map(fn(pair) { pair.0 })
  let covered : Array[String] = []
  for pair in witnesses {
    let (name, path) = pair
    let report = @qcs.assert_check(
      quick_state_machine(script=Some(path)),
      config=path_coverage_config(path, name),
    )
    for entry in report.command_distribution {
      let (seen, _) = entry
      if !covered.contains(seen) {
        covered.push(seen)
      }
    }
  }
  let missing = denominator.filter(fn(name) { !covered.contains(name) })
  (denominator, covered, missing)
}

///|
/// 可达覆盖账的**不可达项**（不进分母，另由结构钉子钉住）：全部命令名 − 分母。
fn unreachable_command_names() -> Array[String] {
  let denominator = reachable_witness_paths().map(fn(pair) { pair.0 })
  all_commands()
  .map(fn(command) { command_name(command) })
  .filter(fn(name) { !denominator.contains(name) })
}

///|
/// P5.6 可达覆盖门（开启）：40 条见证路径各自一个用例、独立起跑、干净复位；
/// 缺口非空即红并打印**具体缺口名**；分母守恒断言防"把可达项挪出分母"。
test "n3v2 P5.6 可达覆盖门（路径驱动·缺口清零）" {
  let (denominator, covered, missing) = reachable_coverage_account()
  let unreachable_names = unreachable_command_names()
  debug(
    "可达覆盖账 n3v2：分母 \{denominator.length()} / 分子 \{covered.length()} / 缺口 \{missing.length()} / 不可达 \{unreachable_names.length()}",
  )
  if missing.length() > 0 {
    debug("缺口清单：\{missing.join(",")}")
  }
  debug(
    "不可达（不进分母，结构钉子钉住）：\{unreachable_names.join(",")}",
  )
  assert_true(denominator.length() > 0)
  assert_eq(missing, [])
  assert_eq(
    denominator.length() + unreachable_names.length(),
    all_commands().length(),
  )
}

///|
/// **覆盖率门·范围断言**（笔 4，2026-09-19）：门只跑"表上有出边"的命令名——
/// 本断言把"**门没覆盖谁、为什么**"钉死，防两类事：
///   ① 名单悄悄少一名（见证 BFS 漏路）⇒ 这里先红（`witnessed` 与 `anywhere` 数不等）；
///   ② 差额里混进"其实可达"的名字 ⇒ 逐名在册断言失败。
/// 口径同源：两边都由 `valid`（= `[[transitions]]` 派生）算，不手抄。
test "n3v2 覆盖率门范围: 见证名单 = 表上有出边的命令名（差额逐名在册）" {
  let witnessed = reachable_witness_paths().map(fn(pair) { pair.0 })
  let anywhere : Array[String] = []
  for command in all_commands() {
    let name = command_name(command)
    if transition_expectation_is_anywhere(name) {
      anywhere.push(name)
    }
  }
  // ① 数量守恒：见证账必须把"表上有出边"的名字全找到
  assert_eq(witnessed.length(), anywhere.length())
  // ② 差额逐名在册（当前：EOF 表上无出边 ⇒ 合法不覆盖；将来变了这里先红）
  let uncovered : Array[String] = []
  for command in all_commands() {
    let name = command_name(command)
    if !witnessed.contains(name) {
      uncovered.push(name)
    }
  }
  assert_eq(uncovered, ["EOF"])
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
/// **值级槽位视图**（役 ③b）：引擎 `N3SlotSnapshot` 与模型 `Model` 的**同形投影**——
/// 字段面 = 生成面 `[type_mapping]` 的 `model_slots` + `fwd_slot`（模型有的槽这里就有，
/// 一位不多一位不少）。归一化同 `Model`：`Span` → `RefId`（取 start；与 `quad_from_pending`
/// 的 `ref_id_of` 同一把尺子）。两侧同形即可整块 `==` 比对。
priv struct SlotView {
  subject : RefId?
  predicate : RefId?
  object : RefId?
  graph : RefId?
  path_src : RefId?
  path_pend : RefId?
  path_tail : RefId?
  path_fwd : Bool
} derive(Eq)

///|
fn slot_view_of_model(model : Model) -> SlotView {
  {
    subject: model.subject,
    predicate: model.predicate,
    object: model.object,
    graph: model.graph,
    path_src: model.path_src,
    path_pend: model.path_pend,
    path_tail: model.path_tail,
    path_fwd: model.path_fwd,
  }
}

///|
fn slot_view_of_engine(snapshot : @n3.N3SlotSnapshot) -> SlotView {
  {
    subject: snapshot.subject.map(ref_id_of),
    predicate: snapshot.predicate.map(ref_id_of),
    object: snapshot.object.map(ref_id_of),
    graph: snapshot.graph.map(ref_id_of),
    path_src: snapshot.path_src.map(ref_id_of),
    path_pend: snapshot.path_pend.map(ref_id_of),
    path_tail: snapshot.path_tail.map(ref_id_of),
    path_fwd: snapshot.path_fwd,
  }
}

///|
/// 引用值文本（判据消息用）：`None` / `Some(6)`——`RefId` 只 `derive(Debug)`
/// （仓库口径：调试面用 Debug，不给业务类型加 Show），故门消息自备一把小尺子。
fn ref_id_text(value : RefId?) -> String {
  match value {
    None => "None"
    Some(id) => "Some(\{id.id})"
  }
}

///|
/// 槽位差异（空串 = 一致）：**逐槽点名**（值级门的判据本体；负控可直接喂合成视图）。
/// 值级对拍要的正是这个粒度——"哪一槽、期望什么、实得什么"，而不是"两坨不等"。
fn slot_view_diff(expected : SlotView, actual : SlotView) -> String {
  let diffs : Array[String] = []
  if expected.subject != actual.subject {
    diffs.push(
      "subject 期望 \{ref_id_text(expected.subject)} 实得 \{ref_id_text(actual.subject)}",
    )
  }
  if expected.predicate != actual.predicate {
    diffs.push(
      "predicate 期望 \{ref_id_text(expected.predicate)} 实得 \{ref_id_text(actual.predicate)}",
    )
  }
  if expected.object != actual.object {
    diffs.push(
      "object 期望 \{ref_id_text(expected.object)} 实得 \{ref_id_text(actual.object)}",
    )
  }
  if expected.graph != actual.graph {
    diffs.push(
      "graph 期望 \{ref_id_text(expected.graph)} 实得 \{ref_id_text(actual.graph)}",
    )
  }
  if expected.path_src != actual.path_src {
    diffs.push(
      "path_src 期望 \{ref_id_text(expected.path_src)} 实得 \{ref_id_text(actual.path_src)}",
    )
  }
  if expected.path_pend != actual.path_pend {
    diffs.push(
      "path_pend 期望 \{ref_id_text(expected.path_pend)} 实得 \{ref_id_text(actual.path_pend)}",
    )
  }
  if expected.path_tail != actual.path_tail {
    diffs.push(
      "path_tail 期望 \{ref_id_text(expected.path_tail)} 实得 \{ref_id_text(actual.path_tail)}",
    )
  }
  if expected.path_fwd != actual.path_fwd {
    diffs.push(
      "path_fwd 期望 \{bool_text(expected.path_fwd)} 实得 \{bool_text(actual.path_fwd)}",
    )
  }
  diffs.join("；")
}

///|
/// 布尔文本（判据消息用；同 `ref_id_text` 的理由）。
fn bool_text(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
/// 值级根因入账（**每探针首处**；去重后逐条在册）。
fn record_slot_root(
  origin : String,
  state : ModelState,
  command : Command,
  diff : String,
  roots : Array[String],
) -> Unit {
  let site = "\{origin} \{state_name(state)}+\{command_name(command)}：\{diff}"
  if !roots.contains(site) {
    roots.push(site)
  }
}

///|
/// 集合漂移（**不排序**：`sort_by` 在本版语义不可靠，见 `codegen_test.mbt` ctx 风险④）——
/// 长度 + 双向 contains；两向都点名：新增 = 新缺口，消失 = 已清偿（请同笔收紧台账）。
fn site_set_drift(
  actual : Array[String],
  pinned : Array[String],
) -> Array[String] {
  let drift : Array[String] = []
  for site in actual {
    if !pinned.contains(site) {
      drift.push("值级新增分道（未在册）：\{site}")
    }
  }
  for site in pinned {
    if !actual.contains(site) {
      drift.push(
        "值级台账条目已消失（清偿或改判 ⇒ 同笔收紧台账）：\{site}",
      )
    }
  }
  if actual.length() != pinned.length() {
    drift.push(
      "值级台账条数 \{actual.length()} ≠ 在册 \{pinned.length()}（集合逐名比对，重复项也算漂移）",
    )
  }
  drift
}

///|
/// **值级根因台账**（R-20 开账，2026-09-19）：首跑实测 **27 处**（全站点 355 → 根因 27）；**A+B+C+F+D+E 六族全清偿，台账归零**（A 笔消失 11 = A 全族；C 笔消失 18 = C 全族含孪生 8；B 笔消失 4 = B 全族、同笔浮出 26 = 新族 F；F+D+E 合笔消失 30 = F 26 + D 1 + E 3，**新增 0**——开括号站首版外层折写被普查红牌（帧内 s/p 被盖回装槽值），改写后快照无折写形后归零）。
/// 逐条在册 + 棘轮（`const.md` §5.2）：修好一处不改账 ⇒ 红；新冒一处 ⇒ 红。
/// 五族归类（根因与清偿路径见 `src/ttl/todo.md` §AF）：
///   A **公式族压帧的"当前 subject"**（11，**已清偿** 2026-09-19：frame_push 体按 is_formula 位分派 + open_slot 行吃 IR SlotType::Formula 旗；trig/nquads 字节零迁移）——生成器 `frame_push` 硬编码
///     `subject := Some(open_span)`（那是 BnodeProp/Collection 口径），引擎 `open_formula`
///     是 `subject := None`；
///   B **路径入口旗标**（2，**已清偿** 2026-09-19：生成器有值支同吃行 assign——行
///     assign 是引擎 match 之前的无条件置写【actions.mbt:408/:434】，absent 支原已
///     落、present 支补齐；trig/nquads 无 when_some，构造性死路）——原 `when_some`
///     支丢旗；
///   C **`path_subj_end` 的 when_absent 支写未物化**（10）——TOML 有数据
///     （subject=ctx.path_tail / predicate=ctx.path_pend / object=arg0 / 清 tail·pend），
///     生成臂只落了响应与状态；
///   D **`path_elem_close` 清 path 三账**（1，**已清偿** 2026-09-19：TOML 转写
///     s/p/o fwd 排布 + 清三账 + `frame.prev_node=ctx.path_tail`【引擎 :893-928
///     直证；node_seq+1 模型 Frame 无此位，普查八槽不可见不建模】）——引擎 `clear_path()`，表零写；
///   E **ObjTrail 收口三行**（3，**已清偿** 2026-09-19：生成器**末枚 EmitQuad 后**
///     按行 to-state 派 scoped 清槽步【引擎 :967-971 同源镜像：`,` 清 object /
///     `;` 清 p+o / `.` 全清；仅末枚，中间枚 = 列表双发桥接位无独立 reset】）——
///     引擎 `path_obj_close` 的 `clear_path()` + 二次发射 scope 清槽，模型缺；
///   F **PathAfterStep 写槽面**（26，**已清偿** 2026-09-19：`path_end`/`path_hop_fwd·bwd`
///     族 C 同款 TOML 转写【引擎 :482-507/:459-475 直证】+ `path_end_nested` 补
///     `push_writes` 旗 + 生成器**单意图 OpenSlot 触 s/p ⇒ 写后快照形无外层折写**
///     【引擎 :544-548 先装槽后推帧，帧快照携重排 s/p；与 trail 族压帧序反，
///     frame_push 体分派即引擎忠形】）——原 `[actions]` 对 `path_end`/
///     `path_end_nested`/`path_hop_fwd`/`path_hop_bwd` 裸声明零写槽；
///     反跳拒 = R-03-2 负例道不建模。
fn pinned_slot_roots() -> Array[String] {
  // A+B+C+F+D+E 六族全清偿（2026-09-19 F+D+E 合笔，30→0）——空表 = 棘轮全量哨：
  // 任何新冒值级分道即红，请按 const.md §5.2 同笔入册。
  []
}

///|
/// **值级门负控（判据本体）**：合成视图改一槽 ⇒ `slot_view_diff` 必须**点名该槽**
/// （值级门的红字要能直接指出"哪一槽、期望什么、实得什么"）；等价视图 ⇒ 空串。
/// 变异两处：一枚引用槽（`path_pend`）+ 一枚布尔槽（`path_fwd`）——两把尺都要咬。
test "值级门负控：槽位差异逐槽点名（判据本体）" {
  let base : SlotView = {
    subject: Some({ id: 1, }),
    predicate: Some({ id: 2, }),
    object: Some({ id: 3, }),
    graph: None,
    path_src: None,
    path_pend: None,
    path_tail: None,
    path_fwd: false,
  }
  // 正控：等价视图 ⇒ 无差异
  assert_eq(slot_view_diff(base, base), "")
  // ① 引用槽变异（`None` → `Some(9)`）
  let pend_changed : SlotView = { ..base, path_pend: Some({ id: 9, }), }
  let diff1 = slot_view_diff(base, pend_changed)
  assert_true(diff1.contains("path_pend"))
  assert_true(diff1.contains("Some(9)"))
  assert_false(diff1.contains("subject"))
  // ② 布尔槽变异（方向旗标反了）
  let fwd_flipped : SlotView = { ..base, path_fwd: true, }
  let diff2 = slot_view_diff(base, fwd_flipped)
  assert_true(diff2.contains("path_fwd"))
  assert_true(diff2.contains("true"))
  // ③ 多槽同时变 ⇒ 全部点名（值级门不做"首个差异就返回"的省事写法）
  let both : SlotView = { ..pend_changed, graph: Some({ id: 4, }), }
  let diff3 = slot_view_diff(base, both)
  assert_true(diff3.contains("path_pend"))
  assert_true(diff3.contains("graph"))
  // ④ 台账集合判据：新增 / 消失 / 条数漂移，三向都要红
  assert_eq(site_set_drift(["a", "b"], ["a", "b"]), [])
  assert_true(site_set_drift(["a", "b", "c"], ["a", "b"]).length() > 0)
  assert_true(site_set_drift(["a"], ["a", "b"]).length() > 0)
  assert_true(site_set_drift(["a", "a"], ["a"]).length() > 0)
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
///
/// **值级轴（役 ③b，2026-09-19 加）**：在「响应+状态」之外，逐对比对**槽位快照**
/// （引擎 `N3Probe::slots()` ⟷ 模型 `model_slots` + `fwd_slot` 八位，见 `SlotView`）。
/// 缘起：三表 `writes` 的值级条目（`object=arg0` / `path_pend=none` /
/// `subject=fwd:ctx.path_src|ctx.path_tail` …）此前只能靠人从 `actions.mbt` 抄——静态
/// 解析必成纸（48 个 action 里 29 个含难解析写），故开引擎侧只读面 + 本轴对拍。
/// 记账口径：**每探针（见证路径 + 一条命令）只记首处分道**（根因）；级联由根因清偿后
/// 自动消失，台账才稳定可维护（首跑：全站点 355 → 根因 **27**，逐条在册见
/// `pinned_slot_roots()`）。首跑即暴露五族真缺口——A 公式族压帧当前 subject /
/// B 路径入口旗标 / C `path_subj_end` 的 when_absent 写未物化 / D `path_elem_close`
/// 清账 / E ObjTrail 收口三行；**这些在「响应+状态」轴上全部不可见**（载荷被罩压制或
/// 弹帧丢弃）⇒ 值级轴不是重复门。清偿节奏：逐族一笔，修一处露一处
/// （实测：修族 A 后族 C 的**公式孪生**浮出 8 处）。
test "指标·引擎侧普查: 54 可达态 × 41 命令 = 2214 对，响应+状态+槽位分层一致" {
  let witnesses = reachable_state_witness_paths()
  assert_eq(witnesses.length(), 54)
  let violations : Array[String] = [] // 干净领土分道（红线，必须空）
  let debt_sites : Array[String] = [] // 深机械领土分道点（R-17 债台账，数字钉死）
  let slot_roots : Array[String] = [] // 值级（槽位快照）根因：每探针**首处**分道（R-20 台账）
  let mut pairs = 0
  for entry in witnesses {
    let (_, path) = entry
    for command in all_commands() {
      pairs = pairs + 1
      // 每对独立复位：新 probe（=新引擎）+ 新模型
      let system = system_init()
      let mut model = model_empty()
      let mut slot_root_found = false // 本探针已记根因 ⇒ 后续分道是级联，不重复记账
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
        // 值级（役 ③b）：本次 step 之后**逐槽**比对引擎真槽位（N3Probe::slots()）
        // ⟷ 模型槽位。三表 `writes` 值级条目（`object=arg0` / `path_pend=none` /
        // `subject=fwd:ctx.path_src|ctx.path_tail` …）到这一层才有独立读数面。
        // 记账口径：**每探针只记首处分道**（根因）——级联由根因清偿后自动消失，
        // 台账才稳定可维护（首跑实测：全站点 355 → 根因 27）。
        if !slot_root_found {
          let expected_slots = slot_view_of_model(next_model)
          let actual_slots = slot_view_of_engine(system.probe.slots())
          if expected_slots != actual_slots {
            record_slot_root(
              "路径",
              model.state,
              step_command,
              slot_view_diff(expected_slots, actual_slots),
              slot_roots,
            )
            slot_root_found = true
          }
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
      if !slot_root_found {
        let own_slots_expected = slot_view_of_model(next_model)
        let own_slots_actual = slot_view_of_engine(system.probe.slots())
        if own_slots_expected != own_slots_actual {
          record_slot_root(
            "命令",
            model.state,
            command,
            slot_view_diff(own_slots_expected, own_slots_actual),
            slot_roots,
          )
        }
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
  debug(
    "值级槽位根因：\{slot_roots.length()} 处（每探针首处；R-20 台账）",
  )
  for root in slot_roots {
    debug("  值级根因：\{root}")
  }
  // 值级台账：逐条在册 + 棘轮（修好一处不修账 ⇒ 红；新增一处 ⇒ 红）
  assert_eq(site_set_drift(slot_roots, pinned_slot_roots()), [])
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
  // 【2 → 0（笔 3c 下半·二同笔，2026-09-19）】：罩内发射压制开通（`suppress_emit =
  // { frame_flag = "is_formula" }` + 压帧即定旗）——Formula 值分支 Some(_) 臂的
  // `emit_spo` 在罩内被降级为只收拾不上抛（Continue），与引擎 `under_formula()`
  // 判定同刻同口径 ⇒ SubjTrailAfterStepFormula×2 值级同步，债台账**清零**。
  assert_eq(debt_sites.length(), 0)
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
