// ===== FSM Effect System Codegen =====
// 本模块生成 Effect 系统的两个部分：
// 1. Effect 枚举（第一层产物：step 返回的副作用意图，纯数据）
// 2. 第二层 EffectHandler 模板：step 外部真正的 match effect 分发
//
// 两层职责：
// - Actions（step 内部）：业务逻辑，更新 Context，计算并返回 Effect 意图
// - EffectHandler（step 外部）：调度器拿到 (new_ctx, effect) 后，
//   调用 handler.dispatch(effect)（trait 默认方法）解构意图并执行副作用。
//   生成器只生成模板（handle_* 默认返回 Ok(())），错误用 EffectError 强类型表示，
//   具体副作用由用户覆盖

// ===== 第一层产物：Effect 枚举 =====

///|
/// 从 EffectDef 列表生成 Effect 枚举代码
pub fn emit_effect_enum(
  effects : Array[EffectDef],
  config : CodegenConfig,
) -> String {
  if effects.is_empty() {
    return ""
  }

  let code = StringBuilder::new()

  code <+
    "/// Effect 枚举：状态机可能产生的副作用（纯数据）\n"
  code <+ "pub(all) enum \{prefixed_type(config, "Effect")} {\n"

  for i = 0; i < effects.length(); i = i + 1 {
    let effect = effects[i]
    code <+ "  "
    code.write(effect.name)

    // 载荷：单字段 → EmitQuad(T)；多字段 → EmitQuad(A, B)
    // 载荷类型中的生成类型保留名（如 Goto(State)）改写为带前缀版本
    match effect.payload.length() {
      0 => ()
      1 => code <+ "(\{rewrite_type(config, effect.payload[0].type_)})"
      _ => {
        let types = effect.payload.map(fn(f) { rewrite_type(config, f.type_) })
        code <+ "(\{types.join(", ")})"
      }
    }

    if i < effects.length() - 1 {
      code <+ "\n"
    }
  }

  code <+ "\n}\n"

  code.to_string()
}

///|
/// 生成默认的 Effect 枚举（包含常用变体）
pub fn emit_default_effect_enum(config : CodegenConfig) -> String {
  let code = StringBuilder::new()

  code <+
    "/// Effect 枚举：状态机可能产生的副作用（纯数据）\n"
  code <+ "pub(all) enum \{prefixed_type(config, "Effect")} {\n"
  code <+ "  Continue\n" // 继续当前状态
  code <+ "  SkipLine\n" // 跳过当前行
  code <+ "  Done\n" // 完成处理
  code <+ "}\n"

  code.to_string()
}

// ===== 第二层产物：EffectHandler 模板 =====

///|
/// 生成第二层专用错误枚举：副作用执行阶段的错误
/// 强类型区分「可恢复的下游失败」与「需要终止状态机的致命错误」
fn emit_effect_error_enum(config : CodegenConfig) -> String {
  let code = StringBuilder::new()
  code <+ "///|\n"
  code <+ "/// 副作用执行阶段的错误（第二层）\n"
  code <+ "pub(all) enum \{prefixed_type(config, "EffectError")} {\n"
  code <+ "  SinkFailed(String) // 下游写入失败（可恢复）\n"
  code <+ "  Fatal(String) // 致命错误，需要终止状态机\n"
  code <+ "}\n"
  code.to_string()
}

///|
/// EffectHandler trait 名称（加前缀防冲突）
fn effect_handler_name(config : CodegenConfig) -> String {
  prefixed_type(config, "EffectHandler")
}

///|
/// 驼峰转下划线：EmitQuad → emit_quad
/// 注：本版本 String 下标返回码点（Int），需显式 to_char 再拼接
fn to_snake_case(name : String) -> String {
  let buf = StringBuilder::new()
  for i = 0; i < name.length(); i = i + 1 {
    let ch = name[i]
    if ch >= 'A' && ch <= 'Z' {
      if i > 0 {
        buf.write("_")
      }
      buf.write("\{(ch + 32).to_char().unwrap()}")
    } else {
      buf.write("\{ch.to_char().unwrap()}")
    }
  }
  buf.to_string()
}

///|
/// 生成 EffectHandler trait（第二层）：每个 effect 一个 handle_* 模板方法，
/// 并提供 dispatch 默认实现（match effect 分发，self 调用 handle_*）。
/// 声明用 `= _` 标记默认实现，默认体由随后的 impl 块给出；
/// 用户 impl 覆盖需要的 handle_*，通常无需覆盖 dispatch
fn emit_effect_handler_trait(
  effects : Array[EffectDef],
  config : CodegenConfig,
) -> String {
  if effects.is_empty() {
    return ""
  }

  let handler = effect_handler_name(config)
  let effect_t = prefixed_type(config, "Effect")
  let err_t = prefixed_type(config, "EffectError")
  let code = StringBuilder::new()
  code <+ "///|\n"
  code <+
    "/// 第二层 EffectHandler：真正的 match effect 发生在 step 外部\n"
  code <+
    "/// handle_* 模板方法默认 Ok(())；dispatch 默认解构意图并分发\n"
  code <+
    "/// 用户 impl 覆盖需要的 handle_*，通常无需覆盖 dispatch\n"
  code <+ "pub trait \{handler} {\n"
  for effect in effects {
    let handle = "handle_\{to_snake_case(effect.name)}"
    let params = match effect.payload.length() {
      0 => ""
      1 => ", \{rewrite_type(config, effect.payload[0].type_)}"
      _ => {
        let types = effect.payload.map(fn(f) { rewrite_type(config, f.type_) })
        ", \{types.join(", ")}"
      }
    }
    code <+ "  fn \{handle}(Self\{params}) -> Result[Unit, \{err_t}] = _\n"
  }
  code <+
    "  fn dispatch(Self, effect : \{effect_t}) -> Result[Unit, \{err_t}] = _\n"
  code <+ "}\n\n"

  // 模板默认实现：handle_* 无操作（用户按需覆盖）
  for effect in effects {
    let handle = "handle_\{to_snake_case(effect.name)}"
    let args = match effect.payload.length() {
      0 => "_self"
      _ => {
        let names = effect.payload.map(fn(f) { "_\{f.name}" })
        "_self, \{names.join(", ")}"
      }
    }
    code <+ "/// \{handle} 模板默认：无操作\n"
    code <+ "impl \{handler} with fn \{handle}(\{args}) {\n"
    code <+ "  Ok(())\n"
    code <+ "}\n\n"
  }

  // dispatch 默认：真正的 match effect 在这里发生，
  // 解构意图载荷并分发到 handle_*，用户无需调用任何外部函数
  code <+ "/// dispatch 模板默认：match effect 并分发到 handle_*\n"
  code <+ "impl \{handler} with fn dispatch(self, effect) {\n"
  code <+ "  match effect {\n"
  for effect in effects {
    let handle = "handle_\{to_snake_case(effect.name)}"
    match effect.payload.length() {
      0 => code <+ "    \{effect.name} => self.\{handle}()\n"
      _ => {
        let names = effect.payload.map(fn(f) { f.name })
        let args = names.join(", ")
        code <+ "    \{effect.name}(\{args}) => self.\{handle}(\{args})\n"
      }
    }
  }
  code <+ "  }\n"
  code <+ "}\n"
  code.to_string()
}
