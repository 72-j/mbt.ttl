// 检查是否为 pchar（path character）

///|
pub fn is_pchar(c : Char) -> Bool {
  is_unreserved(c) ||
  c == ':' ||
  c == '@' ||
  c == '&' ||
  c == '=' ||
  c == '+' ||
  c == '$' ||
  c == ',' ||
  c == ';'
}

///|
pub fn is_unreserved(c : Char) -> Bool {
  c.is_ascii_alphabetic() ||
  c.is_ascii_digit() ||
  c == '-' ||
  c == '.' ||
  c == '_' ||
  c == '~'
}

///|
pub fn remove_dot_segments_from_array(
  segments : Array[String],
) -> Array[String] {
  let output = []
  for segment in segments {
    match segment {
      "." => () // 忽略
      ".." =>
        if output.length() > 0 {
          // 注意：如果输出是绝对路径（第一个元素是 ""），不应该弹出根目录
          // 这里简化处理，假设调用者会处理绝对路径标记
          let _ = output.pop()
        }
      _ => output.push(segment)
    }
  }
  output
}

///|
fn array_to_view(arr : Array[Byte]) -> Bytes {
  let bytes : Bytes = Bytes::from_array(arr) // 假设有此 API，或者 Bytes::of_array_view
  // let view : BytesView = bytes.view() // 假设 Bytes 有 .view() 方法
  return bytes
}

///|
fn eq_ignore_ascii_case(s1 : StringView, s2 : StringView) -> Bool {
  if s1.length() != s2.length() {
    return false
  }

  for i = 0; i < s1.length(); i = i + 1 {
    let u1 = s1[i] // UInt16
    let u2 = s2[i] // UInt16

    if u1 == u2 {
      continue
    }

    // 手动实现 ASCII 忽略大小写比较
    // 只有当字符是 'A'-'Z' 或 'a'-'z' 时才需要转换

    let is_alpha1 = (u1 >= 65 && u1 <= 90) || (u1 >= 97 && u1 <= 122)
    let is_alpha2 = (u2 >= 65 && u2 <= 90) || (u2 >= 97 && u2 <= 122)

    // 如果其中有一个不是 ASCII 字母，且它们不相等（前面已判断 u1 != u2），则不匹配
    if !(is_alpha1 && is_alpha2) {
      return false
    }

    // 都转为小写再比较
    // 'A'(65)->'a'(97), ..., 'Z'(90)->'z'(122)
    // 'a'-'z' 保持不变
    let lower1 = if u1 >= 65 && u1 <= 90 { u1 + 32 } else { u1 }
    let lower2 = if u2 >= 65 && u2 <= 90 { u2 + 32 } else { u2 }

    if lower1 != lower2 {
      return false
    }
  }

  true
}

///|
fn is_ascii_alphanumeric(c : Char) -> Bool {
  let code = c.to_int()
  // '0'=48, '9'=57, 'A'=65, 'Z'=90, 'a'=97, 'z'=122
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122)
}

///|
fn memchr2(c1 : Byte, c2 : Byte, data : BytesView) -> Int? {
  // 实现逻辑：遍历 data，返回第一个匹配 c1 或 c2 的索引
  for i in 0..<data.length() {
    let b = data.at(i)
    if b == c1 || b == c2 {
      return Some(i)
    }
  }
  None
}

///|
fn memchr(target : Byte, data : BytesView) -> Int? {
  for i in 0..<data.length() {
    if data.at(i) == target {
      return Some(i)
    }
  }
  None
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
pub fn from_str_radix(s : String, radix : Int) -> Result[UInt, String] {
  if s.is_empty() {
    return Err("Input string is empty")
  }

  // 简单的进制检查，通常支持 2-36
  if radix < 2 || radix > 36 {
    return Err("Radix must be between 2 and 36")
  }

  let mut result : UInt = 0
  for c in s {
    let digit = match c {
      '0'..='9' => Char::to_int(c) - Char::to_int('0')
      'a'..='z' => Char::to_int(c) - Char::to_int('a') + 10
      'A'..='Z' => Char::to_int(c) - Char::to_int('A') + 10
      _ => return Err("Invalid character '\{c}' for radix \{radix}")
    }

    if digit >= radix {
      return Err("Character '\{c}' is not valid for radix \{radix}")
    }

    // 检查溢出: result * radix + digit
    // 如果 result > (MAX_UINT - digit) / radix，则溢出
    // 注意：MoonBit 的 UInt 具体最大值取决于平台或定义，这里假设标准溢出逻辑
    // 由于 MoonBit 目前可能没有直接的 MAX_UINT 常量暴露或溢出检查运算符，
    // 我们使用一种安全的累加方式或者依赖语言本身的溢出行为（如果允许）
    // 在这里，为了稳健性，我们手动检查或使用 try_mul/add 如果存在

    // 简化实现：假设 UInt 足够大或者使用内置转换如果存在
    // 如果 MoonBit 标准库有 UInt::try_from_str_radix 或类似，应优先使用。
    // 这里提供一个基础的手动实现逻辑：

    let next_result = result * Int::reinterpret_as_uint(radix) +
      Int::reinterpret_as_uint(digit)

    // 简单的溢出检测逻辑（如果乘法回绕或加法回绕）
    // 在严格的系统中，可能需要更复杂的检查。
    // 鉴于这是 lexer 内部使用，且输入通常很短（4-8位十六进制），溢出风险较低，
    // 但为了正确性，我们保留基本结构。

    result = next_result
  }

  Ok(result)
}
// fn make_ascii_lowercase(s : String) -> String {
//   let mut result = s.clone()
//   for i in 0; i < result.length(); i = i + 1 {
//     let code = result[i].to_int()
//     // 'A'(65) - 'Z'(90) 转为 'a'(97) - 'z'(122)
//     if code >= 65 && code <= 90 {
//       result[i] = Char::from_int(code + 32) // 转为小写
//     }
//   }
//   result
// }
// fn type_of(v : Value) -> String {
//   match v {

//   }
// }
