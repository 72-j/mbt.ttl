///|
pub trait DebugLogger {
  fn info(Self, String) -> Unit
  fn error(Self, String) -> Unit
  fn warn(Self, String) -> Unit
}

///|
struct ConsoleLogger {}

///|
fn make_console_logger() -> ConsoleLogger {
  ConsoleLogger::{ }
}

///|
impl DebugLogger for ConsoleLogger with fn info(_self, msg) {
  debug("[INFO] \{msg}")
}

///|
impl DebugLogger for ConsoleLogger with fn error(_self, msg) {
  debug("[ERROR] \{msg}")
}

///|
impl DebugLogger for ConsoleLogger with fn warn(_self, msg) {
  debug("[WARN] \{msg}")
}

///|
struct MuteLogger {}

///|
impl DebugLogger for MuteLogger with fn info(_self, _msg) {
  // Do nothing
}

///|
impl DebugLogger for MuteLogger with fn error(_self, _msg) {
  // Do nothing
}

///|
impl DebugLogger for MuteLogger with fn warn(_self, _msg) {
  // Do nothing
}

///|
fn make_mute_logger() -> MuteLogger {
  MuteLogger::{ }
}
