// 展示面（Show）逐变体测试。
// 背景（覆盖率实测 2026-09-18）：term.mbt 五个 Show impl 此前是 0/128 行覆盖——
// 产物侧只有 struct 定义被引用，展示面从没被跑过。本文件按变体逐个断言**输出串**，
// 不只"跑过就算"：QuadSpan/QuadEmit 的格式是调试面契约，漂了要能被看见。
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
test "term: Subject 七变体展示（Iri/BNode/PrefName/TripleTerm/Variable/Literal/Formula）" {
  assert_eq(Show::to_string(Subject::Iri(term_view("http://a"))), "<(8)>")
  assert_eq(Show::to_string(Subject::BNode(term_view("_:b"))), "_:(3)")
  assert_eq(Show::to_string(Subject::PrefName(term_view("ex:a"))), "(4)")
  assert_eq(Show::to_string(Subject::TripleTerm(term_view("<<a>>"))), "(5)")
  assert_eq(Show::to_string(Subject::Variable(term_view("?x"))), "?2")
  assert_eq(Show::to_string(Subject::Literal(term_view("\"x\""))), "(3)")
  assert_eq(Show::to_string(Subject::Formula(term_view("{ }"))), "(3)")
}

///|
test "term: Object 七变体展示（Iri/BNode/Literal/TripleTerm/PrefName/Variable/Formula）" {
  assert_eq(Show::to_string(Object::Iri(term_view("http://a"))), "<(8)>")
  assert_eq(Show::to_string(Object::BNode(term_view("_:b"))), "_:(3)")
  assert_eq(Show::to_string(Object::Literal(term_view("\"x\""))), "(3)")
  assert_eq(Show::to_string(Object::TripleTerm(term_view("<<a>>"))), "(5)")
  assert_eq(Show::to_string(Object::PrefName(term_view("ex:a"))), "(4)")
  assert_eq(Show::to_string(Object::Variable(term_view("?x"))), "?2")
  assert_eq(Show::to_string(Object::Formula(term_view("{ }"))), "(3)")
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
  let subject : Subject = Subject::Iri(term_view("http://a"))
  let predicate : Predicate = term_view("p")
  let object_ : Object = Object::Literal(term_view("\"x\""))
  let default_graph : QuadEmit = {
    subject,
    predicate,
    object: object_,
    graph: GraphName::None,
  }
  assert_eq(
    Show::to_string(default_graph),
    "Quad(<(8)>, (1), (3), graph: None)",
  )
  let iri_graph : QuadEmit = {
    ..default_graph,
    graph: GraphName::Iri(term_view("http://g")),
  }
  assert_eq(Show::to_string(iri_graph), "Quad(<(8)>, (1), (3), graph: <(8)>)")
  let bnode_graph : QuadEmit = {
    ..default_graph,
    graph: GraphName::BNode(term_view("_:g")),
  }
  assert_eq(Show::to_string(bnode_graph), "Quad(<(8)>, (1), (3), graph: _:(3))")
  // 主语/宾语侧的 Iri 与 BNode 分支
  let bnode_subject : QuadEmit = {
    ..default_graph,
    subject: Subject::BNode(term_view("_:s")),
    object: Object::Iri(term_view("http://o")),
  }
  assert_eq(
    Show::to_string(bnode_subject),
    "Quad(_:(3), (1), <(8)>, graph: None)",
  )
}
