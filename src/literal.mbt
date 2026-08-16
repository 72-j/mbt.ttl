// ============================================================
// RDF 字面量 - RDF 1.1 语义
// ============================================================

///|
/// RDF 字面量
pub(all) struct Literal(LiteralContent) derive(Eq, Debug, Hash)

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
/// IRI 节点 (拥有所有权)
pub(all) struct NamedNode {
  iri : String
} derive(Debug, Eq, Hash, Default)

///|
pub impl Show for NamedNode with fn output(self, logger) {
  logger.write(self.iri)
}

///|
/// 创建 NamedNodeRef (不验证)
pub fn NamedNode::new_unchecked(iri : StringView) -> NamedNodeRef {
  NamedNodeRef::{ iri, }
}

///|
/// 转_owned
pub fn NamedNodeRef::into_owned(self : NamedNodeRef) -> NamedNode {
  NamedNode::{ iri: self.iri.to_owned() }
}

///|
/// as_ref
pub fn NamedNode::as_ref(self : NamedNode) -> NamedNodeRef {
  NamedNodeRef::{ iri: self.iri }
}

///|
pub impl Show for Literal with fn to_string(self) {
  let f = StringBuilder::new()
  match self.0 {
    LiteralContent::String(value) => {
      append_escaped_str(f, value)
      f.to_string()
    }
    LiteralContent::LanguageTaggedString(value~, language~) => {
      append_escaped_str(f, value)
      f.write("@")
      f.write(language)
      f.to_string()
    }
    LiteralContent::DirectionalLanguageTaggedString(
      value~,
      language~,
      direction~
    ) => {
      append_escaped_str(f, value)
      f.write("@")
      f.write(language)
      f.write("-")
      f.write(direction)
      f.to_string()
    }
    LiteralContent::TypedLiteral(value~, datatype~) => {
      append_escaped_str(f, value)
      f.write("^^")
      f.write(datatype)
      f.to_string()
    }
  }
}

///|
/// 字面量内容
pub(all) enum LiteralContent {
  String(String) // 简单字符串
  LanguageTaggedString(value~ : String, language~ : String) // 带语言标签
  DirectionalLanguageTaggedString(
    value~ : StringView,
    language~ : String,
    direction~ : BaseDirection
  )
  TypedLiteral(value~ : String, datatype~ : NamedNode) // 带类型
} derive(Eq, Debug, Hash)

///|
/// 创建简单字面量
pub fn Literal::new_simple_literal(value : String) -> Literal {
  LiteralContent::String(value)
}

///|
/// 创建语言标签字面量 (验证语言标签)
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
/// 创建语言标签字面量 (不验证)
pub fn Literal::new_language_tagged_literal_unchecked(
  value : String,
  language : String,
) -> Literal {
  LiteralContent::LanguageTaggedString(value~, language~)
}

///|
/// 创建带方向的语言标签字面量 (验证语言标签)
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
}

///|
/// 创建带方向的语言标签字面量 (不验证)
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
/// 获取字面量值
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
/// 获取语言标签
pub fn Literal::language(self : Literal) -> String? {
  match self.0 {
    LiteralContent::LanguageTaggedString(language~, ..) => Some(language)
    LiteralContent::DirectionalLanguageTaggedString(language~, ..) =>
      Some(language)
    _ => None
  }
}

///|
/// 获取文本方向
pub fn Literal::direction(self : Literal) -> BaseDirection? {
  match self.0 {
    LiteralContent::DirectionalLanguageTaggedString(direction~, ..) =>
      Some(direction)
    _ => None
  }
}

///|
/// 获取数据类型
pub fn Literal::datatype(self : Literal) -> NamedNodeRef {
  match self.0 {
    LiteralContent::LanguageTaggedString(..) => rdf_lang_string
    LiteralContent::DirectionalLanguageTaggedString(..) => rdf_dir_lang_string
    LiteralContent::String(_) => rdf_string
    LiteralContent::TypedLiteral(datatype~, ..) => datatype.as_ref()
  }
}

///|
/// 分解为 (值, 数据类型, 语言, 方向)
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
/// 字面量引用 (无所有权)
pub(all) struct LiteralRef(LiteralRefContent) derive(Eq, Debug, Hash)

///|
/// 字面量引用内容
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
pub fn Literal::new_simple_literal_unchecked(value : String) -> Literal {
  Literal(LiteralContent::String(value))
}

///|
/// 创建类型字面量 (优化: string 直接用 String 类型)
pub fn Literal::new_typed_literal_unchecked(
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
/// 获取数据类型
pub fn LiteralRef::datatype(self : LiteralRef) -> NamedNodeRef {
  match self.0 {
    LiteralRefContent::String(_) => rdf_string
    LiteralRefContent::LanguageTaggedString(..) => rdf_lang_string
    LiteralRefContent::DirectionalLanguageTaggedString(..) =>
      rdf_dir_lang_string
    LiteralRefContent::TypedLiteral(datatype~, ..) => datatype
  }
}

///|
/// 转_owned
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
pub impl Show for LiteralRef with fn to_string(self) {
  let f = StringBuilder::new()
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
      f.write("^")
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
pub fn append_escaped_str(f : StringBuilder, string : StringView) -> Unit {
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
