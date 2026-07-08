///|
async test "debug_trig_subj_only" {
  let input = "<http://a/b>"
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

  match parser.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_trig_complete_triple" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()
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

  match parser.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_trig_complete_triple_newline" {
  let input = "<http://a/b> <http://a/c> <http://a/d> .\n"
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

  match parser.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_lexer_tokens" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

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
    match parser.parse_next() {
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
