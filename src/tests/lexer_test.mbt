///|
async test "debug_lexer_only" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  debug("=== Lexer Output ===")
  let mut count = 0
  for ;; {
    match lexer.parse_next(None) {
      Some(Ok(token)) => {
        count += 1
        debug("[\{count}] {token}")

        // 检查具体的 token 内容
        match token {
          @lib.LocatedTokenOrLineJump::LocatedN3Token(located) => {
            debug("    -> type: \{located.to_string()}")
            debug("    -> range: \{located.1.start}-\{located.1.end}")
          }
          @lib.LocatedTokenOrLineJump::LineJump(pos) =>
            debug("    -> LineJump at \{pos}")
          @lib.LocatedTokenOrLineJump::End => {
            debug("    -> End")
            break
          }
        }
      }
      Some(Err(e)) => {
        debug("Lexer Error: \{e}")
        break
      }
      None => {
        debug("No more tokens")
        break
      }
    }
  }

  debug("Total tokens: \{count}")
}


///|
async test "Lexer tokenization test" {
  let input =
    #| "<http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .\n"
  let data = @utf8.encode(input).to_array()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
    data,
    true, // is_ending
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  debug("=== Lexer Tokenization Test ===")
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match lexer.parse_next(None) {
      Some(Ok(token)) => {
        count += 1
        debug("Token \{count}: \{token}")
      }
      Some(Err(e)) => {
        count += 1
        debug("Error \{count}: \{e}")
        break
      }
      None => {
        debug("End of tokens")
        break
      }
    }
  }
}

///|
async test "Parser multi-line test" {
  let input =
    #| <http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .
    #|  <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
    #|  <http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .

  let data = @utf8.encode(input).to_array()

  let logger = @lib.make_console_logger()
  let parser = @lib.NQuadsRecognizer::new_parser(
    data,
    false,
    false,
    debug_logger=logger,
  )

  debug("=== Parser Multi-Line Test ===")
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
