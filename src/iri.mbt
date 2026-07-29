///|
pub(all) struct IriR {
  scheme : StringView
  authority : StringView?
  path : StringView
  query : StringView?
  fragment : StringView?
} derive(Debug, Eq, Default)

///|
pub fn IriR::IriR(
  scheme : StringView,
  authority : StringView?,
  path : StringView,
  query : StringView?,
  fragment : StringView?,
) -> IriR {
  IriR::{ scheme, authority, path, query, fragment }
}

///|
pub fn IriR::parse(_self : IriR, s : String) -> Result[IriR, IriError] {
  match parse_iri.run(@parserc.Seq::from_string(s)) {
    Some((Ok(iri), _)) => Ok(iri)
    Some((Err(e), _)) => Err(e)
    None => Err(IriError::UnexpectedEnd(0))
  }
}

///|
pub fn IriR::parse_unchecked(_self : IriR, s : String) -> IriR {
  match parse_iri.run(@parserc.Seq::from_string(s)) {
    Some((Ok(iri), _)) => iri
    Some((Err(_), _)) =>
      // 尝试返回尽可能多的信息
      IriR::{
        scheme: "",
        authority: None,
        path: s,
        query: None,
        fragment: None,
      }
    None =>
      IriR::{
        scheme: "",
        authority: None,
        path: s,
        query: None,
        fragment: None,
      }
  }
}

///|
/// 合并 IRI
pub fn IriR::resolve(
  self : IriR,
  ref_iri : String,
  remove_dot_segments? : Bool = true,
) -> Result[IriR, IriError] {
  let ref_parsed = match
    IriR::{ scheme: "", authority: None, path: "", query: None, fragment: None }.parse(
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
  let authority = if ref_parsed.authority is Some(_) {
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
  let query = if ref_parsed.query.unwrap_or_default().length() > 0 {
    ref_parsed.query
  } else {
    self.query
  }
  let fragment = if ref_parsed.fragment.unwrap_or_default().length() > 0 {
    ref_parsed.fragment
  } else {
    self.fragment
  }

  Ok(IriR::{ scheme, authority, path, query, fragment })
}

///|
pub fn IriR::relativize(self : IriR, target : IriR) -> Result[IriR, IriError] {
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

  Ok(IriR::{
    scheme: "",
    authority: None,
    path,
    query: target.query,
    fragment: target.fragment,
  })
}

///|
pub fn IriR::resolve_unchecked(
  self : IriR,
  ref_iri : String,
  remove_dot_segments? : Bool = true,
) -> IriR {
  // 尝试解析参考 IRI（忽略错误）
  let ref_parsed = IriR::{
    scheme: "",
    authority: None,
    path: "",
    query: None,
    fragment: None,
  }.parse_unchecked(ref_iri)

  // 如果参考 IRI 是绝对的，直接返回
  if ref_parsed.scheme.length() > 0 {
    return ref_parsed
  }

  // 合并各个组件
  let scheme = self.scheme
  let authority = if ref_parsed.authority is Some(_) {
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

  let query = if ref_parsed.query is Some(_) {
    ref_parsed.query
  } else {
    self.query
  }

  let fragment = ref_parsed.fragment

  IriR::{ scheme, authority, path, query, fragment }
}

///|
pub fn IriR::into_string(self : IriR) -> String {
  let s = StringBuilder::new()

  // scheme
  if self.scheme.length() > 0 {
    s.write_view(self.scheme)
    s.write_char(':')
  }

  // authority
  match self.authority {
    Some(auth) => {
      s.write_string("//")
      if auth.length() > 0 {
        // 添加 authority
        s.write_view(auth)
      }
    }
    None => ()
  }

  // path
  s.write_view(self.path)
  // query
  match self.query {
    Some(q) => {
      s.write_char('?')
      s.write_view(q)
    }
    None => ()
  }

  // fragment
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
/// 解析 scheme（遇到 : 停止）
fn parse_scheme(
  input : @parserc.Seq[Char],
) -> (StringView, @parserc.Seq[Char])? {
  let chars : Array[Char] = []
  let mut input = input
  for ;; {
    match input.uncons() {
      Some((c, rest)) =>
        if is_ascii_alphanumeric(c) {
          chars.push(c)
          input = rest
        } else {
          break
        }
      None => break
    }
  }
  if chars.is_empty() {
    None
  } else {
    let scheme = chars.fold(init="", fn(a, b) { a + b.to_string() })
    match input.uncons() {
      Some((':', rest)) => Some((scheme, rest))
      _ => None
    }
  }
}

///|
/// 解析 authority（遇到 // 开始，遇到 / ? # 空格 停止）
fn parse_authority(
  input : @parserc.Seq[Char],
) -> (StringView?, @parserc.Seq[Char])? {
  match input.uncons() {
    Some(('/', rest1)) =>
      match rest1.uncons() {
        Some(('/', rest2)) => {
          let chars : Array[Char] = []
          let mut input = rest2
          for ;; {
            match input.uncons() {
              Some((c, r)) =>
                if c != '/' && c != '?' && c != '#' && c != ' ' {
                  chars.push(c)
                  input = r
                } else {
                  break
                }
              None => break
            }
          }
          if chars.is_empty() {
            Some((None, rest2))
          } else {
            let auth = chars.fold(init="", fn(a, b) { a + b.to_string() })
            Some((Some(auth), input))
          }
        }
        _ => Some((None, input))
      }
    _ => Some((None, input))
  }
}

///|
/// 解析 path（遇到 ? # 空格 换行 停止）
fn parse_path(input : @parserc.Seq[Char]) -> (StringView, @parserc.Seq[Char])? {
  let chars : Array[Char] = []
  let mut input = input
  for ;; {
    match input.uncons() {
      Some((c, rest)) =>
        if c != '?' && c != '#' && c != ' ' && c != '\n' {
          chars.push(c)
          input = rest
        } else {
          break // ← 这里 break，但 input 是原始输入，没有消费任何字符
        }
      None => break
    }
  }
  if chars.is_empty() {
    // 没有消费任何字符，返回空 path 和原始输入
    Some(("", input))
  } else {
    let path = chars.fold(init="", fn(a, b) { a + b.to_string() })
    Some((path, input))
  }
}

///|
/// 解析 query（遇到 ? 开始，遇到 # 或空白停止）
fn parse_query(
  input : @parserc.Seq[Char],
) -> (StringView?, @parserc.Seq[Char])? {
  let (first, rest) = match input.uncons() {
    Some((c, rest)) => (c, rest)
    None => return Some((None, input))
  }

  if first != '?' {
    return Some((None, input))
  }

  let chars : Array[Char] = []
  let mut rest_view = rest
  for ;; {
    match rest_view.uncons() {
      Some((c, r)) =>
        if c != '#' && c != ' ' && c != '\n' {
          chars.push(c)
          rest_view = r
        } else {
          break
        }
      None => break
    }
  }

  if chars.is_empty() {
    Some((None, input)) // 关键：回退到原始 input
  } else {
    let query = chars.fold(init="", fn(a, b) { a + b.to_string() })
    Some((Some(query), rest_view))
  }
}

///|
/// 解析 fragment（遇到 # 开始，遇到空白停止）
fn parse_fragment(
  input : @parserc.Seq[Char],
) -> (StringView?, @parserc.Seq[Char])? {
  match input.uncons() {
    Some(('#', rest)) => {
      let chars : Array[Char] = []
      let mut rest_view = rest
      for ;; {
        match rest_view.uncons() {
          Some((c, r)) =>
            if c != ' ' && c != '\n' {
              chars.push(c)
              rest_view = r
            } else {
              break
            }
          None => break
        }
      }
      if chars.is_empty() {
        // fragment 为空，不消费 #
        Some((None, input)) // ← 保持 input 不变
      } else {
        let fragment = chars.fold(init="", fn(a, b) { a + b.to_string() })
        Some((Some(fragment), rest_view))
      }
    }
    _ => Some((None, input))
  }
}

///|
/// 完整的 IRI 解析器
pub let parse_iri : IriParser[IriR] = @parserc.Parser::new(fn(input) {
  // 1. 解析 scheme
  let (scheme, rest1) = parse_scheme(input).unwrap_or((""[:], input))

  // 2. 尝试 query 和 fragment（快速路径）
  let (query, rest2) = parse_query(rest1).unwrap_or((None, rest1))
  let (fragment, rest3) = parse_fragment(rest2).unwrap_or((None, rest2))

  // 3. 如果有 query 或 fragment，直接返回
  if query is Some(_) || fragment is Some(_) {
    return Some(
      (
        Ok(IriR::{ scheme, authority: None, path: ""[:], query, fragment }),
        rest3,
      ),
    )
  }

  // 4. 否则解析 authority、path、query、fragment
  let (auth, rest4) = parse_authority(rest3).unwrap_or((None, rest3))
  let (path, rest5) = parse_path(rest4).unwrap_or((""[:], rest4))
  let (query2, rest6) = parse_query(rest5).unwrap_or((None, rest5))
  let (fragment2, rest7) = parse_fragment(rest6).unwrap_or((None, rest6))

  // 5. query/fragment 都为空时，剩余输入追加到 path
  let final_path = if query2 is None(_) &&
    fragment2 is None(_) &&
    rest7.length() > 0 {
    path + rest7.to_string()
  } else {
    path
  }

  // 6. 返回结果
  Some(
    (
      Ok(IriR::{
        scheme,
        authority: auth,
        path: final_path,
        query: query2,
        fragment: fragment2,
      }),
      rest7,
    ),
  )
})
