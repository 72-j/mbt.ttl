// ===== FSM Construct Module =====
// 从 TOML 解析结果构建 FsmIR

///|
/// TOML 解析后的 Effect 定义
pub(all) struct EffectDef {
  name : String // Effect 变体名
  payload : Array[PayloadField] // 载荷字段
  doc : String? // 文档注释
}

///|
/// 载荷字段
pub(all) struct PayloadField {
  name : String
  type_ : String // 类型字符串，如 "String", "Triple"
} derive(Debug)

///|
/// TOML 解析后的事件定义（含载荷）
pub(all) struct EventMeta {
  name : String // 事件名
  payload : Array[PayloadField] // 事件载荷字段
} derive(Debug)

///|
/// TOML 解析后的 Action 定义
pub(all) struct ActionDef {
  name : String // action 名称（对应 trait 方法名）
  params : Array[String] // 参数名列表
  emits : Array[String] // 该 action 可能产生的 Effect 列表
} derive(Debug)

///|
/// TOML 解析后的 Guard 定义
pub(all) struct GuardDef {
  name : String // 守卫条件名称
  expression : String? // 可选：守卫表达式（用于 codegen 生成条件代码）
} derive(Debug)

///|
/// TOML 解析后的转移规则
pub(all) struct TransitionRule {
  from_state : String
  on_event : String
  to_state : String
  guard_def : GuardDef? // 守卫条件声明
  action : String? // action 名称（字符串引用）
} derive(Debug)

///|
/// 错误类型
pub(all) enum ConstructError {
  UnknownState(String)
  UnknownEvent(String)
  UnknownAction(String)
  UnknownEffect(String, String) // (action_name, effect_name)
} derive(Debug)

// ============================================================
// construct - 主构建函数
// ============================================================

///|
/// 从规则列表构建 FsmIR
///
/// # 参数
/// - states: 状态名 → StateDef 的映射
/// - events: 事件名 → EventDef 的映射
/// - transitions: 转移规则列表
/// - actions: action 名 → ActionDef 的映射
/// - effects: effect 名 → EffectDef 的映射
///
/// # 校验逻辑
/// 1. 校验 from_state / to_state 是否存在于 states
/// 2. 校验 on_event 是否存在于 events
/// 3. 校验 action 是否存在于 actions（如果是 Some）
/// 4. 校验 action.emits 中的每个 effect 是否存在于 effects（如果是 Some）
pub fn construct(
  states : Map[String, StateDef],
  events : Map[String, EventDef],
  transitions : Array[TransitionRule],
  actions : Map[String, ActionDef],
  effects : Map[String, EffectDef],
) -> Result[FsmIR, ConstructError] {
  let mut ir = FsmIR::new()

  // 1. 添加所有事件到 IR
  let events_arr = events.to_array()
  for i = 0; i < events_arr.length(); i = i + 1 {
    let (name, _) = events_arr[i]
    let (new_ir, _) = ir.add_event(name)
    ir = new_ir
  }

  // 2. 添加所有状态到 IR
  let states_arr = states.to_array()
  for i = 0; i < states_arr.length(); i = i + 1 {
    let (name, state_def) = states_arr[i]
    let (new_ir, _) = ir.add_state(
      name,
      is_initial=state_def.is_initial,
      is_nestable=state_def.is_nestable,
      exit_event=state_def.exit_event,
      data_fields=state_def.data_fields,
    )
    ir = new_ir
  }

  // 3. 添加转移规则到 IR（带校验）
  for rule in transitions {
    // 校验 from_state
    let from_id = ir.state_index.get(rule.from_state)
    let to_id = ir.state_index.get(rule.to_state)
    let on_id = ir.event_index.get(rule.on_event)

    // 校验 from_state 是否存在
    let from_idx = match from_id {
      Some(id) => id
      None => return Err(ConstructError::UnknownState(rule.from_state))
    }

    // 校验 to_state 是否存在
    let to_idx = match to_id {
      Some(id) => id
      None => return Err(ConstructError::UnknownState(rule.to_state))
    }

    // 校验 on_event 是否存在
    let on_idx = match on_id {
      Some(id) => id
      None => return Err(ConstructError::UnknownEvent(rule.on_event))
    }

    // 校验 action 是否存在（如果是 Some）
    let mut action_name = None
    match rule.action {
      Some(name) =>
        match actions.get(name) {
          Some(action_def) => {
            // 校验 action.emits 中的每个 effect 是否存在
            for emit_name in action_def.emits {
              if effects.get(emit_name).is_none() {
                return Err(ConstructError::UnknownEffect(name, emit_name))
              }
            }
            action_name = Some(name)
          }
          None => return Err(ConstructError::UnknownAction(name))
        }
      None => ()
    }

    // 添加转移到 IR
    ir = ir.add_transition(
      from_idx,
      to_idx,
      on_idx,
      guard_def=rule.guard_def,
      action=action_name,
    )
  }

  Ok(ir)
}

// ============================================================
// 辅助函数：数组形式的构建
// ============================================================

///|
/// 从数组构建 FSM（直接构建，不做校验，用于测试）
pub fn construct_from_arrays(
  states : Array[String],
  events : Array[String],
  rules : Array[TransitionRule],
) -> Result[FsmIR, ConstructError] {
  let mut ir = FsmIR::new()

  // 添加所有事件到 IR
  for i = 0; i < events.length(); i = i + 1 {
    let (new_ir, _) = ir.add_event(events[i])
    ir = new_ir
  }

  // 添加所有状态到 IR
  for i = 0; i < states.length(); i = i + 1 {
    let (new_ir, _) = ir.add_state(states[i], is_initial=i == 0)
    ir = new_ir
  }

  // 添加转移规则到 IR（不做校验）
  for rule in rules {
    let from_id = ir.state_index.get(rule.from_state)
    let to_id = ir.state_index.get(rule.to_state)
    let on_id = ir.event_index.get(rule.on_event)
    match (from_id, to_id, on_id) {
      (Some(fid), Some(tid), Some(eid)) =>
        ir = ir.add_transition(
          fid,
          tid,
          eid,
          guard_def=rule.guard_def,
          action=rule.action,
        )
      _ => ()
    }
  }

  Ok(ir)
}

// ============================================================
// 辅助函数：简单的 (from, on, to) 三元组构建
// ============================================================

///|
/// 简化版构建：不带 action 和 guard
pub fn construct_simple(
  states : Array[String],
  events : Array[String],
  transitions : Array[(String, String, String)], // (from, on, to)
) -> Result[FsmIR, ConstructError] {
  let rules = transitions.map(fn(t) {
    let (from, on, to) = t
    TransitionRule::{
      from_state: from,
      on_event: on,
      to_state: to,
      guard_def: None,
      action: None,
    }
  })

  construct_from_arrays(states, events, rules)
}

// ============================================================
// 测试
// ============================================================

///|
test {
  // 测试 TransitionRule 基本创建
  let rule = TransitionRule::{
    from_state: "idle",
    on_event: "start",
    to_state: "running",
    guard_def: None,
    action: None,
  }

  assert_eq(rule.from_state, "idle")
  assert_eq(rule.on_event, "start")
  assert_eq(rule.to_state, "running")
}

///|
test {
  // 测试带 action 名称的 TransitionRule
  let rule = TransitionRule::{
    from_state: "ExpectSubject",
    on_event: "Iri",
    to_state: "ExpectPredicate",
    guard_def: None,
    action: Some("set_subject"),
  }

  assert_eq(rule.action, Some("set_subject"))
}

///|
test {
  // 测试带 GuardDef 的 TransitionRule
  let rule = TransitionRule::{
    from_state: "idle",
    on_event: "start",
    to_state: "running",
    guard_def: Some(GuardDef::{
      name: "count_check",
      expression: Some("count > 0"),
    }),
    action: None,
  }

  match rule.guard_def {
    Some(g) => {
      assert_eq(g.name, "count_check")
      assert_eq(g.expression, Some("count > 0"))
    }
    None => fail("Expected guard_def")
  }
}

///|
test {
  // 测试 construct_simple 基本功能
  let states = ["idle", "running", "paused"]
  let events = ["start", "stop", "pause", "resume"]
  let transitions = [
    ("idle", "start", "running"),
    ("running", "stop", "idle"),
    ("running", "pause", "paused"),
    ("paused", "resume", "running"),
  ]

  let ir = construct_simple(states, events, transitions).unwrap()

  assert_eq(ir.states.length(), 3)
  assert_eq(ir.events.length(), 4)
  assert_eq(ir.transitions.length(), 4)

  // 验证初始状态（第一个添加的是 idle）
  assert_true(ir.states[0].is_initial)
  assert_eq(ir.states[0].name, "idle")
}

///|
test {
  // 测试带 action 的完整构建
  let states_map = Map([])
  states_map.set("idle", StateDef::{
    id: 0,
    name: "idle",
    is_initial: true,
    is_nestable: false,
    parent: None,
    exit_event: None,
    data_fields: [],
    metadata: Map([]),
  })

  let events_map = Map([])
  events_map.set("start", EventDef::{
    id: 0,
    name: "start",
    payload: [],
    metadata: Map([]),
  })
  events_map.set("stop", EventDef::{
    id: 1,
    name: "stop",
    payload: [],
    metadata: Map([]),
  })

  let actions_map = Map([])
  actions_map.set("log_start", ActionDef::{
    name: "log_start",
    params: [],
    emits: ["Continue"],
  })

  let effects_map = Map([])
  effects_map.set("Continue", EffectDef::{
    name: "Continue",
    payload: [],
    doc: None,
  })

  let rules = [
    TransitionRule::{
      from_state: "idle",
      on_event: "start",
      to_state: "idle",
      guard_def: None,
      action: Some("log_start"),
    },
  ]

  let ir = match
    construct(states_map, events_map, rules, actions_map, effects_map) {
    Ok(ir) => ir
    Err(_e) => fail("construct failed")
  }

  assert_eq(ir.transitions.length(), 1)
  match ir.transitions[0].action {
    Some(name) => assert_eq(name, "log_start")
    None => fail("Expected action")
  }
}

///|
test {
  // 测试 UnknownState 错误
  let states_map = Map([])
  states_map.set("idle", StateDef::{
    id: 0,
    name: "idle",
    is_initial: true,
    is_nestable: false,
    parent: None,
    exit_event: None,
    data_fields: [],
    metadata: Map([]),
  })

  let events_map = Map([])
  events_map.set("start", EventDef::{
    id: 0,
    name: "start",
    payload: [],
    metadata: Map([]),
  })

  let rules = [
    TransitionRule::{
      from_state: "undefined_state", // 不存在的状态
      on_event: "start",
      to_state: "idle",
      guard_def: None,
      action: None,
    },
  ]

  let result = construct(states_map, events_map, rules, Map([]), Map([]))
  match result {
    Err(ConstructError::UnknownState(s)) => assert_eq(s, "undefined_state")
    _ => fail("Expected UnknownState error")
  }
}

///|
test {
  // 测试 UnknownAction 错误
  let states_map = Map([])
  states_map.set("idle", StateDef::{
    id: 0,
    name: "idle",
    is_initial: true,
    is_nestable: false,
    parent: None,
    exit_event: None,
    data_fields: [],
    metadata: Map([]),
  })

  let events_map = Map([])
  events_map.set("start", EventDef::{
    id: 0,
    name: "start",
    payload: [],
    metadata: Map([]),
  })

  let actions_map = Map([]) // 空 map，不包含任何 action

  let effects_map = Map([])

  let rules = [
    TransitionRule::{
      from_state: "idle",
      on_event: "start",
      to_state: "idle",
      guard_def: None,
      action: Some("undefined_action"), // 不存在的 action
    },
  ]

  let result = construct(
    states_map, events_map, rules, actions_map, effects_map,
  )
  match result {
    Err(ConstructError::UnknownAction(s)) => assert_eq(s, "undefined_action")
    _ => fail("Expected UnknownAction error")
  }
}

///|
test {
  // 测试 UnknownEffect 错误
  let states_map = Map([])
  states_map.set("idle", StateDef::{
    id: 0,
    name: "idle",
    is_initial: true,
    is_nestable: false,
    parent: None,
    exit_event: None,
    data_fields: [],
    metadata: Map([]),
  })

  let events_map = Map([])
  events_map.set("start", EventDef::{
    id: 0,
    name: "start",
    payload: [],
    metadata: Map([]),
  })

  let actions_map = Map([])
  actions_map.set("do_something", ActionDef::{
    name: "do_something",
    params: [],
    emits: ["NonExistentEffect"], // 不存在的 effect
  })

  let effects_map = Map([]) // 空 map，不包含任何 effect

  let rules = [
    TransitionRule::{
      from_state: "idle",
      on_event: "start",
      to_state: "idle",
      guard_def: None,
      action: Some("do_something"),
    },
  ]

  let result = construct(
    states_map, events_map, rules, actions_map, effects_map,
  )
  match result {
    Err(ConstructError::UnknownEffect(a, e)) => {
      assert_eq(a, "do_something")
      assert_eq(e, "NonExistentEffect")
    }
    _ => fail("Expected UnknownEffect error")
  }
}

///|
/// Context 业务字段定义（来自 TOML [context] / [[context]]）
pub(all) struct ContextField {
  name : String // 字段名
  type_ : String // 类型（"Span?"、"Int" 等）
  default : String? // 显式默认值（MoonBit 代码字符串）
} derive(Debug)

///|
/// Context 定义（来自 TOML [context]）
pub(all) struct ContextDef {
  struct_name : String // 生成结构体名；空串表示未声明（codegen 用带前缀默认值）
  fields : Array[ContextField] // 业务字段
} derive(Debug)

///|
/// TOML 解析后的 [meta] 定义
pub(all) struct MetaDef {
  name : String // 状态机名称（prefix 未声明时的派生来源）
  version : String // 配置版本
  description : String? // 描述
  trait_name : String? // Actions trait 名；缺省 "{prefix}Actions"
  default_effect : String? // 无 action 转移的默认 Effect 变体；缺省 "Continue"
  prefix : String // 生成代码命名空间前缀（显式声明或从 name 派生，已清洗为 PascalCase）
  terminal_states : Array[String] // 终止状态列表（路径分析用；缺省 []，此时无出边状态按死状态报告）
} derive(Debug)

///|
/// Actions trait 名：显式声明 > "{prefix}Actions" > "Actions"
pub fn MetaDef::trait_or_default(self : MetaDef) -> String {
  match self.trait_name {
    Some(name) if name != "" => name
    _ => if self.prefix != "" { "\{self.prefix}Actions" } else { "Actions" }
  }
}

///|
/// 默认 Effect 变体名：显式声明 > "Continue"
pub fn MetaDef::effect_or_default(self : MetaDef) -> String {
  match self.default_effect {
    Some(name) if name != "" => name
    _ => "Continue"
  }
}

///|
/// 清洗为 PascalCase 标识符前缀：剔除特殊字符（非字母数字），
/// 以特殊字符为分界逐段首字母大写，并丢弃前导数字。
/// "nquads_parser" -> "NquadsParser"；"NQuads" -> "NQuads"；"my-fsm v2" -> "MyFsmV2"
fn sanitize_to_pascal(raw : String) -> String {
  let buf = StringBuilder::new()
  let mut cap_next = true // 段首（或特殊字符之后）的字母需要大写
  let mut started = false
  for i = 0; i < raw.length(); i = i + 1 {
    let ch = raw[i]
    let is_lower = ch >= 'a' && ch <= 'z'
    let is_upper = ch >= 'A' && ch <= 'Z'
    let is_digit = ch >= '0' && ch <= '9'
    if !(is_lower || is_upper || is_digit) {
      cap_next = true // 特殊字符：丢弃，并标记下一段首字母大写
      continue
    }
    if !started && is_digit {
      continue // 前导数字不是合法标识符开头，丢弃
    }
    if cap_next && is_lower {
      buf.write("\{(ch - 32).to_char().unwrap()}")
    } else {
      buf.write("\{ch.to_char().unwrap()}")
    }
    started = true
    cap_next = false
  }
  buf.to_string()
}

///|
test {
  // sanitize_to_pascal：剔除特殊字符并分段大写
  assert_eq(sanitize_to_pascal("nquads_parser"), "NquadsParser")
  assert_eq(sanitize_to_pascal("NQuads"), "NQuads")
  assert_eq(sanitize_to_pascal("my-fsm v2"), "MyFsmV2")
  assert_eq(sanitize_to_pascal("2nd_gen!"), "NdGen")
  assert_eq(sanitize_to_pascal(""), "")
}

///|
test {
  // MetaDef：前缀派生与 trait / 默认 effect 兜底
  let meta = MetaDef::{
    name: "nquads_parser",
    version: "0.1.0",
    description: None,
    trait_name: None,
    default_effect: None,
    prefix: sanitize_to_pascal("nquads_parser"),
    terminal_states: [],
  }
  assert_eq(meta.prefix, "NquadsParser")
  assert_eq(meta.trait_or_default(), "NquadsParserActions")
  assert_eq(meta.effect_or_default(), "Continue")
  let explicit = MetaDef::{
    ..meta,
    trait_name: Some("NQuadsActions"),
    default_effect: Some("Done"),
  }
  assert_eq(explicit.trait_or_default(), "NQuadsActions")
  assert_eq(explicit.effect_or_default(), "Done")
}
