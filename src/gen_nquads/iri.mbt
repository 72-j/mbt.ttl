///| // IRI 解析器 - RFC 3987

///|

// IRI 结构: scheme://authority/path?query#fragment
pub(all) struct Iri {
  scheme : StringView
  authority : StringView?
  path : StringView
  query : StringView? // None = 未出现；Some("") = 出现但为空
  fragment : StringView? // 同上
} derive(Debug, Eq, Default)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend Iri with Default::{default}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend Iri with Eq::{equal, not_equal}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend Iri with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn Iri::Iri(
  scheme : StringView,
  authority : StringView?,
  path : StringView,
  query : StringView?,
  fragment : StringView?,
) -> Iri {
  Iri::{ scheme, authority, path, query, fragment, }
}

///|

// 解析中间状态: 存储各组件的 (偏移, 长度)
struct IriSpan {
  mut scheme : Span
  mut authority : Span
  mut has_authority : Bool // 「//」出现过（含空 authority，如 file:///a）——空串≠无
  mut path : Span
  mut query : Span? // None = 未出现
  mut fragment : Span? // None = 未出现
  mut pos : Int // 当前解析位置
} derive(Eq, Default)

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend IriSpan with Default::{default}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
pub extend IriSpan with Eq::{equal, not_equal}

// ============================================================
// 公共 API
// ============================================================

///|
/// 解析 IRI
pub fn parse(view : BytesView) -> Result[Iri, ParseError] {
  match parse_iri(view, 0) {
    Ok(span) => Ok(span.build(view))
    Err(e) => Err(ParseError::IriErr(ErrOut::message(e)))
  }
}

///|
/// 解析 IRI，忽略错误
fn parse_unchecked(view : BytesView) -> Iri {
  let span : IriSpan = Default::default()
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
  let authority = match ref_parsed.authority {
    Some(a) => Some(a)
    None => self.authority
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
  } else if ref_parsed.authority is Some(_) {
    // RFC 3986 §5.2.2：**authority 出现** ⇒ T.path = R.path（此处为空）——**不继承 base path**
    ref_parsed.path
  } else {
    self.path
  }
  let path = if remove_dot_segments {
    fn_remove_dot_segments(path)
  } else {
    path
  }
  // RFC 3986 §5.2.2：query 继承**只属"引用 path 为空"支**——
  //   空 path ⇒ 引用有 query 则覆盖、否则继承 base；非空 path ⇒ 一律取引用（未定义即丢）。
  // fragment 两档皆取引用（不继承）。
  let query = if ref_parsed.path.length() == 0 && ref_parsed.authority is None {
    // 空 path **且无 authority** ⇒ 才继承（R.query 有则覆盖）
    if ref_parsed.query is Some(_) {
      ref_parsed.query
    } else {
      self.query
    }
  } else {
    ref_parsed.query // authority 出现 或 path 非空 ⇒ 一律取引用（不继承）
  }
  let fragment = ref_parsed.fragment

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
    authority: None,
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
  let authority = match ref_parsed.authority {
    Some(a) => Some(a)
    None => self.authority
  }

  let path = if ref_parsed.path.has_prefix("/") {
    ref_parsed.path
  } else if ref_parsed.path.length() > 0 {
    let base_path = self.path
    let last_slash = base_path.rev_find("/")
    match last_slash {
      // RFC 3986 §5.2.3：base 取**最右 "/"（含）**前缀 + R.path——**无 idx==0 特例**
      Some(idx) => base_path[0:idx + 1].to_owned() + ref_parsed.path.to_owned()
      None => ref_parsed.path.to_owned()
    }
  } else if ref_parsed.authority is Some(_) {
    // RFC 3986 §5.2.2：**authority 出现** ⇒ T.path = R.path（此处为空）——**不继承 base path**
    ref_parsed.path
  } else {
    self.path
  }
  let path = if remove_dot_segments {
    fn_remove_dot_segments(path)
  } else {
    path
  }

  // 同上：query 继承只属"引用 path 为空"支
  let query = if ref_parsed.path.length() == 0 && ref_parsed.authority is None {
    // 空 path **且无 authority** ⇒ 才继承（R.query 有则覆盖）
    if ref_parsed.query is Some(_) {
      ref_parsed.query
    } else {
      self.query
    }
  } else {
    ref_parsed.query // authority 出现 或 path 非空 ⇒ 一律取引用（不继承）
  }

  let fragment = ref_parsed.fragment

  Iri::{ scheme, authority, path, query, fragment, }
}

///|
/// 序列化为字符串
pub fn Iri::into_string(self : Iri) -> String {
  let s = StringBuilder()

  if self.scheme.length() > 0 {
    s.write_view(self.scheme)
    s.write_char(':')
  }

  match self.authority {
    Some(a) => {
      s.write_string("//")
      s.write_view(a)
    }
    None => ()
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
fn fn_remove_dot_segments(path : StringView) -> StringView {
  // RFC 3986 §5.2.4 **字符串算法 A–E 逐字实现**（不 split/join 近似；空段不折叠）：
  //   A 剥前导 "../" / "./"；B "/./"或"/." ⇒ 前缀替换为 "/"；C "/../"或"/.." ⇒ 替换为 "/"
  //   **并弹出输出末段（含其前导 "/"，空段也可能被弹——08 `../xyz` 即此机理）**；D 剩余恰
  //   "."/".." ⇒ 清空；E 搬**首段（含前导 "/" 与到下一个 "/" 为止的全部字节）**到输出。
  let parts : Array[StringView] = []
  let n = path.length()
  let mut i = 0
  while i < n {
    let rest = path[i:]
    if rest.has_prefix("../") {
      i = i + 3
      continue
    }
    if rest.has_prefix("./") {
      i = i + 2
      continue
    }
    if rest == "." || rest == ".." {
      break
    }
    if rest.has_prefix("/./") {
      i = i + 2
      continue
    }
    if rest == "/." {
      // 恰好 "/."：RFC 替换为 "/" ⇒ **显式落一个 "/"**（指针模型下无法"留在输入流"），再让 D 收尾
      parts.push(rest[0:1])
      i = i + 1
      continue
    }
    if rest.has_prefix("/../") {
      i = i + 3
      if parts.length() > 0 {
        let _ = parts.pop()
      }
      continue
    }
    if rest == "/.." {
      // 恰好 "/.."：替换为 "/" + 弹末段 ⇒ 同样显式落 "/"
      if parts.length() > 0 {
        let _ = parts.pop()
      }
      parts.push(rest[0:1])
      i = i + 1
      continue
    }
    // E：首段 = 前导 "/"（如有）+ 到下一个 "/" 为止
    let leading = if rest.has_prefix("/") { 1 } else { 0 }
    let mut j = leading
    while j < rest.length() && rest[j] != '/' {
      j = j + 1
    }
    parts.push(rest[0:j])
    i = i + j
  }
  parts.join("")
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
  while self.pos < len &&
        (
          data[self.pos].to_int() >= 0x80 ||
          is_scheme_char[data[self.pos].to_int()]
        ) {
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
    // 「//」**出现**即记位——与 host 长度无关（`file:///a` 的空 authority 也必须记位，
    // 否则 resolve 会把它当"无 authority"而错继承 base 的 path/query）。
    self.has_authority = true
    let start = self.pos
    while self.pos < len &&
          (
            data[self.pos].to_int() >= 0x80 ||
            is_auth_char[data[self.pos].to_int()]
          ) {
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
  while self.pos < len &&
        (
          data[self.pos].to_int() >= 0x80 ||
          is_path_char[data[self.pos].to_int()]
        ) {
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
fn parse_iri(data : BytesView, start : Int) -> Result[IriSpan, ParseError] {
  let span : IriSpan = Default::default()
  span.pos = start
  let len = data.length()

  span.parse_scheme(data)
  span.parse_authority(data)
  span.parse_path(data)
  span.parse_query(data)
  span.parse_fragment(data)

  if span.query is None && span.fragment is None && span.pos < len {
    // 兜底**精确化**（2026-09-27）：剩余里若含 '#' / '?' 就按**最左者**切，只有都没有才整体并 path。
    // （原实现"剩余全并 path"会在任何扫描提前停下时吞掉 '#'/'?'——非 ASCII 路径曾因此吞 fragment。）
    let mut hash = -1
    let mut qm = -1
    let mut i = span.pos
    while i < len {
      if hash < 0 && qm < 0 && data[i] == b'#' {
        hash = i
      } else if hash < 0 && qm < 0 && data[i] == b'?' {
        qm = i
      }
      i += 1
    }
    if qm >= 0 && (hash < 0 || qm < hash) {
      span.path = (span.path.0, qm - span.path.0)
      span.query = Some((qm + 1, len - (qm + 1)))
      span.pos = len
    } else if hash >= 0 {
      span.path = (span.path.0, hash - span.path.0)
      span.fragment = Some((hash + 1, len - (hash + 1)))
      span.pos = len
    } else {
      span.path = (span.path.0, len - span.path.0)
      span.pos = len
    }
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
  let authority = if self.has_authority {
    Some(
      @utf8.decode_lossy(
        data[self.authority.0:self.authority.0 + self.authority.1],
      )[:],
    )
  } else {
    None
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
    authority,
    path: @utf8.decode_lossy(path),
    query,
    fragment,
  }
}
