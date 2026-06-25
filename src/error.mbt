///|
pub(all) suberror IriError {
  NoScheme
  Expected(Char, Int)
  InvalidIriCodePoint(Char, Int)
  InvalidPercentEncoding(Int)
  InvalidHostCharacter(Char, Int)
  InvalidHostIp(String, Int)
  InvalidPortCharacter(Char, Int)
  PathStartingWithTwoSlashes(Int)
  RelativePathSegment(Char, Int)
  InvalidErrMessage(String)
}

///|
pub trait ErrOut {
  // fn position(self : Self) -> Int
  fn message(self : Self) -> String
  fn err_kind(self : Self) -> String
}

///|
pub fn IriError::position(self : IriError) -> Int {
  match self {
    IriError::NoScheme => 0
    IriError::Expected(_, pos) => pos
    IriError::RelativePathSegment(_, pos) => pos
    IriError::InvalidHostCharacter(_, pos) => pos
    IriError::InvalidHostIp(_, pos) => pos
    IriError::InvalidPortCharacter(_, pos) => pos
    IriError::InvalidIriCodePoint(_, pos) => pos
    IriError::InvalidPercentEncoding(pos) => pos
    IriError::PathStartingWithTwoSlashes(pos) => pos
    IriError::InvalidErrMessage(_) => 0
    // _ => 0 // 默认位置
  }
}

///|
impl ErrOut for IriError with fn message(self : IriError) -> String {
  match self {
    IriError::NoScheme(_) => "The IRI does not have a scheme"
    IriError::Expected(_, _) => "An expected character was not found"
    IriError::RelativePathSegment(_, _) => "A path segment is relative"
    IriError::InvalidHostCharacter(_, _) =>
      "The host contains a character not allowed"
    IriError::InvalidHostIp(_, _) => "The host is not a valid IP address"
    IriError::InvalidPortCharacter(_, _) =>
      "The port contains a character not allowed"
    IriError::InvalidIriCodePoint(_, _) =>
      "The IRI contains a code point not allowed"
    IriError::InvalidPercentEncoding(_) =>
      "The IRI contains invalid percent encoding"
    IriError::PathStartingWithTwoSlashes(_) =>
      "The path starts with two slashes"
    IriError::InvalidErrMessage(msg) => msg
    // _ => "An unknown error occurred" // 默认错误信息
  }
}

///|
impl ErrOut for IriError with fn err_kind(self : IriError) -> String {
  match self {
    IriError::NoScheme(_) => "NoScheme"
    IriError::Expected(_, _) => "Expected"
    IriError::RelativePathSegment(_, _) => "RelativePathSegment"
    IriError::InvalidHostCharacter(_, _) => "InvalidHostCharacter"
    IriError::InvalidHostIp(_, _) => "InvalidHostIp"
    IriError::InvalidPortCharacter(_, _) => "InvalidPortCharacter"
    IriError::InvalidIriCodePoint(_, _) => "InvalidIriCodePoint"
    IriError::InvalidPercentEncoding(_) => "InvalidPercentEncoding"
    IriError::PathStartingWithTwoSlashes(_) => "PathStartingWithTwoSlashes"
    IriError::InvalidErrMessage(_) => "InvalidErrMessage"
    // _ => "UnknownError" // 默认错误类型
  }
}

///|
impl Show for IriError with fn output(self : IriError, logger : &Logger) -> Unit {
  // 使用 trait 方法获取信息
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
pub(all) suberror TokenRecognizerError {
  Invalid
  InvalidFormat(ArrayView[Byte], Range)
  InvalidToken(ArrayView[Byte], Range)
  InvalidCharacter(ArrayView[Byte], Range)
  IncompleteEscapeSequence(ArrayView[Byte], Range)
  InvalidEscapeSequence(ArrayView[Byte], Range)
  UnsupportedFeature(ArrayView[Byte], Range)
  IriTruncated(ArrayView[Byte], Range)
  IriParsingError(String, Range)
  UnexpectedEndOfInput(ArrayView[Byte], Range)
  InvalidErrMessage(ArrayView[Byte], Range, String)
}

///|

///|
pub fn TokenRecognizerError::range(self : TokenRecognizerError) -> Range {
  match self {
    TokenRecognizerError::Invalid => Range::{ start: -1, end: -1 }
    TokenRecognizerError::InvalidFormat(_, range) => range
    TokenRecognizerError::InvalidToken(_, range) => range
    TokenRecognizerError::InvalidCharacter(_, range) => range
    TokenRecognizerError::IncompleteEscapeSequence(_, range) => range
    TokenRecognizerError::InvalidEscapeSequence(_, range) => range
    TokenRecognizerError::UnsupportedFeature(_, range) => range
    TokenRecognizerError::IriTruncated(_, range) => range
    TokenRecognizerError::IriParsingError(_msg, range) => range
    TokenRecognizerError::UnexpectedEndOfInput(_, range) => range
    TokenRecognizerError::InvalidErrMessage(_, range, _) => range
  }
}

///|
impl ErrOut for TokenRecognizerError with fn message(
  self : TokenRecognizerError,
) -> String {
  match self {
    TokenRecognizerError::Invalid => "Invalid token was provided"
    TokenRecognizerError::InvalidFormat(msg, range) => range.utf8_range(msg)
    TokenRecognizerError::InvalidToken(msg, range) => range.utf8_range(msg)
    TokenRecognizerError::InvalidCharacter(msg, range) => range.utf8_range(msg)
    TokenRecognizerError::IncompleteEscapeSequence(msg, range) =>
      range.utf8_range(msg)
    TokenRecognizerError::InvalidEscapeSequence(msg, range) =>
      range.utf8_range(msg)
    TokenRecognizerError::UnsupportedFeature(msg, range) =>
      range.utf8_range(msg)
    TokenRecognizerError::IriTruncated(msg, range) => range.utf8_range(msg)
    TokenRecognizerError::IriParsingError(msg, _) => msg
    TokenRecognizerError::UnexpectedEndOfInput(msg, range) =>
      range.utf8_range(msg)
    TokenRecognizerError::InvalidErrMessage(msg, range, msg_string) =>
      range.utf8_range(msg) + " - " + msg_string
  }
}

///|
impl ErrOut for TokenRecognizerError with fn err_kind(
  self : TokenRecognizerError,
) -> String {
  match self {
    TokenRecognizerError::Invalid => "Invalid"
    TokenRecognizerError::InvalidFormat(_, _) => "InvalidFormat"
    TokenRecognizerError::InvalidToken(_, _) => "InvalidRecognizerToken"
    TokenRecognizerError::InvalidCharacter(_, _) => "InvalidCharacter"
    TokenRecognizerError::IncompleteEscapeSequence(_, _) =>
      "IncompleteEscapeSequence"
    TokenRecognizerError::InvalidEscapeSequence(_, _) => "InvalidEscapeSequence"
    TokenRecognizerError::UnsupportedFeature(_, _) => "UnsupportedFeature"
    TokenRecognizerError::IriTruncated(_, _) => "IriTruncated"
    TokenRecognizerError::IriParsingError(_, _pos) => "IriParsingError"
    TokenRecognizerError::UnexpectedEndOfInput(_, _) => "UnexpectedEndOfInput"
    TokenRecognizerError::InvalidErrMessage(_, _, msg) =>
      "InvalidErrMessage" + " - " + msg
  }
}

///|
impl Show for TokenRecognizerError with fn output(
  self : TokenRecognizerError,
  logger : &Logger,
) -> Unit {
  // 使用 trait 方法获取信息
  let msg = self.message()
  let pos = self.range()
  let err_kind = self.err_kind()
  if pos.start >= 0 {
    logger.write_string(err_kind)
    logger.write_string(" - ")
    logger.write_string(pos.to_string())
    logger.write_string(": ")
    logger.write_string(msg)
  } else {
    logger.write_string(err_kind)
    logger.write_string(" - ")
    logger.write_string(msg)
  }
}

///|
pub impl Show for Range with fn output(self, logger : &Logger) -> Unit {
  logger.write_string("[")
  logger.write_string(self.start.to_string())
  logger.write_string(":")
  logger.write_string(self.end.to_string())
  logger.write_string("]")
}

///|

///|
pub(all) suberror RuleRecognizerError {
  SyntaxError(String, Range)
  BlankNodeOrIriError
  PredicateNotAnIRI
  LiteralDatatypeError
  TripleMissingDot
  InvalidLanguageTag
  BlankNodePropertyListMissingEndBracket
  //  UnexpectedToken(UnexpectedToken)
  // RecoveryError(RecoveryError)
}

///|
struct Range {
  start : Int
  end : Int
} derive(Debug, Default,Eq)

///|
pub fn Range::Range(start : Int, end : Int) -> Range {
  { start, end }
}

///|
pub fn Range::single(pos : Int) -> Range {
  { start: pos, end: pos }
}

///|
pub fn Range::length(self : Self) -> Int {
  self.end - self.start
}

///|
pub fn Range::contains(self : Self, pos : Int) -> Bool {
  pos >= self.start && pos < self.end
}

///|
pub fn Range::utf8_range(self : Range, data : ArrayView[Byte]) -> String {
  let data = data[self.start:self.end]
  let str = @utf8.decode_lossy(array_to_view(data))
  str
}

///|
pub(all) struct SourceRange {
  start : SourcePosition
  end : SourcePosition
} derive(Debug)

///|
fn SourceRange::SourceRange(
  start : SourcePosition,
  end : SourcePosition,
) -> SourceRange {
  { start, end }
}


impl Show for SourceRange with fn output(self, logger : &Logger) -> Unit {
  logger.write_string("[")
  logger.write_string(self.start.to_string())
  logger.write_string(":")
  logger.write_string(self.end.to_string())
  logger.write_string("]")
}

///|
pub fn RuleRecognizerError::text_range(
  self : RuleRecognizerError,
) -> Range {
  match self {
    RuleRecognizerError::SyntaxError(_, pos) =>
      pos
    RuleRecognizerError::BlankNodeOrIriError =>
      Range::default()
    RuleRecognizerError::PredicateNotAnIRI =>
      Range::default()

     
    RuleRecognizerError::TripleMissingDot =>
      Range::default()

    RuleRecognizerError::LiteralDatatypeError =>
      Range::default()

    RuleRecognizerError::InvalidLanguageTag =>
      Range::default()

    RuleRecognizerError::BlankNodePropertyListMissingEndBracket =>
      Range::default()

  }
}

///|
pub impl ErrOut for RuleRecognizerError with fn message(
  self : RuleRecognizerError,
) -> String {
  match self {
    RuleRecognizerError::SyntaxError(msg, _) => msg
    RuleRecognizerError::BlankNodeOrIriError =>
      "The subject of a triple must be an IRI or a blank node"
    RuleRecognizerError::PredicateNotAnIRI =>
      "The predicate of a triple must be an IRI"
    RuleRecognizerError::LiteralDatatypeError =>
      "The datatype of a literal must be an IRI"
    RuleRecognizerError::TripleMissingDot => "Triples must be followed by a dot"
    RuleRecognizerError::InvalidLanguageTag => "Invalid language tag"
    RuleRecognizerError::BlankNodePropertyListMissingEndBracket =>
      "blank node property lists should end with a ']'"
  }
}

///|
pub impl ErrOut for RuleRecognizerError with fn err_kind(
  self : RuleRecognizerError,
) -> String {
  match self {
    RuleRecognizerError::SyntaxError(_, _) => "SyntaxError"
    RuleRecognizerError::BlankNodeOrIriError => "BlankNodeOrIriError"
    RuleRecognizerError::PredicateNotAnIRI => "PredicateNotAnIRI"
    RuleRecognizerError::LiteralDatatypeError => "LiteralDatatypeError"
    RuleRecognizerError::TripleMissingDot => "TripleMissingDot"
    RuleRecognizerError::InvalidLanguageTag => "InvalidLanguageTag"
    RuleRecognizerError::BlankNodePropertyListMissingEndBracket =>
      "BlankNodePropertyListMissingEndBracket"
  }
}

///|
pub impl Show for RuleRecognizerError with fn output(
  self : RuleRecognizerError,
  logger : &Logger,
) -> Unit {
  let msg = self.message()
  let pos = self.text_range()
  let err_kind = self.err_kind()
  // if pos.start >= 0 {
  logger.write_string(err_kind)
  logger.write_string(" - ")
  logger.write_string(msg)
  logger.write_string(" at ")
  logger.write_string(pos.to_string())
  // }
}

///|
pub(all) suberror TurtleError {
  TurtleParseError(String, Range)
  TurtleSyntaxError(String, Range)
  InvalidEscapeSequence
  InvalidCharacter(String)
  InvalidToken(SourcePosition , String)
}

///|
pub impl ErrOut for TurtleError with fn message(self : TurtleError) -> String {
  match self {
    TurtleError::TurtleParseError(msg, _) => msg
    TurtleError::TurtleSyntaxError(msg, _) => msg
    TurtleError::InvalidEscapeSequence => "Invalid escape sequence"
    TurtleError::InvalidCharacter(c) => "Invalid character: " + c
    TurtleError::InvalidToken(_, token) => token
  }
}

///|
pub impl ErrOut for TurtleError with fn err_kind(self : TurtleError) -> String {
  match self {
    TurtleError::TurtleParseError(_, _) => "TurtleParseError"
    TurtleError::TurtleSyntaxError(_, _) => "TurtleSyntaxError"
    TurtleError::InvalidEscapeSequence => "InvalidEscapeSequence"
    TurtleError::InvalidCharacter(_) => "InvalidCharacter"
    TurtleError::InvalidToken(_, _) => "InvalidTurtleToken"
  }
}

///|
impl Show for TurtleError with fn output(self, logger : &Logger) -> Unit {
  let msg = self.message()
  let err_kind = self.err_kind()
  logger.write_string(err_kind)
  logger.write_string(" - ")
  logger.write_string(msg)
}

///|
pub(all) suberror LexerError {
  OutOfMemory(String)
  IoReadError(String)
  SyntaxError(String)
}

///|
pub impl ErrOut for LexerError with fn message(self : LexerError) -> String {
  match self {
    LexerError::OutOfMemory(msg) => msg
    LexerError::IoReadError(msg) => msg
    LexerError::SyntaxError(msg) => msg
  }
}

///|
pub impl ErrOut for LexerError with fn err_kind(self : LexerError) -> String {
  match self {
    LexerError::OutOfMemory(_) => "OutOfMemory"
    LexerError::IoReadError(_) => "IoReadError"
    LexerError::SyntaxError(_) => "SyntaxError"
  }
}

///|
impl Show for LexerError with fn output(self, logger : &Logger) -> Unit {
  let msg = self.message()
  let err_kind = self.err_kind()
  logger.write_string("Error: ")
  logger.write_string(err_kind)
  logger.write_string(" - ")
  logger.write_string(msg)
}

///|
pub(all) suberror LanguageTagParseError {
  // LanguageTagParseError
  TagParseErr(TagParseErr)
}

///|
impl Show for LanguageTagParseError with fn output(self, logger : &Logger) -> Unit {
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
  InvalidSubtag
  InvalidLanguage
  SubtagTooLong
  EmptySubtag
  TooManyExtlangs
  InvalidLanguageLength
}

///|
impl Show for TagParseErr with fn output(self, logger : &Logger) -> Unit {
  match self {
    TagParseErr::EmptyExtension => logger.write_string("EmptyExtension")
    TagParseErr::EmptyPrivateUse => logger.write_string("EmptyPrivateUse")
    TagParseErr::ForbiddenChar => logger.write_string("ForbiddenChar")
    TagParseErr::InvalidSubtag => logger.write_string("InvalidSubtag")
    TagParseErr::InvalidLanguage => logger.write_string("InvalidLanguage")
    TagParseErr::SubtagTooLong => logger.write_string("SubtagTooLong")
    TagParseErr::EmptySubtag => logger.write_string("EmptySubtag")
    TagParseErr::TooManyExtlangs => logger.write_string("TooManyExtlangs")
    TagParseErr::InvalidLanguageLength =>
      logger.write_string("InvalidLanguageLength")
  }
}

///|
enum SerializationError {
  FormatError(String)
  IoError(String)
}

///|
impl Show for SerializationError with fn output(self, logger : &Logger) -> Unit {
  match self {
    SerializationError::FormatError(msg) => {
      logger.write_string("Serialization Error: ")
      logger.write_string(msg)
    }
    SerializationError::IoError(msg) => {
      logger.write_string("Serialization Error: ")
      logger.write_string(msg)
    }
  }
}
