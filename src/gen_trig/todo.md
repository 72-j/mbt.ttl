# gen_trig 待办与战役路线（todo）

版本：v1.0.0（2026-09-03 立卷；2026-09-12 **T16 拆卷重写**——宪法/规格/决策迁出，本卷只留路线与账本）

**时效与定位**（`bangto/world/const.md` §5.1/§5.2）：本卷是**临时账本**——役关闭、结论被推翻或
改名落地后条目即失效，允许随时重写/合并；**只对 `src/ttl/src/gen_trig/` 有效**；
**不记决策**（决策归 `adr.md`）、**不记红线**（红线归 `const.md`）、**不重复结构事实**（归 `spec.md`）。

卷面分工（五卷 + 一页导读，同一信息只在一处详写）：

| 卷 | 回答 | 详写什么 |
|---|---|---|
| `const.md` | 什么绝对不允许 | 三条线、口径铁律、数据生命周期、action/effect 边界、生成物纪律（**冻结**） |
| `spec.md` | 现在怎么运转 | 分层与文件映射、生成链与再生、不变量 I-1..I-8、机械约束、已定语义口径、伪代码、**C 台账**、**R 台账**、验收口径 |
| `ctx.md` | 某项整改怎么做 | 锚点 / 证据 / 动作 / 验收 / 风险（收口项只留索引） |
| `adr.md` | 为什么这么决定 | `ADR-TRIG-001`…（背景 / 决策 / 被否方案 / 后果） |
| `ARCHITECTURE.md` | 一页看懂 | 五层图 + 生成链 + 契约成员 + 不变量速查 + 门 + 已知缺陷 |
| **本卷** | 做什么 / 按什么序 / 何时算完 | 资产与债务索引、战役路线、P 步表、执行记录 |

编号约定：`R-Txx` / `C-Txx` 与 `spec.md` §7/§8 一一对应；役号 `T<n>`（续本包既有 T10–T17）；
ADR 用 `ADR-TRIG-nnn`（世界卷前缀制）。原始底稿：旧 `todo.md` §4「变更收集」全文见 git 历史
（2026-09-12 拆卷前）。

**当前总状态（2026-09-12）**：T10–T17 中 **T16（卷面补全）已收官**；T10/T11/T12/T13/T14/T15 待开工，
T17 [立案]。基线：0 warning · 80/80 · 四套件 357/316/36/75（deferred 全零）· `.mbti` 349 行 / 54 pub 行 ·
表 36 态 / 34 事件 / 10 效果 / 195 转移 · 内联 test 21 · `.bak` 5。

---

## 1 现状可信面（资产，不动）

| # | 资产（一句话） | 详证 |
|---|---|---|
| A-T1 | 五层管线分层单一职责（词法 → 适配 → 表 → 组装/轻验 → 物化/深验 → 序列化） | `spec.md` §1；`ARCHITECTURE.md` |
| A-T2 | 三条线契约（决策在表 / 机械在模板 / 领域知识在契约成员），Effect 只加变体 | `const.md` §1；ADR-TRIG-001 |
| A-T3 | 双词法器同 Token 字母表，C 版为标准对齐源，逐 token pin | ADR-TRIG-002；`trig_bench_wbtest.mbt` |
| A-T4 | 图块区域封闭（表即合法性裁决者）；`EnterGraph`/`ExitGraph` 双路由 | ADR-TRIG-008；`spec.md` §5.3 |
| A-T5 | `[]` / `()` / 注解体 / 引用三元组全部落地，四套件 deferred **全零** | ADR-TRIG-003/004/007/009 |
| A-T6 | `@base` per-quad 快照（`bases` 链 + `base_version`/`prefix_version` 钳） | ADR-TRIG-005；`materialize_trig.mbt:392` |
| A-T7 | 单遍深验（四门融合在物化构词点；`lenient` 只跳轻验） | `const.md` §3；`spec.md` §5.5 |
| A-T8 | 生成面已回灌：`trig.mbt` 归生成器所有（手改面回灌 + 旧 `trig.toml` 退役） | ADR-TRIG-006 |

## 2 待办：不合理的地方（C 台账索引）

写实详表在 `spec.md` §7（事实 / 证据锚点 / 性质），**本节只留索引**。

| C | 一句话 | 现状 | 归属 |
|---|---|---|---|
| C-T1 | 效果面孤儿：`TrigEffectHandler` 无 impl/调用点；`interpret` 零调用 | 待整改 | R-T1 / T11 |
| C-T2 | 产物无黄金门：`trig.mbt:4` 墙钟 ts，一致性靠人工逐行对齐 | 待整改 | R-T2 / T10 |
| C-T3 | 公共面过宽：`.mbti` 349 行 / 54 pub 行（FSM 机械全 `pub`） | 待整改 | R-T3 / T12 |
| C-T4 | 命名未回灌：`TrigLoopPolicy`（正名 `Supervisor`）、`Hooks`（应 `TrigActionsImpl`） | 待整改 | R-T4 / T13 |
| C-T5 | 包内死件 5 个 `.bak` | 待整改 | R-T5 / T15 |
| C-T6 | 生产文件内联 test 21（materialize 16 + serialize 5） | 待整改 | R-T6 / T14 |
| C-T7 | 卷面违规：`todo.md` 曾同时载宪法与规格 | **已收口·T16** | R-T7 ✅ |
| C-T8 | 与 gen_n3v2 用户层重复副本（同名 helper 交集 20 个） | [立案] | R-T8 / T17 |
| C-T9 | `moon.pkg:1` 头注漂移（仍写 gen_nquads） | 待整改（微） | R-T9 / T15 搭车 |
| C-T10 | `<< >>` 壳内 `^^datatype` 误拒 | [立案] | R-T10 |
| C-T11 | 三引号规范化未设计 | [立案] | R-T11 |
| C-T12 | MoonBit 词法落后 C 侧 2.3–2.6× | [立案] | R-T12 |
| C-T13 | `@keywords` 语义豁免未接表 | [立案] | R-T13 |
| C-T14 | 陈数已澄清：旧 §5 item 6 记 deferred 2/1/5/6，实测全零 | **已澄清·T16** | — |

## 3 整改建议（R 台账索引）

详表在 `spec.md` §8；本节只留「动作 + 状态 + 役」。

| R | 动作 | 状态 | 役 |
|---|---|---|---|
| R-T1 | 效果面接活（`interpret` 唯一解释器 + 套装收形 + `emit_queue` 下沉 ctx） | 建议 | T11 |
| R-T2 | 产物黄金门（pin ts + 逐字节对拍 + 强幂等） | 建议 | **T10（第一役）** |
| R-T3 | 公共面收窄（FSM 机械降包内） | 建议 | T12 |
| R-T4 | 命名回灌（`TrigLoopPolicy → TrigSupervisor`；`Hooks → TrigActionsImpl`） | 建议 | T13 |
| R-T5 | 清包内死件（5 个 `.bak` 归档） | 建议 | T15 |
| R-T6 | 测试归位（21 个内联 test 迁 `_wbtest.mbt`） | 建议 | T14 |
| R-T7 | 卷面补全（拆 const/spec/adr，todo 只留账本） | **✅ 已落地** | T16 |
| R-T8 | 双包重复治理（抽共享件 或 有意分叉入 spec） | [立案] | T17 |
| R-T9 | `moon.pkg` 头注改实况 | 建议 | T15（搭车） |
| R-T10 | `<< >>` 内 `^^datatype` 修口 | [立案] | — |
| R-T11 | 三引号规范化设计 | [立案] | — |
| R-T12 | MoonBit 词法性能 | [立案] | — |
| R-T13 | `@keywords` 语义豁免 | [立案] | — |

---

## 4 战役路线（T10 → T17）

总图（`→` 前置；`∥` 可并行）：

```
T10 产物黄金门 ──┬─→ T11 效果面接活 ──┐
（第一役：无门不改生成物）│  ├─→ T12 公共面收窄 ─┤
                 │  ├─→ T13 命名回灌 ────┤
                 └─→ T14 测试归位 ∥ T15 清件 ├─→ T16 卷面补全 ✅ → T17 [立案] 双包重复治理
                                            ┘
```

统一验收（每役都跑，缺一不可；数字为 2026-09-12 基线）：

```sh
cd /home/thy/moonttl
moon test src/rdf            # 20/20（含 IR 侧 trig 对照门；动生成面时必跑）
moon test src/rdf/n3gen      # 12/12（动外仓时兜底）
cd /home/thy/moonttl/src/ttl
moon check src/gen_trig      # 0 error / 0 warning
moon test src/gen_trig       # 80/80；四套件数字不变（357/316/36/75）
moon info && moon fmt        # .mbti diff 逐行审；fmt 幂等
```

### T10 产物黄金门（R-T2）— P0，前置：无（**第一役：无门不改生成物**）

- 范围：`src/fsm/cmd/main.mbt`（再生入口）+ `src/rdf/trig_domain_toml_gen.mbt`（门位）。
- step：① 探针——摸 `fsm/cmd` 再生路径与"能否 pin ts"（`trig.mbt:4` 现为墙钟值
  `src/fsm/codegen.mbt` 的 `@env.now()`）；② 若不可 pin → 加 ts 参数（**先探针后动**，
  外仓 `src/fsm` 全测试兜底）；③ 加门：重生成 ≡ check-in `trig.mbt` **逐字节** + **强幂等**
  （重复生成零字节移动）。参考实现：n3v2 的 `n3_emit_banner(ts)`（ts 显式注入）。
- 交付：`trig.mbt` 可复现、门绿；`domain_to_ir.mbt` 的人工对齐注释改为指向门。
- 验收：故意改一行表 → 门红；复原 → 门绿；两次生成零字节移动。
- 风险：v1 路径共享 codegen（`src/fsm`），改它要跑外仓全测试；**先探针**。
- 待裁：题T4（门落点 A/B）。

**前置修复 ✅ 2026-09-12（外仓）**：`moon test src/rdf` 的「trig 对照：手工 `trig_domain.toml` ≡
词表生成」曾红（`src/rdf/trig_domain_toml_gen.mbt:215` `domain_config_matches`，由 `1152ca8` 引入）——
根因 = 役28 改名 `pver/bver → prefix_version/base_version` 时**第 4 层词表生成器漏笔**
（三层已同笔，`trig_domain_config()` 仍吐旧名）。修法：该函数两处 `name` 改名（+ 注释）。
验收：`moon test src/rdf` **20/20**（原 19/20）。旁注（未改，已标冻结）：
`n3_domain_toml_gen.mbt` + `domain/n3_domain.toml` 仍是旧名但两层自洽（v1 冻结 oracle），勿顺手改。

### T11 效果面接活（R-T1）— P0，前置：T10

- 范围：`trig.mbt:1138–1168`（trait）+ `:1172` 起（默认 impl）+ `engine.mbt:364`（`next`）。
- 交付：`TrigEffectHandler` 有 impl + 调用点；观测/容灾切面可挂；效果语义只有一份。
- 验收：`rg "TrigEffectHandler"` 出现 impl 与调用点；80/80；四套件数字不变；门绿。
- 风险：**trig 有图块**——收形不得动 `EnterGraph`/`ExitGraph` 双路由语义（ADR-TRIG-008）。
- 待裁：题T1（建议 A：`engine.next` 调 `interpret`）。

### T12 公共面收窄（R-T3）— P1，前置：T10

- 范围：`trig.mbt` 生成面的 `pub` 声明 + `pkg.generated.mbti`。
- 交付：`.mbti` 向 n3v2 收窄后看齐（166 行 / 29 pub 行量级）。
- 验收：`moon info` diff 只含收窄项；80/80；门绿；黑盒测试仍可编译。
- 风险：`trig_parser` / `TrigMaterializer` / `TrigSerializer` 必须留 `pub`。
- 待裁：题T2（建议 B：连 trait 一起降包内）。

### T13 命名回灌（R-T4）— P1，前置：T10

- 范围：`TrigLoopPolicy → TrigSupervisor`（`trig.mbt:223` + `engine.mbt:227/240/314/344/353` + 文档）；
  `Hooks → TrigActionsImpl`（`actions.mbt:9` + `engine.mbt` 字段）。
- 交付：`grep -rn 'TrigLoopPolicy'` 只剩迁移记录。
- 验收：门绿；80/80；`moon info` diff 只含改名。
- 待裁：与 T10 同笔（跨仓最省）。

### T14 测试归位（R-T6）+ T15 清件（R-T5/R-T9）— P1/P0，前置：无（可与 T10 并行）

- 范围：`materialize_trig.mbt:1132`（辅助段起，16 test）、`serialize_trig.mbt`（5 test）、5 个 `.bak`、
  `moon.pkg:1` 头注。
- 交付：生产文件只剩实现；包目录无 `.bak`；`moon.pkg` 头注写 trig 实况。
- 验收：**`moon info` 零 diff**（未碰公共面）；测试计数不减（80）。
- 风险：`.bak` 归档（`bak/` 或 `deprecated/`）并留指向，**禁静默删除**。

### T16 卷面补全（R-T7）— P1 **[✅ 已完成 2026-09-12]**

- 交付：五卷 + 一页——`const.md`（红线，自旧 §1 拆出）/ `spec.md`（结构事实 + 不变量 + 机械约束 +
  口径 + 伪代码 + C/R 台账 + 验收口径，自旧 §2/§3 拆出并补账）/ `adr.md`（`ADR-TRIG-001`…`011`，
  自旧 §4/§5 定案提炼）/ `ARCHITECTURE.md`（一页导读）/ 本卷（只留资产、债务、路线、P 步、执行记录）/
  `ctx.md`（对齐 `bangto/world/ctx-template.meta.md`，行号刷新、指标统一）。
- 验收：`todo.md` 不再含红线与结构事实；引用不悬空（`const/spec/adr/ctx` 互指一致）；
  实测数字与 `spec.md` §9 一致（80/80、357/316/36/75、349 行 / 54 pub 行、36/34/10/195、21、5）。
- 备注：拆卷同时清掉两处**陈数**——旧 §2.5 的"@base 已知缺陷"（★1 早已修复）与旧 §5 item 6 的
  "deferred 2/1/5/6"（实测全零）。

### T17 [立案] 双包重复治理（R-T8）— P2，前置：T11–T13

- 范围：`gen_trig` + `gen_n3v2`（同名 helper 交集 20 个；用户层 ≈4064 vs ≈4381 行并行副本）。
- step：① 出"共享面清单 + 抽件方案 + 分叉代价"评估；② 二选一：抽共享用户层件（新包/上移 `gen_nquads`）
  或"有意分叉 + 差异入各自 `spec.md`"。
- 交付：评估报告 + 决策（`adr.md` 条目）。
- 验收：决策落地；若抽件，两包各只留方言特有部分。
- 风险：跨包跨仓大役；**不得与 T11–T13 同笔**。
- 待裁：题T3（建议先 B 登记差异，A 留立项）。

---

## 5 P 步表（P 级 ↔ 役 ↔ R ↔ 前置）

| P | 步骤含义 | 役 | R | 前置 | 阻塞题 |
|---|---|---|---|---|---|
| **P0-1** | 产物黄金门（无门不改生成物） | T10 | R-T2 | — | 题T4 |
| **P0-2** | 效果面接活 | T11 | R-T1 | T10 | 题T1 |
| **P0-3** | 清包内死件 + 头注 | T15 | R-T5 / R-T9 | — | — |
| **P1-1** | 公共面收窄 | T12 | R-T3 | T10 | 题T2 |
| **P1-2** | 命名回灌 | T13 | R-T4 | T10 | — |
| **P1-3** | 测试归位 | T14 | R-T6 | — | — |
| **P1-4** | 卷面补全 | T16 **✅** | R-T7 ✅ | — | — |
| **P2-1** | 双包重复治理 | T17 [立案] | R-T8 | T11–T13 | 题T3 |
| **P2-2** | 生成面修口（壳内后缀 / 三引号 / 词法性能 / 关键字豁免） | — [立案] | R-T10–R-T13 | T10（门先行） | — |

推荐执行序：**T10 →（T14 ∥ T15）→ T13 → T12 → T11 → T17[立案]**；
T16 ✅ 已完成（本卷即其产物）。**R-T10–R-T13 的修口一律排在 T10 之后**（无门不改生成面）。

---

## 6 执行记录（滚动追加）

| 日期 | 役 | 范围 | 结果 / 验收数字 | 备注 |
|---|---|---|---|---|
| 2026-09-03 | — | T-1..T-9 全链落地 | 事件词表 / Effect / State / 转移表 / ContextProtocol / Action / EffectHandler / 对拍 / Turtle 方言 | 旧清单已删；见 `adr.md` ADR-TRIG-001/002 |
| 2026-09-03 | — | ★3 `[]` 属性列表（阶段 1+2） | 三态区域 + 5 入口行；空 fresh 独立成句 | ADR-TRIG-003 |
| 2026-09-04 | — | ★3 阶段 3 `()` 集合链 + 回收 | 合成谓词 `pk` + `emit_queue`；六路入口行 | ADR-TRIG-004 |
| 2026-09-04 | — | ★1 `@base` per-quad 快照 | `bases` 链 + `base_version`/`prefix_version` 钳；subm-27 ×2 出槽 | ADR-TRIG-005 |
| 2026-09-04 | — | ★8 手改面回灌生成管线 | 再生 vs 手稿仅余化妆差；旧 `trig.toml` 退役 | ADR-TRIG-006；"生成器回灌前禁再生"解除 |
| 2026-09-04 | — | 回收出槽五桩 + 撤桶九文件 | rdf-trig 354→355、rdf-turtle 316；deferred 逐步归零 | ADR-TRIG-009 |
| 2026-09-06 | — | 役 9 注解精化 port | 体主语 = TT 壳；+9 钉；316/75/36 不变 | ADR-TRIG-007 |
| 2026-09-12 | — | 立项评审 + `ctx.md` 立卷 | 基线：0 warning · 80/80 · 四套件 pin · `.mbti` 349/54 · 表 36/34/10/195 · 内联 test 21 · `.bak` 5 | 关键发现：产物无黄金门、效果面孤儿、公共面未收窄、命名未回灌 |
| 2026-09-12 | **T16** | **卷面补全（拆卷）** | 五卷 + 一页齐：`const.md` / `spec.md` / `adr.md`（ADR-TRIG-001…011）/ `ARCHITECTURE.md` / 本卷重写 / `ctx.md` 对齐；实测数字复核一致 | 顺带清两处陈数（@base 缺陷已修、deferred 已全零）；`todo.md` 472 → 本版 |
