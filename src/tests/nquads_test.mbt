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

///|
async test "ParserM_basic_single_line for NQuads" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  let data = @utf8.encode(input).to_array()

  let logger = @lib.make_console_logger()

  let parser = @lib.NQuadsRecognizer::new_parser(
    data,
    false,
    false,
    debug_logger=logger,
  )

  debug("=== Single Line Test ===")
  let quads = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] ✓ \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] ✗ \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total: \{quads.length()}")
  @debug.assert_eq(quads.length(), 1)
}


async test "ParserM_multi_line for NQuads" {
    let input =
    #| "<http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .\n"
    #| "<http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .\n"
    #| "<http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .\n"
    let data = @utf8.encode(input).to_array()

    let logger = @lib.make_console_logger()
    let parser = @lib.NQuadsRecognizer::new_parser(
      data,
      false,
      false,
      debug_logger=logger,
    )

    debug("=== Multi Line Test ===")
    let quads = []
    let mut count = 0

    for ;; {
      if count >= 20 { break }
      match parser.parse_next() {
        Some(Ok(quad)) => {
          count += 1
          debug("[\{count}] ✓ \{quad}")
          quads.push(quad)
        }
        Some(Err(e)) => {
          count += 1
          debug("[\{count}] ✗ \{e}")
          break
        }
        None => { debug("End"); break }
      }
    }

    debug("Total: \{quads.length()}")
    @debug.assert_eq(quads.length(), 3)
  }
