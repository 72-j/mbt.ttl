///|
async test "debug_trig_subj_only" {
  let input = "<http://a/b>"
  let data = @utf8.encode(input).to_array()
  let data_world = @lib.DataWorld::default()

  let prefixes = Map([])
  let base_iri = None

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    false,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next(data_world) {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_trig_complete_triple" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()
  let data_world = @lib.DataWorld::default()
  debug("Input length: \{input.length()}")
  let prefixes = Map([])
  let base_iri = None

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    false,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next(data_world) {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_trig_complete_triple_newline" {
  let input = "<http://a/b> <http://a/c> <http://a/d> .\n"
  let data_world = @lib.DataWorld::default()
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = None

  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    false,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  match parser.parse_next(data_world) {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_lexer_tokens" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()
  let data_world = @lib.DataWorld::default()

  debug("Input: \{input}")

  let prefixes = Map([])
  let base_iri = None
  let parser = @lib.TriGRecognizer::new_parser(
    data,
    true,
    false,
    false,
    base_iri,
    prefixes,
    debug_logger=@lib.make_console_logger(),
  )

  for ;; {
    match parser.parse_next(data_world) {
      Some(Ok(t)) => {
        debug("Parsed: \{t}")
        break
      }
      Some(Err(e)) => {
        debug("Error: \{e}")
        break
      }
      None => {
        debug("None")
        break
      }
    }
  }
}

///|
// async test "Parser_basic_single_line for TriG 1" {
//   let input =
//     #|<http://example.org/books> {
//     #|<http://example.org/book1> dc:title "The Great Gatsby"@en .
//     #|<http://example.org/book2> dc:title "1984"@en .
//     #|}

//   let data = @utf8.encode(input).to_array()
// let data_world=@lib.DataWorld::default()

//   let lexer = @lib.Lexer::Lexer(
//     @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::N3, false),
//     data,
//     true,
//     @lib.MIN_BUFFER_SIZE,
//     @lib.MAX_BUFFER_SIZE,
//     Some(b"#"),
//     0,
//     0,
//   )

//   let logger = @lib.make_console_logger()

//   let machine = @lib.TriGRecognizer::{
//     stack: [@lib.TriGState::TriGDoc],
//     cur_subject: [],
//     cur_predicate: [],
//     cur_object: [],
//     cur_graph: @lib.GraphName::DefaultGraph.as_ref(),
//     cur_reifier: [],
//     lenient: true,
//     debug_logger: logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
//     // in_collection: false,
//     last_range: @lib.Range::default(),
//     errors: [],
//   }

//   let context = @lib.RdfContext::TriGRecognizerContext(@lib.TriGRecognizerContext::{
//     with_graph_name: true,
//     lexer_options: { base_iri: None },
//     prefixes: Map([]),
//   })

//   let generic_machine = @lib.GenericStateMachine::{
//     machine,
//     context,
//     outputs: [],
//     debug_logger: logger,
//   }
//   let parser = @lib.Parser::{
//     lexer,
//     engine: generic_machine,
//     context,
//     errors: [],
//   }

//   debug("=== Single Line Test ===")
//   let turtles = []
//   let mut count = 0

//   for ;; {
//     if count >= 20 {
//       break
//     }
//     match parser.parse_next(data_world) {
//       Some(Ok(turtle)) => {
//         count += 1
//         debug("[\{count}] \{turtle}")
//         turtles.push(turtle)
//       }
//       Some(Err(e)) => {
//         count += 1
//         debug("[\{count}] \{e}")
//         break
//       }
//       None => {
//         debug("End")
//         break
//       }
//     }
//   }

//   debug("Total: \{turtles.length()}")
//   @debug.assert_eq(turtles.length(), 1)
// }

///|
async test "Parser_basic_single_line for TriG 2" {
  // "<http://example/graph> {<http://a.example/s> a <http://a.example/o> .}"
  let input =
    #|@prefix dc: <http://purl.org/dc/terms/> .
    #|@prefix ex: <http://example.org/> .
    #|<http://example.org/book1> dc:title "The Great Gatsby"@en ;
    #|dc:creator "F. Scott Fitzgerald" .
    #|<http://example.org/books> {
    #|<http://example.org/book1> dc:title "The Great Gatsby"@en .
    #|<http://example.org/book2> dc:title "1984"@en .
    #|}

  let data = @utf8.encode(input).to_array()
  let data_world = @lib.DataWorld::default()

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

  debug("=== Single Line Test ===")
  let turtles = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next(data_world) {
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
  for i, t in turtles {
    debug("  [\{i}] \{t}")
  }
}

///|
async test "Parser_basic_single_line for TriG 3" {
  let input =
    #|{<http://example/s> <http://example/p> """abc""def''ghi""" .}  

  let data = @utf8.encode(input).to_array()
  let data_world = @lib.DataWorld::default()

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

  debug("=== Single Line Test ===")
  let turtles = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next(data_world) {
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
  for i, t in turtles {
    debug("  [\{i}] \{t}")
  }
}

///|
// async test "test_triple" {

//   // let input = "{<http://example/s> <http://example/p> \"\"\"abc\"\"def''ghi\"\"\" .}"
//   let input =
//     #|@prefix : <http://example/> .
//     #|{:s :p :o .}
//   // #| {:s :p :%20 .}
//   // #|{:s :p """abc""""@en .}

//   let data = @utf8.encode(input).to_array()
// let data_world=@lib.DataWorld::default()

//   debug("Input: \{input}")

//   let lexer = @lib.Lexer::Lexer(
//     @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::N3, false),
//     data,
//     true,
//     @lib.MIN_BUFFER_SIZE,
//     @lib.MAX_BUFFER_SIZE,
//     Some(b"#"),
//     0,
//     0,
//   )

//   let logger = @lib.make_console_logger()

//   let machine = @lib.TriGRecognizer::{
//     current_state: @lib.TriGState::TriGDoc,
//     stack: [@lib.TriGState::TriGDoc],
//     cur_subject: [],
//     cur_predicate: [],
//     cur_object: [],
//     cur_graph: @lib.GraphName::DefaultGraph.as_ref(),
//     cur_reifier: [],
//     lenient: true,
//     debug_logger: logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
//     // in_collection: false,
//     last_range: @lib.Range::default(),
//     errors: [],
//   }

//   let context = @lib.RdfContext::TriGRecognizerContext(@lib.TriGRecognizerContext::{
//     with_graph_name: true,
//     lexer_options: { base_iri: None },
//     prefixes: Map([]),
//   })

//   let generic_machine = @lib.GenericStateMachine::{
//     machine,
//     context,
//     outputs: [],
//     debug_logger: logger,
//   }
//   let parser = @lib.Parser::{
//     lexer,
//     engine: generic_machine,
//     context,
//     errors: [],
//   }

//   debug("=== Single Line Test ===")
//   let turtles = []
//   let mut count = 0

//   for ;; {
//     if count >= 20 {
//       break
//     }
//     match parser.parse_next(data_world) {
//       Some(Ok(turtle)) => {
//         count += 1
//         debug("[\{count}] \{turtle}")
//         turtles.push(turtle)
//       }
//       Some(Err(e)) => {
//         count += 1
//         debug("[\{count}] \{e}")
//         break
//       }
//       None => {
//         debug("End")
//         break
//       }
//     }
//   }

//   debug("Total: \{turtles.length()}")
//   for i, t in turtles {
//     debug("  [\{i}] \{t}")
//   }
// }
