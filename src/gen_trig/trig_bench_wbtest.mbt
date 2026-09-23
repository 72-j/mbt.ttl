// ===== gen_trig C FFI 词法器对照（native-only：Lexerc 裸指针 FFI，UInt64 持有）=====
// 双词法器同机械逐 token 比对 (分类, offset, len)；MoonBit 侧件（bench_tokens/
// lexmoon_stream/语料生成/分类）在 trig_perf_wbtest.mbt，同包白盒共享。
// P2 刀 a) 起 Lexermoon 直产 NQuadsEvent（span 面：词事件自带 / 结构事件终点位
// 回推 / Unknown 走 last_unknown 单槽）；C 侧仍出 Token（FFI 冻结，token_to_event
// 口径在 gen_nquads/engine_c.mbt）。

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
/// MoonBit 词法流：全量取词 → (分类, offset, len) 序列（末位 EOF 不计）。
/// P2 刀 a) 起直产事件：结构事件 span = 终点位回推（pos−1，单字节），
/// Unknown span 走 last_unknown 单槽即读——口径与旧 Token span 逐值一致
fn lexmoon_stream(data : Array[Byte]) -> Array[(Int, Int, Int)] {
  let lexer = Lexermoon::new(data[:])
  let out : Array[(Int, Int, Int)] = []
  while true {
    match lexer.next() {
      Some(NQuadsEvent::NQuadsEOF) | None => break
      Some(ev) => {
        let span = match ev {
          NQuadsEvent::NQuadsIri(s) => s
          NQuadsEvent::NQuadsBlankNode(s) => s
          NQuadsEvent::NQuadsLiteral(s) => s
          NQuadsEvent::NQuadsTripleTerm(s) => s
          NQuadsEvent::NQuadsPrefName(s) => s
          NQuadsEvent::NQuadsUnknown => lexer.last_unknown_span()
          NQuadsEvent::NQuadsDot
          | NQuadsEvent::NQuadsSemicolon
          | NQuadsEvent::NQuadsComma => (lexer.current_pos() - 1, 1)
          NQuadsEvent::NQuadsEOF => (0, 0)
        }
        out.push((bench_span_kind(data, span.0), span.0, span.1))
      }
    }
  }
  out
}

///|
/// C 词法流（lexerc_ffi.c 经 FFI）：逐 token 收集 → (分类, offset, len) 序列，
/// EOF 不计（与 MoonBit 口径一致）；Lexer 显式销毁（裸指针 UInt64 持有，GC 不追踪）
fn lexerc_stream(
  fa : FixedArray[Byte],
  data : Array[Byte],
) -> Array[(Int, Int, Int)] {
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
