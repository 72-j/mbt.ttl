// ========================================
// Valid — 转移表约束（目标形状 = 生成器产物 valid.mbt）
// valid 是客户端契约：只有转移表声明的 (状态, 命令) 组合合法，
// 生成器据此避免非法命令序列（Deadlock 防护）。
// ========================================

///|
/// 检查命令在当前模型状态下是否合法（源 [[transitions]]）
fn valid(model : Model, cmd : Command) -> Bool {
  match (model.state, cmd) {
    // ExpectSubject
    (ExpectSubject, Iri(_)) => true
    (ExpectSubject, BlankNode(_)) => true
    // ExpectPredicate
    (ExpectPredicate, Iri(_)) => true
    // ExpectObject
    (ExpectObject, Iri(_)) => true
    (ExpectObject, BlankNode(_)) => true
    (ExpectObject, Literal(_)) => true
    (ExpectObject, TripleTerm(_)) => true
    // ExpectDotOrGraph
    (ExpectDotOrGraph, Iri(_)) => true
    (ExpectDotOrGraph, BlankNode(_)) => true
    (ExpectDotOrGraph, Dot) => true
    (ExpectDotOrGraph, Comma) => true
    (ExpectDotOrGraph, Semicolon) => true
    (ExpectDotOrGraph, Unknown) => true
    // ExpectDot
    (ExpectDot, Dot) => true
    // 兜底: 未定义转移非法（PrefName/EOF 在本 FSM 无转移）
    (_, _) => false
  }
}

///|
/// 前置条件（quickcheck_statemachine 接口形态，策略 valid_table）
fn precondition(model : Model, command : Command) -> @qcs.Logic {
  @qcs.Logic::predicate(name="valid transition", value=valid(model, command))
}

///|
test "nquads quick machine valid table" {
  let model = model_empty()
  assert_true(valid(model, Iri(Concrete({ id: 1, }))))
  assert_false(valid(model, Literal(Concrete({ id: 1, }))))
  assert_false(valid(model, EOF))
  assert_true(
    precondition(model, Iri(Concrete({ id: 1, }))) is @qcs.Logic::Predicate(..),
  )
}
