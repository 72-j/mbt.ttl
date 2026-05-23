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

// 移除点段（根据 RFC 3986 6.2.2.3）
// 移除点段（根据 RFC 3986 6.2.2.3）

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
