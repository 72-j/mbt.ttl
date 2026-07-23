///|
async fn main {
  cmd_parser()
}

///|
async fn cmd_parser() -> Unit {
  let cmd = @argparse.Command(
    "moonttl",
    about="A RDF parser CLI for N-Quads format",
    flags=[
      FlagArg(
        "verbose",
        short='v',
        long="verbose",
        about="Enable verbose output",
      ),
    ],
    options=[
      OptionArg("file", short='f', long="file", about="Input N-Quads file path"),
    ],
    positionals=[
      PositionArg("input", about="Input N-Quads string (use -f for file)"),
    ],
  )

  let args = @env.args()
  let argv = if args.length() > 1 { args[1:] } else { [] }

  let result = (cmd.parse(argv~, env=Map([])) |> Ok) catch { e => Err(e) }

  match result {
    Ok(matches) => {
      let has_verbose = matches.flags.get("verbose")

      let has_file = matches.values.get("file")
      let has_input = matches.values.get("input")

      let verbose = match has_verbose {
        Some(_) => true
        None => false
      }
      let file_path = match has_file {
        Some(v) => Some(v[0])
        None => None
      }

      let input = match has_input {
        Some(v) => Some(v[0])
        None => None
      }

      match (file_path, input) {
        (Some(path), _) => parse_file(path, verbose)
        (None, Some(text)) => parse_content(text, verbose)
        (None, None) => {
          println("Error: Please provide input via -f <file> or <string>")
          println("Usage: moon run src/cmd/main -- -f <file>")
          println(
            "       moon run src/cmd/main -- '<subject> <predicate> <object> .'",
          )
        }
      }
    }
    Err(e) => println("Error: \{e}")
  }
}

///|
async fn parse_file(path : String, verbose : Bool) -> Unit {
  let content = @fs.read_file(path).text()
  if verbose {
    println("Read file: \{path}")
    println("Content length: \{content.length()} bytes")
  }
  parse_content(content, verbose)
}

///|
fn parse_content(content : String, verbose : Bool) -> Unit {
  let data = @utf8.encode(content)

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false, []),
    data.to_array(),
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let machine = if verbose {
    @lib.NQuadsRecognizer::{
      current_state: @lib.NQuadsState::ExpectSubject,
      stack: [@lib.NQuadsState::ExpectSubject],
      emit_quad: false,
      // finalize_literal: None,
      // last_output: None,
      temp_literal: None,
      lenient: false,
      debug_logger: @lib.make_console_logger(),
      last_range: @lib.Range::default(),
      errors: [],
    }
  } else {
    @lib.NQuadsRecognizer::{
      current_state: @lib.NQuadsState::ExpectSubject,
      stack: [@lib.NQuadsState::ExpectSubject],
      emit_quad: false,
      // finalize_literal: None,
      // last_output: None,
      temp_literal: None,
      lenient: false,
      debug_logger: @lib.make_mute_logger(),
      last_range: @lib.Range::default(),
      errors: [],
    }
  }

  let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
    with_graph_name: false,
    lexer_options: { base_iri: None },
  })

  let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
    machine, context,
  )

  let parser = @lib.Parser::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  let quads = []
  let mut count = 0

  for ;; {
    if count >= 100 {
      break
    }
    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        quads.push(quad)
        if verbose {
          println("[\{count}] \{quad}")
        }
      }
      Some(Err(e)) => {
        count += 1
        println("[\{count}] Error: \{e}")
        break
      }
      None =>
        // if !verbose {
        //   println("End of file")
        // }
        break
    }
  }

  if !verbose {
    for q in quads {
      println("\{q}")
    }
  }
  println("")
  println("Parsed \{quads.length()} quads")
}
