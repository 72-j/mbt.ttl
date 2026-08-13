///|
test "iri parse" {
  let result = @lib.Iri::default()
  let data = "http://example.org"
  let data = @utf8.encode(data)[:]

  let result = result.parse(data)
  match result {
    Ok(r) => @debug.assert_eq(r.scheme, "http")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "iri parse full" {
  let data = "http://user@host:8080/path?q=f#frag"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(r) => {
      @debug.assert_eq(r.scheme, "http")
      @debug.assert_eq(r.authority, "user@host:8080")
      @debug.assert_eq(r.path, "/path")
      @debug.assert_eq(r.query, "q=f")
      @debug.assert_eq(r.fragment, "frag")
    }
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "parse_unchecked: basic absolute IRI" {
  let iri = @lib.Iri::default()
  let data = "https://example.com/path?query#fragment"
  let bytes = @utf8.encode(data)[:]
  let parsed = iri.parse_unchecked(bytes[0:bytes.length()])

  @debug.assert_eq(
    parsed.into_string(),
    "https://example.com/path?query#fragment",
  )
  @debug.assert_eq(parsed.scheme.to_owned(), "https")
  @debug.assert_eq(parsed.authority.to_owned(), "example.com")
  @debug.assert_eq(parsed.path.to_owned(), "/path")
  @debug.assert_eq(parsed.query.to_owned(), "query")
  @debug.assert_eq(parsed.fragment.to_owned(), "fragment")
}

///|
///|
test "parse absolute IRI with slashes" {
  let data = "https://example.com/path/to/resource"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.scheme.to_owned(), "https")
      @debug.assert_eq(parsed.authority.to_owned(), "example.com")
      @debug.assert_eq(parsed.path.to_owned(), "/path/to/resource")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse absolute IRI" {
  let data = "scheme:path-with-dashes_and_underscores"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

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
  let data = "scheme:abc/def.ghi-jkl_mno"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(parsed) =>
      @debug.assert_eq(parsed.into_string(), "scheme:abc/def.ghi-jkl_mno")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}


///|
test "parse: basic absolute IRI" {
  let data = "https://example.com/path?query#fragment"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(parsed) => {
      @debug.assert_eq(
        parsed.into_string(),
        "https://example.com/path?query#fragment",
      )
      @debug.assert_eq(parsed.scheme.to_owned(), "https")
      @debug.assert_eq(parsed.authority.to_owned(), "example.com")
      @debug.assert_eq(parsed.path.to_owned(), "/path")
      @debug.assert_eq(parsed.query.to_owned(), "query")
      @debug.assert_eq(parsed.fragment.to_owned(), "fragment")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative IRI (absolute path)" {
  let data = "/path/to/resource"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.into_string(), "/path/to/resource")
      @debug.assert_eq(parsed.scheme, "")
      @debug.assert_eq(parsed.authority.to_owned(), "")
      @debug.assert_eq(parsed.path.to_owned(), "/path/to/resource")
      @debug.assert_eq(parsed.query.to_owned(), "")
      @debug.assert_eq(parsed.fragment.to_owned(), "")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative path" {
  let data = "path/to/resource"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(parsed) => @debug.assert_eq(parsed.path.to_owned(), "path/to/resource")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: query only" {
  let data = "https://example.com?query=value"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.path.to_owned(), "")
      @debug.assert_eq(parsed.query.to_owned(), "query=value")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
///|
test "parse: fragment only" {
  let data = "https://example.com#fragment"
  let bytes = @utf8.encode(data)[:]
  let result = @lib.Iri::default().parse(bytes[0:bytes.length()])

  match result {
    Ok(parsed) => @debug.assert_eq(parsed.fragment.to_owned(), "fragment")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse_unchecked: basic functionality" {
  let data = "https://example.com/path"
  let bytes = @utf8.encode(data)[:]
  let parsed = @lib.Iri::default().parse_unchecked(bytes[0:bytes.length()])

  @debug.assert_eq(parsed.into_string(), "https://example.com/path")
  @debug.assert_eq(parsed.scheme.to_owned(), "https")
}

///|
test "parse_unchecked: empty string" {
  let data = ""
  let bytes = @utf8.encode(data)[:]
  let parsed = @lib.Iri::default().parse_unchecked(bytes[0:bytes.length()])

  @debug.assert_eq(parsed.into_string(), "")
  @debug.assert_eq(parsed.scheme.to_owned(), "")
  @debug.assert_eq(parsed.authority.to_owned(), "")
  @debug.assert_eq(parsed.path.to_owned(), "")
}

///|
test "resolve: relative to absolute base" {
  let base = @lib.Iri::default()
  let data = "relative/path"
  let bytes = @utf8.encode(data)[:]
  let result = base.resolve(bytes[0:bytes.length()])

  match result {
    Ok(resolved) => @debug.assert_eq(resolved.into_string(), "relative/path")
    Err(e) => fail("Expected Ok from resolve, got Err: \{e}")
  }
}

///|
test "resolve: absolute reference overrides base" {
  let base = @lib.Iri::{
    scheme: "https",
    authority: "example.com",
    path: "/base/",
    query: "",
    fragment: "",
  }
  let data = "http://other.com/path"
  let bytes = @utf8.encode(data)[:]
  let result = base.resolve(bytes[0:bytes.length()])

  match result {
    Ok(resolved) => {
      @debug.assert_eq(resolved.into_string(), "http://other.com/path")
      @debug.assert_eq(resolved.scheme.to_owned(), "http")
      @debug.assert_eq(resolved.authority.to_owned(), "other.com")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: query and fragment replacement" {
  let base = @lib.Iri::{
    scheme: "https",
    authority: "example.com",
    path: "/path",
    query: "",
    fragment: "",
  }
  let data = "?query=value#fragment"
  let bytes = @utf8.encode(data)[:]
  let result = base.resolve(bytes[0:bytes.length()])

  match result {
    Ok(resolved) => {
      @debug.assert_eq(
        resolved.into_string(),
        "https://example.com/path?query=value#fragment",
      )
      @debug.assert_eq(resolved.query.to_owned(), "query=value")
      @debug.assert_eq(resolved.fragment.to_owned(), "fragment")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve_unchecked: basic functionality" {
  let base = @lib.Iri::{
    scheme: "https",
    authority: "example.com",
    path: "/base",
    query: "",
    fragment: "",
  }
  let data = "relative/path"
  let bytes = @utf8.encode(data)[:]
  let resolved = base.resolve_unchecked(bytes[0:bytes.length()])

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


