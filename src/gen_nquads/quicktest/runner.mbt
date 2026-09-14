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
/// 覆盖率门配置：单条长用例（cases=1）+ 要求覆盖全部**可达**命令名。
/// 注意 qcs 的覆盖判定是**逐用例**的（`CoverageFailed` 一票否决），所以这里
/// 用单条长序列而不是把要求挂到随机多用例上。
/// 可达集合 = 转移表里有出边的命令：PrefName / EOF 在本 FSM 无转移（valid 表兜底
/// `(_, _) => false`），因此**不能**进要求列表，否则必然 CoverageFailed。
fn coverage_gate_config() -> @qcs.RunConfig {
  {
    ..quick_run_config(),
    cases: 1,
    max_commands: 200,
    required_command_names: [
      "Iri", "BlankNode", "Literal", "TripleTerm", "Comma", "Semicolon", "Dot", "Unknown",
    ],
  }
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
test "nquads quick machine 覆盖率门" {
  match run_coverage_check() {
    Ok(report) => {
      // qcs 已在内部判定（缺失即 CoverageFailed）；这里用同一 helper 再钉一次，
      // 让"覆盖了哪些命令"成为报告里可复读的事实
      let missing = @qcs.cover_command_names(
        report.command_distribution,
        coverage_gate_config().required_command_names,
      )
      assert_eq(missing, [])
      assert_true(report.commands_run > 0)
    }
    Err(failure) =>
      fail("coverage gate failed: \{@qcs.format_failure(failure)}")
  }
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
