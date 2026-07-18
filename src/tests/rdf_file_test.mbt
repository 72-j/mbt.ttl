///|
async test "multi-line NQuads from file" {
  @async.with_task_group() <| root => {
    let path = "_build/nquads_multi_test.nq"
    root.add_defer(() => @fs.remove(path))

    let content =
      #| <http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .
      #| <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
      #| <http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .

    @fs.write_file(path, content, create_mode=CreateOrTruncate)

    let data = @fs.read_file(path).binary()

    let lexer = @lib.Lexer::Lexer(
      @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
      data.to_array(),
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

    let generic_machine = @lib.GenericStateMachine::{
      machine,
      context,
      outputs: [],
      data_world: @lib.DataWorld::default(),
      debug_logger: logger,
    }

    let parser = @lib.Parser::{
      lexer,
      engine: generic_machine,
      context,
      errors: [],
    }

    debug("=== Multi-Line Test ===")
    let quads = []
    let mut count = 0

    for ;; {
      if count >= 20 {
        break
      }
      match parser.parse_next() {
        Some(Ok(quad)) => {
          count += 1
          debug("[\{count}] ✓ \{quad}")
          quads.push(quad)
        }
        Some(Err(e)) => {
          count += 1
          debug("[\{count}] ✗ \{e}")
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
}

///|
async test "single quad from file" {
  @async.with_task_group() <| root => {
    let path = "_build/nquads_single_test.nq"
    root.add_defer(() => @fs.remove(path))

    let content = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"

    @fs.write_file(path, content, create_mode=CreateOrTruncate)

    let data = @fs.read_file(path).binary()

    let lexer = @lib.Lexer::Lexer(
      @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
      data.to_array(),
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

    let generic_machine = @lib.GenericStateMachine::{
      machine,
      context,
      outputs: [],
      data_world: @lib.DataWorld::default(),
      debug_logger: logger,
    }

    let parser = @lib.Parser::{
      lexer,
      engine: generic_machine,
      context,
      errors: [],
    }

    let quads = []
    let mut count = 0

    for ;; {
      if count >= 20 {
        break
      }
      match parser.parse_next() {
        Some(Ok(quad)) => {
          count += 1
          quads.push(quad)
        }
        Some(Err(e)) => {
          debug("Error: \{e}")
          break
        }
        None => break
      }
    }

    @debug.assert_eq(quads.length(), 1)
  }
}

///|
// async test "run official n-triples test file for TriG file" {
//   let test_dir = "src/tests/src/rdf/rdf11/trig"

//   let file = "trig-syntax-prefix-04"

//   debug("--------------------------------------")
//   debug("Testing: \{file}")

//   let path = "\{test_dir}/\{file}.trig"
//   let is_bad_test = file.contains("bad") || file.contains("error")

//   // 4. 安全读取文件内容
//   // 关键修复：添加 await，因为 read_file 是 async 函数
//   // 如果文件不存在或不可读，await read_file 会 panic。
//   // 若需更健壮的处理，可先用 @fs.exists 检查，或在 try-catch 块中运行（如果支持）
//   let data = @fs.read_file(path).binary().to_array()

//   let prefixes = Map([])
//   let base_iri = None

//   let parser = @lib.TriGRecognizer::new_parser(
//     data,
//     true,
//     false,
//     false,
//     base_iri,
//     prefixes,
//     debug_logger=@lib.make_console_logger(),
//   )

//   let result = parser.parse_next()
//   // @async.sleep(0)
//   // 7. 判定成功与否
//   let success = match result {
//     Some(Ok(_)) => !is_bad_test
//     Some(Err(e)) => {
//       debug(e.to_string())
//       is_bad_test
//     }
//     None => false
//   }

//   // 8. 输出结果
//   debug("Test Suite Results: \{if success {"PASSED"} else {"FAILED"}}")
// }

///|
// async test "run official trig test file dir for Trig file " {
//   let test_dir = "src/tests/src/rdf/rdf11/trig"

//   // 1. 打开目录并确保护理
//   let dir = @fs.opendir(test_dir)
//   defer dir.close() // 确保目录句柄在函数退出时关闭

//   // 2. 获取并过滤文件列表
//   let list = dir
//     .read_all()
//     .filter_map(x => if x == "target" { None } else { Some(x) })
//   list.sort()

//   let mut passed = 0
//   let mut failed = 0
//   let errors = []
//   let mut total_tested = 0

//   for file in list {
//     // 3. 仅处理 .nt 文件
//     if !file.has_suffix(".trig") {
//       continue
//     }

//     debug("--------------------------------------")
//     debug("Testing: \{file}")
//     total_tested += 1

//     let path = "\{test_dir}/\{file}"
//     let is_bad_test = file.contains("bad") || file.contains("error")

//     // 4. 安全读取文件内容
//     // 关键修复：添加 await，因为 read_file 是 async 函数
//     // 如果文件不存在或不可读，await read_file 会 panic。
//     // 若需更健壮的处理，可先用 @fs.exists 检查，或在 try-catch 块中运行（如果支持）
//     let data = @fs.read_file(path).binary().to_array()

//     let lexer = @lib.Lexer::Lexer(
//       @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::Turtle, false),
//       data,
//       true,
//       @lib.MIN_BUFFER_SIZE,
//       @lib.MAX_BUFFER_SIZE,
//       Some(b"#"),
//       0,
//       0,
//     )

//     let logger = @lib.make_console_logger()
//     let machine = @lib.TriGRecognizer::{
//       stack: [@lib.TriGState::TriGDoc],
//       cur_subject: [],
//       cur_predicate: [],
//       cur_object: [],
//       cur_graph: @lib.GraphName::DefaultGraph.as_ref(),
//       cur_reifier: [],
//       lenient: true,
//       debug_logger: logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
//       // in_collection: false,
//       last_range: @lib.Range::default(),
//       errors: [],
//     }

//     let context = @lib.RdfContext::TriGRecognizerContext(@lib.TriGRecognizerContext::{
//       with_graph_name: true,
//       lexer_options: { base_iri: None },
//       prefixes: Map([]),
//     })

//     let generic_machine = @lib.GenericStateMachine::{
//       machine,
//       context,
//       outputs: [],
//       debug_logger: logger,
//     }
//     let parser = @lib.Parser::{
//       lexer,
//       engine: generic_machine,
//       context,
//       errors: [],
//     }

//     let result = parser.parse_next()
//     // @async.sleep(0)
//     // 7. 判定成功与否
//     let success = match result {
//       Some(Ok(_)) => !is_bad_test
//       Some(Err(e)) => {
//         debug(e.to_string())
//         is_bad_test
//       }
//       None => false
//     }

//     if success {
//       passed += 1
//     } else {
//       failed += 1
//       let status = if is_bad_test {
//         "Should have failed but passed"
//       } else {
//         "Should have passed but failed"
//       }
//       errors.push("\{file}: \{status}")
//     }
//   }

//   // 8. 输出结果
//   debug("Test Suite Results:")
//   debug("Total Tested: \{total_tested}")
//   debug("Passed: \{passed}")
//   debug("Failed: \{failed}")

//   if Array::length(errors) > 0 {
//     debug("\nFailures:")
//     for err in errors {
//       debug("  - \{err}")
//     }
//     // panic() // 如果有失败，让测试挂掉
//   }
// }
