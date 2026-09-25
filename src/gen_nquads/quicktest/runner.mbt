// ========================================
// Runner — 运行器（目标形状 = 生成器产物 runner.mbt）
// 固定脚本回归（replay）+ 随机属性测试（check），配置源 [random_check]
// ========================================

///|
/// 运行配置（源 [random_check]）
fn quick_run_config() -> @qcs.RunConfig {
  {
    seed: 12345UL,
    cases: 100,
    max_commands: 20,
    size: 20,
    max_tries: 20,
    shrink: true,
    max_shrinks: 100,
    max_shrink_rounds: 20,
    required_labels: [],
    required_command_names: [],
  }
}

///|
/// 固定脚本（源 [[assert_check]]）：无图三元组 + 带图名四元组 + 未定义事件收尾
/// 覆盖两条发射路径（All / 带图）与错误归一化路径
fn assert_script() -> Array[Command] {
  [
    Iri(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Literal(Concrete({ id: 3, })),
    Dot,
    Iri(Concrete({ id: 4, })),
    Iri(Concrete({ id: 5, })),
    Literal(Concrete({ id: 6, })),
    Iri(Concrete({ id: 7, })),
    Dot,
    EOF,
  ]
}

///|
/// 三档重置脚本（P5 补充）：一次跑出 `ResetScope::Object`（Comma）/`PredObj`
/// （Semicolon）/`All`（Dot）三条清槽分支 + 带图发射。
/// 引擎与模型必须逐步同响应；清槽语义漂移（清错槽/不清槽）会被 postcondition 抓住。
fn assert_script_scopes() -> Array[Command] {
  [
    Iri(Concrete({ id: 1, })), // subject
    Iri(Concrete({ id: 2, })), // predicate
    Literal(Concrete({ id: 3, })), // object
    Comma, // emit(1,2,3) + ResetScope::Object
    Iri(Concrete({ id: 4, })), // object
    Semicolon, // emit(1,2,4) + ResetScope::PredObj
    Iri(Concrete({ id: 5, })), // predicate
    Iri(Concrete({ id: 6, })), // object
    Dot, // emit(1,5,6) + ResetScope::All
    Iri(Concrete({ id: 7, })),
    Iri(Concrete({ id: 8, })),
    Iri(Concrete({ id: 9, })),
    Iri(Concrete({ id: 10, })),
    Dot, // 带图名发射：(7,8,9,10)
  ]
}

///|
/// 脚本 → 符号程序：逐条 mock 预测响应并推进符号模型（replay 的程序形态）
fn script_program(script : Array[Command]) -> @qcs.Commands[Command, Response] {
  let entries : Array[@qcs.Command[Command, Response]] = []
  let mut model = model_empty()
  let mut gen_sym = @qcs.GenSym::new()
  for command in script {
    let (response, next_gen_sym) = mock_command(model, command, gen_sym)
    gen_sym = next_gen_sym
    entries.push(@qcs.Command::{ command, response, vars: [], })
    model = transition(model, command, response)
  }
  @qcs.Commands::{ commands: entries, }
}

///|
/// 固定脚本检查: 失败即抛出（回归基准；覆盖关键路径）
fn run_assert_check() -> @qcs.RunReport[Command, Response, Command, Response] raise {
  run_assert_check_for(assert_script())
}

///|
/// 指定脚本的固定检查（同一组装，供多条回归脚本复用）
fn run_assert_check_for(
  script : Array[Command],
) -> @qcs.RunReport[Command, Response, Command, Response] raise {
  match
    @qcs.replay(
      quick_state_machine(),
      script_program(script),
      config=quick_run_config(),
    ) {
    Ok(report) => report
    Err(failure) =>
      fail("nquads assert check failed: \{@qcs.format_failure(failure)}")
  }
}

///|
/// **语义路径（label）门配置**：单条长用例（cases=1）+ 要求覆盖四个真能走到的响应分档。
/// 说明（2026-09-19 分母同源改造）：**命令名**维度已迁到 `reachable_coverage_account()`
/// （路径驱动、分母由 `reachable_witness_paths()` 派生、分子取自执行记录）；
/// 本 config 只保留 label 维度，避免同一个分母出现第二个手抄来源。
fn coverage_gate_config() -> @qcs.RunConfig {
  {
    ..quick_run_config(),
    cases: 1,
    max_commands: 200,
    // 语义路径覆盖（第二层，命令名之上）：只列随机生成**真能走到**的响应分档。
    // `resp:error` 只在未定义转移出现，而生成器被 valid 过滤 ⇒ 永远走不到，
    // 列进要求必然 CoverageFailed（与可达命令名同规）。
    required_labels: [
      "resp:continue", "resp:emit", "resp:emit:default", "resp:emit:graph",
    ],
    required_command_names: [],
  }
}

///|
/// 可达覆盖 **逐路径用例配置**：一条见证路径 = 一个用例，只扛它自己那一个命令名。
/// 依据：qcs 覆盖判定是**逐用例**的（`CoverageFailed` 一票否决）⇒ 多条路径塞一个用例会互相污染状态。
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
/// **可达命令名覆盖账（分子必须来自执行记录）**：
///   分母 = `reachable_witness_paths()` 派生（起点初始态、边 = `valid`，不可达项不进分母）；
///   分子 = 各条见证路径**实际执行**后 `RunReport.command_distribution` 的并集
///          （**不是**路径声明覆盖了谁 —— 声明与执行脱钩就是假绿）；
///   缺口 = 分母 − 分子（逐名列出，清空即门绿）。
/// 逐条独立起跑 + 干净复位：每条路径一个新 `check`、新状态机实例。
/// 用例漂移（模型 ≠ 引擎）由 `assert_check` 直接抛，不混进"缺口"。
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
  .map(fn(command) { name_of(command) })
  .filter(fn(name) { !denominator.contains(name) })
}

///|
/// 覆盖率门: 成功一次即可（覆盖要求由 config 判定，缺失即 CoverageFailed）
fn run_coverage_check() -> Result[
  @qcs.RunReport[Command, Response, Command, Response],
  @qcs.RunFailure[Model, Model, Command, Command, Response, Response],
] {
  @qcs.check(quick_state_machine(), config=coverage_gate_config())
}

///|
/// 随机检查: Result 返回，失败信息含反例命令序列（供 CI 分支处理）
fn run_random_check(
  config? : @qcs.RunConfig = quick_run_config(),
) -> Result[
  @qcs.RunReport[Command, Response, Command, Response],
  @qcs.RunFailure[Model, Model, Command, Command, Response, Response],
] {
  @qcs.check(quick_state_machine(), config~)
}

///|
test "nquads quick machine assert check" {
  let report = run_assert_check()
  assert_eq(report.commands_run, assert_script().length())
}

///|
test "nquads quick machine 三档重置脚本" {
  let report = run_assert_check_for(assert_script_scopes())
  assert_eq(report.commands_run, assert_script_scopes().length())
}

///|
test "nquads quick machine 覆盖率门（路径驱动·缺口清零）" {
  let (denominator, covered, missing) = reachable_coverage_account()
  let unreachable_names = unreachable_command_names()
  debug(
    "可达覆盖账 nquads[Deep]：分母 \{denominator.length()} / 分子 \{covered.length()} / 缺口 \{missing.length()} / 不可达 \{unreachable_names.length()}",
  )
  if missing.length() > 0 {
    debug("缺口清单：\{missing.join(",")}")
  }
  if unreachable_names.length() > 0 {
    debug(
      "不可达（不进分母，结构钉子钉住）：\{unreachable_names.join(",")}",
    )
  }
  // 防"分母为空"假绿（分母由 BFS 派生，表被改坏时可能整片塌掉）
  assert_true(denominator.length() > 0)
  // 缺口清零门：可达即必须被实际执行到
  assert_eq(missing, [])
  // 分母 + 不可达 = 全命令名（守恒，防"悄悄把可达项挪出分母"）
  assert_eq(
    denominator.length() + unreachable_names.length(),
    all_commands().length(),
  )
}

///|
/// 覆盖率门必须**不靠单一种子侥幸**：多种子重跑，任何一个种子缺命令名即失败。
/// 这条是生成分布（权重 × valid 过滤）的健康检查；分布调整后它会先亮红灯。
test "nquads quick machine 覆盖率门: 多种子稳定" {
  for seed in [12345UL, 1UL, 7UL, 99UL, 2026UL] {
    let config : @qcs.RunConfig = { ..coverage_gate_config(), seed, }
    match @qcs.check(quick_state_machine(), config~) {
      Ok(report) => {
        let missing = @qcs.cover_command_names(
          report.command_distribution,
          config.required_command_names,
        )
        assert_eq(missing, [])
      }
      Err(failure) =>
        fail("seed \{seed} coverage failed: \{@qcs.format_failure(failure)}")
    }
  }
}

///|
test "nquads quick machine random check" {
  match run_random_check() {
    Ok(report) => assert_eq(report.cases_run, quick_run_config().cases)
    Err(failure) =>
      fail("nquads random check failed: \{@qcs.format_failure(failure)}")
  }
}

///|
test "nquads quick machine detects system drift" {
  // 反例注入：系统丢图名（模型预测 graph = Some，系统返回 None）——必须被判定失败
  let graph_dropping = fn(command : Command, system : System) -> Response {
    match run_command(command, system) {
      EmitQuad(quad) => EmitQuad({ ..quad, graph: None, })
      other => other
    }
  }
  let config : @qcs.RunConfig = {
    ..quick_run_config(),
    cases: 30,
    max_commands: 12,
  }
  match @qcs.check(quick_state_machine(system_call=graph_dropping), config~) {
    Ok(_) => fail("expected the injected drift to be detected")
    Err(_) => ()
  }
}

///|
test "nquads quick machine detects error-code drift" {
  // 反例注入：系统返回**约定外错误码**（Error(99)；[type_mapping].error_codes 只约定
  // 0 = 未定义转移 / 1 = action 失败）——spec §5 失败语义第三档必须被判定失败。
  // Continue 是恒可达分档 ⇒ 任一用例首命令即触发，检出是确定性的。
  let code_flipping = fn(command : Command, system : System) -> Response {
    match run_command(command, system) {
      Continue => Error(99)
      other => other
    }
  }
  let config : @qcs.RunConfig = {
    ..quick_run_config(),
    cases: 5,
    max_commands: 4,
  }
  match @qcs.check(quick_state_machine(system_call=code_flipping), config~) {
    Ok(_) =>
      fail("约定外错误码必须被检出（unexpected error code）")
    Err(_) => ()
  }
}

///|
test "nquads quick machine random check: 多种子稳定" {
  // 属性主门与覆盖率门同规（spec §9.6）：不靠单种子侥幸——
  // 种子只影响探索路径，不放宽判定；分布/收缩回归会先在这里亮红灯。
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
