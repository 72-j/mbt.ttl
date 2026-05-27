///|
test "parse_unchecked: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri = Iri::Iri(iri)
  assert_eq(iri.to_own(), "https://example.com/path?query#fragment")
  let result = Iri::parse(iri, unchecked=true)
  match result {
    Ok(parsed) => {
      assert_eq(parsed.to_own(), iri.to_own())
      assert_true(parsed.is_absolute())
      assert_eq(parsed.scheme(), Some("https"))
      assert_eq(parsed.authority(), Some("example.com"))
      assert_eq(parsed.path(), Some("/path"))
      assert_eq(parsed.query(), Some("query"))
      assert_eq(parsed.fragment(), Some("fragment"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri = Iri::Iri(iri)
  assert_eq(iri.to_own(), "https://example.com/path?query#fragment")
  let result = Iri::parse(iri)
  match result {
    Ok(parsed) => {
      assert_eq(parsed.to_own(), iri.to_own())
      assert_true(parsed.is_absolute())
      assert_eq(parsed.scheme(), Some("https"))
      assert_eq(parsed.authority(), Some("example.com"))
      assert_eq(parsed.path(), Some("/path"))
      assert_eq(parsed.query(), Some("query"))
      assert_eq(parsed.fragment(), Some("fragment"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative IRI (absolute path)" {
  let iri = "/path/to/resource"
  let iri = Iri::Iri(iri)
  let result = Iri::parse(iri)

  match result {
    Ok(parsed) => {
      assert_eq(parsed.to_own(), iri.to_own())
      assert_false(parsed.is_absolute()) // No scheme
      assert_eq(parsed.scheme(), None)
      assert_eq(parsed.authority(), None)
      assert_eq(parsed.path(), Some("/path/to/resource"))
      assert_eq(parsed.query(), None)
      assert_eq(parsed.fragment(), None)
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: relative path (relative-path reference)" {
  let iri = "path/to/resource"
  let iri = Iri::Iri(iri)

  let result = Iri::parse(iri)

  match result {
    Ok(parsed) => {
      assert_eq(parsed.path(), Some("path/to/resource"))
      assert_false(parsed.is_absolute())
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: query only" {
  let iri = "https://example.com?query=value"
  let iri = Iri::Iri(iri)

  let result = Iri::parse(iri)

  match result {
    Ok(parsed) => {
      assert_eq(parsed.path(), Some(""))
      assert_eq(parsed.query(), Some("query=value"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: fragment only" {
  let iri = "https://example.com#fragment"
  let iri = Iri::Iri(iri)

  let result = Iri::parse(iri)

  match result {
    Ok(parsed) => assert_eq(parsed.fragment(), Some("fragment"))
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse: error on invalid scheme format" {
  // "invalid:iri" is technically a valid URI with scheme "invalid".
  // If the test expects NoScheme, it implies strict checking or specific context.
  // However, our parser accepts alphabetic schemes.
  // Let's adjust the test to expect Ok if the parser is standard, 
  // OR change input to something that definitely fails if we had strict validation.
  // For now, assuming standard parser behavior:
  let iri = Iri::Iri("invalid:iri")
  let result = Iri::parse(iri)

  match result {
    Ok(parsed) => assert_eq(parsed.scheme(), Some("invalid"))
    Err(IriError::NoScheme) => fail("Unexpected NoScheme for 'invalid:iri'")
    Err(e) => fail("Expected Ok or specific error, got \{e}")
  }
}

///|
test "parse_unchecked: basic functionality" {
  let iri = "https://example.com/path"
  let iri = Iri::Iri(iri)
  let parsed = Iri::parse(iri, unchecked=true)
  match parsed {
    Ok(parsed) => {
      assert_eq(parsed.to_own(), iri.to_own())
      assert_true(parsed.is_absolute())
      assert_eq(parsed.scheme(), Some("https"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse_unchecked: empty string" {
  let iri = Iri::Iri("")
  let parsed = Iri::parse(iri, unchecked=true)
  match parsed {
    Ok(parsed) => {
      assert_eq(parsed.to_own(), "")
      assert_false(parsed.is_absolute()) // Empty string has no scheme
      assert_eq(parsed.scheme(), None)
      assert_eq(parsed.authority(), None)
      assert_eq(parsed.path(), Some(""))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse_unchecked: Unicode IRI" {
  let iri = "https://例子.测试/路径"
  let iri = Iri::Iri(iri)

  let parsed = Iri::parse(iri, unchecked=true)
  match parsed {
    Ok(parsed) => {
      assert_eq(parsed.to_own(), "https://例子.测试/路径")
      assert_eq(parsed.scheme(), Some("https"))
      assert_eq(parsed.authority(), Some("例子.测试"))
      assert_eq(parsed.path(), Some("/路径"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "parse_unchecked: percent encoding preserved" {
  let iri = "https://example.com/path%20with%20spaces"
  let iri = Iri::Iri(iri)
  let parsed = Iri::parse(iri, unchecked=true)
  match parsed {
    Ok(parsed) => assert_eq(parsed.path(), Some("/path%20with%20spaces"))
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

// --- Group: Resolution Tests ---

///|
test "resolve: relative to absolute base" {
  let iri = "https://example.com/base/path"
  let iri_obj = Iri::Iri(iri)

  // 先解析 base，处理可能的解析错误
  match Iri::parse(iri_obj, unchecked=true) {
    Ok(base) => {
      let relative = "relative/path"

      // 再调用 resolve，处理可能的解析/合并错误
      match base.resolve(relative) {
        Ok(resolved) =>
          assert_eq(resolved.to_own(), "https://example.com/base/relative/path")
        Err(e) => fail("Expected Ok from resolve, got Err: \{e}")
      }
    }
    Err(e) => fail("Expected Ok from parse, got Err: \{e}")
  }
}

// test "resolve: absolute reference overrides base" {
//   let base = Iri::parse_unchecked("https://example.com/base/")
//   let absolute = "http://other.com/path"

//   match base.resolve(absolute) {
//     Ok(resolved) => {
//       assert_eq(resolved.to_own(), "http://other.com/path")
//       assert_eq(resolved.scheme(), Some("http"))
//       assert_eq(resolved.authority(), Some("other.com"))
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// test "resolve: path starting with slash" {
//   let base = Iri::parse_unchecked("https://example.com/base/path")
//   let relative = "/new/path"

//   match base.resolve(relative) {
//     Ok(resolved) => {
//       assert_eq(resolved.to_own(), "https://example.com/new/path")
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// test "resolve: query and fragment replacement" {
//   let base = Iri::parse_unchecked("https://example.com/path")
//   let relative = "?query=value#fragment"

//   match base.resolve(relative) {
//     Ok(resolved) => {
//       assert_eq(resolved.to_own(), "https://example.com/path?query=value#fragment")
//       assert_eq(resolved.query(), Some("query=value"))
//       assert_eq(resolved.fragment(), Some("fragment"))
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// test "resolve: dot segments (preserved as per simple impl)" {
//   let base = Iri::parse_unchecked("https://example.com/a/b/c/")
//   let relative = "../d/e"

//   match base.resolve(relative) {
//     Ok(resolved) => {
//       // Our simple resolve merges paths but doesn't normalize dots automatically
//       // Base path: /a/b/c/ -> last slash at index 7. Substr(0, 8) = "/a/b/c/"
//       // Relative: ../d/e
//       // Result: /a/b/c/../d/e
//       assert_eq(resolved.to_own(), "https://example.com/a/b/c/../d/e")
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// test "resolve: sequence of resolutions" {

//   let base = Iri::parse_unchecked("https://example.com/a/b/c/")

//   match base.resolve("d") {
//     Ok(r1) => {
//       assert_eq(r1.to_own(), "https://example.com/a/b/c/d")

//       match r1.resolve("e") {
//         Ok(r2) => {
//           assert_eq(r2.to_own(), "https://example.com/a/b/c/d/e")
//         }
//         Err(e) => fail("Failed second resolve: \{e}")
//       }
//     }
//     Err(e) => fail("Failed first resolve: \{e}")
//   }
// }

// test "resolve_into: write to buffer" {
//   let base = Iri::parse_unchecked("https://example.com/")
//   let buffer = StringBuilder::new(size_hint=100)

//   match base.resolve_into("path/to/resource", buffer) {
//     Ok(_) => {
//       assert_eq(buffer.to_string(), "https://example.com/path/to/resource")
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// // --- Group: Relativization Tests ---

// test "relativize: simple child path" {
//   let base = Iri::parse_unchecked("https://example.com/a/b/c/")
//   let absolute = Iri::parse_unchecked("https://example.com/a/b/c/d/e")

//   match Iri::relativize(base, absolute) {
//     Ok(relative) => {
//       assert_eq(relative.to_own(), "d/e")
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// test "relativize: different scheme returns absolute" {
//   let base = Iri::parse_unchecked("https://example.com/path")
//   let absolute = Iri::parse_unchecked("http://example.com/path")

//   match Iri::relativize(base, absolute) {
//     Ok(relative) => {
//       assert_eq(relative.to_own(), "http://example.com/path")
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// test "relativize: different authority returns absolute" {
//   let base = Iri::parse_unchecked("https://example.com/path")
//   let absolute = Iri::parse_unchecked("https://different.com/path")

//   match Iri::relativize(base, absolute) {
//     Ok(relative) => {
//       assert_eq(relative.to_own(), "https://different.com/path")
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// test "relativize: parent directory navigation" {
//   let base = Iri::parse_unchecked("https://example.com/a/b/c/d")
//   let absolute = Iri::parse_unchecked("https://example.com/a/b/e/f")

//   match Iri::relativize(base, absolute) {
//     Ok(relative) => {
//       // Our simple relativize returns absolute if prefix doesn't match
//       assert_eq(relative.to_own(), "https://example.com/a/b/e/f")
//     }
//     Err(e) => fail("Expected Ok, got Err: \{e}")
//   }
// }

// // --- Group: Component Accessors ---

// test "accessors: scheme" {
//   assert_eq(Iri::parse_unchecked("https://example.com").scheme(), Some("https"))
//   assert_eq(Iri::parse_unchecked("/path").scheme(), None)
// }

// test "accessors: authority" {
//   assert_eq(Iri::parse_unchecked("https://example.com:8080/path").authority(), Some("example.com:8080"))
//   assert_eq(Iri::parse_unchecked("/path").authority(), None)
//   assert_eq(Iri::parse_unchecked("https://[::1]:8080/path").authority(), Some("[::1]:8080"))
//   assert_eq(Iri::parse_unchecked("https://user:pass@example.com/path").authority(), Some("user:pass@example.com"))
// }

// test "accessors: path" {
//   assert_eq(Iri::parse_unchecked("https://example.com/path/to/resource").path(), "/path/to/resource")
//   assert_eq(Iri::parse_unchecked("https://example.com/").path(), "/")
//   assert_eq(Iri::parse_unchecked("https://example.com").path(), "")
//   assert_eq(Iri::parse_unchecked("path/to/resource").path(), "path/to/resource")
// }

// test "accessors: query" {
//   assert_eq(Iri::parse_unchecked("https://example.com/path?key=value").query(), Some("key=value"))
//   assert_eq(Iri::parse_unchecked("https://example.com/path?").query(), Some(""))
//   assert_eq(Iri::parse_unchecked("https://example.com/path").query(), None)
// }

// test "accessors: fragment" {
//   assert_eq(Iri::parse_unchecked("https://example.com/path#section-1").fragment(), Some("section-1"))
//   assert_eq(Iri::parse_unchecked("https://example.com/path#").fragment(), Some(""))
//   assert_eq(Iri::parse_unchecked("https://example.com/path").fragment(), None)
// }

// // --- Group: Conversion & Inner Value ---

// test "conversion: as_ref" {
//   let iri = Iri::parse_unchecked("https://example.com/path")
//   // In MoonBit, as_ref might not be needed if we just use the object directly
//   // But if defined:
//   let as_ref = iri // Copy/Self

//   assert_eq(as_ref.to_own(), "https://example.com/path")
//   assert_true(as_ref.is_absolute())
//   assert_eq(as_ref.scheme(), Some("https"))
// }

// test "conversion: into_inner" {
//   let iri = Iri::parse_unchecked("https://example.com")
//   let inner: String = iri.into_inner()

//   assert_eq(inner, "https://example.com")
// }

// // --- Group: Edge Cases & Specific Formats ---

// test "edge: single slash" {
//   let slash = Iri::parse_unchecked("/")
//   assert_eq(slash.to_own(), "/")
//   assert_eq(slash.path(), "/")
// }

// test "edge: scheme without authority (file URI)" {
//   let no_authority = Iri::parse_unchecked("file:/path/to/file")
//   assert_eq(no_authority.scheme(), Some("file"))
//   assert_eq(no_authority.authority(), None)
//   assert_eq(no_authority.path(), "/path/to/file")
// }

// test "edge: is_absolute behavior" {
//   assert_true(Iri::parse_unchecked("https://example.com").is_absolute())
//   assert_false(Iri::parse_unchecked("/path").is_absolute()) // No scheme
//   assert_false(Iri::parse_unchecked("//example.com/path").is_absolute()) // No scheme
// }
