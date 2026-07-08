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

    match parser.state {
      Some(state) => {
        debug("State stack depth: \{state.stack.length()}")
        debug("Current object: \{@debug.to_string(state.cur_object)}")
      }
      None => debug("No active state")
    }

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
