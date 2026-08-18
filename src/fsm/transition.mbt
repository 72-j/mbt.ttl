// 守卫条件（简化为字符串表达式，后续可替换为 AST）

///|
/// 守卫条件
pub struct Guard {
  name : String
  condition : String
} derive(Debug, Eq)

///|
pub fn Guard::new(condition : String) -> Guard {
  Guard::{ name: "guard", condition }
}

///|
pub fn Guard::to_string(self : Guard) -> String {
  "\{self.name}(\{self.condition})"
}

///|
impl Show for Guard with fn output(self, logger) {
  logger.write("Guard:")
  logger.write("  name: \{self.name}")
  logger.write("  condition: \{self.condition}")
}

///|
impl Show for Action with fn output(self, logger) {
  logger.write("Action:")
  logger.write("  name: \{self.name}")
  logger.write("  params: \{self.params}")
}

///|
/// 动作
pub struct Action {
  name : String
  params : Array[String]
} derive(Debug, Eq)

///|
pub fn Action::new(name : String) -> Action {
  Action::{ name, params: [] }
}

///|
pub fn Action::with_params(name : String, params : Array[String]) -> Action {
  Action::{ name, params }
}

///|
pub fn Action::to_string(self : Action) -> String {
  if self.params.is_empty() {
    self.name
  } else {
    "\{self.name}(\{self.params.join(", \\")})"
  }
}

// 转移规则：张量中每个非零元素

///|
pub struct Transition {
  next_state : String
  guard_def : Guard?
  action : Action?
} derive(Debug)

///|
pub impl Show for Transition with fn output(self, logger) {
  logger.write("Transition:")
  logger.write("  next_state: \{@debug.to_string(self.next_state)}")
  logger.write("  guard_def: \{@debug.to_string(self.guard_def)}")
  logger.write("  action: \{@debug.to_string(self.action)}")
}

///|
pub fn Transition::new(
  next_state : String,
  guard_def : Guard?,
  action : Action?,
) -> Transition {
  Transition::{ next_state, guard_def, action }
}

///|
test {
  // 定义状态和事件
  let states = ["Idle", "Running", "Stopped"]
  let events = ["Start", "Stop", "Reset"]

  // 定义转移规则
  let rules = [
    TransitionRule::{
      from_state: "Idle",
      on_event: "Start",
      to_state: "Running",
      guard_def: None,
      action: None,
    },
    TransitionRule::{
      from_state: "Running",
      on_event: "Stop",
      to_state: "Stopped",
      guard_def: None,
      action: Some("log_stopped"),
    },
    TransitionRule::{
      from_state: "Stopped",
      on_event: "Reset",
      to_state: "Idle",
      guard_def: None,
      action: None,
    },
    TransitionRule::{
      from_state: "Running",
      on_event: "Reset",
      to_state: "Idle",
      guard_def: Some(GuardDef::{ name: "x_check", expression: Some("x > 0") }),
      action: Some("force_reset"),
    },
  ]

  // 1. construct：构建 FSM
  let ir = construct_from_arrays(states, events, rules).unwrap()

  assert_eq(ir.states.length(), 3)
  assert_eq(ir.events.length(), 3)
  assert_eq(ir.transitions.length(), 4)

  // 2. validate：验证 FSM
  let validation = validate_ir(ir)
  assert_true(validation.is_ok())

  // 3. prune：剪枝
  let pruned = prune(ir)
  assert_eq(pruned.states.length(), 3) // 所有状态都可达
  assert_eq(pruned.transitions.length(), 4)

  // 4. minimize：最小化
  let minimized = minimize(pruned)
  // Running 和 Stopped 行为不同，不应合并
  assert_eq(minimized.states.length(), 3)

  // 5. fuse：融合
  let fused = fuse(minimized)
  // 没有可融合的链，保持不变
  assert_eq(fused.transitions.length(), 4)

  // 6. codegen：生成代码
  let config = CodegenConfig::default()
  let code = codegen(fused, config)

  // 验证生成的代码
  assert_true(code.contains("pub(all) enum Event"))
  assert_true(code.contains("pub(all) enum State"))
  assert_true(code.contains("] step("))
  assert_true(code.contains("pub trait Actions"))

  // 验证事件名称
  assert_true(code.contains("Start"))
  assert_true(code.contains("Stop"))
  assert_true(code.contains("Reset"))

  // 验证状态名称
  assert_true(code.contains("Idle"))
  assert_true(code.contains("Running"))
  assert_true(code.contains("Stopped"))
}

///|
test {
  // 测试带命名前缀
  let states = ["idle", "running"]
  let events = ["start", "stop"]
  let rules = [
    TransitionRule::{
      from_state: "idle",
      on_event: "start",
      to_state: "running",
      guard_def: None,
      action: None,
    },
  ]

  let ir = construct_from_arrays(states, events, rules).unwrap()
  let config = CodegenConfig::{
    trait_name: "Actions",
    debug: false,
    output_module: "my_fsm",
    name_prefix: "My",
    actions: None,
    effects: None,
    context: None,
  }
  let code = codegen(ir, config)

  // 验证命名前缀
  assert_true(code.contains("MyIdle"))
  assert_true(code.contains("MyRunning"))
  assert_true(code.contains("MyStart"))
  assert_true(code.contains("MyStop"))
}

///|
test {
  // 测试 debug 模式
  let states = ["idle", "running"]
  let events = ["start"]
  let rules = [
    TransitionRule::{
      from_state: "idle",
      on_event: "start",
      to_state: "running",
      guard_def: None,
      action: None,
    },
  ]

  let ir = construct_from_arrays(states, events, rules).unwrap()
  let config = CodegenConfig::{
    trait_name: "Actions",
    debug: true,
    output_module: "debug_fsm",
    name_prefix: "",
    actions: None,
    effects: None,
    context: None,
  }
  let code = codegen(ir, config)

  // 验证 debug 辅助函数
  assert_true(code.contains("pub fn state_name"))
  assert_true(code.contains("pub fn event_name"))
  assert_true(code.contains("// [FSM]"))
}
