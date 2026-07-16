///|
/// Parse N-Quads file example
/// 
/// This example demonstrates how to parse N-Quads format RDF data from a file.
/// N-Quads is a line-based format for RDF triples/quads.
async fn main {
  // Create a task group for cleanup
  @async.with_task_group() <| root => {
    let path = "./example.nq"
    root.add_defer(() => @fs.remove(path))

    // Sample N-Quads content
    let content =
      #| <http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .
      #| <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
      #| <http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .

    // Write content to file
    @fs.write_file(path, content, create_mode=CreateOrTruncate)
    println("Written N-Quads content to: \{path}")

    // Read file content as binary
    let data = @fs.read_file(path).binary()
    let data_world = @lib.DataWorld::default()

    // Create lexer for N-Triples mode
    let lexer = @lib.Lexer::Lexer(
      @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
      data.to_array(),
      true, // resize enabled
      @lib.MIN_BUFFER_SIZE,
      @lib.MAX_BUFFER_SIZE,
      Some(b"#"), // comment character
      0, // initial line
      0, // initial column
    )

    // Create NQuads recognizer state machine
    let logger = @lib.make_mute_logger()

    let machine = @lib.NQuadsRecognizer::{
      current_state: @lib.NQuadsState::ExpectSubject,
      stack: [@lib.NQuadsState::ExpectSubject],
      subjects: [],
      predicates: [],
      objects: [],
      lenient: false,
      debug_logger: logger,
      last_range: @lib.Range::default(),
      errors: [],
    }

    // Context configuration
    let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
      with_graph_name: false, // N-Quads without graph names
      lexer_options: { base_iri: None },
    })

    // Wrap in generic state machine
    let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
      machine,
      context,
      debug_logger=logger,
    )

    // Create parser
    let parser = @lib.Parser::{
      lexer,
      engine: generic_machine,
      context,
      errors: [],
    }

    parser.end()
    // Parse all quads
    println("Parsing N-Quads file...")
    let quads = []
    let mut count = 0

    for ;; {
      if count >= 100 {
        break
      } // Safety limit
      match parser.parse_next(data_world) {
        Some(Err(e)) => {
          count += 1
          println("[\{count}] Error: \{e}")
          break
        }
        Some(Ok(quad)) => {
          count += 1
          println("[\{count}] \{quad}")
          quads.push(quad)
        }
        None => {
          println("End of file")
          break
        }
      }
    }

    // Print summary
    println("")
    println("=== Summary ===")
    println("Total quads parsed: \{quads.length()}")
  }
}
