// ===== FSM Trait Codegen =====
// 本模块生成 FsmHandler trait 和默认实现

///|
/// 生成 FsmHandler trait 定义
/// - action 名称 → on_* 方法（核心方法，必须实现）
/// - effect 名称 → handle_* 方法（有默认实现）
pub fn emit_fsm_handler_trait(
  actions : Array[ActionDef],
  effects : Array[EffectDef],
  _config : CodegenConfig,
) -> String {
  let code = StringBuilder::new()

  // Trait 定义开始
  code <+ "///|\n"
  code <+ "pub trait FsmHandler {\n"

  // 生成 on_* 方法声明（action 名称，核心方法）
  for action in actions {
    let method_name = "on_\{action.name}"
    code <+ "  \{method_name}(Self) -> Effect\n"
  }

  // 生成 handle_* 方法声明（effect 名称，有默认实现）
  for effect in effects {
    let method_name = "handle_\{effect.name}"
    let params = if effect.payload.length() > 0 {
      // 有载荷时，需要参数
      let type_name = effect.payload[0].type_
      "(Self, \{type_name})"
    } else {
      "(Self)"
    }
    code <+ "  \{method_name}\{params} -> Effect = _\n"
  }

  code <+ "}\n"

  code.to_string()
}

///|
/// ��成 FsmHandler 默认实现
/// handle_* 方法的默认实现：返回对应的 Effect 变体
pub fn emit_fsm_handler_impl(
  effects : Array[EffectDef],
  _config : CodegenConfig,
) -> String {
  if effects.is_empty() {
    return ""
  }

  let code = StringBuilder::new()

  code <+ "/// FsmHandler 默认实现\n"

  // 收集无载荷的 effects 用于批量实现
  let no_payload_effects = effects.filter(fn(e) { e.payload.is_empty() })
  let with_payload_effects = effects.filter(fn(e) { e.payload.length() > 0 })

  // 批量实现无载荷的 handle_* 方法
  if no_payload_effects.is_empty() == false {
    code <+ "impl FsmHandler with "
    for i = 0; i < no_payload_effects.length(); i = i + 1 {
      let effect = no_payload_effects[i]
      if i > 0 {
        code <+ ", "
      }
      let name = effect.name
      code <+ "handle_\{name}(self) { Effect::\{name}\n  }\n"
    }
  }

  // 单独实现有载荷的 handle_* 方法
  for effect in with_payload_effects {
    let name = effect.name
    let type_name = effect.payload[0].type_
    code <+
      "impl FsmHandler with handle_\{name}(self, _v: \{type_name}) { Effect::\{name}(_v)\n}\n"
  }

  code.to_string()
}

///|
/// 生成完整的 FsmHandler 代码（trait + impl）
pub fn emit_fsm_handler(
  actions : Array[ActionDef],
  effects : Array[EffectDef],
  config : CodegenConfig,
) -> String {
  let trait_code = emit_fsm_handler_trait(actions, effects, config)
  let impl_code = emit_fsm_handler_impl(effects, config)

  if impl_code.length() > 0 {
    "\{trait_code}\n\n\{impl_code}"
  } else {
    trait_code
  }
}
