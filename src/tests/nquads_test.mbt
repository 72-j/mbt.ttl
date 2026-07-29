///|
test "parse simple IRI" {
  let input =
    #| "\u0000\u0002\u0003\u0004" .
  // #| .
  // #|"299.00"^^<http://www.w3.org/2001/XMLSchema#decimal>
  // #|"A . b" 
  // #| <http://example/\u0053> 
  // #|"2024-06-01T12:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
  // #| 'a 
  // #|abc" .
  // #|'abc' .
  // #| "a v"
  // #| """ dc ''' d'''asd""" 
  debug("Input: \{input}")

  let data = @utf8.encode(input).to_array()
  // for i in 0..<data.length() {
  //   let b = data[i]
  //   let cc = @lib.classify_byte(b)
  //   debug("  [\{i}] '\{b.to_int().unsafe_to_char()}' -> \{cc}")
  // }
  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(
      @lib.RdfLexerMode::NTriples,
      false,
      [],
      debug_logger=@lib.make_console_logger(),
    ),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let result = lexer.parse_next(None)
  debug("Result: \{@debug.to_string(result)}")
}

///|
test "full parse with string" {
  let input =
    #|<http://example.org/s> <http://example.org/p> <http://example.org/o>  <http://example.org/g> .
  let data = @utf8.encode(input).to_array()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(
      @lib.RdfLexerMode::NTriples,
      false,
      [],
      debug_logger=@lib.make_console_logger(),
    ),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )
  // Token 1: String
  let r1 = lexer.parse_next(None)
  debug("Token 1: \{@debug.to_string(r1)}")

  // Token 2: Space (可能被跳过)

  // Token 3: .
  let r2 = lexer.parse_next(None)
  debug("Token 2: \{@debug.to_string(r2)}")
  let r3 = lexer.parse_next(None)
  debug("Token 3: \{@debug.to_string(r3)}")
  let r4 = lexer.parse_next(None)
  debug("Token 4: \{@debug.to_string(r4)}")
  let r5 = lexer.parse_next(None)
  debug("Token 5: \{@debug.to_string(r5)}")
  let r6 = lexer.parse_next(None)
  debug("Token 6: \{@debug.to_string(r6)}")
}

///|
test "parse IRI full" {
  let input =
    #|"""a """  .
  let data = @utf8.encode(input).to_array()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false, []),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let result = lexer.parse_next(None)
  debug("Result: \{@debug.to_string(result)}")

  match result {
    Some(Ok(token)) => debug("Token: \{token}")
    _ => ()
  }
}

///|
test "parse basic quad" {
  let parser = @lib.NQuadsParser::new()
  let low_level = parser.low_level()

  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  // let input = 
  // #| <http://example/s> <http://example/p> "abc' .

  low_level.extend_from_slice(@utf8.encode(input).to_array())
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
  low_level.extend_from_slice(data.to_array())

  low_level.end()
}

///|
async test "Parser_basic_single_line for NQuads" {
  let input =
    #| <http://example/s> <http://example/p> _:o . # comment
    #| <http://example.org/s> <http://example.org/p> '''"Hello\u0020World"''' .
    #| <http://example/s> <http://example/p> "o"^^<http://example/dt> . # comment
    #|<http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #|<http://example.org/s> <http://example.org/p> <http://example.org/o>  <http://example.org/g> .
    #|<http://example.org/s> <http://example.org/p> "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\t\u000B\u000C\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\u001B\u001C\u001D\u001E\u001F" .
    #|
  let data = @utf8.encode(input).to_array()
  // debug("Input bytes: \{@debug.to_string(data)}")

  let logger = @lib.make_console_logger()

  let parser = @lib.NQuadsRecognizer::new_parser(
    data,
    false,
    false,
    debug_logger=logger,
  )

  debug("=== Single Line Test ===")
  debug("data: \{input}")
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
  for i, t in quads {
    debug("  [\{i}] \{t}")
  }
}

///|
async test "Parser_multi_line for NQuads" {
  let input =
    #| <http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .
    #| <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
    #| <http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .
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
  @debug.assert_eq(quads.length(), 3)
}
