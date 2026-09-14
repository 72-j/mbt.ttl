# gen_nquads 决策录（adr）

版本：v1.0.0（2026-09-13 由 `todo.adr.md` 更名并收敛为**决策录**；对齐 gen_trig 五卷口径）

**卷面分工**：本卷只讲**为什么这么决定**；红线在 `const.md`、结构事实与已验证口径在 `spec.md`、
路线与账本在 `todo.md`、整改上下文在 `ctx.md`。
**本包定位 = B 冻结样本**（用户定 2026-09-13）——决策录此后只增不改，演进类决策不再产生。

**编号**：`ADR-NQ-nnn`（方言前缀制，与 `ADR-TRIG-nnn` 同规）。

**历史卷内容去向（更名时整理，防静默丢失）**：
§1 宪法 → `const.md`（已在，含勘误回灌）；§2 规格 / §3 伪代码 → `spec.md` §4（**已搬**，2026-09-13）；
§4 变更收集 → 本卷 `ADR-NQ-001…007`；§5 未完成事项 → `todo.md` §2/§3 与 `ctx.md` §4。

---

## ADR-NQ-001：FSM 生成链路打通（第一样板）——✅ 2026-09-03

**决策**：`src/fsm` 生成器（`ir.toml` + `codegen*`）以 `test_nquads.toml` 为输入产出 `nquads.mbt`
（DO NOT EDIT）；三条线（决策在表 / 机械在模板 / 领域知识在契约成员）、`ResetScope` 四档、
Effect 三件套（`Continue`/`EmitQuad`/`Done`）、`LoopPolicy` 四钩子由此定案，并**推广至 gen_trig**
（第二样板）。

**后果**：trig 的全部方言差异此后都落在"数据 + 适配层"，生成器本身零方言知识。

## ADR-NQ-002：单泛型轴（Hooks 单载体双 trait）——✅ 2026-09-03

**决策**：`Hooks` 同时实现 `NQuadsActions` + `NQuadsEffectHandler`，引擎只持一个实例；
泛型只落在词法器 `L`（`LexerSource`）上；C 侧 `engine_c.mbt` 薄适配复用同一 loop 与 `token_to_event`。

**被否**：第二泛型轴（actions 也泛型化）——调用面复杂度翻倍且无当前需求。

**后果**：`step[A : NQuadsActions]` 保持泛型，使 **quicktest 包**能以自有实现跨包接入
（后来成为 `pub(open)` 的载荷面，见 `src/rdf/adr.md` ADR-9）。

## ADR-NQ-003：双词法器同字母表；C 版为标准对齐源——✅ 2026-09-03

**决策**：`Lexermoon`（Moon）与 `Lexerc`（C FFI）同 Token 型、同宽、同 span 口径（全词含定界符）；
`token_to_event` 映射共用、零补偿透传；**词法语义以 C 版为标准对齐源**；EOF 协议统一
（结尾 `Some(EOF(pos))`，`None` 仅异常分支）。

**验收**：`lexerc_parity_wbtest` 逐 token pin（72 段 mismatch 0）。

## ADR-NQ-004：套件 pin 策略（合并语料 + 段标记切段）——✅ 2026-09-03

**决策**：rdf-n-quads 用 `all_combined.nq` 单文件 + `# >>> 段标记`切段，**运行时零目录遍历**；
ntriples 走"循环读文件 + 整合文件对比"双口径；`read_context` 提供错误上下文诊断。

**理由**：单文件切段对 W3C 合并语料天然稳定，且避免目录遍历在不同 FS 上的行为差异。

## ADR-NQ-005：bench 双件（分层开销 + 三阶段）——✅ 2026-09-03

**决策**：`fsm_bench`（Token→Event / step 重放 / 完整引擎三段）+ `nquads_bench_wbtest`
（三阶段 + C Lexerc/引擎/SliceParser 对比六段计时）并存；前者供跨方言对照，后者供词法器对比。

## ADR-NQ-006：`const.md` 勘误回灌——✅ 2026-09-03

**决策**（按实际代码修正宪法表述）：① "Complete/done 死码一并移除"的准确说法 = **表中无转移产出
`Done`，但变体保留**（三件套之一），loop 保留 `Done → return None` 分支；② "loop 按 SkipError 口径记录"
= 手写版遗留称呼，现为 `LoopPolicy::recover`；③ 分层清单补全 `actions.mbt` 与 materialize/serialize
两层；④ "`EmitQuad` 携带 `ResetScope`"的含糊表述改为 **`EmitQuad(ResetScope)` 变体携参**。

## ADR-NQ-007：词法事件槽位**不拆**（与 n3 的分叉口径）——✅ 2026-09-05

**背景**：三 term 事件（`NQuadsBlankNode` / `NQuadsLiteral` / `NQuadsPrefName`）是否拆 `(span, span)`。

**决策**：**不拆**——词法无脑扫出的词项内部分界（如引号体 / `@lang` / `^^dt`）由
`validate_literal` 单点裁决并即弃，**不进事件与槽位形状**。

**理由**：① nquads 物化层字节保真直写，无"需要精确 lang/dt span"的需求；② 拆事件会穿透
`span_of_event → normalize → 表 payload → QuadSpan → QuadEmit` 五道签名，违"结构判断不提前回词法/归位层"。
**对照**（为何 n3 拆了）：n3 物化要发 `langString`，`N3Literal(span, lang)` 双载荷是其物化口径逼出来的。

**演进位**：将来若需两段内容，把门卫升级为 splitter（`validate_literal -> Result[LiteralSplit, …]`），
词法事件形状与三层边界不动。

**关联**：细则与证据见 `spec.md` §1–§3；2.0 数据面与门见 `src/rdf/adr.md`（ADR-1…ADR-9）。

## ADR-NQ-008：目录瘦身（遗留计划件 / 空件 / v1 输入件）——✅ 2026-09-13

**决策**（定位 B 冻结样本下的"只清障、不改语义"）：
1. `plan-retire-owned-terms.md`（94 行，owned term 退役方案，**早已执行完**）——**删除**，git 历史留档；
2. `quicktest/todo.md`（0 行空件）——**删除**；
3. `test_nquads.toml`（326 行 v1 遗留输入件；生产链早已走 `domain2/nquads_*`）——**归档**到
   `bak/gen_nquads/`（与 trig 的 `bak/gen_trig/` 同规；`src/md/*` 两处引用已在 R-N1 标为"旧输入件"）。

**依据/验收**：`gen_nquads` **124/124**、模块 330/330、`moon check` 干净；包目录只留实现 + 测试 + 五卷 + `spec/const/adr/todo/ctx`。

## ADR-NQ-009：性能口径定版——正式数字 = native + `--release` + `Lexermoon`——✅ 2026-09-14

**背景**：词法性能役 P1 实测出两条与既有假设相反的事实：

1. 既有对外数字**全部取自 debug 档**；同一份代码 release 快 **4.6×**（10k 总计 34.07 → 7.41 ms）；
2. release 下**纯 MoonBit `Lexermoon` 反超 C FFI `Lexerc` ~2×**（10k：1505 µs / 33.2M tok/s vs
   3039 µs / 16.5M tok/s）——每 token 一次跨界调用（外加 12 字节清零 + 3×`read_int32` 回读）
   比 C 侧扫描省下的时间更贵。

**决策**：

1. 性能结论一律以 **`--target native --release`** 为正式口径；debug 数字只作代码形状回归；
2. 基准默认词法器 = `Lexermoon`（各目标都有）；`Lexerc` 降为**对照**（native-only，parity 门与
   `lexer_bench_wbtest.mbt` 保留），不再是 `src/bench` 的计时路径；
3. `src/bench/nquads-benchmark` 的"词法探针按目标二选一"退役——它是为"FFI 更快"假设搭的桥，
   假设已证伪（ADR-NQ-003 的"C 版为标准对齐源"仍成立：那是**语义**对齐，不是性能排序）。

**后果**：nquads 与 Rust Oxigraph 的关系由"慢 1.6×"改为"**快 ~2.7×**"（同口径 release：10k
7.41 ms vs 21 ms，且我们多做轻验 + 深验四门 + 物化、不建图）。

**关联**：数字与复现命令见 `todo.md` §5、`ctx.md` §7；对外口径见 `src/bench/README.md`；
测量仪 `lexer_bench_wbtest.mbt`。

## ADR-NQ-010：P1 三项词法微改造判定——实测负收益，全部回退——✅ 2026-09-14

**背景**：P1 立项时按"扫描层可优化"假设列了三项改造，逐项在 release 下做三轮交错 A/B。

| 改造 | 假设 | 实测（release，10k 纯词法，三轮交错中位） | 判定 |
|---|---|---|---|
| `pos` 局部化（每字节不碰字段） | 字段访存是热循环瓶颈 | 1505 → 1694 µs（**−15%**） | 回退 |
| `<` 分派提前 + `v[pos+1]` 一次读 | N-Quads 里 `<` 占多数，可省判别 | 1505 → 1620 µs（**−7.6%**，三轮一致） | 回退 |
| 终止字节查表（256 项） | 5 次比较换 1 次查表 | 扫描段 552 → 530 µs（−4%，噪声级） | 不采纳 |

**决策**：`lexer_mbt.mbt` **零改动**入库；三项负结果留档，防后续重复尝试。

**理由**：release 后端已把字段访问与边界检查处理好；现有扫描 ≈ 0.55 ns/byte（约 1.5 cycle/byte）
已近上限，改形状只会破坏代码布局。

**下一步杠杆**（另立役，跨方言）：词法成本 **63% 是"造 Token"**；微基准显示每 token 表示税
≈ **8.1 ns**（tuple `(Int,Int)` 4.8 + enum 变体 3.2；`Option` 0.1 = 免费），占 Lexermoon 单 token
成本 ~27%。释放它要把 `pub type Span` 与 `Token` 载荷从 tuple 换成紧凑表示（packed Int 或双 Int
字段）——**跨 `gen_nquads / gen_trig / gen_n3v2` 的原子改动**（含 parity 门），不在定位 B 内单做。
