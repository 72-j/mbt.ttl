// ========================================
// Types — 类型映射层（手写版；目标形状 = 生成器产物 types.mbt）
// FSM: nquads_parser（引擎 = thy1016/moonttl/gen_nquads，step 由 [[transitions]] 生成）
// 规范: src/quick_machine/quick_machine.md §3.1 类型映射 / §11 补充清单
// 手写一版先跑通，再回灌 src/quick_machine 生成器。
// ========================================
// 映射约定：
//   Event   → Command （Span 载荷 → @qcs.Ref[RefId]，多载荷简化为单引用）
//   Effect  → Response（Continue/EmitQuad/Done；错误统一 Error(Int)，码见 system.mbt）
//   Context → Model   （只保留语义槽位；状态镜像为 ModelState）

// 引擎 Actions trait 的包内别名（引擎侧需 pub(open) 才能跨包实现，见 system.mbt）

///|
using @nquads {trait NQuadsActions}

///|
/// Span 的符号替身：符号期 Symbolic(Var)，执行期 Concrete(RefId)。
/// 编解码在 system.mbt：Span = (id, id)，往返可逆，模型与系统同值可比。
priv struct RefId {
  id : Int
} derive(Eq, Debug)

///|
/// Command - 测试命令类型（源 [[events]]）：每个 Event 变体对应一个 Command 变体
priv enum Command {
  Iri(@qcs.Ref[RefId])
  BlankNode(@qcs.Ref[RefId])
  Literal(@qcs.Ref[RefId])
  PrefName(@qcs.Ref[RefId])
  TripleTerm(@qcs.Ref[RefId])
  Comma
  Semicolon
  Dot
  Unknown
  EOF
} derive(Eq, Debug)

///|
/// Quad - EmitQuad 载荷的模型表示（槽位引用；graph 缺省 = 默认图）
priv struct Quad {
  subject : RefId
  predicate : RefId
  object : RefId
  graph : RefId?
} derive(Eq, Debug)

///|
/// Response - 测试响应类型（源 [[effects]] + 错误归一化）
priv enum Response {
  Continue
  EmitQuad(Quad)
  Done
  Error(Int)
} derive(Eq, Debug)

///|
/// ModelState - 纯模型状态枚举（镜像引擎 NQuadsState，独立于引擎包）
priv enum ModelState {
  ExpectSubject
  ExpectPredicate
  ExpectObject
  ExpectDotOrGraph
  ExpectDot
} derive(Eq, Debug)

///|
/// Model - 纯模型（规格，不是被测实现）：状态 + 四个语义槽位
priv struct Model {
  state : ModelState
  subject : RefId?
  predicate : RefId?
  object : RefId?
  graph : RefId?
} derive(Eq, Debug)

///|
/// 初始模型：ExpectSubject，槽位全空
fn model_empty() -> Model {
  {
    state: ExpectSubject,
    subject: None,
    predicate: None,
    object: None,
    graph: None,
  }
}

///|
/// 符号引用取具体值：符号期返回 None，执行期返回 Some
fn ref_id(reference : @qcs.Ref[RefId]) -> RefId? {
  match reference {
    Concrete(id) => Some(id)
    Symbolic(_) => None
  }
}

///|
/// 执行期引用必为 Concrete；防御性兜底 id = 0
fn concrete_ref_id(reference : @qcs.Ref[RefId]) -> RefId {
  match reference {
    Concrete(id) => id
    Symbolic(_) => { id: 0, }
  }
}

///|
test "nquads quick machine types" {
  let model = model_empty()
  assert_eq(model.state, ExpectSubject)
  assert_eq(ref_id(Concrete({ id: 7, })), Some({ id: 7, }))
  assert_true(ref_id(Symbolic(@qcs.Var::{ id: 0, })) is None)
  assert_eq(concrete_ref_id(Symbolic(@qcs.Var::{ id: 0, })), { id: 0, })
}
