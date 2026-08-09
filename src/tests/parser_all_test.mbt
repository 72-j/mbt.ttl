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
test "materialize_all: basic triples" {
  let data = @utf8.encode(
    "<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .\n<http://ex.org/s2> <http://ex.org/p2>      <http://ex.org/o2> .",
  ).to_fixedarray()

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, parse_errors) = slice.parse_all()
  debug(
    "quad_spans: \{quad_spans.length()}, parse_errors: \{parse_errors.length()}",
  )

  for q in quad_spans {
    debug("  quad: subj_type=\{q.subj_type}, obj_type=\{q.obj_type}")
  }

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  debug("quads: \{quads.length()}, mat_errors: \{mat_errors.length()}")

  for err in mat_errors {
    debug("  error: \{err}")
  }

  assert_true(parse_errors.is_empty())
  assert_true(mat_errors.is_empty())
  assert_eq(quads.length(), 2)
}

///|
test "materialize_all: with graph" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> <http://ex.org/g> .",
  ).to_fixedarray()

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _parse_errors) = slice.parse_all()
  debug("quad_spans: \{quad_spans.length()}")

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  debug("quads: \{quads.length()}, mat_errors: \{mat_errors.length()}")

  assert_true(mat_errors.is_empty())
  assert_eq(quads.length(), 1)

  // 检查图名
  let quad = quads[0]
  match quad.graph_name {
    @lib.GraphName::Iri(g) => debug("graph: (\{g.0}, \{g.1})")
    @lib.GraphName::None => debug("graph: None")
  }
}

///|
test "materialize_all: with blank node" {
  let data = @utf8.encode("_:b1 <http://ex.org/p> <http://ex.org/o> .").to_fixedarray()

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _) = slice.parse_all()
  debug("quad_spans: \{quad_spans.length()}")

  for q in quad_spans {
    debug("  subj_type: \{q.subj_type}")
  }

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  debug("quads: \{quads.length()}, mat_errors: \{mat_errors.length()}")

  for err in mat_errors {
    debug("  error: \{err}")
  }

  assert_true(mat_errors.is_empty())
  assert_eq(quads.length(), 1)
}

///|
test "materialize_all: with debug" {
  let sb = StringBuilder::new()
  for i = 0; i < 10; i = i + 1 {
    sb.write_string("<http://ex.org/s")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/p")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/o")
    sb.write_string("\{i}")
    sb.write_string("> .\n")
  }
  let input = sb.to_string()
  let data = @utf8.encode(input).to_fixedarray()

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _) = slice.parse_all()

  // 逐个物化
  let quads = []
  let errors = []

  for i = 0; i < quad_spans.length(); i = i + 1 {
    let q = quad_spans[i]
    match @lib.materialize_quad(q, data) {
      Ok(quad) => quads.push(quad)
      Err(e) => {
        debug("Failed at quad [\{i}]: \{e}")
        // 打印这个 quad 的详情
        debug("  subj=(\{q.subj.0},\{q.subj.1})")
        debug("  pred=(\{q.pred.0},\{q.pred.1})")
        debug("  obj=(\{q.obj.0},\{q.obj.1})")
        debug("  subj_type=\{q.subj_type}")
        debug("  obj_type=\{q.obj_type}")
        errors.push(e)
      }
    }
  }

  debug("result: \{quads.length()} quads, \{errors.length()} errors")

  assert_eq(quad_spans.length(), 10)
  assert_eq(quads.length(), 10)
  assert_true(errors.is_empty())
}

///|
test "parse_all: only parse, no materialize" {
  let sb = StringBuilder::new()
  for i = 0; i < 10; i = i + 1 {
    sb.write_string("<http://ex.org/s")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/p")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/o")
    sb.write_string("\{i}")
    sb.write_string("> .\n")
  }
  let input = sb.to_string()
  let data = @utf8.encode(input).to_fixedarray()

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  // 只解析，不物化
  let (quad_spans, parse_errors) = slice.parse_all()

  debug("quad_spans: \{quad_spans.length()}")
  debug("parse_errors: \{parse_errors.length()}")

  // 打印每个 quad
  for i = 0; i < quad_spans.length(); i = i + 1 {
    let q = quad_spans[i]
    // 打印内容验证
    let (subj_off, subj_len) = q.subj
    let subj_content = {
      let mut s = ""
      let max = subj_len.min(20)
      for j = subj_off; j < subj_off + max; j = j + 1 {
        s = s + data[j].to_char().to_string()
      }
      if subj_len > 20 {
        s = s + "..."
      }
      s
    }
    debug(
      "  [\{i}] line=\{q.line}, subj=(\{subj_off},\{subj_len})='\{subj_content}'",
    )
  }

  // 只检查解析
  assert_eq(quad_spans.length(), 10)
}

///|
test "check lexer output" {
  let sb = StringBuilder::new()
  for i = 0; i < 20; i = i + 1 {
    sb.write_string("<http://ex.org/s")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/p")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/o")
    sb.write_string("\{i}")
    sb.write_string("> .\n")
  }
  let input = sb.to_string()
  let data = @utf8.encode(input).to_fixedarray()

  // 检查 5518 位置附近的数据
  let start = 5510
  let end = (start + 50).min(data.length())

  println("Data around offset 5518:")
  for i = start; i < end; i = i + 1 {
    let c = data[i]
    if c == b'\n' {
      println("  [\{i}] = '\\n'")
    } else if c == b'<' || c == b'>' || c == b' ' {
      println("  [\{i}] = '\{c.to_char()}'")
    } else {
      debug("  [\{i}] = '\{c.to_char()}'")
      if (i - start) % 10 == 9 {
        println("")
      }
    }
  }
  println("")
}

///|
async test "materialize_all: 1000 quads" {
  let file = "test_1000.nq"
  let test_dir = "/home/thy/moonttl/bak/benchmark"
  let filepath = test_dir + "/" + file

  // 同步读取（避免异步问题）
  let content = @fs.read_file(filepath).text()
  debug("content length: \{content.length()}")

  let data = @utf8.encode(content).to_fixedarray()
  debug("data length: \{data.length()}")

  // 验证内容
  if content.length() != data.length() {
    debug("ERROR: content.length() != data.length()")
  }

  // 验证开头和结尾
  let header = content[0:50]
  let footer = content[content.length() - 50:content.length()]
  debug("header: '\{header}'")
  debug("footer: '\{footer}'")

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _parse_errors) = slice.parse_all()
  debug("quad_spans: \{quad_spans.length()}")

  // 检查第一个和最后一个 quad
  if quad_spans.length() >= 2 {
    let first = quad_spans[0]
    let last = quad_spans[quad_spans.length() - 1]

    // 验证 offset 是否递增
    if first.subj.0 != 0 {
      debug("ERROR: first.subj.0 != 0")
    }

    // 检查跨度
    if last.subj.0 < data.length() - 100 {
      debug(
        "WARNING: last.subj.0 = \{last.subj.0}, data.length() = \{data.length()}",
      )
    }
  }

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  debug("result: \{quads.length()} quads, \{mat_errors.length()} errors")

  for err in mat_errors {
    debug("  error: \{err}")
  }

  assert_eq(quad_spans.length(), 1000)
  assert_eq(quads.length(), 1000)
  assert_true(mat_errors.is_empty())
}

///|
async test "materialize_all" {
  let sb = StringBuilder::new()
  for i = 0; i < 1000; i = i + 1 {
    sb.write_string("<http://ex.org/s")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/p")
    sb.write_string("\{i}")
    sb.write_string("> <http://ex.org/o")

    sb.write_string("\{i}")
    sb.write_string("> .\n")
  }
  let input = sb.to_string()
  let data = @utf8.encode(input).to_fixedarray()

  debug("data length: \{data.length()}")

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _parse_errors) = slice.parse_all()
  debug("quad_spans: \{quad_spans.length()}")

  // 找出有问题的 quad
  for i = 0; i < quad_spans.length(); i = i + 1 {
    let q = quad_spans[i]
    // 检查最后一个 quad 的 obj
    if i == quad_spans.length() - 1 {
      debug("=== Last quad ===")
      debug("  subj: (\{q.subj.0},\{q.subj.1})")
      debug("  pred: (\{q.pred.0},\{q.pred.1})")
      debug("  obj: (\{q.obj.0},\{q.obj.1})")
      debug("  obj_type: \{q.obj_type}")

      // 打印 obj 的实际内容
      let (obj_off, obj_len) = q.obj
      let mut content = ""
      let max_len = (obj_len + 20).min(50)
      for j = obj_off; j < obj_off + max_len; j = j + 1 {
        if j < data.length() {
          content = content + data[j].to_char().to_string()
        }
      }
      debug("  obj content: '\{content}'")
    }
  }

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  debug("result: \{quads.length()} quads, \{mat_errors.length()} errors")

  for err in mat_errors {
    let (off, len) = err.span
    debug("  error at (\{off},\{len}): \{err.message}")
    // 打印出错位置的内容
    let max_len = (len + 20).min(50)
    let mut content = ""
    for j = off; j < off + max_len; j = j + 1 {
      if j < data.length() {
        content = content + data[j].to_char().to_string()
      }
    }
    debug("  content: '\{content}'")
  }

  assert_true(mat_errors.is_empty())
}

///|
async test "materialize_all from file" {
  let file = "test_1000.nq"
  let test_dir = "/home/thy/moonttl/bak/benchmark"
  let filepath = test_dir + "/" + file

  let content = @fs.read_file(filepath).binary()
  let bytes = content.to_fixedarray()
  let data = bytes

  debug("data length: \{data.length()}")

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let (quad_spans, _parse_errors) = slice.parse_all()
  debug("quad_spans: \{quad_spans.length()}")

  // 找出有问题的 quad
  for i = 0; i < quad_spans.length(); i = i + 1 {
    let q = quad_spans[i]
    // 检查最后一个 quad 的 obj
    if i == quad_spans.length() - 1 {
      debug("=== Last quad ===")
      debug("  subj: (\{q.subj.0},\{q.subj.1})")
      debug("  pred: (\{q.pred.0},\{q.pred.1})")
      debug("  obj: (\{q.obj.0},\{q.obj.1})")
      debug("  obj_type: \{q.obj_type}")

      // 打印 obj 的实际内容
      let (obj_off, obj_len) = q.obj
      let mut content = ""
      let max_len = (obj_len + 20).min(50)
      for j = obj_off; j < obj_off + max_len; j = j + 1 {
        if j < data.length() {
          content = content + data[j].to_char().to_string()
        }
      }
      debug("  obj content: '\{content}'")
    }
  }

  let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)
  debug("result: \{quads.length()} quads, \{mat_errors.length()} errors")

  for err in mat_errors {
    let (off, len) = err.span
    debug("  error at (\{off},\{len}): \{err.message}")
    // 打印出错位置的内容
    let max_len = (len + 20).min(50)
    let mut content = ""
    for j = off; j < off + max_len; j = j + 1 {
      if j < data.length() {
        content = content + data[j].to_char().to_string()
      }
    }
    debug("  content: '\{content}'")
  }

  assert_true(mat_errors.is_empty())
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
test "lexer full output with data" {
  let data = @utf8.encode(
    "<ftp://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()

  debug("=== Data content ===")
  for i = 0; i < data.length(); i = i + 1 {
    let c = data[i]
    if c == b' ' || c == b'\n' {
      debug("  [\{i}] = ' '")
    } else if c == b'<' || c == b'>' || c == b'/' || c == b':' {
      debug("  [\{i}] = '\{c.to_char()}'")
    } else {
      debug("  [\{i}] = '\{c.to_char()}'")
    }
  }

  let lexer = @lib.Lexerc::new(data)

  debug("=== Lexer output ===")
  for i = 0; i < 20; i = i + 1 {
    match lexer.next() {
      Some(token) => {
        debug("token[\{i}]: \{token}")
        // 打印 token 内容
        match token {
          @lib.Token::Iri(span)
          | @lib.Token::Literal(span)
          | @lib.Token::BlankNode(span)
          | @lib.Token::PrefName(span)
          | @lib.Token::Unknown(span) => {
            let (off, len) = span
            let mut content = ""
            for j = off; j < (off + len).min(off + 30); j = j + 1 {
              content = content + data[j].to_char().to_string()
            }
            debug("    content: '\{content}'")
          }
          _ => ()
        }
      }
      None => {
        debug("lexer returned None at \{i}")
        break
      }
    }
  }

  lexer.destroy()
}

///|
test "slice next debug" {
  let data = @utf8.encode(
    "<ftp://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  let result = slice.next()
  println("slice.next() = \{@debug.to_string(result)}")
}

///|
test "parse_all debug" {
  let data = @utf8.encode(
    "<ftp://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()

  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.ParserE::from_bytes(data, engine)
  let slice = @lib.SliceParser::new(parser, data)

  debug("=== parse_all ===")

  let mut count = 0
  for ;; {
    // 先检查 inner 的状态
    // let inner_next = slice.inner.next()
    // debug("[\{count}] inner.next() = \{inner_next}")

    let result = slice.next()
    debug("[\{count}] slice.next() = \{@debug.to_string(result)}")

    match result {
      Some(Ok(_q)) => {
        count = count + 1
        debug("[\{count}] ok")
      }
      Some(Err(e)) => {
        count = count + 1
        debug("[\{count}] err: \{e}")
      }
      None => {
        debug("next() returned None")
        break
      }
    }
  }

  debug("total: \{count}")
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
  let file = "test_1000.nq"
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
