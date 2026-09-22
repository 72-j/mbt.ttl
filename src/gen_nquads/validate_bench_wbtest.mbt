// ===== P1 验证段逐门剖析（役：验证段 5.8 → 3 ms 级，第①步）=====
// 分阶口径（native release）：
//   A 引擎裸跑（= bench Parser 段）
//   B parse_all lenient=true（组装 + span 切分 + 类型探测 + QuadSpan 构造，**四门全跳**）
//   C parse_all lenient=false（全量）
//   ⇒ 组装开销 = B − A；四门净开销 = C − B
//   D 微基准：对同一批词项视图逐门计时（validate_iri × 4 位 / validate_bnode / validate_literal）
// 纪律：读数只留证（机器相关），不入判据；本测试断言只做计数一致性。

///|
async fn p1_bench_data() -> Array[Byte] {
  let path = "./src/bench/test_10000.nq"
  Array::from_fixed_array(@fs.read_file(path).binary().to_fixedarray())
}

///|
async test "P1 逐门剖析: 验证段分阶计时（A 引擎 / B 组装 / C 全量 / D 微基准）" {
  let data = p1_bench_data()
  let view = data[:]

  // A 引擎裸跑 ×3
  let a_elapsed : Array[Double] = []
  for _rep in 0..<3 {
    let engine = NQuadsEngine::from_bytes(data.copy())
    let start = @bench.monotonic_clock_start()
    let mut count = 0
    for ;; {
      match engine.next() {
        Some(Ok(_)) => count = count + 1
        Some(Err(_)) => ()
        None => break
      }
    }
    a_elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(count, 10000)
  }

  // B lenient 组装 ×3 / C 全量 ×3
  let b_elapsed : Array[Double] = []
  let c_elapsed : Array[Double] = []
  let mut c_quads : Array[QuadSpan] = []
  for _rep in 0..<3 {
    let engine_b = NQuadsEngine::from_bytes(data.copy())
    let slice_b = SliceParser::new(engine_b, view).lenient()
    let start = @bench.monotonic_clock_start()
    let (quads_b, errors_b) = slice_b.parse_all()
    b_elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(quads_b.length(), 10000)
    assert_true(errors_b.is_empty())

    let engine_c = NQuadsEngine::from_bytes(data.copy())
    let slice_c = SliceParser::new(engine_c, view)
    let start = @bench.monotonic_clock_start()
    let (quads_c, errors_c) = slice_c.parse_all()
    c_elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(quads_c.length(), 10000)
    assert_true(errors_c.is_empty())
    if _rep == 0 {
      c_quads = quads_c
    }
  }

  // D 微基准：逐门计时（对同一批 QuadSpan 的词项视图）
  let subjects : Array[ArrayView[Byte]] = c_quads.map(fn(q) { q.subj })
  let preds : Array[ArrayView[Byte]] = c_quads.map(fn(q) { q.pred })
  let objs : Array[ArrayView[Byte]] = c_quads.map(fn(q) { q.obj })
  let graphs : Array[ArrayView[Byte]] = c_quads
    .map(fn(q) { q.graph.unwrap_or(data[0:0]) })
    .filter(fn(g) { g.length() > 0 })
  let mut d_subj = 0.0
  let mut d_pred = 0.0
  let mut d_obj = 0.0
  let mut d_graph = 0.0
  for _rep in 0..<3 {
    let start = @bench.monotonic_clock_start()
    for term in subjects {
      let _ = validate_iri(term, 0)
    }
    d_subj = d_subj + @bench.monotonic_clock_end(start)
    let start = @bench.monotonic_clock_start()
    for term in preds {
      let _ = validate_iri(term, 0)
    }
    d_pred = d_pred + @bench.monotonic_clock_end(start)
    let start = @bench.monotonic_clock_start()
    for term in objs {
      let _ = validate_iri(term, 0)
    }
    d_obj = d_obj + @bench.monotonic_clock_end(start)
    let start = @bench.monotonic_clock_start()
    for term in graphs {
      let _ = validate_iri(term, 0)
    }
    d_graph = d_graph + @bench.monotonic_clock_end(start)
  }

  println(
    "=== P1 逐门剖析（10k 全 IRI 语料 / native release / 3 次取均值）===",
  )
  println(
    "A 引擎裸跑:      \{a_elapsed[0]} / \{a_elapsed[1]} / \{a_elapsed[2]} µs",
  )
  println(
    "B lenient 组装:  \{b_elapsed[0]} / \{b_elapsed[1]} / \{b_elapsed[2]} µs",
  )
  println(
    "C 全量 parse_all: \{c_elapsed[0]} / \{c_elapsed[1]} / \{c_elapsed[2]} µs",
  )
  println(
    "分解: 组装开销 ≈ \{b_elapsed[2] - a_elapsed[2]} µs; 四门净开销 ≈ \{c_elapsed[2] - b_elapsed[2]} µs",
  )
  println(
    "D validate_iri 均值/次×3rep: subj \{d_subj / 3.0} µs, pred \{d_pred / 3.0} µs, obj \{d_obj / 3.0} µs, graph(\{graphs.length()}) \{d_graph / 3.0} µs",
  )
  println(
    "D 四位合计: \{(d_subj + d_pred + d_obj + d_graph) / 3.0} µs（对照 C−B 净开销）",
  )
}
