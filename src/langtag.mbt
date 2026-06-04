///|
pub struct LanguageTag {
  tag : String
  positions : TagElementsPositions
} derive(Default, Hash, Eq)

///|
enum SubtagType {
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
} derive(Default, Hash, Eq)

///|
pub fn LanguageTag::parse(tag : StringView) -> Result[LanguageTag, TagParseErr] {
  match parse_language_tag(tag) {
    Ok(pos) => Ok({ tag: tag.to_owned(), positions: pos })
    Err(e) => Err(e)
  }
}

///|
pub fn LanguageTag::as_str(self : LanguageTag) -> String {
  self.tag
}

///|
pub fn LanguageTag::primary_language(self : LanguageTag) -> String {
  sub_string(self.tag, 0, self.positions.language_end)
}

///|
pub fn LanguageTag::extended_language(self : LanguageTag) -> String? {
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
) -> Array[String] {
  let s = self.extended_language().unwrap_or("")
  split_to_strings(s, '-')
}

///|
pub fn LanguageTag::full_language(self : LanguageTag) -> String {
  sub_string(self.tag, 0, self.positions.extlang_end)
}

///|
pub fn LanguageTag::script(self : LanguageTag) -> String? {
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
pub fn LanguageTag::region(self : LanguageTag) -> String? {
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
pub fn LanguageTag::variant(self : LanguageTag) -> String? {
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
pub fn LanguageTag::variant_subtags(self : LanguageTag) -> Array[String] {
  let s = self.variant().unwrap_or("")
  split_to_strings(s, '-')
}

///|
pub fn LanguageTag::extension(self : LanguageTag) -> String? {
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
  match self.extension() {
    Some(parts) => ExtensionsIterator::new(parts)
    None => ExtensionsIterator::new("")
  }
}

///|
pub fn LanguageTag::private_use(self : LanguageTag) -> String? {
  if self.tag.has_prefix("x-") {
    Some(self.tag)
  } else if self.positions.extension_end == self.tag.length() {
    None
  } else {
    Some(
      sub_string(self.tag, self.positions.extension_end + 1, self.tag.length()),
    )
  }
}

///|
pub fn LanguageTag::private_use_subtags(self : LanguageTag) -> Array[String] {
  let opt = self.private_use()
  match opt {
    None => []
    Some(part) => split_to_strings(sub_string(part, 2, part.length()), '-')
  }
}

///|
pub fn LanguageTag::parse_and_normalize(
  tag : String,
) -> Result[LanguageTag, TagParseErr] {
  match normalize_tag(tag) {
    Ok(normalized) => LanguageTag::parse(normalized)
    Err(e) => Err(e)
  }
}

///|
impl Show for LanguageTag with fn to_string(self : LanguageTag) -> String {
  self.tag
}

///|
impl FromStr for LanguageTag with fn from_str(tag : StringView) -> LanguageTag {
  match LanguageTag::parse_and_normalize(tag.to_owned()) {
    Err(_e) => LanguageTag::default()
    Ok(lang_tag) => lang_tag
  }
}

///|
fn sub_string(s : String, start : Int, end : Int) -> String {
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
fn split_to_strings(s : String, delim : Char) -> Array[String] {
  if s.is_empty() {
    return []
  }
  s
  .split(String::from_array([delim]))
  .map(fn(part) { part.to_owned() })
  .collect()
}

///|
fn parse_language_tag(
  input : StringView,
) -> Result[TagElementsPositions, TagParseErr] {
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
fn calculate_positions(
  input : StringView,
) -> Result[TagElementsPositions, TagParseErr] {
  let mut pos = 0
  let mut language_end = 0
  let mut extlang_end = 0
  let mut script_end = 0
  let mut region_end = 0
  let mut variant_end = 0
  let mut extension_end = 0
  let mut extlangs_count = 0
  let mut state = 0

  for subtag in input.split("-") {
    let subtag_str = subtag.to_owned()
    if subtag_str.is_empty() {
      return Err(TagParseErr::EmptySubtag)
    }
    if subtag_str.length() > 8 {
      return Err(TagParseErr::SubtagTooLong)
    }

    let prev_pos = pos
    pos = prev_pos + subtag_str.length() + 1

    // if state == 0 {
    //   if subtag_str.length() < 2 || !is_alphabetic(subtag_str) {
    //     return Err(TagParseErr::InvalidLanguage)
    //   }
    //   language_end = pos - 1
    //   if subtag_str.length() < 4 {
    //     state = 1
    //   } else {
    //     state = 2
    //   }
    // } else if subtag_str == "x" || subtag_str == "X" {
    //   if state == 5 {
    //     return Err(TagParseErr::EmptyExtension)
    //   }
    //   extension_end = input.length()
    //   break
    // } else if subtag_str.length() == 1 && is_alphanumeric(subtag_str) {
    //   if state == 5 {
    //     return Err(TagParseErr::EmptyExtension)
    //   }
    //   state = 5
    // } else if state == 5 {
    //   extension_end = pos - 1
    // } else if state == 1 &&
    //   subtag_str.length() == 3 &&
    //   is_alphabetic(subtag_str) {
    //   extlangs_count += 1
    //   if extlangs_count > 3 {
    //     return Err(TagParseErr::TooManyExtlangs)
    //   }
    //   extlang_end = pos - 1
    //   state = 2
    // } else if (state == 1 || state == 2) &&
    //   subtag_str.length() == 4 &&
    //   is_alphabetic(subtag_str) {
    //   script_end = pos - 1
    //   state = 3
    // } else if (state == 1 || state == 2 || state == 3) &&
    //   (
    //     (subtag_str.length() == 2 && is_alphabetic(subtag_str)) ||
    //     (subtag_str.length() == 3 && is_numeric(subtag_str))
    //   ) {
    //   region_end = pos - 1
    //   state = 4
    // } else if (state == 1 || state == 2 || state == 3 || state == 4) &&
    //   is_alphanumeric(subtag_str) &&
    //   (
    //     (
    //       subtag_str.length() >= 5 &&
    //       is_alphabetic(sub_string(subtag_str, 0, 1))
    //     ) ||
    //     (subtag_str.length() >= 4 && is_numeric(sub_string(subtag_str, 0, 1)))
    //   ) {
    //   variant_end = pos - 1
    //   state = 4
    // } else {
    //   return Err(TagParseErr::InvalidSubtag)
    // }
    // debug("Processing subtag: \{subtag_str}, State: \{state}")

    // match classify_subtag(subtag_str) {
    //   SubtagType::Invalid => return Err(TagParseErr::InvalidSubtag)
    //   SubtagType::PrivateUseIntro => {
    //     // 处理 x- 逻辑
    //     if state == 5 { return Err(TagParseErr::EmptyExtension) }
    //     extension_end = input.length()
    //     break
    //   }
    //   SubtagType::ExtensionIntro(_c) => {
    //     // 处理单字母扩展标识符
    //     if state == 5 { return Err(TagParseErr::EmptyExtension) }
    //     state = 5
    //   }
    //   SubtagType::Alphabetic(len) => {
    //     // 根据 state 和 len 决定是语言、扩展语言、脚本还是变体
    //     if state == 0 {
    //       // 主语言逻辑
    //       if len < 2 { return Err(TagParseErr::InvalidLanguage) }
    //       language_end = pos - 1
    //       state = if len < 4 { 1 } else { 2 }
    //     } else if (state == 1 || state == 2) && len == 3 {
    //       // 扩展语言
    //       extlangs_count += 1
    //       if extlangs_count > 3 { return Err(TagParseErr::TooManyExtlangs) }
    //       extlang_end = pos - 1
    //       state = 2
    //     } else if (state == 1 || state == 2) && len == 4 {
    //       // 脚本
    //       script_end = pos - 1
    //       state = 3
    //     } else if (state >= 1 && state <= 4) && 
    //           (
    //     (subtag_str.length() == 2 && is_alphabetic(subtag_str)) || // <--- 旧代码在这里处理了 2 字母地区
    //     (subtag_str.length() == 3 && is_numeric(subtag_str))
    //   ){
    //       // 变体 (以字母开头)
    //       variant_end = pos - 1
    //       state = 4
    //     } else {
    //       return Err(TagParseErr::InvalidSubtag)
    //     }
    //   }
    //   SubtagType::Numeric(len) => {
    //     // 处理数字子标签 (地区或变体)
    //     if (state == 1 || state == 2 || state == 3) && len == 3 {
    //       region_end = pos - 1
    //       state = 4
    //     } else if (state >= 1 && state <= 4) && len >= 4 {
    //       variant_end = pos - 1
    //       state = 4
    //     } else {
    //       return Err(TagParseErr::InvalidSubtag)
    //     }
    //   }
    //   SubtagType::Alphanumeric(len) => {
    //      // 处理混合子标签 (通常是变体)
    //      // 注意：BCP47中变体可以是字母数字混合
    //      if (state >= 1 && state <= 4) && (len >= 5 || (len >= 4 && is_numeric(subtag_str[0:1]))) {
    //         variant_end = pos - 1
    //         state = 4
    //      } else {
    //         return Err(TagParseErr::InvalidSubtag)
    //      }
    //   }
    // }

    match classify_subtag(subtag_str) {
      SubtagType::Invalid => return Err(TagParseErr::InvalidSubtag)
      SubtagType::PrivateUseIntro => {
        if state == 0 {
          return Err(TagParseErr::EmptyExtension)
        }
        if extension_end == variant_end && state == 5 {
          return Err(TagParseErr::EmptyExtension)
        }

        // extension_end = input.length()
        break
      }
      SubtagType::ExtensionIntro(_c) => {
        if state == 0 {
          return Err(TagParseErr::EmptyExtension)
        }

        if state == 5 {
          extension_end = pos - 1
          continue
        }
        state = 5
      }
      SubtagType::Alphabetic(len) => {
        if state == 5 {
          extension_end = pos - 1

          continue
        }
        if state == 0 {
          // 1. 主语言 (Primary Language): 2-3 字母
          if len < 2 {
            return Err(TagParseErr::InvalidLanguage)
          }
          language_end = pos - 1
          state = if len < 4 { 1 } else { 2 }
        } else if (state == 1 || state == 2) && len == 3 {
          // if state == 2 {
          //   return Err(TagParseErr::InvalidSubtag)
          // }

          // 2. 扩展语言 (Extlang): 3 字母
          extlangs_count += 1
          if extlangs_count > 3 {
            return Err(TagParseErr::TooManyExtlangs)
          }
          extlang_end = pos - 1
          state = 2
        } else if (state == 1 || state == 2) && len == 4 {
          // 3. 脚本 (Script): 4 字母
          script_end = pos - 1
          state = 3
        } else if (state == 1 || state == 2 || state == 3) && len == 2 {
          // 4. 地区 (Region): 2 字母 (例如 MN, US)
          region_end = pos - 1
          state = 4
        } else if (state >= 1 && state <= 4) && len >= 5 {
          // 5. 变体 (Variant): 5+ 字母 (例如 nedis, boont)
          variant_end = pos - 1
          state = 4
        } else {
          return Err(TagParseErr::InvalidSubtag)
        }
      }
      SubtagType::Numeric(len) => {
        if state == 5 {
          extension_end = pos - 1

          continue
        }
        // 处理数字子标签 (地区或变体)
        if (state == 1 || state == 2 || state == 3) && len == 3 {
          // 6. 地区 (Region): 3 数字 (例如 419, 005)
          region_end = pos - 1
          state = 4
        } else if (state >= 1 && state <= 4) && len >= 4 {
          // 7. 变体 (Variant): 4+ 数字 (例如 1996)
          variant_end = pos - 1
          state = 4
        } else {
          return Err(TagParseErr::InvalidSubtag)
        }
      }
      SubtagType::Alphanumeric(len) => {
        if state == 5 {
          extension_end = pos - 1

          continue
        }
        // 8. 变体 (Variant): 字母数字混合 (通常以数字开头，长度>=4; 或以字母开头，长度>=5)
        // 注意：classify_subtag 已经将纯字母和纯数字分离了，这里剩下的是混合类型
        if (state >= 1 && state <= 4) &&
          (len >= 5 || (len >= 4 && is_numeric(subtag_str[0:1]))) {
          variant_end = pos - 1
          state = 4
        } else {
          return Err(TagParseErr::InvalidSubtag)
        }
      }
    }
  }

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
fn normalize_tag(input : StringView) -> Result[String, TagParseErr] {
  // 修复：祖父级标签应返回预定义列表中的规范形式，保持原有大小写
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
    return Ok(String::to_lower(input.to_owned()))
  }

  let result = StringBuilder::new()
  let mut is_first = true
  let mut is_private_use = false
  let mut is_in_extension = false // <--- 新增：标记是否处于扩展部分

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
      result.write_string(String::to_lower(subtag_str))
      continue
    }

    if is_private_use {
      // 私有子标签始终小写
      result.write_string(String::to_lower(subtag_str))
    } else if is_in_extension {
      // 扩展子标签始终小写
      result.write_string(String::to_lower(subtag_str))
    } else if result.to_string().length() == 0 {
      // 主语言子标签：小写
      result.write_string(String::to_lower(subtag_str))
    } else if subtag_str.length() == 3 && is_alphabetic(subtag_str) {
      // 扩展语言子标签：小写
      result.write_string(String::to_lower(subtag_str))
    } else if subtag_str.length() == 4 && is_alphabetic(subtag_str) {
      // 脚本子标签：标题大小写 (Latn)
      result.write_string(to_title_case(subtag_str))
    } else if (subtag_str.length() == 2 && is_alphabetic(subtag_str)) ||
      (subtag_str.length() == 3 && is_numeric(subtag_str)) {
      // 地区子标签：大写 (US, 419)
      result.write_string(String::to_upper(subtag_str))
    } else {
      // 变体和其他：小写
      result.write_string(String::to_lower(subtag_str))
    }
  }
  Ok(result.to_string())
}

///|
struct ExtensionsIterator {
  input : String
}

///|
fn ExtensionsIterator::new(input : String) -> ExtensionsIterator {
  { input, }
}

///|
fn classify_subtag(s : StringView) -> SubtagType {
  if s == "x" || s == "X" {
    return SubtagType::PrivateUseIntro
  }
  if s.length() == 1 && is_alphanumeric(s) {
    return SubtagType::ExtensionIntro(StringView::get_char(s, 0).unwrap())
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
let grandfathereds : Array[StringView] = [
  "art-lojban", "cel-gaulish", "en-GB-oed", "i-ami", "i-bnn", "i-default", "i-enochian",
  "i-hak", "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay",
  "i-tsu", "no-bok", "no-nyn", "sgn-BE-FR", "sgn-BE-NL", "sgn-CH-DE", "zh-guoyu",
  "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang",
]
