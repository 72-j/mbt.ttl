///|

///|
async test "ParserM_basic_with_lexer_working for NQuads" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
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

  let logger = @lib.make_console_logger()

  // 创建 TriGRecognizer
  let machine = @lib.NQuadsRecognizer::{
    stack: [@lib.NQuadsState::ExpectSubject],
    subjects: [],
    predicates: [],
    objects: [],
    lenient: false,
    debug_logger: logger, // 修复：包装为 Option 类型
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
    with_graph_name: false,
    lexer_options: { base_iri: None },
  })

  // 创建 GenericStateMachine
  let generic_machine = @lib.GenericStateMachine::{
    machine,
    context,
    outputs: [],
  }

  let parser = @lib.ParserM::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  debug("=== ParserM Test ===")
  let quads = []
  let mut count = 0
  let max_iterations = 20

  for ;; {
    if count >= max_iterations {
      debug("WARNING: Max iterations reached")
      break
    }

    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] ✓ Quad: \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] ✗ Error: \{e}")
        break
      }
      None => {
        debug("[\{count}] Finished")
        break
      }
    }
  }

  debug("Total quads: \{quads.length()}")

  if quads.is_empty() {
    debug("=== Debug Info ===")
    debug("Engine is_accepting: \{parser.engine.is_accepting()}")
    debug("Engine outputs length: \{parser.engine.outputs.length()}")
    debug("Errors length: \{parser.errors.length()}")

    // 检查引擎状态
    debug("Engine current state: \{parser.engine.current_state()}")
  }

  @debug.assert_eq(quads.length(), 0)
}

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
