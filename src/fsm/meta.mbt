// 状态元数据（用于 V3, V4, V5 检查）
///|
pub(all) struct StateMeta {
  name : String
  is_initial : Bool
  is_nestable : Bool
  exit_event : String?
}

// 扩展的验证函数

///|
pub fn validate(
  states_meta : Array[StateMeta],
  events : Array[String],
  rules : Array[TransitionRule],
  errors : Array[ValidationError],
) -> ValidationResult {
  let result = ValidationResult::new()

  // 构建快速查找集合
  let state_set = Set([])
  let event_set = Set([])
  let trans_set = Set([]) // 用于 V6 去重检查

  for s in states_meta {
    state_set.add(s.name)
  }
  for e in events {
    event_set.add(e)
  }

  // --- V3: UNIQUE_INITIAL ---
  // V3 的建议
  let initial_count = states_meta.filter(fn(s) { s.is_initial }).length()
  if initial_count == 0 {
    result.add_error_with_suggestion(
      V3_UNIQUE_INITIAL,
      "No initial state defined.",
      "Add 'is_initial = true' to one of your states.",
    )
  } else if initial_count > 1 {
    let initial_names = states_meta
      .filter(fn(s) { s.is_initial })
      .map(fn(s) { s.name })
      .join(", ")
    result.add_error_with_suggestion(
      V3_UNIQUE_INITIAL,
      "Multiple initial states found: \{initial_names}",
      "Mark only one state with 'is_initial = true'.",
    )
  }

  // --- V4 & V5: NESTABLE / EXIT_EVENT 检查 ---
  for s in states_meta {
    if s.is_nestable {
      match s.exit_event {
        None =>
          result.add_error(
            V4_NESTABLE_HAS_EXIT,
            "Nestable state '\{s.name}' must declare an exit_event.",
          )
        Some(evt) =>
          if !event_set.contains(evt) {
            result.add_error(
              V5_EXIT_EVENT_DEFINED,
              "exit_event '\{evt}' in state '\{s.name}' is not a defined event.",
            )
          }
      }
    }
  }

  // --- V1, V2, V6: 转移规则检查 ---
  for rule in rules {
    // V1: from / goto 引用检查
    if !state_set.contains(rule.from_state) {
      result.add_error(
        V1_FROM_REFS_STATE,
        "Transition from unknown state '\{rule.from_state}'.",
      )
    }
    if !state_set.contains(rule.to_state) {
      result.add_error(
        V1_FROM_REFS_STATE,
        "Transition goto unknown state '\{rule.to_state}'.",
      )
    }

    // V2: on 引用检查
    if !event_set.contains(rule.on_event) {
      result.add_error(
        V2_ON_REFS_EVENT,
        "Transition on unknown event '\{rule.on_event}'.",
      )
    }

    // V6: 重复转移检查 (from, on) 必须唯一
    let trans_key = "\{rule.from_state}|\{rule.on_event}"
    if trans_set.contains(trans_key) {
      result.add_error(
        V6_NO_DUPLICATE_TRANS,
        "Duplicate transition defined for (\{rule.from_state}, \{rule.on_event}).",
      )
    } else {
      trans_set.add(trans_key)
    }
  }

  result
}

///|
pub fn ValidationResult::add_error_with_suggestion(
  self : ValidationResult,
  rule : Rule,
  msg : String,
  suggestion : String,
) -> Unit {
  self.errors.push(ValidationError::{
    rule,
    message: msg,
    suggestion: Some(suggestion),
  })
}

// 查找最相似的状态名

///|
fn find_similar_state(
  target : String,
  states_meta : Array[StateMeta],
) -> String? {
  let states = states_meta.map(fn(s) { s.name })
  find_similar(target, states)
}

// 查找最相似的事件名

///|
fn find_similar_event(target : String, events : Array[String]) -> String? {
  find_similar(target, events)
}

// 通用相似查找（编辑距离 ≤ 2）

///|
fn find_similar(target : String, candidates : Array[String]) -> String? {
  let mut best = None
  let mut best_dist = 3 // 阈值

  for candidate in candidates {
    let dist = edit_distance(target, candidate)
    if dist < best_dist {
      best_dist = dist
      best = Some(candidate)
    }
  }

  best
}

// 编辑距离

///|
fn edit_distance(a : String, b : String) -> Int {
  let len_a = a.length()
  let len_b = b.length()

  if len_a == 0 {
    return len_b
  }
  if len_b == 0 {
    return len_a
  }

  // 简化为长度差作为近似（完整实现需要动态规划）
  (len_a - len_b).abs()
}

///|
test {
  // V3: 没有初始状态
  let result = validate(
    [
      StateMeta::{
        name: "idle",
        is_initial: false,
        is_nestable: false,
        exit_event: None,
      },
    ],
    [],
    [],
    [],
  )
  assert_false(result.is_ok())
  assert_true(result.errors[0].rule == V3_UNIQUE_INITIAL)
}

///|
test {
  // V3: 多个初始状态
  let result = validate(
    [
      StateMeta::{
        name: "a",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
      StateMeta::{
        name: "b",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
    ],
    [],
    [],
    [],
  )
  assert_false(result.is_ok())
  assert_true(result.errors[0].rule == V3_UNIQUE_INITIAL)
}

///|
test {
  // V1: 引用未定义的状态
  let result = validate(
    [
      StateMeta::{
        name: "idle",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
    ],
    ["start"],
    [
      TransitionRule::{
        from_state: "idle",
        to_state: "undefined",
        on_event: "start",
        guard_def: None,
        action: None,
      },
    ],
    [],
  )
  assert_false(result.is_ok())
  let has_v1_error = result.errors.any(fn(e) { e.rule == V1_FROM_REFS_STATE })
  assert_true(has_v1_error)
}

///|
test {
  // V2: 引用未定义的事件
  let result = validate(
    [
      StateMeta::{
        name: "idle",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
    ],
    ["start"],
    [
      TransitionRule::{
        from_state: "idle",
        to_state: "idle",
        on_event: "undefined",
        guard_def: None,
        action: None,
      },
    ],
    [],
  )
  assert_false(result.is_ok())
  let has_v2_error = result.errors.any(fn(e) { e.rule == V2_ON_REFS_EVENT })
  assert_true(has_v2_error)
}

///|
test {
  // V6: 重复转移
  let result = validate(
    [
      StateMeta::{
        name: "idle",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
    ],
    ["start"],
    [
      TransitionRule::{
        from_state: "idle",
        to_state: "a",
        on_event: "start",
        guard_def: None,
        action: None,
      },
      TransitionRule::{
        from_state: "idle",
        to_state: "b",
        on_event: "start",
        guard_def: None,
        action: None,
      },
    ],
    [],
  )
  assert_false(result.is_ok())
  let has_v6_error = result.errors.any(fn(e) { e.rule == V6_NO_DUPLICATE_TRANS })
  assert_true(has_v6_error)
}

///|
test {
  // V4: nestable 状态没有 exit_event
  let result = validate(
    [
      StateMeta::{
        name: "parent",
        is_initial: true,
        is_nestable: true,
        exit_event: None,
      },
    ],
    ["enter", "exit"],
    [],
    [],
  )
  assert_false(result.is_ok())
  let has_v4_error = result.errors.any(fn(e) { e.rule == V4_NESTABLE_HAS_EXIT })
  assert_true(has_v4_error)
}

///|
test {
  // V5: exit_event 引用未定义的事件
  let result = validate(
    [
      StateMeta::{
        name: "parent",
        is_initial: true,
        is_nestable: true,
        exit_event: Some("undefined_exit"),
      },
    ],
    ["enter"],
    [],
    [],
  )
  assert_false(result.is_ok())
  let has_v5_error = result.errors.any(fn(e) { e.rule == V5_EXIT_EVENT_DEFINED })
  assert_true(has_v5_error)
}

///|
test {
  // 合法的 nestable 状态
  let result = validate(
    [
      StateMeta::{
        name: "parent",
        is_initial: true,
        is_nestable: true,
        exit_event: Some("exit"),
      },
    ],
    ["enter", "exit"],
    [],
    [],
  )
  assert_true(result.is_ok())
}

///|
test {
  // 合法状态机
  let result = validate(
    [
      StateMeta::{
        name: "idle",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
      StateMeta::{
        name: "running",
        is_initial: false,
        is_nestable: false,
        exit_event: None,
      },
    ],
    ["start", "stop"],
    [
      TransitionRule::{
        from_state: "idle",
        to_state: "running",
        on_event: "start",
        guard_def: None,
        action: None,
      },
      TransitionRule::{
        from_state: "running",
        to_state: "idle",
        on_event: "stop",
        guard_def: None,
        action: None,
      },
    ],
    [],
  )
  assert_true(result.is_ok())
  assert_true(result.errors.is_empty())
}

///|
test {
  // 带有 action 和 guard 的合法状态机
  let result = validate(
    [
      StateMeta::{
        name: "idle",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
    ],
    ["start", "stop"],
    [
      TransitionRule::{
        from_state: "idle",
        to_state: "idle",
        on_event: "start",
        guard_def: Some(GuardDef::{
          name: "check",
          expression: Some("count > 0"),
        }),
        action: Some("increment"),
      },
    ],
    [],
  )
  assert_true(result.is_ok())
}

///|
test {
  // 多个错误同时存在
  let result = validate(
    [
      StateMeta::{
        name: "a",
        is_initial: true,
        is_nestable: false,
        exit_event: None,
      },
    ],
    ["start"],
    [
      TransitionRule::{
        from_state: "a",
        to_state: "b",
        on_event: "start",
        guard_def: None,
        action: None,
      }, // b
      TransitionRule::{
        from_state: "a",
        to_state: "a",
        on_event: "stop",
        guard_def: None,
        action: None,
      }, //
    ],
    [],
  )
  assert_false(result.is_ok())
  assert_true(result.errors.length() >= 2)
}
