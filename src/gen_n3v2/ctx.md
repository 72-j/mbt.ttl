# gen_n3v2 整改上下文（ctx）

版本：v1.1.0（2026-09-11 立卷；2026-09-12 整理收口；**锚点行号为 2026-09-12 实测**）

**时效与定位**（定自 `bangto/world/const.md` §5.1/§5.2）：本卷是**临时账本**——某项整改"怎么做"的
工作上下文；条目随役关闭而失效，允许随时重写/合并；**只对 `src/ttl/src/gen_n3v2/` 有效**；
**不记决策**（决策归 `adr.md`）、**不记红线**（红线归 `const`）、**不重复结构事实**（归 `spec.md`）。
因此：**收口项只留索引**（动作 / 锚点 / 验收随 ADR 归档），只有 [立案] 项保留完整字段。

**怎么用**：接到某个 R 项 → 读本卷对应小节 → 按"锚点"定位 → 按"动作"改 → 按"验收"跑命令 →
回写 `spec.md` §8 的 R 台账 → 语义变更写 `adr.md` → 刷新本卷失效锚点（缺失环视为未完成）。

**注解约定**：`锚点` 一律 `文件:行`；`[定案]` = 已裁 / `[建议]` = 待裁 / `[立案]` = 另役；`⚠` = 易踩的坑。
术语以 `bangto/world/vocabulary.spec.md`（v2.0）为准，本卷 §3 只收本包私有词。

---

## 1. 坐标与基线

仓界（改代码前先确认落到哪个仓，**提交必须分开**）：

```
外层仓 /home/thy/moonttl            （生成器 + 表源 + 契约）
├── src/rdf/n3gen/                  n3v2_base.toml + n3v2_trans.toml
│   ├── compose.mbt                 构建期求积（役30：子机 × 实例 × 标记行）
│   ├── validate.mbt                G10 装配门 / G11 可达性 + 分级开关
│   └── n3gen_test.mbt              G1–G9、G12、G13；G9 落 n3v2_out.gen
└── src/ttl/                        （嵌套仓，独立 .git；下游包）
    └── src/gen_n3v2/
        ├── n3.mbt                  ⚠ 生成物，禁手编；改它 = 改表 + 再生
        ├── engine.mbt / actions.mbt / lexer_adapter.mbt / parser_slice.mbt / materialize_n3.mbt / serialize_n3.mbt
        └── spec.md / ctx.md / todo.md / adr.md / ARCHITECTURE.md
```

基线（2026-09-12 实测；整改前后都要对得上）：

| 命令 | 当前值 | 目标 |
|---|---|---|
| `cd src/ttl && moon check src/gen_n3v2` | 0 error / **0 warning** | 守（役26 起强制） |
| `cd src/ttl && moon test src/gen_n3v2` | **116/116** | 只增不减 |
| `cd src/ttl && moon test` | **329/329**（模块） | 守 |
| `cd /home/thy/moonttl && moon test src/rdf/n3gen` | **12/12**（G1–G9 + G12 + G13 + 纯函数单测） | 守 |
| `cd /home/thy/moonttl && moon test src/rdf` | **20/20** | 守 |
| 套件 | trig 357/357、rdf-turtle 316/316、rdf12-trig 36/36、rdf12-turtle 75/75、nquads 124 | pin 不变 |
| N3Tests | neg 23ok/0miss；pos+eval 205 clean | pin 不变 |
| examples | A=13 / B=0 / C=0（pinned） | pin 不变 |
| 影子缺口（strict-gap 基线） | 5 / 0 / 123 / 13 | R-16 目标 0/0/0/0 |
| `.mbti` 公共面 | 166 行 / **29 pub** | 收窄即需逐行审 diff |

现状提示：两仓与各自 remote 齐平，工作区无未提交改动（`MD/MoonMarkMind`、`MD/frontierlab`、
`MD/moui` 为另一条工作线的未跟踪内容，与本事无关）。

---

## 2. 契约面（三成员 + 切点表）

生成侧事实：三个 trait **全部由 `src/rdf/n3gen/emit.mbt` 发射**，产物是 `n3.mbt`；
役28（ADR-28）后三者均为 `priv`（包内可见）。world 词表口径：**声明属 `Contract`，实现属 `Assembly`**；
三者合称"契约成员"，旧称"业务面"已废弃。

### 成员 ① `N3Actions`（语义落点）

- 声明 / 实现锚点：`n3.mbt:299`（48 方法，签名统一 `Result[N3Effect, N3ActionError]`）/
  `actions.mbt`（`impl N3Actions for N3ActionsImpl`）。
- 契约：只写槽位/账本、返回意图；**永不重置 ctx**；拿不到数据视图（只有 span）。
- 命名：实现载体 `N3ActionsImpl`（役28 由 `Hooks` 改名；trait 保留是生成模板的形态选择）。

### 成员 ② `N3EffectHandler`（效果面 Hook）

- 声明 / 实现锚点：`n3.mbt:2044`（trait）/ `n3.mbt:2128`（`impl N3EffectHandler with fn interpret`）；
  套装 verbatim 生成在 `emit.mbt:1085`（`n3_emit_handler_suite`）。
- 成员：`handle_continue / handle_emit_quad / handle_reset / handle_done / handle_sequence /
  handle_pop_bnp / handle_open_slot`、`snapshot`、`apply_scope`、`on_exit_graph`、`on_pop_bnp`、
  `on_open_slot`、`interpret`；配套 `N3EffectOutcome`（`n3.mbt:2100`）。
- 现状（役22 接活后）：`interpret` = **唯一解释器**，`engine.next`（`engine.mbt:577`）只做
  "取事件 → step → interpret → 上抛"；倒装/注解壳交换已下沉 `N3Context::take_pending`（`engine.mbt:517`）；
  `apply_scope`（`n3.mbt:2108`）调用 `N3Context::reset`（`n3.mbt:216`）而非另实现。
  ⚠ `dispatch` 已不存在（旧卷记载作废）。
- 挂点用途：观测（quad 计数 / span 范围）与容灾（丢弃 / 改写 / 降级）都经此面。

### 成员 ③ `N3LoopPolicy`（控制流 Hook；**world 正名 `Supervisor`，代码待改名**）

- 声明 / 实现锚点：`n3.mbt:282` / `engine.mbt:350`（`begin_record`）、`:366`（`recover`）、
  `:423`（`finish_at_end`）、`:454`（`on_business_failed`）；模板注释 `emit.mbt:660`。
- 契约：循环骨架固定（入口/终止 → step → interpret → 错误降级），领域知识全在 4 钩子。
- 钩子语义：`begin_record` 会话起点（计数器/trace 注入）｜`recover` 容灾决策点（现行 = 记录 +
  清栈 + `consume_to_recover_point`，`engine.mbt:388`）｜`finish_at_end` 脏尾兜底（⚠ 自排水不许破坏，
  否则 `parse_all` 死循环）｜`on_business_failed` 失败映射（现行 = `ParseError::SyntaxErr`）。
- **命名欠账**：world 词表（v2.0）把 `LoopPolicy` 列为废弃别名、正名 `Supervisor`；
  本包代码仍是 `N3LoopPolicy`（`.mbt` 命中 7 处：`n3.mbt:282` 声明 + `engine.mbt` 四 impl 与 extend 块），
  生成侧模板在 `emit.mbt:660`。改名是跨包原子变更（trig 侧 `TrigLoopPolicy` 命中 26 处），
  列为候选**役34**，与 gen_trig 的 T13 同源，建议**同笔**做。

**切点表（要挂什么 → 挂哪 → 现状能不能挂）**：

| 切面需求 | 挂点 | 现状 |
|---|---|---|
| 观测：步级 trace (state,event,effect) | ③ `Supervisor` 或 ② `EffectHandler` | **需新增钩子**（现无步级挂点） |
| 观测：quad 计数 / span 范围 | ② `interpret` 的 EmitQuad 臂 | 可以（役22 接活） |
| 容灾：丢弃 / 改写 / 降级为注释 | ② `interpret` | 可以（效果面全控，役22 题1=A） |
| 容灾：错误分类 / skip / 重试 | ③ `recover` | 可以（机械在 `engine.mbt:388`，切面在此决策） |
| 观测/容灾：会话级注入 | ③ `begin_record` | 可以 |

**切面纪律**：默认实现 = 现行行为；切面**零语义副作用**且可开关；开/关两态下套件判据必须一致。

---

## 3. 术语表（本包私有词）

| 词 | 含义（本包语境） |
|---|---|
| 役N | 一次可独立交付/验收的战役编号（`adr.md`） |
| ADR-00X | 语义裁决编号：002 公式不透明 / 003a 集合单一 BNode / 003b 显式链预留 / 004 变量只记身份 / 005 规则与等同谓词 / 006 路径 fresh 链 |
| 罩 | 公式帧在栈上；"罩内" = `N3Context::under_formula`（`engine.mbt:336`）为真 |
| 胶 | 词法吞边界，相邻标点粘进词项 span（如 `"x"@en,` 的 `,`） |
| 归位点 | 事件进表前的引擎预处理点（`N3Engine::normalize_term_span`，`engine.mbt:192`） |
| 账 | ctx 上的记账数组/字段（`prefixes` / `bases` / `kw_ledger` / `is_src` / 壳账四字段） |
| 门 | 生成器门 G1–G13（外层仓）与物化四门（`gate_iri` 等） |
| 钉 | 断言式测试（数字写死，漂移即红） |
| 死位 / 预留位 | 有意保留但当前不生效的口径（ADR-003b 的 `RDFFirst/RDFRest`；`graph` 恒 `None`；`iri_upcast` 为**活机制**非死位） |
| 桶 | 套件分类记账（neg / pos / eval、deferred / mat-only 等） |
| 自排水 | `finish_at_end` 报告一次即清零，防 `parse_all` 无限重报（`engine.mbt:423`） |

> `Contract` / `Policy` / `Assembly`(asm) / `Business` / `Supervisor` / `Runtime` / `Aspect` / `Hook`
> 的定义与废弃别名（`Biz` / `User` / `Impl` / `LoopPolicy`）见 `bangto/world/vocabulary.spec.md`，本卷不复制。

---

## 4. 整改项

### 4.1 收口项索引（R-01 … R-15）

**动作 / 锚点 / 验收随对应 ADR 归档**（`spec.md` §8 有裁决与验收；`adr.md` 有完整论证）。
本表只留"现口径 + 现行锚点"，供改代码时快速定位。

| R | 役 | ADR | 现口径（一句） | 现行锚点 |
|---|---|---|---|---|
| R-01 | 役23 | ADR-24 | 状态权威 = 表边为主 + 3 处破例入册（id 特例刻帧 + pop 无条件读帧） | `actions.mbt:172/529/719`；`spec.md` §5.1 |
| R-02 | 役22 | ADR-22 | `interpret` 唯一解释器；engine 只做控制流；`take_pending` 下沉 ctx | `n3.mbt:2044/2128`；`engine.mbt:517/577` |
| R-03 | 役23 | ADR-24 | 归位点分类清单（A 直写 / B 引擎归位 / C 关键词真相）；事件重分类出表模型 | `spec.md` §5.1；`engine.mbt:136/171/192` |
| R-04 | 役29 | ADR-29 | 短期 = 补偿点单点台账（六点地图 + 钉面清单）；长期见 §4.2 | `lexer_adapter.mbt` 头注；`engine.mbt:84` |
| R-05 | 役24 | ADR-25 | `error_spans` 累积 + recover 拆层 + drain 三点保文件序 | `parser_slice.mbt:52`；`engine.mbt:366` |
| R-06 | 役24 | ADR-25 | 零长 span 带内通道保留 + 物化验形双门（唯一构造点 `pop_bnode_prop`） | `materialize_n3.mbt:683`；`actions.mbt:137` |
| R-07 | 役25 | ADR-23 | 三 runner 双判 + 绝对计数钉 + 桶闭合钉 | `rdf_suite_wbtest.mbt:116/118`；`n3tests_suite_wbtest.mbt:50` |
| R-08 | 役28 | ADR-28 | 生成件与用户层机械降 `priv`；`.mbti` 只留入口 + 数据面（pub 55→29 行） | `emit.mbt`（模板 priv 化）；`pkg.generated.mbti` |
| R-09 | 役26 | ADR-26 | 0 warning（全模块 30 条清零）；死字段先改表源再生 | `n3v2_base.toml`；`moon check` |
| R-10 | 役27a/28 | ADR-27·28 | `prefix_version/base_version/iri_version`；`fr→frame`；`Hooks→N3ActionsImpl` | `types.mbt`；`actions.mbt`；trig 同笔 |
| R-11 | 役27a | ADR-27 | 27 test 迁 `materialize_n3_wbtest.mbt` / `serialize_n3_wbtest.mbt`，生产件纯实现 | 两新件；`grep '^test '` = 0 |
| R-12 | 役26 | ADR-26 | `ARCHITECTURE.md` 一页 + guides 实名化 + 役21 跨卷注记 | `ARCHITECTURE.md`；`src/ttl/guides/n3/*` |
| R-13 | 役28 | ADR-28 | 组清方法：`clear_annotation`（四件套）/ `clear_path`（三槽）；keywords/directive 不立项 | `engine.mbt` ctx 方法区；`actions.mbt` |
| R-14 | 役30 | ADR-30 | 交叉族全部改为**子机声明 + 构建期求积**；G10 装配门；声明面 schema 见 `spec.md` §10.6 | `compose.mbt:161`；`validate.mbt:687`；`n3v2_base.toml` |
| R-15 | 役29 | ADR-29 | 识别件单点 `gen_nquads/numeric.mbt`（八消费点三面收编；展开件留各物化层） | `numeric.mbt`；`rg "has_digit" src` 单点 |
| （口径对齐，非 R） | — | **ADR-32** | **RDF 1.2 单开关**：`scalar_only_escapes → rdf12`（构造默认 `true`=1.2，对齐 nquads）；一个开关门控转义代理 + 方向后缀 `--ltr/--rtl`（1.1 显式拒） | `materialize_n3.mbt:30/47/1230`；`rdf_suite_wbtest.mbt:101`（rdf11 显式 `false`）；钉子 `materialize_n3_wbtest.mbt`（双向） |

### 4.2 存活项上下文（[立案]，完整七字段）

#### R-04（长期半）方言感知词法器 `[立案]`

- 目标：词法边界欠账不再"一次改动四处同步"——adapter 退回纯分类，方言差异收进词法器本身。
- 锚点：`gen_nquads/lexer_mbt.mbt`（Moon 词法器）+ `lexerc_ffi.c`（C 词法器，**必须同步**）；
  `lexer_adapter.mbt`（①`[]` 合并 ②`?x` peek ③`@kw:` 拆字 ④`<-` 拆字 ⑤langtag 拆字）；
  `engine.mbt:84`（尾标点三瓣 + 合成事件回灌）。
- 现状证据：役29 只做了**补偿点台账**（头注六点地图 + 钉面清单），五点仍在 adapter 内就地手术；
  ADR-18 的 `^` 门事故即"一次词法口径变动牵动 Moon/C/适配/引擎"的实证。
- 动作：给共享 `Lexermoon` 加方言参数（消费方言能力表）→ 五点并入词法扫描 → adapter 退化为分类器 →
  `normalize_term_span` 相应瘦身 → parity 电池扩到分歧形态。**先盘依赖面再开役**（三包共享）。
- 验收：`lexerc_parity_wbtest` 零差（当前对比 72 段 mismatch=0，扩展后仍 0）；nquads 124、
  trig 357/316/36/75、n3v2 116 全不变；C 侧与 Moon 侧逐点镜像（同笔提交）。
- 风险：共享词法一动影响 nquads / trig / n3v2 三包 + 冻结的 C 电池；C 侧 2026-09-04 分歧口径
  已冻结，**分歧形态不得进电池**。
- 依赖：R-15 ✅（识别件已单点）。

#### R-16 影子缺口修口 `[立案]`（C-16 + C-17）

- 目标：把影子扫描暴露的**真校验缺口**修掉，使校验层能进主判定链（`lenient=true` 旁路可撤）。
- 锚点：`parser_slice.mbt:63`（`prefix_declared`）、`:263`（`validate_term`）、`:364`（`validate_prefname`）；
  影子面 `rdf_suite_wbtest.mbt:118`、`n3tests_suite_wbtest.mbt`（skip 名单）、`examples_wbtest.mbt`。
- 现状证据（strict-gap 基线 **5 / 0 / 123 / 13**，役25 冻结）：
  ① C-16 主因 **486 处**——N3/cwm 内建前缀（`log:` / `string:` + 隐式空前缀）不声明即用，
  官方正例 `extra/good_prefix.n3` 也翻；② C-17 次因 **2 处**——`<=`（`=>` 同构）作为 raw 谓词
  被 `validate_pred` 以 "IRI must be wrapped in <>" 拒绝，与 ADR-005"操作符 = 谓词身份"冲突。
- 动作：① 内建前缀表**预绑定**（或校验层按方言豁免：n3/cwm 方言下 `log:`/`string:` 视为已声明，
  空前缀按 sP 语义处理）；② `<=` / `=>` 进 `validate_pred` 白名单（判据 = ADR-005）；③ 影子钉
  逐项翻 0 后，把校验层从影子面升格进主判定链。
- 验收：strict-gap **5/0/123/13 → 0/0/0/0**；nquads 124、trig 357/316/36/75、n3v2 116 不变；
  `good_prefix.n3` 从 STRICT-GAP 名单移出；影子扫描与主判定的判定差 = 0（可加对拍钉固化）。
- 风险：豁免过宽会掩掉真错误（未声明前缀拼错）；⚠ 每加一条豁免都要有反例钉（拼错前缀仍必须拒）。
- 依赖：R-07 ✅（双判 + 绝对计数钉已就位，缺口可量化）。

---

## 5. 影响面与原子性

| 变更 | 是原子的 | 跨包 / 跨仓清单 |
|---|---|---|
| 改表（`n3v2_*.toml`） | 是 | 表 → `moon test src/rdf/n3gen`（G9 落 `n3v2_out.gen`）→ `cp` 交付 `n3.mbt` → 本包测试 |
| 改生成器（`emit.mbt` / `compose.mbt` / `validate.mbt`） | 是 | 生成器 + G9 对拍翻新 + G10/G11/G12/G13 门 + 产物再生 |
| 加 TOML 键（如 `terminal_states`、`state_entries`） | 是 | 新键**必须可选**、未知键忽略、缺省不报错（AGENTS「TOML 是持久契约」） |
| 重命名跨包结构（如 `QuadSpan` 字段、`LoopPolicy→Supervisor`） | 是 | 本包 + `gen_trig` 同名结构 + 测试 + `.mbti` 同笔 |
| 动共享词法 / 公共依赖（R-04 长期、R-15 类） | 是 | `gen_nquads`（Moon + C）+ `gen_trig` + `gen_n3v2` 三包 + parity 电池 |

⚠ 通用纪律：`n3.mbt` 手改必被 G9 判红；`.mbti` diff 逐行审；`moon fmt` 放最后；
**探针后必须还原并用 md5 复核产物零漂移**。

---

## 6. 裁断表（题1 … 题11；**当前无待裁**）

| 题 | 问题 | 裁断 | 出处 |
|---|---|---|---|
| 题1 | R-02 形态：A 全控 / B 观察者 / C 双实现 | **A**（`interpret` 唯一解释器） | ADR-22 |
| 题2 | 扩展维可见性：`pub` / 包内 | **B**（包内；零外部消费者） | ADR-28 |
| 题3 | R-01 状态改写承载：表行 / 改签名 / 保留例外 | **机制收敛 + 登记**（A/B 均不可行） | ADR-24 |
| 题4 | R-05 错误形态：累积 / 流式 / 单错 | **A**（API 不变 + 累积） | ADR-25 |
| 题5 | R-13 分组是否连带改表 schema | **A**（组清方法，表平铺；B 留账） | ADR-28 |
| 题6 | R-07 双判成本 | **A**（严格 + 影子双跑） | ADR-23 |
| 题7 | R-14 选型：A 生成器组合 / B 混合架构 / C 只加门 | **A**（B 三条硬理由否决；C 吸收为 G10） | ADR-30 |
| 题8 | 探针族取 `Quant` / `Annot` | **`Quant`**（`quant` 机器 4 段 + 两实例） | ADR-30 |
| 题9 | 等价判据是否只取"产物字节等价" | **是**（G9 逐字节） | ADR-30 |
| 题10 | 可达性门是否常设 | **是**（→ 役31 三源 + 分级 + G13） | ADR-31 |
| 题11 | 锚点登记落表源 / `spec.md` 清单 | **表源**（`[[state_entries]]`，门可直接消费） | ADR-31 |

---

## 7. 动手前 / 动手后 检查清单

动手前：

- [ ] 确认改的是嵌套仓（`src/ttl`）还是外层仓（`src/rdf/n3gen`）——**两仓分开提交**。
- [ ] 读 `spec.md` §5 机械约束（guard 只通 ctx / EOF 不进表 / ctx 新字段守门）与 §12 可达性判据。
- [ ] 跑基线命令并记录数字（§1 表）。
- [ ] 涉及 `n3.mbt` → 先写清表源改法（禁手编，走 G9 再生）。
- [ ] 涉及契约成员（② / ③）→ 先看 §2 切点表与切面纪律。
- [ ] 涉及 git 操作 → 按 `AGENTS.md`「商量制」：先说明 + 命令草案，等指令再执行。

动手后：

- [ ] 若动表/生成器：`moon test src/rdf/n3gen` 绿 + `cp` 交付 + `moon fmt` 幂等。
- [ ] `cd src/ttl && moon check src/gen_n3v2` → **0 warning**。
- [ ] `cd src/ttl && moon test src/gen_n3v2` → 116/116 且套件四项（316/75/357/36）不变；模块 329/329。
- [ ] `moon info` 审 `.mbti` diff（重命名 / 收面 / 加字段都在这露出）。
- [ ] 探针复原 + 产物 md5 复核；门与表格同步（G10/G11/G13 类改动附探针证据）。
- [ ] 回写 `spec.md` §7/§8 状态；语义变更写 `adr.md`；本卷刷新失效锚点；`todo.md` §6 追加一行。

---

## 8. 锚点索引（2026-09-12 实测）

| 主题 | 锚点 |
|---|---|
| 契约成员声明 | `n3.mbt:282`（Supervisor/trait 名 `N3LoopPolicy`）、`:299`（Actions）、`:2044`（EffectHandler） |
| 效果解释器 | `n3.mbt:2128`（impl `interpret`）、`:2108`（`apply_scope`）、`:2100`（`N3EffectOutcome`）；`emit.mbt:1085`（套装生成） |
| ctx 基座 | `n3.mbt:148`（struct）、`:216`（reset）、`:264`（snapshot）；`engine.mbt:517`（take_pending） |
| 主循环 | `engine.mbt:577`（`next`）、`:336`（under_formula）、`:388`（consume_to_recover_point） |
| Supervisor 四钩子 | `engine.mbt:350` / `:366` / `:423` / `:454`；模板 `emit.mbt:660` |
| 归位点 | `engine.mbt:84`（trim_trailing_punct）、`:136`（kw_ledger_hits）、`:171`（is_deprecated_this）、`:192`（normalize_term_span） |
| 状态直写三处 | `actions.mbt:172`、`:529`、`:719`（全入册 `spec.md` §5.1-A） |
| 路径机器 | `actions.mbt:370`（path_hop_resolve）、`:563`（path_tail_hop_resolve）、`:938`（path_obj_close） |
| 集合 / 帧 | `actions.mbt:137`（pop_bnode_prop）、`:990`（list_top）、`:1002`（list_first） |
| 倒装 / 等同 / 注解 | `actions.mbt:1115`（is_of）、`:1128`（set_inversion）、`:1142`（set_sameas）、`:1155` 起（annot_*） |
| 组装 / 校验 | `parser_slice.mbt:431`（assemble）、`:263`（validate_term）、`:364`（validate_prefname）、`:63`（prefix_declared）、`:52`（drain_engine_errors） |
| 物化门 | `materialize_n3.mbt:683`（materialize_quad）、`:1008`（materialize_all）、`:1107` 起（gate_iri 等四门） |
| 生成链 | `compose.mbt:161`（n3gen_compose）、`emit.mbt:1273`（n3gen_build）、`validate.mbt:687`（G10 装配门）、`:567`（G11 可达性）、`:489`（可达性报告纯函数）、`:558`（`n3_g11_strict`） |
| 生成门测试 | `src/rdf/n3gen/n3gen_test.mbt:31`（G1）→ `:209`（G9）→ `:234`（G12）→ `:284`（G13） |
| 套件 runner | `rdf_suite_wbtest.mbt:116/118`、`n3tests_suite_wbtest.mbt:50`、`examples_wbtest.mbt:9` |

---

## 9. 工程经验（役间沉淀，动手前先翻）

**再生与格式化**

- 生成器输出必须 fmt-clean：`moon fmt` 后 G9 仍逐字节一致才算达标。已知 fmt 形态：单语句 match 臂折花括号、
  `assert_eq` 80 列内折叠、fn 签名超宽折叠、`new()` 展开内建——新输出非规范形 = **改模板**，禁事后 fmt 生成件。
- 再生一条链（外层仓根）：`moon test src/rdf/n3gen`（G9 红 = 表领先）→
  `cp src/rdf/n3gen/n3v2_out.gen src/ttl/src/gen_n3v2/n3.mbt` → 复测绿。
- `moon info | head` 会 SIGPIPE 杀半程导致 `.mbti` 半新半旧——**不要接 `head`**；pipeline 退出码会说谎，
  判定一律看 `grep "Error"/"failed"/"Total tests"`。

**生成器手术（`emit.mbt` / `validate.mbt` 类）**

- 两种形态：`$|` 字面量行 = verbatim 套装体（按行替换，锚下一臂首行）；字符串字面量（带转义）= struct/new/reset
  生成段（python 侧 old 串写反斜杠 n）。
- **门的调用点必须在数据可见的阶段**：G10 放 `validate` 会因标记行已被 compose 消费而"全死"误报，
  正确位置是 `n3gen_build` 内 compose **之前**（役30e 现场纠正）。
- **探针锚点必须可证伪**：G8 负例原锚指向 `trans` 里的 ListPath 行，迁移后锚点失配 ⇒ replace 静默变 no-op
  ⇒ 门假绿（役30d）；修法 = `n3_neg_patch(base, trans, old, new)` 两文件都试、命中即改。
- 探针流程：**先备份 → 跑 → 立刻还原 → md5 复核产物零漂移**（G9 会先写 `.gen` 再比对）。

**判定"能不能上表"**

- 先查**事件分类学**：表消费的是已分类事件；凡改判事件种类（`KeywordA→PrefName`、`Unknown→KeywordX`）
  或切分事件（一词两事件）的机制天然在表**上游**，登记不上表（§5.1-B/C）。
- 表行 guard 只能拒绝（else = UnexpectedEvent），**不能改派、不能 fallback 下一行**——同 `(from,on)` 双链形
  异判（`path_subj_end`）表内无解，唯有 action 运行时判。
- 宽度侦察的字面清单（"3 处直写"）要先问每处**判别数据源是否表内可得**，再定迁移方案；
  否则验收口径（"grep 为空"）本身不可达（役23）。

**测试与钉构造**

- 点名跑：`moon test src/gen_n3v2 -f "*役N*"`（`-p` 包参数与 file-filter 混用会报错）。
- 坏句测试输入必须自带 Dot——`recover` 跳读会吃掉 Dot 前一切（役24 钉红 1!=2 的根因）。
- 造路径类错误先查表可达三件事：态族（主语位 / 宾语位链）、词法合并（`[]` 并成单 BlankNode）、
  span 回填（无载荷事件 span=(0,0)）。
- 物化断言禁 `view.to_string()`（出 `[b'\x3C', …]` 调试形）——用 `view_str(v, (0, v.length()))`；
  词表 IRI 含尖括号，判尾用 `has_suffix("#nil>")`。
- 业务错触发点之前合法路径跳已发四元组——钉 `quads` 数要含它们，别按 1 断。

**清账 / 改名 / 归位**

- `moon.pkg` unused_package 的行号锚 ≠ 直觉——先 `cat` 对准再删（役26 错杀回补一次）。
- 同一 trait 对同一类型的多个 `impl` 块，约束必须一致（只改一块报 Inconsistent impl [4135]）。
- 死字段裁决先 `grep 字段名 表源`：`iri_upcast` 被 `n3v2_trans.toml` expr 消费 = **活机制**，
  台账原按"声明未读"误列死位。
- `grep -c` 数行不数处（`\bfr\b` 55 行实为 71 处）——原子断言以匹配总数计。
- 复用前先对语义：`mat_vs`=decode_lossy、`view_str`=逐字节 `to_char`，名异实异；盲替会烂掉多字节断言。
- 跨文件同名消费先盘再迁（`mat_*` 不止一个文件用）——迁移脚本必须同笔扫全包，漏一处即编译错。
- 侦察"全表唯一 X"要含用户层动态构造（役22：表内唯一 `Sequence` ≠ 全系统单发，`path_obj_close` 三发在
  `actions.mbt`）。
- 全仓 `moon test` 触发生成器自写盘（quick_machine / fsm / mdlex 产物）——提交前盘点 `git status`，
  非本役面的改动单独说明。
