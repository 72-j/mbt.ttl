// ===== examples/ 手选 N3 例程三桶分类（first sweep：打印分类，不钉）=====
// 来源：w3c/N3 仓库 examples/（cwm 推理例程，13 个 .n3）。桶：
//   A-full  = 解析零错 + 物化零错（全链可序列化）
//   B-mat   = 解析零错 + 物化有错（公式/规则延后桶——引擎出 quad、物化层 `{` 无臂）
//   C-parse = 解析有错（语法/词法缺口，逐条看）
// log:/list:/string:/time: 内建是推理器语义，不在解析器射程——谓词按普通 IRI 出账。

///|
async test "examples sweep: bucket N3 sample files (pinned)" {
  let dir = "src/gen_n3v2/rdf-tests/examples"
  let files = @fs.readdir(dir, sort=true).filter(fn(x) { x.has_suffix(".n3") })
  let mut a_full = 0
  let mut b_mat = 0
  let mut c_parse = 0
  let mut strict_gap = 0 // 影子缺口（役25 双判）：宽容零错而严格翻脸
  for file in files {
    let data = @fs.read_file("\{dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = N3Engine::from_bytes(data)
    let slice = N3SliceParser::new(engine, sec, lenient=true)
    let (quads, perrs) = slice.parse_all()
    // 影子扫描（役25 R-07 双判·题6=A）：严格组装校验重跑，桶口径不变
    if perrs.length() == 0 {
      let slice_s = N3SliceParser::new(N3Engine::from_bytes(data), sec)
      let (_, perrs_s) = slice_s.parse_all()
      if perrs_s.length() > 0 {
        strict_gap = strict_gap + 1
        debug("STRICT-GAP \{file}")
        for err in perrs_s {
          debug("  S: \{err}")
        }
      }
    }
    let mat = N3Materializer::new(
      sec,
      slice.engine.ctx.prefixes,
      bases=slice.engine.ctx.bases,
      base_fallback=Some("https://example.org/\{file}"),
    )
    let (emits, merrs) = mat.materialize_all(quads)
    let bucket = if perrs.length() > 0 {
      c_parse = c_parse + 1
      "C-parse"
    } else if merrs.length() > 0 {
      b_mat = b_mat + 1
      "B-mat"
    } else {
      a_full = a_full + 1
      "A-full"
    }
    debug(
      "\{bucket} \{file} quads=\{quads.length()} emits=\{emits.length()} p=\{perrs.length()} m=\{merrs.length()}",
    )
    for err in perrs {
      debug("  P: \{err}")
    }
    for err in merrs {
      debug("  M: \{err}")
    }
  }
  // 役25 桶闭合钉：清单冻结 + 三桶计数基线（首扫 2026-09-11：13 全 A-full）
  assert_eq(a_full + b_mat + c_parse, files.length())
  assert_eq(a_full, 13)
  assert_eq(b_mat, 0)
  assert_eq(c_parse, 0)
  debug(
    "=== examples: A=\{a_full} B=\{b_mat} C=\{c_parse} strict-gap=\{strict_gap} ===",
  )
  // 影子基线钉（役25 双判·2026-09-11）：13/13 全翻 = cwm 例程内建前缀
  //（log:/list:/string:/time:）不声明即用——同 N3Tests 影子族，待预绑定修口役
  assert_eq(strict_gap, 13)
}
