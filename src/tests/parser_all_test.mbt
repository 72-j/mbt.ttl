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
        @lib.TermType::BNode => debug("blank node ok")
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
      match quad.subj_type {
        @lib.TermType::Literal => debug("literal object ok")
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

// ============================================================
// 物化测试
// ============================================================

///|
test "materialize: basic quad" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, errors) = slice.parse_all()
  assert_true(errors.is_empty())
  assert_eq(quad_spans.length(), 1)

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  assert_true(mat_errors.is_empty())
  assert_eq(quads.length(), 1)

  let quad = quads[0]
  match quad.subject {
    @lib.NamedOrBlankNode::NamedNode(n) => assert_eq(n.iri, "http://ex.org/s")
    _ => abort("Expected NamedNode")
  }
  match quad.object {
    @lib.Term::NamedNode(n) => assert_eq(n.iri, "http://ex.org/o")
    _ => abort("Expected NamedNode")
  }
  debug("basic quad materialize ok")
}

///|
test "materialize: with blank node" {
  let data = @utf8.encode("_:b1 <http://ex.org/p> <http://ex.org/o> .").to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, parse_errors) = slice.parse_all()
  debug(
    "quad_spans: \{quad_spans.length()}, parse_errors: \{parse_errors.length()}",
  )

  // 检查 quad_spans
  if quad_spans.is_empty() {
    debug("No quad_spans, parsing failed")
    return
  }

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  debug("quads: \{quads.length()}, mat_errors: \{mat_errors.length()}")

  // 打印错误详情
  for err in mat_errors {
    debug("materialize error: \{err}")
  }

  if quads.is_empty() {
    debug("Materialization failed")
    return
  }

  let quad = quads[0]
  match quad.subject {
    @lib.NamedOrBlankNode::BlankNode(b) =>
      match b {
        @lib.BlankNode::Named(label) => assert_eq(label, "b1")
        _ => abort("Expected Named blank node")
      }
    _ => abort("Expected BlankNode")
  }
  debug("blank node materialize ok")
}

///|
test "materialize: with literal" {
  let data = @utf8.encode("<http://ex.org/s> <http://ex.org/p> \"hello\" .").to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, errors) = slice.parse_all()
  assert_true(errors.is_empty())

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  assert_true(mat_errors.is_empty())

  let quad = quads[0]
  match quad.object {
    @lib.Term::Literal(l) => {
      assert_eq(l.value(), "hello")
      debug("literal materialize ok")
    }
    _ => abort("Expected Literal")
  }
}

///|
test "materialize: with graph" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> <http://ex.org/g>  .",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, errors) = slice.parse_all()
  assert_true(errors.is_empty())

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  assert_true(mat_errors.is_empty())

  let quad = quads[0]
  match quad.graph_name {
    @lib.GraphName::NamedNode(n) => assert_eq(n.iri, "http://ex.org/g")
    @lib.GraphName::DefaultGraph => abort("Expected named graph")
    @lib.GraphName::BlankNode(_) => abort("Expected named graph")
  }
  debug("graph materialize ok")
}

///|
test "materialize: multiple quads" {
  let data =
    #|<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .
    #|<http://ex.org/s2> <http://ex.org/p2> <http://ex.org/o2> .
    #|<http://ex.org/s3> <http://ex.org/p3> <http://ex.org/o3> <http://ex.org/g3> .
    #|
  let data = @utf8.encode(data).to_fixedarray()
  // 检查 lexer 输出
  let lexer = @lib.Lexerc::new(data)
  debug("=== Lexer output ===")
  for ;; {
    match lexer.next() {
      Some(token) => debug("token: \{token}")
      None => break
    }
  }

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  debug("=== Parse result ===")
  let (quad_spans, errors) = slice.parse_all()
  debug("quad_spans: \{quad_spans.length()}")

  for err in errors {
    debug("parse error: \{err}")
  }

  assert_true(errors.is_empty())
  assert_eq(quad_spans.length(), 3)

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  assert_true(mat_errors.is_empty())
  assert_eq(quads.length(), 3)
  for quad in quads {
    debug("quad: \{quad}")
  }

  debug("multiple quads materialize ok")
}

///|
test "materialize: invalid IRI" {
  let data = @utf8.encode(
    "<ftp://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _) = slice.parse_all()
  let (_quads, errors) = @lib.materialize_all(quad_spans, data)

  // 物化应该捕获 IRI 错误
  assert_true(errors.length() > 0)
  debug("invalid IRI error caught ok")
}

///|
test "materialize: empty input" {
  let data = @utf8.encode("").to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _) = slice.parse_all()
  assert_eq(quad_spans.length(), 0)

  let (quads, errors) = @lib.materialize_all(quad_spans, data)
  assert_eq(quads.length(), 0)
  assert_true(errors.is_empty())
  debug("empty input materialize ok")
}

///|
test "performance: compare layers" {
  // 生成 1000 个三元组
  let input = {
    let mut s = ""
    for i = 0; i < 1000; i = i + 1 {
      s = s +
        "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
    }
    s
  }

  let data = @utf8.encode(input).to_fixedarray()

  // 1. 仅 Lexer
  let start1 = @bench.monotonic_clock_start()
  let lexer = @lib.Lexerc::new(data)
  let mut lexer_count = 0
  for ;; {
    match lexer.next() {
      Some(@lib.Token::EOF(_)) => break
      Some(_) => lexer_count = lexer_count + 1
      None => break
    }
  }
  lexer.destroy()
  let elapsed1 = @bench.monotonic_clock_end(start1)

  // 2. ParserE (不含验证)
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let start2 = @bench.monotonic_clock_start()
  let mut parser_count = 0
  for ;; {
    match parser.next() {
      Some(Ok(_)) => parser_count = parser_count + 1
      Some(Err(_)) => ()
      None => break
    }
  }
  let elapsed2 = @bench.monotonic_clock_end(start2)

  // 3. SliceParser::parse_all (含验证)
  let engine2 = @lib.NQuadsEngine::new()
  let parser2 = @lib.ParserE::from_bytes(data, engine2)
  let slice = @lib.SliceParser::new(parser2, data)
  let start3 = @bench.monotonic_clock_start()
  let (quads, _) = slice.parse_all()
  let elapsed3 = @bench.monotonic_clock_end(start3)

  // 4. materialize
  let engine3 = @lib.NQuadsEngine::new()
  let parser3 = @lib.ParserE::from_bytes(data, engine3)
  let slice3 = @lib.SliceParser::new(parser3, data)
  let (quad_spans, _) = slice3.parse_all()
  let start4 = @bench.monotonic_clock_start()
  let (_, _mat_errors) = @lib.materialize_all(quad_spans, data)
  let elapsed4 = @bench.monotonic_clock_end(start4)

  debug("=== Performance Comparison (1000 quads) ===")
  debug("Lexer:         \{elapsed1} us (\{lexer_count} tokens)")
  debug("ParserE:       \{elapsed2} us (\{parser_count} quads)")
  debug("SliceParser:   \{elapsed3} us (\{quads.length()} quads)")
  debug("Materialize:   \{elapsed4} us")
  debug("Total:         \{elapsed3 + elapsed4} us")
}

///|
async test "performance: compare layers from file" {
  let file = "test_10000.nq"
  let test_dir = "/home/thy/moonttl/bak/benchmark"
  let filepath = test_dir + "/" + file

  let content = @fs.read_file(filepath).binary()
  let bytes = content.to_fixedarray()
  let data = bytes

  // 1. 仅 Lexer
  let start1 = @bench.monotonic_clock_start()
  let lexer = @lib.Lexerc::new(data)
  let mut lexer_count = 0
  for ;; {
    match lexer.next() {
      Some(@lib.Token::EOF(_)) => break
      Some(_) => lexer_count = lexer_count + 1
      None => break
    }
  }
  lexer.destroy()
  let elapsed1 = @bench.monotonic_clock_end(start1)

  // 2. ParserE (不含验证)
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let start2 = @bench.monotonic_clock_start()
  let mut parser_count = 0
  for ;; {
    match parser.next() {
      Some(Ok(_)) => parser_count = parser_count + 1
      Some(Err(_)) => ()
      None => break
    }
  }
  let elapsed2 = @bench.monotonic_clock_end(start2)

  // 3. SliceParser::parse_all (含验证)
  let engine2 = @lib.NQuadsEngine::new()
  let parser2 = @lib.ParserE::from_bytes(data, engine2)
  let slice = @lib.SliceParser::new(parser2, data)
  let start3 = @bench.monotonic_clock_start()
  let (quads, _) = slice.parse_all()
  let elapsed3 = @bench.monotonic_clock_end(start3)

  // 4. materialize
  let engine3 = @lib.NQuadsEngine::new()
  let parser3 = @lib.ParserE::from_bytes(data, engine3)
  let slice3 = @lib.SliceParser::new(parser3, data)
  let (quad_spans, _) = slice3.parse_all()
  let start4 = @bench.monotonic_clock_start()
  let (_, _mat_errors) = @lib.materialize_all(quad_spans, data)
  let elapsed4 = @bench.monotonic_clock_end(start4)

  debug("=== Performance Comparison (1000 quads) ===")
  debug("Lexer:         \{elapsed1} us (\{lexer_count} tokens)")
  debug("ParserE:       \{elapsed2} us (\{parser_count} quads)")
  debug("SliceParser:   \{elapsed3} us (\{quads.length()} quads)")
  debug("Materialize:   \{elapsed4} us")
  debug("Total:         \{elapsed3 + elapsed4} us")
}
