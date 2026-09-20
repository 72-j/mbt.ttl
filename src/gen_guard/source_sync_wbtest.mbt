// ===== 跨包结构钉子（T17 / C-T8）：把"源同步"与"裁定表"从**人判**变**门判** =====
//
// 背景（2026-09-20 评审）：抽件后的"逐字同源"若只写在 ADR / 裁定表里，就只是"新旧册"——
// 本门把它钉成三条**可执行**事实（世界宪法 §6.2.2 结构钉子 + 反向断言）：
//   ① **源同步**：14 项纯函数在 `gen_shared` 各**有且仅有一处**定义；两包**不再有**本地定义（防回潮）；
//      两包**各自**至少一处调用（防"只为某一方言所用"退化）。
//   ② **裁定表对齐**：裁定表（`../gen_trig/spec.md` §7.1）必须**点名**两个名单的每一项 ⇒ 人写表 vs 门读名单同笔。
//   ③ **覆盖边界**：复核面账（`suite-review.txt` 表头）必须写明**覆盖什么 / 不覆盖什么**。

///|
/// 抽件名单（14 项纯函数自两包装配层抽入 `gen_shared`）。
/// 钉子三向：① `gen_shared` 各**有且仅有一处** `pub fn <name>(`；② 两包**任何** `.mbt`（含 `_wbtest`）
/// 都**不再有**本地定义（防回潮）；③ 两包**各自**至少一处调用（防"只为某一方言所用"退化）。
fn extracted_names() -> Array[String] {
  [
    "deep_check_literal", "deep_check_tt", "literal_body_end", "is_pn_local_esc",
    "check_iri_view", "check_bnode_view", "tt_bool_word", "is_scheme_byte", "view_has_scheme",
    "eq_ignore_case", "eq_lower", "at_style_kw", "triple_term_inner_terms", "slice_span",
  ]
}

///|
/// 有意分叉名单（**两包各自本地定义**，不抽件；逐条理由见 `../gen_trig/spec.md` §7.1）。
/// 钉子：每项在**两包**都能找到 `fn <name>(`（`impl` 形用子串匹配）；且与抽件名单**不相交**。
fn forked_names() -> Array[String] {
  [
    "classify_structural", "validate_term", "prefix_declared", "classify_prefname",
    "span_of_event", "ctx_span", "list_top", "message", "bytes_of",
  ]
}

///|
/// 钉子扫描的文件清单（子仓根为基；缺文件即 panic ⇒ 改名/删除会被本门抓到）。
fn n3_files() -> Array[String] {
  [
    "src/gen_n3v2/actions.mbt", "src/gen_n3v2/engine.mbt", "src/gen_n3v2/lexer_adapter.mbt",
    "src/gen_n3v2/materialize_n3.mbt", "src/gen_n3v2/parser_slice.mbt", "src/gen_n3v2/serialize_n3.mbt",
    "src/gen_n3v2/types.mbt", "src/gen_n3v2/probe.mbt", "src/gen_n3v2/engine_wbtest.mbt",
    "src/gen_n3v2/materialize_n3_wbtest.mbt", "src/gen_n3v2/examples_wbtest.mbt",
  ]
}

///|
fn trig_files() -> Array[String] {
  [
    "src/gen_trig/actions.mbt", "src/gen_trig/engine.mbt", "src/gen_trig/lexer_adapter.mbt",
    "src/gen_trig/materialize_trig.mbt", "src/gen_trig/parser_slice.mbt", "src/gen_trig/serialize_trig.mbt",
    "src/gen_trig/types.mbt", "src/gen_trig/probe.mbt", "src/gen_trig/trig_wbtest.mbt",
    "src/gen_trig/materialize_trig_wbtest.mbt", "src/gen_trig/rdf_suite_wbtest.mbt",
  ]
}

///|
fn shared_files() -> Array[String] {
  [
    "src/gen_shared/materialize_common.mbt", "src/gen_shared/lexer_common.mbt", "src/gen_shared/parse_common.mbt",
    "src/gen_shared/types_common.mbt",
  ]
}

///|
/// 文本里 `fn <name>(` 的出现次数（不区分 `pub` / `priv` / `impl … with` 前缀）。
fn def_count(text : String, name : String) -> Int {
  text
  .split("\n")
  .iter()
  .filter(fn(l) { l.contains("fn " + name + "(") })
  .count()
}

///|
/// 文本里**调用点**计数（`<name>(`，排除定义行）。
fn call_count(text : String, name : String) -> Int {
  text
  .split("\n")
  .iter()
  .filter(fn(l) { l.contains(name + "(") && !l.contains("fn " + name + "(") })
  .count()
}

///|
async test "T17 源同步钉子：抽件一处定义 + 两包零本地定义（防回潮）+ 双向消费者" {
  let b_shared = StringBuilder()
  for p in shared_files() {
    b_shared.write(@fs.read_file(p).text())
    b_shared.write("\n")
  }
  let shared = b_shared.to_string()
  let b_n3 = StringBuilder()
  for p in n3_files() {
    b_n3.write(@fs.read_file(p).text())
    b_n3.write("\n")
  }
  let n3 = b_n3.to_string()
  let b_trig = StringBuilder()
  for p in trig_files() {
    b_trig.write(@fs.read_file(p).text())
    b_trig.write("\n")
  }
  let trig = b_trig.to_string()
  let names = extracted_names()
  assert_eq(names.length(), 14) // 数字钉子（抽件名单规模）
  for name in names {
    // ① gen_shared：有且仅有一处定义（抽件未被复制）
    assert_eq(def_count(shared, name), 1)
    // ② 两包：**零**本地定义（抽件后若又长出副本即红 —— 防回潮）
    assert_eq(def_count(n3, name), 0)
    assert_eq(def_count(trig, name), 0)
    // ③ 消费者（两条，口径见下）：
    //    ① **非死件**：两包 + 共享内部合计至少一处调用；
    //    ② **防单方言化**：要么**共享内部**消费（`view_has_scheme`/`tt_bool_word` 这类**共享叶子件**），
    //       要么**两包各自**都有消费者 —— "只被一个方言调用"即红。
    let c_n3 = call_count(n3, name)
    let c_trig = call_count(trig, name)
    let c_shared = call_count(shared, name)
    assert_true(c_n3 + c_trig + c_shared > 0)
    assert_true(c_shared > 0 || (c_n3 > 0 && c_trig > 0))
  }
}

///|
async test "T17 裁定表钉子：分叉项两包各自在册 + 名单正交 + 与 spec §7.1 同笔" {
  let b_n3 = StringBuilder()
  for p in n3_files() {
    b_n3.write(@fs.read_file(p).text())
    b_n3.write("\n")
  }
  let n3 = b_n3.to_string()
  let b_trig = StringBuilder()
  for p in trig_files() {
    b_trig.write(@fs.read_file(p).text())
    b_trig.write("\n")
  }
  let trig = b_trig.to_string()
  let forked = forked_names()
  assert_eq(forked.length(), 9) // 数字钉子（分叉名单规模）
  for name in forked {
    // 分叉项：**两包各自本地定义**（有意分叉，不抽件）
    assert_true(def_count(n3, name) > 0)
    assert_true(def_count(trig, name) > 0)
  }
  // 名单正交（抽件 ∩ 分叉 = ∅）
  for name in extracted_names() {
    assert_true(!forked.contains(name))
  }
  // **人写的裁定表**必须点名两个名单的每一项（否则裁定表 = 新旧册）
  let spec = @fs.read_file("src/gen_trig/spec.md").text()
  assert_true(spec.contains("### 7.1 T17 双包重复**裁定表**"))
  for name in extracted_names() {
    assert_true(spec.contains("`" + name + "`"))
  }
  for name in forked {
    assert_true(spec.contains("`" + name + "`"))
  }
}

///|
async test "复核面账钉子：覆盖边界必须写明（覆盖什么 / 不覆盖什么）" {
  let table = @fs.read_file("suite-review.txt").text()
  assert_true(table.contains("# 覆盖边界"))
  assert_true(table.contains("不覆盖"))
  // 边界必须点名"本面不覆盖"的两类（IR/产物面、覆盖率面）——防读者误以为面覆盖全部
  assert_true(table.contains("IR/产物"))
  assert_true(table.contains("覆盖率"))
}
