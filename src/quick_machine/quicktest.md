
  # QuickCheck Statemachine 集成方案

  ## 一、目标

  将 quickcheck_statemachine 集成到 FSM 代码生成器中，实现：

  - 从状态机定义自动生成模型驱动测试代码
  - 用纯模型与真实执行器做双执行比较
  - 用路径分析发现未覆盖转移
  - 用属性测试验证状态机正确性

  ---

  ## 二、整体架构


  ┌─────────────┐
  │ FSM (TOML)  │
  └──────┬──────┘
  │
  ▼
  ┌─────────────────────────────────────┐
  │          Code Generator              │
  │                                      │
  │  1. 引擎代码 (step, Context)        │
  │  2. 测试骨架 (Command/Response)     │
  │  3. 纯模型 (model_execute)         │
  │  4. 约束函数 (valid)                │
  │  5. 属性测试 (property)             │
  └─────────────────────────────────────┘
  │
  ▼
  ┌─────────────────────────────────────┐
  │         Path Analyzer                │
  │                                      │
  │  - 枚举合法路径                      │
  │  - 发现未覆盖转移                    │
  │  - 生成长序列/边界序列               │
  └─────────────────────────────────────┘
  │
  ▼
  ┌─────────────────────────────────────┐
  │      quickcheck_statemachine         │
  │                                      │
  │  - 生成命令序列                      │
  │  - 执行到真实系统                    │
  │  - 与纯模型比较                      │
  │  - 报告不一致                        │
  └─────────────────────────────────────┘


  ---

  ## 三、模块划分

  ### 3.1 类型映射层

  负责把 FSM 定义中的类型映射为 QuickCheck 可用的类型。

  | FSM 类型 | 测试类型 | 转换方式 |
  |---------|---------|---------|
  | Event | Command | Span → RefId，其他保留 |
  | Effect | Response | 直接映射，错误统一为 Response::Error |
  | Context | Model | 只保留语义相关字段 |

  #### 生成模板

  ```moonbit
  // ========================================
  // Generated: Command type
  // Source: Event enum in FSM definition
  // ========================================

  ///| Command - 测试命令类型
  pub enum Command {
    /// 每个 Event 变体对应一个 Command 变体
    /// Span 类型载荷替换为 RefId (Int)
    Iri(Int)
    BlankNode(Int)
    Literal(Int)
    Dot
    Comma
    Semicolon
    EOF
  } derive(Eq, Debug)

  // ========================================
  // Generated: Response type
  // Source: Effect enum in FSM definition
  // ========================================

  ///| Response - 测试响应类型
  pub enum Response {
    Continue
    EmitTriple(Triple)
    SkipLine
    Done
    Error(Int)
  } derive(Eq, Debug)

  // ========================================
  // Generated: Model type
  // Source: Context struct (semantic fields only)
  // ========================================

  ///| Model - 纯模型，只保留语义字段
  pub struct Model {
    state: State
    subject: Int?
    predicate: Int?
    object: Int?
    graph: Int?
  } derive(Eq, Debug)

  ———

  ### 3.2 约束生成器

  从转移表生成 valid 函数。

  #### 生成逻辑

  // ========================================
  // Generated: valid constraint
  // Source: transition table
  // ========================================

  ///| 检查命令是否在当前状态合法
  pub fn valid(model: Model, cmd: Command) -> Bool {
    match (model.state, cmd) {
      // 合法转移
      (ExpectSubject, Iri(_)) => true
      (ExpectSubject, BlankNode(_)) => true
      (ExpectPredicate, Iri(_)) => true
      (ExpectObject, Dot) => true
      (ExpectObject, EOF) => true

      // 兜底：未定义转移非法
      (_, _) => false
    }
  }

  ———

  ### 3.3 纯模型执行器

  生成 model_execute 函数。

  #### 生成模板

  // ========================================
  // Generated: model_execute
  // Source: transition semantics
  // ========================================

  ///| 纯模型执行（无副作用）
  pub fn model_execute(model: Model, cmd: Command) -> (Model, Response) {
    match (model.state, cmd) {
      // Subject 状态
      (ExpectSubject, Iri(id)) => (
        { ..model, state: ExpectPredicate, subject: Some(id) },
        Response::Continue
      )
      (ExpectSubject, BlankNode(id)) => (
        { ..model, state: ExpectPredicate, subject: Some(id) },
        Response::Continue
      )

      // Predicate 状态
      (ExpectPredicate, Iri(id)) => (
        { ..model, state: ExpectObject, predicate: Some(id) },
        Response::Continue
      )

      // Object 状态
      (ExpectObject, Dot) => {
        match (model.subject, model.predicate, model.object) {
          (Some(s), Some(p), Some(o)) => (
            { ..model, state: ExpectSubject, subject: None, predicate: None, object: None },
            Response::EmitTriple(Triple::{ s, p, o })
          )
          _ => (model, Response::Error(1))  // 不完整三元组
        }
      }
      (ExpectObject, EOF) => (model, Response::Done)

      // 非法转移
      (_, _) => (model, Response::Error(0))
    }
  }

  ———

  ### 3.4 真实执行器适配层

  #### 生成模板

  // ========================================
  // Generated: real_execute
  // Source: step function + Command/Event mapping
  // ========================================

  ///| Command → Event 转换
  fn command_to_event(cmd: Command, env: Env) -> Event {
    match cmd {
      Iri(ref_id) => Iri(env.resolve_span(ref_id))
      BlankNode(ref_id) => BlankNode(env.resolve_blank(ref_id))
      Literal(ref_id) => Literal(env.resolve_literal(ref_id))
      Dot => Dot
      Comma => Comma
      Semicolon => Semicolon
      EOF => EOF
    }
  }

  ///| Effect → Response 转换
  fn effect_to_response(effect: Effect) -> Response {
    match effect {
      Effect::Continue => Response::Continue
      Effect::EmitTriple(t) => Response::EmitTriple(t)
      Effect::SkipLine => Response::SkipLine
      Effect::Done => Response::Done
      Effect::Goto(_) => Response::Continue  // 内部处理
      Effect::Fatal(code) => Response::Error(code)
    }
  }

  ///| 真实执行
  pub fn real_execute(
    ctx: Context,
    cmd: Command,
    env: Env,
  ) -> (Context, Response) {
    let event = command_to_event(cmd, env)
    match step(ctx, event) {
      Ok((new_ctx, effect)) => (new_ctx, effect_to_response(effect))
      Err(code) => (ctx, Response::Error(code))
    }
  }

  ———

  ### 3.5 测试 Actions 实现

  // ========================================
  // Generated: TestActions
  // Purpose: collect side effects for assertion
  // ========================================

  ///| 测试用的 Actions 实现
  pub struct TestActions {
    mut emitted_triples: Array[Triple]
    mut errors: Array[Int]
  }

  pub fn TestActions::new() -> TestActions {
    { emitted_triples: [], errors: [] }
  }

  impl Actions for TestActions {
    fn emit_triple(self: Self, ctx: Context, triple: Triple) -> Result[(Context, Effect), Error] {
      self.emitted_triples.push(triple)
      Ok((ctx, Effect::Continue))
    }

    fn on_error(self: Self, ctx: Context, code: Int) -> Result[(Context, Effect), Error] {
      self.errors.push(code)
      Ok((ctx, Effect::SkipLine))
    }

    // 其他方法默认空实现
  }

  ———

  ### 3.6 属性测试生成

  // ========================================
  // Generated: property tests
  // ========================================

  ///| 属性测试 1：模型与真实执行器状态一致
  pub fn property_state_consistency() {
    for_all { cmds: List[Command] | valid_sequence(cmds) }

    let (model, _) = run_model(initial_model(), cmds)
    let (ctx, _) = run_real(initial_context(), cmds)

    assert!(model.state == ctx.state)
  }

  ///| 属性测试 2：状态始终合法
  pub fn property_valid_state() {
    for_all { cmds: List[Command] | valid_sequence(cmds) }

    let (model, _) = run_model(initial_model(), cmds)
    assert!(is_valid_state(model.state))
  }

  ///| 属性测试 3：Complete 时必要字段非空
  pub fn property_complete_fields() {
    for_all { cmds: List[Command] | valid_sequence(cmds) }

    let (model, _) = run_model(initial_model(), cmds)
    if model.state == Complete {
      assert!(model.subject.is_some())
      assert!(model.predicate.is_some())
      assert!(model.object.is_some())
    }
  }

  ———

  ## 四、路径分析器

  ### 4.1 目标

  从转移表中分析出所有可达路径，用于：

  - 生成覆盖性测试序列
  - 发现未覆盖转移
  - 识别死状态和不可达状态

  ### 4.2 算法

  // ========================================
  // Generated: path analysis report
  // ========================================

  ///| 路径分析报告
  pub struct PathReport {
    reachable_states: Set[State]
    unreachable_states: Set[State]
    dead_states: Set[State]
    cycles: List[List[State]]
    uncovered_transitions: Set[(State, Command)]
    generated_paths: List[List[Command]]
  }

  ///| 分析路径
  pub fn analyze_paths(
    transitions: TransitionTable,
    initial: State,
  ) -> PathReport {
    // 1. 构建有向图
    // 2. BFS 标记可达状态
    // 3. 识别死状态（无出边）
    // 4. 检测环
    // 5. 生成覆盖路径
    // 6. 输出未覆盖转移
  }

  ### 4.3 输出示例

  {
    "reachable_states": ["Start", "ExpectPredicate", "ExpectObject"],
    "unreachable_states": ["Dead"],
    "dead_states": [],
    "cycles": [["Start", "ExpectPredicate", "ExpectObject"]],
    "uncovered_transitions": [],
    "generated_paths": 15
  }

  ———

  ## 五、动态探索模块（可选）

  ### 5.1 目标

  在已有状态机实现上，通过动态执行发现转移表中未记录的转移。

  ### 5.2 算法

  ///| 动态探索
  pub fn discover_transitions(
    initial: State,
    executor: Executor,
  ) -> List[(State, Command, State, Response)] {
    let queue = [initial]
    let mut visited = Set::new()
    let mut discovered = []

    while not(queue.is_empty()) {
      let state = queue.pop().unwrap()
      if visited.contains(state) { continue }
      visited.add(state)

      for cmd in all_commands() {
        match executor.execute(state, cmd) {
          Ok((next, resp)) => {
            discovered.push((state, cmd, next, resp))
            if not(visited.contains(next)) {
              queue.push(next)
            }
          }
          _ => ()
        }
      }
    }

    discovered
  }

  ———

  ## 六、集成流程

  ┌─────────────────────────────────────┐
  │  1. 用户编写 FSM 定义 (TOML)       │
  └─────────────────┬───────────────────┘
                    │
                    ▼
  ┌─────────────────────────────────────┐
  │  2. 代码生成器解析 TOML             │
  └─────────────────┬───────────────────┘
                    │
                    ▼
  ┌─────────────────────────────────────┐
  │  3. 生成引擎代码                   │
  │                                      │
  │  • state.mbt      (State 枚举)       │
  │  • event.mbt      (Event 枚举)       │
  │  • effect.mbt     (Effect 枚举)      │
  │  • context.mbt    (Context 结构体)   │
  │  • engine.mbt     (step 函数)        │
  └─────────────────┬───────────────────┘
                    │
                    ▼
  ┌─────────────────────────────────────┐
  │  4. 生成测试代码                   │
  │                                      │
  │  • command.mbt     (Command 枚举)    │
  │  • response.mbt    (Response 枚举)   │
  │  • model.mbt       (Model 结构体)    │
  │  • valid.mbt       (valid 函数)      │
  │  • model_exec.mbt  (model_execute)   │
  │  • real_exec.mbt   (real_execute)    │
  │  • test_actions.mbt(TestActions)     │
  │  • properties.mbt  (属性测试)        │
  └─────────────────┬───────────────────┘
                    │
                    ▼
  ┌─────────────────────────────────────┐
  │  5. 生成路径分析报告               │
  │                                      │
  │  • path_report.json                  │
  │  • uncovered_transitions.json        │
  └─────────────────────────────────────┘

  ———

  ## 七、CI 集成

  # GitHub Actions 示例
  name: FSM Tests

  on: [push, pull_request]

  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - name: Generate engine + tests
          run: moon run codegen

        - name: Run property tests
          run: moon test --package fsm_test

        - name: Check path coverage
          run: |
            moon run path_analyzer
            # 如果未覆盖转移 > 0，CI 失败
            jq '.uncovered_transitions | length' path_report.json \
              | xargs test 0 -eq

  ———

  ## 八、依赖

  {
    "dependencies": {
      "moonbit-community/quickcheck_statemachine": "0.0.1",
      "moonbitlang/quickcheck": "0.14.0"
    }
  }

  ———

  ## 九、迁移检查清单

  将现有状态机迁移到本框架时，逐项确认：

  - [ ] Event 枚举中所有 Span 载荷已标记为可替换
  - [ ] Effect 枚举中所有变体都有 Eq 和 Debug derive
  - [ ] Context 中语义字段和非语义字段已区分
  - [ ] 转移表完整覆盖所有 (State, Event) 组合
  - [ ] Goto 转移在纯模型中有对应处理
  - [ ] 错误路径在转移表中有明确定义
  - [ ] Actions trait 的所有方法都有测试实现
  - [ ] 至少声明 3 个不变量属性

  ———

  ## 十、风险与缓解

   风险                          影响                  缓解措施
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Span 无法在测试中构造         编译失败              用 RefId 替代，command_to_event 中解析
  ────────────────────────────  ────────────────────  ────────────────────────────────────────
   纯模型与真实执行器语义漂移    假阳性                两者同源生成，修改转移表时同步更新
  ────────────────────────────  ────────────────────  ────────────────────────────────────────
   转移表不完整                  valid 遗漏合法命令    用路径分析器检测未覆盖转移
  ────────────────────────────  ────────────────────  ────────────────────────────────────────
   长序列测试超时                CI 变慢               设置 max_steps 参数，默认 100
  ────────────────────────────  ────────────────────  ────────────────────────────────────────
   Goto 导致状态跳转不可预测     模型不一致            在 model_execute 中显式处理 Goto 分支

  ———

  ## 十一、生成文件清单

   文件                 说明
  ━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   state.mbt            State 枚举
  ───────────────────  ────────────────────────────
   event.mbt            Event 枚举
  ───────────────────  ────────────────────────────
   effect.mbt           Effect 枚举
  ───────────────────  ────────────────────────────
   context.mbt          Context 结构体
  ───────────────────  ────────────────────────────
   engine.mbt           step 函数
  ───────────────────  ────────────────────────────
   command.mbt          Command 枚举（测试）
  ───────────────────  ────────────────────────────
   response.mbt         Response 枚举（测试）
  ───────────────────  ────────────────────────────
   model.mbt            Model 结构体（测试）
  ───────────────────  ────────────────────────────
   valid.mbt            valid 函数（测试）
  ───────────────────  ────────────────────────────
   model_exec.mbt       model_execute 函数（测试）
  ───────────────────  ────────────────────────────
   real_exec.mbt        real_execute 函数（测试）
  ───────────────────  ────────────────────────────
   test_actions.mbt     TestActions 实现（测试）
  ───────────────────  ────────────────────────────
   properties.mbt       属性测试（测试）
  ───────────────────  ────────────────────────────
   path_analyzer.mbt    路径分析器
  ───────────────────  ────────────────────────────
   path_report.json     覆盖率报告

  ———

  文档版本：v0.1.0
  最后更新：2026-08-18

