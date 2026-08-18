// ===== FSM Code Generator =====
// 本模块将 FsmIR 转换为可编译的 MoonBit 代码
//
// 生成的驱动函数契约：
//   pub fn step(ctx, event, actions) -> Result[(Context, Effect), Error]
// - ctx 提供状态（Context 携带当前状态）
// - event 提供数据（Event 枚举）
// - actions 提供逻辑（trait 方法，直接调用，无字符串匹配）
// - 返回值：状态变更（新 Context）与副作用意图（Effect）分开返回
//
// 两层设计：
// 第一层 Actions（step 内部）：业务逻辑，更新 Context，返回 Effect 意图
// 第二层 EffectHandler（step 外部）：调度器拿到 (new_ctx, effect) 后，
//   调用 handler.dispatch(effect)（trait 默认方法）match effect 并执行副作用

///|
/// 配置选项
pub(all) struct CodegenConfig {
  debug : Bool // 是否生成调试日志
  output_module : String // 输出模块名
  name_prefix : String // 命名前缀，防止冲突
  trait_name : String // 生成的 Actions trait 名称
  actions : Array[ActionDef]? // 可选：action 定义列表
  effects : Array[EffectDef]? // 可选：effect 定义列表
  context : ContextDef? // 可选：Context 定义（TOML [context]，含结构体名与业务字段）
}

///|
pub fn CodegenConfig::default() -> CodegenConfig {
  CodegenConfig::{
    trait_name: "Actions",
    debug: false,
    output_module: "fsm_gen",
    name_prefix: "",
    actions: None,
    effects: None,
    context: None,
  }
}

///|
pub fn CodegenConfig::with_prefix(prefix : String) -> CodegenConfig {
  CodegenConfig::{
    trait_name: "Actions",
    debug: false,
    output_module: "fsm_gen",
    name_prefix: prefix,
    actions: None,
    effects: None,
    context: None,
  }
}

///|
/// 生成类型的命名空间前缀（PascalCase；空串 = 不加前缀）
/// 借用 sanitize_to_pascal 清洗："test_fsm" -> "TestFsm"（而非仅首字母大写的 "Test_fsm"）
fn type_prefix(config : CodegenConfig) -> String {
  sanitize_to_pascal(config.name_prefix)
}

///|
/// 生成类型名加命名空间前缀：prefix 为空时保持原名。
/// 如 prefix = "NQuads" 时 prefixed_type(config, "Event") -> "NQuadsEvent"
pub fn prefixed_type(config : CodegenConfig, base : String) -> String {
  let prefix = type_prefix(config)
  if prefix == "" {
    base
  } else {
    "\{prefix}\{base}"
  }
}

///|
/// 类型字符串中的生成类型保留名（整词匹配）→ 带前缀版本。
/// "State" -> "NQuadsState"；"Span?"、"QuadSpan" 等业务类型不受影响
fn rewrite_word(prefix : String, word : String) -> String {
  if word == "State" ||
    word == "Event" ||
    word == "Effect" ||
    word == "ActionError" ||
    word == "EffectError" {
    "\{prefix}\{word}"
  } else {
    word
  }
}

///|
/// 改写类型字符串：按字母数字分词，逐词套用保留名前缀化，
/// "?"、括号、逗号等分隔符原样保留。如 "(State, Event?)" -> "(NQuadsState, NQuadsEvent?)"
pub fn rewrite_type(config : CodegenConfig, type_ : String) -> String {
  let prefix = type_prefix(config)
  if prefix == "" {
    return type_
  }
  let out = StringBuilder::new()
  let mut word = ""
  for i = 0; i < type_.length(); i = i + 1 {
    let ch = type_[i]
    let is_alnum = (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9')
    if is_alnum {
      word = word + "\{ch.to_char().unwrap()}"
    } else {
      out.write(rewrite_word(prefix, word))
      word = ""
      out.write("\{ch.to_char().unwrap()}")
    }
  }
  out.write(rewrite_word(prefix, word))
  out.to_string()
}

///|
test {
  // rewrite_type：仅整词替换生成类型保留名，业务类型不受影响
  let config = CodegenConfig::with_prefix("NQuads")
  assert_eq(rewrite_type(config, "Span"), "Span")
  assert_eq(rewrite_type(config, "Span?"), "Span?")
  assert_eq(rewrite_type(config, "State"), "NQuadsState")
  assert_eq(
    rewrite_type(config, "(State, Event?)"),
    "(NQuadsState, NQuadsEvent?)",
  )
  assert_eq(rewrite_type(config, "QuadSpan"), "QuadSpan")
  // 无前缀：原样返回
  assert_eq(rewrite_type(CodegenConfig::default(), "State"), "State")
}

///|
/// 主生成函数
pub fn codegen(ir : FsmIR, config : CodegenConfig) -> String {
  generate(ir, config)
}

///|
/// 格式化事件名称（添加前缀防止冲突）
pub fn format_event_name(name : String, prefix : String) -> String {
  sanitize_to_pascal(prefix) + to_pascal_case(name)
}

///|
/// 格式化状态名称（添加前缀防止冲突）
pub fn format_state_name(name : String, prefix : String) -> String {
  sanitize_to_pascal(prefix) + to_pascal_case(name)
}

///|
/// 主生成函数
pub fn generate(ir : FsmIR, config : CodegenConfig) -> String {
  let header = emit_header(config.output_module)
  let token_enum = emit_token_enum(ir, config)
  let state_enum = emit_state_enum(ir, config)
  let effect_enum = match config.effects {
    Some(effects) => emit_effect_enum(effects, config)
    None => emit_default_effect_enum(config)
  }
  let context = emit_context(ir, config)
  let error_enum = emit_error_enum(config)
  let actions_trait = emit_actions_trait(ir, config)
  let step_fn = emit_step_fn(ir, config)

  // 组装所有部分
  let full_code = StringBuilder::new()
  full_code.write(header)
  full_code <+ "\n\n"
  full_code.write(token_enum)
  full_code <+ "\n\n"
  full_code.write(state_enum)
  full_code <+ "\n\n"
  full_code.write(effect_enum)
  full_code <+ "\n\n"
  full_code.write(context)
  full_code <+ "\n\n"
  full_code.write(error_enum)
  full_code <+ "\n\n"
  full_code.write(actions_trait)
  full_code <+ "\n\n"
  full_code.write(step_fn)

  // 第二层：EffectHandler 模板（step 外部真正的 match effect 分发）
  match config.effects {
    Some(effects) if !effects.is_empty() => {
      let effect_error = emit_effect_error_enum(config)
      let handler_trait = emit_effect_handler_trait(effects, config)
      full_code <+ "\n\n"
      full_code.write(effect_error)
      full_code <+ "\n\n"
      full_code.write(handler_trait)
    }
    _ => ()
  }

  if config.debug {
    let debug_helpers = emit_debug_helpers(ir, config)
    full_code <+ "\n\n"
    full_code.write(debug_helpers)
  }

  full_code.to_string()
}

///|
/// 生成头部注释
fn emit_header(module_name : String) -> String {
  let timestamp = @env.now()

  let header =
    $|// ========================================
    $|// Generated by FSM Code Generator
    $|// Module: \{module_name}
    $|// Generated at: \{timestamp}
    $|// DO NOT EDIT MANUALLY
    $|// ========================================
  header
}

///|
/// 事件载荷的类型签名：
/// - 无载荷 → 裸变体 Dot
/// - 单字段 → Iri(Span)
/// - 多字段 → Pair(A, B)
pub fn event_payload_type(event : EventDef) -> String? {
  match event.payload.length() {
    0 => None
    1 => Some(event.payload[0].type_)
    n => {
      let types = event.payload.map(fn(f) { f.type_ })
      let tuple = "(\{types.join(", ")})"
      ignore(n)
      Some(tuple)
    }
  }
}

///|
/// action 方法的参数形态（action 可由多个事件触发，需统一参数类型）
pub enum ActionParam {
  NoParam // (Self, Context)
  Payload(String) // (Self, Context, T) — 触发事件载荷类型一致
  WholeEvent // (Self, Context, Event) — 载荷不一致时退化为整个事件
}

///|
/// 计算 action 方法的参数形态
/// action 可由多个事件触发：载荷类型完全一致 → Payload，否则退化为 WholeEvent
pub fn action_param_type(ir : FsmIR, action : String) -> ActionParam {
  // None 表示尚未见到任何触发转移，首个候选直接采纳
  let mut param : ActionParam? = None

  for t in ir.transitions {
    if t.action == Some(action) {
      let payload = event_payload_type(ir.events[t.on_event])
      let candidate : ActionParam = match payload {
        Some(type_) => Payload(type_)
        None => NoParam
      }
      param = match (param, candidate) {
        (None, c) => Some(c)
        (Some(NoParam), NoParam) => Some(NoParam)
        (Some(Payload(a)), Payload(b)) if a == b => Some(Payload(a))
        _ => return WholeEvent // 载荷形态冲突，退化为整个事件
      }
    }
  }

  param.unwrap_or(NoParam)
}

///|
/// 生成事件枚举（带载荷变体）
fn emit_token_enum(ir : FsmIR, config : CodegenConfig) -> String {
  let code = StringBuilder::new()

  code <+ "///|\n"
  code <+ "pub(all) enum \{prefixed_type(config, "Event")} {\n"

  for i = 0; i < ir.events.length(); i = i + 1 {
    let name = format_event_name(ir.events[i].name, config.name_prefix)
    let pascal_name = to_pascal_case(name)
    code <+ "  "
    code.write(pascal_name)
    match event_payload_type(ir.events[i]) {
      Some(type_) => code <+ "(\{rewrite_type(config, type_)})"
      None => ()
    }
    if i < ir.events.length() - 1 {
      code <+ "\n"
    }
  }

  code <+ "\n}\n"

  code.to_string()
}

///|
/// 生成状态枚举
fn emit_state_enum(ir : FsmIR, config : CodegenConfig) -> String {
  let code = StringBuilder::new()

  code <+ "///|\n"
  code <+ "pub(all) enum \{prefixed_type(config, "State")} {\n"

  for i = 0; i < ir.states.length(); i = i + 1 {
    let name = format_state_name(ir.states[i].name, config.name_prefix)
    let pascal_name = to_pascal_case(name)
    code <+ "  "
    code.write(pascal_name)
    if i < ir.states.length() - 1 {
      code <+ "\n"
    }
  }

  code <+ "\n}\n"

  code.to_string()
}

///|
/// Context 结构体类型名：TOML 显式 struct_name > 带前缀默认 "{prefix}Context"
pub fn context_type(config : CodegenConfig) -> String {
  match config.context {
    Some(def) if def.struct_name != "" => def.struct_name
    _ => prefixed_type(config, "Context")
  }
}

///|
/// 初始状态名（生成代码中的变体名）：优先 is_initial，退回首个状态
fn initial_state_name(ir : FsmIR, config : CodegenConfig) -> String? {
  let mut found : String? = None
  for state in ir.states {
    if state.is_initial {
      found = Some(format_state_name(state.name, config.name_prefix))
      break
    }
  }
  if found.is_none() && ir.states.length() > 0 {
    found = Some(format_state_name(ir.states[0].name, config.name_prefix))
  }
  found
}

///|
/// Context 字段在 ::new 中的默认值：
/// TOML 显式 default > `?` 后缀 → None > 基础类型字面量
fn context_field_default(field : ContextField) -> String {
  match field.default {
    Some(d) => d
    None => {
      let t = field.type_
      let n = t.length()
      if n > 0 && t[n - 1] == '?' {
        "None"
      } else {
        match t {
          "Int" => "0"
          "Double" => "0.0"
          "Bool" => "false"
          "String" => "\"\""
          _ => "None // TODO: 该类型无默认值，请手工补"
        }
      }
    }
  }
}

///|
/// 生成 Context 结构体（state + TOML 声明的业务字段）、::new、with_state、transition
fn emit_context(ir : FsmIR, config : CodegenConfig) -> String {
  let ctx = context_type(config)
  let fields = match config.context {
    Some(def) => def.fields
    None => []
  }

  let code = StringBuilder::new()
  code <+ "///|\n"
  code <+
    "/// FSM 运行时上下文：ctx 提供状态（state）与业务数据（其余字段）\n"
  code <+ "pub(all) struct \{ctx} {\n"
  code <+ "  state : \{prefixed_type(config, "State")}\n"
  for field in fields {
    code <+ "  \{field.name} : \{rewrite_type(config, field.type_)}\n"
  }
  code <+ "}\n\n"

  // ::new：state 置初始状态，业务字段取默认值（存在状态时才生成）
  match initial_state_name(ir, config) {
    Some(initial) => {
      code <+ "///|\n"
      code <+ "/// 状态机初始上下文\n"
      code <+ "pub fn \{ctx}::new() -> \{ctx} {\n"
      code <+ "  { state: \{initial}"
      for field in fields {
        code <+ ", \{field.name}: \{context_field_default(field)}"
      }
      code <+ " }\n"
      code <+ "}\n\n"
    }
    None => ()
  }

  code <+ "///|\n"
  code <+
    "/// 返回携带新状态的上下文（状态变更的唯一入口）\n"
  code <+
    "fn with_state(ctx : \{ctx}, state : \{prefixed_type(config, "State")}) -> \{ctx} {\n"
  code <+ "  { ..ctx, state }\n"
  code <+ "}\n\n"
  code <+ "///|\n"
  code <+
    "/// 状态转移（控制流）：将 action 返回的新上下文打上转移声明的目标状态标签\n"
  code <+ "fn transition(\n"
  code <+
    "  result : Result[(\{ctx}, \{prefixed_type(config, "Effect")}), \{prefixed_type(config, "ActionError")}],\n"
  code <+ "  state : \{prefixed_type(config, "State")},\n"
  code <+
    ") -> Result[(\{ctx}, \{prefixed_type(config, "Effect")}), \{prefixed_type(config, "ActionError")}] {\n"
  code <+ "  match result {\n"
  code <+ "    Ok((c, e)) => Ok((with_state(c, state), e))\n"
  code <+ "    Err(err) => Err(err)\n"
  code <+ "  }\n"
  code <+ "}\n"
  code.to_string()
}

///|
/// 生成错误枚举（注：MoonBit 保留类型名 Error，故命名为 ActionError）
fn emit_error_enum(config : CodegenConfig) -> String {
  let code = StringBuilder::new()
  code <+ "///|\n"
  code <+ "/// Action 执行或状态转移阶段的错误\n"
  code <+ "pub(all) enum \{prefixed_type(config, "ActionError")} {\n"
  code <+
    "  UnexpectedEvent(\{prefixed_type(config, "State")}, \{prefixed_type(config, "Event")}) // 状态机引擎抛出：当前状态未定义该事件的转移\n"
  code <+
    "  BusinessFailed(String) // 用户业务逻辑抛出：Action 执行失败（如解析格式错误）\n"
  code <+ "}\n"
  code.to_string()
}

///|
/// 收集转移中使用的 action 名称（按首次出现顺序去重）
pub fn collect_action_names(ir : FsmIR) -> Array[String] {
  let names : Array[String] = []

  for t in ir.transitions {
    match t.action {
      Some(name) => if !names.contains(name) { names.push(name) }
      None => ()
    }
  }

  names
}

///|
/// 生成 Actions trait：每个 action 一个方法，直接调用（无字符串匹配）
/// action 只负责「读 ctx → 结构体更新写回新 ctx → 计算 Effect 意图」，
/// 不执行副作用（Effect 由外部 EffectHandler 执行），也不改状态（由 step 应用 with_state）
fn emit_actions_trait(ir : FsmIR, config : CodegenConfig) -> String {
  let actions = collect_action_names(ir)
  let ctx = context_type(config)
  let event_t = prefixed_type(config, "Event")
  let effect_t = prefixed_type(config, "Effect")
  let err_t = prefixed_type(config, "ActionError")

  let code = StringBuilder::new()
  code <+ "///|\n"
  code <+
    "/// Actions trait：actions 提供逻辑，Self 携带运行时数据\n"
  code <+
    "/// 每个方法：(ctx, 事件载荷) → (新 ctx, 副作用意图) 或错误\n"
  code <+ "pub trait \{config.trait_name} {\n"
  for name in actions {
    let params = match action_param_type(ir, name) {
      NoParam => "(Self, \{ctx})"
      Payload(type_) => "(Self, \{ctx}, \{rewrite_type(config, type_)})"
      WholeEvent => "(Self, \{ctx}, \{event_t})"
    }
    code <+ "  \{name}\{params} -> Result[(\{ctx}, \{effect_t}), \{err_t}]\n"
  }
  code <+ "}\n"
  code.to_string()
}

///|
/// 无 action 转移的默认副作用意图：
/// - TOML 声明了 effects → 优先名为 "Continue" 的变体，否则首个无载荷变体
/// - 未声明 → 默认枚举的 Continue
pub fn default_effect_name(config : CodegenConfig) -> String {
  match config.effects {
    Some(effects) => {
      let has_continue = effects.any(fn(e) { e.name == "Continue" })
      if has_continue {
        "Continue"
      } else {
        let first_bare = effects.filter(fn(e) { e.payload.is_empty() })
        if first_bare.length() > 0 {
          first_bare[0].name
        } else {
          "Continue" // 全部带载荷时退回 Continue（生成后按需调整）
        }
      }
    }
    None => "Continue"
  }
}

///|
/// 生成 step 驱动函数：match (state, event) 解构载荷并直接调用 trait 方法
fn emit_step_fn(ir : FsmIR, config : CodegenConfig) -> String {
  let default_effect = default_effect_name(config)
  let ctx = context_type(config)
  let effect_t = prefixed_type(config, "Effect")
  let err_t = prefixed_type(config, "ActionError")
  let code = StringBuilder::new()
  code <+ "///|\n"
  code <+
    "/// FSM Driver：接收事件，返回 (新上下文, 副作用意图) 或错误\n"
  code <+ "/// ctx 提供状态，event 提供数据，actions 提供逻辑\n"
  code <+ "pub fn[A : \{config.trait_name}] step(\n"
  code <+ "  ctx : \{ctx},\n"
  code <+ "  event : \{prefixed_type(config, "Event")},\n"
  code <+ "  actions : A,\n"
  code <+ ") -> Result[(\{ctx}, \{effect_t}), \{err_t}] {\n"
  code <+ "  match (ctx.state, event) {\n"

  for t in ir.transitions {
    let from_name = format_state_name(
      ir.states[t.from_state].name,
      config.name_prefix,
    )
    let event_def = ir.events[t.on_event]
    let event_name = format_event_name(event_def.name, config.name_prefix)
    let to_name = format_state_name(
      ir.states[t.to_state].name,
      config.name_prefix,
    )

    // debug 日志（作为臂前注释）
    if config.debug {
      code <+ "    // [FSM] \{from_name} --[\{event_name}]--> \{to_name}\n"
    }

    // match 臂：action 消费载荷时解构 (State, Event(payload))，否则用裸/忽略模式
    let has_payload = event_payload_type(event_def).is_some()
    match t.action {
      Some(action) => {
        let param = action_param_type(ir, action)
        let (pattern, arg) = match (param, has_payload) {
          (Payload(_), true) =>
            ("(\{from_name}, \{event_name}(payload))", "ctx, payload")
          (Payload(_), false) =>
            // 理论不可达（action 期待载荷但事件无载荷），退化传整个事件
            ("(\{from_name}, \{event_name})", "ctx, event")
          (WholeEvent, true) =>
            ("(\{from_name}, \{event_name}(_))", "ctx, event")
          (WholeEvent, false) => ("(\{from_name}, \{event_name})", "ctx, event")
          (NoParam, true) => ("(\{from_name}, \{event_name}(_))", "ctx")
          (NoParam, false) => ("(\{from_name}, \{event_name})", "ctx")
        }
        // 直接调用 trait 方法；声明的目标状态由 transition（控制流）应用
        code <+
          "    \{pattern} => transition(actions.\{action}(\{arg}), \{to_name})\n"
      }
      None => {
        let pattern = if has_payload {
          "(\{from_name}, \{event_name}(_))"
        } else {
          "(\{from_name}, \{event_name})"
        }
        code <+
          "    \{pattern} => Ok((with_state(ctx, \{to_name}), \{effect_t}::\{default_effect}))\n"
      }
    }
  }

  // 兜底：结构化错误而非 panic
  code <+ "    (_, _) => Err(\{err_t}::UnexpectedEvent(ctx.state, event))\n"

  code <+ "  }\n"
  code <+ "}\n"

  code.to_string()
}

///|
/// 生成调试辅助函数
fn emit_debug_helpers(ir : FsmIR, config : CodegenConfig) -> String {
  let code = StringBuilder::new()

  // state_name 函数
  code.write("///|\n")
  code.write(
    "pub fn state_name(state: \{prefixed_type(config, "State")}) -> String {\n",
  )
  code.write("  match state {\n")

  for state in ir.states {
    // 变体名与 emit_state_enum 一致（含命名空间前缀）
    let variant = format_state_name(state.name, config.name_prefix)
    code <+ "    "
    code.write(variant)
    code <+ " => \""
    code.write(state.name)
    code <+ "\"\n"
  }

  code <+ "  }\n"
  code <+ "}\n\n"

  // event_name 函数（带载荷的变体需用 _ 模式匹配）
  code <+ "///|\n"
  code <+
    "pub fn event_name(event: \{prefixed_type(config, "Event")}) -> String {\n"
  code <+ "  match event {\n"
  for event in ir.events {
    // 变体名与 emit_token_enum 一致（含命名空间前缀）
    let variant = format_event_name(event.name, config.name_prefix)
    let pattern = match event_payload_type(event) {
      Some(_) => "\{variant}(_)"
      None => variant
    }
    code <+ "    \{pattern} => \"\{event.name}\"\n"
  }

  code <+ "  }\n"
  code <+ "}\n"

  code.to_string()
}

///|
/// 转换为 PascalCase
fn to_pascal_case(name : String) -> String {
  // 如果已经是 PascalCase，直接返回
  if name.length() > 0 {
    let first_char = name[0]
    if first_char >= 'A' && first_char <= 'Z' {
      return name
    }
  }

  // 将首字母转为大写
  let mut result = name
  if result.length() > 0 {
    let first = result[0]
    let upper = (first - 32).to_char().unwrap() // 小写转大写
    result = "\{upper}" + result[1:result.length()].to_owned()
  }
  result
}

// ///| 构建状态 ID → 名称映射
// fn build_state_id_map(ir: FsmIR) -> Map[Int, String] {
//   let  map = Map([])
//   for state in ir.states {
//     map.set(state.id, state.name)
//   }
//   map
// }

// ///| 构建事件 ID → 名称映射
// fn build_event_id_map(ir: FsmIR) -> Map[Int, String] {
//   let  map = Map([])
//   for event in ir.events {
//     map.set(event.id, event.name)
//   }
//   map
// }

///|
async test {
  // 测试基本代码生成
  let toml_content = @fs.read_file("./src/fsm/test.toml").text()
  let result = parse_toml(toml_content)
  guard result is Ok(ir) else { fail("Failed to parse TOML") }

  let config = CodegenConfig::default()
  let code = generate(ir, config)
  debug(code)
  // 验证生成代码包含必要元素
  assert_true(code.contains("pub(all) enum Event"))
  assert_true(code.contains("pub(all) enum State"))
  assert_true(code.contains("] step("))
  assert_true(code.contains("Idle"))
  assert_true(code.contains("Running"))
}

///|
async test {
  // 测试 debug 模式
  let toml_content = @fs.read_file("./src/fsm/test.toml").text()
  let result = parse_toml(toml_content)
  guard result is Ok(ir) else { fail("Failed to parse TOML") }

  let config = CodegenConfig::{
    trait_name: "Actions",
    debug: true,
    output_module: "test_debug",
    name_prefix: "test_",
    actions: None,
    effects: None,
    context: None,
  }
  let code = generate(ir, config)

  // 验证 debug 标记存在
  assert_true(code.contains("// [FSM]"))
  assert_true(code.contains("pub fn state_name"))
  assert_true(code.contains("pub fn event_name"))
}

///|
test {
  // 测试空状态机
  let ir = FsmIR::new()
  let config = CodegenConfig::default()
  let code = generate(ir, config)

  // 空状态机也应该生成有效代码
  assert_true(code.contains("pub(all) enum Event"))
  assert_true(code.contains("pub(all) enum State"))
  assert_true(code.contains("] step("))
}

///|
async test {
  // 测试带 action 的状态机
  let ir = FsmIR::new()
  let (ir, start_id) = ir.add_event("start")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, running_id) = ir.add_state("running")
  let ir = ir.add_transition(
    idle_id,
    running_id,
    start_id,
    action=Some("on_start"),
  )

  let config = CodegenConfig::default()
  let code = generate(ir, config)

  // 验证 action 生成为 trait 方法，match 臂直接调用（无字符串匹配）
  assert_true(
    code.contains(
      "on_start(Self, Context) -> Result[(Context, Effect), ActionError]",
    ),
  )
  assert_true(code.contains("actions.on_start(ctx)"))
  assert_false(code.contains("dispatch_action"))
}

///|
test {
  // 前缀命名空间：所有生成类型名统一加前缀（Event/State/Effect/ActionError/Context）
  let ir = FsmIR::new()
  let (ir, iri_id) = ir.add_event("Iri", payload=[
    PayloadField::{ name: "iri", type_: "Span" },
  ])
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, done_id) = ir.add_state("done")
  let ir = ir.add_transition(idle_id, done_id, iri_id, action=Some("go"))

  let config = CodegenConfig::{
    trait_name: "MyActions",
    debug: true,
    output_module: "my_fsm",
    name_prefix: "My",
    actions: None,
    effects: None,
    context: None,
  }
  let code = generate(ir, config)

  // 类型名前缀化
  assert_true(code.contains("pub(all) enum MyEvent"))
  assert_true(code.contains("pub(all) enum MyState"))
  assert_true(code.contains("pub(all) enum MyEffect"))
  assert_true(code.contains("pub(all) enum MyActionError"))
  assert_true(code.contains("pub(all) struct MyContext {"))
  // 变体名前缀化
  assert_true(code.contains("MyIri(Span)"))
  assert_true(code.contains("state: MyIdle"))
  // step / trait 签名前缀化
  assert_true(code.contains("pub fn[A : MyActions] step("))
  assert_true(code.contains("event : MyEvent,"))
  assert_true(code.contains("-> Result[(MyContext, MyEffect), MyActionError]"))
  // 调试辅助：变体名与枚举一致（前缀化）
  assert_true(code.contains("MyIdle => \"idle\""))
  assert_true(code.contains("MyIri(_) => \"Iri\""))
  assert_false(code.contains("pub(all) enum Event"))
  assert_false(code.contains("pub(all) enum State"))
}
