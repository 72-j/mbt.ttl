///|
struct Iri {
  base_iri : String
  mut state : ParserState
} derive(Debug)

///|
struct IriRef(Ref[Iri])

///|
pub struct IriPositions {
  mut scheme_end : Int
  mut authority_end : Int
  mut path_end : Int
  mut query_end : Int
} derive(Default, Debug)

///|
fn IriRef::new(iri : Iri) -> IriRef {
  guard iri.base_iri.is_empty()

  IriRef(Ref::Ref(iri))
}

///|
fn IriRef::new_unchecked(iri : Iri) -> IriRef {
  IriRef(Ref::Ref(iri))
}

///|
fn IriRef::to_owned(iri_ref : IriRef) -> Iri {
  { base_iri: iri_ref.val.base_iri, state: iri_ref.val.state }
}

///|
priv struct ParserState {
  mut pos : Int // 当前解析位置（字节索引）
  // 位置记录
  positions : IriPositions
} derive(Debug)

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
pub fn Iri::Iri(base_iri : String) -> Iri {
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
pub fn IriRef::peek_match(self : IriRef, pattern : CharMatch) -> Bool {
  let mut current_pos = self.val.state.pos
  let input_len = self.val.as_ref().length()

  for i in 0..<pattern.length() {
    if current_pos >= input_len {
      return false
    }

    match StringView::get_char(self.val.base_iri, current_pos) {
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
pub fn IriRef::try_match_range(
  self : IriRef,
  pattern : Array[CharMatchRule],
) -> Bool {
  let mut current_pos = self.val.state.pos

  for rule in pattern {
    if current_pos >= self.val.as_ref().length() {
      return false
    }

    match StringView::get_char(self.val.base_iri, current_pos) {
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
  self.val.state.pos = current_pos
  true
}

///|
pub fn IriRef::peek_match_range(
  self : IriRef,
  pattern : Array[CharMatchRule],
) -> Int? {
  let mut current_pos = self.val.state.pos
  let input_len = self.val.as_ref().length()

  for rule in pattern {
    // 检查是否越界
    if current_pos >= input_len {
      return None
    }

    // 获取当前字符
    match StringView::get_char(self.val.base_iri, current_pos) {
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
  Some(current_pos - self.val.state.pos)
}
// 解析完整的 IRI

///|
pub fn IriRef::parse(
  self : IriRef,
  unchecked? : Bool = false,
) -> Result[Iri, IriError] {
  // 保存起始位置，以便在无 scheme 时重置
  let start_pos = self.val.state.pos

  // 1. 解析 scheme
  let has_scheme = match self.parse_scheme() {
    Ok(has) => has
    Err(e) =>
      if unchecked {
        // 在 unchecked 模式下，如果 scheme 解析出错（极少见，因为 parse_scheme 内部主要返回 Ok(false)），
        // 我们假设没有 scheme 并重置位置，或者根据具体错误策略处理。
        // 这里为了稳健，如果 parse_scheme 报错，我们在 unchecked 下视为无 scheme
        self.val.state.pos = start_pos
        false
      } else {
        return Err(e)
      }
  }

  if has_scheme {
    // 期望 ':'
    match self.expect(':') {
      Ok(_) => self.val.state.positions.scheme_end = self.val.state.pos
      Err(e) =>
        if unchecked {
          // 如果缺少 ':' 但识别出了 scheme 字符，在 unchecked 模式下可能意味着这不是一个标准的 scheme
          // 或者我们强制认为它是 scheme 的一部分直到遇到非合法字符。
          // 简单策略：重置 scheme 标记，当作相对引用处理，或者保留当前位置但不标记 scheme_end
          // 这里选择重置，退化为相对路径解析
          self.val.state.pos = start_pos
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

    if self.val.state.positions.scheme_end > 0 && self.peek_match(['/', '/']) {
      self.val.state.pos += 2 // 跳过 "//"
      match self.parse_authority() {
        Ok(_) => ()
        Err(e) => if !unchecked { return Err(e) }
        // unchecked: 忽略 authority 解析错误，继续解析路径
      }
    }
  } else {
    // 没有 scheme，重置位置到开始，作为相对引用解析
    self.val.state.pos = start_pos
  }

  // 2. 解析 path
  match self.parse_path() {
    Ok(_) => ()
    Err(e) => if !unchecked { return Err(e) }
    // unchecked: 忽略 path 错误
  }
  self.val.state.positions.path_end = self.val.state.pos

  // 3. 解析 query (可选)
  if self.peek_match(['?']) {
    match self.parse_query() {
      Ok(_) => ()
      Err(e) => if !unchecked { return Err(e) }
    }
  }
  self.val.state.positions.query_end = self.val.state.pos

  // 4. 解析 fragment (可选)
  if self.peek_match(['#']) {
    match self.parse_fragment() {
      Ok(_) => ()
      Err(e) => if !unchecked { return Err(e) }
    }
  }

  // 始终返回 Ok，因为在 unchecked 模式下我们忽略了错误
  // 在 checked 模式下，如果到达这里，说明所有步骤都成功了
  Ok({ base_iri: self.val.base_iri, state: self.val.state })
}

///|
pub fn IriRef::parse_scheme(self : IriRef) -> Result[Bool, IriError] {
  let start_pos = self.val.state.pos

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
  self.val.state.pos += first.utf16_len()

  // 继续解析 scheme 字符
  while self.peek() is Some(c) {
    if c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      c == '+' ||
      c == '-' ||
      c == '.' {
      self.val.state.pos += c.utf16_len()
    } else if c == ':' {
      // 找到 scheme 结束
      return Ok(true)
    } else {
      // 无效字符，回退
      self.val.state.pos = start_pos
      return Ok(false)
    }
  }

  // 没有找到 ':'，回退
  self.val.state.pos = start_pos
  Ok(false)
}
// 解析 authority

///|
pub fn IriRef::parse_authority(self : IriRef) -> Result[Unit, IriError] {
  // self.val.state.positions.authority_start = self.val.state.pos

  // 解析 userinfo (可选)
  while self.peek() is Some(c) {
    if c == '@' {
      self.val.state.pos += c.utf16_len()
      break
    } else if c == '/' || c == '?' || c == '#' {
      break
    }
    self.val.state.pos += c.utf16_len()
  }

  // 解析 host
  self.parse_host().unwrap()

  // 解析 port (可选)
  if self.peek_match([':']) {
    self.val.state.pos += 1
    while self.peek() is Some(c) {
      if c.is_ascii_digit() {
        self.val.state.pos += c.utf16_len()
      } else {
        break
      }
    }
  }

  self.val.state.positions.authority_end = self.val.state.pos
  Ok(())
}

// 解析 host (支持 IPv4、IPv6、域名)

///|
pub fn IriRef::parse_host(
  self : IriRef,
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
pub fn IriRef::parse_ipv6_host(self : IriRef) -> Result[Unit, IriError] {
  self.val.state.pos += 1 // 跳过 '['
  while self.peek() is Some(c) {
    self.val.state.pos += c.utf16_len()
    if c == ']' {
      break
    }
  }
  Ok(())
}

///|
pub fn IriRef::parse_domain_host(self : IriRef) -> Result[Unit, IriError] {
  while self.peek() is Some(c) {
    if c == ':' || c == '/' || c == '?' || c == '#' {
      break
    }
    self.val.state.pos += c.utf16_len()
  }
  Ok(())
}

// 解析路径

///|
pub fn IriRef::parse_path(self : IriRef) -> Result[Unit, IriError] {
  // self.val.state.positions.path_start = self.val.state.pos

  while self.peek() is Some(c) {
    if c == '?' || c == '#' {
      break
    }
    self.val.state.pos += c.utf16_len()
  }

  self.val.state.positions.path_end = self.val.state.pos
  Ok(())
}

// 解析 query
// 解析 query
// 解析 query

///|
pub fn IriRef::parse_query(self : IriRef) -> Result[Unit, IriError] {
  self.val.state.pos += 1 // 跳过 '?'
  // let query_start = self.val.state.pos

  // 修复：使用 is_some() 检查是否存在字符，替代 while let
  while self.peek() is Some(c) {
    // let c = self.peek().unwrap()
    if c == '#' {
      break
    }
    self.val.state.pos += c.utf16_len()
  }

  self.val.state.positions.query_end = self.val.state.pos
  Ok(())
}

// 解析 fragment

///|
pub fn IriRef::parse_fragment(self : IriRef) -> Result[Unit, IriError] {
  self.val.state.pos += 1 // 跳过 '#'
  // self.val.state.positions.fragment_start = self.val.state.pos

  while self.peek() is Some(c) {
    self.val.state.pos += c.utf16_len()
  }

  // self.val.state.positions.query_end = self.val.state.pos // fragment 结束后，query_end 也指向这里
  Ok(())
}

// 辅助函数

///|
pub fn IriRef::peek(self : IriRef) -> Char? {
  if self.val.state.pos >= self.val.as_ref().length() {
    None
  } else {
    // 使用 try? 或 match 更优雅地处理错误
    match StringView::get_char(self.val.base_iri, self.val.state.pos) {
      Some(c) => Some(c)
      None => None // 无效的 UTF-16 序列
    }
  }
}

///|
pub fn IriRef::peek_next(self : IriRef) -> Char? {
  if self.val.state.pos + 1 >= self.val.as_ref().length() {
    None
  } else {
    // 需要找到下一个字符的起始位置
    // 不能直接用 self.val.state.pos + 1，因为当前字符可能占多个字节

    let mut next_pos = self.val.state.pos
    // 跳过当前字符的所有字节
    match StringView::get_char(self.val.base_iri, next_pos) {
      Some(c) => next_pos += c.utf16_len()
      None => return None
    }

    // 获取下一个字符
    if next_pos >= self.val.as_ref().length() {
      None
    } else {
      StringView::get_char(self.val.base_iri, next_pos)
    }
  }
}

///|
pub fn IriRef::expect(self : IriRef, expected : Char) -> Result[Unit, IriError] {
  if self.peek() == Some(expected) {
    self.val.state.pos += expected.utf16_len()
    Ok(())
  } else {
    Err(IriError::Expected(expected, self.val.state.pos))
  }
}

///|
pub fn IriRef::parse_percent_encoded(self : IriRef) -> Result[Char, IriError] {
  if self.peek() != Some('%') {
    return Err(IriError::Expected('%', self.val.state.pos))
  }

  self.val.state.pos += 1 // 跳过 '%'

  let c1 = self.peek().unwrap()
  let c2 = self.peek_next().unwrap()

  if c1.is_ascii_hexdigit() && c2.is_ascii_hexdigit() {
    // 验证百分比编码，但不解码（保持原始形式）
    self.val.state.pos += 2 // 跳过两个十六进制字符
    Ok('%') // 返回 '%' 表示遇到了编码
  } else {
    Err(IriError::InvalidPercentEncoding(self.val.state.pos))
  }
}

// 解析单个路径段

///|
pub fn IriRef::parse_path_segment(self : IriRef) -> Result[String, IriError] {
  let start = self.val.state.pos

  while self.peek() is Some(c) {
    match c {
      '/' | '?' | '#' => break
      '%' => {
        let _ = self.parse_percent_encoded() // 验证百分比编码，但不解码
      }
      _ =>
        if is_pchar(c) {
          self.val.state.pos += c.utf16_len()
        } else {
          return Err(IriError::RelativePathSegment(c, self.val.state.pos))
        }
    }
  }

  Ok(self.val.base_iri.sub(start~, end=self.val.state.pos).to_owned())
}

// 2. Iri 结构中的完整实现

///|
pub fn Iri::remove_dot_segments(_self : Iri, path : StringView) -> String {
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
// pub fn IriRef::as_str(self : IriRef) -> String {
//   self.val.base_iri
// }

///|
pub fn IriRef::validate(self : IriRef) -> Result[Unit, IriError] {
  // 保存原始状态
  let saved_state = self.val.state

  // 尝试解析（会修改 state）
  match self.parse() {
    Ok(_) => {
      // 解析成功，恢复原始状态（不保留解析结果）
      self.val.state = saved_state
      Ok(())
    }
    Err(e) => {
      // 解析失败，恢复原始状态
      self.val.state = saved_state
      Err(e)
    }
  }
}

///|
pub fn IriRef::resolve(
  self : IriRef,
  ref_iri_str : String,
  remove_dot_segments? : Bool = true,
) -> Result[Iri, IriError] {
  // 1. 解析参考 IRI (Relative Reference)
  let ref_parser = Iri::Iri(ref_iri_str)
  let ref_parser = IriRef::new(ref_parser)
  // 注意：parse 会修改内部 state，所以我们需要一个解析后的副本或者确保后续只读
  // 由于 parse 返回 Result[Iri, ...]，我们直接使用解析后的对象
  let parsed_ref = match ref_parser.parse(unchecked=false) {
    Ok(iri) => iri
    Err(e) => return Err(e)
  }

  // 2. 如果参考 IRI 是绝对的，直接返回它
  // 利用 trait 方法 is_absolute
  if parsed_ref.is_absolute() {
    return Ok(parsed_ref)
  }

  // 3. 解析 Base IRI (当前 self)
  // 注意：self 可能尚未解析，或者状态已脏。为了安全，重新解析 self
  let base_parser = Iri::Iri(self.val.base_iri)
  let base_parser = IriRef::new(base_parser)
  let parsed_base = match base_parser.parse(unchecked=false) {
    Ok(iri) => iri
    Err(e) => return Err(e)
  }

  // 4. 提取组件 (使用 IriComponents trait)
  let base_scheme = parsed_base.scheme()
  let base_authority = parsed_base.authority()
  let base_path = parsed_base.path()

  let ref_scheme = parsed_ref.scheme()
  let ref_authority = parsed_ref.authority()
  let ref_path = parsed_ref.path()
  let ref_query = parsed_ref.query()
  let ref_fragment = parsed_ref.fragment()

  // 5. 构建目标 IRI 的各个部分

  // Scheme: 如果参考 IRI 有 scheme，则使用它；否则使用 Base 的 scheme
  let target_scheme = match ref_scheme {
    Some(s) => Some(s)
    None => base_scheme
  }

  // Authority: 如果参考 IRI 有 authority，则使用它；
  // 如果参考 IRI 没有 authority 但有 scheme，则无 authority；
  // 否则使用 Base 的 authority
  let target_authority = match ref_authority {
    Some(auth) => Some(auth)
    None => if ref_scheme != None { None } else { base_authority }
  }

  // Path: 核心合并逻辑
  let target_path = match ref_path {
    Some(r_path) =>
      if r_path == "" {
        // 如果参考路径为空字符串（例如 ?query 或 #frag），直接继承基路径
        match base_path {
          Some(p) => p
          None => ""
        }
      } else if r_path.has_prefix("/") {
        // 如果参考路径是绝对的，直接使用，并去除点段
        self.to_owned().remove_dot_segments(r_path)
      } else {
        // 如果参考路径是相对的，需要与 Base 路径合并
        let merged_raw = match base_path {
          Some(b_path) =>
            if b_path == "" && base_scheme != None && base_authority == None {
              // Base 是 http: 这种形式，路径为空，相对路径前加 /
              "/" + r_path
            } else {
              // 找到 Base 路径的最后一个 /
              let last_slash_idx = b_path.rev_find("/")
              match last_slash_idx {
                Some(idx) => {
                  // 保留目录部分
                  let base_dir = b_path.sub(start=0, end=idx + 1)
                  base_dir.to_owned() + r_path
                }
                None =>
                  // Base 没有 /，说明是整个文件名，替换它
                  // 但如果 base_path 本身为空（例如 base 是 http://host），则直接拼接
                  if b_path == "" {
                    "/" + r_path
                  } else {
                    r_path
                  }
              }
            }
          None =>
            // Base 没有路径部分
            "/" + r_path
        }
        if remove_dot_segments {
          self.to_owned().remove_dot_segments(merged_raw)
        } else {
          merged_raw
        }
      }
    None =>
      // 参考 IRI 没有路径，使用 Base 路径
      match base_path {
        Some(p) => p
        None => ""
      }
  }

  // Query: 如果参考 IRI 有 query，使用它；否则如果参考 IRI 有路径或 authority 或 scheme，则无 query；否则使用 Base query
  // 简化逻辑：RFC 3986 规定，如果 ref 有 query，用 ref 的；如果 ref 没有 query 但有其他非空部分（scheme/auth/path），则 query 为空；只有当 ref 几乎为空时才继承 base query? 
  // 实际上 RFC 说: If the URI reference defines a query component, then set the URI's query to that component; otherwise, set the URI's query to the base URI's query (if any).
  // 但是，如果 ref 定义了 path 或 authority 或 scheme，通常意味着它是一个新的资源定位，query 应该重置，除非显式指定。
  // 标准行为：
  // let target_query = match ref_query {
  //   Some(q) => Some(q)
  //   None => {
  //     // 如果 ref 有 scheme, authority, 或 path，则 query 为 None (除非 ref 显式给了 ?)
  //     // 这里 ref_query 是 None 意味着没给 ?
  //     if ref_scheme != None || ref_authority != None || ref_path != None {
  //       None
  //     } else {
  //       // ref 什么都没给，继承 base
  //       parsed_base.query()
  //     }
  //   }
  // }

  // 更严格的 RFC 3986 Section 5.2.2:
  // "If the URI reference defines a query component, then set the URI's query to that component; otherwise, set the URI's query to the base URI's query (if any)."
  // 这里的 "defines" 指的是语法上存在。在我们的 trait 中，query() 返回 None 表示不存在。
  let target_query = match ref_query {
    Some(q) => Some(q)
    None => parsed_base.query()
  }

  // Fragment: 类似 Query
  let target_fragment = match ref_fragment {
    Some(f) => Some(f)
    None => parsed_base.fragment()
  }

  // 6. 重组字符串
  let sb = StringBuilder::new()

  // Scheme
  match target_scheme {
    Some(s) => {
      sb.write(s)
      sb.write(":")
    }
    None => ()
  }

  // Authority
  match target_authority {
    Some(auth) => {
      sb.write("//")
      sb.write(auth)
    }
    None => ()
  }

  // Path
  sb.write(target_path)

  // Query
  match target_query {
    Some(q) => {
      sb.write("?")
      sb.write(q)
    }
    None => ()
  }

  // Fragment
  match target_fragment {
    Some(f) => {
      sb.write("#")
      sb.write(f)
    }
    None => ()
  }

  let final_str = sb.to_string()

  // 7. 返回新的 Iri 对象
  let final_parser = Iri::Iri(final_str)
  let final_parser = IriRef::new(final_parser)
  // 再次解析以确保内部状态一致，或者直接返回未解析但字符串正确的对象？
  // 通常 resolve 应该返回一个有效的 Iri 对象，所以再次 parse 是安全的
  final_parser.parse(unchecked=false)
}

///|
pub fn IriRef::resolve_unchecked(
  self : IriRef,
  ref_iri_str : String,
  remove_dot_segments? : Bool = true,
) -> Iri {
  // 1. 解析参考 IRI (Relative Reference) - Unchecked
  let ref_parser = Iri::Iri(ref_iri_str)
  let ref_parser = IriRef::new(ref_parser)
  // 忽略错误，如果解析失败，parsed_ref 将是一个处于初始状态或部分解析状态的对象
  let parsed_ref = match ref_parser.parse(unchecked=true) {
    Ok(iri) => iri
    Err(_) => ref_parser.to_owned() // 使用原始 parser 作为 fallback，其 state.pos 可能为 0
  }

  // 2. 如果参考 IRI 是绝对的，直接返回它 (Unchecked)
  // 注意：is_absolute 依赖于 scheme 的解析。如果 parse 失败，scheme 可能为空。
  if parsed_ref.is_absolute() {
    return parsed_ref
  }

  // 3. 解析 Base IRI (当前 self) - Unchecked
  let base_parser = Iri::Iri(self.val.base_iri)
  let base_parser = IriRef::new(base_parser)
  let parsed_base = match base_parser.parse(unchecked=true) {
    Ok(iri) => iri
    Err(_) => base_parser.to_owned()
  }

  // 4. 提取组件
  // 由于是 unchecked，这些方法应该能安全返回 Option[String]，即使内部状态不完全正确
  let base_scheme = parsed_base.scheme()
  let base_authority = parsed_base.authority()
  let base_path = parsed_base.path()

  let ref_scheme = parsed_ref.scheme()
  let ref_authority = parsed_ref.authority()
  let ref_path = parsed_ref.path()
  let ref_query = parsed_ref.query()
  let ref_fragment = parsed_ref.fragment()

  // 5. 构建目标 IRI 的各个部分

  // Scheme
  let target_scheme = match ref_scheme {
    Some(s) => Some(s)
    None => base_scheme
  }

  // Authority
  let target_authority = match ref_authority {
    Some(auth) => Some(auth)
    None => if ref_scheme != None { None } else { base_authority }
  }

  // Path: 核心合并逻辑
  let target_path = match ref_path {
    Some(r_path) =>
      if r_path.has_prefix("/") {
        // 绝对路径，去除点段
        self.to_owned().remove_dot_segments(r_path)
      } else {
        // 相对路径，与 Base 合并
        let merged_raw = match base_path {
          Some(b_path) =>
            if b_path == "" && base_scheme != None && base_authority == None {
              "/" + r_path
            } else {
              let last_slash_idx = b_path.rev_find("/")
              match last_slash_idx {
                Some(idx) => {
                  let base_dir = b_path.sub(start=0, end=idx + 1)
                  base_dir.to_owned() + r_path
                }
                None => if b_path == "" { "/" + r_path } else { r_path }
              }
            }
          None => "/" + r_path
        }
        if remove_dot_segments {
          self.to_owned().remove_dot_segments(merged_raw)
        } else {
          merged_raw
        }
      }
    None =>
      match base_path {
        Some(p) => p
        None => ""
      }
  }

  // Query
  let target_query = match ref_query {
    Some(q) => Some(q)
    None => parsed_base.query()
  }

  // Fragment
  let target_fragment = match ref_fragment {
    Some(f) => Some(f)
    None => parsed_base.fragment()
  }

  // 6. 重组字符串
  let sb = StringBuilder::new()

  match target_scheme {
    Some(s) => {
      sb.write(s)
      sb.write(":")
    }
    None => ()
  }

  match target_authority {
    Some(auth) => {
      sb.write("//")
      sb.write(auth)
    }
    None => ()
  }

  sb.write(target_path)

  match target_query {
    Some(q) => {
      sb.write("?")
      sb.write(q)
    }
    None => ()
  }

  match target_fragment {
    Some(f) => {
      sb.write("#")
      sb.write(f)
    }
    None => ()
  }

  let final_str = sb.to_string()

  // 7. 直接返回新的 Iri 对象，不进行严格解析验证
  Iri::Iri(final_str)
}

///|
// pub fn IriRef::resolve(
//   self : IriRef,
//   ref_iri : String,
// ) -> Result[Iri, IriError] {
//   // 1. 解析参考 IRI
//   let ref_parser = IriRef::Iri(ref_iri)
//   let parsed_ref = match ref_parser.parse(unchecked=false){
//     Ok(iri) => iri
//     Err(e) => return Err(e)
//   }

//   // 如果参考 IRI 是绝对的，直接返回
//   if parsed_ref.is_absolute() {
//     return Ok(parsed_ref)
//   }

//   // 2. 解析 Base IRI
//   let base_parser = IriRef::Iri(self.val.base_iri)
//   let parsed_base = match base_parser.parse(unchecked=false){
//     Ok(iri) => iri
//     Err(e) => return Err(e)
//   }

//   let sb = StringBuilder::new()

//   // 提取 Base 的关键位置
//   let b_scheme_end = parsed_base.state.positions.scheme_end
//   let b_auth_end = parsed_base.state.positions.authority_end
//   let b_path_end = parsed_base.state.positions.path_end

//   // 提取 Ref 的关键位置
//   let r_path_end = parsed_ref.state.positions.path_end
//   let r_query_end = parsed_ref.state.positions.query_end
//   let r_len = parsed_ref.base_iri.length()

//   // 3. 构建 Scheme 和 Authority (来自 Base)
//   if b_scheme_end > 0 {
//     sb.write(parsed_base.base_iri.sub(start=0, end=b_scheme_end))
//     if b_auth_end > b_scheme_end {
//       sb.write(parsed_base.base_iri.sub(start=b_scheme_end, end=b_auth_end))
//     }
//   }

//   // 4. 构建 Path
//   let ref_path = parsed_ref.base_iri.sub(start=0, end=r_path_end)
//   let merged_path = StringBuilder::new()

//   if ref_path.has_prefix("/") {
//     merged_path.write(ref_path.to_owned())
//   } else {
//     let base_path = parsed_base.base_iri.sub(start=b_auth_end, end=b_path_end)
//     if base_path == "" && b_scheme_end > 0 && b_auth_end == b_scheme_end {
//       merged_path.write("/") 
//       merged_path.write(ref_path.to_owned())
//     } else {
//       let last_slash = base_path.find("/")
//       let base_dir = match last_slash {
//         Some(idx) => base_path.sub(start=0, end=idx + 1)
//         None => ""
//       }
//       merged_path.write(base_dir)
//       merged_path.write(ref_path.to_owned())
//     }
//   }

//   // 移除 . 和 .. 并追加到 StringBuilder
//   sb.write(self.val.remove_dot_segments(merged_path.to_string()))

//   // 5. 构建 Query (仅当 Ref 存在时)
//   if r_query_end > r_path_end {
//     sb.write('?')
//     sb.write(parsed_ref.base_iri.sub(start=r_path_end + 1, end=r_query_end))
//   }

//   // 6. 构建 Fragment (仅当 Ref 存在时)
//   if r_query_end < r_len && StringView::get_char(parsed_ref.base_iri, r_query_end) == Some('#') {
//     sb.write('#')
//     sb.write(parsed_ref.base_iri.sub(start=r_query_end + 1, end=r_len))
//   }

//   // 7. 返回最终结果
//   let final_str = sb.to_string()
//   let final_parser = IriRef::Iri(final_str)
//   final_parser.parse(unchecked=false)
// }
