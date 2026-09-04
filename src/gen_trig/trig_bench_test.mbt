// ===== gen_trig 性能测试（与 gen_nquads/nquads_bench_test.mbt 同模板）=====
// 分阶段计时：
//   1. 仅词法（Lexermoon::tokenize 一次性取全）
//   2. 引擎不含验证（TrigEngine::next 出 span 快照 PendingQuad）
//   3. SliceParser::parse_all（含轻校验）
//   4. 物化（TrigMaterializer，默认开深验——trig 全链路特有阶段）
// C Lexerc 对比不适用：C 侧引擎/解析器只按 nquads 转移表生成，trig 换表后无对应物。
// 语料在内存确定性生成，简单/复杂两档分开计。两档均避开 [] 属性列表 / ()
// 集合（转移表未落地，落表外即报错，见 rdf_suite_test.mbt 的 deferred 桶）。

///|
/// MoonBit 字符串 → 字节组（trig_wbtest 的 bytes_of 同口径；另名避免测试期重名）
fn bench_bytes(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
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

  // 1. 仅词法（tokenize 一次性取全，末位 EOF 不计入 token 数）
  let start1 = @bench.monotonic_clock_start()
  let tokenizer = Lexermoon::new(data[:])
  let tokens = tokenizer.tokenize()
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
  println("=== gen_trig 简单语料（全 IRI 扁平三元组 + 具名图块） ===")
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

  // 1. 仅词法（tokenize 一次性取全，末位 EOF 不计入 token 数）
  let start1 = @bench.monotonic_clock_start()
  let tokenizer = Lexermoon::new(data[:])
  let tokens = tokenizer.tokenize()
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
  println("=== gen_trig 复杂语料（指令/图块/链式/字面量族/三元组词项/注解） ===")
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

///|
/// 简单语料生成（与上方简单性能测试同口径，机械抽取复用）
fn bench_simple_input() -> String {
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
  buf.to_string()
}

///|
/// 复杂语料生成（与上方复杂性能测试同口径，机械抽取复用）
fn bench_complex_input() -> String {
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
  buf.to_string()
}

///|
/// 词法 span 分类（首字节口径，跨词法器可比）：0=IRI/TT 壳 1=字面量 2=bnode 3=其他
fn bench_span_kind(data : Array[Byte], off : Int) -> Int {
  let c = data[off]
  if c == b'<' {
    0
  } else if c == b'"' || c == b'\'' {
    1
  } else if c == b'_' {
    2
  } else {
    3
  }
}

///|
/// MoonBit 词法流：tokenize 全量 → (分类, offset, len) 序列（末位 EOF 不计）
fn lexmoon_stream(data : Array[Byte]) -> Array[(Int, Int, Int)] {
  let tokens = Lexermoon::new(data[:]).tokenize()
  let n = tokens.length() - 1
  let out : Array[(Int, Int, Int)] = []
  for i in 0..<n {
    let span = match tokens[i] {
      Token::Iri(s) => s
      Token::BlankNode(s) => s
      Token::Literal(s) => s
      Token::TripleTerm(s) => s
      Token::Dot(s) => s
      Token::Comma(s) => s
      Token::Semicolon(s) => s
      Token::PrefName(s) => s
      Token::Unknown(s) => s
      Token::EOF(_) => (0, 0)
    }
    out.push((bench_span_kind(data, span.0), span.0, span.1))
  }
  out
}

///|
/// C 词法流（lexerc_ffi.c 经 FFI）：逐 token 收集 → (分类, offset, len) 序列，
/// EOF 不计（与 MoonBit 口径一致）；Lexer 显式销毁（裸指针 UInt64 持有，GC 不追踪）
fn lexerc_stream(fa : FixedArray[Byte], data : Array[Byte]) -> Array[(Int, Int, Int)] {
  let lex = @nquads.Lexerc::new(fa)
  let out : Array[(Int, Int, Int)] = []
  for ;; {
    match lex.next() {
      None => break
      Some(Token::EOF(_)) => ()
      Some(t) => {
        let span = match t {
          Token::Iri(s) => s
          Token::BlankNode(s) => s
          Token::Literal(s) => s
          Token::TripleTerm(s) => s
          Token::Dot(s) => s
          Token::Comma(s) => s
          Token::Semicolon(s) => s
          Token::PrefName(s) => s
          Token::Unknown(s) => s
          Token::EOF(_) => (0, 0)
        }
        out.push((bench_span_kind(data, span.0), span.0, span.1))
      }
    }
  }
  lex.destroy()
  out
}

///|
async test "gen_trig 词法双引擎(Lexermoon vs C Lexerc): 口径一致性 + 性能" {
  // 两套词法器同机械（用户定案：口径一致）——逐 token 比对 (分类, 偏移, 长度)
  // 三元组，任何分歧即失败。C 侧引擎无 trig 转移表，故只比词法层；
  // 分类走 span 首字节（IRI/TT '<' / 字面量引号 / bnode '_' / 其他），
  // 两边词表形态对齐：`{|`/数值整词出 Unknown、`<<(`/`<<` 出 TripleTerm、
  // 尾部裸点回退、关键词/裸词出 PrefName
  let corpus_names = ["简单语料", "复杂语料"]
  let corpora = [bench_simple_input(), bench_complex_input()]
  for ci in 0..<2 {
    let input = corpora[ci]
    let data = bench_bytes(input)
    let fa = @utf8.encode(input).to_fixedarray()
    let start_m = @bench.monotonic_clock_start()
    let moon = lexmoon_stream(data)
    let elapsed_m = @bench.monotonic_clock_end(start_m)
    let start_c = @bench.monotonic_clock_start()
    let c = lexerc_stream(fa, data)
    let elapsed_c = @bench.monotonic_clock_end(start_c)
    println("--- \{corpus_names[ci]}: \{data.length()} bytes ---")
    println("词法(MoonBit):  \{elapsed_m} µs (\{moon.length()} tokens)")
    println("词法(C Lexerc): \{elapsed_c} µs (\{c.length()} tokens)")
    assert_eq(moon.length(), c.length())
    for i in 0..<moon.length() {
      assert_eq(moon[i], c[i])
    }
  }
}
