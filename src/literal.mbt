///|
pub struct Literal(LiteralContent) derive(Eq, Debug, Hash)

///|
// impl Show for Literal with fn output(self : Literal, f : &Logger) -> Unit {
//   match self.0 {
//     LiteralContent::String(value) => {
//       f.write("\"")
//       f.write_string(value)
//       f.write("\"")
//     }
//     LiteralContent::LanguageTaggedString(value~, language~) => {
//       f.write_string(value)
//       f.write("@")
//       f.write_string(language)
//     }
//     LiteralContent::DirectionalLanguageTaggedString(
//       value~,
//       language~,
//       direction~
//     ) => {
//       f.write_string(value)
//       f.write("@")
//       f.write_string(language)
//       f.write("^")
//       f.write_string(direction.to_string())
//     }
//     LiteralContent::TypedLiteral(value~, datatype~) => {
//       f.write_string(value.to_string())
//       f.write("^^")
//       f.write_string(datatype.as_stringview().to_string())
//     }
//   }
// }
impl Show for Literal with fn to_string(self : Literal) -> String {
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
      f.write("^")
      f.write(direction)
      f.to_string()
    }
    LiteralContent::TypedLiteral(value~, datatype~) => {
      let _ = print_quoted_str(f, value.to_string())
      f.write("^^")
      f.write(datatype)
      f.to_string()
    }
  }
}

///|
enum LiteralContent {
  String(String)
  LanguageTaggedString(value~ : String, language~ : String)
  DirectionalLanguageTaggedString(
    value~ : String,
    language~ : String,
    direction~ : BaseDirection
  )
  TypedLiteral(value~ : VarDataType, datatype~ : NamedNode)
} derive(Eq, Debug, Hash)

///|
pub fn Literal::new_simple_literal(value : String) -> Literal {
  LiteralContent::String(value)
}

///|
pub fn Literal::new_typed_literal(
  value : VarDataType,
  datatype : NamedNode,
) -> Literal {
  let value = value
  let datatype = datatype
  Literal(
    if datatype == lwSTRING {
      LiteralContent::String(value.to_string())
    } else {
      LiteralContent::TypedLiteral(value~, datatype~)
    },
  )
}

///|
pub fn Literal::new_language_tagged_literal(
  value : String,
  language : String,
) -> Result[Literal, LanguageTagParseError] {
  let language = String::to_lower(language)
  match LanguageTag::parse(language) {
    Ok(lang_tag) =>
      // 假设 LanguageTag 实现了 ToString trait，或者通过 .to_string() 方法获取其字符串表示
      // 如果 LanguageTag 是一个 struct 且其原始字符串被保留，可能需要访问特定字段
      // 这里使用通用的 .to_string() 进行转换
      Ok(
        Literal::new_language_tagged_literal_unchecked(
          value,
          lang_tag.into_inner(),
        ),
      )
    Err(e) => Err(LanguageTagParseError::TagParseErr(e))
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
) -> Result[Literal, LanguageTagParseError] {
  let language = String::to_lower(language)
  match LanguageTag::parse(language) {
    Ok(lang_tag) =>
      // 假设 LanguageTag 实现了 ToString trait，或者通过 .to_string() 方法获取其字符串表示
      // 如果 LanguageTag 是一个 struct 且其原始字符串被保留，可能需要访问特定字段
      // 这里使用通用的 .to_string() 进行转换
      Ok(
        Literal::new_directional_language_tagged_literal_unchecked(
          value, lang_tag, direction,
        ),
      )
    Err(e) => Err(LanguageTagParseError::TagParseErr(e))
  }
  // Ok(Literal::new_directional_language_tagged_literal_unchecked(value, LanguageTag::parse(language), direction))
}

///|
pub fn Literal::new_directional_language_tagged_literal_unchecked(
  value : String,
  language : LanguageTag,
  direction : BaseDirection,
) -> Literal {
  LiteralContent::DirectionalLanguageTaggedString(
    value~,
    language=language.into_inner(),
    direction~,
  )
}

///|
// pub fn Literal::value(self : Literal) -> String {
//   self.value()
// }

///|
pub fn Literal::value(self : Literal) -> String {
  match self.0 {
    LiteralContent::String(value)
    | LiteralContent::LanguageTaggedString(value~, ..) => value
    LiteralContent::TypedLiteral(value~, ..) => value.to_string()
    LiteralContent::DirectionalLanguageTaggedString(value~, ..) => value
  }
}

///|
pub fn Literal::language(self : Literal) -> String? {
  self.language()
}

///|
pub fn Literal::direction(self : Literal) -> BaseDirection? {
  self.direction()
}

///|
pub fn Literal::datatype(self : Literal) -> NamedNodeRef {
  match self.0 {
    LiteralContent::LanguageTaggedString(..) => lwLANG_STRING.as_stringview()
    LiteralContent::DirectionalLanguageTaggedString(..) =>
      lwDIR_LANG_STRING.as_stringview()
    LiteralContent::String(_) => lwSTRING.as_stringview()
    LiteralContent::TypedLiteral(datatype~, ..) => datatype.as_stringview()
  }
}

///|
pub fn Literal::as_stringview(self : Literal) -> LiteralRef {
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
        LiteralRefContent::TypedLiteral(
          value~,
          datatype=datatype.as_stringview(),
        )
    },
  )
}

///|
pub fn Literal::destruct(
  self : Literal,
) -> (String, NamedNode?, String?, BaseDirection?) {
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
      (value.to_string(), Some(datatype), None, None)
  }
}

///|
pub struct LiteralRef(LiteralRefContent) derive(Eq, Debug, Hash)

///|
enum LiteralRefContent {
  String(StringView)
  LanguageTaggedString(value~ : String, language~ : StringView)
  DirectionalLanguageTaggedString(
    value~ : StringView,
    language~ : StringView,
    direction~ : BaseDirection
  )
  TypedLiteral(value~ : VarDataType, datatype~ : NamedNodeRef)
} derive(Eq, Debug, Hash)

///|
pub fn LiteralRef::new_simple_literal(value : StringView) -> LiteralRef {
  LiteralRef(LiteralRefContent::String(value))
}

///|
pub fn LiteralRef::to_owned(self : LiteralRef) -> Literal {
  match self.0 {
    LiteralRefContent::String(v) => Literal::new_simple_literal(v.to_owned())
    LiteralRefContent::LanguageTaggedString(value~, language~) =>
      Literal::new_language_tagged_literal_unchecked(value, language.to_owned())
    LiteralRefContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~
    ) =>
      Literal::new_directional_language_tagged_literal_unchecked(
        value.to_owned(),
        LanguageTag::parse(language.to_owned()).unwrap(),
        direction,
      )
    _ => panic()
  }
}

///|
pub fn LiteralRef::new_typed_literal(
  value : VarDataType,
  datatype : NamedNodeRef,
) -> LiteralRef {
  LiteralRef(
    if datatype == lwSTRING.as_stringview() {
      LiteralRefContent::String(value.to_string())
    } else {
      LiteralRefContent::TypedLiteral(value~, datatype~)
    },
  )
}

///|
pub fn LiteralRef::new_language_tagged_literal_unchecked(
  value : String,
  language : String,
) -> LiteralRef {
  LiteralRef(LiteralRefContent::LanguageTaggedString(value~, language~))
}

///|
pub fn LiteralRef::new_directional_language_tagged_literal_unchecked(
  value : String,
  language : String,
  direction : BaseDirection,
) -> LiteralRef {
  LiteralRef(
    LiteralRefContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~,
    ),
  )
}

///|
pub fn LiteralRef::into_value(self : LiteralRef) -> String {
  match self.0 {
    LiteralRefContent::String(v) => v.to_owned()
    LiteralRefContent::LanguageTaggedString(value~, ..) => value
    LiteralRefContent::TypedLiteral(value~, ..) => value.to_string()
    LiteralRefContent::DirectionalLanguageTaggedString(value~, ..) =>
      value.to_owned()
  }
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
    LiteralRefContent::String(_) => lwSTRING.as_stringview()
    LiteralRefContent::LanguageTaggedString(..) => lwLANG_STRING.as_stringview()
    LiteralRefContent::DirectionalLanguageTaggedString(..) =>
      lwDIR_LANG_STRING.as_stringview()
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
impl Show for LiteralRef with fn to_string(self : LiteralRef) -> String {
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
      let _ = print_quoted_str(f, value.to_string())
      f.write("^^")
      f.write(datatype)
      f.to_string()
    }
  }
}

///|
pub fn print_quoted_str(f : StringBuilder, string : String) -> String {
  f.write('\"')
  for c in string {
    let code = Char::to_int(c)
    match c {
      '\u{08}' => f.write("\\b")
      '\t' => f.write("\\t")
      '\n' => f.write("\\n")
      '\u{0C}' => f.write("\\f")
      '\r' => f.write("\\r")
      '"' => f.write("\\\"")
      '\\' => f.write("\\\\")
      _ if code <= 0x1F || code == 0x7F || code == 0xFFFE || code == 0xFFFF =>
        f.write("\\u{:04X}\{code}")
      _ => f.write_char(c)
    }
  }
  f.write('\"').to_string()
}
