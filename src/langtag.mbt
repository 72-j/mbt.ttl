// ============================================================
// 类型定义
// ============================================================

///|
/// 子标签位置，左闭右开 [start, end)
pub type TagSpan = (Int, Int)

///|
/// 扩展 (单字符标识符 + 多个子标签)
/// 例如: u-nu-hanidec → ident='u', subtags=["nu", "hanidec"]
pub struct Extension {
  ident : TagSpan // 单字符标识符的位置
  subtags : Array[TagSpan] // 后续子标签
} derive(Debug, Eq)

///|
pub impl Show for Extension with fn output(self : Extension, logger : &Logger) -> Unit {
  logger.write("Extension:")
  logger.write("  { ")
  logger.write("    ident: ")
  logger.write(@debug.to_string(self.ident))
  logger.write(", ")
  logger.write("    subtags: ")
  logger.write(@debug.to_string(self.subtags))
  logger.write("  }")
}

///|
/// 私有使用 (x- 前缀 + 多个子标签)
/// 例如: x-mycorp-private → prefix='x', subtags=["mycorp", "private"]
pub struct PrivateUse {
  prefix : TagSpan // "x" 的位置
  subtags : Array[TagSpan]
} derive(Debug, Eq)

///|
pub impl Show for PrivateUse with fn output(self : PrivateUse, logger : &Logger) -> Unit {
  logger.write("PrivateUse:")
  logger.write("  { ")
  logger.write("    prefix: ")
  logger.write(@debug.to_string(self.prefix))
  logger.write(", ")
  logger.write("    subtags: ")
  logger.write(@debug.to_string(self.subtags))
  logger.write("  }")
}

///|
/// 语言标签 (RFC 5646 / BCP 47)
/// 结构: language ["-" extlang] ["-" script] ["-" region] *("-" variant) *("-" extension) ["-" privateuse]
pub struct LanguageTag {
  tag : StringView // 原始输入
  state : TagState
} derive(Debug, Eq)

///|
pub impl Show for LanguageTag with fn output(
  self : LanguageTag,
  logger : &Logger,
) -> Unit {
  logger.write("LanguageTag:")
  logger.write("\n")
  logger.write("  { ")
  logger.write("    tag: ")
  logger.write(self.tag)
  logger.write("\n")
  logger.write("    state: ")
  logger.write(self.state)
  logger.write("\n")
  logger.write("    } ")
}

///|
pub struct TagState {
  // 必选 + 位置固定的部分
  language : TagSpan // 主语言 (2-3位 或 5-8位字母)
  extlang : TagSpan? // 扩展语言范围 (多个3位字母，可选)
  script : TagSpan? // 脚本 (4位字母，首字母大写)
  region : TagSpan? // 区域 (2位大写字母 或 3位数字)

  // 可变部分
  variants : Array[TagSpan] // 变体 (多个)
  extensions : Array[Extension] // 扩展 (多个)
  private_use : PrivateUse? // 私有使用
  // 元信息
  is_grandfathered : Bool // 是否是祖父标签
} derive(Debug, Eq)

///|
// pub fn TagState::new(tag : StringView) -> TagState {
//   ...
// }

///|
pub impl Show for TagState with fn output(self : TagState, logger : &Logger) -> Unit {
  logger.write("TagState:")
  logger.write("\n")
  logger.write("  { ")
  logger.write("\n")

  logger.write("    language: ")
  logger.write(@debug.to_string(self.language))
  logger.write(", ")
  logger.write("    extlang: ")
  logger.write(@debug.to_string(self.extlang))
  logger.write(", ")
  logger.write("    script: ")
  logger.write(@debug.to_string(self.script))
  logger.write(", ")
  logger.write("    region: ")
  logger.write(@debug.to_string(self.region))
  logger.write("    variants: ")
  logger.write(@debug.to_string(self.variants))
  logger.write(", ")
  logger.write("    extensions: ")
  logger.write(@debug.to_string(self.extensions))
  logger.write(", ")
  logger.write("    private_use: ")
  logger.write(@debug.to_string(self.private_use))
  logger.write("\n")

  logger.write("  }")
}

///|
pub fn LanguageTag::to_tagstr(self : LanguageTag) -> String {
  self.tag.to_owned()
}

// ============================================================
// 辅助函数
// ============================================================

///|
/// 从 StringView 提取 TagSpan 范围的子字符串
fn sub(s : StringView, span : TagSpan) -> StringView {
  if span.1 <= span.0 {
    return ""
  }
  let start = if span.0 < 0 { 0 } else { span.0 }
  let end = if span.1 > s.length() { s.length() } else { span.1 }
  s[start:end]
}

///|
/// 计算 TagSpan 长度
fn span_len(span : TagSpan) -> Int {
  span.1 - span.0
}

///|
/// 检查 TagSpan 是否有效
// fn span_is_valid(span : TagSpan) -> Bool {
//   span.1 > span.0
// }

///|
/// 提取范围内的所有子标签
fn split_by_span(
  s : StringView,
  start : Int,
  end : Int,
  delim : Char,
) -> Array[StringView] {
  let view = sub(s, (start, end))
  if view.is_empty() {
    return []
  }
  view.split(StringView::from_array([delim])).collect()
}

///|
/// 数字常量
/// 'A'=65 'Z'=90 'a'=97 'z'=122 '0'=48 '9'=57
const UPPER_A : Int = 65

///|
const UPPER_Z : Int = 90

///|
const LOWER_A : Int = 97

///|
const LOWER_Z : Int = 122

///|
const DIGIT_0 : Int = 48

///|
const DIGIT_9 : Int = 57

///|
/// 字符分类
fn is_alpha(c : Int) -> Bool {
  (c >= LOWER_A && c <= LOWER_Z) || (c >= UPPER_A && c <= UPPER_Z)
}

///|
fn is_digit(c : Int) -> Bool {
  c >= DIGIT_0 && c <= DIGIT_9
}

///|
fn is_alphanumeric_char(c : Int) -> Bool {
  is_alpha(c) || is_digit(c)
}

///|
// fn is_lower(c : Int) -> Bool {
//   c >= LOWER_A && c <= LOWER_Z
// }

///|
fn is_upper(c : Int) -> Bool {
  c >= UPPER_A && c <= UPPER_Z
}

///|
/// 检查 StringView 范围是否全为字母
fn is_alphabetic_span(s : StringView, span : TagSpan) -> Bool {
  let mut i = span.0
  while i < span.1 {
    if !is_alpha(s[i].to_int()) {
      return false
    }
    i += 1
  }
  true
}

///|
/// 检查 StringView 范围是否全为字母数字
fn is_alphanumeric_span(s : StringView, span : TagSpan) -> Bool {
  let mut i = span.0
  while i < span.1 {
    let c = s[i].to_int().to_char().unwrap()
    if c < '0' || (c > '9' && c < 'A') || (c > 'Z' && c < 'a') || c > 'z' {
      return false
    }
    i += 1
  }
  true
}

///|
/// 检查是否是脚本 (4位，首字母大写，其余小写)
fn is_script(s : StringView, span : TagSpan) -> Bool {
  if span_len(span) != 4 {
    return false
  }
  // 首字符必须是字母
  let c0 = s[span.0].to_int()
  if !is_alpha(c0) {
    return false
  }
  // 后3个字符必须是字母
  let mut i = span.0 + 1
  while i < span.1 {
    if !is_alpha(s[i].to_int()) {
      return false
    }
    i += 1
  }
  true
}

///|
/// 检查是否是区域 (2位大写字母 或 3位数字)
fn is_region(s : StringView, span : TagSpan) -> Bool {
  let len = span_len(span)
  if len == 2 {
    // 2位字母（大小写均可）
    return is_alphabetic_span(s, span)
  }
  if len == 3 {
    let mut i = span.0
    while i < span.1 {
      if !is_digit(s[i].to_int()) {
        return false
      }
      i += 1
    }
    return true
  }
  false
}

///|
/// 检查是否是变体 (5-8位字母数字，或4位数字首位非0，或旧式3字母变体)
fn is_variant(
  s : StringView,
  span : TagSpan,
  legacy : Array[StringView],
) -> Bool {
  let len = span_len(span)
  if len >= 5 {
    return is_alphanumeric_span(s, span)
  }
  if len == 4 {
    let c0 = s[span.0].to_int()
    if is_digit(c0) && c0 != DIGIT_0 {
      return is_alphanumeric_span(s, span)
    }
  }
  // 旧式3字母变体
  let subtag = sub(s, span)
  for l in legacy {
    if subtag.to_lower() == l.to_lower() {
      return true
    }
  }
  false
}

///|
/// 检查是否是扩展标识符 (单字符，非 x/X)
fn is_extension_ident(s : StringView, span : TagSpan) -> Bool {
  if span_len(span) != 1 {
    return false
  }
  let c = s[span.0].to_int()
  let cl = if is_upper(c) { c + 32 } else { c } // 转小写
  cl != 'x'.to_int() && is_alphanumeric_char(c)
}

///|
/// 检查是否是私有使用前缀 (单字符 x 或 X)
fn is_private_use_prefix(s : StringView, span : TagSpan) -> Bool {
  if span_len(span) != 1 {
    return false
  }
  let c = s[span.0].to_int()
  let cl = if is_upper(c) { c + 32 } else { c }
  cl == 'x'.to_int()
}

// ============================================================
// 旧式3字母变体 (RFC 5646 允许)
// ============================================================

///|
let legacy_3letter_variants : Array[StringView] = [
  "BIS", "NIS", "PIN", "SIN", "KNI", "QUI", "JAN", "FON", "SAA", "SBE", "SCO", "SGU",
  "WUU",
]

// ============================================================
// 祖父标签 (不区分大小写)
// ============================================================

///|
let grandfathereds : Array[StringView] = [
  "art-lojban", "cel-gaulish", "en-GB-oed", "i-ami", "i-bnn", "i-default", "i-enochian",
  "i-hak", "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay",
  "i-tsu", "no-bok", "no-nyn", "sgn-BE-FR", "sgn-BE-NL", "sgn-CH-DE", "zh-guoyu",
  "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang",
]
// 预计算小写版本

// 祖父标签（预计算小写，用于比较）

///|
let grandfathereds_lower : Array[StringView] = [
  "art-lojban", "cel-gaulish", "en-gb-oed", "i-ami", "i-bnn", "i-default", "i-enochian",
  "i-hak", "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay",
  "i-tsu", "no-bok", "no-nyn", "sgn-be-fr", "sgn-be-nl", "sgn-ch-de", "zh-guoyu",
  "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang",
]

///|
/// 检查是否是祖父标签，返回原始格式的 span
/// 检查是否是祖父标签
fn is_grandfathered(tag : StringView) -> Bool {
  let lower = tag.to_lower()
  let mut i = 0
  while i < grandfathereds_lower.length() {
    if lower == grandfathereds_lower[i] {
      return true
    }
    i += 1
  }
  false
}

// ============================================================
// 解析（祖父标签）
// ============================================================

///|
/// 创建祖父标签（返回小写标准格式）
fn make_grandfathered(tag : StringView) -> LanguageTag {
  // 找到祖父标签的标准格式
  let lower = tag.to_lower()
  let mut i = 0
  let mut canonical = tag // 默认用原输入
  while i < grandfathereds_lower.length() {
    if lower == grandfathereds_lower[i] {
      canonical = grandfathereds[i] // 使用标准格式
      break
    }
    i += 1
  }

  {
    tag: canonical,
    state: {
      language: (0, canonical.length()),
      extlang: None,
      script: None,
      region: None,
      variants: [],
      extensions: [],
      private_use: None,
      is_grandfathered: true,
    },
  }
}

// ============================================================
// 解析入口
// ============================================================

///|
/// 解析语言标签
pub fn LanguageTag::parse(tag : StringView) -> Result[LanguageTag, TagParseErr] {
  if tag.is_empty() {
    return Err(TagParseErr::EmptyTag)
  }

  // 检查祖父标签
  if is_grandfathered(tag) {
    return Ok(make_grandfathered(tag))
  }

  if tag.length() >= 2 && tag[0] == 'x' && tag[1] == '-' {
    return parse_private_use_tag(tag)
  }
  parse_tag(tag)
}

///|
/// 纯解析（不含祖父标签检查）
fn parse_tag(tag : StringView) -> Result[LanguageTag, TagParseErr] {
  // 第一步：扫描所有子标签
  let subtags = scan_subtags(tag)
  if subtags.is_empty() {
    return Err(TagParseErr::EmptySubtag)
  }
  // 先验证字符
  match validate_tag_chars(tag) {
    Err(e) => return Err(e)
    _ => ()
  }
  // 验证格式
  match validate_tag_format(tag) {
    Err(e) => return Err(e)
    _ => ()
  }
  let mut i = 0

  // 1. 语言（必选，第一个子标签）
  let lang = subtags[0]
  let lang_len = span_len(lang)
  // 检查长度：2-3 位 或 5-8 位（4 位无效）
  let is_valid_length = (lang_len >= 2 && lang_len <= 3) ||
    (lang_len >= 5 && lang_len <= 8)
  if !is_valid_length {
    return Err(TagParseErr::InvalidLanguageLength)
  }
  if !is_alphabetic_span(tag, lang) {
    return Err(TagParseErr::ForbiddenChar)
  }
  i += 1

  // 2. 扩展语言（可选，2-3位语言后可跟最多3个3位字母）
  let mut extlang_start = lang.1
  let mut extlang_end = lang.1
  let mut extlang_count = 0

  //  debug(
  //   "extlang check: lang_len=\{lang_len}, i=\{i}, subtags[1]=\{subtags.get(1)}",
  // )

  while i < subtags.length() && lang_len <= 3 && extlang_count < 3 {
    let ext = subtags[i]
    // debug(("extlang loop: ext=\{ext}, ext.0=\{ext.0}, ext.1=\{ext.1}")

    if span_len(ext) != 3 || !is_alphabetic_span(tag, ext) {
      // debug(("  break: ! alphabetic")
      break
    }
    let ext_view = sub(tag, ext)
    let mut is_legacy = false
    for l in legacy_3letter_variants {
      if ext_view.to_lower() == l.to_lower() {
        is_legacy = true
        break
      }
    }
    if is_legacy {
      // debug(("  break: legacy variant")
      break
    }

    if extlang_count == 0 {
      extlang_start = ext.0
      // debug(("  set extlang_start = \{ext.0}")
    }
    extlang_count += 1
    extlang_end = ext.1
    i += 1
  }

  //  debug(
  //    "extlang result: start=\{extlang_start}, end=\{extlang_end}, count=\{extlang_count}",
  //  )
  let extlang : TagSpan? = if extlang_count > 0 {
    Some((extlang_start, extlang_end)) // (3, 6)
  } else {
    None
  }

  // 3. 脚本（可选，4位字母，首字母大写）
  let mut script : TagSpan? = None
  if i < subtags.length() && span_len(subtags[i]) == 4 {
    let s = subtags[i]
    // let cand = sub(tag, s)
    let is_s = is_script(tag, s)
    // debug(("@@script candidate: '\{cand}' is_script: \{is_s}")
    if is_s {
      script = Some(s)
      i += 1
    }
  }

  // 4. 区域（2位大写 或 3位数字）
  let mut region : TagSpan? = None
  if i < subtags.length() {
    // debug(("@@region check: '\{sub(tag, subtags[i])}' i=\{i}")
  }
  if i < subtags.length() && is_region(tag, subtags[i]) {
    region = Some(subtags[i])
    i += 1
  }
  // 5. 变体（可选，多个）
  let variants : Array[TagSpan] = []
  while i < subtags.length() {
    let s = subtags[i]
    // let cand = sub(tag, s)
    let is_v = is_variant(tag, s, legacy_3letter_variants)
    // debug(("@@variant check: '\{cand}' is_variant=\{is_v}")
    if is_v {
      variants.push(s)
      i += 1
    } else {
      break
    }
  }

  // 6. 扩展（可选，多个）
  let extensions : Array[Extension] = []
  while i < subtags.length() && is_extension_ident(tag, subtags[i]) {
    let ident = subtags[i]
    i += 1
    let ext_subtags : Array[TagSpan] = []
    // 收集后续子标签直到遇到下一个扩展标识符、私有使用或结束
    while i < subtags.length() &&
          !is_extension_ident(tag, subtags[i]) &&
          !is_private_use_prefix(tag, subtags[i]) {
      let s = subtags[i]
      // 验证扩展子标签：1-8位字母数字
      if !is_valid_private_use_subtag(tag, s) {
        return Err(TagParseErr::InvalidSubtag(s, sub(tag, s)))
      }
      ext_subtags.push(subtags[i])
      i += 1
    }
    if ext_subtags.is_empty() {
      return Err(TagParseErr::EmptyExtension)
    }
    extensions.push({ ident, subtags: ext_subtags })
  }

  // 7. 私有使用（可选）
  let private_use : PrivateUse? = if i < subtags.length() &&
    is_private_use_prefix(tag, subtags[i]) {
    let prefix = subtags[i]
    i += 1
    let subs : Array[TagSpan] = []
    while i < subtags.length() {
      subs.push(subtags[i])
      i += 1
    }
    Some({ prefix, subtags: subs })
  } else {
    None
  }

  Ok({
    tag,
    state: TagState::{
      language: lang,
      extlang,
      script,
      region,
      variants,
      extensions,
      private_use,
      is_grandfathered: false,
    },
  })
}

///|
/// 扫描所有子标签，返回位置数组
fn scan_subtags(tag : StringView) -> Array[TagSpan] {
  let mut pos = 0
  let subtags : Array[TagSpan] = []

  // debug(("scan_subtags: tag='\{tag}', length=\{tag.length()}")

  while pos < tag.length() {
    if tag[pos] == '-' {
      // debug(("  skip '-' at pos \{pos}")
      pos += 1
      continue
    }
    let start = pos
    while pos < tag.length() && tag[pos] != '-' {
      pos += 1
    }
    let end = pos
    // let subtag = tag[start:end]
    // debug(("  subtag '\{subtag}' at (\{start}, \{end})")
    subtags.push((start, end))
    if pos < tag.length() {
      pos += 1
    }
  }

  subtags
}

///|
/// 解析并归一化语言标签
pub fn LanguageTag::parse_and_normalize(
  tag : StringView,
) -> Result[LanguageTag, TagParseErr] {
  match LanguageTag::parse(tag) {
    Ok(parsed) => Ok(parsed.normalize())
    Err(e) => Err(e)
  }
}

///|
fn LanguageTag::normalize(self : LanguageTag) -> LanguageTag {
  if self.state.is_grandfathered {
    // debug("normalize: grandfathered")
    return self
  }
  // 私有使用标签：整体小写
  if self.state.private_use is Some(_) {
    // debug("normalize: private use")
    return { tag: self.tag.to_lower(), state: self.state }
  }

  let result = StringBuilder::new()
  // debug(("normalize input \{self}")
  // 1. 主语言 (小写)
  let lang = sub(self.tag, self.state.language).to_lower()
  // debug("normalize: language = '\{lang}'")
  result.write(lang)

  // 2. 扩展语言 (小写)
  match self.state.extlang {
    Some(span) => {
      // span.0 是主语言结束位置（包含 '-'）
      // 需要跳过这个 '-'

      let ext_start = span.0 + 1
      let parts = split_by_span(
        self.tag,
        self.state.language.1 + 1,
        span.1,
        '-',
      )
      // debug("normalize: extlang parts = \{parts}")
      if ext_start < span.1 {
        for part in parts {
          result.write("-")
          result.write(part.to_lower())
        }
      }
    }
    None => ()
  }

  // 3. 脚本 (Title Case)
  // debug("normalize: checking script = \{self.state.script}")
  match self.state.script {
    Some(span) => {
      // debug("normalize: script span = \{span}")
      let s = sub(self.tag, span)
      let s_len = span_len(span)
      if s_len > 0 {
        let first = s[0].to_int().to_char().unwrap()
        let first_upper = if first >= 'a' && first <= 'z' {
          (first.to_int() - 32).to_char().unwrap()
        } else {
          first
        }
        let rest = s[1:].to_lower()
        result.write("-")
        result.write_char(first_upper)
        result.write(rest)
      }
    }
    None => ()
  }

  // 4. 区域 (大写)
  // debug("normalize: checking region = \{self.state.region}")
  match self.state.region {
    Some(span) => {
      // debug("normalize: region span = \{span}")
      let r = sub(self.tag, span).to_upper()
      // debug("normalize: region written = '\{r}'")
      result.write("-")
      result.write(r)
    }
    None => () // debug("normalize: no region")
  }
  // 5. 变体 (小写)
  // debug("normalize: checking variants, count = \{self.state.variants.length()}")
  for v in self.state.variants {
    // debug("normalize: variant span = \{v}")
    let s = sub(self.tag, v).to_lower()
    // debug("normalize: variant written = '\{s}'")
    result.write("-")
    result.write(s)
  }

  // 6. 扩展 (小写)
  //  debug(
  //   "normalize: checking extensions, count = \{self.state.extensions.length()}",
  // )
  for ext in self.state.extensions {
    // debug("normalize: extension ident = \{ext.ident}")
    result.write("-")
    result.write(sub(self.tag, ext.ident).to_lower())
    for sub_tag in ext.subtags {
      let s = sub(self.tag, sub_tag).to_lower()
      // debug("normalize: extension subtag = '\{s}'")
      result.write("-")
      result.write(s)
    }
  }

  // 7. 私有使用 (小写)
  match self.state.private_use {
    Some(p) => {
      result.write("-")
      result.write(sub(self.tag, p.prefix).to_lower())
      for subtag in p.subtags {
        result.write("-")
        result.write(sub(self.tag, subtag).to_lower())
      }
    }
    None => ()
  }

  // 重新解析归一化后的标签
  let normalized = result.to_string()
  // debug(("normalized: \{normalized}") // 添加调试
  match LanguageTag::parse(normalized) {
    Ok(t) => t
    Err(_) => self
  }
}

///|
fn parse_private_use_tag(tag : StringView) -> Result[LanguageTag, TagParseErr] {
  let subtags = scan_subtags(tag)
  if subtags.is_empty() {
    return Err(TagParseErr::EmptyPrivateUse)
  }

  let prefix = subtags[0]
  if !is_private_use_prefix(tag, prefix) {
    return Err(TagParseErr::InvalidPrivateUsePrefix)
  }

  let subs : Array[TagSpan] = []
  let mut i = 1
  while i < subtags.length() {
    let s = subtags[i]
    if !is_valid_private_use_subtag(tag, s) {
      return Err(TagParseErr::InvalidSubtag(s, sub(tag, s)))
    }
    subs.push(s)
    i += 1
  }

  if subs.is_empty() {
    return Err(TagParseErr::EmptyPrivateUse)
  }

  Ok({
    tag,
    state: {
      language: (0, tag.length()), // 整个标签作为 language
      extlang: None,
      script: None,
      region: None,
      variants: [],
      extensions: [],
      private_use: Some({ prefix, subtags: subs }),
      is_grandfathered: false,
    },
  })
}

// ============================================================
// 访问器
// ============================================================

///|
/// 主语言（原始格式）
/// 主语言（原始格式）
pub fn LanguageTag::primary_language(self : LanguageTag) -> StringView {
  // 普通标签直接返回 language span
  // 检查是否是纯私有使用标签（language 覆盖整个标签）
  if self.state.language.1 == self.tag.length() {
    self.tag // 纯私有使用标签，返回整个标签
  } else {
    sub(self.tag, self.state.language) // 普通标签，返回第一个子标签
  }
}

///|
/// 扩展语言子标签列表
pub fn LanguageTag::extended_language_subtags(
  self : LanguageTag,
) -> Array[StringView] {
  match self.state.extlang {
    Some(span) =>
      // debug("extended_language_subtags \{span}")
      // span.0 是主语言结束位置（包含 '-'），跳过它
      split_by_span(self.tag, span.0, span.1, '-')
    None => []
  }
}

///|
/// 主语言 + 扩展语言（完整）
pub fn LanguageTag::full_language(self : LanguageTag) -> StringView {
  match self.state.extlang {
    Some(span) =>
      // debug("full_language \{span}")
      sub(self.tag, (0, span.1))
    None => sub(self.tag, self.state.language)
  }
}

///|
/// 脚本
pub fn LanguageTag::script(self : LanguageTag) -> StringView? {
  self.state.script.map(fn(s) { sub(self.tag, s) })
}

///|
/// 区域
pub fn LanguageTag::region(self : LanguageTag) -> StringView? {
  self.state.region.map(fn(r) { sub(self.tag, r) })
}

///|
/// 变体子标签列表
pub fn LanguageTag::variant_subtags(self : LanguageTag) -> Array[StringView] {
  self.state.variants.iter().map(fn(v) { sub(self.tag, v) }).collect()
}

///|
/// 扩展迭代器
pub fn LanguageTag::extensions(self : LanguageTag) -> ExtensionIter {
  ExtensionIter::{ tag: self.tag, extensions: self.state.extensions, index: 0 }
}

///|
/// 扩展语言（完整字符串，如 "cmn-hans"，不含前缀 "-"）
pub fn LanguageTag::extended_language(self : LanguageTag) -> StringView? {
  match self.state.extlang {
    Some(span) => {
      // span.0 是主语言结束位置（包含 '-'），跳过它
      let start = span.0 + 1
      if start >= span.1 {
        return None
      }
      Some(sub(self.tag, span))
    }
    None => None
  }
}

///|
/// 私有使用子标签列表
pub fn LanguageTag::private_use_subtags(
  self : LanguageTag,
) -> Array[StringView] {
  match self.state.private_use {
    None => []
    Some(p) => p.subtags.iter().map(fn(s) { sub(self.tag, s) }).collect()
  }
}

///|
/// 是否有扩展
pub fn LanguageTag::has_extensions(self : LanguageTag) -> Bool {
  !self.state.extensions.is_empty()
}

///|
/// 是否有私有使用
pub fn LanguageTag::has_private_use(self : LanguageTag) -> Bool {
  self.state.private_use is Some(_)
}

// ============================================================
// 扩展迭代器
// ============================================================

///|
pub struct ExtensionIter {
  tag : StringView
  extensions : Array[Extension]
  index : Int
}

///|
/// 获取下一个扩展
/// 返回 (标识符, 子标签列表, 下一个迭代器)
fn ExtensionIter::next(
  self : ExtensionIter,
) -> (StringView, Array[StringView], ExtensionIter)? {
  match self.extensions.get(self.index) {
    None => None
    Some(ext) => {
      let ident = sub(self.tag, ext.ident)
      let subtags = ext.subtags.iter().map(fn(s) { sub(self.tag, s) }).collect()
      let next = {
        tag: self.tag,
        extensions: self.extensions,
        index: self.index + 1,
      }
      Some((ident, subtags, next))
    }
  }
}

///|
pub fn LanguageTag::extension_subtags(self : LanguageTag) -> ExtensionIter {
  ExtensionIter::{ tag: self.tag, extensions: self.state.extensions, index: 0 }
}

///|
/// 转换为数组
pub fn ExtensionIter::to_array(
  self : ExtensionIter,
) -> Array[(StringView, Array[StringView])] {
  let result : Array[(StringView, Array[StringView])] = []
  let mut iter = self
  for ;; {
    match iter.next() {
      None => break
      Some((ident, subtags, next)) => {
        result.push((ident, subtags))
        iter = next
      }
    }
  }
  result
}

///|
/// 验证标签格式（无连续 '-'，无首尾 '-'）
fn validate_tag_format(tag : StringView) -> Result[Unit, TagParseErr] {
  if tag.length() == 0 {
    return Ok(())
  }
  if tag[0] == '-' || tag[tag.length() - 1] == '-' {
    return Err(TagParseErr::EmptySubtag)
  }
  let mut i = 1
  while i < tag.length() {
    if tag[i] == '-' && tag[i - 1] == '-' {
      return Err(TagParseErr::EmptySubtag)
    }
    i += 1
  }
  Ok(())
}

///|
/// 检查字符是否有效（字母、数字、'-'）
fn is_valid_char(c : Int) -> Bool {
  is_alphanumeric_char(c) || c == '-'.to_int()
}

///|
/// 验证标签字符（只允许字母、数字、'-'）
fn validate_tag_chars(tag : StringView) -> Result[Unit, TagParseErr] {
  let mut i = 0
  while i < tag.length() {
    if !is_valid_char(tag[i].to_int()) {
      return Err(TagParseErr::ForbiddenChar)
    }
    i += 1
  }
  Ok(())
}

///|
/// 检查私有使用子标签长度（1-8位）
fn is_valid_private_use_subtag(tag : StringView, span : TagSpan) -> Bool {
  let len = span_len(span)
  // 私有使用子标签：1-8位字母数字
  len >= 1 && len <= 8 && is_alphanumeric_span(tag, span)
}
