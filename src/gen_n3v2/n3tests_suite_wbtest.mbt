// ===== W3C N3 官方套件 runner（manifest-parser.ttl 裁决，首扫打印不钉）=====
// 来源：w3c/N3 tests/N3Tests（bak/N3/tests/N3Tests 全量副本的 manifest 引用子集，
// 唯一 >100KB 的 cwm_other/rdfcore-tests.n3 以 skip 行排除——机器聚合料，parser
// 裁决价值零，见 parser_index.tsv）。
// 裁决口径（与 rdf_suite_wbtest.mbt 的 good/bad 契约同构）：
//   neg  = NegativeSyntax：全链必须至少一错（parse 或 materialize）——
//          零错 = NEG-MISS（负例被接受，真 bug/缺口）
//   pos  = PositiveSyntax：解析必须零错；物化错单列（残差 = path 家族，见钉
//          注释，役18 扩展步清账）
//   eval = TestN3Eval：推理对照测试，本 runner 只取其语法面，按 pos 口径
// base：N3 正例大量使用 <#name> 相对 IRI 且无 @base——base_fallback 兑现
// 官方 harness 口径（base = 套件根 + 文件路径）。
// 首扫打印分类，不钉；分桶后再钉（turtle 套件同路径）。

///|
async test "N3Tests parser suite: first sweep (print-only)" {
  let dir = "src/gen_n3v2/rdf-tests/N3Tests"
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
      // pos / eval：解析零错为门槛
    } else if perrs.length() > 0 {
      pos_parse_fail = pos_parse_fail + 1
      debug("P-FAIL \{path} p=\{perrs.length()}")
      for err in perrs {
        debug("  P: \{err}")
      }
    } else if merrs.length() > 0 {
      // 解析零错 + 物化有错 = 残差桶（役17 后仅 path 家族），不算解析失败
      pos_mat_only = pos_mat_only + 1
      debug("P-OK-MAT \{path} m=\{merrs.length()}")
    } else {
      pos_ok = pos_ok + 1
    }
  }
  debug(
    "=== N3Tests parser sweep: neg \{neg_ok}ok/\{neg_miss}miss, pos+eval \{pos_ok}clean \{pos_mat_only}mat-only \{pos_parse_fail}parse-fail ===",
  )
  // 役16 钉（步5 收口）：解析门槛全绿。负例缺口 3（役17 起）：
  // thisadoc / qname-as-prefix-in-decl / bad_prefix2——cwm 传统合法、套件判负
  // 的口径分歧；bad_prefix2 = `:bad:o` 空前缀未声明，与套件正例 boolean.n3/
  // decimal.n3 依赖的隐式空前缀绑定直接冲突（套件自身跨传统不一致），役17 随
  // Team Submission 口径入账此缺口。
  // 役17 物化残差 2（path 家族）役18 清账：真根因 = 词法 `^` 门把单 `^` 当
  // `^^` 门字节，`"lit"^:prop` 整段胶进字面量 span，引擎收不到 Caret 事件。
  // 解胶后路径 desugar（役3 ADR-006）+ 役18 path_obj_close 双发纠偏（外层
  // 语句随跳边双发，旧径只发跳边、外层语句被后续语句覆写静默丢失），
  // path2/caret_pos 翻 clean，物化残差清零（pos_mat_only = 0）。
  assert_eq(pos_parse_fail, 0)
  assert_eq(neg_miss, 3)
  // 役18 收官钉：物化残差清零闭环
  assert_eq(pos_mat_only, 0)
}
