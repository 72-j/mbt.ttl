///|
test "ConsoleLogger: info logs message" {
  let logger = @lib.make_console_logger()
  logger.info("This is an info message.")
}

///|
test "ConsoleLogger: error logs message" {
  let logger = @lib.make_console_logger()
  logger.error("This is an error message.")
}

///|
test "ConsoleLogger: warn logs message" {
  let logger = @lib.make_console_logger()
  logger.warn("This is a warning message.")
}

///|
test "MuteLogger: info does nothing" {
  let logger = @lib.make_mute_logger()
  logger.info("This message should be silently ignored.")
}

///|
test "MuteLogger: error does nothing" {
  let logger = @lib.make_mute_logger()
  logger.error("This error message should be silently ignored.")
}

///|
test "MuteLogger: warn does nothing" {
  let logger = @lib.make_mute_logger()
  logger.warn("This warning should be silently ignored.")
}

///|
test "ConsoleLogger: empty message" {
  let logger = @lib.make_console_logger()
  logger.info("")
  logger.error("")
  logger.warn("")
}

///|
test "MuteLogger: empty message" {
  let logger = @lib.make_mute_logger()
  logger.info("")
  logger.error("")
  logger.warn("")
}

///|
test "ConsoleLogger: long message" {
  let logger = @lib.make_console_logger()
  let long_msg = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " +
    "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
  logger.info(long_msg)
  logger.error(long_msg)
  logger.warn(long_msg)
}

///|
test "ConsoleLogger: unicode message" {
  let logger = @lib.make_console_logger()
  logger.info("你好，世界！🌍")
  logger.error("错误消息：测试中文")
  logger.warn("警告：日本語テスト")
}

///|
test "MuteLogger: unicode message" {
  let logger = @lib.make_mute_logger()
  logger.info("你好，世界！🌍")
  logger.error("错误消息：测试中文")
  logger.warn("警告：日本語テスト")
}

///|
test "ConsoleLogger: special characters" {
  let logger = @lib.make_console_logger()
  logger.info("Line1\nLine2\tTabbed")
  logger.error("Backslash: \\ Slash: / Quote: \"")
  logger.warn("Newline\n\rTab\t")
}

///|
test "MuteLogger: special characters" {
  let logger = @lib.make_mute_logger()
  logger.info("Line1\nLine2\tTabbed")
  logger.error("Backslash: \\ Slash: / Quote: \"")
  logger.warn("Newline\n\rTab\t")
}

///|
test "ConsoleLogger: multiple loggers same instance" {
  let logger = @lib.make_console_logger()
  logger.info("First message")
  logger.info("Second message")
  logger.info("Third message")
}

///|
test "MuteLogger: multiple loggers same instance" {
  let logger = @lib.make_mute_logger()
  logger.info("First message")
  logger.info("Second message")
  logger.info("Third message")
}
