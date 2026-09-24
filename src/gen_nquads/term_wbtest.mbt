// 展示面（Show）逐变体测试。
// 背景（覆盖率实测 2026-09-18）：term.mbt 展示面此前是 0/128 行覆盖——
// 产物侧只有 struct 定义被引用，展示面从没被跑过。本文件按变体逐个断言**输出串**，
// 不只"跑过就算"：QuadSpan/QuadEmit 的格式是调试面契约，漂了要能被看见。
//
// P3 平化（2026-09-24）：Subject/Object 七变体金样随型迁——经 show_term_view
// 直测（wbtest 白盒见私有件），**断言串逐字不变**；新增 TermKind 裸名展示金样；
// QuadEmit 三档金样字节不变。
//
// 调用口径：方法隐式提升已 deprecated（`--deny-warn` 红）⇒ 一律显式 `Show::to_string(x)`。

///|
/// 测试用字节视图（Show 只吃 span 长度，故内容取可读串便于断言）
fn term_view(text : String) -> ArrayView[Byte] {
  @utf8.encode(text).to_array()[:]
}

///|
test "term: TermType 四变体展示" {
  assert_eq(Show::to_string(TermType::Iri), "Iri")
  assert_eq(Show::to_string(TermType::BNode), "BNode")
  assert_eq(Show::to_string(TermType::Literal), "Literal")
  assert_eq(Show::to_string(TermType::TripleTerm), "TripleTerm")
}

///|
test "term: 词项七变体展示（Iri/BNode/PrefName/TripleTerm/Variable/Literal/Formula）" {
  // 与原 Subject/Object 七变体臂文本逐字同（金样迁移，断言串不变）
  let buf = StringBuilder()
  show_term_view(TermKind::Iri, term_view("http://a"), buf)
  assert_eq(buf.to_string(), "<(8)>")
  let buf = StringBuilder()
  show_term_view(TermKind::BNode, term_view("_:b"), buf)
  assert_eq(buf.to_string(), "_:(3)")
  let buf = StringBuilder()
  show_term_view(TermKind::PrefName, term_view("ex:a"), buf)
  assert_eq(buf.to_string(), "(4)")
  let buf = StringBuilder()
  show_term_view(TermKind::TripleTerm, term_view("<<a>>"), buf)
  assert_eq(buf.to_string(), "(5)")
  let buf = StringBuilder()
  show_term_view(TermKind::Variable, term_view("?x"), buf)
  assert_eq(buf.to_string(), "?2")
  let buf = StringBuilder()
  show_term_view(TermKind::Literal, term_view("\"x\""), buf)
  assert_eq(buf.to_string(), "(3)")
  let buf = StringBuilder()
  show_term_view(TermKind::Formula, term_view("{ }"), buf)
  assert_eq(buf.to_string(), "(3)")
  // 位-种类非法组合臂（调试面显式点名，无金样钉）
  let buf = StringBuilder()
  show_term_view(TermKind::DefaultGraph, term_view(""), buf)
  assert_eq(buf.to_string(), "DefaultGraph")
}

///|
test "term: TermKind 裸名展示（P3 单 kind 轴新增面）" {
  assert_eq(Show::to_string(TermKind::Iri), "Iri")
  assert_eq(Show::to_string(TermKind::BNode), "BNode")
  assert_eq(Show::to_string(TermKind::PrefName), "PrefName")
  assert_eq(Show::to_string(TermKind::TripleTerm), "TripleTerm")
  assert_eq(Show::to_string(TermKind::Variable), "Variable")
  assert_eq(Show::to_string(TermKind::Literal), "Literal")
  assert_eq(Show::to_string(TermKind::Formula), "Formula")
  assert_eq(Show::to_string(TermKind::DefaultGraph), "DefaultGraph")
}

///|
test "term: QuadSpan 展示（graph 缺省 / 带图名两档）" {
  let plain : QuadSpan = {
    subj: term_view("s"),
    pred: term_view("p"),
    obj: term_view("o"),
    graph: None,
    subj_type: TermType::Iri,
    obj_type: TermType::Literal,
  }
  let text = Show::to_string(plain)
  assert_true(text.has_prefix("QuadSpan"))
  assert_true(text.contains("subj: s"))
  assert_true(text.contains("pred: p"))
  assert_true(text.contains("obj_type: Literal"))
  // 带图名档：graph 分支真的走 Some 侧
  let named : QuadSpan = { ..plain, graph: Some(term_view("g")), }
  assert_true(Show::to_string(named).contains("graph: g"))
}

///|
test "term: QuadEmit 展示（主/谓/宾 + 图名三档）" {
  let predicate : Predicate = term_view("p")
  let default_graph : QuadEmit = {
    s_kind: TermKind::Iri,
    s_view: term_view("http://a"),
    predicate,
    o_kind: TermKind::Literal,
    o_view: term_view("\"x\""),
    g_kind: TermKind::DefaultGraph,
    g_view: predicate[0:0],
  }
  assert_eq(
    Show::to_string(default_graph),
    "Quad(<(8)>, (1), (3), graph: None)",
  )
  let iri_graph : QuadEmit = {
    ..default_graph,
    g_kind: TermKind::Iri,
    g_view: term_view("http://g"),
  }
  assert_eq(Show::to_string(iri_graph), "Quad(<(8)>, (1), (3), graph: <(8)>)")
  let bnode_graph : QuadEmit = {
    ..default_graph,
    g_kind: TermKind::BNode,
    g_view: term_view("_:g"),
  }
  assert_eq(Show::to_string(bnode_graph), "Quad(<(8)>, (1), (3), graph: _:(3))")
  // 主语/宾语侧的 Iri 与 BNode 分支
  let bnode_subject : QuadEmit = {
    ..default_graph,
    s_kind: TermKind::BNode,
    s_view: term_view("_:s"),
    o_kind: TermKind::Iri,
    o_view: term_view("http://o"),
  }
  assert_eq(
    Show::to_string(bnode_subject),
    "Quad(_:(3), (1), <(8)>, graph: None)",
  )
}
