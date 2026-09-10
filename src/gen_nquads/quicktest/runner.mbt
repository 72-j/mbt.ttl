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
  match
    @qcs.replay(
      quick_state_machine(),
      script_program(assert_script()),
      config=quick_run_config(),
    ) {
    Ok(report) => report
    Err(failure) =>
      fail("nquads assert check failed: \{@qcs.format_failure(failure)}")
  }
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
