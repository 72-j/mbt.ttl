///|
async test "ParserM_basic_single_line for NQuads" {
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
  }
  let parser = @lib.ParserM::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

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

///|
async test "multi-line  for NQuads" {
  let input =
    #| <http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #| <http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #| <http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #| 

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
  }
  let parser = @lib.ParserM::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

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
  @debug.assert_eq(quads.length(), 3)
}
