 FSM Code Generator 设计文档

  ## 一、架构总览


  ┌─────────────┐     ┌──────────┐     ┌───────────┐     ┌───────────┐     ┌──────────┐
  │  TOML 描述   │────│  Loader  │────│ Validator │────│ Optimizer│────│Generator │
  │  (用户编写)   │     │(解析+索引)│     │ (校验)     │     │(图优化)   │     │ (产出代码) │
  └─────────────┘     └──────────┘     └───────────┘     └───────────┘     └──────────┘
  │
  ┌──────┴──────┐
  │  Cache 层    │
  │ (增量判定)    │
  └─────────────┘


  **设计原则：**

  - **数据驱动**：TOML 是唯一输入，所有行为由数据决定。
  - **管道清晰**：Load → Validate → Optimize → Generate，每步可独立测试。
  - **零魔法**：没有隐式约定，所有规则显式写在 Validator 中。
  - **渐进增强**：前期 TOML 够用，后期可替换为自举 DSL，中间结构不变。
  - **可观测**：debug 开关 + --dump-spec + --check，每一步都能检查。

  ---

  ## 二、宪法（Constitution）

  本宪法是 FSM 代码生成器的最高设计准则。所有模块、数据结构、算法和 CLI 行为必须遵守本宪法；如需偏离，必须在本文件末
  尾新增修正案并说明理由。

  ### 第一条：IR 结构定义

  整个系统的唯一事实来源是 FsmIR。

  - FsmIR 由 EventDef、StateDef、TransitionDef 组成，所有行为必须由 IR 数据驱动。
  - 禁止在代码生成器中硬编码任何状态名、事件名、转移规则。
  - 禁止通过环境变量、全局变量、隐式上下文传递 FSM 定义。
  - IR 必须支持版本字段，便于后续前向/后向兼容。

  ### 第二条：不变量验证器

  代码生成前必须通过全部不变量检查。

  - 验证器必须覆盖以下检查项：
    - from / goto 必须引用已定义状态
    - on 必须引用已定义事件
    - 有且仅有一个初始状态
    - nestable 状态必须声明 exit_event
    - exit_event 必须引用已定义事件
    - 同一 (from, on) 不允许重复定义
    - 初始状态不可作为 goto 目标
    - 不可达状态必须报告 Warning
  - 验证器必须收集全部违规项后一次性报告，禁止 fail-fast 只报第一个。
  - 验证器必须是纯函数，不得修改 IR。

  ### 第三条：数据持有规范

  状态机运行时数据必须与转移逻辑分离。

  - State 持有自身数据（如栈、缓冲区、上下文）。
  - Action 必须是纯函数，输入为当前数据 + 事件，输出为新数据。
  - 禁止全局可变状态。
  - 禁止在 Action 中执行 I/O、网络请求、文件系统操作。
  - 所有副作用必须通过返回值显式传递。

  ### 第四条：代码生成器

  生成器将 FsmIR 转换为目标语言源码。

  - 生成的代码必须包含头部注释，标明来源 IR 和生成时间。
  - 生成的 match 分支必须与 IR 中 transitions 的顺序一致。
  - 禁止生成压缩代码、混淆变量名、省略换行。
  - 生成的代码必须是可编译的，不得包含语法错误或未解析的占位符。
  - 生成器必须是纯函数，相同 IR + 相同配置必须产出相同代码。

  ### 第五条：测试规范

  生成器必须有完整的测试保障。

  - 每个模块必须有独立的单元测试。
  - 测试覆盖率目标：核心逻辑 ≥ 80%。
  - 快照测试覆盖场景：全量生成、增量生成（无变更）、增量生成（有变更）、debug 模式、校验失败。
  - 端到端测试：从 IR 输入 → 验证 → 生成 → 编译 → 运行，全链路自动化。

  ### 第六条：可观测性规范

  生成的状态机必须具备可观测能力。

  - debug 模式下，每次转移必须输出日志：`[FSM] {pos}: {from_state} --[{event}]--> {to_state}`。
  - 支持从 FsmIR 生成 DOT/Graphviz 格式。
  - 运行时度量通过回调函数上报，生成器不直接依赖具体监控系统。

  ### 第七条：可扩展性规范

  生成器必须支持扩展和多后端。

  - 插件/钩子机制：before_generate、after_generate、custom_action。
  - 多后端生成：MoonBit Backend、TypeScript Backend、Rust Backend。
  - 分层状态机（HSM）：IR 中 StateDef 预留 parent 字段。
  - 并发状态机：支持正交区域（Orthogonal Regions）。

  ### 第八条：工程化基础设施

  - **CLI 工具**：统一命令行入口。
  - **增量生成**：缓存文件存储 IR 哈希 + 配置哈希 + 状态级代码哈希。
  - **版本兼容性**：IR schema 必须包含 version 字段。
  - **文档生成**：从 IR 自动生成 Markdown 文档。

  ### 第九条：宪法修正

  - 任何对本宪法的修改必须在本文件末尾新增修正案。
  - 禁止静默修改已有条款。
  - 修正案必须经过至少一人审查后方可合并。

  ---

  ## 三、修正案

  ### 修正案 A-001：移除底层张量存储，确立 FsmIR 唯一核心地位

  - **日期**：2026-08-17
  - **修改内容**：
    - 明确废弃 FsmTensor、CooStorage、CsrStorage 等底层稀疏矩阵存储结构。
    - 确立 FsmIR 为系统中唯一的内存数据结构。
    - 优化算子（prune, minimize, fuse）的签名统一为 `fn(FsmIR) -> FsmIR`，彻底消除 IR → Tensor → IR 的格式转换开销。
  - **理由**：FSM 的状态规模通常在几十到几百之间，属于典型的"小规模图论问题"。引入 COO/CSR 等矩阵存储属于过度设计，
  不仅增加了数百行底层维护代码，还引入了不必要的内存拷贝开销。FsmIR 配合内置的 `Map[String, Int]` 索引，足以在毫秒级
  完成所有图遍历与优化操作。

  ### 修正案 A-002：算子接口正交化与管线化规范

  - **日期**：2026-08-17
  - **修改内容**：
    - 在第七条（可扩展性规范）中补充"算子接口规范"。
    - 规定所有图优化算子必须遵循 `FsmIR -> FsmIR` 的纯函数签名。
    - 支持通过管道操作符（如 `|>`）进行无缝组合：
      ```moonbit
      build() |> validate() |> prune() |> minimize() |> codegen()
      ```
  - **理由**：保持接口的高度一致性，避免引入类似 PrunedMatrix、MinimizedMatrix 等语义泄漏的中间类型。统一的输入输出
  使得优化管线可以像 Unix 管道一样灵活编排，极大提升了可测试性和可观测性。

  ### 修正案 A-003：验证器错误恢复与编辑距离建议

  - **日期**：2026-08-17
  - **修改内容**：
    - 在第二条细则（2.3 错误恢复建议）中，明确"编辑距离（Levenshtein Distance）"算法的实现要求。
    - 当触发 INV-1、INV-2、INV-3（引用不存在）时，验证器必须在 suggestion 字段中返回编辑距离 ≤ 2 的候选项。
  - **理由**：在 DSL 或配置文件编写中，拼写错误是最常见的异常。提供精准的修复建议（如："Did you mean 'Running'?"）能
  将开发者的 Debug 时间从分钟级缩短到秒级，显著提升 DX（开发者体验）。

  ---

  ## 四、核心数据结构

  ### FsmIR 结构

  FsmIR 是系统中唯一的内存数据结构，自带 O(1) 语义索引：

  ```moonbit
  pub struct FsmIR {
    version: Int
    events: Array[EventDef]
    states: Array[StateDef]
    transitions: Array[TransitionDef]
  }

  pub struct EventDef {
    id: Int
    name: String
    metadata: Map[String, String]
  }

  pub struct StateDef {
    id: Int
    name: String
    is_initial: Bool
    is_nestable: Bool
    parent: Option[Int]
    exit_event: Option[Int]
    data_fields: Array[FieldDef]
    metadata: Map[String, String]
  }

  pub struct TransitionDef {
    id: Int
    from_state: Int
    to_state: Int
    on_event: Int
    guard_def: Option[Guard]
    action: Option[Action]
    metadata: Map[String, String]
  }

  pub struct Guard {
    name: String
    condition: String
  }

  pub struct Action {
    name: String
    params: Array[String]
  }

  关键决策：

  - exit_event 只在 nestable = true 时出现，由 Validator 强制约束。
  - action 和 semantic 都是可选字段，缺省 = 普通 goto / 无副作用。
  - guard 是可选的转移守卫条件，用于更复杂的转移逻辑。
  - 所有 ID 在 IR 内部使用 Int，但 TOML 描述中使用 String（由 Loader 完成映射）。
  - 禁止使用 FsmTensor、CooStorage、CsrStorage 等底层稀疏矩阵存储结构。

  ### Diag 诊断结构

  pub struct Diag {
    rule: String              // 规则编号，如 "INV-1"
    severity: Severity        // Error | Warning
    message: String           // 人类可读描述
    location: Option[SourceLocation]  // 文件名 + 行号 + 列号
    suggestion: Option[String]        // 修复建议（可选）
  }

  ———

  ## 五、模块设计

  ### 模块职责总览

   模块         职责                                    输入 → 输出
  ━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   loader       TOML → FsmIR（含 ID 映射与索引构建）    String → FsmIR
  ───────────  ──────────────────────────────────────  ───────────────────────────────────────────
   validator    静态不变量检查 (V1-V6, INV-1~INV-8)     FsmIR → Array[Diag]
  ───────────  ──────────────────────────────────────  ───────────────────────────────────────────
   optimizer    纯图论优化管线                          FsmIR → FsmIR (prune |> minimize |> fuse)
  ───────────  ──────────────────────────────────────  ───────────────────────────────────────────
   codegen      FsmIR → 源码字符串                      FsmIR + Config → String
  ───────────  ──────────────────────────────────────  ───────────────────────────────────────────
   cache        增量判定                                (FsmIR, Config) → bool
  ───────────  ──────────────────────────────────────  ───────────────────────────────────────────
   cli          命令行入口，串联上述模块                解析参数，协调管线执行

  ### Loader 模块

  职责：将 TOML 描述文件解析为 FsmIR，同时构建 state_index 和 event_index。

  - 解析 TOML 中的 meta、events、states、transitions 四个 section。
  - 将字符串 ID 映射为整数 ID（0-based）。
  - 自动构建 state_index: Map[String, Int] 和 event_index: Map[String, Int]。
  - 构建完成后直接返回 FsmIR，无需中间结构。

  ### Validator 模块

  职责：对 FsmIR 执行 V1-V6（INV-1~INV-8）不变量检查，收集全部错误后一次性报告。

  - 纯函数，不修改 IR。
  - Fail-Safe 模式：收集所有错误，而非遇到第一个就停止。
  - 提供编辑距离建议：当引用不存在时，推荐最相似的状态/事件名（编辑距离 ≤ 2）。

  ### Optimizer 模块

  职责：对 FsmIR 执行图论优化操作，所有算子签名统一为 fn(FsmIR) -> FsmIR。

   算子        职责                    算法                                      时间复杂度
  ━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━
   prune       移除不可达状态          BFS 从初始状态出发标记可达状态            O(V+E)
  ──────────  ──────────────────────  ────────────────────────────────────────  ────────────────
   minimize    合并等价状态            Hopcroft 简化版等价类划分                 O(V log V * E)
  ──────────  ──────────────────────  ────────────────────────────────────────  ────────────────
   fuse        合并无副作用的转移链    识别单入边单出边且无 action 的中间状态    O(E)

  ### Codegen 模块

  职责：将 FsmIR 转换为目标语言（MoonBit）源码字符串。

  codegen(FsmIR, Config)
  ├── emit_header()           // 头部注释（来源 IR、生成时间）
  ├── emit_token_enum(events) // Event 枚举
  ├── emit_state_enum(states) // State 枚举
  ├── emit_step_fn(transitions, config)
  │     └── 按 from 分组 → 每个状态一个 match 分支
  ├── emit_action_dispatch(semantic_actions)
  └── emit_debug_helpers()?   // 仅 debug=true 时

  代码风格规范：

  - 缩进：2 空格
  - 每行不超过 100 字符
  - 变量命名：snake_case
  - 类型命名：PascalCase
  - 函数命名：snake_case

  ### Cache 模块

  职责：通过哈希对比实现增量生成判定。

  缓存文件 (.fsm_cache.json) 结构：

  {
    "input_hash": "sha256...",
    "config_hash": "sha256...",
    "generated_at": 1234567890
  }

  判定流程：

  1. input_hash 变了？ → 必须重新生成
  2. config_hash 变了？ → 必须重新生成（debug 开关切换等）
  3. 都没变？ → 跳过，输出 "up to date"

  ### CLI 模块

  统一命令行入口，支持以下命令：

  fsm-gen <input.toml> [options]

  Options:
    -o, --output <path>    输出文件路径
    -d, --debug            生成带追踪日志的代码
    -p, --prefix <prefix>  命名前缀（防冲突）
    --full                 全量生成（默认）
    --incremental          增量模式（对比缓存）
    --cache <path>         缓存文件路径（默认: .fsm_cache.json）
    --check                仅校验，不生成代码
    --dump-spec            打印解析后的 FsmIR（调试用）
    --visualize <path>     生成 Graphviz DOT 可视化文件

  典型使用管线：

  let final_code = build(toml_content)
    |> validate_and_halt()   // 验证失败直接报告错误并退出
    |> prune()               // O(V+E) 剔除死代码
    |> minimize()            // 等价类合并
    |> fuse()                // 转移链融合
    |> codegen(_, config)    // 生成纯净的 MoonBit 代码

  ———

  ## 六、TOML 描述格式（Schema）

  一个 TOML 文件描述一个完整的 FSM，分为三个顶层 section：

  [meta]
  name = "turtle_parser"
  version = "0.1.0"
  prefix = "Turtle"            # 可选：生成代码命名空间前缀；缺省从 name 派生（剔除特殊字符转 PascalCase）
  trait_name = "TurtleActions" # 可选：Actions trait 名；缺省 "{prefix}Actions"
  default_effect = "Continue"  # 可选：无 action 转移的默认 Effect 变体；缺省 "Continue"

  [[events]]
  id = "IRIREF"

  [[states]]
  id = "Start"
  kind = "initial"        # initial | final | ""（省略即可）
  nestable = false

  [[transitions]]
  from = "Start"
  on = "IRIREF"
  goto = "ExpectPredicate"
  guard = "depth < MAX_DEPTH"  # 可选：转移守卫条件
  action = "push"              # push | pop | pop_or_goto | ""（省略即可）
  semantic = "set_subject"     # 语义动作名，可选

  设计要点：

  - 字段名全部小写 + 下划线，与 TOML 惯例一致。
  - 可选字段直接省略（不用空字符串占位），Loader 侧给默认值。
  - action 和 semantic 分离——前者是 FSM 机制（push/pop），后者是业务语义（emit_triple）。
  - guard 字段支持更复杂的转移守卫条件。

  ———

  ## 七、Validator 不变量规则清单

   编号     规则                                严重度     说明
  ━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━
   INV-1    from 必须引用已定义状态             Error      转移来源不存在
  ───────  ──────────────────────────────────  ─────────  ────────────────────────
   INV-2    on 必须引用已定义事件               Error      触发事件不存在
  ───────  ──────────────────────────────────  ─────────  ────────────────────────
   INV-3    goto 必须引用已定义状态             Error      转移目标不存在
  ───────  ──────────────────────────────────  ─────────  ────────────────────────
   INV-4    有且仅有一个初始状态                Error      初始状态数量不合法
  ───────  ──────────────────────────────────  ─────────  ────────────────────────
   INV-5    nestable 状态必须声明 exit_event    Error      可嵌套状态缺少退出事件
  ───────  ──────────────────────────────────  ─────────  ────────────────────────
   INV-6    exit_event 必须引用已定义事件       Error      退出事件不存在
  ───────  ──────────────────────────────────  ─────────  ────────────────────────
   INV-7    同一 (from, on) 不允许重复          Warning    转移规则冲突
  ───────  ──────────────────────────────────  ─────────  ────────────────────────
   INV-8    不可达状态报告 Warning              Warning    存在孤立状态

  错误恢复建议：

  - from 引用不存在 → 建议最相似的状态名（编辑距离 ≤ 2）
  - on 引用不存在 → 建议最相似的事件名
  - 缺少初始状态 → 建议将第一个状态标记为初始
  - 重复 (from, on) → 建议合并或删除其中一个

  ———

  ## 八、文件结构

  fsm-gen/
  ├── moon.pkg.json
  ├── main.mbt              # CLI 入口
  ├── loader.mbt            # TOML → FsmIR
  ├── validator.mbt         # FsmIR → Diagnostics
  ├── optimizer.mbt         # prune / minimize / fuse 算子
  ├── codegen.mbt           # FsmIR → String
  ├── cache.mbt             # 哈希 + 缓存读写
  ├── types.mbt             # FsmIR / Diag / Config 定义
  └── test/
      ├── fixtures/
      │   ├── valid/          # 合法 TOML 文件
      │   └── invalid/        # 非法 TOML 文件（预期报错）
      ├── expected/
      │   ├── valid/          # 合法 TOML 的预期生成代码
      │   └── invalid/        # 非法 TOML 的预期诊断信息
      └── snapshots/          # 快照文件

  ———

  ## 九、演进路线

  ### Phase 1：正确性闭环（高优先级）

  - 实现 FsmIR 结构体和 validate 模块（包含编辑距离建议）。
  - 实现 prune 和 minimize 纯图论算子。
  - 实现完整的测试规范（单元测试 + 快照测试 + 端到端测试）。
  - 实现生成代码编译验证。

  ### Phase 2：可观测性（中优先级）

  - 实现 debug 日志与追踪。
  - 实现状态机可视化（DOT 输出）。
  - 实现 CLI 工具。

  ### Phase 3：可扩展性（中优先级）

  - 实现插件与多后端。
  - 实现分层状态机（HSM）。
  - 实现并发状态机。

  ### Phase 4：工程化（低优先级）

  - 实现增量生成。
  - 实现文档生成。
  - 实现运行时度量。

  ———

  ## 十、设计原则总结

   原则            体现
  ━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   数据驱动        TOML 是唯一输入，所有行为由数据决定
  ──────────────  ───────────────────────────────────────────────────────
   管道清晰        Load → Validate → Optimize → Generate，每步可独立测试
  ──────────────  ───────────────────────────────────────────────────────
   零魔法          没有隐式约定，所有规则显式写在 Validator 中
  ──────────────  ───────────────────────────────────────────────────────
   渐进增强        前期 TOML 够用，后期可替换为自举 DSL，中间结构不变
  ──────────────  ───────────────────────────────────────────────────────
   可观测          debug 开关 + --dump-spec + --check，每一步都能检查
  ──────────────  ───────────────────────────────────────────────────────
   单一事实来源    FsmIR 是唯一内存数据结构，无中间类型
  ──────────────  ───────────────────────────────────────────────────────
   正交接口        所有优化算子统一 FsmIR → FsmIR，支持管道组合
  ──────────────  ───────────────────────────────────────────────────────
   零开销抽象      无不必要的格式转换和内存拷贝

  ———

  本文档遵循 FSM Code Generator Constitution v1.0
  最后更新：2026-08-17

