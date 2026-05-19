///|
pub struct Iri[T] {
  iri : T
  positions : IriElementsPositions
}

///|
pub fn[T : IriInput] IriRef::parse(
  iri : T,
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[IriRef[T], IriParseError] {
  let positions = IriParser::parse(
    iri.to_string(),
    None,
    VoidOutputBuffer::default(),
    unchecked~,
    remove_dot_segments~,
  ).unwrap()
  Ok({ iri, positions })
}

///|
pub fn[T : IriInput] IriRef::parse_unchecked(iri : T) -> IriRef[T] {
  let positions = IriParser::parse(
    iri.to_string(),
    None,
    VoidOutputBuffer::default(),
    unchecked=true,
    remove_dot_segments=false,
  ).unwrap()
  { iri, positions }
}

///|
pub fn[T : IriInput] IriRef::resolve(
  self : IriRef[T],
  iri : String,
) -> Result[IriRef[String], IriParseError] {
  let target_buffer = StringBuilder::new(
    size_hint=self.iri.len() + iri.length(),
  )
  let positions = IriParser::parse(
    iri.to_string(),
    Some(self.as_ref()),
    target_buffer,
    unchecked=false,
    remove_dot_segments=false,
  ).unwrap()
  Ok({ iri: target_buffer.to_string(), positions })
}

///|
pub fn[T : IriInput] IriRef::resolve_unchecked(
  self : IriRef[T],
  iri : String,
) -> IriRef[String] {
  let target_buffer = StringBuilder::new(
    size_hint=self.iri.len() + iri.length(),
  )
  let positions = IriParser::parse(
    iri.to_string(),
    Some(self.as_ref()),
    target_buffer,
    unchecked=true,
    remove_dot_segments=false,
  ).unwrap()
  { iri: target_buffer.to_string(), positions }
}

///|
pub fn[T : IriInput] IriRef::resolve_into(
  self : IriRef[T],
  iri : String,
  target_buffer : StringBuilder,
) -> Result[Unit, IriParseError] {
  let _ = IriParser::parse(
    iri,
    Some(self.as_ref()),
    target_buffer,
    unchecked=false,
    remove_dot_segments=false,
  ).unwrap()
  Ok(())
}

///|
pub fn[T : IriInput] IriRef::resolve_into_unchecked(
  self : IriRef[T],
  iri : String,
  target_buffer : StringBuilder,
) -> Unit {
  let _ = IriParser::parse(
    iri,
    Some(self.as_ref()),
    target_buffer,
    unchecked=true,
    remove_dot_segments=false,
  ).unwrap()
}

///|
pub fn[T : IriInput] IriRef::as_ref(self : IriRef[T]) -> IriRef[String] {
  { iri: self.iri.to_string(), positions: self.positions }
}

///|
pub fn[T : IriInput] IriRef::as_str(self : IriRef[T]) -> String {
  self.iri.to_string()
}

///|
pub fn[T] IriRef::into_inner(self : IriRef[T]) -> T {
  self.iri
}

///|
pub fn[T] IriRef::is_absolute(self : IriRef[T]) -> Bool {
  self.positions.scheme_end != 0
}

///|
pub fn[T : IriView] IriRef::scheme(self : IriRef[T]) -> String? {
  if self.positions.scheme_end == 0 {
    None
  } else {
    Some(self.iri.view(0, self.positions.scheme_end - 1).to_owned())
  }
}

///|
pub fn[T : IriView] IriRef::authority(self : IriRef[T]) -> String? {
  if self.positions.scheme_end + 2 > self.positions.authority_end {
    None
  } else {
    Some(
      self.iri
      .view(self.positions.scheme_end + 2, self.positions.authority_end)
      .to_owned(),
    )
  }
}

///|
pub fn[T : IriView] IriRef::path(self : IriRef[T]) -> String {
  self.iri
  .view(self.positions.authority_end, self.positions.path_end)
  .to_owned()
}

///|
pub fn[T : IriView] IriRef::query(self : IriRef[T]) -> String? {
  if self.positions.path_end >= self.positions.query_end {
    None
  } else {
    Some(
      self.iri
      .view(self.positions.path_end + 1, self.positions.query_end)
      .to_owned(),
    )
  }
}

///|
pub fn[T : IriView] IriRef::fragment(self : IriRef[T]) -> String? {
  if self.positions.query_end >= self.iri.len() {
    None
  } else {
    Some(self.iri.view(self.positions.query_end + 1, self.iri.len()).to_owned())
  }
}

pub fn[T : IriView, T2 : IriView + IriInput] Iri::relativize(
  self : Iri[T],
  abs : Iri[T2],
) -> Result[IriRef[String], IriParseError] {
  let base = self
  let abs_authority = abs.authority()
  let base_authority = base.authority()
  let abs_path = abs.path()
  let base_path = base.path()
  let abs_query = abs.query()
  let base_query = base.query()
  for segment in abs_path.split("/") {
    if segment is ("." | "..") {
      return Err(
        (
          IriParseError::RelativePathSegment(segment.to_owned()),
        ),
      )
    }
  }

  let cond1 = abs.scheme() != base.scheme()
  let cond2 = abs_authority is None &&
    (base_authority is Some(_) || abs_path.is_empty()) &&
    (!base_path.is_empty() || (abs_query is None && base_query is Some(_)))
  let cond3 = match abs_path.split_once(":") {
    Some((candidate_scheme, _)) => !candidate_scheme.contains("/")
    None => false
  }
  if cond1 || cond2 || cond3 {
    return Ok({ iri: abs.as_str(), positions: abs.positions })
  }
  // if abs.scheme() != base.scheme() || abs_authority.is_none() && (base_authority.is_some() || abs_path.is_empty() && (not(base_path.is_empty()) || abs_query.is_none() && base_query.is_some())) || abs_path.split_once(':').map_or(false, fn((candidate_scheme, _)) {   not(candidate_scheme.contains('/')) }) {
  //   return Ok({ iri: abs.0.to_string(), positions: abs.0.positions })
  // }

  let authority_changed = abs_authority != base_authority

  let empty_path_with_base_conditions = abs_path.is_empty() &&
    (!base_path.is_empty() || base_query is Some(_))

  let path_starts_with_double_slash = abs_path.has_prefix("//")

  if authority_changed ||
    empty_path_with_base_conditions ||
    path_starts_with_double_slash {
    let scheme_offset = abs.positions.scheme_end

    return Ok(IriRef::{
      iri: abs.as_str()[abs.positions.scheme_end:].to_owned(),
      positions: IriElementsPositions::{
        scheme_end: 0,
        authority_end: abs.positions.authority_end - scheme_offset,
        path_end: abs.positions.path_end - scheme_offset,
        query_end: abs.positions.query_end - scheme_offset,
      },
    })
  }
  if abs_path != base_path || (abs_query is None && base_query is Some(_)) {
    // 计算公共前缀长度
    let shared_bytes = abs_path
      .iter()
      .zip(base_path.iter())
      .take_while(fn(p) {
        let (l, r) = p
        l == r
      })
      .map(fn(p) {
        let (l, _) = p
        Char::utf16_len(l)
      })
      .fold(init=0, fn(acc, len) { acc + len })

    let last_slash = abs_path[:shared_bytes].find("/").map_or(0, p => p + 1)

    let needs_special = abs_path[last_slash:].has_prefix("/") ||
      base_path[last_slash:].contains("/") ||
      abs_path[last_slash:].contains(":")

    let offset = abs.positions.authority_end

    if needs_special {
      if !abs_path.has_prefix("/") && !base_path.is_empty() {
        return Ok({ iri: abs.as_str().to_string(), positions: abs.positions })
      } else {
        return Ok(IriRef::{
          iri: abs.as_str()[offset:].to_owned(),
          positions: IriElementsPositions::{
            scheme_end: 0,
            authority_end: 0,
            path_end: abs.positions.path_end - offset,
            query_end: abs.positions.query_end - offset,
          },
        })
      }
    }

    // 正常情况
    let remaining = abs.as_str()[offset + last_slash:]
    if remaining.is_empty() {
      let iri_builder = StringBuilder::new(
        size_hint=abs.as_str().length() - offset - last_slash + 1,
      )
      iri_builder.write_string(".")
      iri_builder.write_string(remaining.to_owned())

      let iri = IriRef::{
        iri: iri_builder.to_string(), // 修复点：转换为 String
        positions: IriElementsPositions::{
          scheme_end: 0,
          authority_end: 0,
          path_end: abs.positions.path_end - offset - last_slash + 1,
          query_end: abs.positions.query_end - offset - last_slash + 1,
        },
      }
      return Ok(iri)
    } else {
      let remaining = IriRef::{
        iri: remaining.to_owned(),
        positions: IriElementsPositions::{
          scheme_end: 0,
          authority_end: 0,
          path_end: abs.positions.path_end - offset - last_slash,
          query_end: abs.positions.query_end - offset - last_slash,
        },
      }
      return Ok(remaining)
    }
  }


  if abs_query != base_query {
    return Ok({
      iri: abs.as_str()[abs.positions.path_end:].to_owned(),
      positions: {
        scheme_end: 0,
        authority_end: 0,
        path_end: 0,
        query_end: abs.positions.query_end - abs.positions.path_end,
      },
    })
  }
  Ok({
    iri: abs.as_str()[abs.positions.query_end:].to_owned(),
    positions: { scheme_end: 0, authority_end: 0, path_end: 0, query_end: 0 },
  })
}

struct IriElementsPositions {
  mut scheme_end : Int
  mut authority_end : Int
  mut path_end : Int
  mut query_end : Int
} derive(Debug, Default)

///|
struct VoidOutputBuffer {
  mut len : Int
} derive(Debug, Default)

///|
struct ParserInput {
  value : Iter[Char]
  mut position : Int
}

///|
fn ParserInput::next(self : ParserInput) -> Char? {
  if self.value.next() is Some(head) {
    self.position += head.utf16_len()
    Some(head)
  } else {
    None
  }
}

///|
fn ParserInput::front(self : ParserInput) -> Char? {
  self.value.next()
}

///|
fn ParserInput::starts_with(self : ParserInput, c : Char) -> Bool {
  match self.front() {
    Some(next_char) => next_char == c
    None => false
  }
}

///|
pub struct IriParser[O] {
  iri : String
  base : IriRef[String]?
  mut input : ParserInput
  output : O
  output_positions : IriElementsPositions
  mut input_scheme_end : Int
}

///|
fn[O : IriOutput] IriParser::parse(
  iri : String,
  base : IriRef[String]?,
  output : O,
  unchecked~ : Bool,
  remove_dot_segments~ : Bool, // 新增参数
) -> Result[IriElementsPositions, IriParseError] {
  let parser = {
    iri,
    base,
    input: { value: iri.iter(), position: 0 },
    output,
    output_positions: {
      scheme_end: 0,
      authority_end: 0,
      path_end: 0,
      query_end: 0,
    },
    input_scheme_end: 0,
  }
  match parser.parse_scheme_start(unchecked~, remove_dot_segments~) {
    Ok(_) => Ok(parser.output_positions)
    Err(e) => Err(e)
  }
}

///|
fn[O : IriOutput] IriParser::parse_scheme_start(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  match self.input.front() {
    Some(':') =>
      if unchecked {
        self.parse_scheme(unchecked~, remove_dot_segments~)
      } else {
        Err(IriParseError::NoScheme)
      }
    Some(c) if c.is_ascii_alphabetic() =>
      self.parse_scheme(unchecked~, remove_dot_segments~)
    _ => self.parse_relative(unchecked~, remove_dot_segments~)
  }
}

///|
fn[O : IriOutput] IriParser::parse_scheme(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  while true {
    let c = self.input.next()
    match c {
      Some(c) if Char::is_ascii_alphabetic(c) ||
        Char::is_ascii_digit(c) ||
        c == '+' ||
        c == '-' ||
        c == '.' => {
        let _ = self.output.push(c)
      }
      Some(':') => {
        let _ = self.output.push(':')
        self.output_positions.scheme_end = self.output.len()
        self.input_scheme_end = self.input.position
        return if self.input.starts_with('/') {
          let _ = self.input.next()
          let _ = self.output.push('/')
          self.parse_path_or_authority(unchecked~, remove_dot_segments~)
        } else {
          self.output_positions.authority_end = self.output.len()
          self.parse_path(unchecked~, remove_dot_segments~)
        }
      }
      _ => {
        self.input = { value: self.iri.iter(), position: 0 }
        let _ = self.output.clear()
        return self.parse_relative(unchecked~, remove_dot_segments~)
      }
    }
  } nobreak {
    Err(
      (
        IriParseError::RelativePathSegment(
          "Unexpected end of input while parsing scheme",
        ),
      ),
    )
  }
}

///|
fn[O : IriOutput] IriParser::parse_path_or_authority(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  if self.input.starts_with('/') {
    let _ = self.input.next()
    let _ = self.output.push('/')
    self.parse_authority(unchecked~, remove_dot_segments~)
  } else {
    self.output_positions.authority_end = self.output.len() - 1
    self.parse_path(unchecked~, remove_dot_segments~)
  }
}

///|
fn[O : IriOutput] IriParser::parse_relative(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  if self.base is Some(base) {
    match self.input.front() {
      None => {
        let _ = self.output.push_str(
          base.iri[:base.positions.query_end].to_owned(),
        )
        self.output_positions.scheme_end = base.positions.scheme_end
        self.output_positions.authority_end = base.positions.authority_end
        self.output_positions.path_end = base.positions.path_end
        self.output_positions.query_end = base.positions.query_end
        Ok(())
      }
      Some('/') => {
        let _ = self.input.next()
        self.parse_relative_slash(base, unchecked~, remove_dot_segments~)
      }
      Some('?') => {
        let _ = self.input.next()
        let _ = self.output.push_str(
          base.iri[:base.positions.path_end].to_owned(),
        )
        let _ = self.output.push('?')
        self.output_positions.scheme_end = base.positions.scheme_end
        self.output_positions.authority_end = base.positions.authority_end
        self.output_positions.path_end = base.positions.path_end
        self.parse_query(unchecked~)
      }
      Some('#') => {
        let _ = self.input.next()
        let _ = self.output.push_str(
          base.iri[:base.positions.query_end].to_owned(),
        )
        self.output_positions.scheme_end = base.positions.scheme_end
        self.output_positions.authority_end = base.positions.authority_end
        self.output_positions.path_end = base.positions.path_end
        self.output_positions.query_end = base.positions.query_end
        let _ = self.output.push('#')
        self.parse_fragment(unchecked~)
      }
      _ => {
        let _ = self.output.push_str(
          base.iri[:base.positions.path_end].to_owned(),
        )
        self.output_positions.scheme_end = base.positions.scheme_end
        self.output_positions.authority_end = base.positions.authority_end
        self.output_positions.path_end = base.positions.path_end
        self.remove_last_segment()
        self.parse_relative_path(unchecked~, remove_dot_segments~)
      }
    }
  } else {
    self.output_positions.scheme_end = 0
    self.input_scheme_end = 0
    if self.input.starts_with('/') {
      let _ = self.input.next()
      let _ = self.output.push('/')
      self.parse_path_or_authority(unchecked~, remove_dot_segments~)
    } else {
      self.output_positions.authority_end = 0
      self.parse_relative_path(unchecked~, remove_dot_segments~)
    }
  }
}

///|
fn[O : IriOutput] IriParser::parse_relative_path(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  for ;; {
    match self.input.front() {
      Some(c) => {
        if c is ('/' | '?' | '#') {
          break
        }
        let _ = self.input.next()
        let _ = self.read_url_codepoint_or_echar(
          c,
          fn(c) { is_iunreserved_or_sub_delims(c) || c == '@' },
          unchecked~,
        )
      }
      _ => break
    }
  }
  self.parse_path(unchecked~, remove_dot_segments~)
}

///|
fn[O : IriOutput] IriParser::parse_relative_slash(
  self : IriParser[O],
  base : IriRef[String],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  if self.input.starts_with('/') {
    let _ = self.input.next()
    self.output.push_str(base.iri[:base.positions.scheme_end].to_owned())
    self.output_positions.scheme_end = base.positions.scheme_end
    self.output.push('/')
    self.output.push('/')
    self.parse_authority(unchecked~, remove_dot_segments~)
  } else {
    self.output.push_str(base.iri[:base.positions.authority_end].to_owned())
    self.output.push('/')
    self.output_positions.scheme_end = base.positions.scheme_end
    self.output_positions.authority_end = base.positions.authority_end
    self.parse_path(unchecked~, remove_dot_segments~)
  }
}

///|
fn[O : IriOutput] IriParser::parse_authority(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  let input = self.input
  // let start_pos = input.position

  // Moonbit 中 while true 需要确保所有路径返回，或者使用 loop/break 结构
  // 这里重构为更清晰的逻辑
  for ;; {
    let c = input.next()
    match c {
      Some('@') => {
        self.output.push('@')
        self.input = input
        return self.parse_host(unchecked~, remove_dot_segments~)
      }
      None | Some('/') | Some('?') | Some('#') => {
        // 回退到 "//" 之后
        // 注意：self.iri[start..] 是 StringView，需要转换为 Iter[Char]
        // 假设 ParserInput 的 value 字段接受 Iter[Char]
        let new_value = self.iri[self.input_scheme_end + 2:].iter()
        self.input = { value: new_value, position: self.input_scheme_end + 2 }
        self.output.truncate(self.output_positions.scheme_end + 2)
        return self.parse_host(unchecked~, remove_dot_segments~)
      }
      Some('[') => {
        self.input = input
        // 如果尚未实现 parse_ipv6_host，这里暂时返回错误或占位
        // return self.parse_ipv6_host() 
        return Err(
          (IriParseError::InvalidHostCharacter('[')),
        ) // 临时处理
      }
      Some(c) => {
        let is_valid = fn(c : Char) -> Bool {
          is_iunreserved_or_sub_delims(c) || c == ':'
        }
        // 修复点：显式忽略 Result 的 Ok 值，避免类型推断错误和隐式忽略警告
        let _ = self.read_url_codepoint_or_echar(c, is_valid, unchecked~)
      }
    }
  }
  // 理论上 loop 内部应该总是 return，如果退出循环说明逻辑漏洞
  Err(
    (
      IriParseError::RelativePathSegment("Unexpected end in authority"),
    ),
  )
}

///|
fn[O : IriOutput] IriParser::parse_host(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  if self.input.starts_with('[') {
    let start_position = self.input.position
    let input = self.input

    for ;; {
      match input.next() {
        Some(c) => {
          self.output.push(c)
          if c == ']' {
            let ip = self.iri[start_position + 1:input.position - 1]
            if !unchecked {
              if ip.has_prefix("v") || ip.has_prefix("V") {
                let _ = self.validate_ip_v_future(ip.to_owned())
              } else {
                let ip = try? @socket.Addr::parse(ip.to_owned())
                match ip {
                  Ok(addr) =>
                    if !addr.is_ipv6() {
                      return Err(
                        (
                          IriParseError::InvalidHostIp("Not an IPv6 address"),
                        ),
                      )
                    }
                  Err(_e) =>
                    return Err(
                      (
                        IriParseError::InvalidHostIp("Not an IPv6 address"),
                      ),
                    )
                }
              }
            }
            self.input = input
            let next_c = self.input.next()
            return match next_c {
              Some(':') => {
                self.output.push(':')
                self.parse_port(unchecked~, remove_dot_segments~)
              }
              None | Some('/') | Some('?') | Some('#') => {
                self.output_positions.authority_end = self.output.len()
                self.parse_path_start(next_c, unchecked~, remove_dot_segments~)
              }
              Some(c) =>
                if unchecked {
                  self.output.push(c)
                  continue
                } else {
                  return Err(
                    (
                      IriParseError::InvalidHostCharacter(c),
                    ),
                  )
                }
            }
          }
        }
        None =>
          return Err(
            (IriParseError::InvalidHostCharacter(']')),
          )
        // 或者更具体的错误，表示 IPv6 地址未正确闭合
      }
    }

    if unchecked {
      self.output_positions.authority_end = self.output.len()
      self.parse_path_start(None, unchecked~, remove_dot_segments~)
    } else {
      return Err(
        (IriParseError::InvalidHostCharacter('[')),
      )
    }
  } else {
    for ;; {
      let c = self.input.next()
      match c {
        Some(':') => {
          self.output.push(':')
          break self.parse_port(unchecked~, remove_dot_segments~)
        }
        None | Some('/') | Some('?') | Some('#') => {
          self.output_positions.authority_end = self.output.len()
          break self.parse_path_start(c, unchecked~, remove_dot_segments~)
        }
        Some(c) => {
          let _ = self.read_url_codepoint_or_echar(
            c,
            is_iunreserved_or_sub_delims,
            unchecked~,
          )
        }
      }
    }
  }
}

fn[O : IriOutput] IriParser::parse_port(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  for ;; {
    let c = self.input.next()
    match c {
      Some('/') | Some('?') | Some('#') | None => {
        self.output_positions.authority_end = self.output.len()
        return self.parse_path_start(c, unchecked~, remove_dot_segments~)
      }
      Some(c) =>
        if unchecked || c.is_ascii_digit() {
          self.output.push(c)
        } else {
          return Err(
            (IriParseError::InvalidPortCharacter(c)),
          )
        }
    }
  }
}

///|
fn[O : IriOutput] IriParser::parse_path_start(
  self : IriParser[O],
  c : Char?,
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  match c {
    None => {
      self.output_positions.path_end = self.output.len()
      self.output_positions.query_end = self.output.len()
      Ok(())
    }
    Some('?') => {
      self.output_positions.path_end = self.output.len()
      self.output.push('?')
      self.parse_query(unchecked~)
    }
    Some('#') => {
      self.output_positions.path_end = self.output.len()
      self.output_positions.query_end = self.output.len()
      self.output.push('#')
      self.parse_fragment(unchecked~)
    }
    Some('/') => {
      self.output.push('/')
      self.parse_path(unchecked~, remove_dot_segments~)
    }
    Some(c) => {
      let _ = self.read_url_codepoint_or_echar(
        c,
        fn(c) { is_iunreserved_or_sub_delims(c) || c is (':' | '@') },
        unchecked~,
      )
      self.parse_path(unchecked~, remove_dot_segments~)
    }
  }
}

///|
fn[O : IriOutput] IriParser::parse_path(
  self : IriParser[O],
  unchecked~ : Bool,
  remove_dot_segments~ : Bool,
) -> Result[Unit, IriParseError] {
  for ;; {
    let c = self.input.next()
    match c {
      None | Some('/') | Some('?') | Some('#') => {
        let output_str = self.output
        if remove_dot_segments {
          let output_path = output_str.as_str()[self.output_positions.authority_end:]
          if output_path.has_prefix("/..") {
            self.output.truncate(self.output.len() - 3)
            self.remove_last_segment()
          } else if output_path.has_prefix("/.") || output_path == "." {
            self.output.truncate(self.output.len() - 1)
          } else if output_path == ".." {
            self.output.truncate(self.output.len() - 2)
          } else if c == Some('/') {
            self.output.push('/')
            continue
          }
        } else if c == Some('/') {
          self.output.push('/')
          continue
        }
        let output_str = self.output
        if remove_dot_segments &&
          !unchecked &&
          output_str.as_str()[self.output_positions.authority_end:].has_prefix(
            "//",
          ) &&
          self.output_positions.authority_end ==
          self.output_positions.scheme_end {
          return Err(
            (IriParseError::PathStartingWithTwoSlashes),
          )
        }
        if c == Some('?') {
          self.output_positions.path_end = self.output.len()
          self.output.push('?')
          return self.parse_query(unchecked~)
        } else if c == Some('#') {
          self.output_positions.path_end = self.output.len()
          self.output_positions.query_end = self.output.len()
          self.output.push('#')
          return self.parse_fragment(unchecked~)
        } else if c is None {
          self.output_positions.path_end = self.output.len()
          self.output_positions.query_end = self.output.len()
          return Ok(())
        }
      }
      Some(c) => {
        let _ = self.read_url_codepoint_or_echar(
          c,
          fn(c) { is_iunreserved_or_sub_delims(c) || c is (':' | '@') },
          unchecked~,
        )
      }
    }
  }
}

///|
fn[O : IriOutput] IriParser::parse_query(
  self : IriParser[O],
  unchecked~ : Bool,
) -> Result[Unit, IriParseError] {
  let input = self.input
  for ;; {
    match input.next() {
      None => break
      Some('#') => {
        self.output_positions.query_end = self.output.len()
        self.output.push('#')
        self.input = input
        return self.parse_fragment(unchecked~) // 修改点：将 break 改为 return
      }
      Some(c) => {
        let is_valid = fn(ch) {
          is_iunreserved_or_sub_delims(ch) ||
          ch == ':' ||
          ch == '@' ||
          ch == '/' ||
          ch == '?' ||
          (ch >= '\u{E000}' && ch <= '\u{F8FF}') ||
          (ch >= '\u{F0000}' && ch <= '\u{FFFFD}') ||
          (ch >= '\u{100000}' && ch <= '\u{10FFFD}')
        }
        let _ = self.read_url_codepoint_or_echar(c, is_valid, unchecked~)
      }
    }
  }
  self.output_positions.query_end = self.output.len()
  Ok(())
}

///|
fn[O : IriOutput] IriParser::parse_fragment(
  self : IriParser[O],
  unchecked~ : Bool,
) -> Result[Unit, IriParseError] {
  let input = self.input
  for ;; {
    match input.next() {
      None => break
      Some(c) => {
        let is_valid = fn(ch) {
          is_iunreserved_or_sub_delims(ch) ||
          ch == ':' ||
          ch == '@' ||
          ch == '/' ||
          ch == '?'
        }
        let _ = self.read_url_codepoint_or_echar(c, is_valid, unchecked~)
      }
    }
  }
  Ok(())
}

///|
fn[O : IriOutput] IriParser::remove_last_segment(self : IriParser[O]) -> Unit {
  if self.output.as_str()[self.output_positions.authority_end:].rev_find("/")
    is Some(last_slash_position) {
    self.output.truncate(
      last_slash_position + self.output_positions.authority_end,
    )
    self.output.push('/')
  } else {
    self.output.truncate(self.output_positions.authority_end)
    if self.output_positions.authority_end > self.output_positions.scheme_end {
      self.output.push('/')
    }
  }
}

///|
fn[O : IriOutput] IriParser::read_url_codepoint_or_echar(
  self : IriParser[O],
  c : Char,
  valid : (Char) -> Bool,
  unchecked~ : Bool,
) -> Result[Unit, IriParseError] {
  if unchecked || valid(c) {
    self.output.push(c)
    Ok(())
  } else if c == '%' {
    self.read_echar()
  } else {
    Err((IriParseError::InvalidIriCodePoint(c)))
  }
}

///|
fn[O : IriOutput] IriParser::read_echar(
  self : IriParser[O],
) -> Result[Unit, IriParseError] {
  let c1 = self.input.next()
  let c2 = self.input.next()
  if c1.map_or(false, fn(c) { c.is_ascii_hexdigit() }) &&
    c2.map_or(false, fn(c) { c.is_ascii_hexdigit() }) {
    self.output.push('%')
    self.output.push(c1.unwrap())
    self.output.push(c2.unwrap())
    Ok(())
  } else {
    Err((IriParseError::InvalidPercentEncoding))
  }
}
// fn[O :IriOutput] IriParser::parse_error(self : IriParser[O], kind : IriParseErrorKind) -> Result[T, IriParseError] {
//   Err((kind))
// }

///|
fn[O] IriParser::validate_ip_v_future(
  _self : IriParser[O],
  ip : String,
) -> Result[Unit, IriParseError] {
  let chars = ip.iter()
  let c = chars
    .next()
    .unwrap_or(
      Err((IriParseError::InvalidHostCharacter(']'))).unwrap(),
    )
  if !(c is ('v' | 'V')) {
    return Err((IriParseError::InvalidHostCharacter(c)))
  }
  let mut with_a_version = false
  for c in chars {
    if c == '.' {
      break
    } else if c.is_ascii_hexdigit() {
      with_a_version = true
    } else {
      return Err(
        (IriParseError::InvalidHostCharacter(c)),
      )
    }
  }
  if !with_a_version {
    return Err(
      (
        IriParseError::InvalidHostCharacter(chars.next().unwrap_or(']')),
      ),
    )
  }
  if chars.next() is None {
    return Err(
      (IriParseError::InvalidHostCharacter(']')),
    )
  }
  for c in chars {
    if !is_unreserved_or_sub_delims(c) && c != ':' {
      return Err(
        (IriParseError::InvalidHostCharacter(c)),
      )
    }
  }
  Ok(())
}

///|
fn is_iunreserved_or_sub_delims(c : Char) -> Bool {
  c
  is ('a'..='z'
  | 'A'..='Z'
  | '0'..='9'
  | '!'
  | '$'
  | '&'
  | '\''
  | '('
  | ')'
  | '*'
  | '+'
  | ','
  | '-'
  | '.'
  | ';'
  | '='
  | '_'
  | '~'
  | '\u{A0}'..='\u{D7FF}'
  | '\u{F900}'..='\u{FDCF}'
  | '\u{FDF0}'..='\u{FFEF}'
  | '\u{10000}'..='\u{1FFFD}'
  | '\u{20000}'..='\u{2FFFD}'
  | '\u{30000}'..='\u{3FFFD}'
  | '\u{40000}'..='\u{4FFFD}'
  | '\u{50000}'..='\u{5FFFD}'
  | '\u{60000}'..='\u{6FFFD}'
  | '\u{70000}'..='\u{7FFFD}'
  | '\u{80000}'..='\u{8FFFD}'
  | '\u{90000}'..='\u{9FFFD}'
  | '\u{A0000}'..='\u{AFFFD}'
  | '\u{B0000}'..='\u{BFFFD}'
  | '\u{C0000}'..='\u{CFFFD}'
  | '\u{D0000}'..='\u{DFFFD}'
  | '\u{E0000}'..='\u{EFFFD}'
  | '\u{F0000}'..='\u{FFFFD}'
  | '\u{100000}'..='\u{10FFFD}')
}

///|
fn is_unreserved_or_sub_delims(c : Char) -> Bool {
  c
  is ('a'..='z'
  | 'A'..='Z'
  | '0'..='9'
  | '!'
  | '$'
  | '&'
  | '\''
  | '('
  | ')'
  | '*'
  | '+'
  | ','
  | '-'
  | '.'
  | ';'
  | '='
  | '_'
  | '~')
}
