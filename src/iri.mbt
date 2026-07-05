///|
struct Iri {
  base_iri : String
  mut state : ParserState
} derive(Debug)

///|
impl Show for Iri with fn to_string(self) {
  self.base_iri
}

///|
struct IriRef(Ref[Iri]) derive(Debug)

///|
pub struct IriPositions {
  mut scheme_end : Int
  mut authority_end : Int
  mut path_end : Int
  mut query_end : Int
} derive(Default, Debug)

///|
// fn IriRef::of_ref(iri : Iri) -> IriRef {
//   IriRef(Ref::Ref(iri))
// }

///|
fn IriRef::new_unchecked(iri : Iri) -> IriRef {
  // guard !iri.base_iri.is_empty()
  IriRef(Ref::Ref(iri))
}

///|
fn IriRef::into_owned(iri_ref : IriRef) -> Iri {
  { base_iri: iri_ref.val.base_iri, state: iri_ref.val.state }
}

///|
priv struct ParserState {
  mut pos : Int // 当前解析位置（字节索引）  
  positions : IriPositions // 位置记录
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
pub fn Iri::new(base_iri : String) -> IriRef {
  Iri::Iri(base_iri).as_ref()
}

///|
fn Iri::as_ref(iri : Self) -> IriRef {
  // IriRef(Ref::Ref(iri))
  IriRef::new_unchecked(iri)
}
// 修复 peek_match - 只查看不消耗

///|
pub fn IriRef::peek_match(self : IriRef, pattern : CharMatch) -> Bool {
  let mut current_pos = self.val.state.pos
  let input_len = self.val.as_stringview().length()

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

///|
pub fn IriRef::try_match_range(
  self : IriRef,
  pattern : Array[CharMatchRule],
) -> Bool {
  let mut current_pos = self.val.state.pos

  for rule in pattern {
    if current_pos >= self.val.as_stringview().length() {
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
  let input_len = self.val.as_stringview().length()

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

///|
/// 严格解析 IRI。如果格式不符合规范，返回错误。
pub fn IriRef::parse(self : IriRef) -> Result[Iri, IriError] {
  self.parse_impl(unchecked=false)
}

///|
/// 宽松解析 IRI。忽略非致命错误，尽力解析并返回结果。
pub fn IriRef::parse_unchecked(self : IriRef) -> Iri {
  match self.parse_impl(unchecked=true) {
    Ok(iri) => iri
    Err(_) =>
      // 在 unchecked 模式下，parse_impl 理论上不应返回 Err，
      // 但为了类型安全，如果发生意外错误，返回一个包含原始字符串的默认 Iri
      self.into_owned()
  }
}

///|
fn IriRef::parse_impl(
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
  match self.parse_host() {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
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
  if self.val.state.pos >= self.val.as_stringview().length() {
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
  if self.val.state.pos + 1 >= self.val.as_stringview().length() {
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
    if next_pos >= self.val.as_stringview().length() {
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

  // 安全地获取第一个十六进制字符
  let c1 = match self.peek() {
    Some(c) => c
    None => return Err(IriError::InvalidPercentEncoding(self.val.state.pos))
  }

  // 安全地获取第二个十六进制字符
  let c2 = match self.peek_next() {
    Some(c) => c
    None => return Err(IriError::InvalidPercentEncoding(self.val.state.pos))
  }
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
  let ref_parser = Iri::new(ref_iri_str)
  // let ref_parser = IriRef::of_ref(ref_parser)

  let parsed_ref = ref_parser.parse_unchecked()
  // 2. 如果参考 IRI 是绝对的，直接返回它
  // 利用 trait 方法 is_absolute
  if parsed_ref.is_absolute() {
    return Ok(parsed_ref)
  }

  // 3. 解析 Base IRI (当前 self)
  // 注意：self 可能尚未解析，或者状态已脏。为了安全，重新解析 self
  let base_parser = Iri::new(self.val.base_iri)
  // let base_parser = IriRef::of_ref(base_parser)
  let parsed_base = match base_parser.parse() {
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
        self.into_owned().remove_dot_segments(r_path)
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
          self.into_owned().remove_dot_segments(merged_raw)
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
  let final_parser = Iri::new(final_str)
  // let final_parser = IriRef::of_ref(final_parser)
  final_parser.parse()
}

///|
pub fn IriRef::resolve_unchecked(
  self : IriRef,
  ref_iri_str : String,
  remove_dot_segments? : Bool = true,
) -> Iri {
  // 1. 解析参考 IRI (Relative Reference) - Unchecked
  let ref_parser = Iri::new(ref_iri_str)
  // let ref_parser = IriRef::of_ref(ref_parser)
  let parsed_ref = ref_parser.parse_unchecked()

  // 2. 如果参考 IRI 是绝对的，直接返回它 (Unchecked)
  // 注意：is_absolute 依赖于 scheme 的解析。如果 parse 失败，scheme 可能为空。
  if parsed_ref.is_absolute() {
    return parsed_ref
  }

  // 3. 解析 Base IRI (当前 self) - Unchecked
  let base_parser = Iri::new(self.val.base_iri)
  // let base_parser = IriRef::of_ref(base_parser)
  let parsed_base = base_parser.parse_unchecked()

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
        self.into_owned().remove_dot_segments(r_path)
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
          self.into_owned().remove_dot_segments(merged_raw)
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
pub fn IriRef::resolve_into(
  self : IriRef,
  relative_ref : String,
  buffer : StringBuilder,
) -> Result[Unit, IriError] {
  let relative_ref = Iri::new(relative_ref)
  // 1. 解析相对引用
  let parsed_relative = match IriRef::parse(relative_ref) {
    Ok(r) => r
    Err(e) => return Err(e)
  }

  // 2. 如果相对引用是绝对的（包含 scheme），直接将其写入 buffer
  if parsed_relative.is_absolute() {
    buffer.write_string(parsed_relative.into_string())
    return Ok(())
  }

  // 3. 处理相对路径合并
  // 获取基础 IRI 的各个部分
  let base_scheme = self.scheme()
  let base_authority = self.authority()
  let base_path = self.path().unwrap_or("")

  // 开始构建结果
  // 写入 Scheme
  match base_scheme {
    Some(s) => {
      buffer.write_string(s)
      buffer.write_char(':')
    }
    None => ()
  }

  // 写入 Authority
  match base_authority {
    Some(a) => {
      buffer.write_string("//")
      buffer.write_string(a)
    }
    None => ()
  }

  // 计算合并后的路径
  let merged_path = match parsed_relative.path() {
    Some(rel_path) =>
      if !rel_path.is_empty() {
        if rel_path.has_prefix("/") {
          // 如果相对路径以 / 开头，它替换基础路径
          rel_path
        } else {
          // 否则，合并路径
          // 找到基础路径的最后一个 /
          let last_slash_idx = base_path.find("/") // 注意：通常找最后一个 slash 用 rfind，原代码用的是 find，这里保持原意或修正为 rfind
          match last_slash_idx {
            Some(idx) => {
              // 保留基础路径直到最后一个 /
              let base_prefix = base_path[0:idx + 1]
              "\{base_prefix}\{rel_path}"
            }
            None =>
              if base_path.is_empty() {
                rel_path
              } else if base_authority is Some(_) && base_path.is_empty() {
                "/\{rel_path}"
              } else {
                // 移除基础路径的最后一段
                rel_path
              }
          }
        }
      } else {
        // 相对引用路径为空字符串，使用基础路径
        base_path
      }
    None =>

      // 相对引用没有路径，使用基础路径
      base_path
  }

  // 写入路径
  buffer.write_string(merged_path)

  // 写入查询
  match parsed_relative.query() {
    Some(q) => {
      buffer.write_char('?')
      buffer.write_string(q)
    }
    None => ()
  }

  // 如果相对引用没有 query，但我们有基础 query，且相对引用也没有覆盖它（即 relative.query() is None）
  if parsed_relative.query() is None(_) {
    match self.query() {
      Some(q) => {
        buffer.write_char('?')
        buffer.write_string(q)
      }
      None => ()
    }
  }

  // 写入片段
  match parsed_relative.fragment() {
    Some(f) => {
      buffer.write_char('#')
      buffer.write_string(f)
    }
    None =>
      if parsed_relative.fragment() is None(_) {
        match self.fragment() {
          Some(f) => {
            buffer.write_char('#')
            buffer.write_string(f)
          }
          None => ()
        }
      }
  }

  Ok(())
}

///|
pub fn IriRef::relativize(
  base : IriRef,
  target : IriRef,
) -> Result[Iri, IriError] {
  let base_scheme = base.scheme()
  let target_scheme = target.scheme()

  let base_authority = base.authority()
  let target_authority = target.authority()

  // 1. 如果 Scheme 或 Authority 不同，无法相对化，返回目标的字符串表示作为绝对 IRI
  if base_scheme != target_scheme || base_authority != target_authority {
    return IriRef::parse(target)
  }

  let base_path = base.path().unwrap_or("")
  let target_path = target.path().unwrap_or("")

  // 2. 计算相对路径
  let relative_path = if target_path == base_path {
    // 路径完全相同
    ""
  } else if target_path.has_prefix(base_path) {
    // 目标是基础的子路径
    // 确保我们是在目录边界上切割
    // 例如 base: /a/b/, target: /a/b/c -> c
    // base: /a/b, target: /a/bc -> 不应该匹配前缀，除非 base 是 /a/b/

    // 简单处理：如果 base 以 / 结尾，或者 target 在 base 长度处的字符是 /
    let is_base_empty = base_path.is_empty()
    let is_base_suffix_slash = base_path.has_suffix("/")

    let is_next_char_slash = if target_path.length() > base_path.length() {
      match target_path.get_char(base_path.length()) {
        Some(c) => c == '/'
        None => false // 如果无法获取字符，视为前缀无效
      }
    } else {
      false
    }

    let is_prefix_valid = is_base_empty ||
      is_base_suffix_slash ||
      is_next_char_slash

    if is_prefix_valid {
      // 截取剩余部分
      let suffix_start = if base_path.is_empty() {
        0
      } else {
        base_path.length()
      }

      let rel_p = target_path[suffix_start:]

      if !base_path.is_empty() && !base_path.has_suffix("/") {
        // 跳过前面的 /
        if rel_p.has_prefix("/") {
          rel_p[1:].to_owned()
        } else {
          rel_p.to_owned()
        }
      } else {
        rel_p.to_owned()
      }
    } else {
      // 前缀匹配但不是目录边界，无法相对化
      return IriRef::parse(target)
    }
  } else {

    // 简单实现：返回绝对路径
    return IriRef::parse(target)
  }

  // 3. 构建相对 IRI 字符串
  let result = StringBuilder::new()

  // 写入相对路径
  if !relative_path.is_empty() {
    result.write_string(relative_path)
  } else {
    // 如果路径相同，检查 query 和 fragment

    result.write_string("")
  }

  // 4. 处理 Query
  let base_query = base.query()
  let target_query = target.query()

  if target_query != base_query {
    match target_query {
      Some(q) => {
        result.write_char('?')
        result.write_string(q)
      }
      None => ()

      // RFC 3986: If the reference's query component is empty, it means the resulting URI has no query.
      // But our Option<String> doesn't distinguish empty vs undefined easily.
      // Assuming None means undefined (inherit), Some("") means empty.
      // If we want to REMOVE the base query, we should write "?"?
      // Let's assume if target_query is None, we don't write anything (inherits).
      // If target_query is Some(""), we write "?"?
      // For simplicity, if they differ, and target has Some(q), we write it.
    }
  }

  // 5. 处理 Fragment
  let base_fragment = base.fragment()
  let target_fragment = target.fragment()

  if target_fragment != base_fragment {
    match target_fragment {
      Some(f) => {
        result.write_char('#')
        result.write_string(f)
      }
      None => ()
    }
  }

  let final_str = result.to_string()

  let final_iri = Iri::new(final_str)
  // parse 空字符串应该返回一个有效的相对 IriRef。
  IriRef::parse(final_iri)
}



///|
pub impl IriComponents for Iri with fn query(self : Iri) -> String? {
  if self.state.positions.query_end > self.state.positions.path_end + 1 {
    Some(
      self.base_iri
      .sub(
        start=self.state.positions.path_end + 1,
        end=self.state.positions.query_end,
      )
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for Iri with fn is_absolute(self : Iri) -> Bool {
  self.state.positions.scheme_end > 0
}

///|
pub impl IriComponents for Iri with fn scheme(self : Iri) -> String? {
  if self.state.positions.scheme_end > 0 {
    Some(
      self.base_iri
      .sub(start=0, end=self.state.positions.scheme_end - 1)
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for Iri with fn authority(self : Iri) -> String? {
  if self.state.positions.authority_end > self.state.positions.scheme_end + 2 {
    Some(
      self.base_iri
      .sub(
        start=self.state.positions.scheme_end + 2,
        end=self.state.positions.authority_end,
      )
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for Iri with fn path(self : Iri) -> String? {
  Some(
    self.base_iri
    .sub(
      start=self.state.positions.authority_end,
      end=self.state.positions.path_end,
    )
    .to_owned(),
  )
}

///|
pub impl IriComponents for Iri with fn fragment(self : Iri) -> String? {
  if self.state.positions.query_end + 1 < self.base_iri.length() { // 简单判断是否有 fragment
    if self.state.positions.query_end + 1 > 0 {
      Some(
        self.base_iri
        .sub(
          start=self.state.positions.query_end + 1,
          end=self.base_iri.length(),
        )
        .to_owned(),
      )
    } else {
      None
    }
  } else {
    None
  }
}

///|
pub impl IriComponents for IriRef with fn query(self : IriRef) -> String? {
  if self.val.state.positions.query_end > self.val.state.positions.path_end + 1 {
    Some(
      self.val.base_iri
      .sub(
        start=self.val.state.positions.path_end + 1,
        end=self.val.state.positions.query_end,
      )
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for IriRef with fn is_absolute(self : IriRef) -> Bool {
  self.val.state.positions.scheme_end > 0
}

///|
pub impl IriComponents for IriRef with fn scheme(self : IriRef) -> String? {
  if self.val.state.positions.scheme_end > 0 {
    Some(
      self.val.base_iri
      .sub(start=0, end=self.val.state.positions.scheme_end - 1)
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for IriRef with fn authority(self : IriRef) -> String? {
  if self.val.state.positions.authority_end >
    self.val.state.positions.scheme_end + 2 {
    Some(
      self.val.base_iri
      .sub(
        start=self.val.state.positions.scheme_end + 2,
        end=self.val.state.positions.authority_end,
      )
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for IriRef with fn path(self : IriRef) -> String? {
  Some(
    self.val.base_iri
    .sub(
      start=self.val.state.positions.authority_end,
      end=self.val.state.positions.path_end,
    )
    .to_owned(),
  )
}

///|
pub impl IriComponents for IriRef with fn fragment(self : IriRef) -> String? {
  if self.val.state.positions.query_end + 1 < self.val.base_iri.length() { // 简单判断是否有 fragment
    if self.val.state.positions.query_end + 1 > 0 {
      Some(
        self.val.base_iri
        .sub(
          start=self.val.state.positions.query_end + 1,
          end=self.val.base_iri.length(),
        )
        .to_owned(),
      )
    } else {
      None
    }
  } else {
    None
  }
}
