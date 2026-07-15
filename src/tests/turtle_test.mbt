///|
async test "debug_simple_turtle_1" {
  let input = "<http://a.example/s>"
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}

///|
async test "debug_simple_turtle_2" {
  let input = "<http://a.example/s> <http://a.example/p> <p> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}

///|
async test "debug_simple_turtle_workaround" {
  let input = "<http://a.example/s> <http://a.example/p> 1 ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}

///|
async test "debug_simple_turtle_fixed_input" {
  let input = "<http://a.example/s> <http://a.example/p> <http://a.example/o> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}

///|
async test "debug_simple_turtle" {
  let input =
    #| <http://a.example/s> <http://a.example/p> (1) .

  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    true,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}

///|
async test "debug_simple_triple" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  let data = @utf8.encode(input)

  let parser = @lib.TurtleParser::new().lenient()

  let low_level = parser.low_level()

  low_level.extend_from_slice(data)
  low_level.end()

  let result = low_level.parse_next()

  match result {
    Some(Ok(triple)) => debug("Success! Parsed Quad: \{triple.to_string()}")
    Some(Err(e)) => debug("Parse Error: \{e.to_string()}")
    None => debug("Parse returned None (No output)")
  }
}

///|
async test "debug_simple_triple 2" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = None

  let parser = @lib.TriGRecognizer::new_parser(
    data, true, false, false, base_iri, prefixes,
  )

  let mut step = 0
  for ;; {
    step += 1
    debug("\n=== Step \{step} ===")

    // match parser.state {
    //   Some(state) => {
    //     debug("State stack depth: \{state.stack.length()}")
    //     debug("Current object: \{@debug.to_string(state.cur_object)}")
    //   }
    //   None => debug("No active state")
    // }

    match parser.parse_next() {
      Some(Ok(t)) => debug("✓ Parsed quad: \{t.to_string()}")
      Some(Err(e)) => {
        debug("Error: \{e.to_string()}")
        break
      }
      None => {
        debug("Need more input or end of file")
        break
      }
    }
  }
}

///|
async test "verify_with_turtle" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  let data = @utf8.encode(input)

  let parser = @lib.TurtleParser::new().lenient()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)
  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("Turtle Success:\{t.to_string()} ")
    Some(Err(e)) => debug("Turtle Error: \{e.to_string()}")
    None => debug("Turtle None")
  }
}

///|
async test "debug_minimal_turtle" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input)

  debug("Input bytes length: \{data.length()}")
  debug("Input string: \{input}")

  let parser = @lib.TurtleParser::new()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)

  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None: Parser needs more input or finished silently")
  }
}

///|
async test "debug_minimal_turtle_with_newline" {
  let input = "<http://a/b> <http://a/c> <http://a/d> .\n"
  let data = @utf8.encode(input)

  debug("Input bytes length: \{data.length()}")
  debug("Input string: \{input}")

  let parser = @lib.TurtleParser::new()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)

  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None: Parser needs more input or finished silently")
  }
}

///|
async test "debug_no_dot" {
  let input = "<http://a/b> <http://a/c> <http://a/d>"
  let data = @utf8.encode(input)

  let parser = @lib.TurtleParser::new()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)
  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("✓ Success (Unexpected): \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error (Expected): \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_subj_pred_only" {
  let input = "<http://a/b> <http://a/c>"
  let data = @utf8.encode(input)

  let parser = @lib.TurtleParser::new()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)
  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("✓ Success (Unexpected): \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_subj_only" {
  let input = "<http://a/b>"
  let data = @utf8.encode(input)

  let parser = @lib.TurtleParser::new()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)
  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("✓ Success (Unexpected): \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "Parser_basic_single_line for Turtle" {
  let input =
    #|<http://example/s> <http://example/p> <http://example/o> .

  let data = @utf8.encode(input).to_array()

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

  let machine = @lib.TriGRecognizer::{
    current_state: @lib.TriGState::TriGDoc,
    stack: [@lib.TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: @lib.GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: true,
    debug_logger: logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
    // in_collection: false,
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::TriGRecognizerContext(@lib.TriGRecognizerContext::{
    with_graph_name: false,
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
  parser.end()

  debug("=== Single Line Test ===")
  let turtles = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next() {
      Some(Ok(turtle)) => {
        count += 1
        debug("[\{count}] \{turtle}")
        turtles.push(turtle)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total: \{turtles.length()}")
  @debug.assert_eq(turtles.length(), 1)
}

///|
async test "Parser Turtle" {
  let input =
    #|@prefix ex: <http://example.org/> .
    #|@prefix foaf: <http://xmlns.com/foaf/0.1/> .
    #|@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    #|
    #|ex:Alice
    #|    foaf:name "Alice" ;
    #|    foaf:mbox <mailto:alice@example.org> ;
    #|    foaf:age "30"^^xsd:integer ;
    #|    ex:department "Engineering" ;
    #|    ex:hireDate "2020-03-15"^^xsd:date .
    #|    
  let data = @utf8.encode(input).to_array()

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

  let machine = @lib.TriGRecognizer::{
    current_state: @lib.TriGState::TriGDoc,
    stack: [@lib.TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: @lib.GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: true,
    debug_logger: logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
    // in_collection: false,
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::TriGRecognizerContext(@lib.TriGRecognizerContext::{
    with_graph_name: false,
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
  parser.end()

  debug("=== Single Line Test ===")
  let turtles = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next() {
      Some(Ok(turtle)) => {
        count += 1
        debug("[\{count}] \{turtle}")
        turtles.push(turtle)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total: \{turtles.length()}")
  @debug.assert_eq(turtles.length(), 5)
    for i, t in turtles {
    debug("  [\{i}] \{t}")
  }
}

///|
async test "Parser Turtle Test" {
  let input =
    #|@prefix ex: <http://example.org/> .
    #|@prefix foaf: <http://xmlns.com/foaf/0.1/> .
    #|@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    #|
    #|ex:Alice
    #|    foaf:name "Alice" ;
    #|    foaf:mbox <mailto:alice@example.org> ;
    #|    foaf:age "30"^^xsd:integer ;
    #|    ex:department "Engineering" ;
    #|    ex:hireDate "2020-03-15"^^xsd:date .
    #|    
  let data = @utf8.encode(input)

  let parser = @lib.TurtleParser::new()
  let low_level = parser.low_level(debug=true)

  low_level.extend_from_slice(data)
  low_level.end()

  let turtles = []
  for ;; {
    match low_level.parse_next() {
      Some(Ok(t)) => turtles.push(t)
      Some(Err(e)) => {
        debug("✗ Error: \{e}")
        break
      }
      None => break
    }
  }

  debug("=== Parser Turtle Test ===")
  debug("Parsed \{turtles.length()} triples:")
  for i, t in turtles {
    debug("  [\{i}] \{t}")
  }
}
