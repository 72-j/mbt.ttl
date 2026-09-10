// ===== W3C rdf-turtle official suite runner (clone of gen_trig/rdf_suite_wbtest.mbt, graph axis retired) =====
// Verdict (skeleton syntax + materialization gates, full chain):
//   Axis deltas vs trig runner: N3 has no graph-block syntax and no dialect knob
//   (N3 engine has no graph states at all; the table has no edges for graph blocks
//   so they reject naturally). is_bad = name contains "-bad" only -- the 3 trig
//   graph-position exceptions do not apply (turtle suite has no graph-position cases).
//   役6 豁免：turtle 负例、N3 方言正例（n3_suite_n3_legal）——verdict 反转为
//   good（零错 + emits==quads），全量闭包不动。
//   bad  -> must error somewhere on the chain (parse or materialize, incl. deep gates)
//   good -> zero errors AND emits.length == quads.length (every parsed quad survives)
// First sweep: failures print only (no assert) to bucket gaps into (deferred feature /
// true bug); entries below pinned (failed==0, full-set closure) after bucketing.

///|
/// Negative verdict: name contains "-bad" (no graph-position exceptions for N3)
fn n3_suite_is_bad(name : String) -> Bool {
  name.contains("-bad")
}

///|
/// Turtle 负例、N3 方言正例豁免（役6）：W3C turtle 负例清单里混着 N3 扩展
/// 语法——对 TURTLE 非法，对 gen_n3 的 N3 方言合法。倒装 `is..of` 役6 起
/// 正解出账（此前靠 of 无行 recover 撞进负例契约，属误收编的副产物）。
/// 命中者 verdict 反转为 good（零错 + emits==quads），套件全量闭包不动。
fn n3_suite_n3_legal(name : String) -> Bool {
  // :z is :p of :x . ≡ (:x,:p,:z)——倒装役6
  name == "turtle-syntax-bad-n3-extras-05.ttl" ||
  // :x^ns:p :p :z .（N3 路径）——役14 主位尾随正形：主语 = 路径节点
  // `:x^ns:p`，真谓词 `:p`，宾语 `:z`（Turtle 非法、N3 合法）
  name == "turtle-syntax-bad-n3-extras-04.ttl" ||
  // :a = :b . ≡ (:a, owl:sameAs, :b)——等同役7
  name == "turtle-syntax-bad-n3-extras-02.ttl" ||
  // <s> = <o> .（文件自注 "Turtle is not N3"）——同一语义的全 IRI 版
  name == "turtle-syntax-bad-struct-02.ttl" ||
  // 役10 词位扩展：N3 grammar verb ::= expression，官方 bad-preds-* 翻案
  // PositiveSyntax——以下 Turtle 非法、N3 合法（ADR-001 单向超集），verdict
  // 反转 good（零错 + emits==quads，物化臂随役10 就位）：
  // true 作主语/谓词（词法折 Literal 事件）
  name == "turtle-syntax-bad-kw-05.ttl" ||
  // 字面量作谓词（mat raw 臂原文保真）
  name == "turtle-syntax-bad-struct-05.ttl" ||
  name == "turtle-syntax-bad-struct-15.ttl" ||
  // `[]` 作谓词（mat raw 臂）
  name == "turtle-syntax-bad-struct-06.ttl" ||
  name == "turtle-syntax-bad-struct-16.ttl" ||
  // `:x .` 零谓词语句链（收口行零发射，emits==quads==1 白得过）
  name == "turtle-syntax-bad-n3-extras-03.ttl" ||
  name == "turtle-syntax-bad-n3-extras-06.ttl" ||
  // @forSome/@forAll 量化指令（役13：指令头接表）——Turtle 非法、N3 正典
  name == "turtle-syntax-bad-n3-extras-11.ttl" ||
  name == "turtle-syntax-bad-n3-extras-12.ttl" ||
  // 役17 物化臂就位（verdict 全净反转，mat_deferred 桶清零退役）：
  // "hello"/"abc" 字面量主语（主语位 expression 臂）
  name == "turtle-syntax-bad-struct-04.ttl" ||
  name == "turtle-syntax-bad-struct-14.ttl" ||
  // { :a :q :c . } 公式主语（ADR-002 GraphTerm 不透明，mat 层配对扫描）
  name == "turtle-syntax-bad-n3-extras-01.ttl" ||
  // :s <= :o . 反向蕴含谓词（log:impliedBy 原文保真，先于 IRI 臂裁决）
  name == "turtle-syntax-bad-n3-extras-10.ttl" ||
  // true 作主语（升格自 mat_deferred：布尔主语臂就位）
  name == "turtle-syntax-bad-kw-04.ttl" ||
  // :s => :o . 规则蕴含谓词（升格自 mat_deferred：`=` raw 臂就位）
  name == "turtle-syntax-bad-n3-extras-09.ttl" ||
  // 役17 隐式空前缀绑定：`:a :b :c .` 无 @prefix : 声明——Turtle 非法、
  // cwm 传统 N3 合法（Team Submission "behaves as though there were a
  // @prefix : <#> just before the file"）
  name == "turtle-syntax-bad-prefix-01.ttl" ||
  name == "turtle-syntax-bad-prefix-02.ttl"
}

///|
/// Unified verdict: parse errors + materializer errors (incl. deep gates) merged;
/// good files additionally require emits.length == quads.length
fn n3_suite_verdict(
  name : String,
  is_bad : Bool,
  perr_count : Int,
  emits : Array[@nquads.QuadEmit],
  merrs : Array[ParseError],
  quad_count : Int,
) -> Bool {
  // 役17：mat_deferred 两档豁免退役（桶清零，成员全数升格 n3_legal），二元裁定
  if is_bad {
    perr_count + merrs.length() > 0
  } else {
    perr_count == 0 && merrs.length() == 0 && emits.length() == quad_count
  }
}

///|
/// Run one suite directory: list files, per-file full chain, verdict, tally.
/// manifest* = suite control files (W3C harness entry lists), not test cases;
/// excluded at the filter layer (trig: its rdfs:comment carries an illegal \x
/// escape as documentation -- treating control files as data is a category error).
/// pin=true: assert failed==0 AND passed+failed==files.length() (full-set closure).
async fn run_n3_suite(
  test_dir : String,
  suffix : String,
  label : String,
  suite_base : String,
  pin? : Bool = false,
  scalar_only? : Bool = false, // RDF 1.2: surrogate escapes banned outright (pairs too)
) -> Unit {
  let files = @fs.readdir(test_dir, sort=true).filter(fn(x) {
    x.has_suffix(suffix) && !x.has_prefix("manifest")
  })
  let mut passed = 0
  let mut failed = 0
  for file in files {
    let is_bad = n3_suite_is_bad(file) && !n3_suite_n3_legal(file)
    let data = @fs.read_file("\{test_dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = N3Engine::from_bytes(data)
    let slice = N3SliceParser::new(engine, sec, lenient=true)
    let (quads, perrs) = slice.parse_all()
    let mat = N3Materializer::new(
      sec,
      slice.engine.ctx.prefixes,
      bases=slice.engine.ctx.bases,
      base_fallback=Some("\{suite_base}\{file}"),
      scalar_only_escapes=scalar_only,
    )
    let (emits, merrs) = mat.materialize_all(quads)
    let ok = n3_suite_verdict(
      file,
      is_bad,
      perrs.length(),
      emits,
      merrs,
      quads.length(),
    )
    if ok {
      passed = passed + 1
    } else {
      failed = failed + 1
      debug("FAIL \{label}/\{file} p=\{perrs.length()} m=\{merrs.length()}")
      for err in perrs {
        debug("  P: \{err}")
      }
      for err in merrs {
        debug("  M: \{err}")
      }
    }
  }
  debug("=== \{label}: \{passed}/\{passed + failed} (failed \{failed}) ===")
  if pin {
    // closure pin: zero failures, full-set coverage
    assert_eq(failed, 0)
    assert_eq(passed + failed, files.length())
  }
}

///|
async test "W3C turtle suite: rdf11 + rdf12 syntax (pinned)" {
  run_n3_suite(
    "src/gen_n3v2/rdf-tests/rdf-turtle",
    ".ttl",
    "rdf-turtle",
    "http://www.w3.org/2013/TurtleTests/",
    pin=true,
  )
  run_n3_suite(
    "src/gen_n3v2/rdf-tests/rdf12/rdf-turtle/syntax",
    ".ttl",
    "rdf12-turtle",
    "https://w3c.github.io/rdf-tests/rdf12/rdf-turtle/syntax/",
    pin=true,
    scalar_only=true,
  )
}
