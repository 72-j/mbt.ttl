///|
async test "debug_n3_implies" {
  let input = "{ <http://example.org/s> <http://example.org/p> <http://example.org/o> } => { <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> } ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.N3Recognizer::new_parser(
    data,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Implies Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Implies Error: \{e.to_string()}")
    None => debug("N3 Implies None")
  }
}

///|
async test "debug_n3_forall" {
  let input = "@forAll <http://example.org/x> . <http://example.org/s> <http://example.org/p> <http://example.org/x> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.N3Recognizer::new_parser(
    data,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 ForAll Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 ForAll Error: \{e.to_string()}")
    None => debug("N3 ForAll None")
  }
}

///|
async test "debug_n3_path_alternative" {
  let input = "<http://example.org/s> (<http://example.org/p1>|<http://example.org/p2>) <http://example.org/o> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.N3Recognizer::new_parser(
    data,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Path Alt Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Path Alt Error: \{e.to_string()}")
    None => debug("N3 Path Alt None")
  }
}

///|
async test "debug_n3_literal_complex" {
  let input =
    #|<http://example.org/s> <http://example.org/p> "Simple String"@en-us .
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.N3Recognizer::new_parser(
    data,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Literal Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Literal Error: \{e.to_string()}")
    None => debug("N3 Literal None")
  }
}

///|
async test "debug_n3_nested_formula" {
  let input = "<http://example.org/s> <http://example.org/p> { <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> } ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.N3Recognizer::new_parser(
    data,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Nested Formula Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Nested Formula Error: \{e.to_string()}")
    None => debug("N3 Nested Formula None")
  }
}

///|
async test "n3 test for Parser" {
  let input = ":Alice :knows :Bob ."
  let data = @utf8.encode(input).to_array()

  // let prefixes = Map([])
  // let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::N3, false),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = @lib.make_console_logger()
  let machine = @lib.N3Recognizer::{
    stack: [@lib.N3State::N3Doc],
    terms: [],
    predicates: [],
    contexts: [],
    debug_logger: logger, 
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::TriGRecognizerContext(@lib.TriGRecognizerContext::{
    with_graph_name: true,
    lexer_options: { base_iri: None },
    prefixes: Map([]),
  })

  let generic_machine = @lib.GenericStateMachine::{
    machine,
    context,
    outputs: [],
    debug_logger: logger,
  }
  let parser = @lib.Parser::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Nested Formula Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Nested Formula Error: \{e.to_string()}")
    None => debug("N3 Nested Formula None")
  }
}
