///|
test "nquads: basic triple" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.Parser::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(quad)) => debug(quad)
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}
