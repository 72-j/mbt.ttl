// ===== W3C N3 官方套件 runner（manifest-parser.ttl 裁决，首扫打印不钉）=====
// 来源：w3c/N3 tests/N3Tests（bak/N3/tests/N3Tests 全量副本的 manifest 引用子集，
// 唯一 >100KB 的 cwm_other/rdfcore-tests.n3 以 skip 行排除——机器聚合料，parser
// 裁决价值零，见 parser_index.tsv）。
//   - bad_prefix2（extra/）：rdft:Rejected——重定义非法规则被 WG 否决，
//     后者胜是 cwm/Turtle 官方语义（正例重定义实证），役20 起 skip 留账
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
  let mut strict_gap = 0 // 影子缺口（役25 双判）：宽容零错而严格翻脸的 pos/eval
  let skip_names : Array[String] = [] // skip 名单（役25 名单冻结钉）
  let mut lines_total = 0 // tsv 非空行（闭合钉分母）
  let mut unknown_kind = 0 // kind 词表外静默落 pos 桶的行（恒钉 0）
  for line in tsv.split("\n") {
    if line.is_empty() {
      continue
    }
    lines_total = lines_total + 1
    let parts : Array[StringView] = line.split("\t").collect()
    let kind = parts[0]
    let path = parts[1]
    if kind == "skip" {
      skip_names.push(path.to_owned())
      continue
    }
    if kind != "neg" && kind != "pos" && kind != "eval" {
      unknown_kind = unknown_kind + 1
      debug("UNKNOWN-KIND \{path} kind=\{kind}")
    }
    let data = @fs.read_file("\{dir}/\{path}").binary().to_array()
    let sec = data[:]
    let engine = N3Engine::from_bytes(data)
    let slice = N3SliceParser::new(engine, sec, lenient=true)
    let (quads, perrs) = slice.parse_all()
    // 影子扫描（役25 R-07 双判·题6=A）：严格组装校验重跑，主判定链口径不变
    if kind != "neg" && perrs.length() == 0 {
      let slice_s = N3SliceParser::new(N3Engine::from_bytes(data), sec)
      let (_, perrs_s) = slice_s.parse_all()
      if perrs_s.length() > 0 {
        strict_gap = strict_gap + 1
        debug("STRICT-GAP \{path}")
        for err in perrs_s {
          debug("  S: \{err}")
        }
      }
    }
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
    "=== N3Tests parser sweep: neg \{neg_ok}ok/\{neg_miss}miss, pos+eval \{pos_ok}clean \{pos_mat_only}mat-only \{pos_parse_fail}parse-fail, strict-gap \{strict_gap} ===",
  )
  // 役20 负例缺口 3 收口（三案三裁断）：
  // ① thisadoc——`this` 套件 deprecated（manifest 判负口径），引擎归位点晋升
  //    门拒之（kw_ledger_hits 门加 is_deprecated_this），永保 Unknown 无表行
  //    → perr，错误落使用点；② qname-as-prefix-in-decl——声明名带本地部，
  //    物化器账本验形门（materialize_all 入口，声明名末字节须 `:`）零 quad
  //    也报 merr；③ bad_prefix2——役17 误诊纠偏：真因是前缀重定义（manifest
  //    注释），非 `:bad:o` 空前缀（兄弟正例 good_prefix.n3 同 token
  //    rdft:Approved 铁证）；重定义后者胜是 cwm/Turtle 官方语义（正例
  //    qvars/path2/prefix_reassigned_and_used 实证），测试本身 rdft:Rejected
  //    → 索引改 skip 留账，不实现被 WG 否决的规则。
  // 役17 物化残差 2（path 家族）役18 清账：真根因 = 词法 `^` 门把单 `^` 当
  // `^^` 门字节，`"lit"^:prop` 整段胶进字面量 span，引擎收不到 Caret 事件。
  // 解胶后路径 desugar（役3 ADR-006）+ 役18 path_obj_close 双发纠偏（外层
  // 语句随跳边双发，旧径只发跳边、外层语句被后续语句覆写静默丢失），
  // path2/caret_pos 翻 clean，物化残差清零（pos_mat_only = 0）。
  assert_eq(pos_parse_fail, 0)
  assert_eq(neg_miss, 0) // 役20 收口钉：负例缺口清零
  assert_eq(neg_ok, 23) // 24 负例 −1 skip（bad_prefix2）
  // 役18 收官钉：物化残差清零闭环
  assert_eq(pos_mat_only, 0)
  // 役25 证据面钉：绝对计数 + 名单冻结 + 桶闭合
  assert_eq(pos_ok, 205) // 190 pos + 15 eval 全净
  assert_eq(skip_names, [
    "cwm_other/rdfcore-tests.n3", // >100KB 机器聚合料，parser 裁决价值零
     "extra/bad_prefix2.n3", // rdft:Rejected（役20 翻案 skip 留账）
  ])
  assert_eq(unknown_kind, 0) // kind 词表外行静默落 pos 桶——词表扩容须显式改钉
  assert_eq(
    neg_ok +
    neg_miss +
    pos_ok +
    pos_mat_only +
    pos_parse_fail +
    skip_names.length(),
    lines_total,
  ) // 桶闭合：tsv 每行恰落一桶（或 skip），drift 即红
  // 影子基线钉（役25 双判·2026-09-11）：205 正/eval 里 136 文件宽容零错而严格
  // 组装校验翻脸——绝对主因 validate_prefname "前缀必须先声明" 门 vs N3/cwm
  // 生态事实（内建前缀 log:/string:/... 预绑定 + 隐式空前缀，官方正例
  // good_prefix.n3 也翻）；次因 `<=` raw 谓词（ADR-005 操作符=谓词身份）被
  // validate_pred 拒。两族均系真缺口，另立小役修口（R-07 风险节纪律：不为绿
  // 回退 lenient）——基线冻结，缺口收窄也须显式翻新本钉
  assert_eq(strict_gap, 123)
}
