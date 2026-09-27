// 授权与来源（三源抽取，2026-09-27 langtag 役）：
// ① W3C rdf-tests（双许可：W3C Test Suite License + 3-clause BSD，
//    https://www.w3.org/Consortium/Legal/2008/04-testsuite-copyright.html），
//    抽取自 w3c/rdf-tests @ f172950b7c8b42a7d2618a7905bba521847249b1
//    （rdf/rdf11/rdf-trig/langtagged_*.trig、*bad-lang-01、rdf-n-triples/langtagged_string.nt）。
//    This file includes material copied from or derived from the W3C RDF 1.1 Test Suite
//    (https://github.com/w3c/rdf-tests). Copyright (c) 2026 World Wide Web Consortium.
//    https://www.w3.org/copyright/software-license-2023/
// ② Apache Jena jena-langtag 测试电池（Apache License 2.0, SPDX-License-Identifier: Apache-2.0），
//    抽取自 jena-langtag/src/test/.../TestLangTag.java、TestLangTagFormat.java、
//    TestBasicSyntaxLangTags.java。Copyright 2026 The Apache Software Foundation.
//    http://www.apache.org/licenses/LICENSE-2.0
// ③ bcp-47 v2.1.1 test/fixtures/（MIT License, Copyright (c) Titus Wormer），
//    https://github.com/wooorm/bcp-47 —— 副本须保留版权与许可声明。
// 方言注记：bcp-47 是宽松结构解析（子标签 = 1-8 alnum，不校验 RFC 5646 长度律）；
// 其 fixture 中被 RFC 5646 语法拒收者逐条移入「拒收表」并注明条款（本层 = RFC 5646 语法，
// 4 字母保留语言沿用本仓既定口径拒收，见 langtag_wbtest 现有钉）。

///|
// ① W3C 官方行（引擎层字面门在 trig/nt 方言门，此处钉 LanguageTag 层判定）
test "w3c rdf-tests langtag rows" {
  // langtagged_LONG.trig / langtagged_string.nt / langtagged_non_LONG.trig：@en 合法
  match LanguageTag::parse_and_normalize("en") {
    Ok(v) => @debug.assert_eq(v.to_tagstr(), "en")
    Err(e) => fail("w3c en Err: \{e}")
  }
  // langtagged_LONG_with_subtag.trig：@en-UK（结构合法；region 不做 ISO 注册表校验）
  match LanguageTag::parse_and_normalize("en-UK") {
    Ok(v) => {
      @debug.assert_eq(v.to_tagstr(), "en-UK")
      @debug.assert_eq(v.primary_language().to_owned(), "en")
      @debug.assert_eq(v.region().map(fn(s) { s.to_owned() }), Some("UK"))
    }
    Err(e) => fail("w3c en-UK Err: \{e}")
  }
  // trig-syntax-bad-lang-01.trig / nt-syntax-bad-lang-01.nt：@1 拒收（主语言须字母）
  match LanguageTag::parse("1") {
    Ok(v) => fail("w3c @1 应拒收，got \{v.to_tagstr()}")
    Err(_) => ()
  }
  // trig-syntax-bad-LITERAL2_with_langtag_and_datatype：@en^^datatype 共现禁令属
  // 引擎语法门（langtag 本身合法），不在本层——见套件同名单文件。
}

///|
// ② Jena RFC 5646 电池：canonical 规范形（每行三变形 同一 canonical——Jena runTest 口径：
//    原文/全小/全大输入 → lang 小写、script Title、region 大写、变体/扩展/私有小写）
test "jena rfc5646 canonicalization battery" {
  let rows = [
    ("lng-scrp-rg", "lng-Scrp-RG"),
    ("lng-scrp-rg-variant", "lng-Scrp-RG-variant"),
    ("lng-scrp-rg-variant-e-abc", "lng-Scrp-RG-variant-e-abc"),
    ("en", "en"),
    ("en-us", "en-US"),
    ("en-latn-us", "en-Latn-US"),
    ("en-123", "en-123"),
    ("en-1234", "en-1234"),
    ("en-latn", "en-Latn"),
    ("en-latn-gb", "en-Latn-GB"),
    ("en-brs-xxx-latn-gb", "en-brs-xxx-Latn-GB"),
    ("de-CH-w-extend", "de-CH-w-extend"),
    ("de-CH-w-extend-extend", "de-CH-w-extend-extend"),
    ("en-12345", "en-12345"),
    ("en-123-12345678", "en-123-12345678"),
    ("en-s-12", "en-s-12"),
    ("en-s-12345678", "en-s-12345678"),
    ("de-CH-x-phonebk-morech", "de-CH-x-phonebk-morech"),
    ("x-private", "x-private"),
    ("az-Latn-x-latn", "az-Latn-x-latn"),
    ("sss-x-y", "sss-x-y"),
    ("sss-x-1", "sss-x-1"),
    ("sss-x-12345678", "sss-x-12345678"),
    ("x-12345678", "x-12345678"),
    ("abcd", "abcd"),
    ("abcdefgh", "abcdefgh"),
    ("en-GB-oed", "en-GB-oed"),
    ("EN-gb-OED", "en-GB-oed"),
    ("sgn-BE-FR", "sgn-BE-FR"),
    ("sgn-BE-NL", "sgn-BE-NL"),
    ("sgn-CH-DE", "sgn-CH-DE"),
    ("de", "de"),
    ("fr", "fr"),
    ("ja", "ja"),
    ("i-enochian", "i-enochian"),
    ("zh-Hant", "zh-Hant"),
    ("zh-Hans", "zh-Hans"),
    ("sr-Cyrl", "sr-Cyrl"),
    ("sr-Latn", "sr-Latn"),
    ("zh-cmn-Hans-CN", "zh-cmn-Hans-CN"),
    ("cmn-Hans-CN", "cmn-Hans-CN"),
    ("zh-yue-HK", "zh-yue-HK"),
    ("yue-HK", "yue-HK"),
    ("zh-Hans-CN", "zh-Hans-CN"),
    ("sr-Latn-RS", "sr-Latn-RS"),
    ("sl-rozaj", "sl-rozaj"),
    ("sl-rozaj-biske", "sl-rozaj-biske"),
    ("sl-nedis", "sl-nedis"),
    ("de-CH-1901", "de-CH-1901"),
    ("sl-IT-nedis", "sl-IT-nedis"),
    ("hy-Latn-IT-arevela", "hy-Latn-IT-arevela"),
    ("de-DE", "de-DE"),
    ("en-US", "en-US"),
    ("es-419", "es-419"),
    ("de-CH-x-phonebk", "de-CH-x-phonebk"),
    ("az-Arab-x-AZE-derbend", "az-Arab-x-aze-derbend"),
    ("x-whatever-a-abc-x-xyz", "x-whatever-a-abc-x-xyz"),
    ("qaa-Qaaa-QM-x-southern", "qaa-Qaaa-QM-x-southern"),
    ("de-Qaaa", "de-Qaaa"),
    ("sr-Latn-QM", "sr-Latn-QM"),
    ("sr-Qaaa-RS", "sr-Qaaa-RS"),
    ("en-US-u-islamcal", "en-US-u-islamcal"),
    ("zh-CN-a-myext-x-private", "zh-CN-a-myext-x-private"),
    ("en-a-myext-b-another", "en-a-myext-b-another"),
    ("en-x-private", "en-x-private"),
    ("en-x-US", "en-x-us"),
    ("en-a-bbb-x-a-ccc", "en-a-bbb-x-a-ccc"),
    (
      "en-Latn-GB-boont-r-extended-sequence-x-private", "en-Latn-GB-boont-r-extended-sequence-x-private",
    ),
    (
      "en-Latn-GB-boont-r-extended-sequence-s-another-x-private", "en-Latn-GB-boont-r-extended-sequence-s-another-x-private",
    ),
    ("FR", "fr"),
    ("jA", "ja"),
    ("en-US-variant", "en-US-variant"),
    ("es-latn-419", "es-Latn-419"),
    ("zh-hant", "zh-Hant"),
    ("sr-cyrl", "sr-Cyrl"),
    ("sr-latn", "sr-Latn"),
    ("zh-cmn-hans-cn", "zh-cmn-Hans-CN"),
    ("cmn-hans-cn", "cmn-Hans-CN"),
    ("zh-yue-hk", "zh-yue-HK"),
    ("yue-hk", "yue-HK"),
    ("zh-hans-cn", "zh-Hans-CN"),
    ("sr-latn-rs", "sr-Latn-RS"),
    ("de-ch-1901", "de-CH-1901"),
    ("sl-it-nedis", "sl-IT-nedis"),
    ("hy-latn-it-arevela", "hy-Latn-IT-arevela"),
    ("de-ch-x-phonebk", "de-CH-x-phonebk"),
    ("az-arab-x-aze-derbend", "az-Arab-x-aze-derbend"),
    ("x-whatever", "x-whatever"),
    ("qaa-qaaa-qm-x-southern", "qaa-Qaaa-QM-x-southern"),
    ("de-qaaa", "de-Qaaa"),
    ("en-us-u-islamcal", "en-US-u-islamcal"),
    ("zh-cn-a-myext-x-private", "zh-CN-a-myext-x-private"),
    ("EN-LATN", "en-Latn"),
    ("de-ch-w-extend", "de-CH-w-extend"),
    ("de-ch-x-phonebk-morech", "de-CH-x-phonebk-morech"),
    ("az-latn-x-latn", "az-Latn-x-latn"),
    ("en-latn-X-DaTa", "en-Latn-x-data"),
    ("SGN-BE-FR", "sgn-BE-FR"),
    ("sgn-be-fr", "sgn-BE-FR"),
    ("sgn-be-nl", "sgn-BE-NL"),
    ("sgn-ch-de", "sgn-CH-DE"),
    ("i-klingon", "i-klingon"),
    ("en-ca-x-ca", "en-CA-x-ca"),
    ("EN-ca-X-Ca", "en-CA-x-ca"),
    ("En-Ca-X-Ca", "en-CA-x-ca"),
    ("AZ-latn-x-LATN", "az-Latn-x-latn"),
    ("Az-latn-X-Latn", "az-Latn-x-latn"),
    ("zh-latn-wadegile", "zh-Latn-wadegile"),
    ("zh-latn-pinyin", "zh-Latn-pinyin"),
    ("EN-Gb", "en-GB"),
    ("qqq-002", "qqq-002"),
    ("ja-latn", "ja-Latn"),
    ("x-local", "x-local"),
    ("he-latn", "he-Latn"),
    ("und", "und"),
    ("nn", "nn"),
    ("ko-latn", "ko-Latn"),
    ("ar-latn", "ar-Latn"),
    ("la-x-liturgic", "la-x-liturgic"),
    ("fa-x-middle", "fa-x-middle"),
    ("qqq-142", "qqq-142"),
    ("bnt", "bnt"),
    ("grc-x-liturgic", "grc-x-liturgic"),
    ("egy-Latn", "egy-Latn"),
    ("la-x-medieval", "la-x-medieval"),
  ]
  for (input, canonical) in rows {
    for variant in [input, input.to_lower(), input.to_upper()] {
      match LanguageTag::parse_and_normalize(variant) {
        Ok(v) => @debug.assert_eq(v.to_tagstr(), canonical)
        Err(e) => fail("jena(\{variant}) Err: \{e}")
      }
    }
  }
}

///|
// ② Jena 负例电池（RFC 5646 非法 + 基础语法负例；含重复 singleton、超长、空段、
//    非字母主语言、孤儿 singleton、超长私有用等）
test "jena bad battery" {
  let bads = [
    "123", "abcdefghijklmn", "abcdefghijklmn-123", "abcdefghijklmn-latn", "a?", "a b",
    "en--us", "-us", "en-", "en-gb-", "i18n", "s", "abcdefghz", "en-abcdefghz", "en-Latn-x-abcdefghz",
    "en-123456789", "sss-d", "sss-d-", "sss-d-e", "sss-d-ext-", "sss-x", "sss-x-",
    "sss-x-part-", "sss-x-part-Q12345678", "en-a-bbb-a-ccc", "en-x-Q123456789", "sgn-GB-SW",
    "", "-", "--", "abc-xy%20", "abc def", "a12-def", "9-def",
  ]
  for b in bads {
    match LanguageTag::parse(b) {
      Ok(v) => fail("jena bad 应拒收: \{b} got \{v.to_tagstr()}")
      Err(_) => ()
    }
  }
}

///|
// ③ bcp-47 fixtures 电池（92 例合法标签，组件分解 JSON 驱动；round-trip 保真 +
//    主语言/脚本/区域/变体数/扩展数/私有用数；grandfathered 行仅 round-trip——
//    本仓口径：祖父标签不透明整体）
test "bcp47 fixtures battery" {
  let rows : Array[(String, String?, String?, String?, Int, Int, Int)] = [
    ("aa-111", Some("aa"), None, Some("111"), 0, 0, 0),
    ("aa-7-123abc-abc-a-12", Some("aa"), None, None, 0, 2, 0),
    ("aa-b1b1b-6a8b-cccccc", Some("aa"), None, None, 3, 0, 0),
    ("aa-b1b1b", Some("aa"), None, None, 1, 0, 0),
    ("aa-bb", Some("aa"), None, Some("bb"), 0, 0, 0),
    ("aa-bbb-ccc-1111-ccccc-b1b1b", Some("aa"), None, None, 3, 0, 0),
    ("aa-bbb-ccc-ddd", Some("aa"), None, None, 0, 0, 0),
    ("aa-bbb", Some("aa"), None, None, 0, 0, 0),
    ("aa-bbbb-cc", Some("aa"), Some("bbbb"), Some("cc"), 0, 0, 0),
    ("aa-bbbb", Some("aa"), Some("bbbb"), None, 0, 0, 0),
    ("aa-x-1234ab-d", Some("aa"), None, None, 0, 0, 2),
    ("aa", Some("aa"), None, None, 0, 0, 0),
    (
      "aaa-bbb-ccc-ddd-abcd-123-abc123-0abc-b-01-abc123-x-01ab-abc12",
      Some("aaa"),
      Some("abcd"),
      Some("123"),
      2,
      1,
      2,
    ),
    ("aaa-bbb-ccc", Some("aaa"), None, None, 0, 0, 0),
    ("aaaa", Some("aaaa"), None, None, 0, 0, 0),
    ("aaaaa", Some("aaaaa"), None, None, 0, 0, 0),
    ("aaaaaa", Some("aaaaaa"), None, None, 0, 0, 0),
    ("aaaaaaa", Some("aaaaaaa"), None, None, 0, 0, 0),
    ("aaaaaaaa", Some("aaaaaaaa"), None, None, 0, 0, 0),
    ("afb", Some("afb"), None, None, 0, 0, 0),
    ("ar-afb", Some("ar"), None, None, 0, 0, 0),
    ("art-lojban", None, None, None, 0, 0, 0),
    ("ast", Some("ast"), None, None, 0, 0, 0),
    ("az-Arab-x-AZE-derbend", Some("az"), Some("Arab"), None, 0, 0, 2),
    ("az-Latn", Some("az"), Some("Latn"), None, 0, 0, 0),
    ("cel-gaulish", None, None, None, 0, 0, 0),
    ("cmn-Hans-CN", Some("cmn"), Some("Hans"), Some("CN"), 0, 0, 0),
    ("de-CH-1901", Some("de"), None, Some("CH"), 1, 0, 0),
    ("de-CH-x-phonebk", Some("de"), None, Some("CH"), 0, 0, 1),
    ("de-DE-u-co-phonebk", Some("de"), None, Some("DE"), 0, 1, 0),
    ("de-DE", Some("de"), None, Some("DE"), 0, 0, 0),
    ("de-Qaaa", Some("de"), Some("Qaaa"), None, 0, 0, 0),
    ("de", Some("de"), None, None, 0, 0, 0),
    ("en-GB-oed", None, None, None, 0, 0, 0),
    ("en-US-u-islamcal", Some("en"), None, Some("US"), 0, 1, 0),
    ("en-US-x-twain", Some("en"), None, Some("US"), 0, 0, 1),
    ("en-US", Some("en"), None, Some("US"), 0, 0, 0),
    ("en-a-myext-b-another", Some("en"), None, None, 0, 2, 0),
    ("en", Some("en"), None, None, 0, 0, 0),
    ("es-005", Some("es"), None, Some("005"), 0, 0, 0),
    ("es-419", Some("es"), None, Some("419"), 0, 0, 0),
    ("fr-CA", Some("fr"), None, Some("CA"), 0, 0, 0),
    ("fr", Some("fr"), None, None, 0, 0, 0),
    ("hak", Some("hak"), None, None, 0, 0, 0),
    ("hy-Latn-IT-arevela", Some("hy"), Some("Latn"), Some("IT"), 1, 0, 0),
    ("i-ami", None, None, None, 0, 0, 0),
    ("i-bnn", None, None, None, 0, 0, 0),
    ("i-default", None, None, None, 0, 0, 0),
    ("i-enochian", None, None, None, 0, 0, 0),
    ("i-hak", None, None, None, 0, 0, 0),
    ("i-klingon", None, None, None, 0, 0, 0),
    ("i-lux", None, None, None, 0, 0, 0),
    ("i-mingo", None, None, None, 0, 0, 0),
    ("i-navajo", None, None, None, 0, 0, 0),
    ("i-pwn", None, None, None, 0, 0, 0),
    ("i-tao", None, None, None, 0, 0, 0),
    ("i-tay", None, None, None, 0, 0, 0),
    ("i-tsu", None, None, None, 0, 0, 0),
    ("ja", Some("ja"), None, None, 0, 0, 0),
    ("mas", Some("mas"), None, None, 0, 0, 0),
    ("no-bok", None, None, None, 0, 0, 0),
    ("no-nyn", None, None, None, 0, 0, 0),
    ("pt-ao1990", Some("pt"), None, None, 1, 0, 0),
    ("qaa-Qaaa-QM-x-southern", Some("qaa"), Some("Qaaa"), Some("QM"), 0, 0, 1),
    ("sgn-BE-FR", None, None, None, 0, 0, 0),
    ("sgn-BE-NL", None, None, None, 0, 0, 0),
    ("sgn-CH-DE", None, None, None, 0, 0, 0),
    ("sl-IT-nedis", Some("sl"), None, Some("IT"), 1, 0, 0),
    ("sl-nedis", Some("sl"), None, None, 1, 0, 0),
    ("sl-rozaj-biske", Some("sl"), None, None, 2, 0, 0),
    ("sl-rozaj", Some("sl"), None, None, 1, 0, 0),
    ("sr-Cyrl", Some("sr"), Some("Cyrl"), None, 0, 0, 0),
    ("sr-Latn-QM", Some("sr"), Some("Latn"), Some("QM"), 0, 0, 0),
    ("sr-Latn-RS", Some("sr"), Some("Latn"), Some("RS"), 0, 0, 0),
    ("sr-Latn", Some("sr"), Some("Latn"), None, 0, 0, 0),
    ("sr-Qaaa-RS", Some("sr"), Some("Qaaa"), Some("RS"), 0, 0, 0),
    ("x-111-aaaaa-BBB", None, None, None, 0, 0, 3),
    ("x-whatever", None, None, None, 0, 0, 1),
    ("yue-HK", Some("yue"), None, Some("HK"), 0, 0, 0),
    ("zh-CN-a-myext-x-private", Some("zh"), None, Some("CN"), 0, 1, 1),
    ("zh-Hans-CN", Some("zh"), Some("Hans"), Some("CN"), 0, 0, 0),
    ("zh-Hans", Some("zh"), Some("Hans"), None, 0, 0, 0),
    ("zh-Hant-HK", Some("zh"), Some("Hant"), Some("HK"), 0, 0, 0),
    ("zh-Hant", Some("zh"), Some("Hant"), None, 0, 0, 0),
    ("zh-cmn-Hans-CN", Some("zh"), Some("Hans"), Some("CN"), 0, 0, 0),
    ("zh-guoyu", None, None, None, 0, 0, 0),
    ("zh-hakka", None, None, None, 0, 0, 0),
    ("zh-min-nan", None, None, None, 0, 0, 0),
    ("zh-min", None, None, None, 0, 0, 0),
    ("zh-xiang", None, None, None, 0, 0, 0),
    ("zh-yue-HK", Some("zh"), None, Some("HK"), 0, 0, 0),
    ("zh-yue", Some("zh"), None, None, 0, 0, 0),
  ]
  for (input, lang, script, region, n_variants, n_ext, n_pu) in rows {
    match LanguageTag::parse(input) {
      Ok(v) => {
        @debug.assert_eq(v.to_tagstr(), input)
        match lang {
          Some(l) => @debug.assert_eq(v.primary_language().to_owned(), l)
          None => ()
        }
        match script {
          Some(s) =>
            @debug.assert_eq(v.script().map(fn(x) { x.to_owned() }), Some(s))
          None => ()
        }
        match region {
          Some(r) =>
            @debug.assert_eq(v.region().map(fn(x) { x.to_owned() }), Some(r))
          None => ()
        }
        @debug.assert_eq(v.variant_subtags().length(), n_variants)
        @debug.assert_eq(v.has_extensions(), n_ext > 0)
        @debug.assert_eq(v.has_private_use(), n_pu > 0)
      }
      Err(e) => fail("bcp47(\{input}) Err: \{e}")
    }
  }
}
