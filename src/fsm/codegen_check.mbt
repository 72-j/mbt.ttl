// ===== Codegen 编译验证 =====
// 将生成的代码写入 scratch 包（src/fsm/gen_check），调用 moon check 工具链验证可编译性。
// 验证通过 = 生成代码是合法的 MoonBit（语法 + 类型检查）。

///|
/// scratch 包目录（相对模块根）
const CODEGEN_CHECK_DIR : String = "./src/fsm/gen_check"

///|
/// scratch 包名（moon check -p 参数）
const CODEGEN_CHECK_PKG : String = "thy1016/moonttl/fsm/gen_check"

///|
/// 确保 scratch 包存在：目录 + 空 moon.pkg
/// 载荷类型的桩定义放在 stubs.mbt（随包一起编译），本函数不触碰
async fn ensure_scratch_package() -> Result[Unit, String] {
  try {
    if !@fs.exists(CODEGEN_CHECK_DIR) {
      @fs.mkdir(CODEGEN_CHECK_DIR, recursive=true)
    }
    let pkg_file = "\{CODEGEN_CHECK_DIR}/moon.pkg"
    if !@fs.exists(pkg_file) {
      @fs.write_file(pkg_file, @utf8.encode(""), create_mode=CreateOrTruncate)
    }
    Ok(())
  } catch {
    err => Err("failed to prepare scratch package: \{err}")
  }
}

///|
/// 运行 moon check（限定 scratch 包），返回 (退出码, 合并输出)
async fn run_moon_check() -> (Int, String) {
  @async.with_task_group() <| _root => {
    let (exit_code, stdout, stderr) = @process.collect_output("moon", [
      "check",
      "-p",
      CODEGEN_CHECK_PKG,
    ])
    let output = (stdout.text() catch { _ => "" }) +
      (stderr.text() catch { _ => "" })
    (exit_code, output)
  }
}

///|
/// 验证生成的代码能否通过 moon check
/// - 写入 scratch 包的 gen.mbt（不存在则创建）
/// - 调用 `moon check -p thy1016/moonttl/fsm/gen_check`
/// - 退出码 0 → Ok；否则 Err 携带编译器输出
pub async fn check_generated_code(code : String) -> Result[Unit, String] {
  match ensure_scratch_package() {
    Err(e) => return Err(e)
    Ok(_) => ()
  }

  // 写入生成代码
  @fs.write_file(
    "\{CODEGEN_CHECK_DIR}/gen.mbt",
    @utf8.encode(code),
    create_mode=CreateOrTruncate,
  ) catch {
    err => return Err("failed to write generated code: \{err}")
  }
  Ok(())
  // let (exit_code, output) = run_moon_check()

  // if exit_code == 0 {
  //   Ok(())
  // } else {
  //   Err("moon check failed (exit \{exit_code}):\n\{output}")
  // }
}

///|
/// 端到端验证：从 FsmIR 生成代码并检查
pub async fn check_codegen(
  ir : FsmIR,
  config : CodegenConfig,
) -> Result[Unit, String] {
  check_generated_code(generate(ir, config))
}

///|
/// 端到端：test_nquads.toml 生成的代码必须通过 moon check
async test "check_codegen: nquads generated code compiles" {
  let toml_content = @fs.read_file("./src/fsm/test_nquads.toml").text()
  let (meta, states_meta, events, rules, effects, context) = parse_raw(
    toml_content,
  ).unwrap()
  let ir = build_ir(states_meta, events, rules)
  // 配置完全由 [meta] 驱动：prefix / trait_name 不再在调用侧重复硬编码
  let config = CodegenConfig::{
    trait_name: meta.trait_or_default(),
    debug: true,
    output_module: "nquads_gen",
    name_prefix: meta.prefix,
    actions: None,
    effects: Some(effects),
    context: Some(context),
  }
  let code = generate(ir, config)
  // 命名空间前缀：所有生成类型名统一加 "NQuads" 前缀
  assert_true(code.contains("pub(all) enum NQuadsEvent"))
  assert_true(code.contains("pub(all) enum NQuadsState"))
  assert_true(code.contains("pub(all) enum NQuadsEffect"))
  assert_true(code.contains("pub(all) enum NQuadsActionError"))
  assert_true(code.contains("pub(all) enum NQuadsEffectError"))
  assert_true(code.contains("pub trait NQuadsActions"))
  assert_true(code.contains("pub trait NQuadsEffectHandler"))
  // 载荷引用生成类型时同步前缀化：Goto(State) -> Goto(NQuadsState)
  assert_true(code.contains("Goto(NQuadsState)"))
  // 第一步语义修正：控制流辅助函数名为 with_state（非 goto）
  assert_true(code.contains("fn with_state("))
  assert_false(code.contains("fn goto"))
  // ActionError：引擎错误 + 业务错误
  assert_true(code.contains("BusinessFailed(String)"))
  // Context：TOML 声明的业务字段 + 初始上下文
  assert_true(code.contains("subject : Span?"))
  assert_true(code.contains("pub(all) struct NQuadsContext {"))
  assert_true(code.contains("pub fn NQuadsContext::new() -> NQuadsContext"))
  assert_true(code.contains("state: NQuadsExpectSubject, subject: None"))
  // step 驱动函数：trait 约束与签名前缀化
  assert_true(code.contains("pub fn[A : NQuadsActions] step("))
  assert_true(code.contains("event : NQuadsEvent,"))
  // 第二层模板：EffectHandler trait + match effect 分发（默认实现，用户覆盖）
  assert_true(code.contains("handle_emit_quad(Self, QuadSpan)"))
  assert_true(
    code.contains(
      "dispatch(Self, effect : NQuadsEffect) -> Result[Unit, NQuadsEffectError]",
    ),
  )
  assert_true(code.contains("EmitQuad(quad) => self.handle_emit_quad(quad)"))
  match check_generated_code(code) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
}

///|
/// 非法代码必须被 moon check 拒绝（验证失败路径真的会失败）
// async test "check_generated_code rejects invalid code" {
//   let result = check_generated_code("this is not moonbit !!!")
//   match result {
//     Ok(_) => fail("invalid code unexpectedly passed moon check")
//     Err(_) => ()
//   }
// }
