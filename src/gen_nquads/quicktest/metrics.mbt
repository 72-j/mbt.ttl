// ========================================
// Metrics — 指标口径样板（nquads quicktest）
//
// **本文件即"什么算够"的事实源**（样板口径，trig/n3v2 生成后照此对齐）：
//   ① 命令覆盖：全部**可达**命令名（转移表有出边）——`runner.coverage_gate_config`
//   ② 语义路径覆盖：响应分档 label（`resp:continue` / `resp:emit` /
//      `resp:emit:default` / `resp:emit:graph`）——同上 config 的 `required_labels`
//   ③ 转移覆盖：全部 (状态, 命令) 组合逐对判定——合法→目标态，非法→Error(0) 且模型不推进
//   ④ 收缩收敛：注入失败后**载荷收缩**生效（`shrinks > 0`）。
//      **已测边界**：本 FSM 的"删命令"收缩无效——命令序列受转移表强约束，
//      删掉任何中间命令都会让后续命令在前置条件上非法，`shrink_and_validate`
//      直接否决该候选（见"收缩机制"测试）。所以反例**长度不缩短**，只有载荷
//      （RefId 取值）被最小化；qcs 的候选集只有"删一条"+"用户 shrinker 替换"两类。
//   ⑤ 重映射恒等：收缩期允许删命令（`remap_command` 返回 None 会整体否决候选 ⇒ shrinks 必为 0）
//
// 口径纪律（与 runner 的两条门同规）：要求项只列**真能走到**的；走不到的（如
// `PrefName`/`EOF` 无转移、`resp:error` 只出现在未定义转移、`Done` 在 [[effects]]
// 声明但转移表零引用 ⇒ `resp:done`）必须显式标注为"不适用"，而不是悄悄从要求里删掉。
// ========================================

///|
/// 全部状态（源 [[states]]）
fn all_states() -> Array[ModelState] {
  [ExpectSubject, ExpectPredicate, ExpectObject, ExpectDotOrGraph, ExpectDot]
}

///|
/// 全部命令构造子（各带具体载荷；源 [[events]]）
fn all_commands() -> Array[Command] {
  [
    Iri(Concrete({ id: 1, })),
    BlankNode(Concrete({ id: 2, })),
    Literal(Concrete({ id: 3, })),
    PrefName(Concrete({ id: 4, })),
    TripleTerm(Concrete({ id: 5, })),
    Comma,
    Semicolon,
    Dot,
    Unknown,
    EOF,
  ]
}

///|
/// 命令名（与 `command_name` 同口径，表格判定用）
fn name_of(command : Command) -> String {
  command_name(command)
}

///|
/// 转移表**数据化镜像**（源 [[transitions]]）：合法 (状态, 命令) → 目标状态；None = 无转移。
/// 这是"纯模型执行器"的独立规格，`model_execute` 与它逐对对齐才算通过。
fn transition_expectation(state : ModelState, command : Command) -> ModelState? {
  match (state, command) {
    (ExpectSubject, Iri(_)) => Some(ExpectPredicate)
    (ExpectSubject, BlankNode(_)) => Some(ExpectPredicate)
    (ExpectPredicate, Iri(_)) => Some(ExpectObject)
    (ExpectObject, Iri(_)) => Some(ExpectDotOrGraph)
    (ExpectObject, BlankNode(_)) => Some(ExpectDotOrGraph)
    (ExpectObject, Literal(_)) => Some(ExpectDotOrGraph)
    (ExpectObject, TripleTerm(_)) => Some(ExpectDotOrGraph)
    (ExpectDotOrGraph, Iri(_)) => Some(ExpectDot)
    (ExpectDotOrGraph, BlankNode(_)) => Some(ExpectDot)
    (ExpectDotOrGraph, Dot) => Some(ExpectSubject)
    (ExpectDotOrGraph, Comma) => Some(ExpectObject)
    (ExpectDotOrGraph, Semicolon) => Some(ExpectPredicate)
    (ExpectDotOrGraph, Unknown) => Some(ExpectSubject)
    (ExpectDot, Dot) => Some(ExpectSubject)
    _ => None
  }
}

///|
/// 某状态下的**合槽模型**（镜像 `slots_consistent` 的槽位要求）：
/// 判定"发射路径"需要一个真实可达的起点，否则 legal 判定与槽位语义都会失真。
fn ready_model(state : ModelState) -> Model {
  let subject = { id: 1, }
  let predicate = { id: 2, }
  let object = { id: 3, }
  let graph = { id: 4, }
  match state {
    ExpectSubject => model_empty()
    ExpectPredicate => { ..model_empty(), state, subject: Some(subject), }
    ExpectObject =>
      {
        ..model_empty(),
        state,
        subject: Some(subject),
        predicate: Some(predicate),
      }
    ExpectDotOrGraph =>
      {
        ..model_empty(),
        state,
        subject: Some(subject),
        predicate: Some(predicate),
        object: Some(object),
      }
    ExpectDot =>
      {
        state,
        subject: Some(subject),
        predicate: Some(predicate),
        object: Some(object),
        graph: Some(graph),
        recovering: false,
      }
  }
}

///|
/// 全空槽白板模型（BFS 起点用）：合法性只由 `(状态, 命令)` 决定，与槽位无关。
fn blank_model(state : ModelState) -> Model {
  { ..model_empty(), state, }
}

///|
/// 沿路径推状态（只走表，不看槽位）：`reachable_witness_paths` 的定位用。
fn path_end_state(path : Array[Command]) -> ModelState {
  let mut state = ExpectSubject
  for command in path {
    let (next, _) = model_execute(blank_model(state), command)
    state = next.state
  }
  state
}

///|
/// **可达见证路径 = 覆盖率分母的唯一来源**：起点 = 初始态（`ExpectSubject`）；
/// 边 = `valid`（= `[[transitions]]` 派生）；下一态**跑模型**取；命令名归一 = `name_of`。
/// **纪律**：分母必须由本函数派生，**不许手抄**（trig P4.3 的教训；nquads 手抄表退役）。
/// 口径边界：本函数只走表，返回的路径尚未经引擎验证 —— 逐条起跑验证见 runner 的路径门。
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
        let name = name_of(command)
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
/// 可达命令名（分母）：由 `reachable_witness_paths()` 派生。
/// 旧口径是"任意状态有出边"——那会把引擎**到不了**的命令名算进分母（第二个口径来源），
/// 2026-09-19 按"分母同源"纪律退役。
fn reachable_command_names() -> Array[String] {
  reachable_witness_paths().map(fn(pair) { pair.0 })
}

///|
/// ③ 转移覆盖门：全部 (状态, 命令) 组合逐对判定——合法走目标态、非法 Error(0) 且不推进。
/// 任何一条转移臂写错（目标态、合法性、兜底）都会在这里红。
test "指标·转移覆盖: 全 (状态,命令) 对逐对判定" {
  let mut legal = 0
  let mut illegal = 0
  for state in all_states() {
    for command in all_commands() {
      let model = ready_model(state)
      let (next, response) = model_execute(model, command)
      match transition_expectation(state, command) {
        Some(expected) => {
          legal = legal + 1
          assert_true(valid(model, command)) // valid 表与转移表同源
          assert_true(response != Error(0)) // 合法转移不是未定义错误
          assert_eq(next.state, expected) // 目标态正确
          assert_true(slots_consistent(next)) // 推进后仍合槽（不变量）
        }
        None => {
          illegal = illegal + 1
          assert_false(valid(model, command)) // 无转移 ⇒ 非法
          assert_eq(response, Error(0)) // 未定义转移归一到错误码 0
          assert_eq(next, recovery_enter(model)) // 非法命令不进表，但开窗清账（R-19）
        }
      }
    }
  }
  // 组合数守恒：5 状态 × 10 命令 = 50，合法 14 / 非法 36（改表即变，写死防漏）
  assert_eq(legal, 14)
  assert_eq(illegal, 36)
}

///|
/// ② 语义路径覆盖：label 面必须覆盖配置里要求的四个分档
test "指标·语义路径覆盖: label 分档齐全" {
  match run_coverage_check() {
    Ok(report) => {
      let seen = @qcs.collect_labels(report.labels)
      for required in coverage_gate_config().required_labels {
        assert_true(seen.contains(required))
      }
      // 未定义转移路径（resp:error）不走随机生成 —— 显式记为"不适用"
      assert_false(seen.contains("resp:error"))
      // Done 在 [[effects]] 声明（semantics = "stop"）但转移表零引用（5 条 effect
      // 全是 EmitQuad）⇒ resp:done 同为不可达分档 —— 对称地钉成"不适用"
      assert_false(seen.contains("resp:done"))
    }
    Err(failure) =>
      fail("label coverage failed: \{@qcs.format_failure(failure)}")
  }
}

///|
/// ① generator 门：多种子下"可达命令全覆盖"+"产出恒合法"。
/// 权重只影响概率，可达性必须靠 valid + 候选全集保证——这条是它的验收面。
test "指标·generator: 可达命令全覆盖 + 产出恒合法" {
  let reachable = reachable_command_names()
  let produced : Array[String] = []
  for seed in [1UL, 7UL, 99UL, 12345UL, 2026UL] {
    let rng = @splitmix.new(seed~)
    let mut model = model_empty()
    let mut steps = 0
    while steps < 200 {
      match generate_command(model, 20, rng) {
        Some(command) => {
          assert_true(valid(model, command)) // 产出恒合法（valid 过滤生效）
          let name = name_of(command)
          if !produced.contains(name) {
            produced.push(name)
          }
          let (_, response) = model_execute(model, command)
          model = transition(model, command, response)
        }
        None => break
      }
      steps = steps + 1
    }
  }
  for name in reachable {
    assert_true(produced.contains(name)) // 可达集合 ⊆ 实际产出集合
  }
  // 不可达命令不得出现（无转移 ⇒ valid 恒假 ⇒ 生成器永不产出）
  assert_false(produced.contains("PrefName"))
  assert_false(produced.contains("EOF"))
}

///|
/// ① 姊妹门·无死锁：generate_command 返回 None ⇒ qcs 判 Deadlock。本 FSM 转移表
/// 保证每个状态都有合法出边，None 不可达——generator 门测试的循环遇 None 会
/// 静默提前 break，钉不住这个事实，这里按状态逐一钉死。
test "指标·generator: 无死锁（五状态恒有合法候选）" {
  for index, state in all_states() {
    let model = ready_model(state)
    let rng = @splitmix.new(seed=42UL)
    match generate_command(model, 20, rng) {
      Some(command) => assert_true(valid(model, command)) // 候选恒合法
      None =>
        fail(
          "状态#\{index} 无合法候选（Deadlock 可达，转移表被破坏）",
        )
    }
  }
}

///|
/// ① generator 权重口径：声明的取配置值，未声明的取默认 1
test "指标·generator: 权重口径" {
  assert_eq(command_weight("Iri"), 3)
  assert_eq(command_weight("BlankNode"), 2)
  assert_eq(command_weight("Literal"), 2)
  assert_eq(command_weight("Dot"), 3)
  assert_eq(command_weight("Comma"), 1) // 未声明 → 默认 1（不是 0 = 禁用）
  assert_eq(command_weight("不存在"), 1)
}

///|
/// ④ 收缩收敛门：注入"系统丢图名"，要求机器**真的收缩**并给出短反例。
/// 这条同时是 ⑤ 的集成证据：`shrink_and_validate` 对每一步都调 `remap_command`，
/// 一旦它返回 None，整个候选被否决 ⇒ 收缩一次也做不成（shrinks 恒 0）。
test "指标·shrinker: 注入失败被最小化（shrinks > 0 且反例短）" {
  let graph_dropping = fn(command : Command, system : System) -> Response {
    match run_command(command, system) {
      EmitQuad(quad) => EmitQuad({ ..quad, graph: None, })
      other => other
    }
  }
  let config : @qcs.RunConfig = {
    ..quick_run_config(),
    cases: 1,
    max_commands: 40,
    shrink: true,
  }
  match @qcs.check(quick_state_machine(system_call=graph_dropping), config~) {
    Ok(_) => fail("注入的漂移必须被检出")
    Err(failure) =>
      match failure {
        @qcs.PostconditionFailed(shrinks~, commands~, ..) => {
          assert_true(shrinks > 0) // 收缩真的发生（依赖 shrinker + remap）
          // 反例非空且不超过生成上限；**长度不缩短**是本 FSM 的已知边界（见文件头 ④）
          assert_true(commands.commands.length() > 0)
          assert_true(commands.commands.length() <= config.max_commands)
        }
        _ =>
          fail("期望 PostconditionFailed（模型与系统响应不一致）")
      }
  }
}

///|
/// ④/⑤ 收缩机制直测（机器原因）：
/// (a) 合法程序可被 `shrink_and_validate` 重建 → Some（remap + precondition + mock 协同）；
/// (b) 删掉一条中间命令的损坏程序被否决 → None（这就是"删命令收缩无效"的根因）。
test "指标·收缩机制: 重建校验接受合法程序、否决损坏程序" {
  let spec = quick_state_machine()
  let program = script_program(assert_script_scopes())
  assert_true(@qcs.shrink_and_validate(spec, program) is Some(_))
  // 删掉索引 3（Comma）：此后 Semicolon 在 ExpectDot 下非法 → 前置条件否决
  let damaged_entries : Array[@qcs.Command[Command, Response]] = []
  for index, entry in program.commands {
    if index != 3 {
      damaged_entries.push(entry)
    }
  }
  let damaged : @qcs.Commands[Command, Response] = {
    commands: damaged_entries,
  }
  assert_true(@qcs.shrink_and_validate(spec, damaged) is None)
}

///|
/// ⑤ remap 门（单位面）：恒等保留——含非空 scope 映射也不丢命令。
test "指标·remap: 恒等保留（含非空 scope）" {
  let empty : Map[@qcs.Var, @qcs.Var] = Map([])
  let mapped : Map[@qcs.Var, @qcs.Var] = Map([
    (@qcs.Var::{ id: 0, }, @qcs.Var::{ id: 1, }),
  ])
  for command in all_commands() {
    assert_eq(remap_command(command, empty), Some(command))
    assert_eq(remap_command(command, mapped), Some(command))
  }
}
