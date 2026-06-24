///|
test "parse_unchecked: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri = Iri::new(iri)
  // let iri = IriRef::of_ref(iri)
  assert_eq(iri.into_string(), "https://example.com/path?query#fragment")
  let parsed = IriRef::parse_unchecked(iri)
  // match result {
  //   Ok(parsed) => {
  assert_eq(parsed.as_stringview(), iri.into_string())
  assert_true(parsed.is_absolute())
  assert_eq(parsed.scheme().unwrap(), "https")
  assert_eq(parsed.authority().unwrap(), "example.com")
  assert_eq(parsed.path().unwrap(), "/path")
  assert_eq(parsed.query().unwrap(), "query")
  assert_eq(parsed.fragment().unwrap(), "fragment")
  //   }
  //   Err(e) => fail("Expected Ok, got Err: \{e}")
  // }
}

///|
test "parse absolute IRI" {
  let iri = "<scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~?#>"
  let iri = Iri::new(iri)
  // let iri = IriRef::of_ref(iri)
  assert_eq(
    iri.into_string(),
    "<scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~?#>",
  )
  let result = IriRef::parse(iri)
  match result {
    Ok(parsed) => assert_eq(parsed.as_stringview(), iri.into_string())

    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri = Iri::new(iri)

  assert_eq(iri.into_string(), "https://example.com/path?query#fragment")
  let result = IriRef::parse(iri)
  match result {
    Ok(parsed) => {
      assert_eq(parsed.into_string(), iri.into_string())
      assert_true(parsed.is_absolute())
      assert_eq(parsed.scheme().unwrap(), "https")
      assert_eq(parsed.authority().unwrap(), "example.com")
      assert_eq(parsed.path().unwrap(), "/path")
      assert_eq(parsed.query().unwrap(), "query")
      assert_eq(parsed.fragment().unwrap(), "fragment")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative IRI (absolute path)" {
  let iri = "/path/to/resource"
  let iri = Iri::new(iri)

  let result = IriRef::parse(iri)

  match result {
    Ok(parsed) => {
      assert_eq(parsed.into_string(), iri.into_string())
      assert_false(parsed.is_absolute()) // No scheme
      assert_eq(parsed.scheme(), None)
      assert_eq(parsed.authority(), None)
      assert_eq(parsed.path().unwrap(), "/path/to/resource")
      assert_eq(parsed.query(), None)
      assert_eq(parsed.fragment(), None)
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative path (relative-path reference)" {
  let iri = "path/to/resource"
  let iri = Iri::new(iri)

  let result = IriRef::parse(iri)

  match result {
    Ok(parsed) => {
      assert_eq(parsed.path().unwrap(), "path/to/resource")
      assert_false(parsed.is_absolute())
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: query only" {
  let iri = "https://example.com?query=value"
  let iri = Iri::new(iri)

  let result = IriRef::parse(iri)

  match result {
    Ok(parsed) => {
      assert_eq(parsed.path().unwrap(), "")
      assert_eq(parsed.query().unwrap(), "query=value")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: fragment only" {
  let iri = "https://example.com#fragment"
  let iri = Iri::new(iri)

  let result = IriRef::parse(iri)

  match result {
    Ok(parsed) => assert_eq(parsed.fragment().unwrap(), "fragment")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: error on invalid scheme format" {

  let iri = Iri::Iri("invalid:iri").as_ref()

  let result = IriRef::parse(iri)

  match result {
    Ok(parsed) => assert_eq(parsed.scheme().unwrap(), "invalid")
    Err(IriError::NoScheme) => fail("Unexpected NoScheme for 'invalid:iri' ")
    Err(e) => fail("Expected Ok or specific error, got \{e}")
  }
}

///|
test "parse_unchecked: basic functionality" {
  let iri = "https://example.com/path"
  let iri = Iri::new(iri)

  let parsed = IriRef::parse_unchecked(iri)
  // match parsed {
  //   Ok(parsed) => {
  assert_eq(parsed.into_string(), iri.into_string())
  assert_true(parsed.is_absolute())
  assert_eq(parsed.scheme().unwrap(), "https")
  //   }
  //   Err(e) => fail("Expected Ok, got Err: \{e}")
  // }
}

///|
test "parse_unchecked: empty string" {
  let iri = Iri::Iri("").as_ref()

  let parsed = IriRef::parse_unchecked(iri)
  // match parsed {
  //   Ok(parsed) => {
  assert_eq(parsed.into_string(), "")
  assert_false(parsed.is_absolute()) // Empty string has no scheme
  assert_eq(parsed.scheme(), None)
  assert_eq(parsed.authority(), None)
  assert_eq(parsed.path().unwrap(), "")
  //   }
  //   Err(e) => fail("Expected Ok, got Err: \{e}")
  // }
}

///|
test "parse_unchecked: Unicode IRI" {
  let iri = "https://例子.测试/路径"
  let iri = Iri::new(iri)

  let parsed = IriRef::parse_unchecked(iri)
  // match parsed {
  //   Ok(parsed) => {
  assert_eq(parsed.into_string(), "https://例子.测试/路径")
  assert_eq(parsed.scheme().unwrap(), "https")
  assert_eq(parsed.authority().unwrap(), "例子.测试")
  assert_eq(parsed.path().unwrap(), "/路径")
  //   }
  //   Err(e) => fail("Expected Ok, got Err: \{e}")
  // }
}

///|
test "parse_unchecked: percent encoding preserved" {
  let iri = "https://example.com/path%20with%20spaces"
  let iri = Iri::new(iri)

  let parsed = IriRef::parse_unchecked(iri)
  assert_eq(parsed.path().unwrap(), "/path%20with%20spaces")
  // match parsed {
  //   Ok(parsed) => assert_eq(parsed.path(), Some("/path%20with%20spaces"))
  //   Err(e) => fail("Expected Ok, got Err: \{e}")
  // }
}

// --- Group: Resolution Tests ---

///|
test "resolve: relative to absolute base" {
  let iri = "https://example.com/base/path"
  let iri = Iri::new(iri)
  let relative = "relative/path"

  // 先解析 base，处理可能的解析错误
  // match IriRef::parse_unchecked(iri) {
  // Ok(base) => {
  // let base = IriRef::of_ref(base)

  // 再调用 resolve，处理可能的解析/合并错误
  match iri.resolve(relative) {
    Ok(resolved) =>
      assert_eq(
        resolved.into_string(),
        "https://example.com/base/relative/path",
      )
    Err(e) => fail("Expected Ok from resolve, got Err: \{e}")
  }
  //   }
  //   Err(e) => fail("Expected Ok from parse, got Err: \{e}")
  // }
}

///|
test "resolve: absolute reference overrides base" {
  let iri = "https://example.com/base/"
  let iri = Iri::new(iri)

  // let base = IriRef::parse_unchecked(iri)
  let absolute = "http://other.com/path"

  match iri.resolve(absolute) {
    Ok(resolved) => {
      assert_eq(resolved.into_string(), "http://other.com/path")
      assert_eq(resolved.scheme().unwrap(), "http")
      assert_eq(resolved.authority().unwrap(), "other.com")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: path starting with slash" {
  let iri = "https://example.com/base/path"
  let iri = Iri::new(iri)
  let base = IriRef::parse_unchecked(iri)
  // match IriRef::parse_unchecked(iri) {
  //   Ok(base) => {
  let relative = "/new/path"
  // let base = IriRef::of_ref(base)
  match base.as_ref().resolve(relative) {
    Ok(resolved) =>
      assert_eq(resolved.into_string(), "https://example.com/new/path")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
  //   }
  //   Err(e) => fail("Expected Ok from parse, got Err: \{e}")
  // }
}

///|
test "resolve: query and fragment replacement" {
  let iri = "https://example.com/path"
  let iri = Iri::new(iri)

  let base = IriRef::parse_unchecked(iri)
  let relative = "?query=value#fragment"
  match base.as_ref().resolve(relative) {
    Ok(resolved) => {
      assert_eq(
        resolved.into_string(),
        "https://example.com/path?query=value#fragment",
      )
      assert_eq(resolved.query().unwrap(), "query=value")
      assert_eq(resolved.fragment().unwrap(), "fragment")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: dot segments (preserved as per simple impl)" {
  let iri = "https://example.com/a/b/c/"
  let iri = Iri::new(iri)

  let base = IriRef::parse_unchecked(iri)
  let relative = "../d/e"
  match base.as_ref().resolve(relative, remove_dot_segments=false) {
    Ok(resolved) =>
      // Our simple resolve merges paths but doesn't normalize dots automatically
      assert_eq(resolved.into_string(), "https://example.com/a/b/c/../d/e")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: sequence of resolutions" {
  let iri = "https://example.com/a/b/c/"
  let iri = Iri::new(iri)

  let base1 = IriRef::parse_unchecked(iri)
  match base1.as_ref().resolve("d") {
    Ok(r1) => {
      assert_eq(r1.into_string(), "https://example.com/a/b/c/d")
      // r1 is likely an Iri or IriRef, assuming it has resolve method
      match r1.as_ref().resolve("e") {
        Ok(r2) => assert_eq(r2.into_string(), "https://example.com/a/b/c/e")
        Err(e) => fail("Failed second resolve: \{e}")
      }
    }
    Err(e) => fail("Failed first resolve: \{e}")
  }
}

///|
test "resolve_into: write to buffer" {
  let iri = "https://example.com/"
  let iri = Iri::new(iri)

  let base = IriRef::parse_unchecked(iri)
  let buffer = StringBuilder::new(size_hint=100)
  match base.as_ref().resolve_into("path/to/resource", buffer) {
    Ok(_) =>
      assert_eq(buffer.to_string(), "https://example.com/path/to/resource")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

// --- Group: Relativization Tests ---

///|
test "relativize: simple child path" {
  let base_iri = "https://example.com/a/b/c/"
  let base_iri = Iri::Iri(base_iri).as_ref()

  let abs_iri = "https://example.com/a/b/c/d/e"
  let abs_iri = Iri::new(abs_iri)

  let base_parsed = IriRef::parse_unchecked(base_iri)
  let abs_parsed = IriRef::parse_unchecked(abs_iri)

  match IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) => assert_eq(relative.into_string(), "d/e")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "relativize: different scheme returns absolute" {
  let base_iri = "https://example.com/path"
  let base_iri = Iri::Iri(base_iri).as_ref()

  let abs_iri = "http://example.com/path"
  let abs_iri = Iri::new(abs_iri)

  let base_parsed = IriRef::parse_unchecked(base_iri)
  let abs_parsed = IriRef::parse_unchecked(abs_iri)

  match IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) => assert_eq(relative.into_string(), "http://example.com/path")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "relativize: different authority returns absolute" {
  let base_iri = "https://example.com/path"
  let base_iri = Iri::Iri(base_iri).as_ref()

  let abs_iri = "https://different.com/path"
  let abs_iri = Iri::new(abs_iri)

  let base_parsed = IriRef::parse_unchecked(base_iri)
  let abs_parsed = IriRef::parse_unchecked(abs_iri)

  match IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) =>
      assert_eq(relative.into_string(), "https://different.com/path")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "relativize: parent directory navigation" {
  let base_iri = "https://example.com/a/b/c/d"
  let base_iri = Iri::Iri(base_iri).as_ref()

  let abs_iri = "https://example.com/a/b/e/f"
  let abs_iri = Iri::new(abs_iri)

  let base_parsed = IriRef::parse_unchecked(base_iri)
  let abs_parsed = IriRef::parse_unchecked(abs_iri)

  match IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) =>
      // Our simple relativize returns absolute if prefix doesn't match
      assert_eq(relative.into_string(), "https://example.com/a/b/e/f")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

