///|
test "iri parse" {
  let result = @lib.IriR::default()

  let result = result.parse("http://example.org")
  match result {
    Ok(r) => @debug.assert_eq(r.scheme, "http")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "iri parse full" {
  let result = @lib.IriR::default().parse("http://user@host:8080/path?q=f#frag")

  match result {
    Ok(r) => {
      @debug.assert_eq(r.scheme, "http")
      @debug.assert_eq(r.authority, Some("user@host:8080"))
      @debug.assert_eq(r.path, "/path")
      @debug.assert_eq(r.query, Some("q=f"))
      @debug.assert_eq(r.fragment, Some("frag"))
    }
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "parse_unchecked: basic absolute IRI" {
  let iri = @lib.IriR::default()
  let parsed = iri.parse_unchecked("https://example.com/path?query#fragment")

  @debug.assert_eq(
    parsed.into_string(),
    "https://example.com/path?query#fragment",
  )
  @debug.assert_eq(parsed.scheme.to_owned(), "https")
  @debug.assert_eq(parsed.authority, Some("example.com"))
  @debug.assert_eq(parsed.path.to_owned(), "/path")
  @debug.assert_eq(parsed.query, Some("query"))
  @debug.assert_eq(parsed.fragment, Some("fragment"))
}

///|
test "parse absolute IRI with slashes" {
  // 带 authority 的完整 IRI
  let result = @lib.IriR::default().parse(
    "https://example.com/path/to/resource",
  )

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.scheme.to_owned(), "https")
      @debug.assert_eq(parsed.authority, Some("example.com"))
      @debug.assert_eq(parsed.path.to_owned(), "/path/to/resource")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse absolute IRI" {
  // scheme 后面不带 authority，直接是 path
  let result = @lib.IriR::default().parse(
    "scheme:path-with-dashes_and_underscores",
  )

  match result {
    Ok(parsed) =>
      @debug.assert_eq(
        parsed.into_string(),
        "scheme:path-with-dashes_and_underscores",
      )
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse absolute IRI with dots" {
  let result = @lib.IriR::default().parse("scheme:abc/def.ghi-jkl_mno")

  match result {
    Ok(parsed) =>
      @debug.assert_eq(parsed.into_string(), "scheme:abc/def.ghi-jkl_mno")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse absolute IRI with special characters" {
  let result = @lib.IriR::default().parse(
    "scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz?#",
  )

  match result {
    Ok(parsed) =>
      @debug.assert_eq(
        parsed.into_string(),
        "scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz?#",
      )
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: basic absolute IRI" {
  let result = @lib.IriR::default().parse(
    "https://example.com/path?query#fragment",
  )

  match result {
    Ok(parsed) => {
      @debug.assert_eq(
        parsed.into_string(),
        "https://example.com/path?query#fragment",
      )
      @debug.assert_eq(parsed.scheme.to_owned(), "https")
      @debug.assert_eq(parsed.authority, Some("example.com"))
      @debug.assert_eq(parsed.path.to_owned(), "/path")
      @debug.assert_eq(parsed.query, Some("query"))
      @debug.assert_eq(parsed.fragment, Some("fragment"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative IRI (absolute path)" {
  let result = @lib.IriR::default().parse("/path/to/resource")

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.into_string(), "/path/to/resource")
      @debug.assert_eq(parsed.scheme.to_owned(), "")
      @debug.assert_eq(parsed.authority, None)
      @debug.assert_eq(parsed.path.to_owned(), "/path/to/resource")
      @debug.assert_eq(parsed.query, None)
      @debug.assert_eq(parsed.fragment, None)
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative path" {
  let result = @lib.IriR::default().parse("path/to/resource")

  match result {
    Ok(parsed) => @debug.assert_eq(parsed.path.to_owned(), "path/to/resource")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: query only" {
  let result = @lib.IriR::default().parse("https://example.com?query=value")

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.path.to_owned(), "")
      @debug.assert_eq(parsed.query, Some("query=value"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: fragment only" {
  let result = @lib.IriR::default().parse("https://example.com#fragment")

  match result {
    Ok(parsed) => @debug.assert_eq(parsed.fragment, Some("fragment"))
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse_unchecked: basic functionality" {
  let parsed = @lib.IriR::default().parse_unchecked("https://example.com/path")

  @debug.assert_eq(parsed.into_string(), "https://example.com/path")
  @debug.assert_eq(parsed.scheme.to_owned(), "https")
}

///|
test "parse_unchecked: empty string" {
  let parsed = @lib.IriR::default().parse_unchecked("")

  @debug.assert_eq(parsed.into_string(), "")
  @debug.assert_eq(parsed.scheme.to_owned(), "")
  @debug.assert_eq(parsed.authority, None)
  @debug.assert_eq(parsed.path.to_owned(), "")
}

///|
test "resolve: relative to absolute base" {
  let base = @lib.IriR::default()
  let result = base.resolve("relative/path")

  match result {
    Ok(resolved) => @debug.assert_eq(resolved.into_string(), "relative/path")
    Err(e) => fail("Expected Ok from resolve, got Err: \{e}")
  }
}

///|
test "resolve: absolute reference overrides base" {
  let base = @lib.IriR::{
    scheme: "https",
    authority: Some("example.com"),
    path: "/base/",
    query: None,
    fragment: None,
  }
  let result = base.resolve("http://other.com/path")

  match result {
    Ok(resolved) => {
      @debug.assert_eq(resolved.into_string(), "http://other.com/path")
      @debug.assert_eq(resolved.scheme.to_owned(), "http")
      @debug.assert_eq(resolved.authority, Some("other.com"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: query and fragment replacement" {
  let base = @lib.IriR::{
    scheme: "https",
    authority: Some("example.com"),
    path: "/path",
    query: None,
    fragment: None,
  }
  let result = base.resolve("?query=value#fragment")

  match result {
    Ok(resolved) => {
      @debug.assert_eq(
        resolved.into_string(),
        "https://example.com/path?query=value#fragment",
      )
      @debug.assert_eq(resolved.query, Some("query=value"))
      @debug.assert_eq(resolved.fragment, Some("fragment"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve_unchecked: basic functionality" {
  let base = @lib.IriR::{
    scheme: "https",
    authority: Some("example.com"),
    path: "/base",
    query: None,
    fragment: None,
  }
  let resolved = base.resolve_unchecked("relative/path")

  @debug.assert_eq(
    resolved.into_string(),
    "https://example.com/base/relative/path",
  )
}

///|
test "remove_dot_segments: basic" {
  @debug.assert_eq(@lib.fn_remove_dot_segments("/a/b/c/./g"), "/a/b/c/g")
  @debug.assert_eq(@lib.fn_remove_dot_segments("/a/b/c/../g"), "/a/b/g")
  @debug.assert_eq(@lib.fn_remove_dot_segments("/a/b/c/../../g"), "/a/g")
}

///|
test "remove_dot_segments: multiple dots" {
  @debug.assert_eq(@lib.fn_remove_dot_segments("/a/./b/./c"), "/a/b/c")
  @debug.assert_eq(@lib.fn_remove_dot_segments("/a/b/../c/../d"), "/a/d")
  @debug.assert_eq(@lib.fn_remove_dot_segments("/../a"), "/a")
}

///|
test "remove_dot_segments: relative" {
  @debug.assert_eq(@lib.fn_remove_dot_segments("a/b/c/./g"), "a/b/c/g")
  @debug.assert_eq(@lib.fn_remove_dot_segments("a/b/c/../g"), "a/b/g")

  // 单独使用 .. 没有上级可返回，丢弃
  @debug.assert_eq(@lib.fn_remove_dot_segments(".."), "")

  // a/.. 有上级可返回，移除 a
  @debug.assert_eq(@lib.fn_remove_dot_segments("a/.."), "")

  // 多个 .. 依次移除
  @debug.assert_eq(@lib.fn_remove_dot_segments("a/b/.."), "a")
  @debug.assert_eq(@lib.fn_remove_dot_segments("a/b/c/.."), "a/b")

  // ../a - 第一个 .. 没有上级，丢弃；a 保留
  @debug.assert_eq(@lib.fn_remove_dot_segments("../a"), "a")

  // ../a/b - 第一个 .. 没有上级，丢弃
  @debug.assert_eq(@lib.fn_remove_dot_segments("../a/b"), "a/b")
}

///|
test "remove_dot_segments: edge cases" {
  @debug.assert_eq(@lib.fn_remove_dot_segments("/."), "/")
  @debug.assert_eq(@lib.fn_remove_dot_segments("/.."), "/")
  @debug.assert_eq(@lib.fn_remove_dot_segments("."), "")
  @debug.assert_eq(@lib.fn_remove_dot_segments(".."), "")
  @debug.assert_eq(@lib.fn_remove_dot_segments(""), "")
  @debug.assert_eq(@lib.fn_remove_dot_segments("/"), "/")
  @debug.assert_eq(@lib.fn_remove_dot_segments("///"), "/")
}

///|
test "remove_dot_segments: ends with slash" {
  @debug.assert_eq(@lib.fn_remove_dot_segments("/a/b/"), "/a/b")
  @debug.assert_eq(@lib.fn_remove_dot_segments("/a/b/c/./"), "/a/b/c")
  @debug.assert_eq(@lib.fn_remove_dot_segments("a/b/"), "a/b")
}
