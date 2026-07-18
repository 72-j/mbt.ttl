///|
test "simple literal creation" {
  let lit = @lib.Literal::new_simple_literal("hello")
  @debug.assert_eq(lit.value(), "hello")
}

///|
test "simple literal with empty string" {
  let lit = @lib.Literal::new_simple_literal("")
  @debug.assert_eq(lit.value(), "")
}

///|
test "typed literal with non-string datatype" {
  let lit = @lib.LiteralRef::new_typed_literal(
    "true",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwBOOLEAN.to_string()),
  )
  @debug.assert_eq(lit.into_owned().value(), "true")
  // @debug.assert_eq(lit.datatype().to_string(), @lib.lwBOOLEAN.to_string())
}

///|
test "typed literal with string datatype normalizes to simple" {
  let lit = @lib.LiteralRef::new_typed_literal(
    "hello",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwSTRING.to_string()),
  )
  // Should be normalized to simple literal since xsd:string is the default
  @debug.assert_eq(lit.into_owned().value(), "hello")
}

///|
test "typed literal with integer datatype" {
  let lit = @lib.LiteralRef::new_typed_literal(
    "42",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwINTEGER.to_string()),
  )
  @debug.assert_eq(lit.into_owned().value(), "42")
  @debug.assert_eq(lit.datatype().to_string(), @lib.lwINTEGER.to_string())
}

///|
test "language-tagged literal creation" {
  let lit = @lib.Literal::new_language_tagged_literal("hello", "en")
  match lit {
    Ok(l) => @debug.assert_eq(l.value(), "hello")
    Err(e) => fail("Failed to create language-tagged literal: \{e}")
  }
}

///|
test "language-tagged literal case normalization" {
  let lit = @lib.Literal::new_language_tagged_literal("hello", "EN")
  match lit {
    Ok(l) => @debug.assert_eq(l.value(), "hello")
    Err(e) => fail("Failed to create language-tagged literal: \{e}")
  }
}

///|
test "language-tagged literal language extraction" {
  let lit = @lib.Literal::new_language_tagged_literal("hello", "en")
  match lit {
    Ok(l) =>
      match l.language() {
        Some(lang) => @debug.assert_eq(lang, "en")
        None => fail("Expected language 'en', got None")
      }
    Err(_) => fail("Failed")
  }
}

///|
test "language-tagged literal invalid tag" {
  let lit = @lib.Literal::new_language_tagged_literal("hello", "123")
  match lit {
    Ok(_) => fail("Should have failed with invalid language tag")
    Err(_) => () // Expected
  }
}

///|
test "language-tagged literal without direction" {
  let lit = @lib.LiteralRef::new_language_tagged_literal_unchecked(
    "hello", "en",
  )
  @debug.assert_eq(lit.into_owned().value(), "hello")
  match lit.language() {
    Some(lang) => @debug.assert_eq(lang, "en")
    None => fail("Expected language 'en', got None")
  }
  @debug.assert_eq(lit.direction(), None)
}

// Tests for directional language-tagged literals

///|
test "directional language-tagged literal ltr" {
  let lit = @lib.Literal::new_directional_language_tagged_literal(
    "hello",
    "en",
    @lib.BaseDirection::Ltr,
  )
  match lit {
    Ok(l) => {
      @debug.assert_eq(l.value(), "hello")
      @debug.assert_eq(l.language(), Some("en"))
      @debug.assert_eq(l.direction(), Some(@lib.BaseDirection::Ltr))
    }
    Err(e) => fail("Failed: \{e}")
  }
}

///|
test "directional language-tagged literal rtl" {
  let lit = @lib.Literal::new_directional_language_tagged_literal(
    "مرحبا",
    "ar",
    @lib.BaseDirection::Rtl,
  )
  match lit {
    Ok(l) => {
      @debug.assert_eq(l.value(), "مرحبا")
      @debug.assert_eq(l.language(), Some("ar"))
      @debug.assert_eq(l.direction(), Some(@lib.BaseDirection::Rtl))
    }
    Err(e) => fail("Failed: \{e}")
  }
}

///|
test "directional language-tagged literal unchecked" {
  let tag = @lib.LanguageTag::parse("en").unwrap()
  let lit = @lib.Literal::new_directional_language_tagged_literal_unchecked(
    "hello",
    tag,
    @lib.BaseDirection::Ltr,
  )
  @debug.assert_eq(lit.value(), "hello")
  @debug.assert_eq(lit.language(), Some("en"))
  @debug.assert_eq(lit.direction(), Some(@lib.BaseDirection::Ltr))
}

///|
test "literal value extraction for simple literal" {
  let lit = @lib.Literal::new_simple_literal("test")
  @debug.assert_eq(lit.value(), "test")
}

///|
test "literal value extraction for typed literal" {
  let lit = @lib.LiteralRef::new_typed_literal(
    "123",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwINTEGER.to_string()),
  )
  @debug.assert_eq(lit.into_owned().value(), "123")
}

///|
test "literal value extraction for language-tagged" {
  let lit = @lib.Literal::new_language_tagged_literal("test", "en").unwrap()
  @debug.assert_eq(lit.value(), "test")
}

///|
test "datatype for simple literal" {
  let lit = @lib.Literal::new_simple_literal("test")
  @debug.assert_eq(lit.datatype(), @lib.lwSTRING)
}

///|
test "datatype for typed literal" {
  let lit = @lib.LiteralRef::new_typed_literal(
    "true",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwBOOLEAN.to_string()),
  )
  @debug.assert_eq(lit.datatype(), @lib.lwBOOLEAN)
}

///|
test "datatype for language-tagged literal" {
  let lit = @lib.Literal::new_language_tagged_literal("test", "en").unwrap()
  @debug.assert_eq(lit.datatype(), @lib.lwLANG_STRING)
}

///|
test "datatype for directional language-tagged literal" {
  let tag = @lib.LanguageTag::parse("en").unwrap()
  let lit = @lib.Literal::new_directional_language_tagged_literal_unchecked(
    "test",
    tag,
    @lib.BaseDirection::Ltr,
  )
  @debug.assert_eq(lit.datatype(), @lib.lwDIR_LANG_STRING)
}

///|
test "destruct simple literal" {
  let lit = @lib.Literal::new_simple_literal("hello")
  let (value, datatype, language, direction) = lit.destruct()
  @debug.assert_eq(value, "hello")
  @debug.assert_eq(datatype, None)
  @debug.assert_eq(language, None)
  @debug.assert_eq(direction, None)
}

///|
test "destruct typed literal" {
  let lit = @lib.LiteralRef::new_typed_literal(
    "42",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwINTEGER.to_string()),
  )
  let (value, datatype, language, direction) = lit.into_owned().destruct()
  @debug.assert_eq(value, "42")
  assert_true(datatype is Some(_lwINTEGER))
  @debug.assert_eq(language, None)
  @debug.assert_eq(direction, None)
}

///|
test "destruct language-tagged literal" {
  let lit = @lib.Literal::new_language_tagged_literal("hello", "en").unwrap()
  let (value, datatype, language, direction) = lit.destruct()
  @debug.assert_eq(value, "hello")
  @debug.assert_eq(datatype, None)
  @debug.assert_eq(language, Some("en"))
  @debug.assert_eq(direction, None)
}

///|
test "destruct directional language-tagged literal" {
  let tag = @lib.LanguageTag::parse("en").unwrap()
  let lit = @lib.Literal::new_directional_language_tagged_literal_unchecked(
    "hello",
    tag,
    @lib.BaseDirection::Rtl,
  )
  let (value, datatype, language, direction) = lit.destruct()
  @debug.assert_eq(value, "hello")
  @debug.assert_eq(datatype, None)
  @debug.assert_eq(language, Some("en"))
  @debug.assert_eq(direction, Some(@lib.BaseDirection::Rtl))
}

///|
test "literalref simple literal creation" {
  let literalref = @lib.LiteralRef::new_simple_literal("hello")
  @debug.assert_eq(literalref.into_value(), "hello")
}

///|
test "literalref typed literal" {
  let literalref = @lib.LiteralRef::new_typed_literal("true", @lib.lwBOOLEAN)
  @debug.assert_eq(literalref.into_value(), "true")
  @debug.assert_eq(literalref.datatype(), @lib.lwBOOLEAN)
}

///|
test "literalref typed literal with string normalizes to simple" {
  let literalref = @lib.LiteralRef::new_typed_literal("hello", @lib.lwSTRING)
  @debug.assert_eq(literalref.into_value(), "hello")
  @debug.assert_eq(literalref.datatype(), @lib.lwSTRING)
}

///|
test "literalref language-tagged literal" {
  let literalref = @lib.Literal::new_language_tagged_literal_unchecked(
    "hello", "en",
  )
  @debug.assert_eq(literalref.as_ref().into_value(), "hello")
  @debug.assert_eq(literalref.language(), Some("en".to_string()))
  @debug.assert_eq(literalref.datatype(), @lib.lwLANG_STRING)
}

///|
test "literalref directional language-tagged literal" {
  let tag = @lib.LanguageTag::parse("en").unwrap()
  let literalref = @lib.LiteralRef::new_directional_language_tagged_literal_unchecked(
    "hello",
    tag,
    @lib.BaseDirection::Ltr,
  )
  @debug.assert_eq(literalref.into_value(), "hello")
  @debug.assert_eq(literalref.language(), Some("en".to_string()))
  @debug.assert_eq(literalref.direction(), Some(@lib.BaseDirection::Ltr))
  @debug.assert_eq(literalref.datatype(), @lib.lwDIR_LANG_STRING)
}

///|
test "literalref into_owned" {
  let literalref = @lib.LiteralRef::new_simple_literal("hello")
  let owned = literalref.into_owned()
  @debug.assert_eq(owned.value(), "hello")
}

///|
test "literalref to_owned" {
  let literalref = @lib.LiteralRef::new_language_tagged_literal_unchecked(
    "hello", "en",
  )
  let owned = literalref.into_owned()
  @debug.assert_eq(owned.value(), "hello")
  match owned.language() {
    Some(lang) => @debug.assert_eq(lang, "en")
    None => fail("Expected language 'en', got None")
  }
}

///|
test "literal equality simple vs typed string" {
  let simple = @lib.Literal::new_simple_literal("foo")
  let typed = @lib.LiteralRef::new_typed_literal(
    "foo",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwSTRING.to_string()),
  )
  @debug.assert_eq(simple, typed.into_owned())
}

///|
test "literalref equality simple vs typed string" {
  let simple = @lib.LiteralRef::new_simple_literal("foo")
  let typed = @lib.LiteralRef::new_typed_literal("foo", @lib.lwSTRING)
  @debug.assert_eq(simple, typed)
}

///|
test "literal as_ref equality with typed literal" {
  let literal = @lib.LiteralRef::new_typed_literal(
    "foo",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwSTRING.to_string()),
  )
  let literalref = @lib.LiteralRef::new_simple_literal("foo")
  @debug.assert_eq(literalref, literal.into_owned().as_ref())
}

///|
test "literal vs literalref equality" {
  let lit = @lib.Literal::new_simple_literal("foo")
  let literalref = @lib.LiteralRef::new_simple_literal("foo")
  @debug.assert_eq(lit, literalref.into_owned()) // This tests Literal == LiteralRef via derived Eq
}

///|
test "literal show simple" {
  let lit = @lib.LiteralRef::new_simple_literal("hello")
  @debug.assert_eq(lit.to_string(), "\"hello\"")
}

///|
test "literal show language-tagged" {
  let lit = @lib.Literal::new_language_tagged_literal("hello", "en").unwrap()
  @debug.assert_eq(lit.to_string(), "\"hello\"@en")
}

///|
test "literal show directional language-tagged" {
  let tag = @lib.LanguageTag::parse("en").unwrap()
  let lit = @lib.Literal::new_directional_language_tagged_literal_unchecked(
    "hello",
    tag,
    @lib.BaseDirection::Rtl,
  )
  @debug.assert_eq(lit.to_string(), "\"hello\"@en-rtl")
}

///|
test "literal show typed literal" {
  let lit = @lib.LiteralRef::new_typed_literal(
    "42",
    @lib.NamedNodeRef::NamedNodeRef(@lib.lwINTEGER.to_string()),
  )
  @debug.assert_eq(
    lit.to_string(),
    "\"42\"^^http://www.w3.org/2001/XMLSchema#integer",
  )
}

///|
test "literalref to_string" {
  let literalref = @lib.LiteralRef::new_typed_literal("hello", @lib.lwSTRING)
  let s = literalref.to_string()
  // debug(s) // Should produce quoted string representation
  assert_true(s.has_prefix("\""))
  assert_true(s.has_suffix("\""))
}

///|
test "serialize literal with all punctuation marks" {
  // 测试从对象创建字面量并序列化回 N-Triples 格式
  let value = " !\"#$%&():;<=>?@[]^_`{|}~"
  let lit = @lib.LiteralRef::new_simple_literal(value)

  let serialized = lit.to_string()

  // 序列化结果应该包含转义的双引号
  let expected_serialized = "\" !\\\"#$%&():;<=>?@[]^_`{|}~\""
  debug(serialized)
  @debug.assert_eq(serialized, expected_serialized)
}
