// ===== Constraint - 约束生成器 =====
// quicktest.md 3.2: 从转移表生成 valid 函数。
// valid 是客户端契约: 只有转移表中声明的 (状态, 命令) 组合合法,
// 生成器据此避免产生非法命令序列（Deadlock 防护）。

///|
/// 检查命令在当前模型状态下是否合法（源: test_nquads.toml 转移表）
fn valid(model : Model, cmd : Command) -> Bool {
  match (model.state, cmd) {
    // ExpectSubject: 主语位
    (ExpectSubject, Iri(_)) => true
    (ExpectSubject, BlankNode(_)) => true
    (ExpectSubject, PrefName(_)) => true
    (ExpectSubject, Unknown) => true

    // ExpectPredicate: 谓语位（必须为 IRI）
    (ExpectPredicate, Iri(_)) => true
    (ExpectPredicate, BlankNode(_)) => true
    (ExpectPredicate, Literal(_)) => true
    (ExpectPredicate, Dot) => true

    // ExpectObject: 宾语位
    (ExpectObject, Iri(_)) => true
    (ExpectObject, BlankNode(_)) => true
    (ExpectObject, Literal(_)) => true
    (ExpectObject, Dot) => true

    // ExpectDotOrGraph: 收尾三元组或图名
    (ExpectDotOrGraph, Dot) => true
    (ExpectDotOrGraph, Iri(_)) => true
    (ExpectDotOrGraph, PrefName(_)) => true
    (ExpectDotOrGraph, Unknown) => true

    // ExpectDot: 图名之后必须收尾
    (ExpectDot, Dot) => true
    (ExpectDot, Iri(_)) => true

    // Complete: 下一条三元组或结束
    (Complete, Iri(_)) => true
    (Complete, BlankNode(_)) => true
    (Complete, EOF) => true

    // 兜底: 未定义转移非法
    (_, _) => false
  }
}

///|
/// 前置条件（客户端契约, quickcheck_statemachine 接口形态）
fn precondition(model : Model, command : Command) -> @qcs.Logic {
  @qcs.Logic::predicate(name="valid transition", value=valid(model, command))
}

///|
test {
  // 主语位: Iri/BlankNode/PrefName/Unknown 合法; Dot/Literal/EOF 非法
  let model = model_empty()
  assert_true(valid(model, Iri(Concrete({ id: 1 }))))
  assert_true(valid(model, BlankNode(Concrete({ id: 1 }))))
  assert_true(valid(model, PrefName(Concrete({ id: 1 }))))
  assert_true(valid(model, Unknown))
  assert_false(valid(model, Dot))
  assert_false(valid(model, Literal(Concrete({ id: 1 }))))
  assert_false(valid(model, EOF))

  // precondition 返回 Logic 谓词
  let logic = precondition(model, Dot)
  assert_true(logic is @qcs.Logic::Predicate(..))
}

///|
test {
  // 各状态约束与转移表一致
  let in_predicate = { ..model_empty(), state: ExpectPredicate }
  assert_true(valid(in_predicate, Iri(Concrete({ id: 2 }))))
  assert_false(valid(in_predicate, Unknown))

  let in_object = { ..model_empty(), state: ExpectObject }
  assert_true(valid(in_object, Literal(Concrete({ id: 3 }))))
  assert_false(valid(in_object, PrefName(Concrete({ id: 3 }))))

  let in_dot_or_graph = { ..model_empty(), state: ExpectDotOrGraph }
  assert_true(valid(in_dot_or_graph, Dot))
  assert_false(valid(in_dot_or_graph, BlankNode(Concrete({ id: 4 }))))

  let in_dot = { ..model_empty(), state: ExpectDot }
  assert_true(valid(in_dot, Dot))
  assert_false(valid(in_dot, BlankNode(Concrete({ id: 4 }))))

  let complete = { ..model_empty(), state: Complete }
  assert_true(valid(complete, EOF))
  assert_false(valid(complete, Literal(Concrete({ id: 5 }))))
}
