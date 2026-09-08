// ============================================================
// RDF 字面量 - RDF 1.1 语义
// ============================================================

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
/// IRI 引用
pub(all) struct NamedNodeRef {
  iri : StringView
} derive(Debug, Eq, Hash)

///|
pub impl Show for NamedNodeRef with fn output(self, logger) {
  logger.write(self.iri)
}

///|
/// 创建 NamedNodeRef (不验证)
pub fn NamedNodeRef::new_unchecked(iri : StringView) -> NamedNodeRef {
  NamedNodeRef::{ iri, }
}

///|
/// 字面量引用 (无所有权)
pub(all) struct LiteralRef(LiteralRefContent) derive(Eq, Debug, Hash)

///|
/// 字面量引用内容
pub(all) enum LiteralRefContent {
  String(StringView)
  LanguageTaggedString(value~ : StringView, language~ : StringView)
  DirectionalLanguageTaggedString(
    value~ : StringView,
    language~ : StringView,
    direction~ : BaseDirection
  )
  TypedLiteral(value~ : StringView, datatype~ : NamedNodeRef)
} derive(Eq, Debug, Hash)

///|
/// 创建简单字面量
pub fn LiteralRef::new_simple_literal(value : String) -> LiteralRef {
  LiteralRef(LiteralRefContent::String(value))
}

///|
/// 创建语言标签字面量 (验证语言标签)
pub fn LiteralRef::new_language_tagged_literal(
  value : String,
  language : String,
) -> Result[LiteralRef, TagParseErr] {
  let language = String::to_lower(language)
  match LanguageTag::parse(language) {
    Ok(lang_tag) =>
      Ok(
        LiteralRef::new_language_tagged_literal_unchecked(
          value,
          lang_tag.to_tagstr(),
        ),
      )
    Err(e) => Err(e)
  }
}

///|
/// 创建语言标签字面量 (不验证)
pub fn LiteralRef::new_language_tagged_literal_unchecked(
  value : String,
  language : String,
) -> LiteralRef {
  LiteralRef(LiteralRefContent::LanguageTaggedString(value~, language~))
}

///|
/// 创建带方向的语言标签字面量 (验证语言标签)
pub fn LiteralRef::new_directional_language_tagged_literal(
  value : String,
  language : String,
  direction : BaseDirection,
) -> Result[LiteralRef, TagParseErr] {
  let language = String::to_lower(language)
  match LanguageTag::parse(language) {
    Ok(lang_tag) =>
      Ok(
        LiteralRef::new_directional_language_tagged_literal_unchecked(
          value, lang_tag, direction,
        ),
      )
    Err(e) => Err(e)
  }
}

///|
/// 创建带方向的语言标签字面量 (不验证)
pub fn LiteralRef::new_directional_language_tagged_literal_unchecked(
  value : StringView,
  language : LanguageTag,
  direction : BaseDirection,
) -> LiteralRef {
  let language = language.to_tagstr()
  LiteralRef(
    LiteralRefContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~,
    ),
  )
}

///|
/// 获取字面量值
pub fn LiteralRef::value(self : LiteralRef) -> StringView {
  match self.0 {
    LiteralRefContent::String(value)
    | LiteralRefContent::LanguageTaggedString(value~, ..) => value
    LiteralRefContent::TypedLiteral(value~, ..) => value
    LiteralRefContent::DirectionalLanguageTaggedString(value~, ..) =>
      value.to_owned()
  }
}

///|
/// 获取语言标签
pub fn LiteralRef::language(self : LiteralRef) -> StringView? {
  match self.0 {
    LiteralRefContent::LanguageTaggedString(language~, ..) => Some(language)
    LiteralRefContent::DirectionalLanguageTaggedString(language~, ..) =>
      Some(language)
    _ => None
  }
}

///|
/// 获取文本方向
pub fn LiteralRef::direction(self : LiteralRef) -> BaseDirection? {
  match self.0 {
    LiteralRefContent::DirectionalLanguageTaggedString(direction~, ..) =>
      Some(direction)
    _ => None
  }
}

///|
/// 获取数据类型
pub fn LiteralRef::datatype(self : LiteralRef) -> NamedNodeRef {
  match self.0 {
    LiteralRefContent::LanguageTaggedString(..) => rdf_lang_string
    LiteralRefContent::DirectionalLanguageTaggedString(..) =>
      rdf_dir_lang_string
    LiteralRefContent::String(_) => rdf_string
    LiteralRefContent::TypedLiteral(datatype~, ..) => datatype
  }
}

///|
/// 分解为 (值, 数据类型, 语言, 方向)
pub fn LiteralRef::destruct(
  self : LiteralRef,
) -> (StringView, NamedNodeRef?, StringView?, BaseDirection?) {
  match self.0 {
    LiteralRefContent::String(s) => (s, None, None, None)
    LiteralRefContent::LanguageTaggedString(value~, language~) =>
      (value, None, Some(language), None)
    LiteralRefContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~
    ) => (value, None, Some(language), Some(direction))
    LiteralRefContent::TypedLiteral(value~, datatype~) =>
      (value, Some(datatype), None, None)
  }
}

///|
/// 获取字面量值
pub fn LiteralRef::as_value(self : LiteralRef) -> StringView {
  match self.0 {
    LiteralRefContent::String(s) => s
    LiteralRefContent::LanguageTaggedString(value~, ..) => value
    LiteralRefContent::DirectionalLanguageTaggedString(value~, ..) => value
    LiteralRefContent::TypedLiteral(value~, ..) => value
  }
}

///|
/// 创建简单字面量 (不验证)
pub fn LiteralRef::new_simple_literal_unchecked(value : String) -> LiteralRef {
  LiteralRef(LiteralRefContent::String(value))
}

///|
/// 创建类型字面量 (优化: string 直接用 String 类型)
pub fn LiteralRef::new_typed_literal_unchecked(
  value : String,
  datatype : NamedNodeRef,
) -> LiteralRef {
  LiteralRef(
    if datatype == rdf_string {
      LiteralRefContent::String(value)
    } else {
      LiteralRefContent::TypedLiteral(value~, datatype~)
    },
  )
}

///|
pub impl Show for LiteralRef with fn to_string(self) {
  let f = StringBuilder()
  match self.0 {
    LiteralRefContent::String(value) => {
      append_escaped_str(f, value)
      f.to_string()
    }
    LiteralRefContent::LanguageTaggedString(value~, language~) => {
      append_escaped_str(f, value)
      f.write("@")
      f.write(language)
      f.to_string()
    }
    LiteralRefContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~
    ) => {
      append_escaped_str(f, value.to_owned())
      f.write("@")
      f.write(language)
      f.write("-")
      f.write(direction)
      f.to_string()
    }
    LiteralRefContent::TypedLiteral(value~, datatype~) => {
      append_escaped_str(f, value)
      f.write("^^")
      f.write(datatype)
      f.to_string()
    }
  }
}

///|
/// 转义 N-Triples 特殊字符
fn append_escaped_str(f : StringBuilder, string : StringView) -> Unit {
  for c in string {
    let code = Char::to_uint(c)
    match c {
      '\u{08}' => f.write("\\b")
      '\t' => f.write("\\t")
      '\n' => f.write("\\n")
      '\u{0C}' => f.write("\\f")
      '\r' => f.write("\\r")
      _ if code <= 0x1F || code >= 0x80 =>
        f.write("\\u\{code.to_byte().to_hex().lpad(4, '0')}")
      _ => f.write_char(c)
    }
  }
}

///|
/// 左侧填充
fn String::lpad(self : String, width : Int, char : Char) -> String {
  let pad_count = width - self.length()
  if pad_count <= 0 {
    return self
  }
  String::make(pad_count, char) + self
}
