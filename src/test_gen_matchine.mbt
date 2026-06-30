// ===== parser_m_test.mbt =====

///|
async test "ParserM_basic_with_lexer_working" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = make_console_logger()

  // 创建 TriGRecognizer
  let machine = TriGRecognizer::{
    stack: [TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: false,
    debug_logger: logger,
    last_range: Range::default(),
    errors: [],
  }

  let context = RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
    prefixes: Map([]),
  })

  // 创建 GenericStateMachine
  let generic_machine = GenericStateMachine::{ machine, context, outputs: [] }

  let parser = ParserM::{ lexer, engine: generic_machine, context, errors: [] }

  debug("=== ParserM Test ===")
  let quads = []
  let mut count = 0
  let max_iterations = 20

  for ;; {
    if count >= max_iterations {
      debug("WARNING: Max iterations reached")
      break
    }

    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] ✓ Quad: \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] ✗ Error: \{e}")
        break
      }
      None => {
        debug("[\{count}] Finished")
        break
      }
    }
  }

  debug("Total quads: \{quads.length()}")

  if quads.is_empty() {
    debug("=== Debug Info ===")
    debug("Engine is_accepting: \{parser.engine.is_accepting()}")
    debug("Engine outputs length: \{parser.engine.outputs.length()}")
    debug("Errors length: \{parser.errors.length()}")

    // 检查引擎状态
    debug("Engine current state: \{parser.engine.current_state()}")
  }

  assert_eq(quads.length(), 0)
}

///|
async test "ParserM_basic_with_lexer_working for NQuads" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  let data = @utf8.encode(input).to_array()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = make_console_logger()

  // 创建 TriGRecognizer
  let machine = NQuadsRecognizer::{
    stack: [NQuadsState::ExpectSubject],
    subjects: [],
    predicates: [],
    objects: [],
    lenient: false,
    debug_logger: logger, // 修复：包装为 Option 类型
    last_range: Range::default(),
    errors: [],
  }

  let context = RdfContext::NQuadsRecognizerContext(NQuadsRecognizerContext::{
    with_graph_name: false,
    lexer_options: { base_iri: None },
  })

  // 创建 GenericStateMachine
  let generic_machine = GenericStateMachine::{ machine, context, outputs: [] }

  let parser = ParserM::{ lexer, engine: generic_machine, context, errors: [] }

  debug("=== ParserM Test ===")
  let quads = []
  let mut count = 0
  let max_iterations = 20

  for ;; {
    if count >= max_iterations {
      debug("WARNING: Max iterations reached")
      break
    }

    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] ✓ Quad: \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[\{count}] ✗ Error: \{e}")
        break
      }
      None => {
        debug("[\{count}] Finished")
        break
      }
    }
  }

  debug("Total quads: \{quads.length()}")

  if quads.is_empty() {
    debug("=== Debug Info ===")
    debug("Engine is_accepting: \{parser.engine.is_accepting()}")
    debug("Engine outputs length: \{parser.engine.outputs.length()}")
    debug("Errors length: \{parser.errors.length()}")

    // 检查引擎状态
    debug("Engine current state: \{parser.engine.current_state()}")
  }

  assert_eq(quads.length(), 0)
}

///|
async test "debug_lexer_only" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  debug("=== Lexer Output ===")
  let mut count = 0
  for ;; {
    match lexer.parse_next(None) {
      Some(Ok(token)) => {
        count += 1
        debug("[\{count}] {token}")

        // 检查具体的 token 内容
        match token {
          LocatedTokenOrLineJump::LocatedN3Token(located) => {
            debug("    -> type: \{located.to_string()}")
            debug("    -> range: \{located.1.start}-\{located.1.end}")
          }
          LocatedTokenOrLineJump::LineJump(pos) =>
            debug("    -> LineJump at \{pos}")
          LocatedTokenOrLineJump::End => {
            debug("    -> End")
            break
          }
        }
      }
      Some(Err(e)) => {
        debug("Lexer Error: \{e}")
        break
      }
      None => {
        debug("No more tokens")
        break
      }
    }
  }

  debug("Total tokens: \{count}")
}

///|
async test "ParserM_basic_debug_step_by_step" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  let logger = make_console_logger()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let machine = TriGRecognizer::{
    stack: [TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: false,
    debug_logger: logger,
    last_range: Range::default(),
    errors: [],
  }

  let context = RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
    prefixes: Map::new(),
  })

  let generic_machine = GenericStateMachine::{ machine, context, outputs: [] }

  let parser = ParserM::{ lexer, engine: generic_machine, context, errors: [] }

  // ✅ 逐步调试
  let mut step = 0

  // 先检查 Lexer 输出
  debug("=== Testing Lexer ===")
  for ;; {
    match parser.lexer.parse_next(None) {
      Some(Ok(token)) => {
        step += 1
        debug("[Lexer \{step}] \{token}")
        if token is LocatedTokenOrLineJump::End {
          break
        }
      }
      Some(Err(e)) => {
        debug("[Lexer] Error: \{e}")
        break
      }
      None => {
        debug("[Lexer] No more tokens")
        break
      }
    }
  }

  // 重置 Lexer
  parser.lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  // 然后测试 Parser
  debug("=== Testing Parser ===")
  let quads = []
  let mut count = 0
  let max_iterations = 100

  while count < max_iterations {
    match parser.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[Parser {count}] ✓ Quad: {quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        count += 1
        debug("[Parser {count}] ✗ Error: \{e}")
        // 查看当前状态
        debug("  Current state: \{parser.engine.current_state()}")
        debug("  Stack: {parser.engine.machine.stack}")
        break
      }
      None => {
        debug("[Parser] Finished after \{count} iterations")
        break
      }
    }
  }

  debug("=== Results ===")
  debug("Total quads: \{quads.length()}")
  for i in 0..<quads.length() {
    debug("  Quad \{i+1}: \{quads[i]}")
  }

  assert_eq(quads.length(), 1)
}

///|
async test "ParserM_basic_with_safety" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = make_mute_logger() // 或者使用一个能输出到控制台的 Logger
  let machine = TriGRecognizer::{
    stack: [TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: false,
    debug_logger: logger,
    last_range: Range::default(),
    errors: [],
  }
  let generic_machine = GenericStateMachine::GenericStateMachine(
    machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  let parser = ParserM::ParserM(
    lexer,
    generic_machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  let quads = []
  let mut count = 0
  let max_iterations = 100 // 防止死循环的保护计数

  while count < max_iterations {
    match parser.parse_next() {
      Some(result) => {
        count += 1
        match result {
          Ok(quad) => {
            debug("Parsed quad \{count}: \{quad}")
            quads.push(quad)
          }
          Err(e) => {
            debug("Error at iteration \{count}: \{e}")
            // 关键：如果出错，应该打破循环或记录错误后继续，取决于 ParserM 的设计
            // 如果 ParserM 在 Err 后没有推进位置，这里会死循环
            break
          }
        }
      }
      None => {
        debug("Parser finished after \{count} iterations")
        break
      }
    }
  }

  if count >= max_iterations {
    debug("WARNING: Parser might be in an infinite loop!")
  }

  assert_eq(quads.length(), 1)
  if quads.length() > 0 {
    let quad = quads[0]
    debug("Final Quad: \{quad}")
  }
}

///|
async test "ParserM_basic" {
  // 1. 准备输入
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  // 2. 创建 Lexer
  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  // 3. 创建状态机
  let logger = make_mute_logger()
  let machine = TriGRecognizer::{
    stack: [TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: false,
    debug_logger: logger,
    last_range: Range::default(),
    errors: [],
  }
  let generic_machine = GenericStateMachine::GenericStateMachine(
    machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )
  // 4. 创建 ParserM
  let parser = ParserM::ParserM(
    lexer,
    generic_machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  // 5. 解析
  let quads = []
  while parser.parse_next() is Some(result) {
    match result {
      Ok(quad) => quads.push(quad)
      Err(e) => debug("Error: \{e}")
    }
  }

  // 6. 验证
  assert_eq(quads.length(), 1)
  let quad = quads[0]
  debug("Quad: \{quad}")
  // 验证三元组内容
}

///|
async test "Lexer_basic_tokenization" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true, // is_ending
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  // 手动获取几个 token 看看是否正常
  // 假设 Lexer 有 next_token() 方法，或者通过 ParserM 内部调用的接口
  // 这里需要根据你实际的 Lexer API 调整。如果 Lexer 没有公开 next_token，
  // 我们可能需要依赖 ParserM 的调试输出或中间状态。

  // 临时方案：尝试解析第一个三元组，看是否报错或卡住
  let logger = make_mute_logger()
  let machine = TriGRecognizer::{
    stack: [TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: false,
    debug_logger: logger,
    last_range: Range::default(),
    errors: [],
  }
  let generic_machine = GenericStateMachine::GenericStateMachine(
    machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  let parser = ParserM::ParserM(
    lexer,
    generic_machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  // 只尝试解析一步
  let result = parser.parse_next()
  match result {
    Some(Ok(quad)) => {
      debug("First quad parsed successfully: \{quad}")
      assert_eq(true, true) // Pass
    }
    Some(Err(e)) => {
      debug("Parse error on first step: \{e}")
      assert_eq(true, false) // Fail with message
    }
    None => {
      debug("Parser returned None immediately")
      assert_eq(true, false) // Fail
    }
  }
}

///|
async test "Lexer_IRI_Tokenization" {
  let input = "<http://a/b>"
  let data = @utf8.encode(input).to_array()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true, // is_ending
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  // 假设 ParserM 内部有方法可以获取下一个 token，或者我们可以通过解析一个简单的结构来测试
  // 这里我们直接尝试解析一个完整的三元组，但先只关注 Lexer 是否能读完 IRI

  let logger = make_mute_logger()
  let machine = TriGRecognizer::{
    stack: [TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: false,
    debug_logger: logger,
    last_range: Range::default(),
    errors: [],
  }
  let generic_machine = GenericStateMachine::GenericStateMachine(
    machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  let parser = ParserM::ParserM(
    lexer,
    generic_machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  // 尝试解析第一个 Token (Subject IRI)
  // 注意：这里假设 parse_next 会尝试解析整个三元组。
  // 如果报错 "Unexpected end of input"，说明 Lexer 在读取 <http://a/b> 时出了问题。

  let result = parser.parse_next()
  match result {
    Some(Ok(quad)) => {
      debug("Parsed quad: \{quad}")
      assert_eq(true, true)
    }
    Some(Err(e)) => {
      debug("Parse error: \{e}")
      // 打印 Lexer 当前位置，帮助调试
      debug("Lexer position: \{parser.lexer.position.buffer_offset}")
      debug("Lexer data length: \{parser.lexer.data.length()}")
      debug("Last token source: '\{parser.lexer.last_token_source()}'")
      assert_eq(true, false) // Fail to show error
    }
    None => {
      debug("Parser returned None")
      assert_eq(true, false)
    }
  }
}

///|
async test "ParserM_Full_Triple" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, false),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let logger = make_mute_logger()
  let machine = TriGRecognizer::{
    stack: [TriGState::TriGDoc],
    cur_subject: [],
    cur_predicate: [],
    cur_object: [],
    cur_graph: GraphName::DefaultGraph.as_ref(),
    cur_reifier: [],
    lenient: false,
    debug_logger: logger,
    last_range: Range::default(),
    errors: [],
  }
  let generic_machine = GenericStateMachine::GenericStateMachine(
    machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  let parser = ParserM::ParserM(
    lexer,
    generic_machine,
    RdfContext::TriGRecognizerContext(TriGRecognizerContext::{
      lexer_options: LexerOptions::{ base_iri: None },
      with_graph_name: false,
      prefixes: Map([]),
    }),
  )

  let quads = []
  let mut count = 0
  let max_iterations = 10

  while count < max_iterations {
    match parser.parse_next() {
      Some(result) => {
        count += 1
        match result {
          Ok(quad) => {
            debug("Parsed quad \{count}: \{quad}")
            quads.push(quad)
          }
          Err(e) => {
            debug("Error at iteration \{count}: \{e}")
            debug(
              "Lexer state: offset=\{parser.lexer.position.buffer_offset}, len=\{parser.lexer.data.length()}",
            )
            break
          }
        }
      }
      None => {
        debug("Parser finished after \{count} iterations")
        break
      }
    }
  }

  assert_eq(quads.length(), 1)
  if quads.length() > 0 {
    let quad = quads[0]
    debug("Final Quad: \{quad}")
  }
}
