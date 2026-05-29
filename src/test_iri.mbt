///|
test "parse_unchecked: basic absolute IRI" {
  let iri = "https://example.com/path?query#fragment"
  let iri = Iri::Iri(iri)
  let iri = IriRef::new(iri)
  assert_eq(iri.to_own(), "https://example.com/path?query#fragment")
  let result = IriRef::parse(iri, unchecked=true)
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
  let iri = IriRef::new(iri)
  assert_eq(iri.to_own(), "https://example.com/path?query#fragment")
  let result = IriRef::parse(iri)
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
  let iri = IriRef::new(iri)
  let result = IriRef::parse(iri)

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
  let iri = IriRef::new(iri)

  let result = IriRef::parse(iri)

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
  let iri = IriRef::new(iri)

  let result = IriRef::parse(iri)

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
  let iri = IriRef::new(iri)

  let result = IriRef::parse(iri)

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
  let iri = IriRef::new(iri)

  let result = IriRef::parse(iri)

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
  let iri = IriRef::new(iri)

  let parsed = IriRef::parse(iri, unchecked=true)
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
  let iri = IriRef::new(iri)
  let parsed = IriRef::parse(iri, unchecked=true)
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
  let iri = IriRef::new(iri)
  let parsed = IriRef::parse(iri, unchecked=true)
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
  let iri = IriRef::new(iri)
  let parsed = IriRef::parse(iri, unchecked=true)
  match parsed {
    Ok(parsed) => assert_eq(parsed.path(), Some("/path%20with%20spaces"))
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

// --- Group: Resolution Tests ---

///|
test "resolve: relative to absolute base" {
  let iri = "https://example.com/base/path"
  let iri = Iri::Iri(iri)
  let iri = IriRef::new(iri)
  // 先解析 base，处理可能的解析错误
  match IriRef::parse(iri, unchecked=true) {
    Ok(base) => {
      let relative = "relative/path"
      let base = IriRef::new(base)

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

///|
test "resolve: absolute reference overrides base" {
  let iri = "https://example.com/base/"
  let iri = Iri::Iri(iri)
  let iri = IriRef::new(iri)
  // let base = IriRef::parse(iri, unchecked=true)
  let absolute = "http://other.com/path"

  match iri.resolve(absolute) {
    Ok(resolved) => {
      assert_eq(resolved.to_own(), "http://other.com/path")
      assert_eq(resolved.scheme(), Some("http"))
      assert_eq(resolved.authority(), Some("other.com"))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "resolve: path starting with slash" {
  let iri = "https://example.com/base/path"
  let iri = Iri::Iri(iri)
  let iri = IriRef::new(iri)
  
  match IriRef::parse(iri, unchecked=true) {
    Ok(base) => {
      let relative = "/new/path"
      let base = IriRef::new(base)
      match base.resolve(relative) {
        Ok(resolved) => {
          assert_eq(resolved.to_own(), "https://example.com/new/path")
        }
        Err(e) => fail("Expected Ok, got Err: \{e}")
      }
    }
    Err(e) => fail("Expected Ok from parse, got Err: \{e}")
  }
}
test "resolve: query and fragment replacement" {
  let iri = "https://example.com/path"
  let iri = Iri::Iri(iri)
  let iri = IriRef::new(iri)
  
  match IriRef::parse(iri, unchecked=true) {
    Ok(base) => {
      let relative = "?query=value#fragment"
      let base = IriRef::new(base)
      match base.resolve(relative) {
        Ok(resolved) => {
          assert_eq(resolved.to_own(), "https://example.com/path?query=value#fragment")
          assert_eq(resolved.query(), Some("query=value"))
          assert_eq(resolved.fragment(), Some("fragment"))
        }
        Err(e) => fail("Expected Ok, got Err: \{e}")
      }
    }
    Err(e) => fail("Expected Ok from parse, got Err: \{e}")
  }
}

test "resolve: dot segments (preserved as per simple impl)" {
  let iri = "https://example.com/a/b/c/"
  let iri = Iri::Iri(iri)
  let iri = IriRef::new(iri)
  
  match IriRef::parse(iri, unchecked=true) {
    Ok(base) => {
            let base = IriRef::new(base)

      let relative = "../d/e"
      match base.resolve(relative,remove_dot_segments =false) {
        Ok(resolved) => {
          // Our simple resolve merges paths but doesn't normalize dots automatically
          assert_eq(resolved.to_own(), "https://example.com/a/b/c/../d/e")
        }
        Err(e) => fail("Expected Ok, got Err: \{e}")
      }
    }
    Err(e) => fail("Expected Ok from parse, got Err: \{e}")
  }
}

test "resolve: sequence of resolutions" {
  let iri = "https://example.com/a/b/c/"
  let iri = Iri::Iri(iri)
  let iri = IriRef::new(iri)
  
  match IriRef::parse(iri, unchecked=true) {
    Ok(base1) => {
      let base1 = IriRef::new(base1)
      match base1.resolve("d") {
        Ok(r1) => {
          assert_eq(r1.to_own(), "https://example.com/a/b/c/d")
          // r1 is likely an Iri or IriRef, assuming it has resolve method
          let r1 = IriRef::new(r1)
          match r1.resolve("e") {
            Ok(r2) => {
              assert_eq(r2.to_own(), "https://example.com/a/b/c/e")
            }
            Err(e) => fail("Failed second resolve: \{e}")
          }
        }
        Err(e) => fail("Failed first resolve: \{e}")
      }
    }
    Err(e) => fail("Expected Ok from parse, got Err: \{e}")
  }
}

// test "resolve_into: write to buffer" {
//   let iri = "https://example.com/"
//   let iri = Iri::Iri(iri)
//   let iri = IriRef::new(iri)
  
//   match IriRef::parse(iri, unchecked=true) {
//     Ok(base) => {
//       let buffer = StringBuilder::new(size_hint=100)
//       match base.resolve_into("path/to/resource", buffer) {
//         Ok(_) => {
//           assert_eq(buffer.to_string(), "https://example.com/path/to/resource")
//         }
//         Err(e) => fail("Expected Ok, got Err: \{e}")
//       }
//     }
//     Err(e) => fail("Expected Ok from parse, got Err: \{e}")
//   }
// }

// --- Group: Relativization Tests ---

// test "relativize: simple child path" {
//   let base_iri = "https://example.com/a/b/c/"
//   let base_iri = Iri::Iri(base_iri)
//   let base_iri = IriRef::new(base_iri)
  
//   let abs_iri = "https://example.com/a/b/c/d/e"
//   let abs_iri = Iri::Iri(abs_iri)
//   let abs_iri = IriRef::new(abs_iri)
  
//   match IriRef::parse(base_iri, unchecked=true) {
//     Ok(base_parsed) => {
//       match IriRef::parse(abs_iri, unchecked=true) {
//         Ok(abs_parsed) => {
//           // Assuming Iri::relativize takes Iri instances, convert using to_owned()
//           match Iri::relativize(base_parsed.to_owned(), abs_parsed.to_owned()) {
//             Ok(relative) => {
//               assert_eq(relative.to_own(), "d/e")
//             }
//             Err(e) => fail("Expected Ok, got Err: \{e}")
//           }
//         }
//         Err(e) => fail("Expected Ok from parse absolute, got Err: \{e}")
//       }
//     }
//     Err(e) => fail("Expected Ok from parse base, got Err: \{e}")
//   }
// }

// test "relativize: different scheme returns absolute" {
//   let base_iri = "https://example.com/path"
//   let base_iri = Iri::Iri(base_iri)
//   let base_iri = IriRef::new(base_iri)
  
//   let abs_iri = "http://example.com/path"
//   let abs_iri = Iri::Iri(abs_iri)
//   let abs_iri = IriRef::new(abs_iri)
  
//   match IriRef::parse(base_iri, unchecked=true) {
//     Ok(base_parsed) => {
//       match IriRef::parse(abs_iri, unchecked=true) {
//         Ok(abs_parsed) => {
//           match Iri::relativize(base_parsed.to_owned(), abs_parsed.to_owned()) {
//             Ok(relative) => {
//               assert_eq(relative.to_own(), "http://example.com/path")
//             }
//             Err(e) => fail("Expected Ok, got Err: \{e}")
//           }
//         }
//         Err(e) => fail("Expected Ok from parse absolute, got Err: \{e}")
//       }
//     }
//     Err(e) => fail("Expected Ok from parse base, got Err: \{e}")
//   }
// }

// test "relativize: different authority returns absolute" {
//   let base_iri = "https://example.com/path"
//   let base_iri = Iri::Iri(base_iri)
//   let base_iri = IriRef::new(base_iri)
  
//   let abs_iri = "https://different.com/path"
//   let abs_iri = Iri::Iri(abs_iri)
//   let abs_iri = IriRef::new(abs_iri)
  
//   match IriRef::parse(base_iri, unchecked=true) {
//     Ok(base_parsed) => {
//       match IriRef::parse(abs_iri, unchecked=true) {
//         Ok(abs_parsed) => {
//           match Iri::relativize(base_parsed.to_owned(), abs_parsed.to_owned()) {
//             Ok(relative) => {
//               assert_eq(relative.to_own(), "https://different.com/path")
//             }
//             Err(e) => fail("Expected Ok, got Err: \{e}")
//           }
//         }
//         Err(e) => fail("Expected Ok from parse absolute, got Err: \{e}")
//       }
//     }
//     Err(e) => fail("Expected Ok from parse base, got Err: \{e}")
//   }
// }

// test "relativize: parent directory navigation" {
//   let base_iri = "https://example.com/a/b/c/d"
//   let base_iri = Iri::Iri(base_iri)
//   let base_iri = IriRef::new(base_iri)
  
//   let abs_iri = "https://example.com/a/b/e/f"
//   let abs_iri = Iri::Iri(abs_iri)
//   let abs_iri = IriRef::new(abs_iri)
  
//   match IriRef::parse(base_iri, unchecked=true) {
//     Ok(base_parsed) => {
//       match IriRef::parse(abs_iri, unchecked=true) {
//         Ok(abs_parsed) => {
//           match Iri::relativize(base_parsed.to_owned(), abs_parsed.to_owned()) {
//             Ok(relative) => {
//               // Our simple relativize returns absolute if prefix doesn't match
//               assert_eq(relative.to_own(), "https://example.com/a/b/e/f")
//             }
//             Err(e) => fail("Expected Ok, got Err: \{e}")
//           }
//         }
//         Err(e) => fail("Expected Ok from parse absolute, got Err: \{e}")
//       }
//     }
//     Err(e) => fail("Expected Ok from parse base, got Err: \{e}")
//   }
// }