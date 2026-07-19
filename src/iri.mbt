///|
pub type IrParser[A] = @parserc.Parser[Char, Result[A, IriError]]

///|
pub(all) struct IriR {
  scheme : StringView
  authority : StringView?
  path : StringView
  query : StringView?
  fragment : StringView?
} derive(Debug, Eq, Default)

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
pub fn IriR::into_string(self : IriR) -> String {
  let mut s = ""

  // scheme
  if self.scheme.length() > 0 {
    s = s + self.scheme.to_owned() + ":"
  }

  // authority
  match self.authority {
    Some(auth) => s = s + "//" + auth.to_owned()
    None => ()
  }

  // path
  s = s + self.path.to_owned()

  // query
  match self.query {
    Some(q) => s = s + "?" + q.to_owned()
    None => ()
  }

  // fragment
  match self.fragment {
    Some(f) => s = s + "#" + f.to_owned()
    None => ()
  }

  s
}

///|
fn parse_authority(
  input : @parserc.Seq[Char],
) -> (StringView?, @parserc.Seq[Char]) {
  match input.uncons() {
    Some(('/', rest1)) =>
      match rest1.uncons() {
        Some(('/', rest2)) => {
          let body = @parserc.pvalue(fn(ch : Char) {
            if ch != '/' && ch != '?' && ch != '#' && ch != ' ' && ch != '\n' {
              Some(ch)
            } else {
              None
            }
          }).repeat()
          match body.run(rest2) {
            Some((chars, r)) => {
              let result = (
                Some(
                  chars.iter().fold(init=""[:], fn(a, b) { a + b.to_string() }),
                ),
                r,
              )

              result
            }
            None => (Some(""), rest2)
          }
        }
        _ => (None, input)
      }
    _ => (None, input)
  }
}

///|
fn parse_query(input : @parserc.Seq[Char]) -> (StringView?, @parserc.Seq[Char]) {
  let result = match input.uncons() {
    Some(('?', rest)) => {
      let content = @parserc.pvalue(fn(c : Char) {
        if c != '#' && c != ' ' && c != '\n' {
          Some(c)
        } else {
          None
        }
      }).repeat()
      match content.run(rest) {
        Some((chars, r)) =>
          (
            Some(chars.iter().fold(init=""[:], fn(a, b) { a + b.to_string() })),
            r,
          )
        None => (Some(""), rest)
      }
    }
    _ => (None, input)
  }

  result
}

///|
fn parse_fragment(
  input : @parserc.Seq[Char],
) -> (StringView?, @parserc.Seq[Char]) {
  let result = match input.uncons() {
    Some(('#', rest)) => {
      let content = @parserc.pvalue(fn(c : Char) {
        if c != ' ' && c != '\n' {
          Some(c)
        } else {
          None
        }
      }).repeat()
      match content.run(rest) {
        Some((chars, r)) =>
          (
            Some(chars.iter().fold(init=""[:], fn(a, b) { a + b.to_string() })),
            r,
          )
        None => (Some(""), rest)
      }
    }
    _ => (None, input)
  }

  result
}

///|
fn parse_path(input : @parserc.Seq[Char]) -> (StringView, @parserc.Seq[Char]) {
  let content = @parserc.pvalue(fn(c : Char) {
    if c != '?' && c != '#' && c != ' ' && c != '\n' {
      Some(c)
    } else {
      None
    }
  }).repeat()
  let result = match content.run(input) {
    Some((chars, r)) =>
      (chars.iter().fold(init=""[:], fn(a, b) { a + b.to_string() }), r)
    None => ("", input)
  }

  result
}

///|
fn parse_scheme(input : @parserc.Seq[Char]) -> (StringView, @parserc.Seq[Char]) {
  let chars = @parserc.pvalue(fn(c : Char) {
    if is_ascii_alphanumeric(c) {
      Some(c)
    } else {
      None
    }
  }).repeat()
  let result = match chars.run(input) {
    Some((arr, rest)) =>
      (arr.iter().fold(init=""[:], fn(a, b) { a + b.to_string() }), rest)
    None => ("", input)
  }

  result
}

///|
fn parse_iri_rest(
  scheme : StringView,
  input : @parserc.Seq[Char],
) -> (Result[IriR, IriError], @parserc.Seq[Char])? {
  // 1. 先解析 query 和 fragment
  let (query, rest_q) = parse_query(input)
  let (fragment, rest_qf) = parse_fragment(rest_q)

  // 2. 如果有 query 或 fragment，不解析 path
  if query is Some(_) || fragment is Some(_) {
    return Some(
      (
        Ok(IriR::{ scheme, authority: None, path: "", query, fragment }),
        rest_qf,
      ),
    )
  }

  // 3. 没有 query/fragment，解析 authority
  let (auth, rest) = parse_authority(input)

  if auth is Some(_) {
    let (path, rest) = parse_path(rest)
    let (query, rest) = parse_query(rest)
    let (fragment, _) = parse_fragment(rest)
    Some((Ok(IriR::{ scheme, authority: auth, path, query, fragment }), rest))
  } else {
    // 无 authority 时，需要用 rest_qf 来解析 path
    let (path, rest) = parse_path(rest_qf)
    let (query, rest) = parse_query(rest)
    let (fragment, _) = parse_fragment(rest)
    Some((Ok(IriR::{ scheme, authority: None, path, query, fragment }), rest))
  }
}

///|
pub let parse_iri : IrParser[IriR] = @parserc.Parser::new(fn(
  input : @parserc.Seq[Char],
) -> (Result[IriR, IriError], @parserc.Seq[Char])? {
  let result = match input.uncons() {
    Some((':', rest)) => parse_iri_rest(""[:], rest)
    _ => {
      let (scheme, rest) = parse_scheme(input)

      match rest.uncons() {
        Some((':', rest)) => parse_iri_rest(scheme, rest)
        _ => parse_iri_rest(""[:], input)
      }
    }
  }
  // 
  result
})

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
