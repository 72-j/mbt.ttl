///|
struct Iri[T] {
  base_iri : T
  mut state : ParserState
}

///|
pub struct IriPositions {
  mut scheme_end : Int
  mut authority_end : Int
  mut path_end : Int
  mut query_end : Int
}

///|
fn[T] Iri::Iri(base_iri~ : T, state~ : ParserState) -> Iri[T] {
  { base_iri, state }
}

///|
priv struct ParserState {
  mut pos : Int // 当前解析位置（字节索引）
  // 位置记录
  positions : IriPositions
}

///|
fn ParserState::ParserState(
  pos~ : Int,
  positions~ : IriPositions,
) -> ParserState {
  { pos, positions }
}

///|
fn IriPositions::IriPositions(
  scheme_end~ : Int,
  authority_end~ : Int,
  path_end~ : Int,
  query_end~ : Int,
) -> IriPositions {
  { scheme_end, authority_end, path_end, query_end }
}

///|
pub fn[T] Iri::default(base_iri : T) -> Iri[T] {
  {
    base_iri,
    state: ParserState::ParserState(
      pos=0,
      positions=IriPositions::IriPositions(
        scheme_end=0,
        authority_end=0,
        path_end=0,
        query_end=0,
      ),
    ),
  }
}

///|
// 定义 CharMatch 类型

// 修复 peek_match - 只查看不消耗
pub fn[T : IriInput] Iri::peek_match(
  self : Iri[T],
  pattern : CharMatch,
) -> Bool {
  let mut current_pos = self.state.pos
  let input_len = self.base_iri.len()

  for i in 0..<pattern.length() {
    if current_pos >= input_len {
      return false
    }

    match StringView::get_char(self.base_iri.to_str(), current_pos) {
      Some(c) => {
        if c != pattern[i] {
          return false
        }
        current_pos += c.utf16_len()
      }
      None => return false
    }
  }

  true
}

// 最常用的模式：尝试匹配并消费

///|
pub fn[T : IriInput] Iri::try_match_range(
  self : Iri[T],
  pattern : Array[CharMatchRule],
) -> Bool {
  let mut current_pos = self.state.pos

  for rule in pattern {
    if current_pos >= self.base_iri.len() {
      return false
    }

    match StringView::get_char(self.base_iri.to_str(), current_pos) {
      Some(c) => {
        let (expected, range_end) = rule
        let is_match = match range_end {
          Some(end) => c >= expected && c <= end
          None => c == expected
        }

        if !is_match {
          return false
        }

        current_pos += c.utf16_len()
      }
      None => return false
    }
  }

  // 匹配成功，更新状态
  self.state.pos = current_pos
  true
}

///|
pub fn[T : IriInput] Iri::peek_match_range(
  self : Iri[T],
  pattern : Array[CharMatchRule],
) -> Int? {
  let mut current_pos = self.state.pos
  let input_len = self.base_iri.len()

  for rule in pattern {
    // 检查是否越界
    if current_pos >= input_len {
      return None
    }

    // 获取当前字符
    match StringView::get_char(self.base_iri.to_str(), current_pos) {
      Some(c) => {
        let (expected, range_end) = rule

        let is_match = match range_end {
          Some(end) =>
            // 范围匹配: expected <= c <= end
            // 注意：Char 的比较在 MoonBit 中基于 Unicode 码点
            c >= expected && c <= end
          None =>
            // 精确匹配
            c == expected
        }

        if !is_match {
          return None
        }

        // 移动位置到下一个字符的起始字节
        current_pos += c.utf16_len() // 假设 StringView 基于 UTF-16 或 UTF-8，需与实际实现一致
      }
      None =>
        // 无效字符序列
        return None
    }
  }

  // 返回消耗的字节数
  Some(current_pos - self.state.pos)
}
// 解析完整的 IRI

///|
pub fn[T : IriInput] Iri::parse(
  self : Iri[T],
  unchecked? : Bool = false,
) -> Result[Iri[T], IriError] {
  // 保存起始位置，以便在无 scheme 时重置
  let start_pos = self.state.pos

  // 1. 解析 scheme
  let has_scheme = match self.parse_scheme() {
    Ok(has) => has
    Err(e) =>
      if unchecked {
        // 在 unchecked 模式下，如果 scheme 解析出错（极少见，因为 parse_scheme 内部主要返回 Ok(false)），
        // 我们假设没有 scheme 并重置位置，或者根据具体错误策略处理。
        // 这里为了稳健，如果 parse_scheme 报错，我们在 unchecked 下视为无 scheme
        self.state.pos = start_pos
        false
      } else {
        return Err(e)
      }
  }

  if has_scheme {
    // 期望 ':'
    match self.expect(':') {
      Ok(_) => self.state.positions.scheme_end = self.state.pos
      Err(e) =>
        if unchecked {
          // 如果缺少 ':' 但识别出了 scheme 字符，在 unchecked 模式下可能意味着这不是一个标准的 scheme
          // 或者我们强制认为它是 scheme 的一部分直到遇到非合法字符。
          // 简单策略：重置 scheme 标记，当作相对引用处理，或者保留当前位置但不标记 scheme_end
          // 这里选择重置，退化为相对路径解析
          self.state.pos = start_pos
          // 注意：此时 has_scheme 逻辑上应视为 false，但位置已移动。
          // 更安全的 unchecked 做法是：如果 expect 失败，不回退 pos，但也不记录 scheme_end
        } else {
          return Err(e)
        }
    }

    // 检查是否为 authority (//)
    // 只有在确实解析了 scheme 且后面跟着 :// 时才解析 authority
    // 注意：上面的 if has_scheme 块中，如果 expect(':') 失败且 unchecked，我们重置了 pos。
    // 所以需要重新检查当前状态是否真的拥有 scheme。
    // 简化逻辑：如果 scheme_end > 0，说明 scheme 解析成功

    if self.state.positions.scheme_end > 0 && self.peek_match(['/', '/']) {
      self.state.pos += 2 // 跳过 "//"
      match self.parse_authority() {
        Ok(_) => ()
        Err(e) => if !unchecked { return Err(e) }
        // unchecked: 忽略 authority 解析错误，继续解析路径
      }
    }
  } else {
    // 没有 scheme，重置位置到开始，作为相对引用解析
    self.state.pos = start_pos
  }

  // 2. 解析 path
  match self.parse_path() {
    Ok(_) => ()
    Err(e) => if !unchecked { return Err(e) }
    // unchecked: 忽略 path 错误
  }
  self.state.positions.path_end = self.state.pos

  // 3. 解析 query (可选)
  if self.peek_match(['?']) {
    match self.parse_query() {
      Ok(_) => ()
      Err(e) => if !unchecked { return Err(e) }
    }
  }
  self.state.positions.query_end = self.state.pos

  // 4. 解析 fragment (可选)
  if self.peek_match(['#']) {
    match self.parse_fragment() {
      Ok(_) => ()
      Err(e) => if !unchecked { return Err(e) }
    }
  }

  // 始终返回 Ok，因为在 unchecked 模式下我们忽略了错误
  // 在 checked 模式下，如果到达这里，说明所有步骤都成功了
  Ok(Iri::Iri(base_iri=self.base_iri, state=self.state))
}

///|
pub fn[T : IriInput] Iri::parse_scheme(self : Iri[T]) -> Result[Bool, IriError] {
  let start_pos = self.state.pos

  // 获取第一个字符
  let first = match self.peek() {
    Some(c) => c
    None => return Ok(false)
  }

  // scheme 必须以字母开头
  if !first.is_ascii_alphabetic() {
    return Ok(false)
  }

  // 移动位置
  self.state.pos += first.utf16_len()

  // 继续解析 scheme 字符
  while self.peek() is Some(c) {
    if c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      c == '+' ||
      c == '-' ||
      c == '.' {
      self.state.pos += c.utf16_len()
    } else if c == ':' {
      // 找到 scheme 结束
      return Ok(true)
    } else {
      // 无效字符，回退
      self.state.pos = start_pos
      return Ok(false)
    }
  }

  // 没有找到 ':'，回退
  self.state.pos = start_pos
  Ok(false)
}
// 解析 authority

///|
pub fn[T : IriInput] Iri::parse_authority(
  self : Iri[T],
) -> Result[Unit, IriError] {
  // self.state.positions.authority_start = self.state.pos

  // 解析 userinfo (可选)
  while self.peek() is Some(c) {
    if c == '@' {
      self.state.pos += c.utf16_len()
      break
    } else if c == '/' || c == '?' || c == '#' {
      break
    }
    self.state.pos += c.utf16_len()
  }

  // 解析 host
  self.parse_host().unwrap()

  // 解析 port (可选)
  if self.peek_match([':']) {
    self.state.pos += 1
    while self.peek() is Some(c) {
      if c.is_ascii_digit() {
        self.state.pos += c.utf16_len()
      } else {
        break
      }
    }
  }

  self.state.positions.authority_end = self.state.pos
  Ok(())
}

// 解析 host (支持 IPv4、IPv6、域名)

///|
pub fn[T : IriInput] Iri::parse_host(
  self : Iri[T],
  unchecked? : Bool = false,
) -> Result[Unit, IriError] {
  if self.peek_match(['[']) {
    match self.parse_ipv6_host() {
      Ok(_) => ()
      Err(e) => if !unchecked { return Err(e) }
      // unchecked: 忽略 IPv6 解析错误，继续解析域名
    }
  } else {
    match self.parse_domain_host() {
      Ok(_) => ()
      Err(e) => if !unchecked { return Err(e) }
      // unchecked: 忽略域名解析错误，继续解析 IPv4
    }
  }
  Ok(())
}

///|
pub fn[T : IriInput] Iri::parse_ipv6_host(
  self : Iri[T],
) -> Result[Unit, IriError] {
  self.state.pos += 1 // 跳过 '['
  while self.peek() is Some(c) {
    self.state.pos += c.utf16_len()
    if c == ']' {
      break
    }
  }
  Ok(())
}

///|
pub fn[T : IriInput] Iri::parse_domain_host(
  self : Iri[T],
) -> Result[Unit, IriError] {
  while self.peek() is Some(c) {
    if c == ':' || c == '/' || c == '?' || c == '#' {
      break
    }
    self.state.pos += c.utf16_len()
  }
  Ok(())
}

// 解析路径

///|
pub fn[T : IriInput] Iri::parse_path(self : Iri[T]) -> Result[Unit, IriError] {
  // self.state.positions.path_start = self.state.pos

  while self.peek() is Some(c) {
    if c == '?' || c == '#' {
      break
    }
    self.state.pos += c.utf16_len()
  }

  self.state.positions.path_end = self.state.pos
  Ok(())
}

// 解析 query
// 解析 query
// 解析 query

///|
pub fn[T : IriInput] Iri::parse_query(self : Iri[T]) -> Result[Unit, IriError] {
  self.state.pos += 1 // 跳过 '?'
  // let query_start = self.state.pos

  // 修复：使用 is_some() 检查是否存在字符，替代 while let
  while self.peek() is Some(c) {
    // let c = self.peek().unwrap()
    if c == '#' {
      break
    }
    self.state.pos += c.utf16_len()
  }

  self.state.positions.query_end = self.state.pos
  Ok(())
}

// 解析 fragment

///|
pub fn[T : IriInput] Iri::parse_fragment(
  self : Iri[T],
) -> Result[Unit, IriError] {
  self.state.pos += 1 // 跳过 '#'
  // self.state.positions.fragment_start = self.state.pos

  while self.peek() is Some(c) {
    self.state.pos += c.utf16_len()
  }

  // self.state.positions.query_end = self.state.pos // fragment 结束后，query_end 也指向这里
  Ok(())
}

// 辅助函数

///|
pub fn[T : IriInput] Iri::peek(self : Iri[T]) -> Char? {
  if self.state.pos >= self.base_iri.len() {
    None
  } else {
    // 使用 try? 或 match 更优雅地处理错误
    match StringView::get_char(self.base_iri.to_str(), self.state.pos) {
      Some(c) => Some(c)
      None => None // 无效的 UTF-16 序列
    }
  }
}

///|
pub fn[T : IriInput] Iri::peek_next(self : Iri[T]) -> Char? {
  if self.state.pos + 1 >= self.base_iri.len() {
    None
  } else {
    // 需要找到下一个字符的起始位置
    // 不能直接用 self.state.pos + 1，因为当前字符可能占多个字节

    let mut next_pos = self.state.pos
    // 跳过当前字符的所有字节
    match StringView::get_char(self.base_iri.to_str(), next_pos) {
      Some(c) => next_pos += c.utf16_len()
      None => return None
    }

    // 获取下一个字符
    if next_pos >= self.base_iri.len() {
      None
    } else {
      StringView::get_char(self.base_iri.to_str(), next_pos)
    }
  }
}

///|
pub fn[T : IriInput] Iri::expect(
  self : Iri[T],
  expected : Char,
) -> Result[Unit, IriError] {
  if self.peek() == Some(expected) {
    self.state.pos += expected.utf16_len()
    Ok(())
  } else {
    Err(IriError::Expected(expected, self.state.pos))
  }
}

///|
pub fn[T : IriInput] Iri::parse_percent_encoded(
  self : Iri[T],
) -> Result[Char, IriError] {
  if self.peek() != Some('%') {
    return Err(IriError::Expected('%', self.state.pos))
  }

  self.state.pos += 1 // 跳过 '%'

  let c1 = self.peek().unwrap()
  let c2 = self.peek_next().unwrap()

  if c1.is_ascii_hexdigit() && c2.is_ascii_hexdigit() {
    // 验证百分比编码，但不解码（保持原始形式）
    self.state.pos += 2 // 跳过两个十六进制字符
    Ok('%') // 返回 '%' 表示遇到了编码
  } else {
    Err(IriError::InvalidPercentEncoding(self.state.pos))
  }
}

// 解析单个路径段

///|
pub fn[T : IriInput] Iri::parse_path_segment(
  self : Iri[T],
) -> Result[String, IriError] {
  let start = self.state.pos

  while self.peek() is Some(c) {
    match c {
      '/' | '?' | '#' => break
      '%' => {
        let _ = self.parse_percent_encoded() // 验证百分比编码，但不解码
      }
      _ =>
        if is_pchar(c) {
          self.state.pos += c.utf16_len()
        } else {
          return Err(IriError::RelativePathSegment(c, self.state.pos))
        }
    }
  }

  Ok(self.base_iri.sub(start~, end=self.state.pos).to_owned())
}

// 2. Iri 结构中的完整实现

///|
pub fn[T] Iri::remove_dot_segments(_self : Iri[T], path : StringView) -> String {
  // 特殊处理空路径
  if path.length() == 0 {
    return ""
  }
  let parts_iter = path.split("/")

  let parts : Array[String] = parts_iter.map(fn(s) { s.to_owned() }).to_array()

  // 检测是否是绝对路径 (以 / 开头)
  let is_absolute = path.has_prefix("/")

  let cleaned_segments = remove_dot_segments_from_array(parts)

  // 重新构建字符串
  let result = cleaned_segments.join("/")

  if is_absolute {
    // 确保绝对路径以 / 开头
    // 如果 join 后的结果不以 / 开头（例如 segments 是 ["", "a"] -> "/a" 或 ["a"] -> "a"）
    // split 行为决定了一切。假设 split("/") on "/a/b" 产生 ["", "a", "b"]
    // join 后变成 "/a/b"。如果 pop 掉 "a", 变成 ["", "b"] -> "/b"。
    // 如果所有段都被 pop 掉，剩下 [""] -> ""。此时应返回 "/"
    if result == "" {
      return "/"
    } else if !result.has_prefix("/") {
      return "/" + result
    } else {
      return result
    }
    // 相对路径
  } else if result == "" {
    return "./" // 或者 ""，取决于具体需求
  } else {
    return result
  }
}

///|
pub fn[T : IriInput] Iri::as_str(self : Iri[T]) -> String {
  self.base_iri.to_str()
}

///|
pub fn[T : IriInput] Iri::validate(self : Iri[T]) -> Result[Unit, IriError] {
  // 保存原始状态
  let saved_state = self.state

  // 尝试解析（会修改 state）
  match self.parse() {
    Ok(_) => {
      // 解析成功，恢复原始状态（不保留解析结果）
      self.state = saved_state
      Ok(())
    }
    Err(e) => {
      // 解析失败，恢复原始状态
      self.state = saved_state
      Err(e)
    }
  }
}
