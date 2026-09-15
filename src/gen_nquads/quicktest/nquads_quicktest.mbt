// ========================================
// NQuads QuickMachine — 业务补充层 + 状态机组装（手写版）
// 骨架：types.mbt / valid.mbt / model_exec.mbt / system.mbt；运行器：runner.mbt
// 本文件承载生成器无法自动生成的部分（quick_machine.md §二 P2-P5）：
//   P2 generator（参数范围与权重）/ mock（符号响应）
//   P3 response_vars / reify_command / bind_response（本 FSM 无符号变量，直通）
//   P4 shrinker / remap_command（引用值收缩）
//   P5 postcondition（严格双执行比较）/ invariant（槽位一致性）
// 组装点唯一：quick_state_machine；替换业务实现只改本文件。
// ========================================

///|
/// 引用取值范围（源 [business].ref_id_range）：越小越利于 shrink 收敛
const REF_ID_RANGE : Int = 8

///|
/// 命令权重（源 [business.weights]；未声明默认 1，0 表示禁用）
/// 权重只影响选择概率，合法性仍由 valid 过滤（转移表是唯一权威）
fn command_weight(name : String) -> Int {
  match name {
    "Iri" => 3
    "BlankNode" => 2
    "Literal" => 2
    "Dot" => 3
    _ => 1
  }
}

///|
/// 新引用：取值模 REF_ID_RANGE（有限取值空间利于失败复现）
fn fresh_ref(rng : @splitmix.RandomState) -> @qcs.Ref[RefId] {
  Concrete({ id: rng.next_positive_int() % REF_ID_RANGE, })
}

///|
/// P2 generator: 候选全构造 → valid 过滤 → 权重抽取（无合法候选返回 None）
///
/// **size 口径（P2 声明）**：本 FSM 的 `size` 不参与分布——命令合法性完全由
/// 转移表（valid）决定，序列收缩由 P4 shrinker 负责，`size` 在此无可加权的
/// 语义（生成器若将来要"按 size 收束"，接在这里）。`ignore(size)` 是显式声明，
/// 不是遗漏；下面的 "size 不影响分布" 测试把它钉成可验证事实。
fn generate_command(
  model : Model,
  size : Int,
  rng : @splitmix.RandomState,
) -> Command? {
  ignore(size)
  let names : Array[String] = [
    "Iri", "BlankNode", "Literal", "PrefName", "TripleTerm", "Comma", "Semicolon",
    "Dot", "Unknown", "EOF",
  ]
  let candidates : Array[Command] = [
    Iri(fresh_ref(rng)),
    BlankNode(fresh_ref(rng)),
    Literal(fresh_ref(rng)),
    PrefName(fresh_ref(rng)),
    TripleTerm(fresh_ref(rng)),
    Comma,
    Semicolon,
    Dot,
    Unknown,
    EOF,
  ]
  let weighted : Array[(Command, Int)] = []
  for index = 0; index < candidates.length(); index = index + 1 {
    let command = candidates[index]
    if valid(model, command) {
      let weight = command_weight(names[index])
      if weight > 0 {
        weighted.push((command, weight))
      }
    }
  }
  let mut total = 0
  for entry in weighted {
    total = total + entry.1
  }
  if total == 0 {
    return None // 无合法候选：交给 qcs 判 Deadlock
  }
  let mut pick = rng.next_positive_int() % total
  for entry in weighted {
    if pick < entry.1 {
      return Some(entry.0)
    }
    pick = pick - entry.1
  }
  None
}

///|
/// P2 mock: 复用纯模型预测符号响应（本 FSM 不产生新符号变量）
fn mock_command(
  model : Model,
  command : Command,
  gen_sym : @qcs.GenSym,
) -> (Response, @qcs.GenSym) {
  let (_, response) = model_execute(model, command)
  (response, gen_sym)
}

///|
/// P3 response_vars: 响应不携带新资源（无新建节点引用），无变量可提取
fn response_vars(_response : Response) -> Array[@qcs.Var] {
  []
}

///|
/// 单个引用解析: Concrete 透传，Symbolic 查环境（缺变量报错）
fn reify_ref(
  reference : @qcs.Ref[RefId],
  env : @qcs.Environment[RefId],
) -> Result[@qcs.Ref[RefId], @qcs.EnvError] {
  match reference {
    Concrete(_) => Ok(reference)
    Symbolic(variable) =>
      match env.lookup(variable) {
        Ok(id) => Ok(Concrete(id))
        Err(error) => Err(error)
      }
  }
}

///|
/// P3 reify_command: 逐载荷解析 Symbolic → Concrete
fn reify_command(
  command : Command,
  env : @qcs.Environment[RefId],
) -> Result[Command, @qcs.EnvError] {
  match command {
    Iri(reference) =>
      match reify_ref(reference, env) {
        Ok(resolved) => Ok(Iri(resolved))
        Err(error) => Err(error)
      }
    BlankNode(reference) =>
      match reify_ref(reference, env) {
        Ok(resolved) => Ok(BlankNode(resolved))
        Err(error) => Err(error)
      }
    Literal(reference) =>
      match reify_ref(reference, env) {
        Ok(resolved) => Ok(Literal(resolved))
        Err(error) => Err(error)
      }
    PrefName(reference) =>
      match reify_ref(reference, env) {
        Ok(resolved) => Ok(PrefName(resolved))
        Err(error) => Err(error)
      }
    TripleTerm(reference) =>
      match reify_ref(reference, env) {
        Ok(resolved) => Ok(TripleTerm(resolved))
        Err(error) => Err(error)
      }
    Comma => Ok(Comma)
    Semicolon => Ok(Semicolon)
    Dot => Ok(Dot)
    Unknown => Ok(Unknown)
    EOF => Ok(EOF)
  }
}

///|
/// P3 bind_response: 环境透传（响应无新变量）
fn bind_response(
  _symbolic : Response,
  _concrete : Response,
  env : @qcs.Environment[RefId],
) -> Result[@qcs.Environment[RefId], @qcs.BindError] {
  Ok(env)
}

///|
/// P4 remap_command: 命令无符号变量引用，恒可保留
fn remap_command(
  command : Command,
  _scope : Map[@qcs.Var, @qcs.Var],
) -> Command? {
  Some(command)
}

///|
/// 引用收缩候选：id 减半、归零（span 替身取值空间有限，越小越易读）
fn shrink_ref(reference : @qcs.Ref[RefId]) -> Array[@qcs.Ref[RefId]] {
  match reference {
    Concrete(id) if id.id > 0 =>
      [Concrete({ id: id.id / 2, }), Concrete({ id: 0, })]
    _ => []
  }
}

///|
/// P4 shrinker: 只收缩引用载荷；结构命令（Dot/Comma/…）本身已是最简
///
/// 候选设计 = per-slot 收缩思路在本框架的**单载荷退化形**：
///   - 命令在类型映射层恒为"单引用或原子"（spec §2：多载荷 Event 降为单引用），
///     per-slot 候选矩阵（s/p/o/g 各自换最简值）在此退化为单槽候选；
///   - `Concrete(0)` = 最小值替换（simple_uri(0) 同构）；
///   - `id/2` = 数值二分，大 id 时比直接跳 0 收敛更快（两候选可叠加）；
///   - 结构简化分支（如 Query→PatternAll）无对应：本 FSM 命令原子，序列级
///     "删命令"收缩已被实测否决（见 metrics.mbt 文件头 ④ 与"收缩机制"测试）。
fn shrink_command(_model : Model, command : Command) -> Array[Command] {
  match command {
    Iri(reference) => shrink_ref(reference).map(fn(smaller) { Iri(smaller) })
    BlankNode(reference) =>
      shrink_ref(reference).map(fn(smaller) { BlankNode(smaller) })
    Literal(reference) =>
      shrink_ref(reference).map(fn(smaller) { Literal(smaller) })
    PrefName(reference) =>
      shrink_ref(reference).map(fn(smaller) { PrefName(smaller) })
    TripleTerm(reference) =>
      shrink_ref(reference).map(fn(smaller) { TripleTerm(smaller) })
    _ => []
  }
}

///|
/// P5 postcondition: 严格双执行比较（含错误码）——宁可误报，不可漏报
fn postcondition(
  model : Model,
  command : Command,
  response : Response,
) -> @qcs.Logic {
  let (_, expected) = model_execute(model, command)
  @qcs.Logic::predicate(name="model matches system", value=expected == response)
}

///|
/// P5 invariant: 槽位一致性（状态决定哪些槽位必须已填、哪些必空）
fn slots_consistent(model : Model) -> Bool {
  let subject_set = model.subject is Some(_)
  let predicate_set = model.predicate is Some(_)
  let object_set = model.object is Some(_)
  let graph_set = model.graph is Some(_)
  match model.state {
    ExpectSubject => !subject_set && !predicate_set && !object_set && !graph_set
    ExpectPredicate =>
      subject_set && !predicate_set && !object_set && !graph_set
    ExpectObject => subject_set && predicate_set && !object_set && !graph_set
    ExpectDotOrGraph => subject_set && predicate_set && object_set && !graph_set
    ExpectDot => subject_set && predicate_set && object_set && graph_set
  }
}

///|
fn model_invariant(model : Model) -> @qcs.Logic {
  @qcs.Logic::predicate(name="slot consistency", value=slots_consistent(model))
}

///|
test "nquads quick machine invariant 负例矩阵" {
  // 恒真不变量检测不出模型漂移；与 drift 注入同思想：先证明"尺子会咬人"，再信绿。
  // 五状态各构造一个违反槽位形态的模型（源 slots_consistent 的五臂取反），必须全 false。
  let broken : Array[Model] = [
    { ..model_empty(), subject: Some({ id: 1, }), }, // ExpectSubject: 槽位应全空
    { ..model_empty(), state: ExpectPredicate, predicate: Some({ id: 2, }), }, // ExpectPredicate: predicate 应空
    { ..model_empty(), state: ExpectObject, object: Some({ id: 3, }), }, // ExpectObject: object 应空
    { ..model_empty(), state: ExpectDotOrGraph, graph: Some({ id: 4, }), }, // ExpectDotOrGraph: graph 应空
    {
      state: ExpectDot,
      subject: Some({ id: 1, }),
      predicate: Some({ id: 2, }),
      object: Some({ id: 3, }),
      graph: None,
    }, // ExpectDot: graph 必须已填
  ]
  for model in broken {
    assert_false(slots_consistent(model))
    match model_invariant(model) {
      @qcs.Logic::Predicate(value=false, ..) => () // 谓词真的给出 false
      _ => fail("invariant 必须给出可判定的 false 谓词")
    }
  }
}

///|
test "nquads quick machine shrink 候选恒合法（安全性）" {
  // shrink 安全性判定（P4）：收缩候选不得把合法命令变成非法——否则前置条件会
  // 悄悄否决全部候选，收缩静默失效。本 FSM 载荷值不参与 valid；这条钉住
  // "将来 valid 引用载荷值"时不许悄悄变卦。
  for state in all_states() {
    let model = ready_model(state)
    for command in all_commands() {
      if valid(model, command) {
        for smaller in shrink_command(model, command) {
          assert_true(valid(model, smaller))
        }
      }
    }
  }
}

///|
/// 命令名（覆盖率报告用，源 [[events]]）
fn command_name(command : Command) -> String {
  match command {
    Iri(_) => "Iri"
    BlankNode(_) => "BlankNode"
    Literal(_) => "Literal"
    PrefName(_) => "PrefName"
    TripleTerm(_) => "TripleTerm"
    Comma => "Comma"
    Semicolon => "Semicolon"
    Dot => "Dot"
    Unknown => "Unknown"
    EOF => "EOF"
  }
}

///|
/// 组装状态机（quick_machine.md §七）：回调注入点集中在此
/// system_call 可替换，用于反例注入（验证机器真能发现系统漂移）
/// label 提供**语义路径指标**：响应分档（continue / emit / emit:graph / done / error），
/// 供 RunConfig.required_labels 做"路径覆盖门"（命令名粒度之外的第二层覆盖）
fn quick_state_machine(
  system_call? : (Command, System) -> Response = run_command,
) -> @qcs.StateMachine[
  Model,
  Model,
  Command,
  Command,
  Response,
  Response,
  RefId,
  System,
] {
  @qcs.StateMachine::new(
    init_symbolic_model=model_empty,
    init_concrete_model=model_empty,
    init_system=() => system_init(),
    generator=generate_command,
    mock=mock_command,
    transition_symbolic=transition,
    transition_concrete=transition,
    precondition~,
    postcondition~,
    invariant=model_invariant,
    response_vars~,
    shrinker=shrink_command,
    remap_command~,
    reify_command~,
    run_command=(command, system) => system_call(command, system),
    bind_response~,
    label=(_model, _command, response) => {
      match response {
        Continue => ["resp:continue"]
        EmitQuad(quad) =>
          if quad.graph is Some(_) {
            ["resp:emit", "resp:emit:graph"]
          } else {
            ["resp:emit", "resp:emit:default"]
          }
        Done => ["resp:done"]
        Error(_) => ["resp:error"]
      }
    },
    command_name~,
  )
}

///|
test "nquads quick machine generate respects valid table" {
  let rng = @splitmix.new(seed=12345UL)
  let mut model = model_empty()
  let mut steps = 0
  for ;; {
    match generate_command(model, 10, rng) {
      Some(command) => {
        assert_true(valid(model, command))
        let (_, response) = model_execute(model, command)
        model = transition(model, command, response)
        steps = steps + 1
        if steps >= 40 {
          break
        }
      }
      None =>
        fail(
          "generate_command 返回 None（五状态恒有出边，不应发生）",
        )
    }
  }
  assert_true(slots_consistent(model))
}

///|
test "nquads quick machine shrinker reduces refs" {
  // 结构命令已是最简；引用载荷给 id 减半与归零两个候选
  assert_eq(shrink_command(model_empty(), Dot), [])
  assert_eq(shrink_command(model_empty(), Iri(Concrete({ id: 5, }))), [
    Iri(Concrete({ id: 2, })),
    Iri(Concrete({ id: 0, })),
  ])
}

///|
/// P2 口径测试：同一 seed、不同 size → 命令序列逐条一致（size 不参与分布）
fn generated_prefix(seed : UInt64, size : Int, steps : Int) -> Array[Command] {
  let rng = @splitmix.new(seed~)
  let out : Array[Command] = []
  let mut model = model_empty()
  let mut taken = 0
  while taken < steps {
    match generate_command(model, size, rng) {
      Some(command) => {
        let (_, response) = model_execute(model, command)
        model = transition(model, command, response)
        out.push(command)
      }
      None => break
    }
    taken = taken + 1
  }
  out
}

///|
test "nquads quick machine size 不影响分布（P2 口径）" {
  assert_eq(
    generated_prefix(12345UL, 1, 25),
    generated_prefix(12345UL, 200, 25),
  )
  assert_eq(generated_prefix(7UL, 3, 25), generated_prefix(7UL, 999, 25))
}

///|
/// 无转移命令（PrefName / EOF）必须被两条路径一致拒绝：
/// valid=false（生成期过滤）+ 系统归一到未定义转移码（执行期）；
/// 且非法命令不推进纯模型。
test "nquads quick machine 无转移命令被拒" {
  let model = model_empty()
  assert_false(valid(model, PrefName(Concrete({ id: 1, }))))
  assert_false(valid(model, EOF))
  let system = system_init()
  assert_eq(
    run_command(PrefName(Concrete({ id: 1, })), system),
    Error(UNDEFINED_TRANSITION_CODE),
  )
  assert_eq(run_command(EOF, system), Error(UNDEFINED_TRANSITION_CODE))
  let (after, response) = model_execute(model, PrefName(Concrete({ id: 1, })))
  assert_eq(response, Error(0))
  assert_eq(after, model)
}
