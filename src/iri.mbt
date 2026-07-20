///|
pub type IriParser[A] = @parserc.Parser[Char, Result[A, IriError]]

///|
pub type ResParser[A] = (Result[A, IriError], @parserc.Seq[Char])?

///|
pub(all) struct IriR {
  scheme : StringView
  authority : StringView?
  path : StringView
  query : StringView?
  fragment : StringView?
} derive(Debug, Eq, Default)

///|
pub let parse_iri : IriParser[IriR] = @parserc.Parser::new(fn(
  input : @parserc.Seq[Char],
) -> ResParser[IriR] {

  // 🔑 用组合子检查是否有 scheme
  let scheme_part = @parserc.pvalue(fn(c : Char) {
    if is_ascii_alphanumeric(c) {
      Some(c)
    } else {
      None
    }
  }).repeat()
  let with_colon = scheme_part.and_then(@parserc.pchar(':'))

  match with_colon.run(input) {
    Some(((scheme_chars, _), rest2)) => {
      // 有 scheme
      let scheme = scheme_chars.fold(init=""[:], fn(a, b) { a + b.to_string() })

      parse_iri_body(scheme).run(rest2)
    }
    None =>
      // 无 scheme

      parse_iri_body(""[:]).run(input)
  }
})

///|
fn parse_iri_body(scheme : StringView) -> IriParser[IriR] {

  // query（遇到 # 停止）
  let query_parser = @parserc.pchar('?')
    .and_then(
      @parserc.pvalue(fn(c : Char) {
        // 🔑 修改：遇到 # 也要停止
        if c != ' ' && c != '\n' && c != '#' {
          Some(c)
        } else {
          None
        }
      }).repeat(),
    )
    .omit_first()
    .optional()
    .map(fn(opt) -> StringView? {
      match opt {
        Some(chars) =>
          Some(chars.fold(init=""[:], fn(a, b) { a + b.to_string() }))
        None => None
      }
    })

  // fragment
  let fragment_parser = @parserc.pchar('#')
    .and_then(
      @parserc.pvalue(fn(c : Char) {
        if c != ' ' && c != '\n' {
          Some(c)
        } else {
          None
        }
      }).repeat(),
    )
    .omit_first()
    .optional()
    .map(fn(opt) -> StringView? {
      match opt {
        Some(chars) =>
          Some(chars.fold(init=""[:], fn(a, b) { a + b.to_string() }))
        None => None
      }
    })

  // authority（遇到 / 或 ? 或 # 停止）
  let authority_parser = @parserc.pstring("//")
    .and_then(
      @parserc.pvalue(fn(c : Char) {
        // 🔑 修改：遇到 / 或 ? 或 # 停止
        if c != '/' && c != '?' && c != '#' && c != ' ' {
          Some(c)
        } else {
          None
        }
      }).repeat(),
    )
    .omit_first()
    .optional()
    .map(fn(opt) -> StringView? {
      match opt {
        Some(chars) =>
          Some(chars.fold(init=""[:], fn(a, b) { a + b.to_string() }))
        None => None
      }
    })

  // path（遇到 ? 或 # 停止）
  let path_parser = @parserc.pvalue(fn(c : Char) {
      // 🔑 修改：遇到 ? 或 # 停止
      if c != '?' && c != '#' && c != ' ' && c != '\n' {
        Some(c)
      } else {
        None
      }
    })
    .repeat()
    .map(fn(chars) -> StringView {
      chars.fold(init=""[:], fn(a, b) { a + b.to_string() })
    })

  // 完整解析器
  @parserc.Parser::new(fn(input : @parserc.Seq[Char]) -> ResParser[IriR] {

    // 🔑 修复顺序：先尝试 query，再尝试 fragment，再尝试 authority

    // 尝试 query
    let query_result = query_parser.run(input)
    let (query, rest_q) = match query_result {
      Some((q, rest)) => (q, rest)
      _ => (None, input)
    }

    // 尝试 fragment
    let fragment_result = fragment_parser.run(rest_q)
    let (fragment, rest_qf) = match fragment_result {
      Some((f, rest)) => (f, rest)
      _ => (None, rest_q)
    }

    // 如果有 query 或 fragment，直接返回（authority 一定为 None）
    if query is Some(_) || fragment is Some(_) {
      return Some(
        (
          Ok(IriR::{ scheme, authority: None, path: "", query, fragment }),
          rest_qf,
        ),
      )
    }

    // 没有 query/fragment，尝试 authority

    let auth_result = authority_parser.run(rest_qf)
    let (auth, rest_after_auth) = match auth_result {
      Some((a, rest)) => (a, rest)
      _ => (None, rest_qf)
    }

    // 解析 path
    let path_result = path_parser.run(rest_after_auth)
    let (path, rest_after_path) = match path_result {
      Some((p, rest)) => (p, rest)
      _ => ("", rest_after_auth)
    }

    // 解析 path 后的 query 和 fragment
    let query_result2 = query_parser.run(rest_after_path)
    let (query2, rest_q2) = match query_result2 {
      Some((q, rest)) => (q, rest)
      _ => (None, rest_after_path)
    }

    let fragment_result2 = fragment_parser.run(rest_q2)
    let (fragment2, rest_f2) = match fragment_result2 {
      Some((f, rest)) => (f, rest)
      _ => (None, rest_q2)
    }

    // 返回结果
    Some(
      (
        Ok(IriR::{
          scheme,
          authority: auth,
          path,
          query: query2,
          fragment: fragment2,
        }),
        rest_f2,
      ),
    )
  })
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
