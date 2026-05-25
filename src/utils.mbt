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


fn array_to_view(arr : Array[Byte]) -> Bytes {
  let bytes : Bytes = Bytes::from_array(arr) // 假设有此 API，或者 Bytes::of_array_view
  // let view : BytesView = bytes.view() // 假设 Bytes 有 .view() 方法
  return bytes
}


fn eq_ignore_ascii_case(s1 : String, s2 : String) -> Bool {
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

fn is_ascii_alphanumeric(c : Char) -> Bool {
  let code = c.to_int()
  // '0'=48, '9'=57, 'A'=65, 'Z'=90, 'a'=97, 'z'=122
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122)
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