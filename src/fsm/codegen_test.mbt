// ===== Codegen Test - 阶段 3: 测试代码生成（测试即生成）=====
// 由 PathReport.generated_paths（状态序列）+ 转移表生成驱动 step 的路径测试。
// 消除人工盲区: 路径来自静态图分析（含未覆盖转移补充路径），开发者无需手数边界情况。
// 同源生成: 引擎代码与测试代码出自同一份 TOML 与同一次分析，杜绝漂移。
//
// 载荷占位: 带载荷事件用 abort "TODO: fill ..." 占位（可编译，跑到即提示）。
// 下一阶段 quickcheck_statemachine 集成时将替换为 Command/RefId 映射（见 quicktest.md）。

///|
/// 生成路径测试代码（与引擎代码同包放置，无需 import）
///
/// # 参数
/// - ir: 状态机 IR（事件/转移的权威来源）
/// - config: 代码生成配置（前缀等）
/// - paths: 路径分析器输出的测试路径（状态名序列）
pub fn generate_path_tests(
  ir : FsmIR,
  config : CodegenConfig,
  paths : Array[Array[String]],
) -> String {
  let code = StringBuilder::new()
  code <+ "// ===== Auto-generated FSM path tests (fsm-gen) =====\n"
  code <+
    "// 路径来源: 静态图分析（可达/终止/错误/循环加压/未覆盖补充）\n"
  code <+ "// 请勿手工编辑；修改 TOML 后重新生成。\n"
  code <+ "// 路径数: \{paths.length()}\n\n"
  emit_test_stub(ir, config, code)
  code <+ "\n// ---------- 路径测试 ----------\n\n"
  emit_path_test_blocks(ir, config, paths, code)
  code.to_string()
}

///|
/// 测试桩: Actions trait 的直通实现（保持 ctx，返回默认 Effect）
/// 业务断言请在各方法内补充
fn emit_test_stub(
  ir : FsmIR,
  config : CodegenConfig,
  code : StringBuilder,
) -> Unit {
  let stub = prefixed_type(config, "TestActions")
  let ctx = context_type(config)
  let effect_t = prefixed_type(config, "Effect")
  let err_t = prefixed_type(config, "ActionError")
  let default_effect = default_effect_name(config)

  code <+ "///|\n"
  code <+
    "/// 测试桩 Actions: 所有 action 直通（保持 ctx，返回默认 Effect）\n"
  code <+ "struct \{stub} {\n}\n\n"
  code <+ "fn \{stub}::new() -> \{stub} {\n  \{stub}::{}\n}\n\n"

  let actions = collect_action_names(ir)
  if actions.length() > 0 {
    code <+ "impl \{config.trait_name} for \{stub} {\n"
    for name in actions {
      let (params, args) = match action_param_type(ir, name) {
        NoParam => ("(self, ctx : \{ctx})", "")
        Payload(type_) => {
          let rewritten = rewrite_type(config, type_)
          ("(self, ctx : \{ctx}, p0 : \{rewritten})", "")
        }
        WholeEvent =>
          ("(self, ctx : \{ctx}, p0 : \{prefixed_type(config, "Event")})", "")
      }
      ignore(args)
      code <+
        "  fn \{name}\{params} -> Result[(\{ctx}, \{effect_t}), \{err_t}] {\n"
      code <+ "    // TODO: 补充业务断言\n"
      code <+ "    Ok((ctx, \{default_effect}))\n"
      code <+ "  }\n"
    }
    code <+ "}\n"
  } else {
    // 无 action 转移: trait 无方法，空实现
    code <+ "impl \{config.trait_name} for \{stub} {}\n"
  }
}

///|
/// 路径 test 块: 每条路径一个 test，逐步 dispatch 事件并断言终态
fn emit_path_test_blocks(
  ir : FsmIR,
  config : CodegenConfig,
  paths : Array[Array[String]],
  code : StringBuilder,
) -> Unit {
  let ctx = context_type(config)
  let stub = prefixed_type(config, "TestActions")

  for idx, path in paths {
    code <+ "///|\n"
    code <+ "test \"path \{idx + 1}: \{path.join(" -> ")}\" {\n"
    code <+ "  let actions = \{stub}::new()\n"
    code <+ "  let mut ctx = \{ctx}::new()\n"

    // 逐步驱动: 相邻状态对 (from, to) → 声明序第一条转移的事件
    for i = 0; i < path.length() - 1; i = i + 1 {
      match path_event_expr(ir, config, path[i], path[i + 1]) {
        Some(event_expr) =>
          code <+ "  ctx = step(ctx, \{event_expr}, actions).unwrap().0\n"
        None =>
          // 防御: 相邻对无对应转移（路径全部来自图分析，理论不可达）
          code <+ "  // WARNING: no transition \{path[i]} -> \{path[i + 1]}\n"
      }
    }

    // 终态断言
    let final_state = format_state_name(
      path[path.length() - 1],
      config.name_prefix,
    )
    code <+ "  assert_true(ctx.state is \{final_state})\n"
    code <+ "}\n\n"
  }
}

///|
/// 相邻状态对 → 事件构造表达式（取声明序第一条 from→to 转移）
/// 带载荷事件用 abort 占位: NQuadsIri(abort "TODO: fill Span")
fn path_event_expr(
  ir : FsmIR,
  config : CodegenConfig,
  from : String,
  to : String,
) -> String? {
  let mut best : EventDef? = None
  let mut best_id = -1
  for t in ir.transitions {
    if ir.states[t.from_state].name == from && ir.states[t.to_state].name == to {
      if best_id < 0 || t.on_event < best_id {
        best_id = t.on_event
        best = Some(ir.events[t.on_event])
      }
    }
  }
  match best {
    None => None
    Some(event) => {
      let variant = format_event_name(event.name, config.name_prefix)
      if event.payload.is_empty() {
        Some(variant)
      } else {
        // 每个载荷字段一个 abort 占位
        let placeholders = event.payload.map(fn(f) {
          "abort \"TODO: fill \{f.type_} payload\""
        })
        Some("\{variant}(\{placeholders.join(", ")})")
      }
    }
  }
}

///|
test {
  // 线性链: 桩 + 2 个 test 块（无载荷路径完全可执行）
  let states = [
    StateMeta::{
      name: "a",
      is_initial: true,
      is_nestable: false,
      exit_event: None,
    },
    StateMeta::{
      name: "b",
      is_initial: false,
      is_nestable: false,
      exit_event: None,
    },
    StateMeta::{
      name: "c",
      is_initial: false,
      is_nestable: false,
      exit_event: None,
    },
  ]
  let events = [
    EventMeta::{ name: "e1", payload: [] },
    EventMeta::{ name: "e2", payload: [] },
  ]
  let rules = [
    TransitionRule::{
      from_state: "a",
      on_event: "e1",
      to_state: "b",
      guard_def: None,
      action: Some("do_b"),
    },
    TransitionRule::{
      from_state: "b",
      on_event: "e2",
      to_state: "c",
      guard_def: None,
      action: None,
    },
  ]
  let ir = build_ir(states, events, rules)
  let config = CodegenConfig::{
    trait_name: "TActions",
    debug: false,
    output_module: "t_gen",
    name_prefix: "T",
    actions: None,
    effects: None,
    context: None,
  }

  let code = generate_path_tests(ir, config, [["a", "b", "c"], ["a", "b"]])
  // 桩: 直通实现 + 默认 Effect
  assert_true(code.contains("struct TTestActions"))
  assert_true(code.contains("impl TActions for TTestActions"))
  assert_true(code.contains("fn do_b(self, ctx : TContext"))
  assert_true(code.contains("Ok((ctx, Continue))"))
  // test 块: step 链 + 终态断言
  assert_true(code.contains("test \"path 1: a -> b -> c\""))
  assert_true(code.contains("let mut ctx = TContext::new()"))
  assert_true(code.contains("ctx = step(ctx, TE1, actions).unwrap().0"))
  assert_true(code.contains("assert_true(ctx.state is TC)"))
  assert_true(code.contains("assert_true(ctx.state is TB)"))
}

///|
test {
  // 带载荷事件: abort 占位
  let states = [
    StateMeta::{
      name: "a",
      is_initial: true,
      is_nestable: false,
      exit_event: None,
    },
    StateMeta::{
      name: "b",
      is_initial: false,
      is_nestable: false,
      exit_event: None,
    },
  ]
  let events = [
    EventMeta::{ name: "Iri", payload: [{ name: "iri", type_: "Span" }] },
  ]
  let rules = [
    TransitionRule::{
      from_state: "a",
      on_event: "Iri",
      to_state: "b",
      guard_def: None,
      action: None,
    },
  ]
  let ir = build_ir(states, events, rules)
  let config = CodegenConfig::{
    trait_name: "TActions",
    debug: false,
    output_module: "t_gen",
    name_prefix: "T",
    actions: None,
    effects: None,
    context: None,
  }

  let code = generate_path_tests(ir, config, [["a", "b"]])
  assert_true(code.contains("TIri(abort \"TODO: fill Span payload\")"))
  // 无 action: 空 impl
  assert_true(code.contains("impl TActions for TTestActions {}"))
}
