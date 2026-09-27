// 来源与许可（统一形；详见 `THIRD_PARTY_NOTICES.md`）：
//   ① W3C rdf-tests 双许可（W3C Test Suite License + 3-clause BSD）——xsd 词法边界参照；
//   ② Apache Jena（SPDX: Apache-2.0）——间接参照（langtag 电池与 xsd 形态）；
//   ③ Oxigraph（SPDX: MIT OR Apache-2.0）——`oxsdatatypes` 的 float/decimal/integer 词法边界（形态参考，不引实现）。
//
// 定位（2026-09-27）：本件直测**数值/布尔识别的单一实现**（`gen_nquads/numeric.mbt`：`is_numeric_span` /
// `is_boolean_word`）——即 ADR-NQ-011 / C-15 的"单源面"直接覆盖；经物化器之后的端到端仍由各包 conformance 件负责
// （如 `gen_trig/literal_conformance_wbtest.mbt`）。**两件各测各的面，不重复断言。**
//
// ⚠ 待补（如实记）：`expand_*`（词形→值展开）在 nquads 侧**未找到同名函数**（ADR-NQ-011 注"展开件留驻各物化层"）
// ⇒ 本件只覆盖**识别**面；展开面的 conformance 待定位其实现件后再立。

///|
/// 断言 `s` 的整串被视为数值（off=0, len=全长）
fn num(s : String) -> Bool {
  // `@utf8.encode` 给 Bytes；`is_numeric_span` 收 **ArrayView**（见 ADR-NQ-011 单一实现签名），
  // 故按 bench/examples 已实证的转换形走：Bytes → fixedarray → Array → view。
  let arr = Array::from_fixed_array(@utf8.encode(s).to_fixedarray())
  is_numeric_span(arr[:], 0, arr.length())
}

///|
/// 断言 `s` 的整串被视为布尔词
fn boolw(s : String) -> Bool {
  let arr = Array::from_fixed_array(@utf8.encode(s).to_fixedarray())
  is_boolean_word(arr[:], 0, arr.length())
}

///|
test "单源：整数/小数/双精度词形（xsd 词法，正例）" {
  for
    s in [
      "0", "+0", "-0", "1", "+1", "-1", "1234567890",
      // xsd decimal：(\+|-)?([0-9]+(\.[0-9]*)?|\.[0-9]+)
       "1.0", "-0.0", ".5", "1.", "0.0000001",
      // xsd double：小数部分 + ([Ee](\+|-)?[0-9]+)?
       "1E0", "1e0", "+1E-3", "-1e+3", ".5e2", "1.E2",
    ] {
    assert_true(num(s))
  }
}

///|
test "单源：非数值词形（xsd 词法，负例）" {
  for
    s in [
      // ⚠ 空串 `""` **故意不列**：实测 `is_numeric_span` 在 len=0 时 **panic**（`ArrayView::at` 越界）
      // ⇒ 单一实现**未防零长**；消费面不传零长（词法保证），本件不钉未定义行为——**已入册为边界声明**。
      // ⚠ 一字符 `+` / `-` / `.` 同样**不列**：实测亦 panic（同族：实现按 `data[off±1]` 直接索引，
      // 未防**零/一长**）⇒ 消费面传的是词法切分后的**完整词项**（≥2 字节），生产路径不触；入册为边界声明。
      // ⚠ **B 笔清单（实现未兑现自身文档口径；2026-09-27 点名实测）**：`1e` / `1e+` / `++1` / `--1` / `1.2.3`
      //   三者 `is_numeric_span` 皆判 true，但该函数**头注自述口径**为
      //   `[+-]?([0-9]+('.'[0-9]*)? | '.'[0-9]+)([eE][+-]?[0-9]+)?` ⇒ 三者按自述皆非数值。
      //   ⇒ **性质 = 实现偏宽缺陷（非"有意宽松识别"）**：现实现只做"首字节 ∈ {+,-,.,digit} + 字符集 + 至少一数字"，
      //   **未做结构校验**（符号重复 / 小数点重复 / 空指数）。**B 笔单独修**（影响 adapter/校验/物化三面 ⇒ 须全量回归）。
      // ⚠ 另有待裁项：
      //   `is_numeric_span("1e") == true` —— 但 xsd `double` 的指数部分**必须有数字**
      //   （`([Ee](\+|-)?[0-9]+)?`）⇒ `1e` 按 xsd 非数值。**待裁**：是"识别面有意宽（严格性交展开/校验面）"
      //   还是"实现偏宽缺陷"。同族候选：`1e+`（亦带空指数）。裁决后再回到负例集。
      "1e", "1e+", "++1", "--1", "1.2.3", "e1", "0x10", "1,0", "1_000", "١٢٣",
      "abc", "tru",
    ] {
    if num(s) {
      fail("非数值词形被误判为数值: <\{s}>") // 点名式：失败即报输入（防"循环吞名"）
    }
  }
}

///|
test "单源：布尔词（xsd，正例）——仅词形 true/false" {
  assert_true(boolw("true"))
  assert_true(boolw("false"))
  // ⚠ 待核（未读实现，禁猜）：`1`/`0` 与大小写变体（`True`/`TRUE`）是否算布尔词——下一手读
  // `is_boolean_word` 后补断言或补口径。
}

///|
/// xsd 词法覆盖波（2026-09-27；**只覆盖实现面**：numeric / boolean）。数据表 + 点名断言；
/// 不覆盖未实现的 datatype（dateTime/duration…），避免"覆盖到不做的事"变假指标。
test "xsd 词法波：numeric 合法词形" {
  for
    s in [
      "0", "00", "+0", "-0", "1", "+1", "-1", "007", "1234567890", "1.0", "-0.0",
      ".5", "-.5", "1.", "0.", "1.000", "1E0", "1e0", "1E+0", "1E-0", "1e10", ".5e2",
      "1.e2", "1.5E3", "-1.5e-3", "+1.5E+3",
    ] {
    if !num(s) {
      fail("xsd 合法数值词形被拒: <\{s}>")
    }
  }
}

///|
test "xsd 词法波：numeric 非法词形" {
  for
    s in [
      // A 笔回归面：零长
      "",
      // B 笔回归面：结构残缺（符号重复 / 小数点重复 / 空指数）
       "1e", "1e+", "1e-", "++1", "--1", "+-1", "-+1", "1.2.3", "1..2", "1.0.0",
      "1e1e1", "..1",
      // 字符集外
       "e1", "E1", "0x10", "1,0", "1_000", "1 0", " 1", "1 ", "abc", "\u0661\u0662",
      // 结构不成形（纯符号/纯点）
       "+", "-", ".", "e", "-.", "+.",
    ] {
    if num(s) {
      fail("xsd 非法数值词形被收: <\{s}>")
    }
  }
}

///|
test "xsd 词法波：boolean（词形面只认 true/false，小写精确）" {
  for s in ["true", "false"] {
    if !boolw(s) {
      fail("布尔词被拒: <\{s}>")
    }
  }
  for s in ["True", "TRUE", "tru", "fals", "truee", "yes", "", "1", "0"] {
    if boolw(s) {
      fail("非布尔词被收: <\{s}>")
    }
  }
}

///|
test "xsd 词法波：1/0 的分辨（数值 ✓ / 布尔词 ✗）——口径记名" {
  // 口径：`is_boolean_word` **只认词形 true/false**；xsd 的 `1`/`0` 布尔字面量在**物化展开面**处理
  // （识别面 vs 展开面分工，见 `numeric.mbt` 头注与 ADR-NQ-011）。
  for s in ["1", "0"] {
    assert_true(num(s))
    assert_true(!boolw(s))
  }
}
