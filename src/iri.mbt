///|
pub(all) struct Iri {
  scheme : StringView
  authority : StringView
  path : StringView
  query : StringView
  fragment : StringView
} derive(Debug, Eq, Default)

///|
pub fn Iri::Iri(
  scheme : StringView,
  authority : StringView,
  path : StringView,
  query : StringView,
  fragment : StringView,
) -> Iri {
  Iri::{ scheme, authority, path, query, fragment }
}

///|
pub(all) struct IriSpan {
  mut scheme : Span
  mut authority : Span
  mut path : Span
  mut query : Span
  mut fragment : Span
  mut pos : Int
} derive(Eq, Default)

///|
pub fn Iri::parse(
  _self : Iri,
  view : BytesView,
) -> Result[Iri, ParserError] {
  // let data = @utf8.encode(s)
  // let view = data[0:data.length()].to_array()
  match parse_iri(view, 0) {
    Ok(span) => Ok(span.build(view))
    Err(e) => Err(ParserError::IriErr(e.message()))
  }
}

///|
pub fn Iri::parse_unchecked(_self : Iri, view : BytesView) -> Iri {
  let span = IriSpan::default()
  span.pos = 0
  // 尝试解析，即使失败也继续
  span.parse_scheme(view)
  span.parse_authority(view)
  span.parse_path(view)
  span.parse_query(view)
  span.parse_fragment(view)
  span.build(view)
}

///|
/// 合并 IRI
pub fn Iri::resolve(
  self : Iri,
  ref_iri : BytesView,
  remove_dot_segments? : Bool = true,
) -> Result[Iri, ParserError] {
  let ref_parsed = match
    Iri::default().parse(
      ref_iri,
    ) {
    Ok(r) => r
    Err(e) => return Err(e)
  }

  // 如果参考 IRI 是绝对的，直接返回
  if ref_parsed.scheme.length() > 0 {
    return Ok(ref_parsed)
  }

  // 合并各个组件
  let scheme = self.scheme
  let authority = if ref_parsed.authority.length() > 0 {
    ref_parsed.authority
  } else {
    self.authority
  }

  // 路径合并：参考路径不以 / 开头时，合并到 base 路径的目录
  let path = if ref_parsed.path.length() > 0 && ref_parsed.path[0] == '/' {
    ref_parsed.path
  } else if ref_parsed.path.length() > 0 {
    let base_path = self.path
    let last_slash = base_path.rev_find("/")
    match last_slash {
      Some(idx) => base_path[0:idx + 1].to_owned() + ref_parsed.path.to_owned()
      None =>
        if base_path.is_empty() {
          // base 为空，相对路径保持原样
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
  let query = if ref_parsed.query.length() > 0 {
    ref_parsed.query
  } else {
    self.query
  }
  let fragment = if ref_parsed.fragment.length() > 0 {
    ref_parsed.fragment
  } else {
    self.fragment
  }

  Ok(Iri::{ scheme, authority, path, query, fragment })
}

///|
pub fn Iri::relativize(self : Iri, target : Iri) -> Result[Iri, ParserError] {
  // 如果 scheme 或 authority 不同，无法相对化
  if self.scheme != target.scheme || self.authority != target.authority {
    return Ok(target)
  }

  // 计算相对路径
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
pub fn Iri::resolve_unchecked(
  self : Iri,
  ref_iri : BytesView,
  remove_dot_segments? : Bool = true,
) -> Iri {
  // 尝试解析参考 IRI（忽略错误）
  let ref_parsed = Iri::default().parse_unchecked(ref_iri)

  // 如果参考 IRI 是绝对的，直接返回
  if ref_parsed.scheme.length() > 0 {
    return ref_parsed
  }

  // 合并各个组件
  let scheme = self.scheme
  let authority = if ref_parsed.authority.length() > 0 {
    ref_parsed.authority
  } else {
    self.authority
  }

  // 合并路径
  let path = if ref_parsed.path.has_prefix("/") {
    ref_parsed.path // 绝对路径，直接用
  } else if ref_parsed.path.length() > 0 {
    // 相对路径，合并到 base 的目录
    let base_path = self.path
    let last_slash = base_path.rev_find("/")
    match last_slash {
      Some(idx) =>
        if idx == 0 {
          // base = "/base"，没有中间目录
          // 直接拼接："/base" + "/" + "relative/path"
          base_path.to_owned() + "/" + ref_parsed.path.to_owned()
        } else {
          // base = "/dir/base"
          base_path[0:idx + 1].to_owned() + ref_parsed.path.to_owned()
        }
      None => ref_parsed.path.to_owned() // base 为空，直接用 reference
    }
  } else {
    self.path // reference 为空，用 base
  }
  let path = if remove_dot_segments {
    fn_remove_dot_segments(path)
  } else {
    path
  }

  let query = if ref_parsed.query.length() > 0 {
    ref_parsed.query
  } else {
    self.query
  }

  let fragment = ref_parsed.fragment

  Iri::{ scheme, authority, path, query, fragment }
}

///|
pub fn Iri::into_string(self : Iri) -> String {
  let s = StringBuilder::new()

  // scheme
  if self.scheme.length() > 0 {
    s.write_view(self.scheme)
    s.write_char(':')
  }

  // authority
  if self.authority.length() > 0 {
    s.write_string("//")
    s.write_view(self.authority)
  }

  // path
  s.write_view(self.path)

  // query
  if self.query.length() > 0 {
    s.write_char('?')
    s.write_view(self.query)
  }

  // fragment
  if self.fragment.length() > 0 {
    s.write_char('#')
    s.write_view(self.fragment)
  }

  s.to_string()
}

///|
pub fn fn_remove_dot_segments(path : StringView) -> StringView {
  if path.is_empty() {
    return path
  }

  let starts_with_slash = path[0] == '/'

  // 按 / 分割成段
  let parts = path.split("/")
  let result : Array[StringView] = []

  for part in parts {
    match part {
      "" | "." => () // 跳过空段和当前目录
      ".." =>
        if starts_with_slash {
          // 绝对路径：可以移除上一级
          if result.length() > 0 && result[result.length() - 1] != ".." {
            let _ = result.pop()
          }
          // 相对路径
        } else if result.length() > 0 && result[result.length() - 1] != ".." {
          let _ = result.pop() // 移除前一普通段
        }
      // 如果 result 为空或最后一个是 ..，就丢弃这个 ..
      _ => result.push(part)
    }
  }

  // 重建路径
  if result.is_empty() {
    if starts_with_slash {
      return "/"
    } else {
      return ""
    }
  }

  let final_path = result.join("/")
  if starts_with_slash {
    "/" + final_path
  } else {
    final_path
  }
}

///|
/// 字符类型查表
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
let is_auth_char : FixedArray[Bool] = {
  let arr = FixedArray::make(256, false)
  // 可见 ASCII（排除空格、#、?）
  for c in b'!'.to_int()..<=b'~'.to_int() {
    arr[c] = true
  }
  arr[b' '.to_int()] = false // 空格
  arr[b'#'.to_int()] = false
  arr[b'?'.to_int()] = false
  arr[b'/'.to_int()] = false // ← 添加，authority 结束标志
  arr[b'\n'.to_int()] = true
  arr
}

///|
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

///|
// fn peek(data : BytesView, pos : Int) -> Byte? {
//   if pos < data.length() {
//     Some(data[pos])
//   } else {
//     None
//   }
// }

///|
// fn IriSpan::advance(self : IriSpan) -> Unit {
//   self.pos += 1
// }

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
    self.pos += 1 // 消费 :
  } else {
    self.pos = start // 回退
  }
}

///|
/// 解析 authority
/// 解析 authority
fn IriSpan::parse_authority(self : IriSpan, data : BytesView) -> Unit {
  let len = data.length()
  // 检查 //（必须有两个 / 才算 authority）
  if self.pos + 1 < len && data[self.pos] == b'/' && data[self.pos + 1] == b'/' {
    self.pos += 2 // 消费 //
    let start = self.pos
    // authority 在 / ? # 或字符串结束时结束
    while self.pos < len && is_auth_char[data[self.pos].to_int()]{
      self.pos += 1
    }
    if self.pos > start {
      self.authority = (start, self.pos - start)
    }
  }
}

///|
/// 解析 path（遇到 ? # 空格 换行 停止，但包含 :）
fn IriSpan::parse_path(self : IriSpan, data : BytesView) -> Unit {
  let start = self.pos
  let len = data.length()
  while self.pos < len &&is_path_char[data[self.pos].to_int()] {
    self.pos += 1
  }
  if self.pos > start {
    self.path = (start, self.pos - start)
  }
}

///|
/// 解析 query
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
    if self.pos > start {
      self.query = (start, self.pos - start)
    }
  }
}

///|
/// 解析 fragment
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
    if self.pos > start {
      self.fragment = (start, self.pos - start)
    }
  }
}

// ============================================================
// 主解析函数
// ============================================================

///|
  /// 解析 IRI，返回 IriSpan
  pub fn parse_iri(data : BytesView, start : Int) -> Result[IriSpan, ParserError] {
    let span = IriSpan::default()
    span.pos = start
    let len = data.length()

    // 1. 尝试解析 scheme（可选）
    span.parse_scheme(data)

    // 2. 解析 authority（可选）
    span.parse_authority(data)

    // 3. 解析 path
    span.parse_path(data)

    // 4. 解析 query
    span.parse_query(data)

    // 5. 解析 fragment
    span.parse_fragment(data)

    // 6. query/fragment 都为空时，剩余输入追加到 path
    if span.query.1 == 0 && span.fragment.1 == 0 && span.pos < len {
      span.path = (span.path.0, len - span.path.0)
      span.pos = len
    }

    Ok(span)
  }
///|
/// 从 IriSpan 构建 Iri

///|
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
  let query = if self.query.1 > 0 {
    data[self.query.0:self.query.0 + self.query.1]
  } else {
    []
  }
  let fragment = if self.fragment.1 > 0 {
    data[self.fragment.0:self.fragment.0 + self.fragment.1]
  } else {
    []
  }
  Iri::{
    scheme: @utf8.decode_lossy(scheme),
    authority: @utf8.decode_lossy(authority),
    path: @utf8.decode_lossy(path),
    query: @utf8.decode_lossy(query),
    fragment: @utf8.decode_lossy(fragment),
  }
}

