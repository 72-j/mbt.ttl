// ===== gen_trig 性能测试（与 gen_nquads/nquads_bench_test.mbt 同模板；不设门）=====
// 分阶段计时：
//   1. 仅词法（Lexermoon 直产事件一次性取全——P2 刀 a) 后口径）
//   2. 引擎不含验证（TrigEngine::next 出 span 快照 PendingQuad）
//   3. SliceParser::parse_all（含轻校验）
//   4. 物化（TrigMaterializer，默认开深验——trig 全链路特有阶段）
// C Lexerc 对照拆去 trig_bench_wbtest.mbt（native-only 设门）；本文件不设门，
// moon.pkg 的 wbtest bench 导入由本文件在 wasm 档兑用（W18：诊断核查按档跑）。
// 语料在内存确定性生成，简单/复杂两档分开计。两档均避开 [] 属性列表 / ()
// 集合（转移表未落地，落表外即报错，见 rdf_suite_test.mbt 的 deferred 桶）。

///|
/// MoonBit 字符串 → 字节组（trig_wbtest 的 bytes_of 同口径；另名避免测试期重名）
fn bench_bytes(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
/// Lexermoon 全量取事件（含末位 EOF，调用方按 EOF 变体判终止）。
/// gen_nquads 内部的 `Lexermoon::tokenize` 是包私有，跨包只能走 pub `next()`；
/// 口径与内部实现一致：EOF 也入列，事件计数取 `length() - 1`。
/// （P2 刀 a) 起直产 NQuadsEvent；仅计事件数——span 面消费在 C 对照文件的
/// lexmoon_stream：结构事件
/// 终点位回推、Unknown 走 last_unknown 单槽。）
fn bench_tokens(data : Array[Byte]) -> Array[NQuadsEvent] {
  let lexer = Lexermoon::new(data[:])
  let tokens : Array[NQuadsEvent] = []
  while true {
    match lexer.next() {
      Some(token) => {
        tokens.push(token)
        if token is NQuadsEvent::NQuadsEOF {
          break
        }
      }
      None => break
    }
  }
  tokens
}

///|
async test "gen_trig 性能(简单语料): lexer / engine / parse_all / 物化" {
  // 简单语料：全 IRI 扁平三元组（默认图 200 条 + 两个具名图块各 400 条 = 1000 quads），
  // 一行一 triple，无指令/无链式/无字面量——词汇面最窄的吞吐基线
  let n_flat = 200
  let n_per_graph = 400
  let base = "http://example.org/"
  let buf = StringBuilder()
  for i = 0; i < n_flat; i = i + 1 {
    let p = i % 20
    buf.write_string("<\{base}s\{i}> <\{base}p\{p}> <\{base}o\{i}> .\n")
  }
  for gi = 0; gi < 2; gi = gi + 1 {
    buf.write_string("<\{base}g\{gi}> {\n")
    for i = 0; i < n_per_graph; i = i + 1 {
      let p = i % 20
      buf.write_string(
        "<\{base}s\{gi}x\{i}> <\{base}p\{p}> <\{base}o\{gi}x\{i}> .\n",
      )
    }
    buf.write_string("}\n")
  }
  let data = bench_bytes(buf.to_string())
  let total = n_flat + n_per_graph * 2

  // 1. 仅词法（一次性取全，末位 EOF 不计入 token 数）
  let start1 = @bench.monotonic_clock_start()
  let tokens = bench_tokens(data)
  let token_count = tokens.length() - 1
  let elapsed1 = @bench.monotonic_clock_end(start1)

  // 2. 引擎（不含验证）
  let start2 = @bench.monotonic_clock_start()
  let engine = TrigEngine::from_bytes(data)
  let mut engine_count = 0
  let mut engine_errors = 0
  for ;; {
    match engine.next() {
      Some(Ok(_)) => engine_count = engine_count + 1
      Some(Err(_)) => engine_errors = engine_errors + 1
      None => break
    }
  }
  let elapsed2 = @bench.monotonic_clock_end(start2)

  // 3. SliceParser::parse_all（含验证）
  let start3 = @bench.monotonic_clock_start()
  let engine2 = TrigEngine::from_bytes(data)
  let slice = TrigSliceParser::new(engine2, data[:])
  let (quads, parse_errors) = slice.parse_all()
  let elapsed3 = @bench.monotonic_clock_end(start3)

  // 4. 物化（span → QuadEmit，深验默认开）
  let start4 = @bench.monotonic_clock_start()
  let mat = TrigMaterializer::new(
    data[:],
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, mat_errors) = mat.materialize_all(quads)
  let elapsed4 = @bench.monotonic_clock_end(start4)

  // 汇总（时间单位 µs）
  let total_ms = elapsed3 / 1000.0
  let quads_per_sec = if total_ms > 0.0 {
    quads.length().to_double() / (total_ms / 1000.0)
  } else {
    0.0
  }
  println(
    "=== gen_trig 简单语料（全 IRI 扁平三元组 + 具名图块） ===",
  )
  println("文件大小:    \{data.length()} bytes")
  println("词法:        \{elapsed1} µs (\{token_count} tokens)")
  println(
    "引擎:        \{elapsed2} µs (\{engine_count} quads, \{engine_errors} errors)",
  )
  println(
    "验证:        \{elapsed3} µs (\{quads.length()} quads, \{parse_errors.length()} errors)",
  )
  println(
    "物化:        \{elapsed4} µs (\{emits.length()} emits, \{mat_errors.length()} errors)",
  )
  println("每秒解析:    \{quads_per_sec.to_string()}")

  // 正确性断言（性能测试兼冒烟）：各阶段口径一致，默认图/具名图分界正确
  assert_eq(quads.length(), total)
  assert_eq(engine_count, total)
  assert_eq(engine_errors, 0)
  assert_eq(parse_errors.length(), 0)
  assert_eq(emits.length(), total)
  assert_eq(mat_errors.length(), 0)
  assert_true(quads[0].g is None) // 顶层三元组 = 默认图
  assert_true(quads[n_flat].g is Some(_)) // 图块起点起 quad 带图标签
}

///|
async test "gen_trig 性能(复杂语料): lexer / engine / parse_all / 物化" {
  // 复杂语料：指令双风格头部（@prefix + PREFIX/BASE/VERSION）→ 默认图块字面量族
  //（转义/长串/数值/布尔）→ n_iter 个具名图块迭代（图名 10 个轮转复用）→
  // GRAPH 关键字收尾块。每迭代固定 9 quads：
  //   ;/, 两档链 5 + 引用三元组+{| |}注解 2 + ~reifier 1 + <<( )>> 宾位 1
  // 注：^^datatype 后缀不放进 << >> 壳内——验证层 triple_term_inner_terms 按
  // 顶层空白切项，^^xsd:date 会被拆成第 4 项而误拒（壳内只放无后缀字面量）
  let n_iter = 250
  let n_graphs = 10
  let buf = StringBuilder()
  buf.write_string("VERSION \"1.2\"\n")
  buf.write_string("PREFIX ex: <http://example.org/>\n")
  buf.write_string("PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>\n")
  buf.write_string("BASE <http://base.example/>\n")
  buf.write_string(
    "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n",
  )
  buf.write_string("# bench corpus: complex trig\n\n")
  // 默认图块：字面量族，固定 6 quads（h1 三件 ; 链 + h2 三件 , 链）
  buf.write_string("{\n")
  buf.write_string(
    "ex:h1 ex:title \"héllo \\\"quoted\\\"\" ; ex:note \"\"\"line1\nline2\"\"\" ; ex:flag true .\n",
  )
  buf.write_string("ex:h2 ex:val 1.5 , -2 , 1.0e3 .\n")
  buf.write_string("}\n")
  for i = 0; i < n_iter; i = i + 1 {
    let g = i % n_graphs
    let p = i % 20
    let age = 30 + i % 60
    let day = i % 9 + 1
    let score = i % 10
    buf.write_string("ex:g\{g} {\n")
    buf.write_string(
      "ex:s\{i} a ex:C\{p} ; ex:name \"n\{i}\"@en , \"alt\{i}\" ; ex:age \{age} ; ex:stamp \"2024-01-0\{day}\"^^xsd:date .\n",
    )
    buf.write_string(
      "ex:s\{i} ex:cert << ex:b\{i} ex:when \"2024-01-0\{day}\" >> {| ex:score \{score} |} .\n",
    )
    buf.write_string("ex:s\{i} ex:prov ex:g\{g} ~ _:lbl\{i} .\n")
    buf.write_string("_:w\{i} ex:about <<( ex:s\{i} ex:src ex:o\{p} )>> .\n")
    buf.write_string("}\n")
  }
  // GRAPH 关键字收尾块：2 quads（; 链发射 1 + 点发射 1）
  buf.write_string("GRAPH ex:glast { ex:z0 a ex:Z ; ex:label \"last\" . }\n")
  let data = bench_bytes(buf.to_string())
  let total = 6 + n_iter * 9 + 2

  // 1. 仅词法（一次性取全，末位 EOF 不计入 token 数）
  let start1 = @bench.monotonic_clock_start()
  let tokens = bench_tokens(data)
  let token_count = tokens.length() - 1
  let elapsed1 = @bench.monotonic_clock_end(start1)

  // 2. 引擎（不含验证）
  let start2 = @bench.monotonic_clock_start()
  let engine = TrigEngine::from_bytes(data)
  let mut engine_count = 0
  let mut engine_errors = 0
  for ;; {
    match engine.next() {
      Some(Ok(_)) => engine_count = engine_count + 1
      Some(Err(_)) => engine_errors = engine_errors + 1
      None => break
    }
  }
  let elapsed2 = @bench.monotonic_clock_end(start2)

  // 3. SliceParser::parse_all（含验证）
  let start3 = @bench.monotonic_clock_start()
  let engine2 = TrigEngine::from_bytes(data)
  let slice = TrigSliceParser::new(engine2, data[:])
  let (quads, parse_errors) = slice.parse_all()
  let elapsed3 = @bench.monotonic_clock_end(start3)

  // 4. 物化（span → QuadEmit，深验默认开；前缀/账本须在 parse_all 后取）
  let start4 = @bench.monotonic_clock_start()
  let mat = TrigMaterializer::new(
    data[:],
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, mat_errors) = mat.materialize_all(quads)
  let elapsed4 = @bench.monotonic_clock_end(start4)

  // 汇总（时间单位 µs）
  let total_ms = elapsed3 / 1000.0
  let quads_per_sec = if total_ms > 0.0 {
    quads.length().to_double() / (total_ms / 1000.0)
  } else {
    0.0
  }
  println(
    "=== gen_trig 复杂语料（指令/图块/链式/字面量族/三元组词项/注解） ===",
  )
  println("文件大小:    \{data.length()} bytes")
  println("词法:        \{elapsed1} µs (\{token_count} tokens)")
  println(
    "引擎:        \{elapsed2} µs (\{engine_count} quads, \{engine_errors} errors)",
  )
  println(
    "验证:        \{elapsed3} µs (\{quads.length()} quads, \{parse_errors.length()} errors)",
  )
  println(
    "物化:        \{elapsed4} µs (\{emits.length()} emits, \{mat_errors.length()} errors)",
  )
  println("每秒解析:    \{quads_per_sec.to_string()}")

  // 正确性断言（性能测试兼冒烟）：各阶段口径一致，默认图块/具名图块分界正确
  assert_eq(quads.length(), total)
  assert_eq(engine_count, total)
  assert_eq(engine_errors, 0)
  assert_eq(parse_errors.length(), 0)
  assert_eq(emits.length(), total)
  assert_eq(mat_errors.length(), 0)
  assert_true(quads[0].g is None) // 默认图块 {} 内 g=None
  assert_true(quads[6].g is Some(_)) // 首个 ex:g0 图块 quad 带图标签
}
