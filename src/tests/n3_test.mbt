///|
async test "debug_n3_implies" {
  let input = "{ <http://example.org/s> <http://example.org/p> <http://example.org/o> } => { <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> } ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(@lib.Iri::Iri("http://example.org/"))

  let parser = @lib.N3Recognizer::new_parser(
    data,
    true,
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
