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
        (None, Some(text)) => parse_content(@utf8.encode(text), verbose)
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
  let content = @fs.read_file(path).binary()
  if verbose {
    println("Read file: \{path}")
    println("Content length: \{content.length()} bytes")
  }
  parse_content(content, verbose)
}

///|
async fn parse_content(content : Bytes, verbose : Bool) -> Unit {
  @async.with_task_group() <| _root => {

    // Create parser
    let engine = @nquads.NQuadsEngine::from_bytes(content.to_array())
    let slice = @nquads.SliceParser::new(engine, Bytes::to_array(content))

    // Parse all quads
    println("")
    println("=== Parsing N-Quads ===")

    let (quad_spans, parse_errors) = slice.parse_all()

    // Print parse errors
    for err in parse_errors {
      println("Parse Error: \{err}")
    }

    println("Parsed \{quad_spans.length()} quads")

    // Materialize
    println("")
    println("=== Materializing ===")

    let (quads, mat_errors) = @nquads.materialize_all(quad_spans)

    println("Materialized \{quads.length()} quads")
    // Print materialize errors

    for err in mat_errors {
      println("Materialize Error: \{err}")
    }
    if !verbose {

      // Serialize and print
      println("")
      println("=== Serialized Output ===")

      let output = match (@nquads.Serializer::new(format=@nquads.SerializeFormat::Quad)).serialize_all(quads) {
        Ok(value) => value
        Err(error) => {
          println("Serialize Error: \{error}")
          ""
        }
      }
      println(output)
    }

    println("")
    println("Serialized \{quads.length()} quads")
  }
}
