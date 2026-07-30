///|
pub struct LocatedToken(N3Token, Range) derive(Debug)

///|
pub fn LocatedToken::into_token(self : Self) -> N3Token {
  self.0
}

///|
pub fn LocatedToken::new(token : N3Token, range : Range) -> Self {
  LocatedToken(token, range)
}

///|
pub impl Show for LocatedToken with fn output(self : LocatedToken, f : &Logger) -> Unit {
  f.write("LocatedToken(")
  self.0.output(f)
  f.write(", ")
  self.1.output(f)
  f.write(")")
}

///|
pub(all) enum BaseDirection {
  Ltr
  Rtl
} derive(Eq, Debug, Hash, ToJson)

///|
pub impl Show for BaseDirection with fn output(
  self : BaseDirection,
  f : &Logger,
) -> Unit {
  match self {
    BaseDirection::Ltr => f.write("ltr")
    BaseDirection::Rtl => f.write("rtl")
  }
}

///|
pub(all) enum N3Token {
  Iri(String)
  PrefixedName(prefix~ : String, localx~ : String, might_be_invalid_iri~ : Bool)
  Variable(String)
  BlankNodeLabel(String)
  String(String)
  LongString(String)
  Integer(String)
  Decimal(String)
  Double(String)
  LangTag(language~ : String, direction~ : BaseDirection?)
  Punctuation(String)
  PlainKeyword(String)
  LineJump // 换行位置
  End // 文件结束位置
  // Literal(String)
} derive(Debug, Eq)

///|
pub impl Show for N3Token with fn output(self : N3Token, f : &Logger) -> Unit {
  match self {
    N3Token::Iri(iri) => f.write(iri)
    N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~) => {
      f.write(prefix)
      f.write(":")
      f.write(localx)
      if might_be_invalid_iri {
        f.write(" (invalid IRI)")
      }
    }
    N3Token::Variable(v) => {
      f.write("?")
      f.write(v)
    }
    N3Token::BlankNodeLabel(v) =>
      // f.write("_:")
      f.write(v)
    N3Token::String(v) | N3Token::LongString(v) =>
      // f.write("\"")
      f.write(v) // 注意：如果 v 包含引号，可能需要转义，但调试用通常直接写
    // f.write("\"")
    N3Token::Integer(v) | N3Token::Decimal(v) | N3Token::Double(v) => f.write(v)
    N3Token::LangTag(language~, direction~) => {
      // f.write("@")
      f.write(language)
      match direction {
        Some(BaseDirection::Ltr) => f.write(";ltr")
        Some(BaseDirection::Rtl) => f.write(";rtl")
        None => ()
      }
    }
    N3Token::Punctuation(punct) => f.write(punct)
    N3Token::PlainKeyword(keyword) => f.write(keyword)
    N3Token::LineJump => f.write("LineJump")
    N3Token::End => f.write("EOF")
    // N3Token::Literal(literal) => f.write(literal)
  }
}
