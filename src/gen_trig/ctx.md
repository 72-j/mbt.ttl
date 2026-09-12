# gen_trig 整改上下文（ctx）

版本：v1.0.0（2026-09-12 立卷）

**这份文件是什么**：按 `bangto/world/ctx-template.meta.md` 八节模板写的**整改工作上下文**
（锚点 / 证据 / 动作 / 验收 / 风险 / 待裁），结论落 `todo.md`，红线落（待拆的）`const.md`。

**本卷性质**（`bangto/world/const.md` §5.2）：`ctx` / `todo` 是**项目交互与意见的产物**——
有时效、只对本文件夹有效、可修改、**不记录 ADR**（决策归 adr 卷，见 R-T7）。

**怎么用**：接到某个 R-T 项 → 读 §4 对应小节 → 按锚点定位 → 按动作改 → 按验收跑 → 回 `todo.md` 更新。

---

## 1. 坐标与基线

### 1.1 生成链（与 gen_n3v2 的**关键差异**）

| 方言 | 生成链 | 产物门 |
|---|---|---|
| n3v2 | `src/rdf/n3gen`（自含：parse → validate → emit 直产） | **G9 黄金门**：ts 钉 `1788955337965` + 逐字节对拍 + 强幂等 |
| **trig** | `src/rdf/domain_to_ir.mbt` → `src/rdf/fsm_out/trig_fsm.toml` → `src/fsm/cmd`（v1 IR + codegen） | **仅 IR 侧门**：`src/rdf/trig_domain_toml_gen.mbt:222`「双文件编译 ≡ `fsm_out/trig_fsm.toml` 字节级」；**产物 `trig.mbt` 无门**——一致性靠 `domain_to_ir.mbt:15/52/257/407/2717` 注释里的"与 `gen_trig/trig.mbt` 定稿逐行对齐 / 对账即 diff 这两处"人工纪律 |
| md | `src/gen_md/gen`（自有编译器） | — |

> 产物 `trig.mbt:4` 头部 `Generated at: 1788654011855` 是**墙钟值**：即使重跑，该行也会变 ⇒ 无 ts 钉就**不可复现**（R-T2 要解决的第一件事）。

### 1.2 基线（2026-09-12 实测）

| 项 | 值 | 证据 / 命令 |
|---|---|---|
| 警告 | **0** | `cd src/ttl && moon check src/gen_trig` |
| 测试 | **80/80** | `moon test src/gen_trig`（含 rdf12-trig 36/36、rdf12-turtle 75/75 等） |
| 套件钉 | 4 套 `pin=true` | `rdf_suite_wbtest.mbt:47/108/115/123/131` |
| 公共面 | **`.mbti` 349 行 / 37 个 `pub`** | `pkg.generated.mbti`（对比 n3v2 收窄后 **166 / 24**） |
| 表规模 | **36 态 / 34 事件 / 10 效果 / 195 转移** | `grep -c '^\[\[*\]\]' src/rdf/fsm_out/trig_fsm.toml` |
| 用户层体量 | actions 417 / engine 531 / lexer_adapter 333 / parser_slice 603 / materialize 1645 / serialize 375 / types 160 = **4064 行** | `wc -l` |
| 生产文件内联 test | **21**（materialize 16 + serialize 5） | `grep -c '^test ' materialize_trig.mbt serialize_trig.mbt` |
| 包内死件 | **5 个 `.bak`**（`trig.mbt.bak` 36 KB、`engine.mbt.bak` 15 KB、`lexer_mbt*.bak` ×2、`nquads_test.mbt.bak`） | `ls *.bak` |

---

## 2. 契约面注解（三业务面 + 切点）

| 面 | trait | 生成锚点 | 实现锚点 | 现状 |
|---|---|---|---|---|
| ① 语义落点 | `TrigActions` | `trig.mbt`（生成面） | `actions.mbt:9`（`Hooks`） | 已接活 |
| ② 效果执行面 | `TrigEffectHandler` | `trig.mbt:1165`（trait）+ `:1172–1226`（默认 impl） | **无**（`engine.mbt` 只在自己注释里提 `interpret`：`engine.mbt:20`） | **孤儿挂点（C-T1）** |
| ③ 控制流面 | `TrigLoopPolicy` | `trig.mbt`（生成面） | `engine.mbt:227/240/314/344` + `extend`（`:353`） | 已接活；**命名待回灌**（C-T4） |

**切点表**（要挂什么 → 挂哪 → 能不能挂）：

| 切面需求 | 挂点 | 现状 |
|---|---|---|
| 每 quad 观测（emit 埋点） | `TrigEffectHandler.handle_emit_quad` | **不可以**（loop 绕过 handler） |
| 效果降级（丢弃/改写） | `TrigEffectHandler` | **不可以** |
| 错误分类 / 容灾决策 | `TrigLoopPolicy.recover` / `on_business_failed` | 可以（但策略写死在 `engine.mbt:259` 起） |
| 收尾兜底 | `TrigLoopPolicy.finish_at_end` | 可以 |
| 步级 trace `(state,event,effect)` | 无钩子 | 不可以 |

**切面纪律**：默认实现 = 现行行为；零语义副作用；可开关；开/关两态套件判据一致。

---

## 3. 术语表（本包私有）

| 词 | 含义 |
|---|---|
| `Hooks` | `TrigActions` 的实现载体（`actions.mbt:9`）——按命名 ADR 应改 `TrigActionsImpl` |
| `TrigLoopPolicy` | 主循环领域钩子 trait（生成面），钩子 = `begin_record` / `recover` / `finish_at_end` / `on_business_failed` |
| `TrigEffectHandler` | 效果执行面 trait（生成面，当前未被接活） |
| `ResetScope` | 发射后按粒度清槽（Object / PredObj / SPO / All） |
| `Slot` / `SlotType` | 栈帧（BnodeProp / Collection / Formula? —— trig 侧为 BnodeProp / List / Formula） |
| 定稿样板 | `gen_trig/trig.mbt`（历史上人工定稿、现为 check-in 产物）——IR 侧靠"逐行对齐"与它一致 |

---

## 4. 整改项上下文（R-T1 … R-T9）

### R-T1 效果面接活（对齐 n3v2 役22）`[建议]`

- 目标：`TrigEffectHandler` 成为真实切点（观测 / 容灾可挂），效果语义只有一份。
- 锚点：`trig.mbt:1165/1166/1167/1172–1226`；`engine.mbt:20/364`（`next`）；`engine.mbt:237/504/524`（`take_pending_quad` 等价物：`settle_shell` / `settle_annotation`）。
- 现状证据：`grep -n 'impl TrigEffectHandler' *.mbt` 仅命中 `trig.mbt` 的默认 impl；`interpret` 无调用点。
- 动作：① 探针先出"切点表"（§2）；② emit 套装收形（删恒定 `handle_continue`/`handle_done` 之类样板）；③ `interpret` 成唯一解释器，`engine.next` 调它；④ `emit_queue` 下沉 ctx 模板；⑤ 生成面改动走 trig 生成链（R-T2 门先行）。
- 验收：`rg "TrigEffectHandler"` 出现 impl + 调用点；80/80（或更新后计数）；四套件数字不变；门绿。
- 风险：trig 有图块（`enter_graph`/`exit_graph`）与 n3v2 不同，收形时**不得动图块语义**（`engine.mbt` 注释 V 段）。
- 依赖：T10（门）。

### R-T2 产物黄金门（对齐 n3v2 G9）`[建议]`

- 目标：`trig.mbt` 可再生且可对拍，一致性从"人工逐行对齐"升级为机器门。
- 锚点：`trig.mbt:4`（墙钟 ts）；`src/rdf/trig_domain_toml_gen.mbt:222`（现有 IR 侧门）；`domain_to_ir.mbt:15/52/257/407/2717`（人工对齐注释）；`src/fsm/cmd/main.mbt`（再生入口）。
- 动作：① 摸清 `fsm/cmd` 是否支持 pin ts（不支持则加 ts 参数）；② 加"重生成 ≡ check-in `trig.mbt` 逐字节"测试 + 强幂等钉（重复生成零字节移动）；③ 把"人工对账"注释改为指向门的注记。
- 验收：故意改一行表 → 门红；复原 → 门绿；连续两次生成零字节移动。
- 风险：v1 路径（`src/fsm`）为共享 codegen，改它要跑 `src/fsm` 全测试；**先探针再动**。
- 依赖：无（**应是第一役**）。

### R-T3 公共面收窄（对齐 n3v2 役28 / 题2=B）`[建议]`

- 目标：FSM 机械（Context / State / Event / Effect / 三 trait / Engine）不再是对外 API。
- 锚点：`pkg.generated.mbti:10/96–141/179/188`（当前 37 个 `pub`）；对照 n3v2 收窄后 24。
- 动作：逐项判定"对外 / 包内"（白盒测试同包可见，黑盒 `_test.mbt` 需保留必要 `pub`）。
- 验收：`.mbti` ≤166 行 / ≤24 `pub`；`moon test` 80/80（或更新后）；黑盒测试仍可编译。
- 风险：`trig_parser` 入口与 `TrigMaterializer` / `TrigSerializer` 必须留 `pub`；生成面若声明 `pub(all)`，收窄=改模板（依赖 R-T2 门）。

### R-T4 命名回灌（`TrigLoopPolicy → TrigSupervisor`）`[建议]`

- 目标：与 `bangto/world/naming.adr.md`（`ADR-NAMING-001`）一致。
- 锚点：`trig.mbt`（生成面 trait 名）、`engine.mbt:227/240/314/344/353`（impl + extend）、`todo.md` §1.1 的叙述、`ctx.md` 本卷。
- 动作：改生成面（模板/表）→ 再生 → 实现面同名替换 → 文档同步；`Hooks → TrigActionsImpl`（`actions.mbt:9` + `engine.mbt` 字段）同笔。
- 验收：`grep -rn 'TrigLoopPolicy'` 只在迁移记录；门绿；测试不变。
- 风险：跨仓（生成面在外仓 `src/fsm`/`src/rdf`）⇒ 与 R-T2 同笔最省。

### R-T5 清包内死件 `[建议]`

- 目标：包目录只留实现 + 测试 + 文档。
- 锚点：`*.bak` 5 个（`trig.mbt.bak` 36 KB 等）。
- 动作：按 `const.md` §5.2 归档（`bak/` 或本仓 `deprecated/`）并留指向；禁止静默删除。
- 验收：`ls *.bak` 为空；无悬空引用。

### R-T6 测试归位（对齐 n3v2 役27a）`[建议]`

- 目标：生产文件只剩实现。
- 锚点：`materialize_trig.mbt:1132`（测试辅助段起）、`:1212` 起 16 个 `test`；`serialize_trig.mbt:236/284/316` 等 5 个 `test`。
- 动作：新建 `materialize_trig_wbtest.mbt` / `serialize_trig_wbtest.mbt`；辅助去前缀并与 `trig_wbtest.mbt` 既有 helper **去重**（同包 `_wbtest` 共命名空间，重名即编译错）。
- 验收：`moon info` **零 diff**（证明未碰公共面）；测试计数不减。

### R-T7 卷面补全（拆卷）`[建议]`

- 目标：按 `bangto/world/const.md` §5.4（扁平式）补全五卷。
- 现状：只有 `todo.md`（353 行，**同时**载宪法 §1 与规格 §2）+ 空 `ctx.md`；缺 `const.md` / `spec.md` / `adr.md` ⇒ 违反 §5.2"todo/ctx 不承载红线与结构事实"。
- 动作：① `const.md` ← 现 §1（改写为"必须/禁止"句式）；② `spec.md` ← 现 §2（结构事实 + 不变量）；③ `todo.md` 只留役与账本（本卷追加的战役路线）；④ 决策（如 R-T2/R-T3 选型）落 `adr.md`（编号前缀建议 `ADR-TRIG-`）。
- 验收：五卷齐；`todo.md` 不再含红线条目；引用不悬空。

### R-T8 双包重复治理 `[立案]`

- 目标：n3v2 与 trig 是同一模板的两个实例，用户层已出现**大规模并行副本**。
- 证据：同名 helper 交集 20 个（`at_style_kw` / `classify_prefname` / `classify_structural` / `check_iri_view` / `check_bnode_view` / `deep_check_literal` / `deep_check_tt` / `eq_lower` / `eq_ignore_case` / `is_pn_local_esc` / `is_scheme_byte` / `list_top` / `literal_body_end` / `prefix_declared` / `slice_span` / `span_of_event` / `triple_term_inner_terms` / `tt_bool_word` / `bytes_of` / `ctx_span`）；用户层体量 n3v2 ≈4381 行 vs trig ≈4064 行。
- 动作（两选一，先出评估）：**A** 抽"共享用户层件"（helpers 上移到 `gen_nquads` 共享层或新 `gen_shared`）；**B** 明确"有意分叉"并把两包差异写进各自 `spec.md`。
- 验收：评估报告 + 决策（ADR）；若选 A，则两包 helper 各只剩方言特有部分。
- 风险：跨包 + 跨仓，属大役；**不得与 T11–T13 同笔**。

### R-T9 `moon.pkg` 头注漂移 `[建议]`（微）

- 锚点：`moon.pkg:1`——头注仍写"gen_nquads：…"（复制残留）。
- 动作：改为 gen_trig 的实况（生成面来源 + 用户层文件清单）。

---

## 5. 影响面与原子性

| 变更 | 是原子的 | 跨包 / 跨仓清单 |
|---|---|---|
| 改生成面（`src/fsm` 模板 / `src/rdf/domain_to_ir.mbt` 表） | 是 | 外仓 `src/rdf` + `src/fsm` → 再生 `fsm_out/trig_fsm.toml` → 再生 `trig.mbt` → 子仓测试 |
| 公共面收窄（R-T3） | 是 | `trig.mbt`（生成面 `pub`）+ `.mbti` + 黑盒测试可见性 |
| 命名回灌（R-T4） | 是 | 生成面 + 实现面 + 文档 + 测试 |
| 测试归位（R-T6） | 是 | 仅本包 `_wbtest.mbt` 与生产文件 |
| 双包重复治理（R-T8） | 是 | `gen_trig` + `gen_n3v2`（+ 可能新增共享包） |

⚠ 通用纪律：生成物禁手编；`.mbti` diff 逐行审；`moon fmt` 最后跑；**无门不改生成物**（R-T2 先行）。

---

## 6. 待裁题（每题给选项 + 影响）

1. **题T1 效果面接活形态**：A) `engine.next` 调 `interpret`（全控，容灾可接管 emit）——B) handler 退化为观察者注册表（改动小，能力弱）。→ 建议 **A**（与 n3v2 役22 同口径）。
2. **题T2 公共面收窄范围**：A) 只收 FSM 机械、留三 trait `pub`——B) 连同 trait 一起降包内（白盒测试足够）。→ 建议 **B**（与 n3v2 役28 题2=B 同口径）。
3. **题T3 双包重复（R-T8）**：A) 抽共享用户层件——B) 有意分叉 + 差异入 spec。→ 建议先 **B**（登记差异）并保留 A 为立项选项（跨包大役，风险高）。
4. **题T4 生成门落点**：A) 在 `trig_domain_toml_gen.mbt` 扩孪生门（与 n3gen G9 同构）——B) 在 `src/fsm` 侧建通用产物门（波及 nquads）。→ 建议 **A**（爆炸半径最小）。

---

## 7. 动手前 / 动手后 检查清单

动手前：

- [ ] 确认改的是**生成面**（外仓 `src/rdf` / `src/fsm`）还是**用户层**（子仓 `src/ttl/src/gen_trig`）。
- [ ] 生成面改动 → 先确认 R-T2 门状态（无门则先立门）。
- [ ] 跑基线：`moon check` / `moon test src/gen_trig` / 四套件数字记录。
- [ ] 涉及公共面 → 先裁题T2。

动手后：

- [ ] 生成面：外仓测试绿 → 再生 IR → 再生产物 → 子仓测试绿。
- [ ] `moon check src/gen_trig` → 0 warning。
- [ ] `moon test src/gen_trig` → 计数不减、套件数字不变。
- [ ] `moon info` 审 `.mbti` diff；`moon fmt` 幂等。
- [ ] 回写 `todo.md`（役状态 + 执行记录）；决策写 `adr.md`（R-T7 拆卷后）。

---

## 8. 锚点索引

| 主题 | 锚点 |
|---|---|
| 三业务面声明 | `trig.mbt`（`TrigActions` / `TrigEffectHandler:1165` / `TrigLoopPolicy`） |
| 效果面默认 impl | `trig.mbt:1172–1226` |
| 主循环 | `engine.mbt:364`（`next`）、`:504`（`settle_shell`）、`:524`（`settle_annotation`） |
| LoopPolicy 实现 | `engine.mbt:227/240/314/344`、`extend` `:353` |
| 归属点/裁剪 | `engine.mbt:78`（`trim_trailing_dot`）、`:88`（`normalize_term_span`）、`:126`（`directive_ok`） |
| 组装 / 轻验 | `parser_slice.mbt:257`（`validate_term`）、`:342`（`validate_prefname`）、`:539/586`（`parse_next/parse_all`） |
| 物化 | `materialize_trig.mbt:36/55`（struct/new）、`:1132`（测试辅助段） |
| 序列化 | `serialize_trig.mbt:236/284/316`（测试） |
| 生成链（IR 侧门） | `src/rdf/trig_domain_toml_gen.mbt:196/222/241` |
| 人工对齐纪律 | `src/rdf/domain_to_ir.mbt:15/52/257/407/2717` |
| 套件 | `rdf_suite_wbtest.mbt:47/108/115/123/131` |
