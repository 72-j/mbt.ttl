///|
pub(all) struct Literal(LiteralContent) derive(Eq, Debug, Hash)

///|
pub(all) struct NamedNodeRef {
  iri : StringView
} derive(Debug, Eq, Hash)

///|
pub impl Show for NamedNodeRef with fn output(
  self : NamedNodeRef,
  logger : &Logger,
) -> Unit {
  logger.write(self.iri)
}

///|
pub(all) struct NamedNode {
  iri : String
} derive(Debug, Eq, Hash, Default)

///|
pub impl Show for NamedNode with fn output(self : NamedNode, logger : &Logger) -> Unit {
  logger.write(self.iri)
}

///|
pub fn NamedNodeRef::new_unchecked(iri : StringView) -> NamedNodeRef {
  NamedNodeRef::{ iri, }
}

///|
pub fn NamedNodeRef::into_owned(self : NamedNodeRef) -> NamedNode {
  NamedNode::{ iri: self.iri.to_owned() }
}

///|
pub fn NamedNode::as_ref(self : NamedNode) -> NamedNodeRef {
  NamedNodeRef::{ iri: self.iri }
}

///|
pub impl Show for Literal with fn to_string(self : Literal) -> String {
  let f = StringBuilder::new()
  match self.0 {
    LiteralContent::String(value) => print_quoted_str(f, value)
    LiteralContent::LanguageTaggedString(value~, language~) => {
      let _ = print_quoted_str(f, value)
      f.write("@")
      f.write(language)
      f.to_string()
      // write(f , "@{language}")
    }
    LiteralContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~
    ) => {
      let _ = print_quoted_str(f, value)
      f.write("@")
      f.write(language)
      f.write("-")
      f.write(direction)
      f.to_string()
    }
    LiteralContent::TypedLiteral(value~, datatype~) => {
      let _ = print_quoted_str(f, value)
      f.write("^^")
      f.write(datatype)
      f.to_string()
    }
  }
}

///|
pub(all) enum LiteralContent {
  String(String)
  LanguageTaggedString(value~ : String, language~ : String)
  DirectionalLanguageTaggedString(
    value~ : StringView,
    language~ : String,
    direction~ : BaseDirection
  )
  TypedLiteral(value~ : String, datatype~ : NamedNode)
} derive(Eq, Debug, Hash)

///|
pub fn Literal::new_simple_literal(value : String) -> Literal {
  LiteralContent::String(value)
}

///|
pub fn Literal::new_language_tagged_literal(
  value : String,
  language : String,
) -> Result[Literal, TagParseErr] {
  let language = String::to_lower(language)
  match LanguageTag::parse(language) {
    Ok(lang_tag) =>
      Ok(
        Literal::new_language_tagged_literal_unchecked(
          value,
          lang_tag.to_tagstr(),
        ),
      )
    Err(e) => Err(e)
  }
}

///|
pub fn Literal::new_language_tagged_literal_unchecked(
  value : String,
  language : String,
) -> Literal {
  LiteralContent::LanguageTaggedString(value~, language~)
}

///|
pub fn Literal::new_directional_language_tagged_literal(
  value : String,
  language : String,
  direction : BaseDirection,
) -> Result[Literal, TagParseErr] {
  let language = String::to_lower(language)
  match LanguageTag::parse(language) {
    Ok(lang_tag) =>
      Ok(
        Literal::new_directional_language_tagged_literal_unchecked(
          value, lang_tag, direction,
        ),
      )
    Err(e) => Err(e)
  }
  // Ok(Literal::new_directional_language_tagged_literal_unchecked(value, LanguageTag::parse(language), direction))
}

///|
pub fn Literal::new_directional_language_tagged_literal_unchecked(
  value : StringView,
  language : LanguageTag,
  direction : BaseDirection,
) -> Literal {
  LiteralContent::DirectionalLanguageTaggedString(
    value~,
    language=language.to_tagstr(),
    direction~,
  )
}

///|
pub fn Literal::value(self : Literal) -> String {
  match self.0 {
    LiteralContent::String(value)
    | LiteralContent::LanguageTaggedString(value~, ..) => value
    LiteralContent::TypedLiteral(value~, ..) => value
    LiteralContent::DirectionalLanguageTaggedString(value~, ..) =>
      value.to_owned()
  }
}

///|
pub fn Literal::language(self : Literal) -> String? {
  match self.0 {
    LiteralContent::LanguageTaggedString(language~, ..) =>
      // self.language()
      Some(language)
    LiteralContent::DirectionalLanguageTaggedString(language~, ..) =>
      // self.language()
      Some(language)
    _ => None
  }
  // self.language()
}

///|
pub fn Literal::direction(self : Literal) -> BaseDirection? {
  match self.0 {
    LiteralContent::DirectionalLanguageTaggedString(direction~, ..) =>
      // self.direction()
      Some(direction)
    _ => None
  }
  // self.direction()
}

///|
pub fn Literal::datatype(self : Literal) -> NamedNodeRef {
  match self.0 {
    LiteralContent::LanguageTaggedString(..) => lwLANG_STRING
    LiteralContent::DirectionalLanguageTaggedString(..) => lwDIR_LANG_STRING
    LiteralContent::String(_) => lwSTRING
    LiteralContent::TypedLiteral(datatype~, ..) => datatype.as_ref()
  }
}

///|
pub fn Literal::as_ref(self : Literal) -> LiteralRef {
  LiteralRef(
    match self.0 {
      LiteralContent::String(value) => LiteralRefContent::String(value)
      LiteralContent::LanguageTaggedString(value~, language~) =>
        LiteralRefContent::LanguageTaggedString(value~, language~)
      LiteralContent::DirectionalLanguageTaggedString(
        value~,
        language~,
        direction~
      ) =>
        LiteralRefContent::DirectionalLanguageTaggedString(
          value~,
          language~,
          direction~,
        )
      LiteralContent::TypedLiteral(value~, datatype~) =>
        LiteralRefContent::TypedLiteral(value~, datatype=datatype.as_ref())
    },
  )
}

///|
pub fn Literal::destruct(
  self : Literal,
) -> (StringView, NamedNode?, String?, BaseDirection?) {
  match self.0 {
    LiteralContent::String(s) => (s, None, None, None)
    LiteralContent::LanguageTaggedString(value~, language~) =>
      (value, None, Some(language), None)
    LiteralContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~
    ) => (value, None, Some(language), Some(direction))
    LiteralContent::TypedLiteral(value~, datatype~) =>
      (value, Some(datatype), None, None)
  }
}

///|
pub(all) struct LiteralRef(LiteralRefContent) derive(Eq, Debug, Hash)

///|
pub(all) enum LiteralRefContent {
  String(StringView)
  LanguageTaggedString(value~ : String, language~ : StringView)
  DirectionalLanguageTaggedString(
    value~ : StringView,
    language~ : StringView,
    direction~ : BaseDirection
  )
  TypedLiteral(value~ : String, datatype~ : NamedNodeRef)
} derive(Eq, Debug, Hash)

///|
pub fn LiteralRef::into_value(self : LiteralRef) -> StringView {
  match self.0 {
    LiteralRefContent::String(s) => s
    LiteralRefContent::LanguageTaggedString(value~, ..) => value
    LiteralRefContent::DirectionalLanguageTaggedString(value~, ..) => value
    LiteralRefContent::TypedLiteral(value~, ..) => value
  }
}

///|
pub fn LiteralRef::new_simple_literal(value : StringView) -> LiteralRef {
  LiteralRef(LiteralRefContent::String(value))
}

///|
// pub fn LiteralRef::as_term(self : Self) -> TermRef {
//   TermRef::LiteralRef(self)
// }

///|
pub fn LiteralRef::new_typed_literal(
  value : String,
  datatype : NamedNodeRef,
) -> LiteralRef {
  LiteralRef(
    if datatype == lwSTRING {
      LiteralRefContent::String(value)
    } else {
      LiteralRefContent::TypedLiteral(value~, datatype~)
    },
  )
}

///|
pub fn LiteralRef::new_language_tagged_literal_unchecked(
  value : String,
  language : StringView,
) -> LiteralRef {
  LiteralRef(LiteralRefContent::LanguageTaggedString(value~, language~))
}

///|
pub fn LiteralRef::new_directional_language_tagged_literal_unchecked(
  value : String,
  language : LanguageTag,
  direction : BaseDirection,
) -> LiteralRef {
  LiteralRef(
    LiteralRefContent::DirectionalLanguageTaggedString(
      value~,
      language=language.to_tagstr(),
      direction~,
    ),
  )
}

///|
pub fn LiteralRef::language(self : LiteralRef) -> String? {
  match self.0 {
    LiteralRefContent::LanguageTaggedString(language~, ..) =>
      Some(language.to_owned())
    LiteralRefContent::DirectionalLanguageTaggedString(language~, ..) =>
      Some(language.to_owned())
    _ => None
  }
}

///|
pub fn LiteralRef::direction(self : LiteralRef) -> BaseDirection? {
  match self.0 {
    LiteralRefContent::DirectionalLanguageTaggedString(direction~, ..) =>
      Some(direction)
    _ => None
  }
}

///|
pub fn LiteralRef::datatype(self : LiteralRef) -> NamedNodeRef {
  match self.0 {
    LiteralRefContent::String(_) => lwSTRING
    LiteralRefContent::LanguageTaggedString(..) => lwLANG_STRING
    LiteralRefContent::DirectionalLanguageTaggedString(..) => lwDIR_LANG_STRING
    LiteralRefContent::TypedLiteral(datatype~, ..) => datatype
  }
}

///|
pub fn LiteralRef::into_owned(self : LiteralRef) -> Literal {
  Literal(
    match self.0 {
      LiteralRefContent::String(value) =>
        LiteralContent::String(value.to_owned())
      LiteralRefContent::LanguageTaggedString(value~, language~) =>
        LiteralContent::LanguageTaggedString(
          value~,
          language=language.to_owned(),
        )
      LiteralRefContent::DirectionalLanguageTaggedString(
        value~,
        language~,
        direction~
      ) =>
        LiteralContent::DirectionalLanguageTaggedString(
          value=value.to_owned(),
          language=language.to_owned(),
          direction~,
        )
      LiteralRefContent::TypedLiteral(value~, datatype~) =>
        LiteralContent::TypedLiteral(value~, datatype=datatype.into_owned())
    },
  )
}

///|
pub impl Show for LiteralRef with fn to_string(self : LiteralRef) -> String {
  let f = StringBuilder::new()
  match self.0 {
    LiteralRefContent::String(value) => print_quoted_str(f, value.to_owned())
    LiteralRefContent::LanguageTaggedString(value~, language~) => {
      let _ = print_quoted_str(f, value)
      f.write("@")
      f.write(language)
      f.to_string()
      // write(f , "@{language}")
    }
    LiteralRefContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~
    ) => {
      let _ = print_quoted_str(f, value.to_owned())
      f.write("@")
      f.write(language)
      f.write("^")
      f.write(direction)
      f.to_string()
    }
    LiteralRefContent::TypedLiteral(value~, datatype~) => {
      let _ = print_quoted_str(f, value)
      f.write("^^")
      f.write(datatype)
      f.to_string()
    }
  }
}

///|
pub fn print_quoted_str(f : StringBuilder, string : StringView) -> String {
  // f.write('\"')
  for c in string {
    let code = Char::to_uint(c)
    match c {
      '\u{08}' => f.write("\\b")
      '\t' => f.write("\\t")
      '\n' => f.write("\\n")
      '\u{0C}' => f.write("\\f")
      '\r' => f.write("\\r")
      // '"' => f.write("\"")
      // '\\' => f.write("\\")
      _ if code <= 0x1F || code == 0x7F || code == 0xFFFE || code == 0xFFFF =>
        f.write("\\u\{code.lpad(4, '0')}") // 假设 code 已转为 UInt16
      _ if code >= 0x10000 => f.write("\\U\{code.lpad(8, '0')}")
      _ => f.write_char(c)
    }
  }
  // f.write('\"')
  f.to_string()
}

///|
fn UInt::lpad(self : UInt, width : Int, char : Char) -> String {
  let s = self.to_hex_string()
  let pad_count = width - s.length()
  if pad_count <= 0 {
    return s
  }
  String::make(pad_count, char) + s
}

///|
fn UInt::to_hex_string(self : UInt) -> String {
  if self == 0 {
    return "0"
  }
  let chars : Array[Char] = []
  let mut n = self
  while n > 0 {
    let digit = n % 16
    chars.push(digit_to_hex_char(digit))
    n = n / 16
  }
  let sb = StringBuilder::new()
  let rev_chars = chars.rev()
  for c in rev_chars {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn digit_to_hex_char(d : UInt) -> Char {
  if d < 10 {
    (d + 48).to_uint16().to_char().unwrap() // '0' = 48
  } else {
    (d - 10 + 65).to_uint16().to_char().unwrap()
  } // 'A' = 65
}
