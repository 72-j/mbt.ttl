// ===== P3 物化段探针：test_10000.nq -> materialize_all 计时（只计时物化段）=====
// 口径：native release，读数只留证（面四纪律：绝对读数不进比较体）。
// 教训（AP.19 收役账）：开役基线 1399/1543µs 是另一探针协议的冷跑数，与本探针
// 不可同笔比较；有效对比只有同探针交错 A/B（刀前 293-368µs vs 刀后 214-276µs
// 稳态，~23% 降，交错四块方向一致）。后续役复测本探针即得同笔可比读数。

///|
async fn p3_probe_data() -> Array[Byte] {
  let path = "./src/bench/test_10000.nq"
  Array::from_fixed_array(@fs.read_file(path).binary().to_fixedarray())
}

///|
async test "P3 物化段探针" {
  let data = p3_probe_data()
  let engine = NQuadsEngine::from_bytes(data.copy())
  let slice = SliceParser::new(engine, data)
  let (quad_spans, parse_errors) = slice.parse_all()
  assert_eq(parse_errors.length(), 0)
  assert_eq(quad_spans.length(), 10000)
  let elapsed : Array[Double] = []
  for _rep in 0..<5 {
    let start = @bench.monotonic_clock_start()
    let (quads, mat_errors) = materialize_all(quad_spans)
    elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(quads.length(), 10000)
    assert_eq(mat_errors.length(), 0)
  }
  println(
    "P3 materialize: \{elapsed[0]} / \{elapsed[1]} / \{elapsed[2]} / \{elapsed[3]} / \{elapsed[4]} us",
  )
}
