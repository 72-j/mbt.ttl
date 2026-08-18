// ===== QuickMachine Types - 类型映射层（nquads 解析器 FSM）=====
// quicktest.md 3.1 类型映射:
//   Event   → Command   (Span 载荷 → Ref[RefId] 符号引用)
//   Effect  → Response  (错误统一 Error(Int); Goto 归 Continue)
//   Context → Model     (只保留语义相关字段)
//
// 双重身份: 本文件是 nquads 实例的具体落地,
// 也是 fsm 生成器后续自动生成 command.mbt/response.mbt/model.mbt 的模板基准。

///|
/// Span 的符号替身: 生成期引用以 Symbolic(Var) 表示,
/// 执行期由环境解析为 Concrete(RefId)。测试无需构造真实 Span。
struct RefId {
  id : Int
} derive(Eq, Debug)

///|
/// Command - 测试命令类型（源: test_nquads.toml 的 [[events]]）
/// 载荷 Span 全部替换为符号引用, 解决 "Span 无法在测试中构造" 的风险
enum Command {
  Iri(@qcs.Ref[RefId])
  BlankNode(@qcs.Ref[RefId])
  Literal(@qcs.Ref[RefId]) // lang 可空载荷不进模型, 简化为单引用
  Dot
  PrefName(@qcs.Ref[RefId])
  Unknown
  EOF
} derive(Eq, Debug)

///|
/// Quad - 四元组的模型表示（EmitQuad 的载荷, 全部用 RefId 引用）
struct Quad {
  subject : RefId
  predicate : RefId
  object : RefId
  graph : RefId? // 图名可空 = 默认图
} derive(Eq, Debug)

///|
/// Response - 测试响应类型（源: test_nquads.toml 的 [[effects]]）
/// SkipError 的 Span 载荷、Goto 的 State 载荷不进模型; 错误统一 Error(Int)
pub(all) enum Response {
  Continue
  EmitQuad(Quad)
  SkipLine
  SkipError
  Done
  Error(Int)
} derive(Eq, Debug)

///|
/// ModelState - 纯模型的状态枚举（镜像生成的 State 枚举, 独立于生成包）
enum ModelState {
  ExpectSubject
  ExpectPredicate
  ExpectObject
  ExpectDotOrGraph
  ExpectDot
  Complete
} derive(Eq, Debug)

///|
/// Model - 纯模型（源: Context 的语义字段）
/// 是规格而非被测实现: 用于检查真实执行器的行为
struct Model {
  state : ModelState
  subject : RefId?
  predicate : RefId?
  object : RefId?
  graph : RefId?
} derive(Eq, Debug)

///|
/// 初始模型: ExpectSubject, 槽位全空
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
/// 符号引用取具体值: 生成期 Symbolic 返回 None, 执行期 Concrete 返回 Some
fn ref_id(reference : @qcs.Ref[RefId]) -> RefId? {
  match reference {
    Concrete(id) => Some(id)
    Symbolic(_) => None
  }
}

///|
test {
  // 类型映射: 初始模型与引用解包
  let model = model_empty()
  assert_eq(model.state, ExpectSubject)
  assert_true(model.subject is None)

  let concrete : @qcs.Ref[RefId] = Concrete({ id: 7 })
  assert_eq(ref_id(concrete), Some({ id: 7 }))

  let symbolic : @qcs.Ref[RefId] = Symbolic(@qcs.Var::{ id: 0 })
  assert_true(ref_id(symbolic) is None)

  // Quad / Response 构造
  let quad = Quad::{
    subject: { id: 1 },
    predicate: { id: 2 },
    object: { id: 3 },
    graph: None,
  }
  assert_true(EmitQuad(quad) is EmitQuad(_))
}
