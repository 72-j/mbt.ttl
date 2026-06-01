///|
pub(all) enum TokenOrLineJump[T] {
  Token(T)
  // N3Token(T)
  LineJump
} derive(Eq, Debug)

///|
impl Show for TokenOrLineJump[N3Token] with fn output(
  self : TokenOrLineJump[N3Token],
  f : &Logger,
) -> Unit {
  match self {
    TokenOrLineJump::Token(t) => t.output(f)
    TokenOrLineJump::LineJump => f.write_string("\\n")
  }
}

///|
pub fn[T] TokenOrLineJump::into_token(self : TokenOrLineJump[T]) -> T? {
  match self {
    TokenOrLineJump::Token(t) => Some(t)
    TokenOrLineJump::LineJump => None
  }
}

///|
pub(all) enum Token {
  Iri(String)
  PnameLn(String)
  PnameNs(String)
  BlankNodeLabel(String)
  StringLiteral1(String)
  StringLiteral2(String)
  StringLiteralLong1(String)
  StringLiteralLong2(String)
  LangDir(String)
  Integer(String)
  Decimal(String)
  Double(String)
  IntegerPositive(String)
  DecimalPositive(String)
  DoublePositive(String)
  IntegerNegative(String)
  DecimalNegative(String)
  DoubleNegative(String)
  Var1(String)
  Var2(String)
  Keyword(String)
  Operator(String)
  Error(String)
} derive(Eq, Debug)

///|
pub impl Show for Token with fn output(self : Token, f : &Logger) -> Unit {
  match self {
    Token::Iri(v)
    | Token::PnameLn(v)
    | Token::PnameNs(v)
    | Token::BlankNodeLabel(v)
    | Token::StringLiteral1(v)
    | Token::StringLiteral2(v)
    | Token::StringLiteralLong1(v)
    | Token::StringLiteralLong2(v)
    | Token::LangDir(v)
    | Token::Var1(v)
    | Token::Var2(v)
    | Token::Integer(v)
    | Token::Decimal(v)
    | Token::Double(v)
    | Token::IntegerPositive(v)
    | Token::DecimalPositive(v)
    | Token::DoublePositive(v)
    | Token::IntegerNegative(v)
    | Token::DecimalNegative(v)
    | Token::DoubleNegative(v)
    | Token::Keyword(v)
    | Token::Operator(v)
    | Token::Error(v) => f.write_string(v)
  }
}

///|
pub enum BaseDirection {
  Ltr
  Rtl
} derive(Eq, Debug, Hash)

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
} derive(Debug, Eq)

///|
pub impl Show for N3Token with fn output(self : N3Token, f : &Logger) -> Unit {
  match self {
    Iri(iri) => f.write(iri)
    PrefixedName(prefix~, localx~, might_be_invalid_iri~) => {
      f.write(prefix)
      f.write(":")
      f.write(localx)
      if might_be_invalid_iri {
        f.write(" (invalid IRI)")
      }
    }
    Punctuation(punct) => f.write(punct)
    PlainKeyword(keyword) => f.write(keyword)
    _ => ()
  }
}
