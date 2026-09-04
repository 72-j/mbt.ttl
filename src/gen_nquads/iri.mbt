///| // IRI 解析器 - RFC 3987

///|

// IRI 结构: scheme://authority/path?query#fragment
pub(all) struct Iri {
  scheme : StringView
  authority : StringView
  path : StringView
  query : StringView? // None = 未出现；Some("") = 出现但为空
  fragment : StringView? // 同上
} derive(Debug, Eq, Default)

///|
pub fn Iri::Iri(
  scheme : StringView,
  authority : StringView,
  path : StringView,
  query : StringView?,
  fragment : StringView?,
) -> Iri {
  Iri::{ scheme, authority, path, query, fragment, }
}

///|

// 解析中间状态: 存储各组件的 (偏移, 长度)
pub(all) struct IriSpan {
  mut scheme : Span
  mut authority : Span
  mut path : Span
  mut query : Span? // None = 未出现
  mut fragment : Span? // None = 未出现
  mut pos : Int // 当前解析位置
} derive(Eq, Default)

// ============================================================
// 公共 API
// ============================================================

///|
/// 解析 IRI
pub fn parse(view : BytesView) -> Result[Iri, ParseError] {
  match parse_iri(view, 0) {
    Ok(span) => Ok(span.build(view))
    Err(e) => Err(ParseError::IriErr(e.message()))
  }
}

///|
/// 解析 IRI，忽略错误
pub fn parse_unchecked(view : BytesView) -> Iri {
  let span = IriSpan::default()
  span.pos = 0
  span.parse_scheme(view)
  span.parse_authority(view)
  span.parse_path(view)
  span.parse_query(view)
  span.parse_fragment(view)
  span.build(view)
}

///|
/// 合并 base IRI 和参考 IRI (RFC 3986 5.2.2)
pub fn Iri::resolve(
  self : Iri,
  ref_iri : BytesView,
  remove_dot_segments? : Bool = true,
) -> Result[Iri, ParseError] {
  let ref_parsed = match parse(ref_iri) {
    Ok(r) => r
    Err(e) => return Err(e)
  }

  if ref_parsed.scheme.length() > 0 {
    return Ok(ref_parsed)
  }

  let scheme = self.scheme
  let authority = if ref_parsed.authority.length() > 0 {
    ref_parsed.authority
  } else {
    self.authority
  }

  let path = if ref_parsed.path.length() > 0 && ref_parsed.path[0] == '/' {
    ref_parsed.path
  } else if ref_parsed.path.length() > 0 {
    let base_path = self.path
    let last_slash = base_path.rev_find("/")
    match last_slash {
      Some(idx) => base_path[0:idx + 1].to_owned() + ref_parsed.path.to_owned()
      None =>
        if base_path.is_empty() {
          ref_parsed.path
        } else {
          "/" + ref_parsed.path.to_owned()
        }
    }
  } else {
    self.path
  }
  let path = if remove_dot_segments {
    fn_remove_dot_segments(path)
  } else {
    path
  }
  // 引用里出现 query/fragment（哪怕为空）就覆盖 base，否则继承
  let query = if ref_parsed.query is Some(_) {
    ref_parsed.query
  } else {
    self.query
  }
  let fragment = if ref_parsed.fragment is Some(_) {
    ref_parsed.fragment
  } else {
    self.fragment
  }

  Ok(Iri::{ scheme, authority, path, query, fragment, })
}

///|
/// 计算相对 IRI
pub fn Iri::relativize(self : Iri, target : Iri) -> Result[Iri, ParseError] {
  if self.scheme != target.scheme || self.authority != target.authority {
    return Ok(target)
  }

  let path = if self.path == target.path {
    ""
  } else if target.path.has_prefix(self.path) {
    let suffix = target.path[self.path.length():].to_owned()
    if !suffix.has_prefix("/") && suffix != "" {
      "./" + suffix
    } else {
      suffix
    }
  } else {
    target.path.to_owned()
  }

  Ok(Iri::{
    scheme: "",
    authority: "",
    path,
    query: target.query,
    fragment: target.fragment,
  })
}

///|
/// 合并 IRI，忽略错误
pub fn Iri::resolve_unchecked(
  self : Iri,
  ref_iri : BytesView,
  remove_dot_segments? : Bool = true,
) -> Iri {
  let ref_parsed = parse_unchecked(ref_iri)

  if ref_parsed.scheme.length() > 0 {
    return ref_parsed
  }

  let scheme = self.scheme
  let authority = if ref_parsed.authority.length() > 0 {
    ref_parsed.authority
  } else {
    self.authority
  }

  let path = if ref_parsed.path.has_prefix("/") {
    ref_parsed.path
  } else if ref_parsed.path.length() > 0 {
    let base_path = self.path
    let last_slash = base_path.rev_find("/")
    match last_slash {
      Some(idx) =>
        if idx == 0 {
          base_path.to_owned() + "/" + ref_parsed.path.to_owned()
        } else {
          base_path[0:idx + 1].to_owned() + ref_parsed.path.to_owned()
        }
      None => ref_parsed.path.to_owned()
    }
  } else {
    self.path
  }
  let path = if remove_dot_segments {
    fn_remove_dot_segments(path)
  } else {
    path
  }

  let query = if ref_parsed.query is Some(_) {
    ref_parsed.query
  } else {
    self.query
  }

  let fragment = ref_parsed.fragment

  Iri::{ scheme, authority, path, query, fragment, }
}

///|
/// 序列化为字符串
pub fn Iri::into_string(self : Iri) -> String {
  let s = StringBuilder::new()

  if self.scheme.length() > 0 {
    s.write_view(self.scheme)
    s.write_char(':')
  }

  if self.authority.length() > 0 {
    s.write_string("//")
    s.write_view(self.authority)
  }

  s.write_view(self.path)

  match self.query {
    Some(q) => {
      s.write_char('?')
      s.write_view(q)
    }
    None => ()
  }

  match self.fragment {
    Some(f) => {
      s.write_char('#')
      s.write_view(f)
    }
    None => ()
  }

  s.to_string()
}

///|
/// 规范化路径: 处理 . 和 .. (RFC 3986 5.2.4)
pub fn fn_remove_dot_segments(path : StringView) -> StringView {
  if path.is_empty() {
    return path
  }

  let starts_with_slash = path[0] == '/'

  let parts = path.split("/")
  let result : Array[StringView] = []

  for part in parts {
    match part {
      "" | "." => ()
      ".." =>
        if starts_with_slash {
          if result.length() > 0 && result[result.length() - 1] != ".." {
            let _ = result.pop()
          }
        } else if result.length() > 0 && result[result.length() - 1] != ".." {
          let _ = result.pop()
        }
      _ => result.push(part)
    }
  }

  if result.is_empty() {
    return if starts_with_slash { "/" } else { "" }
  }

  let final_path = result.join("/")
  if starts_with_slash {
    // 尾斜杠保留（目录引用语义，RFC 5.2.4 尾空段不可弃——subm-01 口径：
    // base /a/ 上解析 #x 得 /a/#x，吞尾斜杠会把文档引用改成父路径词项）
    if path[path.length() - 1] == '/' {
      "/" + final_path + "/"
    } else {
      "/" + final_path
    }
  } else if path[path.length() - 1] == '/' {
    final_path + "/"
  } else {
    final_path
  }
}

// ============================================================
// 字符集
// ============================================================

///|
/// scheme 字符: [0-9A-Za-z+-.]
let is_scheme_char : FixedArray[Bool] = {
  let arr = FixedArray::make(256, false)
  for c in b'0'.to_int()..<=b'9'.to_int() {
    arr[c] = true
  }
  for c in b'A'.to_int()..<=b'Z'.to_int() {
    arr[c] = true
  }
  for c in b'a'.to_int()..<=b'z'.to_int() {
    arr[c] = true
  }
  arr[b'+'.to_int()] = true
  arr[b'-'.to_int()] = true
  arr[b'.'.to_int()] = true
  arr
}

///|
/// authority 字符 (排除空格、#、?、/)
let is_auth_char : FixedArray[Bool] = {
  let arr = FixedArray::make(256, false)
  for c in b'!'.to_int()..<=b'~'.to_int() {
    arr[c] = true
  }
  arr[b' '.to_int()] = false
  arr[b'#'.to_int()] = false
  arr[b'?'.to_int()] = false
  arr[b'/'.to_int()] = false
  arr[b'\n'.to_int()] = true
  arr
}

///|
/// path 字符 (排除 #、?、空格、换行、制表符)
let is_path_char : FixedArray[Bool] = {
  let arr = FixedArray::make(256, false)
  for c in b'!'.to_int()..<=b'~'.to_int() {
    arr[c] = true
  }
  arr[b' '.to_int()] = false
  arr[b'#'.to_int()] = false
  arr[b'?'.to_int()] = false
  arr[b'\n'.to_int()] = false
  arr[b'\t'.to_int()] = false
  arr
}

// ============================================================
// 解析函数
// ============================================================

///|
/// 解析 scheme
fn IriSpan::parse_scheme(self : IriSpan, data : BytesView) -> Unit {
  let start = self.pos
  let len = data.length()
  while self.pos < len && is_scheme_char[data[self.pos].to_int()] {
    self.pos += 1
  }
  if self.pos > start && self.pos < len && data[self.pos] == b':' {
    self.scheme = (start, self.pos - start)
    self.pos += 1
  } else {
    self.pos = start
  }
}

///|
/// 解析 authority (//host:port)
fn IriSpan::parse_authority(self : IriSpan, data : BytesView) -> Unit {
  let len = data.length()
  if self.pos + 1 < len && data[self.pos] == b'/' && data[self.pos + 1] == b'/' {
    self.pos += 2
    let start = self.pos
    while self.pos < len && is_auth_char[data[self.pos].to_int()] {
      self.pos += 1
    }
    if self.pos > start {
      self.authority = (start, self.pos - start)
    }
  }
}

///|
/// 解析 path
fn IriSpan::parse_path(self : IriSpan, data : BytesView) -> Unit {
  let start = self.pos
  let len = data.length()
  while self.pos < len && is_path_char[data[self.pos].to_int()] {
    self.pos += 1
  }
  if self.pos > start {
    self.path = (start, self.pos - start)
  }
}

///|
/// 解析 query (?key=value)
fn IriSpan::parse_query(self : IriSpan, data : BytesView) -> Unit {
  let len = data.length()
  if self.pos < len && data[self.pos] == b'?' {
    self.pos += 1
    let start = self.pos
    while self.pos < len &&
          data[self.pos] != b'#' &&
          data[self.pos] != b' ' &&
          data[self.pos] != b'\n' {
      self.pos += 1
    }
    // 出现 '?' 即视为有 query（可能为空串）
    self.query = Some((start, self.pos - start))
  }
}

///|
/// 解析 fragment (#anchor)
fn IriSpan::parse_fragment(self : IriSpan, data : BytesView) -> Unit {
  let len = data.length()
  if self.pos < len && data[self.pos] == b'#' {
    self.pos += 1
    let start = self.pos
    while self.pos < len &&
          data[self.pos] != b' ' &&
          data[self.pos] != b'\n' &&
          data[self.pos] != b'\t' {
      self.pos += 1
    }
    // 出现 '#' 即视为有 fragment（可能为空串）
    self.fragment = Some((start, self.pos - start))
  }
}

///|
/// 主解析函数
pub fn parse_iri(data : BytesView, start : Int) -> Result[IriSpan, ParseError] {
  let span = IriSpan::default()
  span.pos = start
  let len = data.length()

  span.parse_scheme(data)
  span.parse_authority(data)
  span.parse_path(data)
  span.parse_query(data)
  span.parse_fragment(data)

  if span.query is None && span.fragment is None && span.pos < len {
    span.path = (span.path.0, len - span.path.0)
    span.pos = len
  }

  Ok(span)
}

///|
/// 从字节位置构建 Iri
fn IriSpan::build(self : IriSpan, data : BytesView) -> Iri {
  let scheme = if self.scheme.1 > 0 {
    data[self.scheme.0:self.scheme.0 + self.scheme.1]
  } else {
    []
  }
  let authority = if self.authority.1 > 0 {
    data[self.authority.0:self.authority.0 + self.authority.1]
  } else {
    []
  }
  let path = if self.path.1 > 0 {
    data[self.path.0:self.path.0 + self.path.1]
  } else {
    []
  }
  let query = match self.query {
    Some(q) => Some(@utf8.decode_lossy(data[q.0:q.0 + q.1])[:])
    None => None
  }
  let fragment = match self.fragment {
    Some(f) => Some(@utf8.decode_lossy(data[f.0:f.0 + f.1])[:])
    None => None
  }
  Iri::{
    scheme: @utf8.decode_lossy(scheme),
    authority: @utf8.decode_lossy(authority),
    path: @utf8.decode_lossy(path),
    query,
    fragment,
  }
}
