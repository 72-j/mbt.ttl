// 来源与许可（统一形；详见 `THIRD_PARTY_NOTICES.md`）：
//   ① W3C rdf-tests 双许可（W3C Test Suite License + 3-clause BSD）；
//   ② Apache Jena（SPDX: Apache-2.0；仅 langtag 电池）；
//   ③ Oxigraph（SPDX: MIT OR Apache-2.0；仅 literal/datatype 形态参考）。

///|
// iri.mbt 一致性钉（2026-09-27 评审役）：RFC 3986 官方口径 + 六处分叉/缺口收口
fn conf_iri(s : String) -> Iri {
  match parse(@utf8.encode(s)[:]) {
    Ok(v) => v
    Err(_) => Iri::default()
  }
}

///|
test "rfc3986 5.4.1 normal table (base http://a/b/c)" {
  let base = conf_iri("http://a/b/c")
  let cases = [
    ("g", "http://a/b/g"),
    ("./g", "http://a/b/g"),
    ("g/", "http://a/b/g/"),
    ("/g", "http://a/g"),
    // authority 已定义 ⇒ 组件全取自引用（曾错继承 base path）
    ("//g", "http://g"),
    ("?y", "http://a/b/c?y"),
    ("g?y", "http://a/b/g?y"),
    ("#s", "http://a/b/c#s"),
    ("g#s", "http://a/b/g#s"),
    ("g?y#s", "http://a/b/g?y#s"),
    ("", "http://a/b/c"),
    // 规则 B/C：尾点段以 "/" 收尾
    (".", "http://a/b/"),
    ("./", "http://a/b/"),
    ("..", "http://a/"),
    ("../", "http://a/"),
    ("../g", "http://a/g"),
    ("../..", "http://a/"),
    ("../../", "http://a/"),
    ("../../g", "http://a/g"),
  ]
  for (ref_iri, expected) in cases {
    match base.resolve(@utf8.encode(ref_iri)[:]) {
      Ok(v) => @debug.assert_eq(v.into_string(), expected)
      Err(e) => fail("resolve(\{ref_iri}) Err: \{e}")
    }
  }
}

///|
test "rfc3986 5.4.2 abnormal table (base http://a/b/c)" {
  let base = conf_iri("http://a/b/c")
  let cases = [
    ("../../../../../g", "http://a/g"),
    ("/./g", "http://a/g"),
    ("/../g", "http://a/g"),
    ("g.", "http://a/b/g."),
    (".g", "http://a/b/.g"),
    ("g..", "http://a/b/g.."),
    ("..g", "http://a/b/..g"),
    // strict 指针：引用带 scheme ⇒ 原样返回
    ("http:g", "http:g"),
  ]
  for (ref_iri, expected) in cases {
    match base.resolve(@utf8.encode(ref_iri)[:]) {
      Ok(v) => @debug.assert_eq(v.into_string(), expected)
      Err(e) => fail("resolve(\{ref_iri}) Err: \{e}")
    }
  }
}

///|
test "remove_dot_segments tail-slash pins (5.2.4 B/C)" {
  @debug.assert_eq(fn_remove_dot_segments("/b/c/.."), "/b/")
  @debug.assert_eq(fn_remove_dot_segments("/b/c/."), "/b/c/")
  @debug.assert_eq(fn_remove_dot_segments("a/b/c/."), "a/b/c/")
  @debug.assert_eq(fn_remove_dot_segments("a/b/."), "a/b/")
  @debug.assert_eq(fn_remove_dot_segments("a/.."), "/")
  // 裸点段族走规则 A，不触发尾斜杠
  @debug.assert_eq(fn_remove_dot_segments("."), "")
  @debug.assert_eq(fn_remove_dot_segments(".."), "")
  @debug.assert_eq(fn_remove_dot_segments("./."), "")
  @debug.assert_eq(fn_remove_dot_segments("../.."), "")
}

///|
test "relativize branch table" {
  let base = conf_iri("https://e.com/a/b/")
  // 同文档 → 空 path
  match base.relativize(conf_iri("https://e.com/a/b/")) {
    Ok(v) => {
      @debug.assert_eq(v.scheme, "")
      @debug.assert_eq(v.path, "")
    }
    Err(e) => fail("relativize Err: \{e}")
  }
  // 子路径 → "./" 前缀
  match base.relativize(conf_iri("https://e.com/a/b/c")) {
    Ok(v) => @debug.assert_eq(v.path, "./c")
    Err(e) => fail("relativize Err: \{e}")
  }
  // 深子路径
  match base.relativize(conf_iri("https://e.com/a/b/c/d")) {
    Ok(v) => @debug.assert_eq(v.path, "./c/d")
    Err(e) => fail("relativize Err: \{e}")
  }
  // 兄弟 → 全 path
  match base.relativize(conf_iri("https://e.com/a/x")) {
    Ok(v) => @debug.assert_eq(v.path, "/a/x")
    Err(e) => fail("relativize Err: \{e}")
  }
  // query/fragment 透传
  match base.relativize(conf_iri("https://e.com/a/b/c?q#f")) {
    Ok(v) => {
      @debug.assert_eq(v.path, "./c")
      @debug.assert_eq(v.query, Some("q"[:]))
      @debug.assert_eq(v.fragment, Some("f"[:]))
    }
    Err(e) => fail("relativize Err: \{e}")
  }
  // 异 scheme/authority → 原样透传 target
  match
    conf_iri("https://e.com/a/b/").relativize(conf_iri("http://e.com/a/b/c")) {
    Ok(v) => @debug.assert_eq(v.scheme, "http")
    Err(e) => fail("relativize Err: \{e}")
  }
}

///|
test "resolve checked/unchecked lockstep" {
  let base = conf_iri("https://e.com/base")
  let refs = [
    "rel", "rel/deep", "/abs", "//g.com/x", "//g.com", "?q", "#f", "?q#f", "", "../r",
  ]
  for ref_iri in refs {
    match base.resolve(@utf8.encode(ref_iri)[:]) {
      Ok(v) =>
        @debug.assert_eq(
          v.into_string(),
          base.resolve_unchecked(@utf8.encode(ref_iri)[:]).into_string(),
        )
      Err(e) => fail("resolve(\{ref_iri}) Err: \{e}")
    }
  }
}

///|
test "nonascii component split" {
  // 修复前：尾扩展把 "#f" 吞进 path（fragment 丢失）
  let v = conf_iri("http://e/中文#f")
  @debug.assert_eq(v.path, "/中文")
  @debug.assert_eq(v.fragment, Some("f"[:]))
  let w = conf_iri("http://e/中文?q#f")
  @debug.assert_eq(w.path, "/中文")
  @debug.assert_eq(w.query, Some("q"[:]))
  @debug.assert_eq(w.fragment, Some("f"[:]))
  // authority 侧非 ASCII（RFC 3987 ireg-name）
  let h = conf_iri("http://例.jp/π")
  @debug.assert_eq(h.authority, Some("例.jp"[:]))
  @debug.assert_eq(h.path, "/π")
  // 解析链上非 ASCII + 点段
  match conf_iri("http://a/b/c").resolve(@utf8.encode("../中文#x")[:]) {
    Ok(v) => {
      @debug.assert_eq(v.into_string(), "http://a/中文#x")
      @debug.assert_eq(v.fragment, Some("x"[:]))
    }
    Err(e) => fail("resolve Err: \{e}")
  }
}

///|
test "lenient parse contract" {
  // parse 结构上永不 Err（lenient 词法，验证层把关）
  let v = conf_iri("scheme:")
  @debug.assert_eq(v.scheme, "scheme")
  @debug.assert_eq(v.path, "")
  let w = conf_iri("123abc/no-colon")
  @debug.assert_eq(w.scheme, "")
  @debug.assert_eq(w.path, "123abc/no-colon")
  // 内嵌空格：尾扩展粘合（引擎层 IRIREF 禁空格，此处只钉词法宽松行为）
  let s = conf_iri("http://e/a b")
  @debug.assert_eq(s.path, "/a b")
}

// 授权与来源（W3C 测试套件双许可：W3C Test Suite License + 3-clause BSD，
// 见 https://www.w3.org/Consortium/Legal/2008/04-testsuite-copyright.html）：
// 本段测试数据抽取自 w3c/rdf-tests @ f172950b7c8b42a7d2618a7905bba521847249b1
// （rdf/rdf11/rdf-trig/IRI-resolution-{01,02,07,08}.{trig,nq}）。
// This file includes material copied from or derived from the W3C RDF 1.1
// Test Suite (https://github.com/w3c/rdf-tests). Copyright (c) 2026
// World Wide Web Consortium. https://www.w3.org/copyright/software-license-2023/

///|
// extracted from W3C rdf-tests rdf11/rdf-trig/IRI-resolution-01 (bases http://a/bb/ccc/d;p?q)
test "w3c iri-resolution-01 extraction" {
  let blocks = [
    (
      "http://a/bb/ccc/d;p?q",
      [
        ("g:h", "g:h"),
        ("g", "http://a/bb/ccc/g"),
        ("./g", "http://a/bb/ccc/g"),
        ("g/", "http://a/bb/ccc/g/"),
        ("/g", "http://a/g"),
        ("//g", "http://g"),
        ("?y", "http://a/bb/ccc/d;p?y"),
        ("g?y", "http://a/bb/ccc/g?y"),
        ("#s", "http://a/bb/ccc/d;p?q#s"),
        ("g#s", "http://a/bb/ccc/g#s"),
        ("g?y#s", "http://a/bb/ccc/g?y#s"),
        (";x", "http://a/bb/ccc/;x"),
        ("g;x", "http://a/bb/ccc/g;x"),
        ("g;x?y#s", "http://a/bb/ccc/g;x?y#s"),
        ("", "http://a/bb/ccc/d;p?q"),
        (".", "http://a/bb/ccc/"),
        ("./", "http://a/bb/ccc/"),
        ("..", "http://a/bb/"),
        ("../", "http://a/bb/"),
        ("../g", "http://a/bb/g"),
        ("../..", "http://a/"),
        ("../../", "http://a/"),
        ("../../g", "http://a/g"),
        ("../../../g", "http://a/g"),
        ("../../../../g", "http://a/g"),
        ("/./g", "http://a/g"),
        ("/../g", "http://a/g"),
        ("g.", "http://a/bb/ccc/g."),
        (".g", "http://a/bb/ccc/.g"),
        ("g..", "http://a/bb/ccc/g.."),
        ("..g", "http://a/bb/ccc/..g"),
        ("./../g", "http://a/bb/g"),
        ("./g/.", "http://a/bb/ccc/g/"),
        ("g/./h", "http://a/bb/ccc/g/h"),
        ("g/../h", "http://a/bb/ccc/h"),
        ("g;x=1/./y", "http://a/bb/ccc/g;x=1/y"),
        ("g;x=1/../y", "http://a/bb/ccc/y"),
        ("g?y/./x", "http://a/bb/ccc/g?y/./x"),
        ("g?y/../x", "http://a/bb/ccc/g?y/../x"),
        ("g#s/./x", "http://a/bb/ccc/g#s/./x"),
        ("g#s/../x", "http://a/bb/ccc/g#s/../x"),
      ],
    ),
  ]
  for (base_iri, cases) in blocks {
    let base = conf_iri(base_iri)
    for (ref_iri, expected) in cases {
      match base.resolve(@utf8.encode(ref_iri)[:]) {
        Ok(v) => @debug.assert_eq(v.into_string(), expected)
        Err(e) => fail("resolve(\{ref_iri}) Err: \{e}")
      }
    }
  }
}

///|
// extracted from W3C rdf-tests rdf11/rdf-trig/IRI-resolution-02 (bases http://a/bb/ccc/d/)
test "w3c iri-resolution-02 extraction" {
  let blocks = [
    (
      "http://a/bb/ccc/d/",
      [
        ("g:h", "g:h"),
        ("g", "http://a/bb/ccc/d/g"),
        ("./g", "http://a/bb/ccc/d/g"),
        ("g/", "http://a/bb/ccc/d/g/"),
        ("/g", "http://a/g"),
        ("//g", "http://g"),
        ("?y", "http://a/bb/ccc/d/?y"),
        ("g?y", "http://a/bb/ccc/d/g?y"),
        ("#s", "http://a/bb/ccc/d/#s"),
        ("g#s", "http://a/bb/ccc/d/g#s"),
        ("g?y#s", "http://a/bb/ccc/d/g?y#s"),
        (";x", "http://a/bb/ccc/d/;x"),
        ("g;x", "http://a/bb/ccc/d/g;x"),
        ("g;x?y#s", "http://a/bb/ccc/d/g;x?y#s"),
        ("", "http://a/bb/ccc/d/"),
        (".", "http://a/bb/ccc/d/"),
        ("./", "http://a/bb/ccc/d/"),
        ("..", "http://a/bb/ccc/"),
        ("../", "http://a/bb/ccc/"),
        ("../g", "http://a/bb/ccc/g"),
        ("../..", "http://a/bb/"),
        ("../../", "http://a/bb/"),
        ("../../g", "http://a/bb/g"),
        ("../../../g", "http://a/g"),
        ("../../../../g", "http://a/g"),
        ("/./g", "http://a/g"),
        ("/../g", "http://a/g"),
        ("g.", "http://a/bb/ccc/d/g."),
        (".g", "http://a/bb/ccc/d/.g"),
        ("g..", "http://a/bb/ccc/d/g.."),
        ("..g", "http://a/bb/ccc/d/..g"),
        ("./../g", "http://a/bb/ccc/g"),
        ("./g/.", "http://a/bb/ccc/d/g/"),
        ("g/./h", "http://a/bb/ccc/d/g/h"),
        ("g/../h", "http://a/bb/ccc/d/h"),
        ("g;x=1/./y", "http://a/bb/ccc/d/g;x=1/y"),
        ("g;x=1/../y", "http://a/bb/ccc/d/y"),
        ("g?y/./x", "http://a/bb/ccc/d/g?y/./x"),
        ("g?y/../x", "http://a/bb/ccc/d/g?y/../x"),
        ("g#s/./x", "http://a/bb/ccc/d/g#s/./x"),
        ("g#s/../x", "http://a/bb/ccc/d/g#s/../x"),
      ],
    ),
  ]
  for (base_iri, cases) in blocks {
    let base = conf_iri(base_iri)
    for (ref_iri, expected) in cases {
      match base.resolve(@utf8.encode(ref_iri)[:]) {
        Ok(v) => @debug.assert_eq(v.into_string(), expected)
        Err(e) => fail("resolve(\{ref_iri}) Err: \{e}")
      }
    }
  }
}

///|
// extracted from W3C rdf-tests rdf11/rdf-trig/IRI-resolution-07 (bases file:///a/bb/ccc/d;p?q)
test "w3c iri-resolution-07 extraction" {
  let blocks = [
    (
      "file:///a/bb/ccc/d;p?q",
      [
        ("g:h", "g:h"),
        ("g", "file:///a/bb/ccc/g"),
        ("./g", "file:///a/bb/ccc/g"),
        ("g/", "file:///a/bb/ccc/g/"),
        ("/g", "file:///g"),
        ("//g", "file://g"),
        ("?y", "file:///a/bb/ccc/d;p?y"),
        ("g?y", "file:///a/bb/ccc/g?y"),
        ("#s", "file:///a/bb/ccc/d;p?q#s"),
        ("g#s", "file:///a/bb/ccc/g#s"),
        ("g?y#s", "file:///a/bb/ccc/g?y#s"),
        (";x", "file:///a/bb/ccc/;x"),
        ("g;x", "file:///a/bb/ccc/g;x"),
        ("g;x?y#s", "file:///a/bb/ccc/g;x?y#s"),
        ("", "file:///a/bb/ccc/d;p?q"),
        (".", "file:///a/bb/ccc/"),
        ("./", "file:///a/bb/ccc/"),
        ("..", "file:///a/bb/"),
        ("../", "file:///a/bb/"),
        ("../g", "file:///a/bb/g"),
        ("../..", "file:///a/"),
        ("../../", "file:///a/"),
        ("../../g", "file:///a/g"),
        ("../../../g", "file:///g"),
        ("../../../../g", "file:///g"),
        ("/./g", "file:///g"),
        ("/../g", "file:///g"),
        ("g.", "file:///a/bb/ccc/g."),
        (".g", "file:///a/bb/ccc/.g"),
        ("g..", "file:///a/bb/ccc/g.."),
        ("..g", "file:///a/bb/ccc/..g"),
        ("./../g", "file:///a/bb/g"),
        ("./g/.", "file:///a/bb/ccc/g/"),
        ("g/./h", "file:///a/bb/ccc/g/h"),
        ("g/../h", "file:///a/bb/ccc/h"),
        ("g;x=1/./y", "file:///a/bb/ccc/g;x=1/y"),
        ("g;x=1/../y", "file:///a/bb/ccc/y"),
        ("g?y/./x", "file:///a/bb/ccc/g?y/./x"),
        ("g?y/../x", "file:///a/bb/ccc/g?y/../x"),
        ("g#s/./x", "file:///a/bb/ccc/g#s/./x"),
        ("g#s/../x", "file:///a/bb/ccc/g#s/../x"),
        ("http:g", "http:g"),
      ],
    ),
  ]
  for (base_iri, cases) in blocks {
    let base = conf_iri(base_iri)
    for (ref_iri, expected) in cases {
      match base.resolve(@utf8.encode(ref_iri)[:]) {
        Ok(v) => @debug.assert_eq(v.into_string(), expected)
        Err(e) => fail("resolve(\{ref_iri}) Err: \{e}")
      }
    }
  }
}

///|
// extracted from W3C rdf-tests rdf11/rdf-trig/IRI-resolution-08 (bases http://abc/def/ghi | http://ab//de//ghi | http://abc/d:f/ghi)
test "w3c iri-resolution-08 extraction" {
  let blocks = [
    (
      "http://abc/def/ghi",
      [
        (".", "http://abc/def/"),
        (".?a=b", "http://abc/def/?a=b"),
        (".#a=b", "http://abc/def/#a=b"),
        ("..", "http://abc/"),
        ("..?a=b", "http://abc/?a=b"),
        ("..#a=b", "http://abc/#a=b"),
      ],
    ),
    (
      "http://ab//de//ghi",
      [
        ("xyz", "http://ab//de//xyz"),
        ("./xyz", "http://ab//de//xyz"),
        ("../xyz", "http://ab//de/xyz"),
      ],
    ),
    (
      "http://abc/d:f/ghi",
      [
        ("xyz", "http://abc/d:f/xyz"),
        ("./xyz", "http://abc/d:f/xyz"),
        ("../xyz", "http://abc/xyz"),
      ],
    ),
  ]
  for (base_iri, cases) in blocks {
    let base = conf_iri(base_iri)
    for (ref_iri, expected) in cases {
      match base.resolve(@utf8.encode(ref_iri)[:]) {
        Ok(v) => @debug.assert_eq(v.into_string(), expected)
        Err(e) => fail("resolve(\{ref_iri}) Err: \{e}")
      }
    }
  }
}
