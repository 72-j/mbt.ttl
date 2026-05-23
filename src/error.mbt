///|
type TextPosition = String

///|
pub(all) suberror IriParseError {
  NoScheme(Int)
  Expected(Char, Int)
  InvalidIriCodePoint(Char, Int)
  InvalidPercentEncoding(Int)
  InvalidHostCharacter(Char, Int)
  InvalidHostIp(String, Int)
  InvalidPortCharacter(Char, Int)
  PathStartingWithTwoSlashes(Int)
  RelativePathSegment(Char, Int)
}

///|
pub trait ParseErrOut {
  position(self : Self) -> Int
  message(self : Self) -> String
  kind(self : Self) -> String
}

///|
impl ParseErrOut for IriParseError with position(self : IriParseError) -> Int {
  match self {
    IriParseError::NoScheme(pos) => pos
    IriParseError::Expected(_, pos) => pos
    IriParseError::RelativePathSegment(_, pos) => pos
    IriParseError::InvalidHostCharacter(_, pos) => pos
    IriParseError::InvalidHostIp(_, pos) => pos
    IriParseError::InvalidPortCharacter(_, pos) => pos
    IriParseError::InvalidIriCodePoint(_, pos) => pos
    IriParseError::InvalidPercentEncoding(pos) => pos
    IriParseError::PathStartingWithTwoSlashes(pos) => pos
    IriParseError::Expected(_, pos) => pos
    // _ => 0 // 默认位置
  }
}

///|
impl ParseErrOut for IriParseError with message(self : IriParseError) -> String {
  match self {
    IriParseError::NoScheme(_) => "The IRI does not have a scheme"
    IriParseError::Expected(_, _) => "An expected character was not found"
    IriParseError::RelativePathSegment(_, _) => "A path segment is relative"
    IriParseError::InvalidHostCharacter(_, _) =>
      "The host contains a character not allowed"
    IriParseError::InvalidHostIp(_, _) => "The host is not a valid IP address"
    IriParseError::InvalidPortCharacter(_, _) =>
      "The port contains a character not allowed"
    IriParseError::InvalidIriCodePoint(_, _) =>
      "The IRI contains a code point not allowed"
    IriParseError::InvalidPercentEncoding(_) =>
      "The IRI contains invalid percent encoding"
    IriParseError::PathStartingWithTwoSlashes(_) =>
      "The path starts with two slashes"
    // _ => "An unknown error occurred" // 默认错误信息
  }
}

///|
impl ParseErrOut for IriParseError with kind(self : IriParseError) -> String {
  match self {
    IriParseError::NoScheme(_) => "NoScheme"
    IriParseError::Expected(_, _) => "Expected"
    IriParseError::RelativePathSegment(_, _) => "RelativePathSegment"
    IriParseError::InvalidHostCharacter(_, _) => "InvalidHostCharacter"
    IriParseError::InvalidHostIp(_, _) => "InvalidHostIp"
    IriParseError::InvalidPortCharacter(_, _) => "InvalidPortCharacter"
    IriParseError::InvalidIriCodePoint(_, _) => "InvalidIriCodePoint"
    IriParseError::InvalidPercentEncoding(_) => "InvalidPercentEncoding"
    IriParseError::PathStartingWithTwoSlashes(_) => "PathStartingWithTwoSlashes"
    // _ => "UnknownError" // 默认错误类型
  }
}

///|
impl Show for IriParseError with output(self : IriParseError, logger : &Logger) -> Unit {
  // 使用 trait 方法获取信息
  let msg = self.message()
  let pos = self.position()
  let kind = self.kind()
  if pos >= 0 {
    logger.write_string("Error: ")
    logger.write_string(kind)
    logger.write_string(" - ")
    logger.write_string(msg)
    logger.write_string(" at position ")
    logger.write_string(pos.to_string())
  } else {
    logger.write_string("Error: ")
    logger.write_string(kind)
    logger.write_string(" - ")
    logger.write_string(msg)
  }
}
