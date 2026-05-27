///|
pub struct LanguageTag {
  tag : String
  positions : TagElementsPositions
} derive(Default,Hash,Eq)

// Error types

///|

///|
struct TagElementsPositions {
  language_end : Int
  extlang_end : Int
  script_end : Int
  region_end : Int
  variant_end : Int
  extension_end : Int
} derive(Default,Hash,Eq)

// Public API

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
pub fn LanguageTag::into_inner(self : LanguageTag) -> String {
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

// Show for display
// impl Show for LanguageTag with output( self : LanguageTag, logger : &Logger) -> Unit { self.tag.output(logger) }

///|
impl Show for LanguageTag with fn to_string(self : LanguageTag) -> String {
  self.tag
}
// FromStr for parsing using @string.FromStr

///|
impl FromStr for LanguageTag with fn from_str(tag : StringView) -> LanguageTag {
  match LanguageTag::parse_and_normalize(tag.to_owned()) {
    Err(e) => LanguageTag::default()
    Ok(lang_tag) => lang_tag
  }
}

// Helper functions

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
  let arr = []
  for part in s.split(String::from_array([delim])) {
    arr.push(part.to_owned())
  }
  arr
}

// Parsing functions
///|
///|
// fn parse_language_tag(
//   input : StringView,
// ) -> Result[TagElementsPositions, TagParseErr] {
//   // Check for grandfathered tags
//   for record in grandfathereds {
//     if eq_ignore_ascii_case(record, input) {
//       // 修复: 祖父级标签也应该解析其内部结构
//       return calculate_positions(input)
//     }
//   }

//   // Private use
//   if input.has_prefix("x-") || input.has_prefix("X-") {
//     if !is_alphanumeric_or_dash(input) {
//       return Err(TagParseErr::ForbiddenChar)
//     }
//     if input.length() == 2 {
//       return Err(TagParseErr::EmptyPrivateUse)
//     }
//     let len = input.length()
//     return Ok({
//       language_end: len,
//       extlang_end: len,
//       script_end: len,
//       region_end: len,
//       variant_end: len,
//       extension_end: len,
//     })
//   }

//   calculate_positions(input)
// }
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

  // Private use
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


// fn parse_language_tag(
//   input : StringView,
// ) -> Result[TagElementsPositions, TagParseErr] {
//   // Check for grandfathered tags
//   for record in grandfathereds {
//     if eq_ignore_ascii_case(record, input) {
//       // 修复: 祖父级标签也应该解析其内部结构
//       return calculate_positions(input)
//     }
//   }

//   // Private use
//   if input.has_prefix("x-") || input.has_prefix("X-") {
//     if !is_alphanumeric_or_dash(input) {
//       return Err(TagParseErr::ForbiddenChar)
//     }
//     if input.length() == 2 {
//       return Err(TagParseErr::EmptyPrivateUse)
//     }
//     let len = input.length()
//     return Ok({
//       language_end: len,
//       extlang_end: len,
//       script_end: len,
//       region_end: len,
//       variant_end: len,
//       extension_end: len,
//     })
//   }

//   calculate_positions(input)
// }

///|
// fn calculate_positions(
//   input : StringView,
// ) -> Result[TagElementsPositions, TagParseErr] {
//   let mut pos = 0
//   let mut language_end = 0
//   let mut extlang_end = 0
//   let mut script_end = 0
//   let mut region_end = 0
//   let mut variant_end = 0
//   let mut extension_end = 0
//   let mut extlangs_count = 0
//   let mut state = 0

//   for subtag in input.split("-") {
//     let subtag_str = subtag.to_owned()
//     if subtag_str.is_empty() {
//       return Err(TagParseErr::EmptySubtag)
//     }
//     if subtag_str.length() > 8 {
//       return Err(TagParseErr::SubtagTooLong)
//     }

//     let prev_pos = pos
//     pos = prev_pos + subtag_str.length() + 1

//     if state == 0 {
//       if subtag_str.length() < 2 || !is_alphabetic(subtag_str) {
//         return Err(TagParseErr::InvalidLanguage)
//       }
//       language_end = pos - 1
//       if subtag_str.length() < 4 {
//         state = 1
//       } else {
//         state = 2
//       }
//     } else if subtag_str == "x" || subtag_str == "X" {
//       if state == 5 {
//         return Err(TagParseErr::EmptyExtension)
//       }
//       // extension_end 应该是 x 之前的位置
//       extension_end = prev_pos - 1
//       break
//     } else if subtag_str.length() == 1 && is_alphanumeric(subtag_str) {
//       if state == 5 {
//         return Err(TagParseErr::EmptyExtension)
//       }
//       state = 5
//     } else if state == 5 {
//       extension_end = pos - 1
//     } else if (state == 1 || state == 2) &&
//       subtag_str.length() == 3 &&
//       is_alphabetic(subtag_str) {
//       extlangs_count += 1
//       if extlangs_count > 3 {
//         return Err(TagParseErr::TooManyExtlangs)
//       }
//       extlang_end = pos - 1
//     } else if (state == 1 || state == 2) &&
//       subtag_str.length() == 4 &&
//       is_alphabetic(subtag_str) {
//       script_end = pos - 1
//       state = 3
//     } else if (state == 1 || state == 2 || state == 3) &&
//       (
//         (subtag_str.length() == 2 && is_alphabetic(subtag_str)) ||
//         (subtag_str.length() == 3 && is_numeric(subtag_str))
//       ) {
//       region_end = pos - 1
//       state = 4
//     } else if (state == 1 || state == 2 || state == 3 || state == 4) &&
//       is_alphanumeric(subtag_str) &&
//       (
//         (
//           subtag_str.length() >= 5 &&
//           is_alphabetic(sub_string(subtag_str, 0, 1))
//         ) ||
//         (subtag_str.length() >= 4 && is_numeric(sub_string(subtag_str, 0, 1)))
//       ) {
//       variant_end = pos - 1
//       state = 4
//     } else {
//       return Err(TagParseErr::InvalidSubtag)
//     }
//   }

//   if extension_end == 0 {
//     extension_end = input.length()
//   }

//   if extlang_end < language_end {
//     extlang_end = language_end
//   }
//   if script_end < extlang_end {
//     script_end = extlang_end
//   }
//   if region_end < script_end {
//     region_end = script_end
//   }
//   if variant_end < region_end {
//     variant_end = region_end
//   }
//   if extension_end < variant_end {
//     extension_end = variant_end
//   }

//   Ok({
//     language_end,
//     extlang_end,
//     script_end,
//     region_end,
//     variant_end,
//     extension_end,
//   })
// }
// fn calculate_positions(
//   input : StringView,
// ) -> Result[TagElementsPositions, TagParseErr] {
//   let mut pos = 0
//   let mut language_end = 0
//   let mut extlang_end = 0
//   let mut script_end = 0
//   let mut region_end = 0
//   let mut variant_end = 0
//   let mut extension_end = 0
//   let mut extlangs_count = 0
//   let mut state = 0

//   for subtag in input.split("-") {
//     let subtag_str = subtag.to_owned()
//     if subtag_str.is_empty() {
//       return Err(TagParseErr::EmptySubtag)
//     }
//     if subtag_str.length() > 8 {
//       return Err(TagParseErr::SubtagTooLong)
//     }

//     let prev_pos = pos
//     pos = prev_pos + subtag_str.length() + 1

//     if state == 0 {
//       if subtag_str.length() < 2 || !is_alphabetic(subtag_str) {
//         return Err(TagParseErr::InvalidLanguage)
//       }
//       language_end = pos - 1
//       if subtag_str.length() < 4 {
//         state = 1
//       } else {
//         state = 2
//       }
//     } else if subtag_str == "x" || subtag_str == "X" {
//       // 修复: 遇到 x 时，extension_end 应该是 x 之前的位置
//       // 此时 pos 已经增加了 subtag_str.length() + 1，即指向了 x 之后的位置
//       // prev_pos 是 x 开始的位置。
//       // extension_end 应该是 prev_pos - 1 (即上一个子标签的结束位置)
//       if state == 5 {
//         return Err(TagParseErr::EmptyExtension)
//       }
//       extension_end = prev_pos - 1
//       // 注意：这里不 break，而是继续循环以消耗剩余部分，或者 break 但需正确处理 private use
//       // 为了简化，我们 break，但必须确保 extension_end 正确
//       break
//     } else if subtag_str.length() == 1 && is_alphanumeric(subtag_str) {
//       if state == 5 {
//         return Err(TagParseErr::EmptyExtension)
//       }
//       state = 5
//       // extension_end 会在后续子标签中更新，或者在循环结束后处理
//     } else if state == 5 {
//       extension_end = pos - 1
//     } else if (state == 1 || state == 2) &&
//       subtag_str.length() == 3 &&
//       is_alphabetic(subtag_str) {
//       extlangs_count += 1
//       if extlangs_count > 3 {
//         return Err(TagParseErr::TooManyExtlangs)
//       }
//       extlang_end = pos - 1
//     } else if (state == 1 || state == 2) &&
//       subtag_str.length() == 4 &&
//       is_alphabetic(subtag_str) {
//       script_end = pos - 1
//       state = 3
//     } else if (state == 1 || state == 2 || state == 3) &&
//       (
//         (subtag_str.length() == 2 && is_alphabetic(subtag_str)) ||
//         (subtag_str.length() == 3 && is_numeric(subtag_str))
//       ) {
//       region_end = pos - 1
//       state = 4
//     } else if (state == 1 || state == 2 || state == 3 || state == 4) &&
//       is_alphanumeric(subtag_str) &&
//       (
//         (
//           subtag_str.length() >= 5 &&
//           is_alphabetic(sub_string(subtag_str, 0, 1))
//         ) ||
//         (subtag_str.length() >= 4 && is_numeric(sub_string(subtag_str, 0, 1)))
//       ) {
//       variant_end = pos - 1
//       state = 4
//     } else {
//       return Err(TagParseErr::InvalidSubtag)
//     }
//   }

//   // 如果循环因为 break (遇到 x) 而提前结束，extension_end 已经设置
//   // 如果循环正常结束，且 extension_end 仍为 0，则设置为 input.length()
//   if extension_end == 0 {
//     extension_end = input.length()
//   }

//   if extlang_end < language_end {
//     extlang_end = language_end
//   }
//   if script_end < extlang_end {
//     script_end = extlang_end
//   }
//   if region_end < script_end {
//     region_end = script_end
//   }
//   if variant_end < region_end {
//     variant_end = region_end
//   }
//   if extension_end < variant_end {
//     extension_end = variant_end
//   }

//   Ok({
//     language_end,
//     extlang_end,
//     script_end,
//     region_end,
//     variant_end,
//     extension_end,
//   })
// }

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

    if state == 0 {
      if subtag_str.length() < 2 || !is_alphabetic(subtag_str) {
        return Err(TagParseErr::InvalidLanguage)
      }
      language_end = pos - 1
      if subtag_str.length() < 4 {
        state = 1
      } else {
        state = 2
      }
    } else if subtag_str == "x" || subtag_str == "X" {
      if state == 5 {
        return Err(TagParseErr::EmptyExtension)
      }
      extension_end = input.length()
      break
    } else if subtag_str.length() == 1 && is_alphanumeric(subtag_str) {
      if state == 5 {
        return Err(TagParseErr::EmptyExtension)
      }
      state = 5
    } else if state == 5 {
      extension_end = pos - 1
    } else if state == 1 &&
      subtag_str.length() == 3 &&
      is_alphabetic(subtag_str) {
      extlangs_count += 1
      if extlangs_count > 3 {
        return Err(TagParseErr::TooManyExtlangs)
      }
      extlang_end = pos - 1
      state = 2
    } else if (state == 1 || state == 2) &&
      subtag_str.length() == 4 &&
      is_alphabetic(subtag_str) {
      script_end = pos - 1
      state = 3
    } else if (state == 1 || state == 2 || state == 3) &&
      (
        (subtag_str.length() == 2 && is_alphabetic(subtag_str)) ||
        (subtag_str.length() == 3 && is_numeric(subtag_str))
      ) {
      region_end = pos - 1
      state = 4
    } else if (state == 1 || state == 2 || state == 3 || state == 4) &&
      is_alphanumeric(subtag_str) &&
      (
        (
          subtag_str.length() >= 5 &&
          is_alphabetic(sub_string(subtag_str, 0, 1))
        ) ||
        (subtag_str.length() >= 4 && is_numeric(sub_string(subtag_str, 0, 1)))
      ) {
      variant_end = pos - 1
      state = 4
    } else {
      return Err(TagParseErr::InvalidSubtag)
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
// fn normalize_tag(input : StringView) -> Result[String, TagParseErr] {
//   for record in grandfathereds {
//     if eq_ignore_ascii_case(record, input) {
//       return Ok(input.to_owned())
//     }
//   }

//   if input.has_prefix("x-") || input.has_prefix("X-") {
//     if !is_alphanumeric_or_dash(input) {
//       return Err(TagParseErr::ForbiddenChar)
//     }
//     if input.length() == 2 {
//       return Err(TagParseErr::EmptyPrivateUse)
//     }
//     return Ok(String::to_lower(input.to_owned()))
//   }

//   let result = StringBuilder::new()
//   let mut is_first = true

//   for subtag in input.split("-") {
//     let subtag_str = subtag.to_owned()
//     if subtag_str.is_empty() {
//       return Err(TagParseErr::EmptySubtag)
//     }
//     if subtag_str.length() > 8 {
//       return Err(TagParseErr::SubtagTooLong)
//     }

//     if !is_first {
//       result.write_string("-")
//     }
//     is_first = false

//     if result.to_string().length() == 0 {
//       result.write_string(String::to_lower(subtag_str))
//     } else if subtag_str.length() == 3 && is_alphabetic(subtag_str) {
//       result.write_string(String::to_lower(subtag_str))
//     } else if subtag_str.length() == 4 && is_alphabetic(subtag_str) {
//       result.write_string(to_title_case(subtag_str))
//     } else if (subtag_str.length() == 2 && is_alphabetic(subtag_str)) ||
//       (subtag_str.length() == 3 && is_numeric(subtag_str)) {
//       result.write_string(String::to_upper(subtag_str))
//     } else {
//       result.write_string(String::to_lower(subtag_str))
//     }
//   }
//   Ok(result.to_string())
// }

///|

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
      result.write_string("x")
      continue
    }

    if is_private_use {
      // 私有子标签始终小写
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


// Helper functions

///|
struct ExtensionsIterator {
  input : String
}

// 修正构造函数，正确返回结构体实例

///|
fn ExtensionsIterator::new(input : String) -> ExtensionsIterator {
  { input, }
}

///|
fn is_alphabetic(s : StringView) -> Bool {
  let chars = StringView::iter(s)
  let mut result = true
  for c in chars {
    if !c.is_ascii_alphabetic() {
      result = false
      break
    }
  }
  result
}

///|
fn is_numeric(s : StringView) -> Bool {
  let chars = StringView::iter(s)
  let mut result = true
  for c in chars {
    if !c.is_ascii_digit() {
      result = false
      break
    }
  }
  result
}

///|
fn is_alphanumeric(s : String) -> Bool {
  let chars = String::iter(s)
  let mut result = true
  for c in chars {
    if !is_ascii_alphanumeric(c) {
      result = false
      break
    }
  }
  result
}

///|
fn is_alphanumeric_or_dash(s : StringView) -> Bool {
  let chars = StringView::iter(s)
  let mut result = true
  for c in chars {
    if !(is_ascii_alphanumeric(c) || c == '-') {
      result = false
      break
    }
  }
  result
}

///|
fn to_title_case(s : StringView) -> String {
  let result = StringBuilder::new()
  let chars = StringView::iter(s)
  let mut is_first = true
  for c in chars {
    if is_first {
      result.write_char(c.to_ascii_uppercase())
      is_first = false
    } else {
      result.write_char(c.to_ascii_lowercase())
    }
  }
  result.to_string()
}

///|
let grandfathereds : Array[StringView] = [
  "art-lojban", "cel-gaulish", "en-GB-oed", "i-ami", "i-bnn", "i-default", "i-enochian",
  "i-hak", "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay",
  "i-tsu", "no-bok", "no-nyn", "sgn-BE-FR", "sgn-BE-NL", "sgn-CH-DE", "zh-guoyu",
  "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang",
]
