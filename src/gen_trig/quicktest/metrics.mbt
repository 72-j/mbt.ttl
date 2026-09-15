// ========================================
// Metrics — 指标口径门（trig quicktest / **手维护补充层**，对齐 nquads 样板）
// FSM: trig_parser | Config: trig_quick_machine
// ========================================
// 分离纪律：本文件与 system.mbt 同属手维护层——生成器 bootstrap 只在目录缺失时
// 物化六份骨架文件，本文件**不在生成清单内**，再生不覆盖，可放心扩充。
//
// **本文件即 trig quicktest "什么算够"的事实源**（口径对齐 nquads metrics.mbt）：
//   ① 转移普查：valid 表 ⟺ model_exec 表全 (状态,命令) 对一致性 + 计数守恒
//   ② 结构钉子：BFS 可达状态集 / 可达命令名 / 死态（ExpectVerbRequired 无入臂）
//   ③ 无死锁门：可达状态恒有合法候选（多种子）；死态不可达 ⇒ 运行期 Deadlock 不可能
//   ④ 强制形态矩阵：BFS 派生"单槽位形态"状态集的负例矩阵（invariant 的可测子集）
//   ⑤ 权重口径 / shrink 安全性 / remap 恒等
//   ⑥ label 钉子：resp:Done 不可达（引擎机制活、表零引用——与 nquads 同款"声明未引用"）
//
// **P4.2d 阻塞门与已知模型盲区（口径纪律：不适用要写明，不悄悄删）**：
//   阻塞门：随机属性门 / 覆盖率运行门 / shrink 收敛门 / 多种子 random check——
//   四门都需要 "模型 ≡ 引擎"在随机探索下成立。已知漂移领土（P4.2d，复开前先清账）：
//   ① 注解收集态（step 6 Semicolon，见 runner.mbt P4.2c 战报）；
//   ② directive_at 盲区（引擎 (ExpectDirectiveEnd, Dot) 挂 @守卫，模型无字段恒
//      Continue——本役引擎实测新发现，锚点门②避路绕行）；
//   ③ list slot_stack 盲区（list_first 经栈发射 EmitQuad(PredObj)，模型无栈字段
//      恒 Error(1) 吸收 ⇒ ListAfterElem 模型侧不可达——本役 BFS 新发现）；
//   ④ 图块 graph=Some（引擎发射带图名，模型 graph 恒 None）。
//   P4.2d 收口后从注释里复活四门并扩全形态表。
// ========================================

///|
/// 全部状态（源 [[states]]，36 个）
fn all_states() -> Array[ModelState] {
  [
    ExpectSubject,
    ExpectPredicate,
    ExpectObject,
    ExpectDotOrGraph,
    ExpectDirectiveKind,
    ExpectPrefixName,
    ExpectPrefixIri,
    ExpectBaseIri,
    ExpectVersionLiteral,
    ExpectDirectiveEnd,
    ExpectGraphLabel,
    ExpectGraphLbrace,
    ExpectVerbOrEnd,
    ExpectVerbOrDot,
    ExpectVerbRequired,
    ExpectTildeEnd,
    AnnotExpectVerb,
    AnnotExpectVerbTail,
    AnnotExpectObject,
    AnnotExpectEnd,
    GraphAnnotExpectVerb,
    GraphAnnotExpectVerbTail,
    GraphAnnotExpectObject,
    GraphAnnotExpectEnd,
    GraphExpectSubject,
    GraphExpectPredicate,
    GraphExpectObject,
    GraphExpectDotOrGraph,
    GraphExpectVerbOrDot,
    GraphExpectTildeEnd,
    GraphExpectVerbOrEnd,
    BnpExpectPredicate,
    BnpExpectObject,
    BnpAfterObject,
    ListExpectElemOrEnd,
    ListAfterElem,
  ]
}

///|
/// 全部命令构造子（各带具体载荷；源 [[events]]，34 个）
fn all_commands() -> Array[Command] {
  [
    Iri(Concrete({ id: 1, })),
    BlankNode(Concrete({ id: 1, })),
    Literal(Concrete({ id: 1, })),
    PrefName(Concrete({ id: 1, })),
    TripleTerm(Concrete({ id: 1, })),
    BracketTripleTerm(Concrete({ id: 1, })),
    KeywordA(Concrete({ id: 1, })),
    At,
    PrefixKw,
    BaseKw,
    GraphKw,
    VersionKw,
    Tilde,
    AnnotStart,
    AnnotEnd,
    Comma,
    Semicolon,
    Dot,
    Lbrace,
    Rbrace,
    Lbracket(Concrete({ id: 1, })),
    Rbracket,
    Lparen(Concrete({ id: 1, })),
    Rparen,
    Anon(Concrete({ id: 1, })),
    Bang,
    Caret,
    Implies,
    ImpliedBy,
    ForAllKw,
    ForSomeKw,
    KeywordsKw,
    Unknown,
    EOF,
  ]
}

///|
/// 命令名（与 command_name 同口径，表格判定用）
fn name_of(command : Command) -> String {
  command_name(command)
}

///|
/// 指定状态的全空槽模型（普查起点：合法性只由 (状态, 命令) 决定，与槽位无关）
fn blank_model(state : ModelState) -> Model {
  { ..model_empty(), state, }
}

///|
/// 模型的槽位形态键（BFS 去重用）：状态 + 三槽有无
fn slot_key(model : Model) -> (ModelState, Bool, Bool, Bool) {
  (
    model.state,
    model.subject is Some(_),
    model.predicate is Some(_),
    model.object is Some(_),
  )
}

///|
/// 每状态首个到达模型的关联表查找（ModelState 无 Hash，不能进 Map）
fn state_model_of(
  models : Array[(ModelState, Model)],
  state : ModelState,
) -> Model? {
  for entry in models {
    let (s, model) = entry
    if s == state {
      return Some(model)
    }
  }
  None
}

///|
/// BFS 结构勘探：从 model_empty 出发沿全部合法边推进（Concrete 载荷）。
/// 返回（可达 (状态,形态) 键集、每状态首个到达模型、可达命令名集）。
/// 这是"生成表的结构事实"的运行期派生源——不手抄转移表，生成表一变这里就变。
fn explore() -> (
  Array[(ModelState, Bool, Bool, Bool)],
  Array[(ModelState, Model)],
  Array[String],
) {
  let start = model_empty()
  let seen : Array[(ModelState, Bool, Bool, Bool)] = [slot_key(start)]
  let queue : Array[Model] = [start]
  let state_models : Array[(ModelState, Model)] = [(start.state, start)]
  let names : Array[String] = []
  let mut index = 0
  while index < queue.length() {
    let model = queue[index]
    index = index + 1
    for command in all_commands() {
      if valid(model, command) {
        let name = name_of(command)
        if !names.contains(name) {
          names.push(name)
        }
        let (_, response) = model_execute(model, command)
        let next = transition(model, command, response)
        let key = slot_key(next)
        if !seen.contains(key) {
          seen.push(key)
          queue.push(next)
          if state_model_of(state_models, next.state) is None {
            state_models.push((next.state, next))
          }
        }
      }
    }
  }
  (seen, state_models, names)
}

///|
/// ① 转移普查门：全部 (状态, 命令) 对（36 × 34 = 1224）从全空槽模型逐对判定——
/// valid 表与 model_exec 表是 [[transitions]] 的两份独立生成物，任一单方面改动
/// （部分再生 / 手改漂移）都会在这里红。
test "指标·转移普查: valid ⟺ model_exec 全对一致 + 计数守恒" {
  let mut legal = 0
  let mut illegal = 0
  for state in all_states() {
    for command in all_commands() {
      let model = blank_model(state)
      let (next, response) = model_execute(model, command)
      if valid(model, command) {
        legal = legal + 1
        // 合法转移的响应构造子空间：Continue / EmitQuad / Error(1)——
        // 绝不是未定义码 Error(0)，也绝不是 Done（Done 声明未引用，见 label 钉子门）
        assert_false(response is Error(0))
        assert_false(response is Done)
      } else {
        illegal = illegal + 1
        // 未定义转移归一：Error(0) 且模型不推进
        assert_true(response is Error(0))
        assert_eq(next, model)
      }
    }
  }
  // 组合数守恒（改表即变，写死防漏）：36 状态 × 34 命令 = 1224，合法 195 / 非法 1029
  assert_eq(legal + illegal, 36 * 34)
  assert_eq(legal, 195)
  assert_eq(illegal, 1029)
}

///|
/// ② 结构钉子门：BFS 派生的可达事实。
///   - 可达状态 34 个；两个"死态"两个类别：
///     · ExpectVerbRequired：**表级死态**（有出臂、全表无入臂；引擎侧唯一出现是
///       open_collection 的 ret_state 参数，不是转移目标）——与 nquads 的
///       PrefName/EOF 钉子同款。
///     · ListAfterElem：**模型侧不可达**——list 盲区吸收袋：list 入臂不设 O 槽 ⇒
///       模型 emit_predobj 永不就绪（Error(1) 吸收），引擎侧经 slot_stack 真实
///       推进（list_first → EmitQuad(PredObj)）——响应级漂移领土，P4.2d。
///   - graph 槽恒空：trig 的模型映射没有 set_graph（图上下文走 GraphKw 块状态机，
///     引擎发射的 graph=Some 模型看不见——P4.2d 已知边界，非缺陷，钉成事实）。
///   - 可达命令名恰 25 个（与 runner.coverage_gate_config 的要求表同口径）；
///     不可达 9 个（valid 无臂 ⇒ 生成器永不产出）。
test "指标·结构钉子: 可达 34 / 双死态 / graph 可达（P4.2d 升级）/ 命令名 25+9" {
  let (seen, state_models, names) = explore()
  // 状态可达性：36 - 2（双死态）
  let mut reachable_states = 0
  for state in all_states() {
    match state_model_of(state_models, state) {
      Some(model) => {
        reachable_states = reachable_states + 1
        assert_true(seen.contains(slot_key(model)))
      }
      None =>
        // 唯二无模型状态 = 唯二死态（第三个状态到达不了即结构被破坏）
        assert_true(state == ExpectVerbRequired || state == ListAfterElem)
    }
  }
  assert_eq(reachable_states, 34)
  // P4.2d 第二步（2026-09-15）：`[actions].writes` 落地后，模型有了 `enter_graph` → `graph`
  // 的写入臂 ⇒ 旧钉子"graph 恒空"**升级为正向断言**：可达状态里必须出现 graph 非空
  // （含图名图块）。钉子不许删，只许升级——盲区从"存在"转为"消失且被钉住"。
  let mut graph_seen = false
  for state in all_states() {
    match state_model_of(state_models, state) {
      Some(model) => if model.graph is Some(_) { graph_seen = true }
      None => ()
    }
  }
  assert_true(graph_seen)
  // 双死态显式钉子
  assert_false(state_model_of(state_models, ExpectVerbRequired) is Some(_))
  assert_false(state_model_of(state_models, ListAfterElem) is Some(_))
  // 可达命令名 = 覆盖门要求集（25）；不可达 = 9（与 runner 注释口径互证）
  let required = [
    "Iri", "BlankNode", "Literal", "PrefName", "TripleTerm", "BracketTripleTerm",
    "KeywordA", "At", "PrefixKw", "BaseKw", "GraphKw", "VersionKw", "Tilde", "AnnotStart",
    "AnnotEnd", "Comma", "Semicolon", "Dot", "Lbrace", "Rbrace", "Lbracket", "Rbracket",
    "Lparen", "Rparen", "Anon",
  ]
  assert_eq(names.length(), required.length())
  for name in required {
    assert_true(names.contains(name))
  }
  for command in all_commands() {
    let name = name_of(command)
    // 名集与钉子表逐名一致
    assert_eq(names.contains(name), required.contains(name))
  }
  let armless = [
    "Bang", "Caret", "Implies", "ImpliedBy", "ForAllKw", "ForSomeKw", "KeywordsKw",
    "Unknown", "EOF",
  ]
  for name in armless {
    assert_false(names.contains(name)) // 无臂命令：valid 恒假 ⇒ BFS 与生成器都不产出
  }
}

///|
/// ③ 无死锁门：每个**可达**状态在多种子下 generate_command 恒有合法候选且产出恒合法。
/// 与 nquads 同款：generator 门的随机游走遇 None 会静默 break，Deadlock 可达性
/// 必须按状态钉死。双死态反向钉 None——注意"死态"是不可达态（无入臂），不是
/// Deadlock（可达且无出边），两者不可混；ExpectVerbRequired 是表级死态（引擎也
/// 到不了），ListAfterElem 是模型侧不可达（引擎经 slot_stack 推进，P4.2d 领土）。
test "指标·generator: 可达状态恒有候选（多种子）+ 双死态 None 钉子" {
  let (_, state_models, _) = explore()
  for index, state in all_states() {
    match state_model_of(state_models, state) {
      Some(model) =>
        for seed in [1UL, 7UL, 42UL, 99UL, 2026UL] {
          let rng = @splitmix.new(seed~)
          match generate_command(model, 20, rng) {
            Some(command) => assert_true(valid(model, command)) // 候选恒合法（valid 过滤生效）
            None =>
              fail(
                "状态#\{index} 无合法候选——Deadlock 可达，转移表被破坏",
              )
          }
        }
      None =>
        // 唯二死态：期望 None 的必须是这两个
        assert_true(state == ExpectVerbRequired || state == ListAfterElem)
    }
  }
  // 死态钉子（反证"死态 ≠ Deadlock"）：两个死态都有出臂 ⇒ generate_command
  // 照样给候选；它们进不了运行期纯靠"无入臂"（结构钉子门的 BFS 已证）。
  assert_true(
    generate_command(
      blank_model(ExpectVerbRequired),
      20,
      @splitmix.new(seed=1UL),
    )
    is Some(_),
  )
  assert_true(
    generate_command(blank_model(ListAfterElem), 20, @splitmix.new(seed=1UL))
    is Some(_),
  )
}

///|
/// ④ 强制形态矩阵：部分状态的槽位形态由**构造路径唯一决定**（所有入臂都是同一
/// set_* 或从同一形态来），这些状态的形态可以钉死——形态被手改破坏即红。
/// 多形态状态（ExpectSubject 族：图块 Rbrace/Dot 不清槽的保守臂让残留槽位合法）
/// 与死态不进矩阵，显式豁免而非悄悄跳过（P4.2d 清账后扩全表）。
test "指标·强制形态: 22 态单形态（BFS 派生 ⟺ 声明表）+ 负例矩阵" {
  let (seen, state_models, _) = explore()
  // 声明表：强制形态状态 → 唯一合法槽位形态 (s, p, o)
  let forced : Array[(ModelState, Bool, Bool, Bool)] = [
    // 指令族：全空
    (ExpectDirectiveKind, false, false, false),
    (ExpectPrefixName, false, false, false),
    (ExpectPrefixIri, false, false, false),
    (ExpectBaseIri, false, false, false),
    (ExpectVersionLiteral, false, false, false),
    (ExpectDirectiveEnd, false, false, false),
    // 单主语族：subject 已填
    (ExpectPredicate, true, false, false),
    (ExpectVerbOrEnd, true, false, false),
    (GraphExpectVerbOrEnd, true, false, false),
    (AnnotExpectVerb, true, false, false),
    (AnnotExpectVerbTail, true, false, false),
    (GraphAnnotExpectVerb, true, false, false),
    (GraphAnnotExpectVerbTail, true, false, false),
    // 主谓族：subject + predicate 已填
    (ExpectObject, true, true, false),
    // 主谓宾族：三槽全满
    (ExpectDotOrGraph, true, true, true),
    (ExpectTildeEnd, true, true, true),
    (GraphExpectDotOrGraph, true, true, true),
    (GraphExpectTildeEnd, true, true, true),
    // 注解族（P4.2d 第二步校正，2026-09-15）：`annot_body_verb` 写 `predicate`
    // 已在 `[actions].writes` 落地 ⇒ 注解动词臂**落 P 槽**；体宾语经 `set_object` 落 O。
    // 旧形 (✓,∅,∅)/(✓,∅,✓) 是"P 未建模"时期的钉子。
    (AnnotExpectObject, true, true, false),
    (AnnotExpectEnd, true, true, true),
    (GraphAnnotExpectObject, true, true, false),
    (GraphAnnotExpectEnd, true, true, true),
  ]
  // 正向：BFS 派生的形态 = 恰声明的那一个（表抄错 / 入臂变化都在这里红）
  for entry in forced {
    let (state, s, p, o) = entry
    let model = state_model_of(state_models, state).unwrap()
    assert_eq(slot_key(model), (state, s, p, o))
  }
  // 反向（负例矩阵）：每个强制形态态翻转一个槽位 ⇒ 形态被破坏
  for entry in forced {
    let (state, s, p, o) = entry
    let base = state_model_of(state_models, state).unwrap()
    let broken = [
      { ..base, subject: if s { None } else { Some({ id: 9, }) }, },
      { ..base, predicate: if p { None } else { Some({ id: 9, }) }, },
      { ..base, object: if o { None } else { Some({ id: 9, }) }, },
    ]
    for model in broken {
      assert_false(slot_key(model) == (state, s, p, o)) // 形态确实被破坏
      assert_true(seen.contains(slot_key(base))) // 原形态在 BFS 可达集中
    }
  }
  // 多形态态显式豁免清单——钉的是"它们不进矩阵"这个决定本身，
  // 防将来误把多形态态当单形态钉死
  let multi_form = [
    ExpectSubject,
    GraphExpectSubject,
    ExpectGraphLabel,
    ExpectGraphLbrace,
    GraphExpectPredicate,
    GraphExpectObject,
    GraphExpectVerbOrDot,
    ExpectVerbOrDot,
    BnpExpectPredicate,
    BnpExpectObject,
    BnpAfterObject,
    ListExpectElemOrEnd,
  ]
  assert_false(multi_form.contains(ExpectVerbRequired)) // 死态不在豁免清单
  assert_false(multi_form.contains(ListAfterElem)) // 死态不在豁免清单
  // 状态守恒：22 强制 + 12 多形态 + 2 死态 = 36
  assert_eq(forced.length() + multi_form.length() + 2, all_states().length())
}

///|
/// ⑤ 权重口径门：声明的取配置值，未声明的取默认 1（0 表示禁用，当前无禁用命令）
test "指标·generator: 权重口径" {
  assert_eq(command_weight("Iri"), 3)
  assert_eq(command_weight("Literal"), 3)
  assert_eq(command_weight("Dot"), 3)
  assert_eq(command_weight("PrefName"), 2)
  assert_eq(command_weight("BlankNode"), 2)
  assert_eq(command_weight("Comma"), 1) // 未声明 → 默认 1（不是 0 = 禁用）
  assert_eq(command_weight("不存在"), 1)
}

///|
/// ⑥ shrink 安全性 + remap 恒等门（P4 单位面）：
///   - 收缩候选不得把合法命令变非法——否则前置条件悄悄否决全部候选，收缩静默失效。
///   - remap 恒等：含非空 scope 映射也不丢命令（丢命令 = shrink_and_validate 整体否决）。
test "指标·shrink 安全 + remap 恒等（全对）" {
  let empty : Map[@qcs.Var, @qcs.Var] = Map([])
  let mapped : Map[@qcs.Var, @qcs.Var] = Map([
    (@qcs.Var::{ id: 0, }, @qcs.Var::{ id: 1, }),
  ])
  for state in all_states() {
    let model = blank_model(state)
    for command in all_commands() {
      if valid(model, command) {
        for smaller in shrink_command(model, command) {
          assert_true(valid(model, smaller)) // 收缩候选恒合法
        }
      }
      assert_eq(remap_command(command, empty), Some(command))
      assert_eq(remap_command(command, mapped), Some(command))
    }
  }
}

///|
/// ⑦ label 钉子：resp:Done 不可达——trig_base.toml [[effects]] 声明了 Done
/// （semantics = "stop"），引擎机制也是活的（interpret 的 `TrigEffect::Done => Stop`
/// 与 handle_done 派发都在），但全表 29 条 effect 引用零处使用 Done ⇒ probe 的
/// Done 分支永不触发（2026-09-15 grep 实测）。与 nquads 同款"声明未引用"，
/// 对称地钉成"不适用"；表里将来加 Done 行时本门先红。
test "指标·label 钉子: resp:Done 不适用（表零引用）+ 引擎单步无 Done" {
  // 模型侧：全 (状态, 命令) 对的响应永非 Done
  for state in all_states() {
    for command in all_commands() {
      let (_, response) = model_execute(blank_model(state), command)
      assert_false(response is Done)
    }
  }
  // 引擎侧：每条命令从新 probe 单步驱动，响应永非 Done
  for command in all_commands() {
    let system = system_init()
    assert_false(run_command(command, system) is Done)
  }
  // resp:error 与 Done 的本质差别（写明防混淆）：生成器被 valid 过滤 ⇒ 随机生成
  // 走不到未定义转移，但引擎直接驱动**能**走到（Error(0) 归一化）——机制够得着，
  // 只是生成路径不走；Done 则是机制和路径都够不着。
  let system = system_init()
  assert_true(run_command(Dot, system) is Error(0))
}
