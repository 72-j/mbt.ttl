///|
async test "multi-line NQuads from file" {
  @async.with_task_group() <| root => {
    let path = "_build/nquads_multi_test.nq"
    root.add_defer(() => @fs.remove(path))

    let content =
      #| <http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .
      #| <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
      #| <http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .

    @fs.write_file(path, content, create_mode=CreateOrTruncate)

    let data = @fs.read_file(path).binary()

    let lexer = @lib.Lexer::Lexer(
      @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
      data.to_array(),
      true,
      @lib.MIN_BUFFER_SIZE,
      @lib.MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    )

    let logger = @lib.make_console_logger()

    let machine = @lib.NQuadsRecognizer::{
      stack: [@lib.NQuadsState::ExpectSubject],
      subjects: [],
      predicates: [],
      objects: [],
      lenient: false,
      debug_logger: logger,
      last_range: @lib.Range::default(),
      errors: [],
    }

    let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
      with_graph_name: false,
      lexer_options: { base_iri: None },
    })

    let generic_machine = @lib.GenericStateMachine::{
      machine,
      context,
      outputs: [],
      debug_logger: logger,
    }

    let parser = @lib.ParserM::{
      lexer,
      engine: generic_machine,
      context,
      errors: [],
    }

    debug("=== Multi-Line Test ===")
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
}

///|
async test "single quad from file" {
  @async.with_task_group() <| root => {
    let path = "_build/nquads_single_test.nq"
    root.add_defer(() => @fs.remove(path))

    let content = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"

    @fs.write_file(path, content, create_mode=CreateOrTruncate)

    let data = @fs.read_file(path).binary()

    let lexer = @lib.Lexer::Lexer(
      @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
      data.to_array(),
      true,
      @lib.MIN_BUFFER_SIZE,
      @lib.MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    )

    let logger = @lib.make_console_logger()

    let machine = @lib.NQuadsRecognizer::{
      stack: [@lib.NQuadsState::ExpectSubject],
      subjects: [],
      predicates: [],
      objects: [],
      lenient: false,
      debug_logger: logger,
      last_range: @lib.Range::default(),
      errors: [],
    }

    let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
      with_graph_name: false,
      lexer_options: { base_iri: None },
    })

    let generic_machine = @lib.GenericStateMachine::{
      machine,
      context,
      outputs: [],
      debug_logger: logger,
    }

    let parser = @lib.ParserM::{
      lexer,
      engine: generic_machine,
      context,
      errors: [],
    }

    let quads = []
    let mut count = 0

    for ;; {
      if count >= 20 {
        break
      }
      match parser.parse_next() {
        Some(Ok(quad)) => {
          count += 1
          quads.push(quad)
        }
        Some(Err(e)) => {
          debug("Error: \{e}")
          break
        }
        None => break
      }
    }

    @debug.assert_eq(quads.length(), 1)
  }
}
