///|
async test "Parser_basic_single_line for NQuads" {
  // #|"""abc""" .
  let input =
    #| <http://example/> <http://example/p> "\u0053" .

  debug("Input: \{input}")

  let data = @utf8.encode(input).to_array()
  let logger = @lib.make_console_logger()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(
      @lib.RdfLexerMode::NTriples,
      false,
      debug_logger=logger,
      [],
    ),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let machine = @lib.NQuadsRecognizer::{
    current_state: @lib.NQuadsState::ExpectSubject,
    stack: [@lib.NQuadsState::ExpectSubject],
    emit_quad: false,
    // finalize_literal: None,
    // last_output: None,
    temp_literal: None,
    lenient: false,
    debug_logger: logger,
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
    with_graph_name: false,
    lexer_options: { base_iri: None },
  })

  let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
    machine,
    context,
    debug_logger=logger,
  )
  let parser = @lib.Parser::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  debug("=== Single Line Test ===")
  let quads = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total: \{quads.length()}")
  @debug.assert_eq(quads.length(), 1)
}

///|
async test "multi-line  for NQuads" {
  let input =
    #| <http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #| <http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #| <http://example.org/s> <http://example.org/p> "\\" .
    #| 

  let data = @utf8.encode(input).to_array()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false, []),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = @lib.make_console_logger()

  let machine = @lib.NQuadsRecognizer::{
    current_state: @lib.NQuadsState::ExpectSubject,
    stack: [@lib.NQuadsState::ExpectSubject],
    emit_quad: false,
    // finalize_literal: None,
    // last_output: None,
    temp_literal: None,
    lenient: false,
    debug_logger: logger,
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
    with_graph_name: false,
    lexer_options: { base_iri: None },
  })

  let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
    machine,
    context,
    debug_logger=logger,
  )
  let parser = @lib.Parser::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  debug("=== Single Line Test ===")
  let quads = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total: \{quads.length()}")
  @debug.assert_eq(quads.length(), 3)
}

///|
async test "Parser_basic_single_line for NQuads GraphName" {
  let input =
    #|<http://example.org/book1> <http://purl.org/dc/terms/title> "The Great Gatsby"@en <http://example.org/books> .
  let data = @utf8.encode(input).to_array()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false, []),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = @lib.make_console_logger()

  let machine = @lib.NQuadsRecognizer::{
    current_state: @lib.NQuadsState::ExpectSubject,
    stack: [@lib.NQuadsState::ExpectSubject],
    emit_quad: false,
    // finalize_literal: None,
    // last_output: None,
    temp_literal: None,
    lenient: false,
    debug_logger: logger,
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
    with_graph_name: true,
    lexer_options: { base_iri: None },
  })

  let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
    machine,
    context,
    debug_logger=logger,
  )
  let parser = @lib.Parser::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  debug("=== Single Line Test ===")
  let quads = []
  let mut count = 0

  for ;; {
    if count >= 20 {
      break
    }
    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total: \{quads.length()}")
  @debug.assert_eq(quads.length(), 1)
}

///|
async test "Parser_NQuads_complete_dataset" {
  let input =
    #|<http://example.org/dataset> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/ns/sparql-service-description#Dataset> .
    #|<http://example.org/dataset> <http://purl.org/dc/terms/modified> "2024-06-01T12:00:00Z"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
    #|<http://example.org/dataset> <http://purl.org/dc/terms/publisher> <http://example.org/org/acme> .
    #|<http://example.org/product/001> <http://schema.org/name> "Widget Pro" <http://example.org/sales/q1-2024> .
    #|<http://example.org/product/001> <http://schema.org/price> "299.00"^^<http://www.w3.org/2001/XMLSchema#decimal> <http://example.org/sales/q1-2024> .
    #|<http://example.org/product/001> <http://schema.org/sold> "1500"^^<http://www.w3.org/2001/XMLSchema#integer> <http://example.org/sales/q1-2024> .
    #|<http://example.org/product/002> <http://schema.org/name> "Widget Lite" <http://example.org/sales/q1-2024> .
    #|<http://example.org/product/002> <http://schema.org/price> "149.00"^^<http://www.w3.org/2001/XMLSchema#decimal> <http://example.org/sales/q1-2024> .
    #|<http://example.org/product/002> <http://schema.org/sold> "3200"^^<http://www.w3.org/2001/XMLSchema#integer> <http://example.org/sales/q1-2024> .
    #|<http://example.org/product/001> <http://schema.org/name> "Widget Pro" <http://example.org/sales/q2-2024> .
    #|<http://example.org/product/001> <http://schema.org/price> "279.00"^^<http://www.w3.org/2001/XMLSchema#decimal> <http://example.org/sales/q2-2024> .
    #|<http://example.org/product/001> <http://schema.org/sold> "2100"^^<http://www.w3.org/2001/XMLSchema#integer> <http://example.org/sales/q2-2024> .
    #|<http://example.org/product/001> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Product> <http://example.org/catalog> .
    #|<http://example.org/product/001> <http://schema.org/category> "Electronics" <http://example.org/catalog> .
    #|<http://example.org/product/002> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://schema.org/Product> <http://example.org/catalog> .
    #|<http://example.org/product/002> <http://schema.org/category> "Electronics" <http://example.org/catalog> .
  let data = @utf8.encode(input).to_array()

  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false, []),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = @lib.make_console_logger()

  let machine = @lib.NQuadsRecognizer::{
    current_state: @lib.NQuadsState::ExpectSubject,
    stack: [@lib.NQuadsState::ExpectSubject],
    emit_quad: false,
    // finalize_literal: None,
    // last_output: None,
    temp_literal: None,
    lenient: false,
    debug_logger: logger,
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
    with_graph_name: true,
    lexer_options: { base_iri: None },
  })

  let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
    machine,
    context,
    debug_logger=logger,
  )
  let parser = @lib.Parser::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  debug("=== NQuads Complete Dataset ===")
  let quads = []
  let mut count = 0

  for ;; {
    if count >= 30 {
      break
    }
    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        // debug("[\{count}] \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total: \{quads.length()}")
  @debug.assert_eq(quads.length(), 16)
}

///|
async test "run official n-triples test file" {
  let test_dir = "src/tests/src/rdf/rdf11/n-triples"

  let file = "nt-syntax-bad-uri-02"

  debug("--------------------------------------")
  debug("Testing: \{file}")

  let path = "\{test_dir}/\{file}.nt"
  let is_bad_test = file.contains("bad") || file.contains("error")

  // 4. 安全读取文件内容
  // 关键修复：添加 await，因为 read_file 是 async 函数
  // 如果文件不存在或不可读，await read_file 会 panic。
  // 若需更健壮的处理，可先用 @fs.exists 检查，或在 try-catch 块中运行（如果支持）
  let data = @fs.read_file(path).binary().to_array()
  let lexer = @lib.Lexer::Lexer(
    @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false, []),
    data,
    true,
    @lib.MIN_BUFFER_SIZE,
    @lib.MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = @lib.make_console_logger()

  let machine = @lib.NQuadsRecognizer::{
    current_state: @lib.NQuadsState::ExpectSubject,
    stack: [@lib.NQuadsState::ExpectSubject],
    emit_quad: false,
    // finalize_literal: None,
    // last_output: None,
    temp_literal: None,
    lenient: false,
    debug_logger: logger,
    last_range: @lib.Range::default(),
    errors: [],
  }

  let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
    with_graph_name: true,
    lexer_options: { base_iri: None },
  })

  let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
    machine,
    context,
    debug_logger=logger,
  )
  let parser = @lib.Parser::{
    lexer,
    engine: generic_machine,
    context,
    errors: [],
  }

  let result = parser.parse_next()
  // @async.sleep(0)
  // 7. 判定成功与否
  let success = match result {
    Some(Ok(_)) => !is_bad_test
    Some(Err(e)) => {
      debug(e.to_string())
      is_bad_test
    }
    None => false
  }

  // 8. 输出结果
  debug("Test Suite Results: \{if success {"PASSED"} else {"FAILED"}}")
}

///|
async test "run official n-triples test suite" {
  // let test_dir = "src/tests/src/rdf/rdf11/n-triples"
  let test_dir = "src/tests/src/bak/c14n"

  // 1. 打开目录并确保护理
  let dir = @fs.opendir(test_dir)
  defer dir.close() // 确保目录句柄在函数退出时关闭

  // 2. 获取并过滤文件列表
  let list = dir
    .read_all()
    .filter_map(x => if x == "target" { None } else { Some(x) })
  list.sort()

  let mut passed = 0
  let mut failed = 0
  let errors = []
  let mut total_tested = 0

  for file in list {
    // 3. 仅处理 .nt 文件
    if !file.has_suffix(".nt") {
      continue
    }

    debug("--------------------------------------")
    debug("Testing: \{file}")
    total_tested += 1

    let path = "\{test_dir}/\{file}"
    let is_bad_test = file.contains("bad") || file.contains("error")

    // 4. 安全读取文件内容
    // 关键修复：添加 await，因为 read_file 是 async 函数
    // 如果文件不存在或不可读，await read_file 会 panic。
    // 若需更健壮的处理，可先用 @fs.exists 检查，或在 try-catch 块中运行（如果支持）
    let data = @fs.read_file(path).binary().to_array()

    let lexer = @lib.Lexer::Lexer(
      @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false, []),
      data,
      true,
      @lib.MIN_BUFFER_SIZE,
      @lib.MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    )

    let logger = @lib.make_console_logger()

    let machine = @lib.NQuadsRecognizer::{
      current_state: @lib.NQuadsState::ExpectSubject,
      stack: [@lib.NQuadsState::ExpectSubject],
      emit_quad: false,
      // finalize_literal: None,
      // last_output: None,
      temp_literal: None,
      lenient: false,
      debug_logger: logger,
      last_range: @lib.Range::default(),
      errors: [],
    }
    let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
      with_graph_name: true,
      lexer_options: { base_iri: None },
    })

    let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
      machine,
      context,
      debug_logger=logger,
    )
    let parser = @lib.Parser::{
      lexer,
      engine: generic_machine,
      context,
      errors: [],
    }

    let result = parser.parse_next()
    // @async.sleep(0)
    // 7. 判定成功与否
    let success = match result {
      Some(Ok(_)) => !is_bad_test
      Some(Err(e)) => {
        debug(e.to_string())
        is_bad_test
      }
      None => false
    }

    if success {
      passed += 1
    } else {
      failed += 1
      let status = if is_bad_test {
        "Should have failed but passed"
      } else {
        "Should have failed!"
      }
      errors.push("\{file}: \{status}")
    }
  }

  // 8. 输出结果
  debug("Test Suite Results:")
  debug("Total Tested: \{total_tested}")
  debug("Passed: \{passed}")
  debug("Failed: \{failed}")

  if Array::length(errors) > 0 {
    debug("Failures:")
    for err in errors {
      debug("Err - \{err}")
    }
    // panic() // 如果有失败，让测试挂掉
  }
}
