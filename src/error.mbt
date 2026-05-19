
type TextPosition = String
pub(all) suberror TagParseErr {
  EmptyExtension
  EmptyPrivateUse
  ForbiddenChar
  InvalidSubtag
  InvalidLanguage
  SubtagTooLong
  EmptySubtag
  TooManyExtlangs
}

///|
impl Show for TagParseErr with output(self : TagParseErr, logger : &Logger) -> Unit {
  match self {
    TagParseErr::EmptyExtension =>
      logger.write_string(
        "If an extension subtag is present, it must not be empty",
      )
    TagParseErr::EmptyPrivateUse =>
      logger.write_string("If the `x` subtag is present, it must not be empty")
    TagParseErr::ForbiddenChar =>
      logger.write_string("The langtag contains a char not allowed")
    TagParseErr::InvalidSubtag =>
      logger.write_string(
        "A subtag fails to parse, it does not match any other subtags",
      )
    TagParseErr::InvalidLanguage =>
      logger.write_string("The given language subtag is invalid")
    TagParseErr::SubtagTooLong =>
      logger.write_string(
        "A subtag may be eight characters in length at maximum",
      )
    TagParseErr::EmptySubtag =>
      logger.write_string("A subtag should not be empty")
    TagParseErr::TooManyExtlangs =>
      logger.write_string("At maximum three extlangs are allowed")
  }
}
pub(all) suberror RuleRecognizerError {
 SyntaxError(SyntaxError )

}
pub(all) struct  SyntaxError { 
  message: String
  pos: TextPosition
}
pub fn SyntaxError::new(pos: TextPosition, message: String) -> SyntaxError {
  SyntaxError:: { message, pos }  
}

pub(all) suberror TurtleParseError {
Syntax(String)
}



///|
pub(all) suberror IriParseError {
  NoScheme
  RelativePathSegment(String)
  InvalidHostCharacter(Char)
  InvalidHostIp(String)
  InvalidPortCharacter(Char)
  InvalidIriCodePoint(Char)
  InvalidPercentEncoding
  PathStartingWithTwoSlashes
}
pub(all) suberror TokenRecognizerError {
  Invalid
  InvalidFormat(String)
  InvalidToken(Range,String)
  InvalidCharacter(String)
  IncompleteEscapeSequence(String)
  InvalidEscapeSequence(String)
  UnsupportedFeature(String)
}

pub(all) suberror LexerError {
  OutOfMemory(String)
  IoReadError(String)
  Syntax(String)

}
pub(all) suberror TurtleSyntaxError {
  InvalidCharacter(String)
  InvalidToken(TextPosition,String)
  InvalidEscapeSequence
}
struct Range {
  start : Int
  end : Int  // 注意：Rust 中通常 end 是 exclusive
}
pub impl Show for Range with to_string(self) {
  self.start.to_string() + ".." + self.end.to_string()
}
pub fn Range::new(start : Int, end : Int) -> Range {
  { start, end }
}

pub fn Range::utf8_range(self: Range, data: BytesView) -> String {
  let data=data[self.start:self.end]
  let str=@utf8.decode_lossy(data)
  str
  }
