// ===== W3C N3 官方套件 runner（manifest-parser.ttl 裁决，首扫打印不钉）=====
// 来源：w3c/N3 tests/N3Tests（bak/N3/tests/N3Tests 全量副本的 manifest 引用子集，
// 唯一 >100KB 的 cwm_other/rdfcore-tests.n3 以 skip 行排除——机器聚合料，parser
// 裁决价值零，见 parser_index.tsv）。
// 裁决口径（与 rdf_suite_wbtest.mbt 的 good/bad 契约同构）：
//   neg  = NegativeSyntax：全链必须至少一错（parse 或 materialize）——
//          零错 = NEG-MISS（负例被接受，真 bug/缺口）
//   pos  = PositiveSyntax：解析必须零错；物化错单列（公式/规则物化 = 延后桶，
//          不算解析失败）
//   eval = TestN3Eval：推理对照测试，本 runner 只取其语法面，按 pos 口径
// base：N3 正例大量使用 <#name> 相对 IRI 且无 @base——base_fallback 兑现
// 官方 harness 口径（base = 套件根 + 文件路径）。
// 首扫打印分类，不钉；分桶后再钉（turtle 套件同路径）。

///|
async test "N3Tests parser suite: first sweep (print-only)" {
  let dir = "src/gen_n3/rdf-tests/N3Tests"
  let base = "https://w3c.github.io/N3/tests/N3Tests/"
  let tsv = @fs.read_file("\{dir}/parser_index.tsv").text()
  let mut neg_ok = 0
  let mut neg_miss = 0
  let mut pos_ok = 0
  let mut pos_parse_fail = 0
  let mut pos_mat_only = 0
  for line in tsv.split("\n") {
    if line.is_empty() {
      continue
    }
    let parts : Array[StringView] = line.split("\t").collect()
    let kind = parts[0]
    let path = parts[1]
    if kind == "skip" {
      continue
    }
    let data = @fs.read_file("\{dir}/\{path}").binary().to_array()
    let sec = data[:]
    let engine = N3Engine::from_bytes(data)
    let slice = N3SliceParser::new(engine, sec, lenient=true)
    let (quads, perrs) = slice.parse_all()
    let mat = N3Materializer::new(
      sec,
      slice.engine.ctx.prefixes,
      bases=slice.engine.ctx.bases,
      base_fallback=Some("\{base}\{path}"),
    )
    let (_emits, merrs) = mat.materialize_all(quads)
    if kind == "neg" {
      if perrs.length() + merrs.length() > 0 {
        neg_ok = neg_ok + 1
      } else {
        neg_miss = neg_miss + 1
        debug("NEG-MISS \{path}（负例被全链接受）")
      }
    } else {
      // pos / eval：解析零错为门槛
      if perrs.length() > 0 {
        pos_parse_fail = pos_parse_fail + 1
        debug("P-FAIL \{path} p=\{perrs.length()}")
        for err in perrs {
          debug("  P: \{err}")
        }
      } else if merrs.length() > 0 {
        // 解析零错 + 物化有错 = 延后桶（公式/规则物化），不算解析失败
        pos_mat_only = pos_mat_only + 1
        debug("P-OK-MAT \{path} m=\{merrs.length()}")
      } else {
        pos_ok = pos_ok + 1
      }
    }
  }
  debug(
    "=== N3Tests parser sweep: neg \{neg_ok}ok/\{neg_miss}miss, pos+eval \{pos_ok}clean \{pos_mat_only}mat-only \{pos_parse_fail}parse-fail ===",
  )
}
