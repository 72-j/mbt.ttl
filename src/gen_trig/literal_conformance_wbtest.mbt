// 来源与许可（统一形；详见 `THIRD_PARTY_NOTICES.md`）：
//   ① W3C rdf-tests 双许可（W3C Test Suite License + 3-clause BSD）；
//   ② Apache Jena（SPDX: Apache-2.0；仅 langtag 电池）；
//   ③ Oxigraph（SPDX: 待核；仅 literal/datatype 形态参考）。
// 授权与来源（W3C 测试套件双许可：W3C Test Suite License + 3-clause BSD，
// 见 https://www.w3.org/Consortium/Legal/2008/04-testsuite-copyright.html）：
// 本文件测试数据抽取自 w3c/rdf-tests（rdf/rdf11/rdf-trig 字面量族），本地副本
// .rdf-tests/trig/rdf-trig/（SHA256SUMS 锁版）。
// This file includes material copied from or derived from the W3C RDF 1.1 Test Suite
// (https://github.com/w3c/rdf-tests). Copyright (c) 2026 World Wide Web Consortium.
// https://www.w3.org/copyright/software-license-2023/
//
// ===== datatype 实现评估（2026-09-27 literal 役，随抽取定案）=====
// ① 裸词合成：integer/decimal/double → is_numeric_span 全词形裁决 + expand_number
//    可信构造（词形已验免深验）；lexical 保真（bareword_double "1E0" 原样出，
//    double_lower_case_e "1e0" 原样出——大小写 e 不归一）。
// ② 布尔：is_boolean_word（小写精确 true/false）+ expand_boolean → "true"^^xsd:boolean。
// ③ 显式 datatype（IRIREF/前缀名）：物化展开 + gate_literal 深验；未知型透传合法
//    （xsd:byte 套件绿），类型域校验（byte≤127 等）不做——语法层透传，域校验归应用层。
// ④ xsd:string：LiteralRef 层塌缩为 simple literal（literal.mbt 钉）；显式 rdf:langString /
//    rdf:dirLangString 禁用（is_banned_langstring_iri）——langtag 形由 @lang 合成。
// ⑤ 方向（RDF 1.2）：directional constructors 齐（BaseDirection + 契约门），rdf12 套件绿。
// ⑥ 套件口径注记：trig 套件判「零错 + 存活数」，不比 .nq 字节——本文件以 .nq 对象
//    字节对拍补上转义解码/合成的正确性实测（本役新增覆盖）。
// ⑦ 对拍口径（eval 电池钉法两分）：带引号字面量 emit = arena view 零拷贝源词形
//    保真（LITERAL1 'x' 原样出单引号；LONG 族长引号原样出）——W3C .nq 期望是规范
//    双引形，两者不同的行钉「源词形」并注记规范形，相同的行（转义族）逐字节对拍；
//    裸词（integer/decimal/double/boolean）emit = 合成 typed literal（= .nq 规范形），
//    钉 .nq 并注记源词形。架构定案：emit 不做词形归一，也不丢合成语义。
//    定案入册：`src/gen_trig/adr.md` ADR-TRIG-019。

///|
/// 字面量 eval 行驱动：全文件入 mat_chain，取第 0 条 emit 的宾语文本
/// base_fallback 镜像官方 harness：manifest BASE = 套件 base + 文件名（相对 IRI 落此）
fn litconf_first_obj(input : String, base_fallback : String?) -> String? {
  let (emits, errors) = mat_chain(input, base_fallback~)
  if errors.length() > 0 || emits.length() == 0 {
    return None
  }
  Some(mat_vs(mat_obj(emits[0])))
}

///|
// ① eval 电池：.trig 全文 → 物化宾语 与 .nq 期望对象字节对拍
// （转义族/边界族/裸词合成/显式 datatype/langtagged 全盖；emits 数 = .nq 行数；
//  base 口径同官方 manifest：BASE = http://www.w3.org/2013/TriGTests/ + 文件名）
test "w3c trig literal eval battery (object byte-exact vs .nq)" {
  let rows : Array[(String, String, Array[String])] = [
    // IRIREF_datatype
    (
      "IRIREF_datatype",
      "{<http://a.example/s> <http://a.example/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"1\"^^<http://www.w3.org/2001/XMLSchema#integer> .}\n",
      [
        "\"1\"^^<http://www.w3.org/2001/XMLSchema#integer>", "\"1\"^^<http://www.w3.org/2001/XMLSchema#integer>",
      ],
    ),
    // LITERAL1
    //   源词形保真（.nq 规范形 "\"x\""）
    //   源词形保真（.nq 规范形 "\"x\""）
    (
      "LITERAL1",
      "{<http://a.example/s> <http://a.example/p> 'x' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> 'x' .}\n",
      ["'x'", "'x'"],
    ),
    // LITERAL1_all_controls
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\u0008\\u0009\\u000B\\u000C\\u000E\\u000F\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001A\\u001B\\u001C\\u001D\\u001E\\u001F\""）
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\u0008\\u0009\\u000B\\u000C\\u000E\\u000F\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001A\\u001B\\u001C\\u001D\\u001E\\u001F\""）
    (
      "LITERAL1_all_controls",
      "{<http://a.example/s> <http://a.example/p> '\u{0}\u{1}\u{2}\u{3}\u{4}\u{5}\u{6}\u{7}\u{8}\t\u{b}\u{c}\u{e}\u{f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\u{0}\u{1}\u{2}\u{3}\u{4}\u{5}\u{6}\u{7}\u{8}\t\u{b}\u{c}\u{e}\u{f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}' .}",
      [
        "'\u{0}\u{1}\u{2}\u{3}\u{4}\u{5}\u{6}\u{7}\u{8}\t\u{b}\u{c}\u{e}\u{f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}'",
        "'\u{0}\u{1}\u{2}\u{3}\u{4}\u{5}\u{6}\u{7}\u{8}\t\u{b}\u{c}\u{e}\u{f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}'",
      ],
    ),
    // LITERAL1_all_punctuation
    //   源词形保真（.nq 规范形 "\" !\\u0022#$%&():;<=>?@[]^_`{|}~\""）
    //   源词形保真（.nq 规范形 "\" !\\u0022#$%&():;<=>?@[]^_`{|}~\""）
    (
      "LITERAL1_all_punctuation",
      "{<http://a.example/s> <http://a.example/p> ' !\"#$%&():;<=>?@[]^_`{|}~' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> ' !\"#$%&():;<=>?@[]^_`{|}~' .}\n",
      ["' !\"#$%&():;<=>?@[]^_`{|}~'", "' !\"#$%&():;<=>?@[]^_`{|}~'"],
    ),
    // LITERAL1_ascii_boundaries
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0009\\u000B\\u000C\\u000E\\u0026\\u0028\\u005B\\u005D\\u007F\""）
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0009\\u000B\\u000C\\u000E\\u0026\\u0028\\u005B\\u005D\\u007F\""）
    (
      "LITERAL1_ascii_boundaries",
      "{<http://a.example/s> <http://a.example/p> '\u{0}\t\u{b}\u{c}\u{e}&([]\u{7f}' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\u{0}\t\u{b}\u{c}\u{e}&([]\u{7f}' .}\n",
      [
        "'\u{0}\t\u{b}\u{c}\u{e}&([]\u{7f}'", "'\u{0}\t\u{b}\u{c}\u{e}&([]\u{7f}'",
      ],
    ),
    // LITERAL2_ascii_boundaries
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0009\\u000B\\u000C\\u000E\\u0021\\u0023\\u005B\\u005D\\u007F\""）
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0009\\u000B\\u000C\\u000E\\u0021\\u0023\\u005B\\u005D\\u007F\""）
    (
      "LITERAL2_ascii_boundaries",
      "{<http://a.example/s> <http://a.example/p> \"\u{0}\t\u{b}\u{c}\u{e}!#[]\u{7f}\" .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"\u{0}\t\u{b}\u{c}\u{e}!#[]\u{7f}\" .}\n",
      [
        "\"\u{0}\t\u{b}\u{c}\u{e}!#[]\u{7f}\"", "\"\u{0}\t\u{b}\u{c}\u{e}!#[]\u{7f}\"",
      ],
    ),
    // LITERAL_LONG1_ascii_boundaries
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0026\\u0028\\u005B\\u005D\\u007F\""）
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0026\\u0028\\u005B\\u005D\\u007F\""）
    (
      "LITERAL_LONG1_ascii_boundaries",
      "{<http://a.example/s> <http://a.example/p> '\u{0}&([]\u{7f}' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\u{0}&([]\u{7f}' .}\n",
      ["'\u{0}&([]\u{7f}'", "'\u{0}&([]\u{7f}'"],
    ),
    // LITERAL_LONG1_with_1_squote
    //   源词形保真（.nq 规范形 "\"x'y\""）
    //   源词形保真（.nq 规范形 "\"x'y\""）
    (
      "LITERAL_LONG1_with_1_squote",
      "{<http://a.example/s> <http://a.example/p> '''x'y''' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '''x'y''' .}\n",
      ["'''x'y'''", "'''x'y'''"],
    ),
    // LITERAL_LONG1_with_2_squotes
    //   源词形保真（.nq 规范形 "\"x''y\""）
    //   源词形保真（.nq 规范形 "\"x''y\""）
    (
      "LITERAL_LONG1_with_2_squotes",
      "{<http://a.example/s> <http://a.example/p> '''x''y''' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '''x''y''' .}\n",
      ["'''x''y'''", "'''x''y'''"],
    ),
    // LITERAL_LONG2_ascii_boundaries
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0021\\u0023\\u005B\\u005D\\u007F\""）
    //   源词形保真（.nq 规范形 "\"\\u0000\\u0021\\u0023\\u005B\\u005D\\u007F\""）
    (
      "LITERAL_LONG2_ascii_boundaries",
      "{<http://a.example/s> <http://a.example/p> \"\u{0}!#[]\u{7f}\" .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"\u{0}!#[]\u{7f}\" .}\n",
      ["\"\u{0}!#[]\u{7f}\"", "\"\u{0}!#[]\u{7f}\""],
    ),
    // LITERAL_LONG2_with_1_squote
    //   源词形保真（.nq 规范形 "\"x\\\"y\""）
    //   源词形保真（.nq 规范形 "\"x\\\"y\""）
    (
      "LITERAL_LONG2_with_1_squote",
      "{<http://a.example/s> <http://a.example/p> \"\"\"x\"y\"\"\" .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"\"\"x\"y\"\"\" .}\n",
      ["\"\"\"x\"y\"\"\"", "\"\"\"x\"y\"\"\""],
    ),
    // LITERAL_LONG2_with_2_squotes
    //   源词形保真（.nq 规范形 "\"x\\\"\\\"y\""）
    //   源词形保真（.nq 规范形 "\"x\\\"\\\"y\""）
    (
      "LITERAL_LONG2_with_2_squotes",
      "{<http://a.example/s> <http://a.example/p> \"\"\"x\"\"y\"\"\" .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"\"\"x\"\"y\"\"\" .}\n",
      ["\"\"\"x\"\"y\"\"\"", "\"\"\"x\"\"y\"\"\""],
    ),
    // LITERAL_LONG2_with_REVERSE_SOLIDUS
    //   源词形保真（.nq 规范形 "\"test-\\\\\""）
    //   源词形保真（.nq 规范形 "\"test-\\\\\""）
    (
      "LITERAL_LONG2_with_REVERSE_SOLIDUS",
      "@prefix : <http://example.org/ns#> .\n\n{:s :p1 \"\"\"test-\\\\\"\"\" .}\n<http://example/graph> {:s :p1 \"\"\"test-\\\\\"\"\" .}\n",
      ["\"\"\"test-\\\\\"\"\"", "\"\"\"test-\\\\\"\"\""],
    ),
    // bareword_decimal
    //   裸词合成（源 "1.0" → 规范形 "\"1.0\"^^<http://www.w3.org/2001/XMLSchema#decimal>"）
    //   裸词合成（源 "1.0" → 规范形 "\"1.0\"^^<http://www.w3.org/2001/XMLSchema#decimal>"）
    (
      "bareword_decimal",
      "{<http://a.example/s> <http://a.example/p> 1.0 .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> 1.0 .}\n",
      [
        "\"1.0\"^^<http://www.w3.org/2001/XMLSchema#decimal>", "\"1.0\"^^<http://www.w3.org/2001/XMLSchema#decimal>",
      ],
    ),
    // bareword_double
    //   裸词合成（源 "1E0" → 规范形 "\"1E0\"^^<http://www.w3.org/2001/XMLSchema#double>"）
    //   裸词合成（源 "1E0" → 规范形 "\"1E0\"^^<http://www.w3.org/2001/XMLSchema#double>"）
    (
      "bareword_double",
      "{<http://a.example/s> <http://a.example/p> 1E0 .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> 1E0 .}\n",
      [
        "\"1E0\"^^<http://www.w3.org/2001/XMLSchema#double>", "\"1E0\"^^<http://www.w3.org/2001/XMLSchema#double>",
      ],
    ),
    // double_lower_case_e
    //   裸词合成（源 "1e0" → 规范形 "\"1e0\"^^<http://www.w3.org/2001/XMLSchema#double>"）
    //   裸词合成（源 "1e0" → 规范形 "\"1e0\"^^<http://www.w3.org/2001/XMLSchema#double>"）
    (
      "double_lower_case_e",
      "{<http://a.example/s> <http://a.example/p> 1e0 .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> 1e0 .}\n",
      [
        "\"1e0\"^^<http://www.w3.org/2001/XMLSchema#double>", "\"1e0\"^^<http://www.w3.org/2001/XMLSchema#double>",
      ],
    ),
    // langtagged_LONG_with_subtag
    //   源词形保真（.nq 规范形 "\"Cheers\"@en-UK"）
    //   源词形保真（.nq 规范形 "\"Cheers\"@en-UK"）
    (
      "langtagged_LONG_with_subtag",
      "# Test long literal with lang tag\n@prefix :  <http://example.org/ex#> .\n{:a :b \"\"\"Cheers\"\"\"@en-UK .}\n<http://example/graph> {:a :b \"\"\"Cheers\"\"\"@en-UK .}\n",
      ["\"\"\"Cheers\"\"\"@en-UK", "\"\"\"Cheers\"\"\"@en-UK"],
    ),
    // langtagged_non_LONG
    (
      "langtagged_non_LONG",
      "{<http://a.example/s> <http://a.example/p> \"chat\"@en .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"chat\"@en .}\n",
      ["\"chat\"@en", "\"chat\"@en"],
    ),
    // literal_false
    //   裸词合成（源 "false" → 规范形 "\"false\"^^<http://www.w3.org/2001/XMLSchema#boolean>"）
    //   裸词合成（源 "false" → 规范形 "\"false\"^^<http://www.w3.org/2001/XMLSchema#boolean>"）
    (
      "literal_false",
      "{<http://a.example/s> <http://a.example/p> false .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> false .}\n",
      [
        "\"false\"^^<http://www.w3.org/2001/XMLSchema#boolean>", "\"false\"^^<http://www.w3.org/2001/XMLSchema#boolean>",
      ],
    ),
    // literal_true
    //   裸词合成（源 "true" → 规范形 "\"true\"^^<http://www.w3.org/2001/XMLSchema#boolean>"）
    //   裸词合成（源 "true" → 规范形 "\"true\"^^<http://www.w3.org/2001/XMLSchema#boolean>"）
    (
      "literal_true",
      "{<http://a.example/s> <http://a.example/p> true .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> true .}\n",
      [
        "\"true\"^^<http://www.w3.org/2001/XMLSchema#boolean>", "\"true\"^^<http://www.w3.org/2001/XMLSchema#boolean>",
      ],
    ),
    // literal_with_BACKSPACE
    //   源词形保真（.nq 规范形 "\"\\u0008\""）
    //   源词形保真（.nq 规范形 "\"\\u0008\""）
    (
      "literal_with_BACKSPACE",
      "{<http://a.example/s> <http://a.example/p> '\u{8}' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\u{8}' .}\n",
      ["'\u{8}'", "'\u{8}'"],
    ),
    // literal_with_CARRIAGE_RETURN
    //   源词形保真（.nq 规范形 "\"\\r\""）
    //   源词形保真（.nq 规范形 "\"\\r\""）
    (
      "literal_with_CARRIAGE_RETURN",
      "{<http://a.example/s> <http://a.example/p> '''\r''' .}\r\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '''\r''' .}",
      ["'''\r'''", "'''\r'''"],
    ),
    // literal_with_CHARACTER_TABULATION
    //   源词形保真（.nq 规范形 "\"\\t\""）
    //   源词形保真（.nq 规范形 "\"\\t\""）
    (
      "literal_with_CHARACTER_TABULATION",
      "{<http://a.example/s> <http://a.example/p> '\t' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\t' .}\n",
      ["'\t'", "'\t'"],
    ),
    // literal_with_FORM_FEED
    //   源词形保真（.nq 规范形 "\"\\u000C\""）
    //   源词形保真（.nq 规范形 "\"\\u000C\""）
    (
      "literal_with_FORM_FEED",
      "{<http://a.example/s> <http://a.example/p> '\u{c}' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\u{c}' .}\n",
      ["'\u{c}'", "'\u{c}'"],
    ),
    // literal_with_LINE_FEED
    //   源词形保真（.nq 规范形 "\"\\n\""）
    //   源词形保真（.nq 规范形 "\"\\n\""）
    (
      "literal_with_LINE_FEED",
      "{<http://a.example/s> <http://a.example/p> '''\n''' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '''\n''' .}",
      ["'''\n'''", "'''\n'''"],
    ),
    // literal_with_REVERSE_SOLIDUS
    //   源词形保真（.nq 规范形 "\"\\\\\""）
    //   源词形保真（.nq 规范形 "\"\\\\\""）
    (
      "literal_with_REVERSE_SOLIDUS",
      "{<http://a.example/s> <http://a.example/p> '\\\\' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\\\' .}\n",
      ["'\\\\'", "'\\\\'"],
    ),
    // literal_with_numeric_escape4
    //   源词形保真（.nq 规范形 "\"o\""）
    //   源词形保真（.nq 规范形 "\"o\""）
    (
      "literal_with_numeric_escape4",
      "{<http://a.example/s> <http://a.example/p> '\\u006F' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\u006F' .}\n",
      ["'\\u006F'", "'\\u006F'"],
    ),
    // two_LITERAL_LONG2s
    //   源词形保真（.nq 规范形 "\"first long literal\""）
    //   源词形保真（.nq 规范形 "\"second long literal\""）
    (
      "two_LITERAL_LONG2s",
      "# Test long literal twice to ensure it does not over-quote\n@prefix :  <http://example.org/ex#> .\n{\n:a :b \"\"\"first long literal\"\"\" .\n:c :d \"\"\"second long literal\"\"\" .\n}\n",
      ["\"\"\"first long literal\"\"\"", "\"\"\"second long literal\"\"\""],
    ),
  ]
  for (name, doc, expected_objs) in rows {
    let fallback = Some("http://www.w3.org/2013/TriGTests/\{name}.trig")
    let (emits, errors) = mat_chain(doc, base_fallback=fallback)
    if errors.length() > 0 {
      fail("parse/mat Err: \{errors[0]}")
    }
    @debug.assert_eq(emits.length(), expected_objs.length())
    match litconf_first_obj(doc, fallback) {
      Some(actual) => @debug.assert_eq(actual, expected_objs[0])
      None => fail("no emit")
    }
  }
}

///|
// ② syntax-only 电池：无 .nq 的字面量族文件（含 trig-syntax-datatypes-01 xsd:byte
//    透传合法、-02 "123"^^xsd:string 合法；相对 IRI 由 manifest BASE 兜底——
//    与套件 harness base_fallback=Some(suite_base+file) 同口径）——判据：解析+物化全零错
test "w3c trig literal syntax-only verdicts (zero-error)" {
  let rows : Array[(String, String)] = [
    (
      "LITERAL1_with_UTF8_boundaries", "<http://a.example/s> <http://a.example/p> '\u{80}\u{7ff}\u{800}\u{fff}\u{1000}\u{cfff}\u{d000}\u{d7ff}\u{e000}\u{fffd}\u{10000}\u{3fffd}\u{40000}\u{ffffd}\u{100000}\u{10fffd}' .\n",
    ),
    (
      "LITERAL2", "{<http://a.example/s> <http://a.example/p> \"x\" .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"x\" .}\n",
    ),
    (
      "LITERAL2_with_UTF8_boundaries", "<http://a.example/s> <http://a.example/p> \"\u{80}\u{7ff}\u{800}\u{fff}\u{1000}\u{cfff}\u{d000}\u{d7ff}\u{e000}\u{fffd}\u{10000}\u{3fffd}\u{40000}\u{ffffd}\u{100000}\u{10fffd}\" .\n",
    ),
    (
      "LITERAL_LONG1", "{<http://a.example/s> <http://a.example/p> '''x''' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '''x''' .}\n",
    ),
    (
      "LITERAL_LONG1_with_UTF8_boundaries", "<http://a.example/s> <http://a.example/p> '''\u{80}\u{7ff}\u{800}\u{fff}\u{1000}\u{cfff}\u{d000}\u{d7ff}\u{e000}\u{fffd}\u{10000}\u{3fffd}\u{40000}\u{ffffd}\u{100000}\u{10fffd}''' .\n",
    ),
    (
      "LITERAL_LONG2", "{<http://a.example/s> <http://a.example/p> \"\"\"x\"\"\" .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"\"\"x\"\"\" .}\n",
    ),
    (
      "LITERAL_LONG2_with_UTF8_boundaries", "<http://a.example/s> <http://a.example/p> \"\"\"\u{80}\u{7ff}\u{800}\u{fff}\u{1000}\u{cfff}\u{d000}\u{d7ff}\u{e000}\u{fffd}\u{10000}\u{3fffd}\u{40000}\u{ffffd}\u{100000}\u{10fffd}\"\"\" .\n",
    ),
    (
      "bareword_integer", "{<http://a.example/s> <http://a.example/p> 1 .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> 1 .}\n",
    ),
    (
      "langtagged_LONG", "{<http://a.example/s> <http://a.example/p> \"\"\"chat\"\"\"@en .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"\"\"chat\"\"\"@en .}\n",
    ),
    (
      "literal_with_escaped_BACKSPACE", "{<http://a.example/s> <http://a.example/p> '\\b' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\b' .}\n",
    ),
    (
      "literal_with_escaped_CARRIAGE_RETURN", "{<http://a.example/s> <http://a.example/p> '\\r' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\r' .}\n",
    ),
    (
      "literal_with_escaped_CHARACTER_TABULATION", "{<http://a.example/s> <http://a.example/p> '\\t' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\t' .}\n",
    ),
    (
      "literal_with_escaped_FORM_FEED", "{<http://a.example/s> <http://a.example/p> '\\f' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\f' .}\n",
    ),
    (
      "literal_with_escaped_LINE_FEED", "{<http://a.example/s> <http://a.example/p> '\\n' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\n' .}\n",
    ),
    (
      "literal_with_numeric_escape8", "{<http://a.example/s> <http://a.example/p> '\\U0000006F' .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> '\\U0000006F' .}\n",
    ),
    (
      "prefixed_name_datatype", "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n{<http://a.example/s> <http://a.example/p> \"1\"^^xsd:integer .}\n<http://example/graph> {<http://a.example/s> <http://a.example/p> \"1\"^^xsd:integer .}\n",
    ),
    (
      "trig-syntax-datatypes-01", "@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .\n{<s> <p> \"123\"^^xsd:byte .}\n",
    ),
    (
      "trig-syntax-datatypes-02", "@prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .\n{<s> <p> \"123\"^^xsd:string .}\n",
    ),
  ]
  for (name, doc) in rows {
    let (_, errors) = mat_chain(
      doc,
      base_fallback=Some("http://www.w3.org/2013/TriGTests/\{name}.trig"),
    )
    if errors.length() > 0 {
      fail("\{name}: \{errors[0]}")
    }
  }
}
