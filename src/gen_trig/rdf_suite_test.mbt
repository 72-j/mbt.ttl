// ===== W3C rdf-trig / rdf-turtle 官方测试套件（循环读文件版，参考 gen_nquads/rdf_suite_test.mbt）=====
// 判定（骨架语法口径）：
//   负例 → 必须报错；正例 → 零错误（eval 正例的 quad 数对比属物化层，阶段二再开）
//   负例 = 名字含 "-bad"；例外 3 条（manifest 逐条核实）：trig-bnodeplist-graph-01 /
//   trig-collection-graph-01 / trig-collection-graph-02（[]/() 落图位，表无边自然拒绝）
// 首轮摸底：失败只打印不阻断，缺口分桶（延后特性/真 bug）后再钉 assert

///|
/// 负例判定：名字含 "-bad" 或三个 manifest 核实的例外（[]/() 落图位负例）
fn trig_suite_is_bad(name : String) -> Bool {
  name.contains("-bad") ||
  name.contains("trig-bnodeplist-graph-01") ||
  name.contains("trig-collection-graph-01") ||
  name.contains("trig-collection-graph-02")
}

///|
/// 正/负例统一判据（④全链路化）：parse 层错误 + 物化层错误（含深验门）合并；
/// 正例加 quad 数对比——每条解析 quad 均须物化存活（emits.length == quads.length）
fn trig_suite_verdict(
  is_bad : Bool,
  perr_count : Int,
  emits : Array[@nquads.QuadEmit],
  merrs : Array[ParseError],
  quad_count : Int,
) -> Bool {
  if is_bad {
    perr_count + merrs.length() > 0
  } else {
    perr_count == 0 && merrs.length() == 0 && emits.length() == quad_count
  }
}

///|
/// deferred 桶已撤销（2026-09-04 六轮收官）：桶概念归零，详见 todo.md ★3 行。
/// 六轮：①[]/() 主桶 61 文件（★3）②lists-05/subm-01/sole 三桩 ③trig-turtle-/
/// minimal-whitespace 整族 ④免试 5 出槽（探针逐文件真跑核实）⑤三桩真堵全平
///（壳内 ~ reifier / [] 图标签 / 注解体 fresh）⑥manifest 控制文件转 harness
/// 过滤层排除——它本就不是测试用例，deferred 计数随之撤销。

///|
/// 循环读文件跑一个套件目录：列目录 → 逐文件 → 全链路判定。
/// manifest 前缀 = 套件控制文件（W3C harness 测试入口清单），非测试用例，
/// 在过滤层排除不入账——rdf11-turtle 那份 rdfs:comment 含 \x 非法转义作文档
/// 说明，当数据测是范畴错误；rdf12-turtle 那份虽可解析，同为控制文件一并排除。
/// pin=true：failed==0 且 passed+failed==files.length()（全集闭合）直接断言
async fn run_trig_suite(
  test_dir : String,
  suffix : String,
  label : String,
  suite_base : String,
  pin? : Bool = false,
  scalar_only? : Bool = false, // RDF 1.2 口径：字面量代理转义全禁（成对也不收）
  dialect? : TrigDialect = TriG, // 方言开关：Turtle 禁图块区（bad-struct-01 口径）
) -> Unit {
  let files = @fs.readdir(test_dir, sort=true).filter(fn(x) {
    x.has_suffix(suffix) && !x.has_prefix("manifest")
  })
  let mut passed = 0
  let mut failed = 0
  for file in files {
    let is_bad = trig_suite_is_bad(file)
    let data = @fs.read_file("\{test_dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = TrigEngine::from_bytes(data, dialect~)
    let slice = TrigSliceParser::new(engine, sec, lenient=true)
    let (quads, perrs) = slice.parse_all()
    // ④全链路化：parse → 物化（深验门默认开）。负例 = 链上任一环报错即成立；
    // 正例 = 链路零错 + quad 数对比（每条解析 quad 均须物化存活）
    let mat = TrigMaterializer::new(
      sec,
      slice.engine.ctx.prefixes,
      bases=slice.engine.ctx.bases,
      base_fallback=Some("\{suite_base}\{file}"),
      scalar_only_escapes=scalar_only,
    )
    let (emits, merrs) = mat.materialize_all(quads)
    let ok = trig_suite_verdict(
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
    "=== \{label}: \{passed}/\{passed + failed} (failed \{failed}) ===",
  )
  if pin {
    // 收口钉：全集闭合 + 零失败
    assert_eq(failed, 0)
    assert_eq(passed + failed, files.length())
  }
}

///|
async test "W3C 套件: 循环读文件（rdf11 已收口钉死；rdf12 摸底）" {
  run_trig_suite(
    "src/gen_trig/rdf-tests/rdf-trig",
    ".trig",
    "rdf-trig",
    "http://www.w3.org/2013/TriGTests/",
    pin=true,
  )
  run_trig_suite(
    "src/gen_trig/rdf-tests/rdf-turtle",
    ".ttl",
    "rdf-turtle",
    "http://www.w3.org/2013/TurtleTests/",
    pin=true,
    dialect=Turtle,
  )
  run_trig_suite(
    "src/gen_trig/rdf-tests/rdf12/rdf-trig/syntax",
    ".trig",
    "rdf12-trig",
    "https://w3c.github.io/rdf-tests/rdf12/rdf-trig/syntax/",
    pin=true,
    scalar_only=true,
  )
  run_trig_suite(
    "src/gen_trig/rdf-tests/rdf12/rdf-turtle/syntax",
    ".ttl",
    "rdf12-turtle",
    "https://w3c.github.io/rdf-tests/rdf12/rdf-turtle/syntax/",
    pin=true,
    scalar_only=true,
    dialect=Turtle,
  )
}
