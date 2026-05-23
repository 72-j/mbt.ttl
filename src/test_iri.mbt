// tests/iri_test.mbt

// --- Helper Assertions ---
// Assuming assert_eq, assert_true, assert_false, fail are available in the test framework

// --- Group: Parsing Tests ---

test "parse: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri=Iri::default(iri)
  assert_eq(iri.as_str(), "https://example.com/path?query#fragment")
  let result = IriRef::parse(iri)
  match result {
    Ok(parsed) => {

      assert_eq(parsed.as_str(), iri.as_str())
      assert_true(parsed.is_absolute())
      assert_eq(parsed.scheme(), Some("https"))
      assert_eq(parsed.authority(), Some("example.com"))
      assert_eq(parsed.path(), "/path")
      assert_eq(parsed.query(), Some("query"))
      assert_eq(parsed.fragment(), Some("fragment"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

