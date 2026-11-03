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
/// good files additionally require emits.length >= quads.length
///（U5 官方律松绑，trig 同款：壳 quad 产主行+reifies 行，emit ≥ quad）
fn n3_suite_verdict(
  is_bad : Bool,
  perr_count : Int32,
  emits : Array[@nquads.QuadEmit],
  merrs : Array[ParseError],
  quad_count : Int32,
) -> Bool {
  // 役17：mat_deferred 两档豁免退役（桶清零，成员全数升格 n3_legal），二元裁定
  if is_bad {
    perr_count + merrs.length() > 0
  } else {
    perr_count == 0 && merrs.length() == 0 && emits.length() >= quad_count
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
  pin~ : Bool = false,
  rdf12~ : Bool = true, // 语法版本（对齐 nquads 口径）：true = RDF 1.2（方向后缀放行 + 转义代理全禁）；false = 1.1 严格契约
  expect_pass~ : Int32 = -1, // 役25 绝对计数钉（-1 不钉）：files 漂移即红
  expect_strict_gap~ : Int32 = -1, // 影子扫描缺口基线（-1 不钉；清零后升格主判定）
) -> Unit {
  let files = @fs.readdir(test_dir, sort=true).filter(fn(x) {
    x.has_suffix(suffix) && !x.has_prefix("manifest")
  })
  let mut passed = 0
  let mut failed = 0
  let mut strict_gap = 0 // 影子缺口：宽容零错而严格翻脸的 good 文件（C-07 实证位）
  for file in files {
    let is_bad = n3_suite_is_bad(file) && !n3_suite_n3_legal(file)
    let data = @fs.read_file("\{test_dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = N3Engine::from_bytes(data)
    // R-16 升格（2026-09-13）：主判定链改走**严格**组装校验（影子缺口已清零）
    let slice = N3SliceParser::new(engine, sec)
    let (quads, perrs) = slice.parse_all()
    // 影子扫描（役25 R-07 双判·题6=A）：lenient=false 严格组装校验同文件重跑。
    // 主判定链仍走宽容口径（套件数字不变硬约束）；影子只暴露被 lenient 掩盖
    // 的校验层缺口（mat 层四门不受 lenient 影响，影子面恒在 parse 层）——
    // 基线钉冻结，真缺口清零后把 expect_strict_gap 升 0 并考虑升格主判定
    // 反向哨兵：宽容口径重跑（结构上不应比严格多报；钉 0）
    let slice_s = N3SliceParser::new(
      N3Engine::from_bytes(data),
      sec,
      lenient=true,
    )
    let (_, perrs_s) = slice_s.parse_all()
    if !is_bad && perrs.length() == 0 && perrs_s.length() > 0 {
      strict_gap = strict_gap + 1
      debug("STRICT-GAP \{label}/\{file}")
      for err in perrs_s {
        debug("  S: \{err}")
      }
    }
    let mat = N3Materializer::new(
      sec,
      slice.engine.ctx.prefixes,
      bases=slice.engine.ctx.bases,
      base_fallback=Some("\{suite_base}\{file}"),
      rdf12~,
    )
    let (emits, merrs) = mat.materialize_all(quads)
    let ok = n3_suite_verdict(
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
  debug(
    "=== \{label}: \{passed}/\{passed + failed} (failed \{failed}, strict-gap \{strict_gap}) ===",
  )
  if pin {
    // closure pin: zero failures, full-set coverage
    assert_eq(failed, 0)
    assert_eq(passed + failed, files.length())
  }
  // 役25 绝对计数钉：closure 钉是自洽恒真式（新增 good 文件不红），清单冻结
  // 靠绝对数——加文件/删文件/翻面全部立即红
  if expect_pass >= 0 {
    assert_eq(passed, expect_pass)
  }
  if expect_strict_gap >= 0 {
    assert_eq(strict_gap, expect_strict_gap)
  }
}

///|
async test "W3C turtle suite: rdf11 + rdf12 syntax (pinned)" {
  run_n3_suite(
    ".rdf-tests/n3v2/rdf-turtle",
    ".ttl",
    "rdf-turtle",
    "http://www.w3.org/2013/TurtleTests/",
    pin=true,
    rdf12=false,
    expect_pass=316,
    expect_strict_gap=0, // R-16 修口后清零（2026-09-13）
  )
  run_n3_suite(
    ".rdf-tests/n3v2/rdf12/rdf-turtle/syntax",
    ".ttl",
    "rdf12-turtle",
    "https://w3c.github.io/rdf-tests/rdf12/rdf-turtle/syntax/",
    pin=true,
    rdf12=true,
    expect_pass=75,
    expect_strict_gap=0, // 影子零缺口（rdf12 语料无未声明前缀/操作符谓词）
  )
}

// ============================================================
// U5：Turtle 1.2 eval 经 N3 链再入（第二实现 oracle 轮）
// ------------------------------------------------------------

///|
/// 行内锚点后第一个 `<...>` 提取（U4 trig runner 同款本地复刻——测试件不跨包）
fn n3_angle_after(line : String, anchor : String) -> String? {
  let anchor_units = anchor.length()
  let mut i = 0
  let units = line.length()
  while i < units {
    if line[i] == anchor[0] {
      let mut j = 0
      let mut hit = true
      while j < anchor_units {
        if line[i + j] != anchor[j] {
          hit = false
          break
        }
        j += 1
      }
      if hit {
        let mut k = i + anchor_units
        while k < units && line[k] != '<' {
          k += 1
        }
        if k < units {
          let mut e = k + 1
          while e < units && line[e] != '>' {
            e += 1
          }
          if e < units {
            return Some(line[k + 1:e].to_owned())
          }
        }
      }
    }
    i += 1
  }
  None
}

///|
/// 行槽词项原文（span 视图 → String）
fn n3_quad_text(view : ArrayView[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(view))
}

///|
/// U5 前哨：turtle12 eval 经 N3 链——manifest 驱动（rdft:TestTurtleEval），
/// N3Engine → N3SliceParser → N3Materializer → 行四元组 → 与期望 .nt
/// rows_isomorphic 对拍。摸底不 pin——先出失败谱定 charter 裁决
/// （官方律全量移植 vs deferred 逐条立案）。
async fn run_n3_turtle12_eval(
  test_dir : String,
  label : String,
  pin~ : Bool = false,
) -> Unit {
  let text = @fs.read_file("\{test_dir}/manifest.ttl").text()
  let cases : Array[(String, String)] = []
  let mut cur_action = ""
  let mut cur_result = ""
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    let mut k = 0
    let units = line.length()
    while k < units && line[k] == ' ' {
      k += 1
    }
    if k < units && line[k] == '#' {
      continue
    }
    if k == 0 && line.contains("rdft:TestTurtleEval") {
      cur_action = ""
      cur_result = ""
      continue
    }
    match n3_angle_after(line, "mf:action") {
      Some(v) => cur_action = v
      None => ()
    }
    match n3_angle_after(line, "mf:result") {
      Some(v) => cur_result = v
      None => ()
    }
    if cur_action != "" && cur_result != "" {
      cases.push((cur_action, cur_result))
      cur_action = ""
      cur_result = ""
    }
  }
  let mut passed = 0
  let mut failed = 0
  let mut detail = ""
  for case in cases {
    let action_file = case.0
    let result_file = case.1
    let data = @fs.read_file("\{test_dir}/\{action_file}").binary().to_array()
    let sec = data[:]
    let engine = N3Engine::from_bytes(data)
    let slice = N3SliceParser::new(engine, sec, lenient=true)
    let (quads, perrs) = slice.parse_all()
    let mat = N3Materializer::new(
      sec,
      slice.prefixes(),
      bases=slice.bases(),
      base_fallback=Some(
        "https://w3c.github.io/rdf-tests/rdf/rdf12/rdf-turtle/eval/",
      ),
      rdf12=true,
    )
    let (emits, merrs) = mat.materialize_all(quads)
    if perrs.length() > 0 || merrs.length() > 0 {
      failed += 1
      detail = "\{detail}\{label}/\{action_file}: parse \{perrs.length()} mat \{merrs.length()} err\n"
      if perrs.length() > 0 {
        detail = "\{detail}  perr0=\{perrs[0].message()}\n"
      }
      if merrs.length() > 0 {
        detail = "\{detail}  merr0=\{merrs[0].message()}\n"
      }
      continue
    }
    let got_rows : Array[(String, String, String, String)] = emits.map(fn(q) {
      (
        n3_quad_text(q.g_view),
        n3_quad_text(q.s_view),
        n3_quad_text(q.predicate),
        n3_quad_text(q.o_view),
      )
    })
    let exp_data = @fs.read_file("\{test_dir}/\{result_file}")
      .binary()
      .to_array()
    let exp_sec = exp_data[:]
    let exp_engine = @nquads.NQuadsEngine::new(@nquads.Lexermoon::new(exp_sec))
    let exp_slice = @nquads.SliceParser::new(exp_engine, exp_sec, lenient=false)
    let (exp_quads, exp_errs) = exp_slice.parse_all()
    if exp_errs.length() > 0 {
      failed += 1
      detail = "\{detail}\{label}/\{action_file}: expected file unparsable\n"
      continue
    }
    let exp_mat = @nquads.materialize_all(exp_quads)
    let exp_rows : Array[(String, String, String, String)] = exp_mat.0.map(fn(
      q,
    ) {
      (
        n3_quad_text(q.g_view),
        n3_quad_text(q.s_view),
        n3_quad_text(q.predicate),
        n3_quad_text(q.o_view),
      )
    })
    let mut same = false
    let mut iso_err = ""
    try {
      same = @nquads.rows_isomorphic(got_rows, exp_rows)
    } catch {
      _ => iso_err = " (iso raise)"
    }
    if same {
      passed += 1
    } else {
      failed += 1
      detail = "\{detail}\{label}/\{action_file}: not isomorphic\{iso_err}\n"
    }
  }
  debug("=== \{label}: \{passed}/\{passed + failed} (failed \{failed}) ===")
  if pin {
    // closure pin: zero failures, full-set coverage（trig U3c 同款）
    assert_eq(passed + failed, cases.length())
    assert_eq(failed, 0)
  }
  if detail != "" {
    debug(detail)
  }
}

///|
async test "U5：turtle12 eval 经 N3 链（第二实现 oracle，pin）" {
  run_n3_turtle12_eval(
    ".rdf-tests/trig/rdf12/rdf-turtle/eval",
    "n3-turtle12-eval",
    pin=true,
  )
}
