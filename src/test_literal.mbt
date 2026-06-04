///|
/// Tests for Literal creation
test "simple literal creation" {
  let lit = Literal::new_simple_literal("hello")
  assert_eq(lit.value(), "hello")
}

///|
test "simple literal with empty string" {
  let lit = Literal::new_simple_literal("")
  assert_eq(lit.value(), "")
}

///|
test "typed literal with non-string datatype" {
  let lit = LiteralRef::new_typed_literal(
    VarDataType::TrueVar,
    NamedNodeRef::NamedNodeRef(lwBOOLEAN.to_string()),
  )
  assert_eq(lit.into_owned().value(), "true")
  // assert_eq(lit.datatype().to_string(), lwBOOLEAN.to_string())
}

///|
test "typed literal with string datatype normalizes to simple" {
  let lit = LiteralRef::new_typed_literal(
    VarDataType::StringVar("hello".to_string()),
    NamedNodeRef::NamedNodeRef(lwSTRING.to_string()),
  )
  // Should be normalized to simple literal since xsd:string is the default
  assert_eq(lit.into_owned().value(), "hello")
}

///|
test "typed literal with integer datatype" {
  let lit = LiteralRef::new_typed_literal(
    VarDataType::IntVar(42),
    NamedNodeRef::NamedNodeRef(lwINTEGER.to_string()),
  )
  assert_eq(lit.into_owned().value(), "42")
  assert_eq(lit.datatype().to_string(), lwINTEGER.to_string())
}

///|
/// Tests for language-tagged literals
test "language-tagged literal creation" {
  let lit = Literal::new_language_tagged_literal("hello", "en")
  match lit {
    Ok(l) => assert_eq(l.value(), "hello")
    Err(e) => fail("Failed to create language-tagged literal: \{e}")
  }
}

///|
test "language-tagged literal case normalization" {
  let lit = Literal::new_language_tagged_literal("hello", "EN")
  match lit {
    Ok(l) => assert_eq(l.value(), "hello")
    Err(e) => fail("Failed to create language-tagged literal: \{e}")
  }
}

///|
test "language-tagged literal language extraction" {
  let lit = Literal::new_language_tagged_literal("hello", "en")
  match lit {
    Ok(l) => assert_eq(l.language(), Some("en"))
    Err(_) => fail("Failed")
  }
}

///|
test "language-tagged literal invalid tag" {
  let lit = Literal::new_language_tagged_literal("hello", "123")
  match lit {
    Ok(_) => fail("Should have failed with invalid language tag")
    Err(_) => () // Expected
  }
}

///|
test "language-tagged literal without direction" {
  let lit = LiteralRef::new_language_tagged_literal_unchecked("hello", "en")
  assert_eq(lit.to_owned().value(), "hello")
  assert_eq(lit.language(), Some("en"))
  assert_eq(lit.direction(), None)
}

// Tests for directional language-tagged literals

///|
test "directional language-tagged literal ltr" {
  let lit = Literal::new_directional_language_tagged_literal(
    "hello",
    "en",
    BaseDirection::Ltr,
  )
  match lit {
    Ok(l) => {
      assert_eq(l.value(), "hello")
      assert_eq(l.language(), Some("en"))
      assert_eq(l.direction(), Some(BaseDirection::Ltr))
    }
    Err(e) => fail("Failed: \{e}")
  }
}

///|
test "directional language-tagged literal rtl" {
  let lit = Literal::new_directional_language_tagged_literal(
    "مرحبا",
    "ar",
    BaseDirection::Rtl,
  )
  match lit {
    Ok(l) => {
      assert_eq(l.value(), "مرحبا")
      assert_eq(l.language(), Some("ar"))
      assert_eq(l.direction(), Some(BaseDirection::Rtl))
    }
    Err(e) => fail("Failed: \{e}")
  }
}

///|
test "directional language-tagged literal unchecked" {
  let tag = LanguageTag::parse("en").unwrap()
  let lit = Literal::new_directional_language_tagged_literal_unchecked(
    "hello",
    tag,
    BaseDirection::Ltr,
  )
  assert_eq(lit.value(), "hello")
  assert_eq(lit.language(), Some("en"))
  assert_eq(lit.direction(), Some(BaseDirection::Ltr))
}

///|
/// Tests for value extraction
test "literal value extraction for simple literal" {
  let lit = Literal::new_simple_literal("test")
  assert_eq(lit.value(), "test")
}

///|
// test "literal value extraction for typed literal" {
//   let lit = LiteralRef::new_typed_literal(
//     VarDataType::IntVar(123),
//     NamedNodeRef::NamedNodeRef(lwINTEGER.to_string()),
//   )
//   assert_eq(lit.to_owned().value(), "123")
// }

///|
test "literal value extraction for language-tagged" {
  let lit = Literal::new_language_tagged_literal("test", "en").unwrap()
  assert_eq(lit.value(), "test")
}

///|
/// Tests for datatype extraction
test "datatype for simple literal" {
  let lit = Literal::new_simple_literal("test")
  assert_eq(lit.datatype(), lwSTRING)
}

///|
test "datatype for typed literal" {
  let lit = LiteralRef::new_typed_literal(
    VarDataType::TrueVar,
    NamedNodeRef::NamedNodeRef(lwBOOLEAN.to_string()),
  )
  assert_eq(lit.datatype(), lwBOOLEAN)
}

///|
test "datatype for language-tagged literal" {
  let lit = Literal::new_language_tagged_literal("test", "en").unwrap()
  assert_eq(lit.datatype(), lwLANG_STRING)
}

///|
test "datatype for directional language-tagged literal" {
  let tag = LanguageTag::parse("en").unwrap()
  let lit = Literal::new_directional_language_tagged_literal_unchecked(
    "test",
    tag,
    BaseDirection::Ltr,
  )
  assert_eq(lit.datatype(), lwDIR_LANG_STRING)
}

///|
/// Tests for destructuring
test "destruct simple literal" {
  let lit = Literal::new_simple_literal("hello")
  let (value, datatype, language, direction) = lit.destruct()
  assert_eq(value, "hello")
  assert_eq(datatype, None)
  assert_eq(language, None)
  assert_eq(direction, None)
}

///|
// test "destruct typed literal" {
//   let lit = LiteralRef::new_typed_literal(
//     VarDataType::IntVar(42),
//     NamedNodeRef::NamedNodeRef(lwINTEGER.to_string()),
//   )
//   let (value, datatype, language, direction) = lit.destruct()
//   assert_eq(value, "42")
//   assert_true(datatype.is_some())
//   assert_eq(language, None)
//   assert_eq(direction, None)
// }

///|
test "destruct language-tagged literal" {
  let lit = Literal::new_language_tagged_literal("hello", "en").unwrap()
  let (value, datatype, language, direction) = lit.destruct()
  assert_eq(value, "hello")
  assert_eq(datatype, None)
  assert_eq(language, Some("en"))
  assert_eq(direction, None)
}

///|
test "destruct directional language-tagged literal" {
  let tag = LanguageTag::parse("en").unwrap()
  let lit = Literal::new_directional_language_tagged_literal_unchecked(
    "hello",
    tag,
    BaseDirection::Rtl,
  )
  let (value, datatype, language, direction) = lit.destruct()
  assert_eq(value, "hello")
  assert_eq(datatype, None)
  assert_eq(language, Some("en"))
  assert_eq(direction, Some(BaseDirection::Rtl))
}

///|
/// Tests for LiteralRef
test "literalref simple literal creation" {
  let literalref = LiteralRef::new_simple_literal("hello")
  assert_eq(literalref.into_value(), "hello")
}

///|
test "literalref typed literal" {
  let literalref = LiteralRef::new_typed_literal(
    VarDataType::TrueVar,
    lwBOOLEAN,
  )
  assert_eq(literalref.into_value(), "true")
  assert_eq(literalref.datatype(), lwBOOLEAN)
}

///|
test "literalref typed literal with string normalizes to simple" {
  let literalref = LiteralRef::new_typed_literal(
    VarDataType::StringVar("hello".to_string()),
    lwSTRING,
  )
  assert_eq(literalref.into_value(), "hello")
  assert_eq(literalref.datatype(), lwSTRING)
}

///|
test "literalref language-tagged literal" {
  let literalref = Literal::new_language_tagged_literal_unchecked("hello", "en")
  assert_eq(literalref.as_ref().into_value(), "hello")
  assert_eq(literalref.language(), Some("en".to_string()))
  assert_eq(literalref.datatype(), lwLANG_STRING)
}

///|
test "literalref directional language-tagged literal" {
  let tag = LanguageTag::parse("en").unwrap()
  let literalref = LiteralRef::new_directional_language_tagged_literal_unchecked(
    "hello",
    tag,
    BaseDirection::Ltr,
  )
  assert_eq(literalref.into_value(), "hello")
  assert_eq(literalref.language(), Some("en".to_string()))
  assert_eq(literalref.direction(), Some(BaseDirection::Ltr))
  assert_eq(literalref.datatype(), lwDIR_LANG_STRING)
}

///|
test "literalref into_owned" {
  let literalref = LiteralRef::new_simple_literal("hello")
  let owned = literalref.into_owned()
  assert_eq(owned.value(), "hello")
}

// ///|
// test "literalref to_owned" {
//   let literalref = LiteralRef::new_language_tagged_literal_unchecked(
//     "hello", "en",
//   )
//   let owned = literalref.to_owned()
//   assert_eq(owned.value(), "hello")
//   assert_eq(owned.language(), Some("en"))
// }

// ///|
// /// Tests for equality between Literal and LiteralRef
// test "literal equality simple vs typed string" {
//   let simple = Literal::new_simple_literal("foo")
//   let typed = Literal::new_typed_literal(
//     VarDataType::StringVar("foo"),
//     NamedNode::NamedNode(lwSTRING.to_string()),
//   )
//   assert_eq(simple, typed)
// }

// ///|
// test "literalref equality simple vs typed string" {
//   let simple = LiteralRef::new_simple_literal("foo")
//   let typed = LiteralRef::new_typed_literal(
//     VarDataType::StringVar("foo"),
//     lwSTRING,
//   )
//   assert_eq(simple, typed)
// }

// ///|
// test "literal as_ref equality with typed literal" {
//   let literal = Literal::new_typed_literal(
//     VarDataType::StringVar("foo"),
//     NamedNode::NamedNode(lwSTRING.to_string()),
//   )
//   let literalref = LiteralRef::new_simple_literal("foo")
//   assert_eq(literalref, literal.as_stringview())
// }

// ///|
// test "literal vs literalref equality" {
//   let lit = Literal::new_simple_literal("foo")
//   let literalref = LiteralRef::new_simple_literal("foo")
//   assert_eq(lit, literalref.to_owned()) // This tests Literal == LiteralRef via derived Eq
// }

// ///|
// /// Tests for Show (to_string)
// test "literal show simple" {
//   let lit = Literal::new_simple_literal("hello")
//   assert_eq(lit.to_string(), "hello")
// }

// ///|
// test "literal show language-tagged" {
//   let lit = Literal::new_language_tagged_literal("hello", "en").unwrap()
//   assert_eq(lit.to_string(), "hello@en")
// }

// ///|
// test "literal show directional language-tagged" {
//   let tag = LanguageTag::parse("en").unwrap()
//   let lit = Literal::new_directional_language_tagged_literal_unchecked(
//     "hello",
//     tag,
//     BaseDirection::Rtl,
//   )
//   assert_eq(lit.to_string(), "hello@en--rtl")
// }

// ///|
// test "literal show typed literal" {
//   let lit = Literal::new_typed_literal(
//     VarDataType::IntVar(42),
//     NamedNode::NamedNode(lwINTEGER.to_string()),
//   )
//   assert_eq(lit.to_string(), "42^^http://www.w3.org/2001/XMLSchema#integer")
// }

// ///|
// test "literalref to_string" {
//   let literalref = Literal::new_typed_literal(
//     VarDataType::StringVar("hello"),
//     lwSTRING,
//   )
//   let s = literalref.to_string()
//   debug(s) // Should produce quoted string representation
//   assert_true(s.has_prefix("\""))
//   assert_true(s.has_suffix("\""))
// }
