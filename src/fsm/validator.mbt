// ===== 验证规则枚举 =====
///|
pub(all) enum Rule {
  V1_FROM_REFS_STATE // from / goto 必须引用已定义状态
  V2_ON_REFS_EVENT // on 必须引用已定义事件
  V3_UNIQUE_INITIAL // 有且仅有一个 initial 状态
  V4_NESTABLE_HAS_EXIT // nestable 状态必须声明 exit_event
  V5_EXIT_EVENT_DEFINED // exit_event 必须引用已定义事件
  V6_NO_DUPLICATE_TRANS // 同一 (from, on) 不允许重复定义
} derive(Debug, Eq)

///|
pub impl Show for Rule with fn output(self : Rule, logger : &Logger) -> Unit {
  match self {
    V1_FROM_REFS_STATE =>
      logger.write(
        "V1_FROM_REFS_STATE: from / goto must reference a defined state",
      )
    V2_ON_REFS_EVENT =>
      logger.write("V2_ON_REFS_EVENT: on must reference a defined event")
    V3_UNIQUE_INITIAL =>
      logger.write("V3_UNIQUE_INITIAL: there must be only one initial state")
    V4_NESTABLE_HAS_EXIT =>
      logger.write(
        "V4_NESTABLE_HAS_EXIT: nestable states must declare an exit_event",
      )
    V5_EXIT_EVENT_DEFINED =>
      logger.write(
        "V5_EXIT_EVENT_DEFINED: exit_event must reference a defined event",
      )
    V6_NO_DUPLICATE_TRANS =>
      logger.write(
        "V6_NO_DUPLICATE_TRANS: same (from, on) cannot be defined multiple times",
      )
  }
}

// ===== 验证错误详情 =====

///|
pub struct ValidationError {
  rule : Rule
  message : String
  suggestion : String?
}

///|
pub impl Show for ValidationError with fn output(
  self : ValidationError,
  logger : &Logger,
) -> Unit {
  logger.write("Validation error: [\{self.rule}] \{self.message}")
}

// ===== 验证结果 =====

///|
pub struct ValidationResult {
  errors : Array[ValidationError]
}

///|
pub fn ValidationResult::new() -> ValidationResult {
  ValidationResult::{ errors: [] }
}

// 记录错误

///|
pub fn ValidationResult::add_error(
  self : ValidationResult,
  rule : Rule,
  msg : String,
) -> Unit {
  self.errors.push(ValidationError::{ rule, message: msg, suggestion: None })
}

// 检查是否通过

///|
pub fn ValidationResult::is_ok(self : ValidationResult) -> Bool {
  self.errors.length() == 0
}

// 格式化输出错误

///|
pub fn ValidationResult::format_errors(self : ValidationResult) -> String {
  if self.is_ok() {
    return "Validation passed: No errors found."
  }
  let buf = StringBuilder::new()
  buf.write("Validation failed with \{self.errors.length()} error(s):")
  for err in self.errors {
    buf.write("  - [\{err.rule}] \{err.message}")
  }
  buf.to_string()
}
