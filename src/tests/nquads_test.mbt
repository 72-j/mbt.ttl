///|
test "parse basic quad" {
  let parser = @lib.NQuadsParser::new()
  let low_level = parser.low_level()

  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  low_level.extend_from_slice(@utf8.encode(input))
  low_level.end()

  let result = low_level.parse_next()
  assert_true(result is Some(_))
  match result.unwrap() {
    Ok(quad) => {
      debug(quad)

      assert_true(true)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parser lenient mode" {
  let parser_strict = @lib.NQuadsParser::new()
  @debug.assert_eq(parser_strict.lenient, false)

  let parser_lenient = @lib.NQuadsParser::new().lenient()
  @debug.assert_eq(parser_lenient.lenient, true)
}

///|
test "low level parser initialization" {
  let parser = @lib.NQuadsParser::new()
  let low_level = parser.low_level()

  assert_false(low_level.is_end())

  let data = @utf8.encode(
    "<http://example.org/s> <http://example.org/p> <http://example.org/o> .",
  )
  low_level.extend_from_slice(data)

  low_level.end()
}
