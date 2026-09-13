# gen_nquads 决策录（adr）

版本：v1.0.0（2026-09-13 由 `todo.adr.md` 更名并收敛为**决策录**；对齐 gen_trig 五卷口径）

**卷面分工**：本卷只讲**为什么这么决定**；红线在 `const.md`、结构事实与已验证口径在 `spec.md`、
路线与账本在 `todo.md`、整改上下文在 `ctx.md`。
**本包定位 = B 冻结样本**（用户定 2026-09-13）——决策录此后只增不改，演进类决策不再产生。

**编号**：`ADR-NQ-nnn`（方言前缀制，与 `ADR-TRIG-nnn` 同规）。

**历史卷内容去向（更名时整理，防静默丢失）**：
§1 宪法 → `const.md`（已在，含勘误回灌）；§2 规格 / §3 伪代码 → `spec.md`（**待搬**，见 `ctx.md` R-N4）；
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
