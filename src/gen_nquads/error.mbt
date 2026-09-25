///|
/// NQuadsEngine 错误类型（包含位置信息）
pub(all) suberror ParseError {
  StructSyntaxErr(String, Int, Span) // 结构错误（语法层）
  SyntaxErr(String, Span) // 结构错误（语法层）
  ValidationErr(String) // 语义错误（验证层）
  IriErr(String) // IRI 解析错误
} derive(Debug)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend ParseError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn ParseError::to_span(err : ParseError) -> Span {
  match err {
    ValidationErr(_) => (0, 0)
    StructSyntaxErr(_, _, span) => span
    SyntaxErr(_, span) => span
    IriErr(_) => (0, 0)
  }
}

///|
pub impl ErrOut for ParseError with fn message(self : ParseError) -> String {
  match self {
    ParseError::ValidationErr(message) => message
    ParseError::StructSyntaxErr(message, _, _) => message
    ParseError::SyntaxErr(message, _) => message
    ParseError::IriErr(message) => message
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend ParseError with ErrOut::{err_kind, message}

///|
pub impl ErrOut for ParseError with fn err_kind(self : ParseError) -> String {
  match self {
    ValidationErr(_) => "ValidationErr"
    ParseError::StructSyntaxErr(_, _, _) => "StructSyntaxErr"
    // 修（2026-09-18）：此处原为 `message`——把消息当 kind 返回（与 trig 侧同名 impl
    // `gen_trig/types.mbt:125` 的 "SyntaxErr" 不一致）；由 error_wbtest 的逐变体断言检出。
    SyntaxErr(_, _) => "SyntaxErr"
    ParseError::IriErr(_) => "IriErr"
  }
}

///|
pub impl Show for ParseError with fn output(self : ParseError, logger : &Logger) -> Unit {
  match self {
    ParseError::ValidationErr(message) => logger.write_string(message)
    ParseError::StructSyntaxErr(message, line, span) => {
      let (offset, length) = span
      logger.write_string(message)
      logger.write_string(" at line ")
      logger.write_string(":")
      logger.write_string(line.to_string())
      logger.write_string(" at position ")
      logger.write_string("(\{offset}, \{length})")
    }
    SyntaxErr(message, span) => {
      let (offset, length) = span
      logger.write_string(message)
      logger.write_string(" at position ")
      logger.write_string("(\{offset}, \{length})")
    }
    ParseError::IriErr(message) => logger.write_string(message)
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend ParseError with Show::{output, to_string}

///|
pub(all) suberror IriError {
  /// 没有 scheme
  NoScheme(Int)
  /// 无效的 scheme 字符
  InvalidScheme(Char, Int)
  /// 无效的字符（IRI 中不允许的）
  InvalidCharacter(Char, Int)
  /// 无效的路径
  InvalidPath(Int)
  /// 无效的授权部分
  InvalidAuthority(String)
  /// 无效的 percent 编码
  InvalidPercentEncoding(Int)
  /// 意外的结束
  UnexpectedEnd(Int)
} derive(Debug)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend IriError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub trait ErrOut {
  // fn position(self : Self) -> Int
  fn message(self : Self) -> String
  fn err_kind(self : Self) -> String
}

///|
pub fn IriError::position(self : IriError) -> Int {
  match self {
    NoScheme(p) => p
    InvalidScheme(_, p) => p
    InvalidCharacter(_, p) => p
    InvalidPath(p) => p
    InvalidAuthority(_) => -1
    InvalidPercentEncoding(p) => p
    UnexpectedEnd(p) => p
  }
}

///|
pub impl ErrOut for IriError with fn message(self : IriError) -> String {
  match self {
    NoScheme(_) => "No scheme found"
    InvalidScheme(_, _) => "Invalid scheme character"
    InvalidCharacter(_, _) => "Invalid character"
    InvalidPath(_) => "Invalid path"
    InvalidAuthority(msg) => "Invalid authority: \{msg}"
    InvalidPercentEncoding(_) => "Invalid percent encoding"
    UnexpectedEnd(_) => "Unexpected end of input"
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend IriError with ErrOut::{err_kind, message}

///|
pub impl ErrOut for IriError with fn err_kind(self : IriError) -> String {
  match self {
    NoScheme(_) => "NoScheme"
    InvalidScheme(_, _) => "InvalidScheme"
    InvalidCharacter(_, _) => "InvalidCharacter"
    InvalidPath(_) => "InvalidPath"
    InvalidAuthority(_) => "InvalidAuthority"
    InvalidPercentEncoding(_) => "InvalidPercentEncoding"
    UnexpectedEnd(_) => "UnexpectedEnd"
  }
}

///|
pub impl Show for IriError with fn output(self : IriError, logger : &Logger) -> Unit {
  // 显式限定：方法隐式提升已 deprecated（`moon test --deny-warn` 红）
  let msg = ErrOut::message(self)
  let pos = self.position()
  let err_kind = ErrOut::err_kind(self)
  if pos >= 0 {
    logger.write_string(err_kind)
    logger.write_string(" - ")
    logger.write_string(msg)
    logger.write_string(" at position ")
    logger.write_string(pos.to_string())
  } else {
    logger.write_string(err_kind)
    logger.write_string(" - ")
    logger.write_string(msg)
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend IriError with Show::{output, to_string}

///|
pub(all) suberror TagParseErr {
  EmptyTag
  EmptySubtag
  InvalidLanguageLength
  ForbiddenChar
  TooManyExtlangs
  InvalidSubtag(Span, StringView)
  EmptyExtension
  EmptyPrivateUse
  InvalidVariant
  InvalidPrivateUsePrefix
} derive(Debug)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TagParseErr with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub impl Show for TagParseErr with fn output(self, logger : &Logger) -> Unit {
  match self {
    TagParseErr::EmptyExtension => logger.write_string("EmptyExtension")
    TagParseErr::EmptyPrivateUse => logger.write_string("EmptyPrivateUse")
    TagParseErr::InvalidVariant => logger.write_string("InvalidVariant")
    TagParseErr::ForbiddenChar => logger.write_string("ForbiddenChar")
    TagParseErr::InvalidSubtag(_, str) => {
      logger.write_string("InvalidSubtag: ")
      logger.write_view(str)
    }
    TagParseErr::InvalidPrivateUsePrefix =>
      logger.write_string("InvalidPrivateUsePrefix")
    TagParseErr::EmptyTag => logger.write_string("EmptyTag")
    TagParseErr::EmptySubtag => logger.write_string("EmptySubtag")
    TagParseErr::TooManyExtlangs => logger.write_string("TooManyExtlangs")
    TagParseErr::InvalidLanguageLength =>
      logger.write_string("InvalidLanguageLength")
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend TagParseErr with Show::{output, to_string}

///|
//
