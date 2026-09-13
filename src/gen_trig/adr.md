# gen_trig 决策录（ADR）

版本：v1.0.0（2026-09-12 立卷；自 `todo.md` §4「变更收集」与 §5 定案拆出）

**卷面分工**：本卷只讲**为什么这么决定**（背景 / 决策 / 被否方案 / 后果）；结构事实在 `spec.md`，
红线在 `const.md`，路线在 `todo.md`，工作上下文在 `ctx.md`。
**编号**：`ADR-TRIG-nnn`（世界卷 `bangto/world/naming.adr.md` 的前缀制）；
本卷前身是 `todo.md` 的"变更收集"流水，2026-09-12 整理为条目——**历史结论不重写，只补来源**。

---

## ADR-TRIG-001：生成契约三条线（与 gen_nquads 同宪法；gen_trig 为第二样板）——✅ 2026-09-03

**背景**：trig 的 FSM 生成链（T-1…T-9）从 gen_nquads 第一样板推广而来，需要一条能跨方言复用的
契约骨架，避免每个方言各自发明主循环与效果语义。

**决策**：三条线冻结——① **决策在表**（`step` 只产出 Effect 意图，收拾粒度写转移行）；
② **机械在模板**（主循环 `next` 全 FSM 同形，四节点零领域逻辑）；③ **领域知识在契约成员**
（`TrigActions` / `TrigEffectHandler` / `TrigSupervisor`）。Effect 只加变体，不改签名。

**被否方案**：把图块/注解语义写进 loop 分支（会让主循环不再是模板，方言差异无法靠数据表达）。

**后果**：trig 的所有方言差异都落在表与适配层；代价是引入 `EnterGraph` / `ExitGraph` /
`Sequence` / `PopBnp` / `ListStep` / `OpenSlot` 六个 Effect 变体（见 ADR-TRIG-004/007）。
**落点**：`const.md` §1（红线）、`spec.md` §5.3。

## ADR-TRIG-002：双词法器同 Token 字母表；C 版为标准对齐源——✅ 2026-09-03

**背景**：MoonBit 词法器（`lexer_mbt.mbt`）与 C FFI（`lexerc_ffi.c`）是两条实现，历史上出现过
扫描口径分叉（如尾点、后缀门）。

**决策**：两器同 Token 字母表、同 span 口径（全词含定界符）；`token_to_event` 映射共用、零补偿透传；
**词法语义以 C 版为对齐源**；`trig_bench_wbtest.mbt` 逐 token pin `(分类, 偏移, 长度)`。

**证据**：简单语料 4006 token、复杂语料 9046 token 全一致；C 侧 434/907 µs vs MoonBit 1117/2056 µs。

**已记录分歧**：`"text".` 形态（C 版把尾点吞进词项）——C 侧维持旧行为，**该形态移出共享电池**，
分歧入账而非静默对齐（见 ADR-TRIG-009）。

**后果**：MoonBit 侧的性能差距成为长期债（R-T12 [立案]）。

## ADR-TRIG-003：`[]` 属性列表（★3 阶段 1+2）——✅ 2026-09-03

**决策**：

1. **帧设计**：`SlotType = BnodeProp | List | Formula`；`Slot = { typ, open_span, subject,
   predicate, graph, ret_state, as_subject, prev_node, mut node_seq }`；**帧只存外层快照 + 身份 + 返回**，
   区域内三元组照常走 `EmitQuad` 发射（不缓存元素数组）。
2. **返回态由开括号转移行写入帧，pop 时兑现**——这是"state 由表管理"的**唯一例外**，
   也是表外入口必须登记的根源（T10 门要覆盖它）。
3. **压栈/弹栈是 action**（`open_bnode_prop` / `pop_bnode_prop`），`PopBnp` 是新 Effect 变体；
   loop 顶层与 `Sequence` 内各一臂直调 action（对齐 ExitGraph 意图兑现口径）。
4. **区域状态按"待收什么"分裂**（`BnpExpectPredicate/Object/AfterObject`），主/宾位不分裂区域——
   位置语义进帧（`as_subject`），避免 `GraphExpect*` 区域倍增。
5. **空 fresh 独立成句静默跳过**（`[] .`）：零三元组，不进缺槽报错。

**被否方案**：为每个语境窗各开一套区域态（状态数乘性增长；n3v2 后来用组合求积才收掉同类问题）。

**后果**：`reset` 不碰栈；`begin_record`/`recover` 清栈；`finish_at_end` 栈非空 = dirty。
**落点**：`spec.md` §5.3/§5.4；`types.mbt`。

## ADR-TRIG-004：`()` 集合链 + 合成谓词（★3 阶段 3）——✅ 2026-09-04

**决策**：

1. **合成谓词 `PredKind`**：链节点 `rdf:first`/`rdf:rest` 在数据中无字节；表在合成行写 `ctx.pred_kind`，
   `TrigContext::snapshot` **读出即归 `Normal`**（快照即消费）；`pk` 随 `TrigPendingQuad`/`QuadSpan` 带出，
   物化层按 `pk` 合成词表 IRI（永不读 `p` 字节）。合成 quad 的 `p` 槽用 `(0,0)` 占位过缺槽检测。
2. **链节点身份** = `Span(open.0, k+1)`（长度承载序号）；`node0` = `(` token 自身 span；
   空集合 pop 特判写 `Span(open.0, 0)` = `rdf:nil` 标记（长度 0 = 无字节词项）。
3. **`emit_queue`**：`list_next` 一步多 quad（`rest` + `first` 双发射），队列 FIFO、`next()` 顶部优先排空
   （旧"单 pending 覆盖"会丢 quad）。
4. **嵌套元素**（`[`/`(` 作元素）：`first`/`rest` 链必须在开帧前发射（快照要拍到链节点，开帧会覆写 `s`）
   ⇒ `OpenSlot` 在 `EmitQuad` 后兑现。
5. **入口行六路**：顶层/指令后主位 ret = `TrigExpectVerbRequired`（新态，仅谓语出边）；图块主位 ret =
   `GraphExpectPredicate`；宾位 ret = `ExpectDotOrGraph` / `GraphExpectDotOrGraph` / `BnpAfterObject`。

**后果**：`bad-list-01/02`、`collection-graph-bad`、`bad-list-03/04` 由表直接裁决（test 即规格）。
**落点**：`spec.md` §5.3/§6.2；`materialize_trig.mbt` 的 `pk` 分派。

## ADR-TRIG-005：`@base` per-quad 快照（★1）——✅ 2026-09-04

**背景**：`ctx.base` 是单槽 ⇒ 文档中途改 `@base` 后，**历史 quad 的相对 IRI 会被最终 base 改写**
（subm-27 等现象）。

**决策**：`ctx.base` 单槽 → **append-only `ctx.bases` 链**；`EmitQuad` 快照带出 `base_version`
（链长）；物化层 `base_at(base_version)` 折叠链前缀（绝对 `@base` 重置累计值，相对 `@base` 按
RFC 3986 §5.2 与累计值合并）；前缀账本同理加 `prefix_version` 上界钳（前缀重声明不污染历史 quad）；
键为 `base_version` 的 memo **错误不 memo**（逐 quad 重报）。

**被否方案**：在组装层就把相对 IRI 解析成绝对（需要物化层文法，破坏"组装后轻验 / 物化才深验"分层）。

**后果**：subm-27 ×2 出槽（rdf-trig 355/355、rdf-turtle 316/316）；`bver=0` 时零开销。
**落点**：`spec.md` §5.5；`materialize_trig.mbt:392`（`base_at`）。

## ADR-TRIG-006：手改面回灌生成管线（★8）——✅ 2026-09-04

**背景**：`trig.mbt` 早期是**人工定稿**，生成器只能部分复现，靠"逐行对齐"注释维持；用户层改动
（★3 系列）落在手写文件里，生成面落后。

**决策**：把手改面**全部回灌生成管线**——`domain/trig_domain.toml`（36 态 / 33 事件 / 10 效果 / 184 行 +
`[[context.snapshot_extras]]` + 18 动作词表）→ `domain_to_ir.mbt` 推导 → `fsm_out/trig_fsm.toml` →
`fsm` CLI 再生 `trig.mbt`。配套机械（外仓 `src/fsm`）：`[[context.snapshot_extras]]` 解析、
根 `[[actions]]` 声明面、多参签名按位统一、binding 词表（`state:` / `::`）、trait 方法 `fn` 前缀补正。

**验收**：再生 vs 手稿 diff 仅余**化妆差**（枚举/注释不发射、单行 vs 折行、canonical 绑定名、
自环行死写 `ctx.state`、dispatch 钩子臂序），四套件 + 单元全绿证行为等价。

**后果**：**"生成器回灌前禁再生"解除**——`trig.mbt` 自此生成器所有（唯一修改路径 = 改生成面 + 再生）；
旧 `src/gen_trig/trig.toml`（20 事件声明、无管线引用）退役删除。
**遗留**：产物侧仍无黄金门（C-T2），故 `const.md` §5 明写"无对拍不得改生成面"，T10 补门。

## ADR-TRIG-007：役 9 注解精化 port——体主语 = TT 壳——✅ 2026-09-06

**背景**：RDF 1.2 注解 `:s :p :o {| :q :z |}` 需要"体 quad 的主语是什么"的定案；gen_n3 役 8 已定，
trig 需同构移植（trig 多一个图块注解区）。

**决策**：主 quad 锚 `(s,p,o)` 照发 + **体 quad 主语 = TT 壳** `<<:s :p :o>>`；壳 span = 锚主语起点→
锚宾语终点的原文连续区间（含原空白）；物化层逐字节保真推 arena → `Subject::TripleTerm`
（**prefname 不展开**，原文保真口径）。

**实现账**：表役双区 20 行转换、**零新行**（195 行不变）；toml 侧 +4 字段（`annot_s`/`annot_o`/
`subj_shell`/`annot_close`）+1 extra +4 动作。机械差异（vs 役 8）：trig 无 `take_pending_quad`
（两发射点各自过 `settle_shell`，`settle_annotation` 只在直臂）、无 `pk=KwA/KeywordX`、
`begin_record` 仅构造期一次（壳账清点落 `recover` + `finish_at_end`）。

**验收**：+9 钉（顶层正典 / 图块区壳+图名保持 / 续锚 / 嵌套 bnp 错键旗落假 / 静默收口 /
TT 独立主语回归 / `~` 驻留位 + 物化 2 钉）；`gen_trig` 80/80、套件 316/75/36 不变。

**补记（2026-09-13）**：本 ADR 声称的"toml 侧 +4 字段 +1 extra +4 动作"当时只落到了
v1 层之外的产物/文档面——**2.0 数据面（`domain2/trig_*`）实际停在役9 之前**，导致
"从盘上 `fsm_out` 再生会抹注解"的预存分歧（ADR-TRIG-006 遗留）。该分歧已由外层仓
`src/rdf/adr.md` **ADR-4** 收口：四字段（含 derived `subj_shell`）/四 `action_hooks`/
20 行行型回灌 `domain2/trig_*`，盘上 IR 与产物注解面追平；残差只剩 fmt 形与墙钟 ts。
同轮 `src/rdf/adr.md` **ADR-5** 退役了 v1 数组对拍腿（v1 TOML 只服务 nquads）；
⚠ Turtle 路径仍走数组函数、口径停在役9 前，翻 2.0 另立役。

## ADR-TRIG-008：Enter/ExitGraph 双路由维持现状（不引入 `action_args`）——✅ 2026-09-03

**背景**：`}` 有两条到达路径——动作路径（`exit_graph` action → dispatch → `handle_exit_graph`）
与序列路径（`[EmitQuad(SPO), ExitGraph]` → `interpret` → `on_exit_graph`），曾考虑用 `action_args`
统一成一条。

**决策**：**维持双路由**，理由写进 `engine.mbt` 头注（差异点 5）：统一会引入参数化动作面，
把"图块退出"的两种时序（有无挂起发射）压成一个签名，反而要在 loop 里分支——违反三条线。

**后果**：`TrigEffectHandler` 同时保留 `handle_exit_graph` 与 `on_exit_graph`；
这也正是 C-T1（效果面孤儿）与 T11 收形时**不得动图块语义**的原因。

## ADR-TRIG-009：回收出槽三桩 + 指令名零空格拆分——✅ 2026-09-04

**决策（四桩，均为"表外真堵"的修口）**：

1. **词法后缀门**：`scan_literal_suffix` 要求紧邻字节为 `^`/`@` 才进后缀扫描——旧"只认空白收束"
   会把 `"a")` 的闭括号吞进词项（lists-05 集合元素位失配）；`"text".` 尾点形态 C 版冻结保留旧行为，
   移出共享电池（ADR-TRIG-002）。
2. **PrefName 相对展开按 base 解析**：`@prefix : <#>` 展开后仍是相对 IRI（subm-01 口径）；
   无 base 报错与 `<rel>` 词项同径。
3. **`fn_remove_dot_segments` 尾斜杠保留**（RFC 3986 §5.2.4 尾空段不可弃；旧口径 base `/a/` 上解析 `#x`
   误得 `/a#x`）。
4. **`] }` 图块无点收口行 + 集合主位 ret 改 `ExpectPredicate`/`GraphExpectPredicate`**，
   新增 `TrigExpectVerbRequired`（顶层集合主位，无 `Lbrace`/`Dot` 出边）——`(1 2) {` 拒绝、`<g> {` 不受扰；
   指令后 TT 主位行（`turtle12-bnode-03`；括号壳 `<<(` 只许宾位）。
5. **`@prefix:<iri>` 零空格拆分**：词法整词扫出 `prefix:`（冒号是名字字符），关键词臂只认 6 字节整词
   ⇒ 适配层单槽 pending 拆分（`@` 邻接位精确 `prefix:`/`base:`/`version:` 才拆；`kw:foo` 带本地部不拆）。

**被否方案**：把这五类判断留在表外"顺手兜住"（每例都表现为套件红点，且红点分布零散）。

**后果**：deferred 桶六轮回收——rdf-trig 354/354 → 355/355、rdf-turtle 316/316、
最终**四套件 deferred 全零**（357/316/36/75）；撤桶九文件（trig-turtle 族 + minimal-whitespace-01）。

## ADR-TRIG-010：命名回灌（采纳世界卷 `ADR-NAMING-001`）——✅ 决策已定，执行归 T13

**决策**：`LoopPolicy → Supervisor`（控制流 Hook 面的正名）、`Hooks → <方言>ActionsImpl`；
`Biz`/`User`/`Impl` 等旧词不再使用（`bangto/world/vocabulary.spec.md` v2.0 废弃别名表）。

**本包落点**：`TrigLoopPolicy → TrigSupervisor`（`trig.mbt:223` + `engine.mbt:227/240/314/344/353`）；
`Hooks → TrigActionsImpl`（`actions.mbt:9` + `engine.mbt` 字段）。**执行**归 T13（跨仓原子变更，
与 T10 门同笔最省）。

**为什么收进本卷**：世界卷的命名 ADR 是跨模块决策；本卷只记录"本包如何落地、何时执行"。

## ADR-TRIG-011：卷面补全——五卷制（本卷即产物）——✅ 2026-09-12（T16）

**背景**：本目录原只有 `todo.md`（472 行）**同时承载**宪法（§1）、规格（§2）、伪代码（§3）、
变更收集（§4）、未完成清单（§5）与战役路线（§6），另有 `ctx.md`（206 行）。
违反 `bangto/world/const.md` §5.2（`ctx`/`todo` 不承载红线与结构事实）与 §5.4（扁平式五卷）。

**决策**：拆为——`const.md`（红线，冻结）← 原 §1；`spec.md`（结构事实 + 不变量 + 已定口径 + C/R 台账 +
验收口径）← 原 §2/§3；`adr.md`（本卷）← 原 §4/§5 定案；`todo.md` 只留资产/债务索引、战役路线、
P 步与执行记录；`ctx.md` 对齐 `bangto/world/ctx-template.meta.md`；新增 `ARCHITECTURE.md` 一页导读。

**被否方案**：保持单文件 `todo.md`（历史包袱最省事，但违反世界卷硬约束，且与本项目已收敛的
n3v2 五卷制分叉）；只拆 `spec.md` 不拆 `adr.md`（决策会继续以"变更收集"流水形式埋在 todo 里）。

**后果**：`todo.md` 472 → 约 200 行；红线与结构事实各归其位；后续 T10–T17 的决策有了固定落点。

## ADR-TRIG-013：效果面接活（T11 / R-T1）——✅ 2026-09-13

**背景**：`TrigEffectHandler` 是"孤儿挂点"（C-T1）——`interpret` 零调用、`engine.next`
自带一份效果解释序；观测/容灾切面（每 quad 埋点、丢弃/改写）**挂不上**。

**决策**（与 n3v2 役22 同构，题T1 = A 全控）：

1. **`interpret` 成唯一解释器**：`engine.next` 只做 loop 控制流
   （取事件 → step → `TrigEffectHandler::interpret` → 上抛），效果语义全数移驻 handler。
2. **`emit_queue` 下沉 ctx**（`domain2/trig_base.toml` 新增 `Array[TrigPendingQuad]` 累积字段）：
   Sequence 多发逐条入队、队首即返、余者 loop 顶部排空——集合链 `rest+first` 双发射不再被
   单 pending 覆盖。
3. **生成器数据驱动开关**（ADR-7 @`src/rdf`）：ctx 声明 `emit_queue` 即发射"队列模式
   interpret"（顶层意图臂走 `handle_*`/`on_*` 兑现）；无该字段的方言（nquads 等）**字节零波及**。
4. **用户层接活**：`engine.mbt` 实现 handler 的真实挂点——`snapshot`（壳旗结算 + 收口旗消费）、
   `on_exit_graph` / `on_pop_bnp` / `on_list_step` / `on_open_slot`（意图兑现调 action）；
   `settle_shell` / `settle_annotation` 由引擎方法改为 **ctx 方法**。

**被否方案**：让用户的 `snapshot` 私藏队列绕过模板（会丢首发/乱序，`rest+first` 顺序不可保）。

**验证**：`moon test src/gen_trig` **80/80**（四套件 357/316/36/75 不变）；
`moon test src/rdf` **21/21**（产物黄金门对新产物仍逐字节绿）；模块 **329/329**；
验收锚点：`engine.mbt:404`（调用点）+ `:476/489/496/504/513`（impl）。

**风险/遗留**：图块语义（ADR-TRIG-008 双路由）未被收形改动；Turtle 路径仍走数组旧口径（ADR-5）。

## ADR-TRIG-014：RDF 1.2 单一模式开关（`rdf12`）——✅ 2026-09-13

**背景**：trig 的 1.2 特征原本只有**半套开关**——字面量转义有 `scalar_only_escapes`
（构造参数 `scalar_only? = false`），而**方向性语言标签 `--ltr/--rtl` 无条件放行**
（`langtag.mbt` 共享文法本身认方向后缀）。后果：RDF 1.1 模式下 `"x"@ar--rtl` 也被接受，
与 WG 语法不一致；两处特征各自为政，口径不对称（rdf11 语料暂无该形态，故 316/75 全绿掩盖了它）。

**裁决（题：B 统一模式开关）**：

1. `TrigMaterializer` 的 `scalar_only_escapes : Bool` → **`rdf12 : Bool`**（构造参数
   `rdf12? : Bool = false`），**一个开关同时管两件事**：
   - **转义**：`rdf12 = true` ⇒ 代理一律拒（成对也不收）；`false` ⇒ 1.1 宽容（成对合法）；
   - **方向后缀**：`rdf12 = true` ⇒ 拆 `--ltr/--rtl` 后验基础标签（放行）；
     `false` ⇒ **显式拒**（`Language direction suffix (--ltr/--rtl) requires RDF 1.2`）。
2. `deep_check_literal` 第二参同步改名 `rdf12`（内部传
   `@nquads.validate_escapes_unicode(..., scalar_only=rdf12)`——nquads 侧参数名保持不动，冻结口径）。
3. 套件 runner `scalar_only?` → **`rdf12?`**；`rdf12-trig` / `rdf12-turtle` 两套件传 `rdf12=true`。

**被否方案**：A（另加 `lang_dir` 开关）——两个布尔表达同一件事，调用方要成对维护；
本仓已收敛"模式开关"口径，1.1/1.2 是**一个模式**而非两个正交特征。

**验证**：`moon test src/gen_trig` **80/80**（rdf11-turtle 316、rdf12-turtle 75、rdf12-trig 36 不变）；
新增钉子：`@ar--rtl` 在 `rdf12=true` 放行（1 emit/0 merr）、在缺省 1.1 模式**拒**（0 emit/1 merr）；
转义钉子随开关改名（1.2 成对代理拒 / 1.1 成对合法）。`.mbti` diff = 预期改名（3 行）。

**遗留（另役）**：n3v2 侧仍是 `scalar_only_escapes` 单命名（无 langdir 面），
若要与本口径对齐，属独立原子改名（`src/ttl/src/gen_n3v2`）。
