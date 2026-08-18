// ===== Validate and Halt =====

///|
/// 从 FsmIR 构建中间表示
fn build_meta_from_ir(
  ir : FsmIR,
) -> (Array[StateMeta], Array[String], Array[TransitionRule]) {
  // 构建状态元数据
  let states_meta = ir.states.map(fn(s) {
    StateMeta::{
      name: s.name,
      is_initial: s.is_initial,
      is_nestable: s.is_nestable,
      exit_event: s.exit_event,
    }
  })

  // 收集事件名
  let events = ir.events.map(fn(e) { e.name })

  // 构建转移规则
  let rules = ir.transitions.map(fn(t) {
    TransitionRule::{
      from_state: ir.states[t.from_state].name,
      on_event: ir.events[t.on_event].name,
      to_state: ir.states[t.to_state].name,
      guard_def: t.guard_def,
      action: t.action,
    }
  })

  (states_meta, events, rules)
}

///|
/// 验证并暂停：如果验证失败直接 panic
pub fn validate_and_halt(ir : FsmIR) -> FsmIR {
  let (states_meta, events, rules) = build_meta_from_ir(ir)

  let validation = validate(states_meta, events, rules, [])

  if not(validation.is_ok()) {
    println("Validation failed with \{validation.errors.length()} error(s):")
    for err in validation.errors {
      println("  [\{err.rule}] \{err.message}")
      match err.suggestion {
        Some(s) => println("    Suggestion: \{s}")
        None => ()
      }
    }
    panic()
  }

  ir
}

///|
/// 验证并返回结果
pub fn validate_ir(ir : FsmIR) -> ValidationResult {
  let (states_meta, events, rules) = build_meta_from_ir(ir)
  validate(states_meta, events, rules, [])
}

///|
test {
  let ir = FsmIR::new()
  let (ir, start_id) = ir.add_event("start")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, running_id) = ir.add_state("running")

  let ir = ir.add_transition(idle_id, running_id, start_id)

  // 合法 FSM，验证通过
  let validated = validate_and_halt(ir)
  assert_eq(validated.states.length(), 2)
}

///|
test {
  let ir = FsmIR::new()
  let (ir, tick_id) = ir.add_event("tick")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, dead_id) = ir.add_state("dead") // 不可达状态，不会导致验证失败

  let ir = ir.add_transition(idle_id, idle_id, tick_id)

  // 无初始状态会导致验证失败
  // 但这里有两个状态且其中一个是初始状态，所以会通过
  let validated = validate_and_halt(ir)
  assert_true(validated.states.length() >= 1)
}

///|
test {
  let states = ["idle", "running", "paused"]
  let events = ["start", "stop", "pause", "resume"]
  let rules = [
    TransitionRule::{
      from_state: "idle",
      on_event: "start",
      to_state: "running",
      guard_def: None,
      action: None,
    },
    TransitionRule::{
      from_state: "running",
      on_event: "stop",
      to_state: "idle",
      guard_def: None,
      action: None,
    },
    TransitionRule::{
      from_state: "running",
      on_event: "pause",
      to_state: "paused",
      guard_def: None,
      action: None,
    },
    TransitionRule::{
      from_state: "paused",
      on_event: "resume",
      to_state: "running",
      guard_def: None,
      action: None,
    },
  ]

  let config = CodegenConfig::default()

  // 使用管道式调用
  let ir = construct_from_arrays(states, events, rules).unwrap()

  let code = ir
    |> validate_and_halt
    |> prune
    |> minimize
    |> fuse
    |> ir => { codegen(ir, config) }

  assert_true(code.contains("pub(all) enum Event"))
  assert_true(code.contains("pub(all) enum State"))
  assert_true(code.contains("] step("))
}

///|
async test {
  // 完整管线：TOML → parse → validate → build_ir → prune → minimize → codegen

  let toml_content = @fs.read_file("./src/fsm/test.toml").text()

  // 1. 解析
  let (_meta, states_meta, events, rules, _effects, _ctx) = parse_raw(
    toml_content,
  ).unwrap()

  // 2. 验证
  let validation = validate(states_meta, events.map(fn(e) { e.name }), rules, [])
  assert_true(validation.is_ok())

  // 3. 构建 IR
  let ir = build_ir(states_meta, events, rules)

  // 4. 构建张量
  // let tensor = FsmTensor::from_ir(ir)

  // // // 5. Prune（移除不可达状态）
  // let pruned = prune(tensor)

  // // // 6. Minimize（合并等价状态）
  // let minimized = minimize(pruned)

  // // 7. Codegen
  // let config = CodegenConfig::{ trait_name: "Actions", debug: false, output_module: "test_e2e" }
  // let code = generate(minimized, config)

  // // 验证生成的代码
  // assert_true(code.contains("pub(all) enum Event"))
  // assert_true(code.contains("pub(all) enum State"))
  // assert_true(code.contains("] step("))
}
