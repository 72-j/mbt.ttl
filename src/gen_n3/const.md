# gen_n3 宪法（Biz / 命名 / Const）

版本：v1.1.0
维护层：Gen / Biz
强制等级：MUST / MUST NOT / NEVER / ALWAYS

---

## 总纲（Preamble）

本包采用 BangOnto 三层边界：生成骨架只产出类型、枚举、模板和桩；  
业务逻辑、N3 名词义解释和副作用执行全部落在用户补面。  
违反本文件即视为生成契约破裂，必须在编译期或 CI 期拦截，禁止运行时漂移。

---

## 词汇表（Lexicon）

| 术语 | 定义 |
|---|---|
| Slot | 栈帧；公式、集合、属性列表三类。 |
| Context | 当前解析视窗位置；state + 四元组槽位 + slot_stack。 |
| Effect | 单步意图；loop 不直接执行副作用。 |
| BlankNode | blank node；BNode 只作别名。 |
| Literal | 字面量；禁用缩写 Lit。 |
| Collection | 有序集合资源；不得展开为成员三元组。 |
| GraphTerm | 不透明度图术语；外部不断言断言为真。 |
| Rule | 规则语句；`=>` / `<=` 只作为标识保留。 |
| Variable | 规则或公式里的变量身份；不在此阶段做绑定。 |
| Path | 资源路径；`!` 正向、`^` 反向。 |
| Builtin | 内置命名空间标识；推迟语义解释。 |
| Langtag | 语言标签；规范拼写为 langtag，API 可用 Langtag。 |

命名铁律：
- 规范术语保留规范拼写：`BlankNode`、`Literal`、`langtag`。
- 自创概念须看名知责：`slot_stack`、`terminal_span`、`pipeline_kind`。
- 单字母/田字缩写只许出现在循环指标。

---

## 条款细则（Articles）

### A0 三条线宪法

- **决策在表**：`step` 只产出 `Effect`；放映意图仅由转移行携带。`Sequence` 仅做意图打包。
- **机械在模板**：主循环 = 生成器固定模板；切片组装与 `ctx.reset(scope)` 都在 loop 发生，引擎不碰槽位。
- **业务在 trait**：业务动作与流转策略同属 Biz 一层，钩子收敛为两个 trait：
  `N3Actions`（业务动作）与 `N3LoopPolicy`（`begin_record` / `recover` / `finish_at_end` / `on_business_failed`）。
  `N3EffectHandler` 为 Gen 侧分发表（`handle_*` 默认体 + `dispatch`），Biz 按需覆盖默认体。

### A1 口径铁律

- action 统一 `Span` 口径；无 payload 事件绑 `(0,0)`；错误兜底位置由 loop 用词法位置回填。
- EOF 是数据边界，不进表；由 `finish_at_end` 判脏收尾；`Done` 仅用于 parser-all 边界。
- 未列举组合 → `UnexpectedEvent` / `BusinessFailed` 兜底；loop 偶遇后进入 `recover`。
- Effect 面向只加变体，实行分类管理：核心流转变体（`Continue`、`Reset`、`Done`、`Sequence`）增删需 ADR；
  业务/输出/结构变体（`EmitQuad`、`PopBnp`、`OpenSlot`）属 Biz 扩展面，经 `N3EffectHandler` 默认体与 `N3Actions` 承接；
  新增同类效果优先扩 Biz trait、不改 Gen 层枚举（确需扩枚举仍需 ADR）。
- 图块区域与顶层彻底分离；`GraphExpect*` 无 `Lbrace` 出边；表即合法性裁决者。
- 全文件由 TOML 可表达；枚举、上下文、action 面、step 表四段无表外逻辑。

### A2 命名分区

- 类型：`N3State`、`N3Event`、`N3Effect`、`N3Context`、`N3Slot`、`N3ResetScope`。
- trait：`N3Actions`、`N3LoopPolicy`、`N3EffectHandler`。
- 错误：`N3ParseError`、`N3ActionError`、`N3EffectError`。
- 词法适配：`N3LexerAdapter`；源 trait 保持 `N3LexerSource`。
- 物化/输出：`QuadSpan` 复用 `nquads.compat` 形状；`GraphTerm`、`Formula`、`Collection`、`Variable` 仅存 IR，不在生成期抢位。

### A3 动词口令

- 连动修改 parser 状态时，只写动词：`set_*`、`enter_*`、`exit_*`、`skip_*`、`resolve_*`。
- 名词口令只发意图：`emit_*`、`done`。
- 禁止在 step 模板里内联“语义着色”：`a`、`=`、`is ... of` 变色只许在 Node/Adapter 或 Action 层做标记，不得改成新 Event。

### A4 三种角色密码

- 生成骨架只发枚举/桩，不做 N3 名词义解释。
- 物化层只负责槽位展开与校验，不退出 FSM 状态机。
- 序列化层只负责本地文本化，不进行词法/语法验证。

### A5 可观测与可验证铁律

- 解析失败必须携带位置、原因、预期结构。
- IR 保留原始字符串、语法类别、词法位置、前缀/base 作用域。
- 未显式 skip 的非法事件不得静默吞掉；必须进入 recover。
- 相同输入 + 相同配置 => 相同 IR。

### A6 副作用分层铁律

| 层级 | 允许行为 | 禁止行为 |
|---|---|---|
| Gen | 产出骨架、枚举、模板 | 写业务语义、解释 N3 名词义 |
| Action | 声明意图、读上下文 | I/O、网络、缓存、日志 |
| Effect | I/O、持久化、日志、AI | 直接改状态机内存 |
| Biz | Guard、Err 映射、Observability | 跑完整业务逻辑 |

### A7 命名保留协议

| 板面 | 命名要求 |
|---|---|
| 原始生料 | 结构形命名：`type`/`spec`/`doc`/`dict`/`kernel`/`vocabulary`/`center`。 |
| 生成 Prism 文件 | 允许加 `boot`/`generic`/`cache`/`full`/`workflow`/`module`。 |
| Pocket/Target | 允许加 `constructor`/`unique_image`/`sequence`/`path`/`internal`/`parallel`/`context`/`primitive`/`serialization`/`document`/`handler`/`layout`/`readable`/`generator`。 |
| 词法 | 必须反映事件来源：`Source`、`Adapter`、`Raw`、`RD`、`vector`。 |

