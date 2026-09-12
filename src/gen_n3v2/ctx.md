# gen_n3v2 整改上下文（ctx）

版本：2026-09-11 立卷（与 `spec.md` v1.0.0 同批）

**这份文件是什么**：整改项的**工作上下文**——每一项要动手时需要的全部上下文（目标、锚点、
现状证据、动作步骤、验收口径、风险、依赖、状态），外加术语注解、待裁选择题、影响面与检查清单。
结论与台账在 `spec.md`（C 台账 = 冲突写实，R 台账 = 整改裁决）；历史原因在 `adr.md`。

**怎么用**：接到某个 R 项 → 先读本文件对应小节 → 按"锚点"定位 → 按"动作"改 → 按"验收"跑命令 →
回 `spec.md` 的 R 台账更新状态。跨项改动（如 R-02 先于 R-01）按 `spec.md` §8 的依赖序。

**注解约定**：`锚点` 一律 `文件:行`（行号为 2026-09-11 实测）；`[定案]` = 用户已裁；
`[建议]` = 待裁；`[立案]` = 需另役；`⚠` = 易踩的坑。

---

## 1. 坐标与基线

仓界（改代码前先确认落到哪个仓，提交要分开）：

```
外层仓 /home/thy/moonttl            （生成器 + 表源 + 契约）
├── src/rdf/n3gen/                  n3v2_base.toml + n3v2_trans.toml → emit → n3v2_out.gen
│   └── n3gen_test.mbt              G1–G9 门（G9 = 黄金门 + 强幂等）
└── src/ttl/                        （嵌套仓，独立 .git；下游包）
    └── src/gen_n3v2/
        ├── n3.mbt                  ⚠ 生成物，禁手编；改它 = 改表 + 再生
        ├── engine.mbt / actions.mbt / lexer_adapter.mbt / parser_slice.mbt / materialize_n3.mbt
        └── spec.md / ctx.md / adr.md / todo.md
```

基线（2026-09-11 实测，整改前后都要对得上）：

| 命令 | 当前值 | 目标 |
|---|---|---|
| `cd src/ttl && moon check src/gen_n3v2` | 0 error / **11 warning** | 0 / 0（R-09） |
| `cd src/ttl && moon test src/gen_n3v2` | **111/111** | ≥111（只增不减） |
| `cd /home/thy/moonttl && moon test src/rdf/n3gen` | 9/9（G9 对拍绿） | 保持绿 |
| rdf-turtle / rdf12-turtle | 316/316 / 75/75 | 保持 pin |
| N3Tests | neg 23ok/0miss，pos+eval 205clean/0mat/0parse | 保持 |
| examples | 13 文件 A-full（print-only） | R-07 后加钉 |

现状提示（与整改无关但需知情）：外层仓 `src/fsm/codegen.mbt`、`src/fsm/prune.mbt` 有未提交改动
（役21 收尾，13 行）；嵌套仓 `todo.md`、`ctx.md` 为新文件（未跟踪）。

---

## 2. 三个业务面契约（注解版）

生成侧事实：三个 trait 全部由 `src/rdf/n3gen/emit.mbt` 发射，`n3.mbt` 是产物。

### 业务面 ① `N3Actions`（语义落点）

- 生成锚点：`n3.mbt:301`（48 个方法声明，签名统一 `Result[N3Effect, N3ActionError]`）。
- 实现锚点：`actions.mbt`（`impl N3Actions for Hooks with fn ...`，48 个）。
- 契约：只写槽位/账本，返回意图；**永不重置 ctx**；拿不到数据视图（只有 span）。
- 注解：48 个方法是 trait 而非普通函数，是生成模板的形态选择（"trait 当命名空间"）；
  R-10 建议把载体 `Hooks` 改名 `N3ActionsImpl`，是否去 trait 化另裁。

### 业务面 ② `N3EffectHandler`（架构维度扩展位）[定案 2026-09-11]

- 生成锚点：`n3.mbt:2045`（trait）；套装 verbatim 固化在 `emit.mbt:1083`（`n3_emit_handler_suite`）。
- 成员：`handle_continue/handle_emit_quad/handle_reset/handle_done/handle_sequence/handle_pop_bnp/handle_open_slot`、
  `snapshot`、`apply_scope`、`on_exit_graph`、`on_pop_bnp`、`on_open_slot`、`interpret`、`dispatch`；
  配套 `N3EffectOutcome{KeepGoing,YieldQuad,Stop}`（`n3.mbt:2117`）与 `N3EffectError`（`n3.mbt:2036`）。
- 用户定案：**保留为扩展维**（效果面切面挂点），形态**可简化**，不得删除。
- 现状：包内零引用；`interpret`（`n3.mbt:2168`）与 `engine.next`（`engine.mbt:533`）是两套效果语义；
  `apply_scope`（`n3.mbt:2144`）与 `N3Context::reset`（`n3.mbt:218`）逻辑重复。
- 注解（R-02 的具体设计）：
  - 目标形态：`interpret` = 唯一解释器；`engine.next` 只做"取事件 → step → interpret → 上抛"。
  - `handle_continue`（恒 `Ok(())`）与 `handle_done` 属纯样板，建议并入默认/删除；
    `handle_emit_quad`/`handle_reset`/`handle_sequence`/`handle_pop_bnp`/`handle_open_slot` 保留 = 真实挂点。
  - `snapshot`/`apply_scope` 归位：`N3Context::snapshot`（`n3.mbt:266`）/`N3Context::reset`（`n3.mbt:218`）已存在，
    EffectHandler 侧改为**调用**而非再实现。
  - `take_pending_quad`（`engine.mbt:495`：倒装交换 + 注解壳交换 + 按 scope 重置）是引擎私有语义，
    若 `interpret` 要发 quad，必须把它下沉为 `N3Context` 级函数（如 `N3Context::take_pending(scope)`），
    否则 EffectHandler 发不出与现状一致的 quad。⚠ 这是 R-02 的真正难点，不是接口对齐。
  - 简化后仍需 emit 侧"接活钉"：`emit.mbt:1083` + engine 一处调用点，否则下次再生又会回到双实现。

### 业务面 ③ `N3LoopPolicy`（第三条业务面 = 控制流切面）[定案 2026-09-11]

- 生成锚点：`n3.mbt:284`（4 钩子）；实现锚点：`engine.mbt:345/364/416/447`；
  模板注释在 `emit.mbt:657`（"领域知识全部收敛到本 trait"）。
- 契约：循环骨架固定（入口/终止 → step → Effect 分发 → 错误降级），领域知识全在 4 钩子。
- 用户定案：将来承载 **Test & Fallback（容灾）** 与 **Observability（可观测）** 切面。
- 注解（切面设计草图，实施时按此展开）：

```
LoopPolicy（控制流面）
  begin_record()      → 会话起点：计数器/trace_id 注入、测试夹具初始化
  recover(span)       → 容灾决策点：现行 = 记录错误 + 清栈 + skip-to-Dot + 归位 ExpectSubject
                        （机械在 engine.mbt:381 consume_to_recover_point）；切面可在此做分类/降级
  finish_at_end()     → 脏尾兜底：现行 = 判脏 + 自排水（报告一次即归零，防无限重报）
                        ⚠ 切面接管时不得破坏自排水，否则 parse_all 死循环
  on_business_failed(m) → 失败映射：现行 = ParseError::SyntaxErr(msg, ctx_span(ctx))

EffectHandler（效果面）
  EmitQuad 点   → 观测：quad 计数/span 范围；容灾：丢弃/改写/降级为注释
  Reset/PopBnp/OpenSlot → 帧审计：栈深、帧身份
  步级 trace (state,event,effect) → 现状无钩子，需新增（挂 ② 或 ③）
```

- 切面纪律（建议写进 R-02/R-03 的验收）：默认实现 = 现行行为；切面**零语义副作用**且可开关；
  开/关两态下套件数字必须一致（否则切面改变了语言判据）。

---

## 3. 术语表（注解）

| 词 | 含义（本包语境） |
|---|---|
| 役N | 一次迭代/战役编号（写在 `adr.md`，如役18/20） |
| ADR-00X | 语义裁决编号（ADR-002 公式 / 003a 集合 / 003b 显式链预留 / 004 变量 / 005 规则与等同 / 006 路径） |
| 业务面 | 生成契约暴露给用户的实现面，本包三个：Actions / EffectHandler / LoopPolicy |
| 扩展维 | 预留但不常改的切面挂点（本包 = EffectHandler 的效果面 + LoopPolicy 的控制流面） |
| 罩 | 公式帧在栈上；"罩内" = `under_formula(ctx)`（`engine.mbt:331`）为真 |
| 胶 | 词法吞边界导致相邻标点粘进词项 span（`"x"@en,` 的 `,`） |
| 归位点 | 事件进表之前的引擎预处理点（`normalize_term_span`，`engine.mbt:190`） |
| 账 | ctx 上的记账数组/字段（`prefixes`/`bases`/`kw_ledger`/`is_src`/壳账四字段） |
| 门 | 校验点：生成器门 G1–G9（外层仓）与物化四门（`gate_iri` 等） |
| 钉 | 断言式测试（数字被写死，漂移即红） |
| 死位 / 预留位 | 有意保留但当前不生效的口径（ADR-003b 的 `RDFFirst/RDFRest` + `iver`；`graph` 恒 `None`） |
| 桶 | 套件分类记账（neg/pos/eval、deferred/mat-only 等） |
| 自排水 | `finish_at_end` 报告一次即清零，防 `parse_all` 无限重报（`engine.mbt:416`） |

---

## 4. 整改项上下文（R-01 … R-15）

### R-01 状态权威回归表 `[✅ 定案·役23]`（翻案：机制收敛，见 §6 题 3）

- 目标：~~I-6 恢复成立~~ → **修正**：运行时数据依赖（帧/链形）出表模型是 FSM 边界本质；
  达成口径 = 破例恒可数、每条有"为何"（spec §5.1 清单）。
- 锚点：`actions.mbt:171`（pop 兑现 [R-03-1]）、`actions.mbt:528`（path_end_nested [R-03-2]）、
  `actions.mbt:718`（path_subj_end [R-03-3]）。
- 结果（役23）：id 特例前移 set_id_subject 刻帧（`fr.ret_state = N3BnpIdAfterClose`，
  `mut ret_state` 役14 path_obj_close 先例），pop 无条件读帧——3 处条件分叉 → 1 机制位
  + 2 登记破例。**SetState 不立项**：2/3 号链形异判（guard else 不 fallback + 两链形
  SubjTrailAfterStep 汇合）、Err 短路无效果通道、pop 经 interpret PopBnp 臂返 Unit——
  三处零可行实例。
- 验收（改口径）：`grep -c "ctx.state = " actions.mbt` = 3 且全带 [R-03-N] 锚；111/111；
  四套件数字不变。原"grep 为空"不可达。

### R-02 接活效果面 ② `[定案]`（简化形态待裁，见 §6 题 1）

- 目标：② 面成为真实切点（观测/容灾可挂），且效果语义只有一份。
- 锚点：`engine.mbt:533`（`next`）、`n3.mbt:2168`（`interpret`）、`n3.mbt:2209`（`dispatch`）、
  `n3.mbt:2144`（`apply_scope`）、`n3.mbt:218`（`ctx.reset`）、`engine.mbt:495`（`take_pending_quad`）、
  `emit.mbt:1083`（套装生成）。
- 现状证据：包内 `N3EffectHandler` 零引用；两套解释器；`apply_scope` 与 `ctx.reset` 重复。
- 动作：见 §2 ② 的注释（解释器唯一化 / handle_* 精简 / snapshot+apply_scope 归位 / `take_pending` 下沉 /
  emit 接活钉）。
- 验收：`rg "N3EffectHandler" src/ttl/src/gen_n3v2` 至少出现"impl + 调用点"；emits 计数在切面上可见；
  111/111 + 套件四项不变；`n3gen` G9 绿（说明 emit 与产物一致）。
- 风险：`take_pending_quad` 的倒装/壳交换语义一旦搬错，会静默产生错主语（役8/役18 踩过）。
  ⚠ 迁移后必须跑 `engine_wbtest` 的倒装/注解钉（役6/役8 家族）与套件。
- 依赖：无（最先做）；是 R-01/R-03 的前置。

### R-03 引擎归位点台账化 `[✅ 定案·役23]`

- 目标：把"引擎里做词法/语法改名"收缩成显式、可数、有理由的清单。
- 结果（役23）：清单落 **spec §5.1**（A 直写 3 条 [R-03-1/2/3] + B 引擎归位 4 条
  [R-03-4~7] + C 关键词真相裁决）。~~能上表的改表行承载~~ 翻案：`this` 门/
  `KeywordA` 降级系**事件重分类**（表上游，改判事件种类出表模型），登记不上表。
  ~~关键词收敛一份数据~~ 写实修正：三处**正交非冗余**（`classify_prefname` 静态保留词
  ∥ `kw_ledger` 动态台账唯一源 ∥ 表行消费）；原 `bool_at` 系误诊（布尔字面量，
  C-15 家族）已从 C-03 除名。
- 验收：清单条目只减不增；每条有"为何表内表达不了"；引擎零代码改动（纯裁决收口）；
  111/111 + `bad-*-05` 类负例仍拒（N3Tests neg 23ok/0miss 实证）。
- 依赖：R-02 ✅。

### R-04 词法收口 / 补偿点台账化 `[✅ 短期定案·役29]`（长期 `[立案]`）

- 目标：词法边界欠账不再"一次改动四处同步"。
- 锚点：`lexer_adapter.mbt`（`next` 内的 `[]` 合并 / `?x` peek / `@kw:` 拆字 / `<-` 拆字）、
  `engine.mbt:84`（尾标点三瓣 + 合成事件回灌）、`@nquads.is_numeric_span`（R-15 单点）。
- 现状证据：ADR-18 的 `^` 门事故（`"lit"^:prop` 整段胶进字面量）——一次词法口径变动牵连 Moon/C/适配/引擎。
- 动作：长期 = 方言感知词法器（共享 `Lexermoon` 加方言参数），adapter 退回纯分类；短期 =
  **补偿点单点台账（役29 落地）**：`lexer_adapter.mbt` 头注六点地图（①[] ANON merge ②?x
  peek-merge ③@kw: 拆分 ④<- 拆字 ⑤langtag 拆分 ⑥engine 尾标点三瓣）+ 钉面清单
  （n3_wbtest ①–⑤ / engine_wbtest Comma·Semicolon 合成件 ⑥ / lexerc_parity 电池）；
  engine `normalize_term_span` 交叉引用回指台账。**不移 trim**（engine 七臂与 kw_a_live/
  version_lit_ok 旗标交织，移动无益于欠账本体）；**不动 Lexermoon/C**（C 侧 2026-09-04
  分歧口径已冻结，parity 电池不含分歧形态）。
- 验收：`lexerc_parity_wbtest` 零差（对比 72 段 mismatch=0）；套件不变（329/329）。
- 风险：动共享词法 = 影响 nquads/trig 两包。本役零 Lexermoon 接触，风险不兑现。
- 依赖：无（短期已清；长期方言感知词法器另役立案）。

### R-05 错误累积 + 失败复位 `[✅ 定案·役24]`（ADR-25）

- 落地：`last_error : Span?` 单槽 → `error_spans : Array[Span]` 累积（`record_error` push）。
  **recover 拆两层**：`recover` = 记录 + 清理；`recover_cleanup` = 清栈/账（slot_stack、pred_kind、
  is_src、annot_s/o、subj_shell、annot_close）+ `consume_to_recover_point`。`BusinessFailed` 臂 =
  产出 ParseError → `recover_cleanup` → `return Some(Err(...))`——引擎已复位，后续语句照常解析。
- drain 三点（`parser_slice.mbt` `drain_engine_errors`）：`parse_next` 入口 / `Some(Err)` 分支
  （跨类文件序：BusinessFailed 先于先前 Structure 错被 parse_all 返回）/ `None` 终态清尾。
  统一转 `StructSyntaxErr("Structure error", line_before(span.0), span)`。
- `finish_at_end` 自排水语义保持（报一次即归零），累积不重复报。
- 钉：`engine_wbtest.mbt` 三钉——两坏句两错序（`", .\n, .\n"`，s=(1,0)/(5,0)）、业务错复位续解
  （`^<q>[...]` 触发 Reverse path，quads==2 含合法路径跳四元组）、混合错误类序（Structure/业务/Structure）。
- API 不变（§6 题4 = A 落地）：`parse_all` 仍返 `(Array[QuadSpan], Array[ParseError])`，
  mbti 面仅 `N3Engine` 字段改名（`last_error` → `error_spans`）。

### R-06 nil 标记显式化 `[✅ 定案·役24]`（ADR-25）

- 裁决：**带内通道保留**（零长 span = nil 标记）——题4 = A（API 硬约束）下带外载体（`nil_marker`
  字段/SlotType 变体）= API 变更，不取；缺口已登记（data[0]=='(' 时意外 (0,0) span 误判为 nil，
  根修需带外）。
- 落地 = **物化层验形门**：`materialize_quad` 入口双门 `len == 0 && data[offset] != b'('`
  → `ValidationErr("Zero-length ... span is not a valid nil marker")`（主/宾语位各一）。
  零长 span 从"静默 nil 语义"变"显式验形"——非法构造报错，合法构造（唯一构造点
  `pop_bnode_prop`，offset 恒指 `(`）照常出 `rdf:nil`。
- 钉：`engine_wbtest.mbt` 两钉——手工造 `s:(2,0)` 于 `"<a> <b> <c> ."` 报 ValidationErr；
  `"( ) ."` 全链出 `rdf-syntax-ns#nil>`（用 `view_str(...).has_suffix(...)`，词表 IRI 含尖括号）。

### R-07 证据面补齐 `[建议]`

- 目标：最强证据覆盖校验层；文件清单漂移可报警。
- 锚点：`rdf_suite_wbtest.mbt:114`、`n3tests_suite_wbtest.mbt:40`、`examples_wbtest.mbt:16`（三处 `lenient=true`）；
  `rdf_suite_wbtest.mbt:148-149`（pin 两项）；`n3tests_suite_wbtest.mbt:89-93`（四个断言，无桶闭合）；
  `examples_wbtest.mbt:9`（print-only）。
- 动作：① 三 runner 双判（严格判定 + 宽容扫描）；② N3Tests 加 `pos_ok` 与 skip 名单钉、examples 加桶闭合钉
  （`passed+failed+deferred == files.length()`）。
- 验收：故意往 `rdf-tests` 目录加一个文件，测试应红；去掉后绿。
- 风险：严格判定可能暴露真实校验缺口（`validate_prefname` 首字符/尾点/转义集）——⚠ 先跑一遍看红点，
  再把真缺口立项（不要为了绿而回退 `lenient`）。
- 依赖：无。

### R-08 公共面收窄 `[✅ 定案·役28]`（§6 题 2 = B）

- 目标：内部机械不再是公共 API；扩展维可见性按策略定。
- 锚点：`pkg.generated.mbti`（38 个 `pub` 项，含 `N3Context` 29 字段与三个 trait）。
- 动作：逐个判定公开性；白盒测试同包可见，不受影响（⚠ 黑盒 `_test.mbt` 只能看 `pub`，
  若将来要写黑盒测试需先补 `pub fn` 入口）。
- 验收：`moon info` 后 `.mbti` 行数显著下降且不含 FSM 内部类型；`moon test` 全绿。
- 风险：若计划做"第三方挂切面"，扩展维必须保留 `pub`；两者冲突，先裁 §6 题 2。
- 依赖：R-02/R-13（先把内部形态定下来再收面，否则收完还要再改）。
- **定案（役28，ADR-28）**：题2 = **B**。裁据：全仓零外部消费者（唯一导入者 = n3gen 金门测试，
  且零用 `@gen_n3v2` 项）；扩展面外部本不可达（`from_bytes` 内建 actions，无公共构造子收自定义
  实现）——"扩展维"是名义面，保 `pub` = 投机面（役23 SetState 同判据）。将来若开外部切面，
  加 `N3Engine::with_actions` 纯增量、一次抖动。落地：生成件 `priv` 化（emit.mbt 模板 → G9 再生
  → cp）；用户层 `N3ActionsImpl`/Slot 族/slice_span 手降；Engine/LexerAdapter 字段级 `priv`；
  顺带删零消费死码 IRIUpcastEvent、SlotNodeId、`Show for N3Event`、`EffectHandler::snapshot` 死套。
  数据面保留：QuadSpan/N3PendingQuad/PredKind/N3Event（LexerSource 契约载荷）/N3Dialect/LexerSource/ErrOut。

### R-09 清账 `[✅ 定案·役26]`

- 结果：`moon check` **0 warning**。账比下表漂移——实清扫 **30 条全模块**（非仅本包）：17
  unused_package（gen_n3v2/gen_trig `bench`、cmd `debug`、examples 两包各 7 条）/ 3
  unused_trait_bound（本包 `on_pop_bnp`/`on_open_slot` 双 impl 块 `impl[L]` 去界——**同 trait 双
  impl 块约束必须一致**；trig `settle_shell`/`settle_annotation` `fn[L]`）/ 6 deprecated
  （`starts_with`→`has_prefix`×4、StringView `to_string`→`to_owned`、`self.interpret`→
  `N3EffectHandler::interpret` 限定调用）/ 4 unused_value（`mat_graph`/`mat_has_graph` 删——graph
  恒 None 无消费者、`n3_suite_verdict` 去 `name` 参、`serialize` 未用 self→`_self`）。
- 死字段：`variable_name`/`rule_side` 真死（仅声明+reset 初始化，零消费者）——**表源删两行 → 再生 →
  cp**（G9 路）；`RuleSide` 枚举连坐删（types.mbt）；**`iri_upcast` 活机制正名**（n3v2_trans expr
  + `iver` 快照消费，非死位，下表误列）。

| 警告 | 锚点 | 处置 |
|---|---|---|
| unused_trait_bound ×2 | `engine.mbt:467`、`engine.mbt:481` | 去掉多余 `[L : LexerSource]` |
| unused_value ×4 | `materialize_n3.mbt:1605`（`mat_graph`）、`:1615`（`mat_has_graph`）、`serialize_n3.mbt:84`（未用 `self`） | 删/改签名（后者随 R-11 归位） |
| unused_package | `moon.pkg:11`（`moonbitlang/core/bench`） | 删导入（确认无 bench 代码后） |
| deprecated ×4 | `materialize_n3.mbt:1678/1691/1753/1754`（`starts_with`） | 改 `has_prefix` |
| 死字段 | `n3.mbt:161`（`variable_name`）、`:166`（`rule_side`）、`:167`（`iri_upcast`） | 删，或在 `spec.md` 建"预留位清单"统一说明 |
| 死注释 | `types.mbt` 注释掉的 `PredKind` 副本 | 删 |

- 验收（已过）：0 warning；116/116；四套件数字不变；G9 9/9（再生链走通）；mbti = 死位删除面。
- 死注释：types.mbt 注释 `PredKind` 副本已删（枚举本体生成器发射，注释指明）。

### R-10 重命名（原子） `[27a 部分 ✅ / 27b 并役28]`

- 27a 已落：`fr → frame`（actions.mbt 局部帧变量 **71 处**，词边界正则一遍；勘察 72 系 grep -c
  数行不数处）——零 API 面。
- 27b（役28 一次抖动）：`pver/bver/iver`、`Hooks`、trig 同笔改——见下表与 todo 役27 段。
- 影响面（本包）：

| 现名 | 建议名 | 涉及 |
|---|---|---|
| `pver` / `bver` / `iver` | `prefix_version` / `base_version` / `iri_version` | `types.mbt:50`（QuadSpan）、`materialize_n3.mbt` 多处、`parser_slice.mbt:432` 组装、测试断言 |
| `fr` | `frame` | `actions.mbt` 多数 action 局部变量 |
| `Hooks` | `N3ActionsImpl`（或去 trait 化） | `actions.mbt:14`、`engine.mbt:271` 字段 |
| `mat_vs` / `mat_bytes` / `mat_chain` / `off_of` | `…` 语义名 | 随 R-11 迁入测试文件后改名 |

- ⚠ `pver/bver/iver` 在 **gen_trig 的 `QuadSpan` 里同名**（同构布局）。本包改名会与 trig 分叉；
  要么两包同笔改（推荐，`moon info` 双改），要么在本包 `spec.md` 注明有意分叉。
- 验收：`moon info` diff 只含预期重命名；111/111；套件不变。
- 依赖：R-06（快照可能加字段）→ 同批省一次 API 抖动。

### R-11 测试归位 `[✅ 定案·役27a]`

- 落地：27 个内联 test（materialize 23 + serialize 4）迁入新建 `materialize_n3_wbtest.mbt`（538 行）/
  `serialize_n3_wbtest.mbt`（64 行）；生产件 1396/101 行纯实现（`grep '^test '` = 0）。
- 命名实落（对勘察表的微调）：`mat_bytes→bytes_of` 复用 ✓；`mat_vs` 删 ✓ 但**未直换 view_str**——
  语义不同（mat_vs=`decode_lossy`，view_str=逐字节 `to_char`，多字节必烂）：先把 view_str 本体归一为
  decode_lossy 子视图解码（ASCII 站点输出不变，役24 钉全绿），再复用；`mat_subj/mat_obj` 收编为
  **emit_subject/emit_object 返 String**（`mat_vs∘mat_*` 73 组合直吸）+ 新立 `emit_predicate`
  （32 处 `.predicate` 直取同型）；`mat_chain→parse_materialize`、`off_of→first_offset_of` ✓；
  `mat_empty` 组合收编后零消费者**亡**（0-warning 强制，未立 empty_bytes）；`mat_deferred` 勘察时已亡。
- 跨文件消费同笔改：n3_wbtest 4 处、engine_wbtest 6 处（`mat_chain/mat_vs/mat_subj/mat_obj`）。
- 验收（已过）：`moon info` **零 diff**（fmt 后复验）+ 0 warning + 116/116 + fmt 幂等；
  mat_* 旧名残留 = 3 处刻意史注。

### R-12 文档三件 `[✅ 定案·役26]`

- ①`ARCHITECTURE.md` 一页落地（五层/生成链 G9/I-1..9 一句话表/术语/预留位清单——含
  `graph` 恒 None、RDFFirst/RDFRest 预留、`iri_upcast` 活机制正名、variable_name/rule_side 删除记录）。
- ②guides/n3：README 8 处 `@gen_n3`→`@gen_n3v2`、3 处 `SliceParser`→`N3SliceParser`、ctx 字段清单
  去死字段、效果枚举实名（`Continue/EmitQuad/Reset/Done/Sequence/PopBnp/OpenSlot`）、物化 API 换实形
  （`N3Materializer::new(data, prefixes, bases=)` + 方法调用，原自由函数形已不存在）；syntax.md 分层
  描述更新。验收 `@gen_n3\b` 残留 = 0（nquads/trig guides 的 `SliceParser` 为本包实名，不动）。
- ③役21 跨卷注记落 adr.md 卷首（役21 落外层 `src/fsm/toml.md` §根级动作声明面，不重复立条）。
- 附带 spec 陈数同步：27 ctx 字段 / 116 测试 / I-6 收敛后状态。

- ① 新增 `gen_n3v2/ARCHITECTURE.md`（一页）：五层图 + 生成链 + 不变量 I-1..I-9 + 术语表 + 预留位清单
  （ADR-003b 死位、`graph` 恒 `None`、`variable_name/rule_side/iri_upcast` 的处置）。
- ② 修 `guides/n3/README.md`（11 处 `@gen_n3` → `@gen_n3v2`、`SliceParser` → `N3SliceParser`、
  API 示例与 `.mbti` 对齐）；`guides/n3/syntax.md:49` 的旧分层描述。
- ③ `adr.md` 补役21 条目（提交 `7630bf2`：`[[actions]]` 全键 round-trip + 五门校验接活、
  `CodegenConfig.actions/codegen_trait` 退役、`src/fsm` 陈钉清零 95/95）——或注明役21 归 `src/rdf` 卷
  （外层仓已有 `src/rdf/adr.md`）。
- 验收：文档中出现的包名/类型名与 `pkg.generated.mbti` 一致（可用 `rg "@gen_n3\b" src/ttl/guides` 复查）。

### R-13 ctx 分组 `[✅ 定案·役28]`（题5 = A）

- 目标：6 个特性轴各自成组；reset 语义随组。
- 锚点：`n3.mbt:140-170`（字段）、`n3v2_base.toml:440-468`（表源声明）、`n3.mbt:218`（reset）、
  `engine.mbt:345/364/416`（begin_record/recover/finish_at_end 的清账清单）。
- 建议分组：`directive{prefix_name, base, prefixes, bases, directive_at}` /
  `path{src, pend, tail, fwd}` / `inversion{is_src, is_depth}` / `annotation{annot_s, annot_o, subj_shell, annot_close}` /
  `keywords{kw_ledger, kw_directive_seen, kw_a_live}`；`slot_stack`/`pred_kind`/`state` 留顶层。
- ⚠ 触发表门槛（`spec.md` §5）：单子系统 ≥4 联动清槽字段或总字段 >40——当前 29 字段已满足前者
  （path 4、annotation 4），但**表的 schema 要跟着分组**（外层仓 `n3v2_base.toml` + emit + G 门），
  这是跨仓改动，见 §6 题 5。
- 验收：分组后 `reset`/`recover` 的清单按组表达；111/111 + G9 绿。
- **落地（役28，ADR-28）**：组清方法形式——表平铺、生成器零改、生成 reset 不动（begin_record
  全清本就是它的语义）。`N3Context::clear_annotation`（四件套；消费点 settle_annotation 收口 /
  begin_record / recover_cleanup）+ `N3Context::clear_path`（src/tail/pend 三槽；path_fwd 单点翻转
  不入组；消费点集合链收口/多跳落位 ×4）。
- 不立项：keywords（kw:1099 是半开重置非清空）、directive（prefix_name 单点清）、inversion
  （settle_inversion 已是现成组方法）——零成组清账现场不设空转方法（役23 投机面判据）。
- B 留账：`[[context.groups]]` 表分节（外层仓生成器 + G 门同改）独立役再做。

### R-14 状态爆炸治理 `[立案]`

- 目标：加特性不再乘性改表。
- 锚点：`n3v2_base.toml` states 段（55 态，含 `FormulaX`/`QuantX`/`SubjTrailX`/`ListPathX` 交叉族）；
  外层仓 `src/fsm/analyze.mbt`（可达性/分析素材）、`src/fsm/construct.mbt`、`src/fsm/fuse.mbt`。
- 动作：A) 生成器按子 FSM 自动组合交叉状态；B) 混合架构（语句核心表驱动 + `{}`/`()`/`[]` 子自动机）。
- 验收：新增一个特性只增"子自动机 + 接线"，不手列交叉态；G1–G9 仍绿。
- 风险：动生成器影响 n3gen 之外的 trig/gen_md（同 emit 家族），⚠ 立项前先盘依赖面。

### R-15 数值/布尔单一实现 `[✅ 定案·役29]`

- 锚点：`gen_nquads/numeric.mbt`（唯一权威：`is_numeric_span` + `is_boolean_word`）；
  消费点八处两包三面：n3v2 adapter `classify_structural`/`classify_prefname`、`parser_slice`
  `validate_term`（数值+布尔）、`materialize_n3`（主语守卫/is_num/宾语守卫）；trig adapter
  `classify_structural`/`classify_prefname`、`parser_slice` `validate_term`、`materialize_trig`（is_num/宾语守卫）。
- 动作（已落地）：识别件独此一份落 `gen_nquads/numeric.mbt`（非账面原建议 n3v2 `types.mbt`
  ——侦察实证 trig `lexer_adapter.mbt:123` 有字节孪生件，"has_digit 全仓一处"强制跨包；
  gen_nquads 是两包公共依赖）；`is_boolean_word` 新增收编六处布尔识别；`bool_at` ×2
  删除（死码门）；展开件 `expand_number`/`expand_boolean` 留驻各物化层（arena 发射是包内
  职责，识别才是共享面）；全部限定名 `@nquads.` 调用（役28 风格）。
- 验收（已过）：`rg "has_digit" src` 全仓单点（numeric.mbt 一处）；nquads 89/89+29/29+
  27/27+72/72、trig 357/357、n3v2 116/116、模块 329/329；0 warning；mbti 仅 nquads +2 行。

---

## 5. 影响面与原子性

| 变更 | 是原子的 | 跨包/跨仓清单 |
|---|---|---|
| 改表（`n3v2_*.toml`） | 是 | 表 → `moon test src/rdf/n3gen` → `cp n3v2_out.gen → n3.mbt` → 本包测试 |
| 改 `emit.mbt`（含 ②③ 套装形态） | 是 | 外层仓 emit + G9 对拍翻新说明；影响 emit 家族（n3gen/trig/gen_md 各自 schema） |
| 重命名 `QuadSpan` 字段（R-10） | 是 | 本包 types/materialize/parser_slice/tests + `.mbti`；gen_trig 同名结构是否同改需决策 |
| 收窄公共面（R-08） | 是 | 本包 + `.mbti`；黑盒测试可见性 |
| 动共享词法（R-04/R-15） | 是 | gen_nquads（Moon + C）+ gen_trig + gen_n3v2 三包 + parity 套件 |

⚠ 通用纪律：`n3.mbt` 手改必被 G9 判红；`moon info` 的 `.mbti` diff 必须逐行审；`moon fmt` 放在最后。

---

## 6. 待裁选择题（每题给选项 + 影响）

1. **R-02 形态**：
   A) `engine.next` 调 `interpret`（效果面全控：容灾可接管 emit/降级；改动最大）——
   B) engine 保留循环，② 面退化为"观察者注册表"（改动小，但降级/截断能力弱）——
   C) 保留双实现，只加语义对拍钉（不推荐）。
   → 影响：A 才真正满足"容灾 + 观测"双切面；B 只够观测。建议 **A**。
   → **裁决（役22）**：**A 落地**。interpret 唯一解释器 + engine.next 纯控制流；emit_queue 下沉 N3Context 解三发 Sequence（ADR-22 翻案）。
2. **R-08 扩展维可见性**：A) ②③ trait 保持 `pub`，作为第三方可挂切面的公共契约；
   B) 降为包内可见，外部只经 `N3Engine` 配置进入。
   → 影响：A 保留生态/插件化可能但公共面大；B 公共面干净但切面只能在本包实现。需按"是否计划外部切面"裁。
   → **裁决（役28）**：**B 落地**——零外部消费者 + 扩展面外部本不可达（from_bytes 内建 actions，
   无公共构造子）；裁据与落地见 R-08 定案块、ADR-28。
3. **R-01 状态改写承载**：A) 新增 `N3Effect::SetState`（表行声明，影响 effect 枚举 + G8）；
   B) action 返回 `(Effect, N3State?)`（改 48 个方法签名）；C) 保留三处例外但登记（0 改动）。
   → 建议 **A**（影响面最小且表可控）。
   → **裁决（役23）**：**A/B 均不可行，落地 = 机制收敛 + C 登记**（ADR-24 翻案）——侦察实证
   2/3 号是运行时链形异判（同 (from,on)，guard else=UnexpectedEvent 不 fallback，两链形
   SubjTrailAfterStep 汇合行分裂也不可行）；Err 短路路径效果无从返回；pop 经 interpret
   PopBnp 臂 handler 返 Unit。1 号收敛 = id 特例前移 set_id_subject 刻帧 + pop 无条件读帧。
   SetState 零可行实例不立项（投机面，役15 守卫具名组先例）。
4. **R-05 错误形态**：A) 保持 `(Array[QuadSpan], Array[ParseError])` 并累积（API 不变）；
   B) 改流式迭代器（破坏 API）；C) 单错 + `error_count`（信息仍缺）。
   → 建议 **A**；行号沿用 `line_before`。
   → **裁决（役24）**：**A 落地**（ADR-25）——`error_spans` 累积 + drain 三点转 `ParseError`；
   R-06 同裁：带外 nil 载体（字段/变体）= API 变更不取，带内通道 + 物化验形门，缺口登记。
5. **R-13 分组是否连带改表 schema**：A) 只改本包 ctx 访问形态（表仍平铺字段，生成器零改）；
   B) 表也分节（`[[context.groups]]`，外层仓生成器 + G 门同改）。
   → A 便宜、B 干净；建议先 A 后 B（分两役）。
   → **裁决（役28）**：**A 落地**（组清方法形式：表平铺、生成器零改；annotation/path 两组现实
   序列收编）；B 留账独立役。见 R-13 落地块。
6. **R-07 双判成本**：A) 每文件既跑严格判定又跑宽容扫描（耗时约 ×2，证据最全）；
   B) 只跑严格判定（套件数字可能变化，需重新分桶）。
   → 建议 **A**（先双判暴露缺口，缺口清完再切单判）。

---

## 7. 动手前 / 动手后 检查清单

动手前：

- [ ] 确认改的是嵌套仓（`src/ttl`）还是外层仓（`src/rdf/n3gen`），提交分开。
- [ ] 读 `spec.md` §5 机械约束（guard 只通 ctx / EOF 不进表 / ctx 新字段守门）。
- [ ] 跑基线三命令并记录数字（§1 表）。
- [ ] 涉及 `n3.mbt` → 先想清表源改法（禁手编）。
- [ ] 涉及扩展维（②③）→ 先裁 §6 题 1/2。

动手后：

- [ ] 若动表：`moon test src/rdf/n3gen` 绿 + `cp` 交付 + 重新 `moon fmt`。
- [ ] `cd src/ttl && moon check src/gen_n3v2` → 0 warning。
- [ ] `moon test src/gen_n3v2` → ≥111 且套件四项数字不变。
- [ ] `moon info` 审 `.mbti` diff（重命名/收面/加字段都在这里露出）。
- [ ] 更新 `spec.md` 对应 C/R 条目状态；语义级变更写 `adr.md` 新条目。

---

## 8. 锚点索引（快速跳转）

| 主题 | 锚点 |
|---|---|
| 三个业务面声明 | `n3.mbt:284`（LoopPolicy）、`n3.mbt:301`（Actions）、`n3.mbt:2045`（EffectHandler） |
| 效果解释器 | `n3.mbt:2168`（interpret）、`n3.mbt:2209`（dispatch）、`n3.mbt:2144`（apply_scope） |
| 主循环 | `engine.mbt:533`（next）、`engine.mbt:495`（take_pending_quad）、`engine.mbt:331`（under_formula） |
| 归位点 | `engine.mbt:190`（normalize_term_span）、`:83`（trim_trailing_punct）、`:135`（kw_ledger_hits）、`:170`（is_deprecated_this） |
| 恢复/收尾 | `engine.mbt:364`（recover）、`:381`（consume_to_recover_point）、`:416`（finish_at_end）、`:447`（on_business_failed） |
| 状态直写三处 | `actions.mbt:166`、`actions.mbt:517`、`actions.mbt:704` |
| 路径机器 | `actions.mbt:360`（path_hop_resolve）、`:551`（path_tail_hop_resolve）、`:929`（path_obj_close） |
| 集合/帧 | `actions.mbt:136`（pop_bnode_prop）、`:983`（list_top）、`:995`（list_first） |
| 倒装/等同/注解 | `actions.mbt:1108`（is_of）、`:1121`（set_inversion）、`:1135`（set_sameas）、`:1148` 起（annot_*） |
| 组装/校验 | `parser_slice.mbt:432`（assemble）、`:251`（validate_term）、`:365`（validate_prefname）、`:51`（prefix_declared） |
| 物化门 | `materialize_n3.mbt:683`（materialize_quad）、`:1012`（materialize_all）、`:1111/1126/1160/1175`（四门） |
| 生成侧 | `emit.mbt:657`（LoopPolicy 模板）、`emit.mbt:1083`（EffectHandler 套装） |
| 生成门 | `src/rdf/n3gen/n3gen_test.mbt:23–186`（G1–G9） |
| 套件 runner | `rdf_suite_wbtest.mbt:95–154`、`n3tests_suite_wbtest.mbt:18–93`、`examples_wbtest.mbt:9` |

---

## 9. 工程经验（役间沉淀，动手前先翻）

**再生与 fmt**：
- 生成器输出必须 fmt-clean——`moon fmt` 后 G9 仍字节一致才算达标。已知形态：match 单语句臂折花括号（`Arm =>` 换行缩进体）、`assert_eq` 单行折叠（80 内）、fn 签名 >80 折叠、`new()` 展开内建。模板新输出了非规范形 = 先改模板直产 fmt 形，禁事后 fmt 生成件。
- `moon fmt src/gen_n3v2` 会顺手格式化 wbtest（assert_eq 折叠等）——无害，随役入库；但 G9 金样是生成件本体，fmt 幂等靠模板侧保证。
- 再生一行（外层仓根）：`moon test src/rdf/n3gen`（G9 红=表领先）→ `cp src/rdf/n3gen/n3v2_out.gen src/ttl/src/gen_n3v2/n3.mbt` → 复测绿。

**emit.mbt 手术（生成器源）两形态**：
- `$|` 字面量行 = 套装/interpret 体（emit 输出的 verbatim 段）——按行替换，臂边界锚下一臂首行。
- 字符串字面量（带转义形态）= struct/new/reset 生成段——python old 串写反斜杠 n（两字符）；插值记号同理加反斜杠前缀。

**python 锚点手术纪律**（Edit 长内容/CJK 边界腐蚀的替代路）：
- 内容锚 + assert 邻距（不硬编码 CJK 行号；行号锚先 `sed -n` / `awk | cat -A` 实探）。
- 每锚 `count==1` 断言；失败即原子 abort 不写盘。
- 落盘后机械验证：`grep -cE "placeholder|STILL_BROKEN"` + 旧名零残留 grep。

**测试与验收**：
- 点名钉：`moon test src/gen_n3v2 -f "*役N*"`（glob 过滤；`-p` 包参数与 file-filter 混用会报错）。
- `moon info | head` 会 SIGPIPE 杀半程 → mbti 半新半旧；重跑不带 head。
- pipeline 退出码会说谎——判定用 grep "Error"/"failed"/"Total tests"。
- zsh 等号开头词展开炸 echo 分隔线——分隔符加引号。Bash CWD 会漂——每命令显式 cd 绝对路径。
- 全仓 `moon test` 触发生成器自写盘（quick_machine/fsm/mdlex 产物时间戳+形态差）——commit 前盘点 status，非本役面单独说明。
- 侦察"全表唯一 X"断言要含用户层 action 动态构造的效果（役22：表内唯一 Sequence 不等于全系统单发，path_obj_close 三发在 actions.mbt）。
- 裁定"能否上表"先查**事件分类学**：表消费的是已分类事件，凡改判事件种类（KeywordA→PrefName、Unknown→KeywordX）或切分事件（一词两事件）的机制天然在表上游；表行 guard 只能拒绝（else=UnexpectedEvent）不能改派/不能 fallback 下一行——同 (from,on) 双链形异判（path_subj_end）表内无解，唯有 action 层运行时判。宽度侦察的字面清单（"3 处直写"）要先问每处**判别数据源**是否表内可得，再定迁移方案，否则验收口径（"grep 为空"）本身不可达（役23）。

**役24 错误面/钉构造**：
- 坏句测试输入必须自带 Dot——recover 跳读吃 Dot 前一切，`",\n,\n"` 第二坏句被吞（钉红 1!=2 的根因）。
- 造路径类错误输入先查**表可达三件事**：① 态族（Bang/Caret 在 ExpectPredicate → SubjTrail 族 =
  主语位链；ExpectObject → PathExpectVerb = 宾语位链）；② 词法合并（`[]` 空属性表并成单 BlankNode
  事件，PathAfterStep+BlankNode → path_end 原子，`^<q>[]` 只出 Structure 不出业务错——非空 `[ ... ]` 才触发
  path_end_nested）；③ span 回填（无载荷事件 span=(0,0)，next() 填 `lexer.pos()` 零长——断言写 (行,0)）。
- 物化词元断言禁 `view.to_string()`（ArrayView[Byte] 出 `[b'\x3C', ...]` 调试形）——用
  `view_str(v, (0, v.length()))` 字节转串；词表 IRI 输出含尖括号，`has_suffix("#nil>")` 判。
- 业务错触发点前合法路径跳已发四元组（path hop 先物化后失败）——钉 quads 数含它们，别按 1 断。

**役26 清账/文档役**：
- `moon.pkg` unused_package 警告的**行号锚 ≠ 直觉**——先 cat 文件对准再删，勿按导入顺序猜
  （cmd/main 警告 :3 是 `debug` 非首行 `argparse`；错杀回补后 [0029] 变 [0071] 才现形：argparse 在
  用、debug 才是死位）。
- 同一 trait 对同一类型的**多个 impl 块约束必须一致**——只给一块去 `: LexerSource` 界会报
  Inconsistent impl（[4135]），双块同改 `impl[L]`。
- 死字段裁决先 grep **表源 expr 引用**再定性：`iri_upcast` 被 `n3v2_trans.toml` expr 消费 = 活机制，
  ctx 表按"声明未读"误列死位——删前一步 `grep 字段名 表源` 省一次错删。
- guides 修 API 示例以 **mbti 为准**逐条对：`materialize_all` 已从自由函数迁 `N3Materializer` 方法，
  文档里的旧调用形全仓无对应物；跨包同名 `SliceParser`（nquads/trig）是实名不是漂移，勿顺手改。

**役27a 归位/改名役**：
- `grep -c` **数行不数处**——`\bfr\b` 55 行实为 71 处（一行可多次）；原子断言以 `len(re.findall)` 为准。
- **复用前先对语义**：mat_vs=decode_lossy、view_str=逐字节 to_char，名异实异；盲替会把多字节断言
  全烂（且 mojibake 未必红测试）。归一手（修 view_str 本体）→ 再复用，ASCII 站点输出不变零涟漪。
- 组合收编消灭双写：`mat_vs∘mat_subj` 73 处不逐点改 `view_str(x,(0,x.length()))`（表达式翻倍），
  改让 emit_subject/emit_object 返 String 直吸组合；零消费者的 `mat_empty` 由 0-warning 门强制除名。
- 跨文件同名消费先盘再迁：`mat_*` 不止 materialize_n3 自己用（n3_wbtest/engine_wbtest 也引），
  迁移脚本必须同笔扫全包，漏一处即编译错（好在是硬失败）。
- 迁移脚本原子纪律实战生效：中途 assert 失败两次均零写盘（失败在写盘前）。
