///|
/// Parse N-Quads file example
async fn main {
  @async.with_task_group() <| _root => {
    let path = "./test_1000.nq"
    let path = if @fs.exists(path) {
      path
    } else {
      "./src/benchmark/test_1000.nq"
    }
    let content = @fs.read_file(path).binary()
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

    // 2. Parser (不含验证)
    let engine = @lib.NQuadsEngine::new()
    let parser = @lib.Parser::from_bytes(data, engine)
    let start2 = @bench.monotonic_clock_start()
    let mut parser_count = 0
    for ;; {
      match parser.next() {
        Some(Ok(_)) => parser_count = parser_count + 1
        Some(Err(_)) => ()
        None => break
      }
    }
    // let (_quads, _parse_errors) = parser.parse_all()

    let elapsed2 = @bench.monotonic_clock_end(start2)

    // 3. SliceParser::parse_all (含验证)
    let engine2 = @lib.NQuadsEngine::new()
    let parser2 = @lib.Parser::from_bytes(data, engine2)
    let slice = @lib.SliceParser::new(parser2, data)
    let start3 = @bench.monotonic_clock_start()
    let (quads, parse_errors) = slice.parse_all()
    let elapsed3 = @bench.monotonic_clock_end(start3)

    // 4. materialize
    let engine3 = @lib.NQuadsEngine::new()
    let parser3 = @lib.Parser::from_bytes(data, engine3)
    let slice3 = @lib.SliceParser::new(parser3, data)
    let (quad_spans, _) = slice3.parse_all()
    let start4 = @bench.monotonic_clock_start()
    let (quad_emits, mat_errors) = @lib.materialize_all(quad_spans, data)
    let elapsed4 = @bench.monotonic_clock_end(start4)

    let total_ms = (elapsed3 + elapsed4) / 1000.0
    let quads_per_sec = if total_ms > 0.0 {
      quads.length().to_double() / (total_ms / 1000.0)
    } else {
      0.0
    }
    let ms_per_quad = if quads.length() > 0 {
      total_ms / quads.length().to_double()
    } else {
      0.0
    }

    println("=== MoonBit 解析 test_1000.nq ===")
    println("文件: \{path}")
    println("文件大小: \{data.length()} bytes")
    println("")
    println("=== 性能数据 ===")
    println("Lexer:       \{elapsed1} µs (\{lexer_count} tokens)")
    println("Parser:     \{elapsed2} µs (\{1000} quads)")
    println(
      "验证:        \{elapsed3} µs (\{quads.length()} quads, \{parse_errors.length()} errors)",
    )
    println(
      "物化:        \{elapsed4} µs (\{quad_emits.length()} quads, \{mat_errors.length()} errors)",
    )
    println("")
    println("=== 总计 ===")
    println("总时间:      \{total_ms} ms")
    println("三元组数量:  \{quads.length()}")
    println("每秒解析:    \{quads_per_sec.to_string()}")
    println("每三元组:    \{ms_per_quad.to_string()} ms")
  }
}
