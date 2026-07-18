///|
test "parse_unchecked: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri = @lib.Iri::new(iri)

  @debug.assert_eq(iri.into_string(), "https://example.com/path?query#fragment")
  let parsed = @lib.IriRef::parse_unchecked(iri)

  @debug.assert_eq(parsed.as_stringview(), iri.into_string())
  assert_true(parsed.is_absolute())
  @debug.assert_eq(parsed.scheme().unwrap(), "https")
  @debug.assert_eq(parsed.authority().unwrap(), "example.com")
  @debug.assert_eq(parsed.path().unwrap(), "/path")
  @debug.assert_eq(parsed.query().unwrap(), "query")
  @debug.assert_eq(parsed.fragment().unwrap(), "fragment")
}

///|
test "parse absolute IRI" {
  let iri = "scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~?#"
  let iri = @lib.Iri::new(iri)

  @debug.assert_eq(
    iri.into_string(),
    "scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~?#",
  )
  let result = @lib.IriRef::parse(iri)
  match result {
    Ok(parsed) => @debug.assert_eq(parsed.as_stringview(), iri.into_string())
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri = @lib.Iri::new(iri)

  @debug.assert_eq(iri.into_string(), "https://example.com/path?query#fragment")
  let result = @lib.IriRef::parse(iri)
  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.into_string(), iri.into_string())
      assert_true(parsed.is_absolute())
      @debug.assert_eq(parsed.scheme().unwrap(), "https")
      @debug.assert_eq(parsed.authority().unwrap(), "example.com")
      @debug.assert_eq(parsed.path().unwrap(), "/path")
      @debug.assert_eq(parsed.query().unwrap(), "query")
      @debug.assert_eq(parsed.fragment().unwrap(), "fragment")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative IRI (absolute path)" {
  let iri = "/path/to/resource"
  let iri = @lib.Iri::new(iri)

  let result = @lib.IriRef::parse(iri)

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.into_string(), iri.into_string())
      assert_false(parsed.is_absolute())
      @debug.assert_eq(parsed.scheme(), None)
      @debug.assert_eq(parsed.authority(), None)
      @debug.assert_eq(parsed.path().unwrap(), "/path/to/resource")
      @debug.assert_eq(parsed.query(), None)
      @debug.assert_eq(parsed.fragment(), None)
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative path (relative-path reference)" {
  let iri = "path/to/resource"
  let iri = @lib.Iri::new(iri)

  let result = @lib.IriRef::parse(iri)

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.path().unwrap(), "path/to/resource")
      assert_false(parsed.is_absolute())
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: query only" {
  let iri = "https://example.com?query=value"
  let iri = @lib.Iri::new(iri)

  let result = @lib.IriRef::parse(iri)

  match result {
    Ok(parsed) => {
      @debug.assert_eq(parsed.path().unwrap(), "")
      @debug.assert_eq(parsed.query().unwrap(), "query=value")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: fragment only" {
  let iri = "https://example.com#fragment"
  let iri = @lib.Iri::new(iri)

  let result = @lib.IriRef::parse(iri)

  match result {
    Ok(parsed) => @debug.assert_eq(parsed.fragment().unwrap(), "fragment")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: error on invalid scheme format" {
  let iri = @lib.Iri::Iri("invalid:iri").as_ref()

  let result = @lib.IriRef::parse(iri)

  match result {
    Ok(parsed) => @debug.assert_eq(parsed.scheme().unwrap(), "invalid")
    Err(@lib.IriError::NoScheme) =>
      fail("Unexpected NoScheme for 'invalid:iri' ")
    Err(e) => fail("Expected Ok or specific error, got \{e}")
  }
}

///|
test "parse_unchecked: basic functionality" {
  let iri = "https://example.com/path"
  let iri = @lib.Iri::new(iri)

  let parsed = @lib.IriRef::parse_unchecked(iri)

  @debug.assert_eq(parsed.into_string(), iri.into_string())
  assert_true(parsed.is_absolute())
  @debug.assert_eq(parsed.scheme().unwrap(), "https")
}

///|
test "parse_unchecked: empty string" {
  let iri = @lib.Iri::Iri("").as_ref()

  let parsed = @lib.IriRef::parse_unchecked(iri)

  @debug.assert_eq(parsed.into_string(), "")
  assert_false(parsed.is_absolute())
  @debug.assert_eq(parsed.scheme(), None)
  @debug.assert_eq(parsed.authority(), None)
  @debug.assert_eq(parsed.path().unwrap(), "")
}

///|
test "parse_unchecked: Unicode IRI" {
  let iri = "https://例子.测试/路径"
  let iri = @lib.Iri::new(iri)

  let parsed = @lib.IriRef::parse_unchecked(iri)

  @debug.assert_eq(parsed.into_string(), "https://例子.测试/路径")
  @debug.assert_eq(parsed.scheme().unwrap(), "https")
  @debug.assert_eq(parsed.authority().unwrap(), "例子.测试")
  @debug.assert_eq(parsed.path().unwrap(), "/路径")
}

///|
test "parse_unchecked: percent encoding preserved" {
  let iri = "https://example.com/path%20with%20spaces"
  let iri = @lib.Iri::new(iri)

  let parsed = @lib.IriRef::parse_unchecked(iri)
  @debug.assert_eq(parsed.path().unwrap(), "/path%20with%20spaces")
}

///|
test "resolve: relative to absolute base" {
  let iri = "https://example.com/base/path"
  let iri = @lib.Iri::new(iri)
  let relative = "relative/path"

  match iri.resolve(relative) {
    Ok(resolved) =>
      @debug.assert_eq(
        resolved.into_string(),
        "https://example.com/base/relative/path",
      )
    Err(e) => fail("Expected Ok from resolve, got Err: \{e}")
  }
}

///|
test "resolve: absolute reference overrides base" {
  let iri = "https://example.com/base/"
  let iri = @lib.Iri::new(iri)

  let absolute = "http://other.com/path"

  match iri.resolve(absolute) {
    Ok(resolved) => {
      @debug.assert_eq(resolved.into_string(), "http://other.com/path")
      @debug.assert_eq(resolved.scheme().unwrap(), "http")
      @debug.assert_eq(resolved.authority().unwrap(), "other.com")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: path starting with slash" {
  let iri = "https://example.com/base/path"
  let iri = @lib.Iri::new(iri)
  let base = @lib.IriRef::parse_unchecked(iri)

  let relative = "/new/path"

  match base.as_ref().resolve(relative) {
    Ok(resolved) =>
      @debug.assert_eq(resolved.into_string(), "https://example.com/new/path")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: query and fragment replacement" {
  let iri = "https://example.com/path"
  let iri = @lib.Iri::new(iri)

  let base = @lib.IriRef::parse_unchecked(iri)
  let relative = "?query=value#fragment"
  match base.as_ref().resolve(relative) {
    Ok(resolved) => {
      @debug.assert_eq(
        resolved.into_string(),
        "https://example.com/path?query=value#fragment",
      )
      @debug.assert_eq(resolved.query().unwrap(), "query=value")
      @debug.assert_eq(resolved.fragment().unwrap(), "fragment")
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: dot segments (preserved as per simple impl)" {
  let iri = "https://example.com/a/b/c/"
  let iri = @lib.Iri::new(iri)

  let base = @lib.IriRef::parse_unchecked(iri)
  let relative = "../d/e"
  match base.as_ref().resolve(relative, remove_dot_segments=false) {
    Ok(resolved) =>
      @debug.assert_eq(
        resolved.into_string(),
        "https://example.com/a/b/c/../d/e",
      )
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: sequence of resolutions" {
  let iri = "https://example.com/a/b/c/"
  let iri = @lib.Iri::new(iri)

  let base1 = @lib.IriRef::parse_unchecked(iri)
  match base1.as_ref().resolve("d") {
    Ok(r1) => {
      @debug.assert_eq(r1.into_string(), "https://example.com/a/b/c/d")

      match r1.as_ref().resolve("e") {
        Ok(r2) =>
          @debug.assert_eq(r2.into_string(), "https://example.com/a/b/c/e")
        Err(e) => fail("Failed second resolve: \{e}")
      }
    }
    Err(e) => fail("Failed first resolve: \{e}")
  }
}

///|
test "resolve_into: write to buffer" {
  let iri = "https://example.com/"
  let iri = @lib.Iri::new(iri)

  let base = @lib.IriRef::parse_unchecked(iri)
  let buffer = StringBuilder::new(size_hint=100)
  match base.as_ref().resolve_into("path/to/resource", buffer) {
    Ok(_) =>
      @debug.assert_eq(
        buffer.to_string(),
        "https://example.com/path/to/resource",
      )
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "relativize: simple child path" {
  let base_iri = "https://example.com/a/b/c/"
  let base_iri = @lib.Iri::Iri(base_iri).as_ref()

  let abs_iri = "https://example.com/a/b/c/d/e"
  let abs_iri = @lib.Iri::new(abs_iri)

  let base_parsed = @lib.IriRef::parse_unchecked(base_iri)
  let abs_parsed = @lib.IriRef::parse_unchecked(abs_iri)

  match @lib.IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) => @debug.assert_eq(relative.into_string(), "d/e")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "relativize: different scheme returns absolute" {
  let base_iri = "https://example.com/path"
  let base_iri = @lib.Iri::Iri(base_iri).as_ref()

  let abs_iri = "http://example.com/path"
  let abs_iri = @lib.Iri::new(abs_iri)

  let base_parsed = @lib.IriRef::parse_unchecked(base_iri)
  let abs_parsed = @lib.IriRef::parse_unchecked(abs_iri)

  match @lib.IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) =>
      @debug.assert_eq(relative.into_string(), "http://example.com/path")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "relativize: different authority returns absolute" {
  let base_iri = "https://example.com/path"
  let base_iri = @lib.Iri::Iri(base_iri).as_ref()

  let abs_iri = "https://different.com/path"
  let abs_iri = @lib.Iri::new(abs_iri)

  let base_parsed = @lib.IriRef::parse_unchecked(base_iri)
  let abs_parsed = @lib.IriRef::parse_unchecked(abs_iri)

  match @lib.IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) =>
      @debug.assert_eq(relative.into_string(), "https://different.com/path")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "relativize: parent directory navigation" {
  let base_iri = "https://example.com/a/b/c/d"
  let base_iri = @lib.Iri::Iri(base_iri).as_ref()

  let abs_iri = "https://example.com/a/b/e/f"
  let abs_iri = @lib.Iri::new(abs_iri)

  let base_parsed = @lib.IriRef::parse_unchecked(base_iri)
  let abs_parsed = @lib.IriRef::parse_unchecked(abs_iri)

  match @lib.IriRef::relativize(base_parsed.as_ref(), abs_parsed.as_ref()) {
    Ok(relative) =>
      @debug.assert_eq(relative.into_string(), "https://example.com/a/b/e/f")
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}
