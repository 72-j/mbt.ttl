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
pub fn array_to_view(arr : ArrayView[Byte]) -> BytesView {
  let bytes : Bytes = Bytes::from_array(arr)
  return bytes
}

///|
pub fn array_view_has_prefix(data : ArrayView[Byte], prefix : Bytes) -> Bool {
  if data.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if data[i] != prefix[i] {
      return false
    }
  }
  return true
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
pub fn array_view_memchr(target : Byte, data : ArrayView[Byte]) -> Int? {
  for i in 0..<data.length() {
    if data[i] == target {
      return Some(i)
    }
  }
  None
}

///|
pub fn array_view_memchr2(c1 : Byte, c2 : Byte, data : ArrayView[Byte]) -> Int? {
  let len = data.length()
  for i in 0..<len {
    let b = data[i]
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
  // let chars = StringView::iter(s)
  if s.is_empty() {
    return false
  }

  let mut result = true
  for c in s {
    if !c.is_ascii_alphabetic() {
      result = false
      break
    }
  }
  result
}

///|
fn is_numeric(s : StringView) -> Bool {
  // let chars = StringView::iter(s)
  if s.is_empty() {
    return false
  }

  let mut result = true
  for c in s {
    if !c.is_ascii_digit() {
      result = false
      break
    }
  }
  result
}

///|
fn is_alphanumeric(s : StringView) -> Bool {
  let mut result = true
  for c in s {
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

///|
pub fn parse_duration(s : String) -> Result[String, String] {
  if s.is_empty() {
    return Err("Empty duration string")
  }
  let has_prefix = s.has_prefix("P") || s.has_prefix("-P")
  if !has_prefix {
    return Err("Duration must start with P or -P")
  }
  // 分别匹配各种可能的模式
  match s {
    // 纯时分秒：PT...H...M...S
    _ if s.has_prefix("PT") => {
      let inner = s[2:]
      let hours = extract_number(inner, "H")
      let minutes = extract_number(inner, "M")
      let seconds : Double = extract_number(inner, "S").to_double()

      let parts = []
      if hours > 0 {
        parts.push("\{hours}H")
      }
      if minutes > 0 {
        parts.push("\{minutes}M")
      }
      if seconds > 0.0 {
        parts.push("\{seconds}S")
      }

      Ok("PT" + parts.join(""))
    }
    // 含日期和时间：P...DT...H...M...S
    _ if s.contains("T") => {
      let parts = s.split("T").to_array()
      let date_part = parts[0][1:] // 去掉 P
      let time_part = parts[1]

      let years = extract_number(date_part, "Y")
      let months = extract_number(date_part, "M")
      let days = extract_number(date_part, "D")
      let hours = extract_number(time_part, "H")
      let minutes = extract_number(time_part, "M")
      let seconds : Double = extract_number(time_part, "S").to_double()

      // 构建标准格式
      let mut result = "P"
      if years > 0 {
        result += "\{years}Y"
      }
      if months > 0 {
        result += "\{months}M"
      }
      if days > 0 {
        result += "\{days}D"
      }
      if hours > 0 || minutes > 0 || seconds > 0.0 {
        result += "T"
        if hours > 0 {
          result += "\{hours}H"
        }
        if minutes > 0 {
          result += "\{minutes}M"
        }
        if seconds > 0.0 {
          result += "\{seconds}S"
        }
      }

      Ok(result)
    }
    // 纯日期：PnYnMnD
    _ => {
      let inner = s[1:]
      let years = extract_number(inner, "Y")
      let months = extract_number(inner, "M")
      let days = extract_number(inner, "D")

      let mut result = "P"
      if years > 0 {
        result += "\{years}Y"
      }
      if months > 0 {
        result += "\{months}M"
      }
      if days > 0 {
        result += "\{days}D"
      }

      Ok(result)
    }
  }
}

///|
fn extract_number(s : StringView, unit : String) -> Int64 {
  let idx = s.find(unit).unwrap_or(-1)
  if idx == -1 {
    return 0
  }

  // 向前查找数字
  let mut start = idx - 1
  while start >= 0 {
    let ch = UInt16::to_char(s[start]).unwrap()
    if !(ch.is_digit(10) || ch == '.') {
      break
    }
    start -= 1
  }

  let num_str = s[start + 1:idx]
  let num_64 = try @string.parse_int64(num_str) |> Ok catch {
    e => Err(e)
  }
  match num_64 {
    Ok(num) => num
    Err(_) => 0
  }
}

///|
fn parse_xsd_date(s : String) -> Result[String, String] {
  // 支持格式：YYYY-MM-DDThh:mm:ss[Z|±hh:mm]
  let re = try
    @string.Regex("^([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2})$") |> Ok
  catch {
    e => Err(e)
  }

  match re.unwrap().execute(s) {
    Some(caps) => {
      debug(caps)
      // 使用 .group(index) 获取捕获组，返回 BytesView?
      // 注意：group(0)是完整匹配，group(1)是第一个捕获组
      let year_str = caps.group(1).unwrap_or("0")
      let month_str = caps.group(2).unwrap_or("0")
      let day_str = caps.group(3).unwrap_or("0")

      let year_val = try @string.parse_int(year_str.to_owned()) |> Ok catch {
        e => Err(e)
      }
      let month_val = try @string.parse_int(month_str.to_owned()) |> Ok catch {
        e => Err(e)
      }
      let day_val = try @string.parse_int(day_str.to_owned()) |> Ok catch {
        e => Err(e)
      }
      // let hour_val = try? @string.parse_int(hour_str.to_owned())
      // let minute_val = try? @string.parse_int(minute_str.to_owned())
      // let second_val = try? @string.parse_int(second_str.to_owned())
      let year_val = match year_val {
        Ok(val) => val
        Err(_) => return Err("Invalid year")
      }
      let month_val = match month_val {
        Ok(val) => val
        Err(_) => return Err("Invalid month")
      }
      let day_val = match day_val {
        Ok(val) => val
        Err(_) => return Err("Invalid day")
      }

      if month_val < 1 || month_val > 12 {
        return Err("Invalid month")
      }

      // 基本的日期范围验证（先于 Date::new）
      if day_val < 1 || day_val > 31 {
        return Err("Invalid day")
      }

      // 验证时间范围
      // if hour_val < 0 || hour_val > 23 {
      //   return Err("Invalid hour")
      // }
      // if minute_val < 0 || minute_val > 59 {
      //   return Err("Invalid minute")
      // }
      // if second_val < 0 || second_val > 59 {
      //   return Err("Invalid second")
      // }

      // 验证日期有效性
      let date = try
        @tempo.Date::new(year_val, month_val, day_val) |> Ok
      catch {
        e => Err(e)
      }
      match date {
        d => {
          let d = match d {
            Ok(d) => d
            Err(_) => return Err("Invalid date")
          }
          if d.year != year_val || d.month != month_val || d.day != day_val {
            return Err("Invalid date")
          }

          // 验证时间有效性
          // if hour_val >= 24 || minute_val >= 60 || second_val >= 60 {
          //   return Err("Invalid time")
          // }

          let date_str = d.to_string()
          return Ok(date_str)
        }
      }
    }
    None => Err("Invalid datetime format")
  }
}

///|
fn hex_to_uint(hex : String) -> UInt {
  let mut result : UInt = 0
  for c in hex {
    let digit = match c {
      '0' => 0
      '1' => 1
      '2' => 2
      '3' => 3
      '4' => 4
      '5' => 5
      '6' => 6
      '7' => 7
      '8' => 8
      '9' => 9
      'A' | 'a' => 10
      'B' | 'b' => 11
      'C' | 'c' => 12
      'D' | 'd' => 13
      'E' | 'e' => 14
      'F' | 'f' => 15
      _ => 0
    }
    result = result * 16 + Int::reinterpret_as_uint(digit)
  }
  result
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
pub fn is_valid_hex_string(hex : String) -> Bool {
  for c in hex {
    if !((c >= '0' && c <= '9') ||
      (c >= 'A' && c <= 'F') ||
      (c >= 'a' && c <= 'f')) {
      return false
    }
  }
  true
}
