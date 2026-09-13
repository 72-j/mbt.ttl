# gen_trig 整改上下文（ctx）

版本：v1.1.0（2026-09-12 立卷；2026-09-12 T16 对齐收口；**锚点行号为 2026-09-12 实测**）

**时效与定位**（`bangto/world/const.md` §5.1/§5.2）：本卷是**临时账本**——某项整改"怎么做"的
工作上下文；条目随役关闭而失效，允许随时重写/合并；**只对 `src/ttl/src/gen_trig/` 有效**；
**不记决策**（`adr.md`）、**不记红线**（`const.md`）、**不重复结构事实**（`spec.md`）。
因此：收口项只留索引，[建议]/[立案] 项保留完整字段。

**怎么用**：接到某个 R-T 项 → 读 §4 对应小节 → 按锚点定位 → 按动作改 → 按验收跑命令 →
回写 `spec.md` §8 状态 → 决策写 `adr.md` → `todo.md` §6 追加一行 → 刷新本卷失效锚点。

**注解约定**：`锚点` 一律 `文件:行`；`[定案]` = 已裁 / `[建议]` = 待裁 / `[立案]` = 另役；`⚠` = 易踩的坑。
术语以 `bangto/world/vocabulary.spec.md`（v2.0）为准，本卷 §3 只收本包私有词。

---

## 1 坐标与基线

### 1.1 生成链（与 gen_n3v2 的**关键差异**）

| 方言 | 生成链 | 产物门 |
|---|---|---|
| n3v2 | `src/rdf/n3gen`（自含：parse → validate → emit 直产） | **G9 黄金门**：ts 显式注入（`n3_emit_banner(ts)`）+ 逐字节对拍 + 强幂等 |
| **trig** | `src/rdf/domain/trig_domain.toml` → `src/rdf/domain_to_ir.mbt` → `src/rdf/fsm_out/trig_fsm.toml` → `src/fsm/cmd`（v1 codegen） | **仅 IR 侧门**：`src/rdf/trig_domain_toml_gen.mbt:215/222`（双文件编译 ≡ `fsm_out/trig_fsm.toml`，四腿）；**产物 `trig.mbt` 无门**——一致性靠 `domain_to_ir.mbt:15/52/257/407/2717` 的人工"逐行对齐"注释 |
| md | `src/gen_md/gen`（自有编译器） | — |

> 产物 `trig.mbt:4` 的 `Generated at:` 是**墙钟值**（`src/fsm/codegen.mbt` 的 `@env.now()`）：
> 重跑即变 ⇒ 无 ts 钉就**不可复现**（T10 要解决的第一件事）。

### 1.2 基线（2026-09-12 实测）

| 项 | 值 | 证据 / 命令 |
|---|---|---|
| 警告 | **0** | `cd src/ttl && moon check src/gen_trig` |
| 单元测试 | **80/80** | `moon test src/gen_trig` |
| 套件 | rdf-trig **357/357**、rdf-turtle **316/316**、rdf12-trig **36/36**、rdf12-turtle **75/75**（四套 `pin=true`，deferred 全零） | `rdf_suite_wbtest.mbt:47/108/115/123/131` |
| 外仓门 | `moon test src/rdf` **20/20**（含 IR 侧 trig 对照）、`moon test src/rdf/n3gen` **12/12** | 外层仓根 |
| 公共面 | `.mbti` **349 行 / 54 顶层 `pub` 行**（同口径：n3v2 收窄后 166 行 / 29 行） | `grep -c '^pub' pkg.generated.mbti` |
| 表规模 | **36 态 / 34 事件 / 10 效果 / 195 转移** | `grep -c '^\[\[\*\]\]' src/rdf/fsm_out/trig_fsm.toml` |
| 用户层体量 | actions 417 / engine 531 / lexer_adapter 333 / parser_slice 603 / materialize 1645 / serialize 375 / types 160 = **4064 行** | `wc -l` |
| 生产文件内联 test | **21**（materialize 16 + serialize 5） | `grep -c '^test '` |
| 包内死件 | **5 个 `.bak`**（`trig.mbt.bak` 36 KB、`engine.mbt.bak` 15 KB、`lexer_mbt*.bak` ×2、`nquads_test.mbt.bak`） | `ls *.bak` |

---

## 2 契约面注解（三名成员 + 切点表）

生成侧事实：三个 trait 全部由生成器发射进 `trig.mbt`；world 词表口径：**声明属 `Contract`，
实现属 `Assembly`**；三者合称"契约成员"（旧称"业务面"已废弃）。

| 成员 | trait（声明锚点） | 实现锚点 | 现状 |
|---|---|---|---|
| ① 语义落点 | `TrigActions`（`trig.mbt:240`，`pub(open)` 风格由生成模板决定） | `actions.mbt:9`（`Hooks` 单载体） | 已接活 |
| ② 效果面 Hook | `TrigEffectHandler`（`trig.mbt:1138`；默认 impl `:1172` 起；`interpret` `:1166`、`dispatch` `:1167`） | **无**（引擎自带效果语义） | **孤儿挂点（C-T1）** |
| ③ 控制流 Hook | `TrigLoopPolicy`（`trig.mbt:223`；world 正名 `TrigSupervisor`） | `engine.mbt:227`（begin_record）/`:240`（recover）/`:314`（finish_at_end）/`:344`（on_business_failed）+ `extend:353` | 已接活；**改名归 T13** |

**② 的成员清单**（`trig.mbt:1138–1168`）：`handle_continue / handle_emit_quad / handle_reset /
handle_done / handle_enter_graph / handle_exit_graph / handle_sequence / handle_pop_bnp /
handle_list_step / handle_open_slot` + `snapshot` + `apply_scope` + `on_exit_graph` + `on_pop_bnp` +
`on_list_step` + `on_open_slot` + `interpret` + `dispatch`——共 18 个，其中恒定样板（`handle_continue`/
`handle_done` 等）是 T11 收形的主要对象。

**切点表（要挂什么 → 挂哪 → 现状）**：

| 切面需求 | 挂点 | 现状 |
|---|---|---|
| 每 quad 观测（emit 埋点） | ② `handle_emit_quad` | **可以（T11 接活）** |
| 效果降级（丢弃 / 改写） | ② `interpret` | **可以（T11：唯一解释器）** |
| 错误分类 / 容灾决策 | ③ `TrigLoopPolicy::recover` / `on_business_failed` | 可以（策略现写死在 `engine.mbt:240` 起） |
| 收尾兜底 | ③ `finish_at_end` | 可以 |
| 会话级注入 | ③ `begin_record` | 可以（trig 仅构造期调用一次） |
| 步级 trace `(state,event,effect)` | 无钩子 | 不可以（需新增） |

**切面纪律**：默认实现 = 现行行为；零语义副作用；可开关；开/关两态下套件判据必须一致。

---

## 3 术语表（本包私有词）

| 词 | 含义（本包语境） |
|---|---|
| `Hooks` | `TrigActions` + `TrigEffectHandler` 的单载体实现（`actions.mbt:9`）——按命名 ADR 应改 `TrigActionsImpl` |
| `TrigLoopPolicy` | 控制流 Hook trait（生成面）；world 正名 **`Supervisor`** ⇒ 本包目标名 `TrigSupervisor` |
| 定稿样板 | `gen_trig/trig.mbt`——历史上人工定稿、现为 check-in 生成物；人工对齐注释遗留（C-T2） |
| TT 壳 | 引用三元组 `<< s p o >>` 的原文连续区间，作为体 quad 主语的物化形式（ADR-TRIG-007） |
| `pk`（合成谓词） | `ctx.pred_kind` 写下的 `rdf:first`/`rdf:rest` 标记，`snapshot` 读出即归 `Normal`（ADR-TRIG-004） |
| `bver` / `pver` | 快照带出的 base 链长 / 前缀账本长，物化层按其钳上界（ADR-TRIG-005） |
| 双路由 | `ExitGraph` 的动作路径与序列路径并存（ADR-TRIG-008） |
| 撤桶 | 把 deferred 桶里的套件文件逐条诊断后移出桶（ADR-TRIG-009） |

---

## 4 整改项

### 4.1 收口项索引

| R | 役 | 现口径 | 证据 |
|---|---|---|---|
| R-T7 卷面补全 | T16 ✅ | 五卷 + 一页：`const` / `spec` / `adr`（ADR-TRIG-001…011）/ `todo` / 本卷 / `ARCHITECTURE.md` | `todo.md` 472 → 现版；拆卷留痕见 ADR-TRIG-011 |
| R-T2 产物黄金门 | **T10 ✅ 2026-09-13** | 钉 ts 再生（`generate_with_ts` + CLI `--ts`）+ 工具链 `moon fmt` ≡ check-in `trig.mbt` 逐字节 + 强幂等；金样 ts `1788654011855`；形态口径 = 原始形 + `moon fmt` | 门：`src/rdf/trig_domain_toml_gen.mbt` `trig 产物黄金门`（`src/rdf` 21/21）；决策 `src/rdf/adr.md` ADR-6；禁令解除见 `const.md` §5 |
| R-T1 效果面接活 | **T11 ✅ 2026-09-13** | `interpret` 唯一解释器（`engine.mbt:404` 调用点）；`emit_queue` 下沉 ctx；引擎实现 `snapshot`/`on_exit_graph`/`on_pop_bnp`/`on_list_step`/`on_open_slot`（`:476/489/496/504/513`）——观测/容灾切面可挂 | ADR-TRIG-013；生成器侧开关 `src/rdf` ADR-7；验收 `gen_trig` 80/80 + 模块 329/329 + `src/rdf` 21/21 |
| Turtle 翻 2.0（清障） | **T18 ✅ 2026-09-13** | `DomainDialectKind::Turtle` 与 Trig 同路 → `domain2/trig_*`；本包全方言**数据面单一**；数组匹配臂收缩为仅 N3 | 钉子「Turtle 路由 ≡ domain2 trig 双文件」（`src/rdf` 22/22）；`src/rdf/adr.md` ADR-8；ADR-5 的"Turtle 例外"关闭 |
| RDF 1.2 单开关 | **T19 ✅ 2026-09-13** | `scalar_only_escapes → rdf12`（单开关管转义 + 方向后缀）：1.2 代理全禁 + `--ltr/--rtl` 放行；1.1 宽容 + 方向后缀**拒** | ADR-TRIG-014；钉子 `@ar--rtl` 1.2 放行 / 1.1 拒；套件 runner `rdf12?`；`gen_trig` 80/80 |
| （陈数澄清） | T16 ✅ | 旧 §2.5"@base 已知缺陷"已由 ★1 修复；旧 §5 item 6"deferred 2/1/5/6"实测全零 | `spec.md` §5.5；套件 357/316/36/75 |

### 4.2 存活项上下文

（R-T1 / R-T2 均已收口，见 4.1 索引；原七字段随 ADR-TRIG-013 / `src/rdf` ADR-6 归档。）

#### R-T1 效果面接活 `[建议]`（对齐 n3v2 役22）

- 目标：`TrigEffectHandler` 成为真实切点（观测/容灾可挂）；效果语义只有一份。
- 锚点：`trig.mbt:1138–1168`（trait）、`:1172` 起（默认 impl）、`:1166`（`interpret` 零调用）；
  `engine.mbt:364`（`next`，自带效果解释）、`:175`（`emit_queue`，引擎私有）、`:504`（`settle_shell`）、
  `:524`（`settle_annotation`）。
- 现状证据：`grep -rn "impl TrigEffectHandler" *.mbt` 只命中生成默认 impl；`interpret` 无任何调用点。
- 动作：① 探针出切点表（§2，现已就位）；② 套装收形（删恒定 `handle_continue`/`handle_done` 等样板，
  保留真实挂点）；③ `interpret` 成唯一解释器、`engine.next` 调它；④ `emit_queue` 下沉 ctx 模板；
  ⑤ 生成面改动**必须走 T10 的门**。
- 验收：`rg "TrigEffectHandler"` 出现 impl + 调用点；80/80；四套件数字不变；门绿。
- 风险：trig 有图块（`enter_graph`/`exit_graph`）与注解双区——收形**不得动图块/注解语义**（ADR-TRIG-007/008）。
- 依赖：T10。

#### R-T3 公共面收窄 `[建议]`（对齐 n3v2 役28，题2=B）

- 目标：FSM 机械（Context / State / Event / Effect / 三 trait / Engine）不再是对外 API。
- 锚点：`pkg.generated.mbti`（349 行 / 54 顶层 `pub` 行；对照 n3v2 166 行 / 29 行）。
- 动作：逐项判定对外/包内（白盒 `_wbtest` 同包可见；黑盒 `_test.mbt` 需保留必要 `pub`）；
  生成面 `pub` 化改动经 T10 门再生。
- 验收：`.mbti` 向 166 行 / 29 pub 行量级收敛；80/80；门绿；黑盒测试仍可编译。
- 风险：`trig_parser` / `TrigMaterializer` / `TrigSerializer` 必须留 `pub`。
- 依赖：T10（改生成面）。待裁：题T2。

#### R-T4 命名回灌 `[建议]`

- 目标：与 `bangto/world/vocabulary.spec.md` v2.0 / `naming.adr.md`（`ADR-NAMING-001`）一致。
- 锚点：`trig.mbt:223`、`engine.mbt:227/240/314/344/353`（`TrigLoopPolicy`）；`actions.mbt:9` +
  `engine.mbt` 字段（`Hooks`）。
- 动作：改生成面（模板/表）→ 再生 → 实现面同名替换 → 文档同步；两处改名**同笔**（跨包原子性）。
- 验收：`grep -rn 'TrigLoopPolicy\|struct Hooks'` 只剩迁移记录；门绿；80/80；`moon info` diff 只含改名。
- 风险：生成面在外仓（`src/rdf` + `src/fsm`）⇒ 与 T10 同笔最省。
- 依赖：T10。决策依据：ADR-TRIG-010。

#### R-T6 测试归位 `[建议]`（对齐 n3v2 役27a）

- 目标：生产文件只剩实现。
- 锚点：`materialize_trig.mbt:1132`（辅助段起）+ 16 个 `test`；`serialize_trig.mbt:236` 起 5 个 `test`。
- 动作：新建 `materialize_trig_wbtest.mbt` / `serialize_trig_wbtest.mbt`；辅助**去前缀并与 `trig_wbtest.mbt`
  既有 helper 去重**（同包 `_wbtest` 共命名空间，重名即编译错）。
- 验收：`moon info` **零 diff**；测试计数不减（80）。
- 依赖：无（可与 T10 并行）。

#### R-T5 清包内死件 `[建议]` + R-T9 `moon.pkg` 头注

- 锚点：`*.bak` 5 个；`moon.pkg:1`（头注仍写"gen_nquads：…"，复制残留）。
- 动作：`.bak` 归档（`bak/` 或本仓 `deprecated/`）并留指向，**禁静默删除**；头注改 trig 实况。
- 验收：`ls *.bak` 为空；`moon.pkg` 头注与实况一致；无悬空引用。
- 依赖：无。

#### R-T10 `<< >>` 壳内 `^^datatype` 修口 `[立案]`

- 锚点：`parser_slice.mbt` 的 `triple_term_inner_terms`（按顶层空白切项）。
- 现状证据：`^^xsd:date` 被当成第 4 项 ⇒ 壳内带 datatype 的项误拒（bench 语料规避了该形态）。
- 动作：切项时"引号单元闭壳后右扩 `@lang` / `^^` 后缀"（与词法无脑扫口径对齐）。
- 验收：新增壳内 `^^` 正例钉 + 负例钉（真多余项仍拒）；套件数字不变。
- 风险：切项函数三层共用（`validate_term` / `tt_shell_terms` / `deep_check_tt`）——**一处改三处验**。
- 依赖：T10（生成面无关，但属表外修口，门先行）。

#### R-T11 三引号规范化 `[立案]`

- 锚点：`serialize_trig.mbt`（当前原样保真回写）。
- 动作：先定规范化口径（是否归一到 `"""` 形态、换行/转义如何统一），再落实现 + round-trip 钉。
- 验收：口径写进 `spec.md` §5.6；`I-3`（round-trip）在规范化域外仍成立。
- 依赖：无。

#### R-T12 MoonBit 词法性能 `[立案]`

- 锚点：`trig_bench_wbtest.mbt`（逐 token pin + 计时）。
- 现状证据：简单 4006 token 434 µs(C) vs 1117 µs(Moon)；复杂 9046 token 907 vs 2056（**2.6× / 2.3×**）。
- 动作（候选）：主循环字节分派表、span 直写、减少 Token 枚举构造；**两器 parity 必须保持零差**。
- 验收：bench 数字改善且 parity 钉不变；套件数字不变。
- 依赖：无（但两器同改 ⇒ 属跨镜像变更）。

#### R-T13 `@keywords` 语义豁免 `[立案]`

- 锚点：`lexer_adapter.mbt`（`classify_structural` 无跨 token 状态）。
- 现状证据：`@keywords` 模式下裸 `a` 仍出 `KeywordA`（语义豁免需跨 token 状态或走表）。
- 动作：接表时定案——在表/物化层兜，或给适配层加单槽 state（后者违反"adapter 只分类"口径，慎）。
- 验收：`@keywords` 正例钉 + 未声明时 `a` 仍 `KeywordA` 的负例钉。
- 依赖：T10。

#### R-T8 双包重复治理 `[立案]`

- 目标：n3v2 与 trig 是同一模板的两个实例，用户层已出现大规模并行副本。
- 证据：同名 helper 交集 20 个（`at_style_kw` / `classify_prefname` / `classify_structural` / `check_iri_view` /
  `check_bnode_view` / `deep_check_literal` / `deep_check_tt` / `eq_lower` / `eq_ignore_case` / `is_pn_local_esc` /
  `is_scheme_byte` / `list_top` / `literal_body_end` / `prefix_declared` / `slice_span` / `span_of_event` /
  `triple_term_inner_terms` / `tt_bool_word` / `bytes_of` / `ctx_span`）；用户层 ≈4064（trig）vs ≈4381（n3v2）行。
- 动作（二选一，先出评估）：**A** 抽共享用户层件（上移 `gen_nquads` 或新 `gen_shared`）——**B** 明确有意分叉 +
  差异写进各自 `spec.md`。
- 验收：评估 + 决策（`adr.md`）；若选 A，两包 helper 各只剩方言特有部分。
- 风险：跨包 + 跨仓，大役；**不得与 T11–T13 同笔**。
- 依赖：T11–T13。待裁：题T3。

---

## 5 影响面与原子性

| 变更 | 是原子的 | 跨包 / 跨仓清单 |
|---|---|---|
| 改生成面（`src/rdf/domain*` / `domain_to_ir.mbt` / `src/fsm` codegen） | 是 | 外仓 `src/rdf` + `src/fsm` → 再生 `fsm_out/trig_fsm.toml` → 再生 `trig.mbt` → 子仓测试（**同笔**） |
| 改产物门（T10） | 是 | `src/fsm/codegen.mbt`（ts 注入）+ `src/rdf/trig_domain_toml_gen.mbt`（门）+ `src/fsm` 全测试 |
| 公共面收窄（R-T3） | 是 | 生成面 `pub` 声明 + `.mbti` + 黑盒测试可见性 |
| 命名回灌（R-T4） | 是 | 生成面 + 实现面 + 文档 + 测试 + `.mbti` 同笔 |
| 测试归位（R-T6） / 清件（R-T5） | 是 | 仅本包 `_wbtest.mbt`、生产文件、`bak/` 归档位 |
| 双包重复治理（R-T8） | 是 | `gen_trig` + `gen_n3v2`（+ 可能新增共享包） |
| 词法镜像改动（R-T12） | 是 | `gen_nquads/lexer_mbt.mbt`（Moon）+ `lexerc_ffi.c`（C）**同步** + parity 电池 |

⚠ 通用纪律：生成物禁手编；**无门不改生成面**（T10 先行）；`.mbti` diff 逐行审；`moon fmt` 放最后；
探针后必须还原并复核产物（T10 立门后：md5/逐字节）。

---

## 6 待裁题（每题给选项 + 影响）

1. **题T1 效果面接活形态**：A) `engine.next` 调 `interpret`（全控，容灾可接管 emit）——B) handler 退化为
   观察者注册表（改动小，能力弱）。→ 建议 **A**（与 n3v2 役22 同口径）。
2. **题T2 公共面收窄范围**：A) 只收 FSM 机械、留三 trait `pub`——B) 连 trait 一起降包内（白盒测试足够）。
   → 建议 **B**（与 n3v2 役28 题2=B 同口径）。
3. **题T3 双包重复（R-T8）**：A) 抽共享用户层件——B) 有意分叉 + 差异入 spec。→ 建议先 **B**（登记差异），
   保留 A 为立项选项（跨包大役，风险高）。
4. **题T4 生成门落点**：A) 在 `trig_domain_toml_gen.mbt` 扩孪生门（与 n3gen G9 同构）——B) 在 `src/fsm` 侧建
   通用产物门（波及 nquads，而 nquads 为 TOML 1.0 冻结口径）。→ **裁断：A 落地**（T10 ✅）——
   门落 `trig_domain_toml_gen.mbt`；B 的同法可在 nquads 产物门补立时复用（另役）。

---

## 7 动手前 / 动手后 检查清单

动手前：

- [ ] 确认改的是**生成面**（外仓 `src/rdf` / `src/fsm`）还是**用户层**（子仓 `src/ttl/src/gen_trig`）。
- [ ] 生成面改动 → 先确认 T10 门状态（**无门不改**）。
- [ ] 读 `const.md` 相关红线（三条线 / 口径铁律 / action-effect 边界）。
- [ ] 跑基线：`moon check` / `moon test src/gen_trig` / 四套件数字记录（§1.2）。
- [ ] 涉及公共面 → 先裁题T2；涉及效果面 → 先裁题T1。
- [ ] 涉及 git 操作 → 按 `AGENTS.md`「商量制」：先说明 + 命令草案，等指令再执行。

动手后：

- [ ] 生成面：外仓测试绿 → 再生 IR → 再生产物 → 子仓测试绿。
- [ ] `moon check src/gen_trig` → 0 warning。
- [ ] `moon test src/gen_trig` → 80/80 且四套件 357/316/36/75 不变。
- [ ] `moon info` 审 `.mbti` diff；`moon fmt` 幂等。
- [ ] 回写 `spec.md` §7/§8；决策写 `adr.md`；`todo.md` §6 追加一行；本卷刷新失效锚点。

---

## 8 锚点索引（2026-09-12 实测）

| 主题 | 锚点 |
|---|---|
| 契约成员声明 | `trig.mbt:223`（Supervisor/trait 名 `TrigLoopPolicy`）、`:240`（Actions）、`:1138`（EffectHandler） |
| 效果面默认 impl / 解释器 | `trig.mbt:1172` 起（impl）、`:1166`（interpret）、`:1167`（dispatch） |
| 主循环 | `engine.mbt:364`（`next`）、`:175`（`emit_queue`）、`:504`（`settle_shell`）、`:524`（`settle_annotation`） |
| Supervisor 四钩子 | `engine.mbt:227` / `:240` / `:314` / `:344`、`extend:353` |
| 归位点 / 裁剪 | `engine.mbt:78`（`trim_trailing_dot`）、`:88`（`normalize_term_span`）、`:126`（`directive_ok`） |
| 组装 / 轻验 | `parser_slice.mbt:257`（`validate_term`）、`:342`（`validate_prefname`）、`:539`（`parse_next`）、`:586`（`parse_all`） |
| 物化 | `materialize_trig.mbt:36`（struct）、`:55`（new）、`:392`（`base_at`）、`:1132`（测试辅助段） |
| 序列化 | `serialize_trig.mbt:236`（首个 test）；round-trip 钉在 `trig_wbtest.mbt` |
| 生成链（IR 侧门） | `src/rdf/trig_domain_toml_gen.mbt:215/222`；人工对齐注释 `src/rdf/domain_to_ir.mbt:15/52/257/407/2717` |
| 套件 runner | `rdf_suite_wbtest.mbt:47`（入口）、`:108/115/123/131`（四套） |
| 双词法 bench | `trig_bench_wbtest.mbt` |
| 头注漂移 | `moon.pkg:1` |

---

## 9 工程经验（役间沉淀，动手前先翻）

**门先行**

- **无门不改生成面**：产物无黄金门时，任何生成面改动都无法自证等价——T10 必须先行。
  n3v2 的做法是把 ts 显式注入（`n3_emit_banner(ts)`）再逐字节对拍；trig 走的是 v1 codegen，需先探针再动。
- **人工"逐行对齐"不是门**：`domain_to_ir.mbt` 的注释纪律在跨三层改动时会静默失效（T10 要把它换成机器门）。
- **IR 侧门 ≠ 产物门**：`fsm_out/trig_fsm.toml` 字节级一致，不代表 `trig.mbt` 一致（ts 行即反例）。

**生成链三层同笔**

- 改名/加字段类改动必须**四层同笔**：`domain/trig_domain.toml` → `domain_to_ir.mbt` →
  `fsm_out/trig_fsm.toml` → 词表生成器（`trig_domain_toml_gen.mbt`）。**漏第 4 层**曾导致
  `moon test src/rdf` 红（役28 的 `pver/bver → prefix_version/base_version`），2026-09-12 修复。
- 冻结 oracle 不要顺手改：`n3_domain_toml_gen.mbt` + `domain/n3_domain.toml` 的旧名两层自洽
  （v1 冻结），改名会破坏对照基线。

**表外真堵的处理法**

- 套件红点分布零散时，先问"是不是表外真堵"（词法后缀门 / 相对展开 / 尾斜杠 / `] }` 收口 / `@prefix:` 零空格）；
  这类问题的修法在**表外某单点**，不是加表行（ADR-TRIG-009 四桩五例全属此）。
- **拆项函数是共用面**：`triple_term_inner_terms` 被 `validate_term` / `tt_shell_terms` / `deep_check_tt`
  三处共用——改它要三处验（R-T10 的坑）。

**测试与钉**

- **点名跑**：`moon test src/gen_trig -f "*关键字*"`（file-filter 与 `-p` 混用会报错）。
- **钉要能证伪**：新增钉先故意破坏实现确认它变红（否则是假钉）；套件 `pin=true` + deferred 必须为 0。
- **错误类钉自带结构**：造 bad 用例前先查表可达（哪些态有出边）与词法合并行为，否则钉会测到别的层。
- bench 类钉（`trig_bench_wbtest.mbt`）兼作**双词法 parity 电池**——改词法两侧同步，否则 parity 先红。

**回收与撤桶**

- deferred 桶不是"免检区"：每轮回收要逐条诊断（哪一桩真堵），撤桶文件数 + 套件数字要成对记录。
- `[]` / `()` 类结构落地后要**回头重扫桶**（当初打包入桶时未逐条诊断，落地后往往整族出槽）。

**文档与口径**

- 五卷分工遵守"单一事实源"：红线进 `const`、事实进 `spec`、决策进 `adr`、路线进 `todo`、动作进 `ctx`；
  `todo`/`ctx` 有时效，可随时重写（本项目已收敛此纪律，勿再让 `todo` 承载宪法或规格）。
