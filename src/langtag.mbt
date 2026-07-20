///|
pub(all) struct LanguageTag {
  tag : StringView
  positions : TagElementsPositions
} derive(Debug, Default, Hash, Eq)

///|
priv enum State {
  Start
  AfterLanguage
  AfterLongLanguage // 主语言 4-8 位，不允许 Extlang
  AfterExtLang
  AfterScript
  AfterRegion
  InExtension(Bool) // true = 期待扩展内容
  InPrivateUse(Bool) // true = 期待私有使用内容
} derive(Eq)

// 已知的遗留 3 字母变体 (RFC 5646 允许)

///|
let legacy_3letter_variants : Array[StringView] = [
  "BIS", "NIS", "PIN", "SIN", "KNI", "QUI", "JAN", "FON", "SAA", "SBE", "SCO", "SGU",
  "WUU",
]

///|
pub(all) enum SubtagType {
  PrivateUseIntro // "x"
  ExtensionIntro(Char) // 单字母扩展标识符
  Alphabetic(Int) // 纯字母，带长度
  Numeric(Int) // 纯数字，带长度
  Alphanumeric(Int) // 字母数字混合，带长度
  Invalid
}

///|
struct TagElementsPositions {
  language_end : Int
  extlang_end : Int
  script_end : Int
  region_end : Int
  variant_end : Int
  extension_end : Int
} derive(Debug, Default, Hash, Eq)

///|
pub fn LanguageTag::parse(tag : StringView) -> Result[LanguageTag, TagParseErr] {
  match parse_language_tag(tag) {
    Ok(pos) => Ok({ tag, positions: pos })
    Err(e) => Err(e)
  }
}

///|
pub fn LanguageTag::into_str(self : LanguageTag) -> String {
  self.tag.to_owned()
}

///|
pub fn LanguageTag::primary_language(self : LanguageTag) -> StringView? {
  if self.positions.language_end <= 0 {
    return Some("")
  }
  extract_subtag(self.tag, 0, self.positions.language_end)
}

///|
pub fn LanguageTag::extended_language(self : LanguageTag) -> StringView? {
  if self.positions.language_end == self.positions.extlang_end {
    None
  } else {
    Some(
      sub_string(
        self.tag,
        self.positions.language_end + 1,
        self.positions.extlang_end,
      ),
    )
  }
}

///|
pub fn LanguageTag::extended_language_subtags(
  self : LanguageTag,
) -> Array[StringView] {
  let s = self.extended_language().unwrap_or("")
  split_stringview(s, '-')
}

///|
pub fn LanguageTag::full_language(self : LanguageTag) -> StringView {
  extract_subtag(self.tag, 0, self.positions.extlang_end).unwrap_or("")
}

///|
pub fn LanguageTag::script(self : LanguageTag) -> StringView? {
  if self.positions.extlang_end == self.positions.script_end {
    None
  } else {
    Some(
      sub_string(
        self.tag,
        self.positions.extlang_end + 1,
        self.positions.script_end,
      ),
    )
  }
}

///|
pub fn LanguageTag::region(self : LanguageTag) -> StringView? {
  if self.positions.script_end == self.positions.region_end {
    None
  } else {
    Some(
      sub_string(
        self.tag,
        self.positions.script_end + 1,
        self.positions.region_end,
      ),
    )
  }
}

///|
pub fn LanguageTag::variant(self : LanguageTag) -> StringView? {
  if self.positions.region_end == self.positions.variant_end {
    None
  } else {
    Some(
      sub_string(
        self.tag,
        self.positions.region_end + 1,
        self.positions.variant_end,
      ),
    )
  }
}

///|
pub fn LanguageTag::variant_subtags(self : LanguageTag) -> Array[StringView] {
  let s = self.variant().unwrap_or("")
  split_stringview(s, '-')
}

///|
pub fn LanguageTag::extension(self : LanguageTag) -> StringView? {
  if self.positions.variant_end == self.positions.extension_end {
    None
  } else {
    Some(
      sub_string(
        self.tag,
        self.positions.variant_end + 1,
        self.positions.extension_end,
      ),
    )
  }
}

///|
pub fn LanguageTag::extension_subtags(self : LanguageTag) -> ExtensionsIterator {
  ExtensionsIterator::ExtensionsIterator(self.extension().unwrap_or(""))
}

///|
pub fn LanguageTag::private_use(self : LanguageTag) -> StringView? {
  // 查找 x 的位置
  let tag_str = self.tag
  if tag_str.find("-x-") is Some(x_pos) {
    // 找到 -x-，私有使用从 x_pos + 1 开始
    Some(sub_string(tag_str, x_pos + 1, tag_str.length()))
  } else if tag_str.has_prefix("x-") {
    // 整个标签就是私有使用
    Some(tag_str)
  } else {
    None
  }
}

///|
pub fn LanguageTag::private_use_subtags(
  self : LanguageTag,
) -> Array[StringView] {
  match self.private_use() {
    None => []
    Some(part) => split_stringview(sub_string(part, 2, part.length()), '-')
  }
}

///|
pub fn LanguageTag::parse_and_normalize(
  tag : StringView,
) -> Result[LanguageTag, TagParseErr] {
  match normalize_tag(tag) {
    Ok(normalized) => LanguageTag::parse(normalized)
    Err(e) => Err(e)
  }
}

///|
pub fn parse_primary_language(
  subtag : StringView,
) -> Result[StringView, TagParseErr] {
  let len = subtag.length()

  // 快速长度过滤
  if len < 2 || len > 8 {
    return Err(TagParseErr::InvalidLanguageLength)
  }

  // 检查是否全为字母
  if !is_alphabetic(subtag) {
    return Err(TagParseErr::ForbiddenChar)
  }

  Ok(subtag.to_lower())
}

///|
pub impl Show for LanguageTag with fn to_string(self : LanguageTag) -> String {
  self.tag.to_owned()
}

///|
fn sub_string(s : StringView, start : Int, end : Int) -> StringView {
  if start >= s.length() {
    return ""
  }
  let real_end = if end > s.length() { s.length() } else { end }
  if start >= real_end {
    return ""
  }
  let result = s[start:real_end]
  result.to_owned()
}

///|
fn split_stringview(s : StringView, delim : Char) -> Array[StringView] {
  if s.is_empty() {
    return []
  }
  s.split(StringView::from_array([delim])).collect()
}

///|
fn parse_language_tag(
  input : StringView,
) -> Result[TagElementsPositions, TagParseErr] {
  if input.is_empty() {
    return Err(TagParseErr::EmptySubtag)
  }
  // Check for grandfathered tags
  for record in grandfathereds {
    if eq_ignore_ascii_case(record, input) {
      let len = input.length()
      return Ok({
        language_end: len,
        extlang_end: len,
        script_end: len,
        region_end: len,
        variant_end: len,
        extension_end: len,
      })
    }
  }

  if input.has_prefix("x-") || input.has_prefix("X-") {
    if !is_alphanumeric_or_dash(input) {
      return Err(TagParseErr::ForbiddenChar)
    }
    if input.length() == 2 {
      return Err(TagParseErr::EmptyPrivateUse)
    }
    let len = input.length()
    return Ok({
      language_end: len,
      extlang_end: len,
      script_end: len,
      region_end: len,
      variant_end: len,
      extension_end: len,
    })
  }

  calculate_positions(input)
}

///|
fn split_with_positions(input : StringView) -> Array[(StringView, Int)] {
  // 返回 (subtag, end_position) 对
  // end_position 是 subtag 结束位置的索引
  let mut pos = 0
  let results : Array[(StringView, Int)] = []
  for subtag in input.split("-") {
    let s = subtag.to_owned()
    pos += s.length() + 1
    results.push((s, pos - 1))
  }
  results
}

///|
fn calculate_positions(
  input : StringView,
) -> Result[TagElementsPositions, TagParseErr] {
  let mut state = State::Start
  let mut language_end = 0
  let mut extlang_end = 0
  let mut script_end = 0
  let mut region_end = 0
  let mut variant_end = 0
  let mut extension_end = 0
  let mut extlangs_count = 0

  for item in split_with_positions(input) {
    let subtag = item.0
    let end = item.1

    if subtag.is_empty() {
      return Err(TagParseErr::EmptySubtag)
    }
    if subtag.length() > 8 {
      return Err(TagParseErr::SubtagTooLong)
    }

    match state {
      State::Start =>
        // 使用专用的解析函数处理主语言子标签
        match parse_primary_language(subtag) {
          Ok(_normalized_lang) => {
            language_end = end
            let len = subtag.length()
            // 2-3 字母后可能跟扩展语言 (extlang)
            // 4-8 字母后不能跟扩展语言，直接进入脚本/地区判断阶段
            state = if len <= 3 {
              State::AfterLanguage
            } else {
              State::AfterLongLanguage // 4-8 位主语言
            }
          }
          Err(e) => return Err(e)
        }
      State::InPrivateUse(_expected) => {
        // 私有使用内容
        if subtag.is_empty() || subtag.length() > 8 {
          return Err(TagParseErr::InvalidSubtag(end, subtag))
        }
        // 不检查 is_alphanumeric
        state = State::InPrivateUse(false)
      }
      _ => {
        // 1. 扩展语言（排除旧式3字母变体）
        if (state == State::AfterLanguage || state == State::AfterExtLang) &&
          subtag.length() == 3 &&
          is_alphabetic(subtag) {
          if !legacy_3letter_variants.contains(subtag.to_lower()) {
            extlangs_count += 1
            if extlangs_count > 3 {
              return Err(TagParseErr::TooManyExtlangs)
            }
            extlang_end = end
            state = State::AfterExtLang
            continue
          }
        }

        // 2. 私有使用引入
        if subtag == "x" || subtag == "X" {
          if state is State::InExtension(true) {
            return Err(TagParseErr::EmptyExtension)
          }
          state = State::InPrivateUse(true)
          continue
        }

        // 3. 扩展引入（单字母）
        if subtag.length() == 1 && is_alphanumeric(subtag) {
          if state is State::InExtension(true) {
            return Err(TagParseErr::EmptyExtension)
          }
          state = State::InExtension(true)
          continue
        }

        // 4. 扩展内容
        if state is State::InExtension(_) {
          if !is_alphanumeric(subtag) {
            return Err(TagParseErr::InvalidSubtag(end, subtag))
          }
          extension_end = end
          state = State::InExtension(false)
          continue
        }

        // 5. 脚本
        if (
            state == State::AfterLanguage ||
            state == State::AfterExtLang ||
            state == State::AfterLongLanguage
          ) &&
          subtag.length() == 4 &&
          is_alphabetic(subtag) {
          script_end = end
          state = State::AfterScript
          continue
        }

        // 6. 地区
        if (
            state == State::AfterLanguage ||
            state == State::AfterExtLang ||
            state == State::AfterLongLanguage ||
            state == State::AfterScript
          ) &&
          (
            (subtag.length() == 2 && is_alphabetic(subtag)) ||
            (subtag.length() == 3 && is_numeric(subtag))
          ) {
          region_end = end
          state = State::AfterRegion
          continue
        }

        // 7. 变体（包括旧式3字母变体）
        if (
            state == State::AfterLanguage ||
            state == State::AfterExtLang ||
            state == State::AfterScript ||
            state == State::AfterRegion
          ) &&
          is_alphanumeric(subtag) &&
          (
            (subtag.length() >= 5 && is_alphabetic(subtag[0:1])) ||
            (subtag.length() >= 4 && is_numeric(subtag[0:1])) ||
            legacy_3letter_variants.contains(subtag.to_lower())
          ) {
          variant_end = end
          state = State::AfterRegion
          continue
        }

        return Err(TagParseErr::InvalidSubtag(end, subtag))
      }
    }
  }

  // 结束检查
  if state is State::InExtension(true) {
    return Err(TagParseErr::EmptyExtension)
  }
  if state is State::InPrivateUse(true) {
    return Err(TagParseErr::EmptyPrivateUse)
  }

  // 设置默认值
  if extlang_end < language_end {
    extlang_end = language_end
  }
  if script_end < extlang_end {
    script_end = extlang_end
  }
  if region_end < script_end {
    region_end = script_end
  }
  if variant_end < region_end {
    variant_end = region_end
  }
  if extension_end < variant_end {
    extension_end = variant_end
  }
  if extension_end == 0 {
    extension_end = input.length()
  }

  Ok({
    language_end,
    extlang_end,
    script_end,
    region_end,
    variant_end,
    extension_end,
  })
}

///|
fn normalize_tag(input : StringView) -> Result[StringView, TagParseErr] {
  for record in grandfathereds {
    if eq_ignore_ascii_case(record, input) {
      return Ok(record.to_owned())
    }
  }

  if input.has_prefix("x-") || input.has_prefix("X-") {
    if !is_alphanumeric_or_dash(input) {
      return Err(TagParseErr::ForbiddenChar)
    }
    if input.length() == 2 {
      return Err(TagParseErr::EmptyPrivateUse)
    }
    // 私有使用标签整体小写
    return Ok(StringView::to_lower(input.to_owned()))
  }

  let result = StringBuilder::new()
  let mut is_first = true
  let mut is_private_use = false
  let mut is_in_extension = false // <--- 新增：标记是否处于扩展部分
  let mut is_primary = true // 新增标志

  for subtag in input.split("-") {
    let subtag_str = subtag.to_owned()
    if subtag_str.is_empty() {
      return Err(TagParseErr::EmptySubtag)
    }
    if subtag_str.length() > 8 {
      return Err(TagParseErr::SubtagTooLong)
    }

    if !is_first {
      result.write_string("-")
    }
    is_first = false

    // 检查是否进入私有使用部分
    if !is_private_use && (subtag_str == "x" || subtag_str == "X") {
      is_private_use = true
      is_in_extension = false // 私有使用开始，扩展结束

      result.write_string("x")
      continue
    }
    if !is_private_use &&
      !is_in_extension &&
      subtag_str.length() == 1 &&
      is_alphanumeric(subtag_str) {
      is_in_extension = true
      result.write_view(StringView::to_lower(subtag_str))
      continue
    }

    if is_private_use {
      // 私有子标签始终小写
      result.write_view(StringView::to_lower(subtag_str))
    } else if is_in_extension {
      // 扩展子标签始终小写
      result.write_view(StringView::to_lower(subtag_str))
    } else if is_primary { // ✅ 使用标志
      // 主语言子标签：小写
      result.write_view(StringView::to_lower(subtag_str))
      is_primary = false
    } else if subtag_str.length() == 3 && is_alphabetic(subtag_str) {
      // 扩展语言子标签：小写
      result.write_view(StringView::to_lower(subtag_str))
    } else if subtag_str.length() == 4 && is_alphabetic(subtag_str) {
      // 脚本子标签：标题大小写 (Latn)
      result.write_view(to_title_case(subtag_str))
    } else if (subtag_str.length() == 2 && is_alphabetic(subtag_str)) ||
      (subtag_str.length() == 3 && is_numeric(subtag_str)) {
      // 地区子标签：大写 (US, 419)
      result.write_view(StringView::to_upper(subtag_str))
    } else {
      // 变体和其他：小写
      result.write_view(StringView::to_lower(subtag_str))
    }
  }
  Ok(result.to_string())
}

///|
pub(all) struct ExtensionsIterator {
  input : StringView
  subtags : Array[StringView]
  index : Int
}

///|
fn ExtensionsIterator::ExtensionsIterator(
  input : StringView,
) -> ExtensionsIterator {
  let subtags = if input.is_empty() { [] } else { split_stringview(input, '-') }
  { input, subtags, index: 0 }
}

///|
// fn ExtensionsIterator::next(
//   self : ExtensionsIterator,
// ) -> (StringView?, ExtensionsIterator) {
//   if self.index >= self.subtags.length() {
//     (None, self)
//   } else {
//     let tag = self.subtags[self.index]
//     let next_iter = {
//       input: self.input,
//       subtags: self.subtags,
//       index: self.index + 1,
//     }
//     (Some(tag), next_iter)
//   }
// }

///|
pub fn classify_subtag(s : StringView) -> SubtagType {
  if s.is_empty() {
    return SubtagType::Invalid
  }

  if s == "x" || s == "X" {
    return SubtagType::PrivateUseIntro
  }
  if s.length() == 1 && is_alphanumeric(s) {
    match StringView::get_char(s, 0) {
      Some(c) => return SubtagType::ExtensionIntro(c)
      None => return SubtagType::Invalid // 理论上不会执行
    }
  }

  let is_alpha = is_alphabetic(s)
  let is_num = is_numeric(s)
  let len = s.length()

  if is_alpha {
    return SubtagType::Alphabetic(len)
  }
  if is_num {
    return SubtagType::Numeric(len)
  }
  if is_alphanumeric(s) {
    return SubtagType::Alphanumeric(len)
  }

  SubtagType::Invalid
}

///|
fn extract_subtag(tag : StringView, start : Int, end : Int) -> StringView? {
  if start >= end || start < 0 {
    None
  } else {
    Some(sub_string(tag, start, end))
  }
}

///|
// fn normalize_subtag(
//   subtag : StringView,
//   is_primary : Bool,
//   is_in_extension : Bool,
// ) -> StringView {
//   if is_primary {
//     StringView::to_lower(subtag)
//   } else if subtag.length() == 4 && is_alphabetic(subtag) {
//     to_title_case(subtag)
//   } else {
//     StringView::to_lower(subtag)
//   }
// }

///|
let grandfathereds : Array[StringView] = [
  "art-lojban", "cel-gaulish", "en-GB-oed", "i-ami", "i-bnn", "i-default", "i-enochian",
  "i-hak", "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay",
  "i-tsu", "no-bok", "no-nyn", "sgn-BE-FR", "sgn-BE-NL", "sgn-CH-DE", "zh-guoyu",
  "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang",
]
