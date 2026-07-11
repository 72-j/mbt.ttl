///|
/// 带位置的 N3Token
pub struct LocatedN3Token(N3Token, Range) derive(Debug)

///|
pub fn LocatedN3Token::into_token(self : Self) -> N3Token {
  self.0
}

///|
fn LocatedN3Token::new(token : N3Token, range : Range) -> Self {
  LocatedN3Token(token, range)
}

///|
pub impl Show for LocatedN3Token with fn output(
  self : LocatedN3Token,
  f : &Logger,
) -> Unit {
  self.0.output(f)
}

///|
pub enum LocatedTokenOrLineJump {
  LocatedN3Token(LocatedN3Token)
  LineJump(Int) // 换行位置
  End // 文件结束位置
} derive(Debug)

///|
pub fn LocatedTokenOrLineJump::into_token(
  self : LocatedTokenOrLineJump,
) -> N3Token? {
  match self {
    LocatedTokenOrLineJump::LocatedN3Token(t) => Some(t.0)
    LocatedTokenOrLineJump::LineJump(_) => None
    LocatedTokenOrLineJump::End => None
  }
}

///|
pub fn LocatedTokenOrLineJump::range(self : LocatedTokenOrLineJump) -> Range? {
  match self {
    LocatedN3Token(t) => Some(t.1)
    LineJump(pos) => Some(Range::{ start: pos, end: pos })
    End => None
  }
}

///|
pub impl Show for LocatedTokenOrLineJump with fn output(
  self : LocatedTokenOrLineJump,
  f : &Logger,
) -> Unit {
  match self {
    LocatedTokenOrLineJump::LocatedN3Token(t) => t.output(f)
    LocatedTokenOrLineJump::LineJump(pos) => pos.output(f)
    LocatedTokenOrLineJump::End => f.write_string("EOF")
  }
}

///|
// pub(all) enum Token {
//   Iri(String)
//   PnameLn(String)
//   PnameNs(String)
//   BlankNodeLabel(String)
//   StringLiteral1(String)
//   StringLiteral2(String)
//   StringLiteralLong1(String)
//   StringLiteralLong2(String)
//   LangDir(String)
//   Integer(String)
//   Decimal(String)
//   Double(String)
//   IntegerPositive(String)
//   DecimalPositive(String)
//   DoublePositive(String)
//   IntegerNegative(String)
//   DecimalNegative(String)
//   DoubleNegative(String)
//   Var1(String)
//   Var2(String)
//   Keyword(String)
//   Operator(String)
//   Error(String)
// } derive(Eq, Debug)

// ///|
// pub impl Show for Token with fn output(self : Token, f : &Logger) -> Unit {
//   match self {
//     Token::Iri(v)
//     | Token::PnameLn(v)
//     | Token::PnameNs(v)
//     | Token::BlankNodeLabel(v)
//     | Token::StringLiteral1(v)
//     | Token::StringLiteral2(v)
//     | Token::StringLiteralLong1(v)
//     | Token::StringLiteralLong2(v)
//     | Token::LangDir(v)
//     | Token::Var1(v)
//     | Token::Var2(v)
//     | Token::Integer(v)
//     | Token::Decimal(v)
//     | Token::Double(v)
//     | Token::IntegerPositive(v)
//     | Token::DecimalPositive(v)
//     | Token::DoublePositive(v)
//     | Token::IntegerNegative(v)
//     | Token::DecimalNegative(v)
//     | Token::DoubleNegative(v)
//     | Token::Keyword(v)
//     | Token::Operator(v)
//     | Token::Error(v) => f.write_string(v)
//   }
// }

///|
pub(all) enum BaseDirection {
  Ltr
  Rtl
} derive(Eq, Debug, Hash, ToJson)

///|
pub impl Show for BaseDirection with fn to_string(self) {
  match self {
    BaseDirection::Ltr => "ltr"
    BaseDirection::Rtl => "rtl"
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
    N3Token::BlankNodeLabel(v) => {
      f.write("_:")
      f.write(v)
    }
    N3Token::String(v) | N3Token::LongString(v) => {
      f.write("\"")
      f.write(v) // 注意：如果 v 包含引号，可能需要转义，但调试用通常直接写
      f.write("\"")
    }
    N3Token::Integer(v) | N3Token::Decimal(v) | N3Token::Double(v) => f.write(v)
    N3Token::LangTag(language~, direction~) => {
      f.write("@")
      f.write(language)
      match direction {
        Some(BaseDirection::Ltr) => f.write(";ltr")
        Some(BaseDirection::Rtl) => f.write(";rtl")
        None => ()
      }
    }
    N3Token::Punctuation(punct) => f.write(punct)
    N3Token::PlainKeyword(keyword) => f.write(keyword)
    // N3Token::Literal(literal) => f.write(literal)
  }
}
