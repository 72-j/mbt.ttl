///|
/// NQuadsEngine 错误类型（包含位置信息）
pub(all) suberror ParseError {
  StructSyntaxErr(String, Int, Span) // 结构错误（语法层）
  SyntaxErr(String, Span) // 结构错误（语法层）
  ValidationErr(String) // 语义错误（验证层）
  IriErr(String) // IRI 解析错误
} derive(Debug)

///|
fn ParseError::span(token : Token) -> Span {
  match token {
    Iri(s)
    | Literal(s)
    | BlankNode(s)
    | PrefName(s)
    | Dot(s)
    | Unknown(s)
    | Comma(s)
    | Semicolon(s) => s
    EOF(int) => (0, int)
  }
}

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
pub impl ErrOut for ParseError with fn err_kind(self : ParseError) -> String {
  match self {
    ValidationErr(_) => "ValidationErr"
    ParseError::StructSyntaxErr(_, _, _) => "StructSyntaxErr"
    SyntaxErr(message, _) => message
    ParseError::IriErr(_) => "IriErr"
  }
}

///|
/// 从 span 创建错误
// pub fn ParseError::from_span(message : String, span : Span) -> ParseError {
//   { message, span }
// }

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
  let msg = self.message()
  let pos = self.position()
  let err_kind = self.err_kind()
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
pub(all) suberror LanguageTagParseError {
  // LanguageTagParseError
  TagParseErr(TagParseErr)
} derive(Debug)

///|
pub impl Show for LanguageTagParseError with fn output(self, logger : &Logger) -> Unit {
  match self {
    LanguageTagParseError::TagParseErr(e) => {
      logger.write_string("Error: Language Tag Parse Error - ")
      logger.write_string(e.to_string())
    }
  }
}

///|
pub(all) suberror TagParseErr {
  EmptyExtension
  EmptyPrivateUse
  ForbiddenChar
  InvalidSubtag(Int, StringView)
  InvalidLanguage
  SubtagTooLong
  EmptySubtag
  TooManyExtlangs
  InvalidLanguageLength
} derive(Debug)

///|
pub impl Show for TagParseErr with fn output(self, logger : &Logger) -> Unit {
  match self {
    TagParseErr::EmptyExtension => logger.write_string("EmptyExtension")
    TagParseErr::EmptyPrivateUse => logger.write_string("EmptyPrivateUse")
    TagParseErr::ForbiddenChar => logger.write_string("ForbiddenChar")
    TagParseErr::InvalidSubtag(_, str) => {
      logger.write_string("InvalidSubtag: ")
      logger.write_view(str)
    }
    TagParseErr::InvalidLanguage => logger.write_string("InvalidLanguage")
    TagParseErr::SubtagTooLong => logger.write_string("SubtagTooLong")
    TagParseErr::EmptySubtag => logger.write_string("EmptySubtag")
    TagParseErr::TooManyExtlangs => logger.write_string("TooManyExtlangs")
    TagParseErr::InvalidLanguageLength =>
      logger.write_string("InvalidLanguageLength")
  }
}

///|
//
