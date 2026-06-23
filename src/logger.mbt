///|
pub trait DebugLogger {
  info(Self, String) -> Unit
  error(Self, String) -> Unit
  warn(Self, String) -> Unit
}

///|
struct ConsoleLogger {}

///|
pub fn make_console_logger() -> ConsoleLogger {
  ConsoleLogger::{  }
}

///|
pub impl DebugLogger for ConsoleLogger with info(_self, msg) {
  println("[INFO] \{msg}")
}
pub impl DebugLogger for ConsoleLogger with error(_self, msg) {
  println("[ERROR] \{msg}")
}
pub impl DebugLogger for ConsoleLogger with warn(_self, msg) {
  println("[WARN] \{msg}")
}
///|
struct MuteLogger {}

///|
pub impl DebugLogger for MuteLogger with info(_self, _msg) {
  // Do nothing
}

pub impl DebugLogger for MuteLogger with error(_self, _msg) {
  // Do nothing
}

pub impl DebugLogger for MuteLogger with warn(_self, _msg) {
  // Do nothing
}

///|
pub fn make_mute_logger() -> MuteLogger {
  MuteLogger::{  }
}
