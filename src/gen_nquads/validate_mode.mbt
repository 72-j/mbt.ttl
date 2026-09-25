///|
/// 校验档位（B2 步①）：**默认 `Deep`**——RDF 1.2 深验是本库的差异化面（口径表见 `const.md` §X）；
/// `Light` 只跳深验面（nquads 侧语义 = `SliceParser::new(..., lenient=true)`），供"只要速度"的
/// 调用方**显式**选择。**不设默认 Light**：性能不换深验。
pub(all) enum ValidateMode {
  Light
  Deep
}

///|
/// 档位 → 内部形参映射（口径表第 1 条：`lenient` 只作内部语义，不外泄第二开关）
pub fn ValidateMode::is_light(self : ValidateMode) -> Bool {
  match self {
    ValidateMode::Light => true
    ValidateMode::Deep => false
  }
}

///|
test "ValidateMode 映射真值（B2 步①）" {
  assert_true(ValidateMode::Light.is_light())
  assert_true(!ValidateMode::Deep.is_light())
}
