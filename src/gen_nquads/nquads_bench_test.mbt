// ===== gen_nquads 性能测试 =====
// 参考手写版 src/moon_ttl/src/benchmark/nquads-benchmark/main.mbt 的分阶段计时逻辑：
//   1. 仅词法（Tokenizer） 2. 引擎不含验证（NQuadsEngine::next） 3. 含验证（SliceParser::parse_all）
// 生成状态机版无 materialize 阶段（QuadSpan 即最终产物）

///|
async test "gen_nquads 性能: lexer / engine / parse_all" {
  // 输入：优先真实语料，缺省时内存生成 1000 条
  let mut input = ""
  let mut source = "generated"
  let path = "./src/moon_ttl/src/benchmark/test_1000.nq"
  if @fs.exists(path) {
    input = @fs.read_file(path).text()
    source = path
  } else {
    let n = 1000
    let base = "http://example.org/"
    let buf = StringBuilder()
    for i = 0; i < n; i = i + 1 {
      buf.write_string("<\{base}s\{i}> <\{base}p\{i}> <\{base}o\{i}> .\n")
    }
    input = buf.to_string()
  }
  let data = bytes_of(input)

  // 1. 仅词法（tokenize 一次性取全，末位 EOF 不计入 token 数）
  let start1 = @bench.monotonic_clock_start()
  let tokenizer = Lexermoon::new(data[:])
  let tokens = tokenizer.tokenize()
  let token_count = tokens.length() - 1
  let elapsed1 = @bench.monotonic_clock_end(start1)

  // 2. 引擎（不含验证）
  let start2 = @bench.monotonic_clock_start()
  let engine = NQuadsEngine::from_bytes(data)
  let mut engine_count = 0
  for ;; {
    match engine.next() {
      Some(Ok(_)) => engine_count = engine_count + 1
      Some(Err(_)) => ()
      None => break
    }
  }
  let elapsed2 = @bench.monotonic_clock_end(start2)

  // 3. SliceParser::parse_all（含验证）
  let start3 = @bench.monotonic_clock_start()
  let engine2 = NQuadsEngine::from_bytes(data)
  let slice = SliceParser::new(engine2, data)
  let (quads, parse_errors) = slice.parse_all()
  let elapsed3 = @bench.monotonic_clock_end(start3)

  // ===== C Lexerc 对比（lexerc_ffi.c，同一状态机仅换词法器） =====
  let fa = @utf8.encode(input).to_fixedarray()

  // 4. 仅词法（C Lexerc；换行不产生 token，计数口径与 Lexermoon 略有差异）
  let start4 = @bench.monotonic_clock_start()
  let lexerc = Lexerc::new(fa)
  let mut c_token_count = 0
  for ;; {
    match lexerc.next() {
      None => break
      Some(_) => c_token_count = c_token_count + 1
    }
  }
  lexerc.destroy()
  let elapsed4 = @bench.monotonic_clock_end(start4)

  // 5. C 引擎（不含验证；显式构造与释放）
  let start5 = @bench.monotonic_clock_start()
  let engine_c : NQuadsEngine[Lexerc] = NQuadsEngine::new(Lexerc::new(fa))
  let mut engine_c_count = 0
  for ;; {
    match engine_c.next() {
      Some(Ok(_)) => engine_c_count = engine_c_count + 1
      Some(Err(_)) => ()
      None => break
    }
  }
  Lexerc::destroy(engine_c.lexer)
  let elapsed5 = @bench.monotonic_clock_end(start5)

  // 6. C SliceParser::parse_all（含验证，内部释放词法器）
  let start6 = @bench.monotonic_clock_start()
  let (quads_c, errors_c) = nquads_parser_c(fa)
  let elapsed6 = @bench.monotonic_clock_end(start6)

  // 汇总（时间单位 µs）
  let total_ms = elapsed3 / 1000.0
  let quads_per_sec = if total_ms > 0.0 {
    quads.length().to_double() / (total_ms / 1000.0)
  } else {
    0.0
  }
  println("=== gen_nquads（fsm 生成状态机）解析 \{source} ===")
  println("文件大小:    \{data.length()} bytes")
  println("词法:        \{elapsed1} µs (\{token_count} tokens)")
  println("引擎:        \{elapsed2} µs (\{engine_count} quads)")
  println(
    "验证:        \{elapsed3} µs (\{quads.length()} quads, \{parse_errors.length()} errors)",
  )
  println("总时间:      \{total_ms} ms")
  println("每秒解析:    \{quads_per_sec.to_string()}")
  let c_total_ms = elapsed6 / 1000.0
  let c_quads_per_sec = if c_total_ms > 0.0 {
    quads_c.length().to_double() / (c_total_ms / 1000.0)
  } else {
    0.0
  }
  println("--- C Lexerc 对比（仅换词法器，状态机相同） ---")
  println("词法(C):     \{elapsed4} µs (\{c_token_count} tokens)")
  println("引擎(C):     \{elapsed5} µs (\{engine_c_count} quads)")
  println(
    "验证(C):     \{elapsed6} µs (\{quads_c.length()} quads, \{errors_c.length()} errors)",
  )
  println("总时间(C):   \{c_total_ms} ms")
  println("每秒解析(C): \{c_quads_per_sec.to_string()}")

  // 正确性断言（性能测试兼冒烟）：三阶段口径一致，两套词法器结果一致
  assert_true(quads.length() > 0)
  assert_eq(engine_count, quads.length())
  assert_eq(parse_errors.length(), 0)
  assert_eq(quads_c.length(), quads.length())
  assert_eq(engine_c_count, quads_c.length())
  assert_eq(errors_c.length(), 0)
}
