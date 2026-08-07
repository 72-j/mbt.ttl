///|
test "nquads: basic triple" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(quad)) => debug(quad)
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}

///|
test "nquads: triple with graph" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> <http://ex.org/g>.",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(quad)) =>
      if quad.graph is Some(_graph) {
        debug("triple with graph ok")
      } else {
        debug("graph missing")
      }
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}

///|
test "nquads: blank node" {
  let data = @utf8.encode("_:b1 <http://ex.org/p> <http://ex.org/o>.").to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(quad)) =>
      match quad.subj_type {
        @lib.SubjType::BNode => debug("blank node ok")
        _ => debug("wrong subj type")
      }
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}

///|
test "nquads: literal object" {
  let data = @utf8.encode("<http://ex.org/s> <http://ex.org/p> \"hello\" .").to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(quad)) =>
      match quad.obj_type {
        @lib.ObjType::Literal => debug("literal object ok")
        _ => debug("wrong obj type")
      }
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}

///|
test "nquads: multiple triples" {
  let data = @utf8.encode(
    "<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .\n<http://ex.org/s2> <http://ex.org/p2> <http://ex.org/o2> .",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(_)) => debug("first quad ok")
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }

  match parser.next() {
    Some(Ok(_)) => debug("second quad ok")
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }

  match parser.next() {
    None => debug("EOF ok")
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}
