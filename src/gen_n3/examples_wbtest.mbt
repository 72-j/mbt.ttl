// ===== examples/ 手选 N3 例程三桶分类（first sweep：打印分类，不钉）=====
// 来源：w3c/N3 仓库 examples/（cwm 推理例程，13 个 .n3）。桶：
//   A-full  = 解析零错 + 物化零错（全链可序列化）
//   B-mat   = 解析零错 + 物化有错（公式/规则延后桶——引擎出 quad、物化层 `{` 无臂）
//   C-parse = 解析有错（语法/词法缺口，逐条看）
// log:/list:/string:/time: 内建是推理器语义，不在解析器射程——谓词按普通 IRI 出账。

///|
async test "examples sweep: bucket N3 sample files (print-only)" {
  let dir = "src/gen_n3/rdf-tests/examples"
  let files = @fs.readdir(dir, sort=true).filter(fn(x) { x.has_suffix(".n3") })
  for file in files {
    let data = @fs.read_file("\{dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = N3Engine::from_bytes(data)
    let slice = N3SliceParser::new(engine, sec, lenient=true)
    let (quads, perrs) = slice.parse_all()
    let mat = N3Materializer::new(
      sec,
      slice.engine.ctx.prefixes,
      bases=slice.engine.ctx.bases,
      base_fallback=Some("https://example.org/\{file}"),
    )
    let (emits, merrs) = mat.materialize_all(quads)
    let bucket = if perrs.length() > 0 {
      "C-parse"
    } else if merrs.length() > 0 {
      "B-mat"
    } else {
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
}
