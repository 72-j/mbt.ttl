// ===== Path Analyzer Integration - 阶段 2: 静态分析前置 =====
// 流水线: [1 解析 TOML] → [2 analyze_fsm_paths → 门禁] → [3 生成引擎+测试代码] → [4 DOT 渲染]
// 设计要点:
//   - 静态分析前置: 不可达/死状态/循环在代码生成阶段暴露, 而非运行时测试失败
//   - 测试与实现同源: 测试路径与引擎代码来自同一份 TOML 和同一次分析
//   - 保守近似: 带 guard 的转移按无条件边处理, 可能在报告中虚报可达性

///|
/// 从 TOML 解析结果执行路径分析
///
/// effect 名推导: 转移声明的 action 名（Effect::classify 启发式归类 Error/Emit）,
/// 无 action 时用 [meta].default_effect（缺省 "Continue"）
pub fn analyze_fsm_paths(
  meta : MetaDef,
  states : Array[StateMeta],
  events : Array[EventMeta],
  rules : Array[TransitionRule],
) -> Result[@path_analyzer.AnalyzeResult, @path_analyzer.BuildError] {
  // 转移四元组 (from, on, to, effect_name)
  let rows = []
  for rule in rules {
    let effect_name = match rule.action {
      Some(action) => action
      None => meta.effect_or_default()
    }
    rows.push((rule.from_state, rule.on_event, rule.to_state, effect_name))
  }

  // 初始状态: is_initial 声明者; 缺失时回退首个状态（validate 已保证唯一初始）
  let mut initial = ""
  let mut found_initial = false
  for s in states {
    if s.is_initial {
      initial = s.name
      found_initial = true
      break
    }
  }
  if !found_initial && states.length() > 0 {
    initial = states[0].name
  }

  @path_analyzer.analyze(
    states=states.map(fn(s) { s.name }),
    events=events.map(fn(e) { e.name }),
    transitions=@path_analyzer.make_transitions(rows),
    initial_state=initial,
    terminal_states=meta.terminal_states,
  )
}

///|
/// 门禁: 结构性缺陷打印为警告（不阻断生成——Error 级拦截由 validate 负责,
/// 这里只暴露"能生成但值得人工审查"的问题）
pub fn print_analysis_warnings(result : @path_analyzer.AnalyzeResult) -> Unit {
  let report = result.report
  if report.unreachable_states.length() > 0 {
    println(
      "Warning: unreachable states (declared but never entered): \{report.unreachable_states.join(", ")}",
    )
  }
  if report.dead_states.length() > 0 {
    println(
      "Warning: dead states (reachable, non-terminal, no outgoing): \{report.dead_states.join(", ")}",
    )
  }
  if report.uncovered_transitions.length() > 0 {
    let pairs = report.uncovered_transitions.map(fn(
      pair : (String, String),
    ) -> String {
      let (state, event) = pair
      "\{state} --\{event}-->"
    })
    println(
      "Warning: \{report.uncovered_transitions.length()} transitions uncovered by generated paths: \{pairs.join(" ")}",
    )
  }
  if report.partial {
    println(
      "Warning: partial report - \{report.degradation_reason.unwrap_or("algorithm degradation")}",
    )
  }
}

///|
test {
  // 线性链 + 终止状态: 全覆盖无警告场景
  let meta = MetaDef::{
    name: "t",
    version: "0.1.0",
    description: None,
    trait_name: None,
    default_effect: None,
    prefix: "T",
    terminal_states: ["c"],
  }
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

  let result = analyze_fsm_paths(meta, states, events, rules).unwrap()
  assert_eq(result.report.reachable_states, ["a", "b", "c"])
  assert_eq(result.report.unreachable_states, [])
  assert_eq(result.report.dead_states, [])
  assert_eq(result.report.coverage_ratio, 1.0)
  // 无 action 转移用 default_effect → Continue; action 名 "do_b" 归 Other
  assert_true(result.dot.contains("digraph fsm"))
  assert_true(result.facts.is_dag)
}

///|
test {
  // 不可达 + 死状态: meta.terminal_states 未声明时, 无出边状态按死状态报告
  let meta = MetaDef::{
    name: "t",
    version: "0.1.0",
    description: None,
    trait_name: None,
    default_effect: None,
    prefix: "T",
    terminal_states: [],
  }
  let states = [
    StateMeta::{
      name: "a",
      is_initial: true,
      is_nestable: false,
      exit_event: None,
    },
    StateMeta::{
      name: "sink",
      is_initial: false,
      is_nestable: false,
      exit_event: None,
    },
    StateMeta::{
      name: "island",
      is_initial: false,
      is_nestable: false,
      exit_event: None,
    },
  ]
  let events = [EventMeta::{ name: "e1", payload: [] }]
  let rules = [
    TransitionRule::{
      from_state: "a",
      on_event: "e1",
      to_state: "sink",
      guard_def: None,
      action: None,
    },
  ]

  let result = analyze_fsm_paths(meta, states, events, rules).unwrap()
  assert_eq(result.report.unreachable_states, ["island"])
  assert_eq(result.report.dead_states, ["sink"]) // 无 terminal 声明 → 无出边即死状态
}
