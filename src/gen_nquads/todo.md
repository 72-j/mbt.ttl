# gen_nquads 待办与战役路线（todo）

版本：v1.0.0（2026-09-13 立卷；自 `todo.adr.md` 拆出后更名 `adr.md`，本卷为新建）

**定位（用户定，2026-09-13）**：nquads = **B 冻结样本**——**不演进功能、不做命名与公共面迁移**；
它的价值是"FSM 生成链路第一样板 + 行为对照基线"。因此本卷不做大路线图，只列**资产、债务与
明确不做的边界**；确有必要的动作走"钉门/清障"两档，且**不改产物语义**。

**时效与定位**（`bangto/world/const.md` §5.1/§5.2）：临时账本；只对 `src/ttl/src/gen_nquads/` 有效；
**不记决策**（→`adr.md`）、**不记红线**（→`const.md`）、**不重复结构事实**（→`spec.md`）。

卷面分工：`const.md` 红线 / `spec.md` 结构事实与已验证口径 / `adr.md` 决策录 / 本卷路线与账本 /
`ctx.md` 整改上下文（锚点·证据·动作·验收·风险）。

---

## 1 现状可信面（冻结样本的资产，不动）

| # | 资产 | 证据 |
|---|---|---|
| A1 | 五层管线：Lexermoon/Lexerc → token_to_event → `step`（生成表）→ SliceParser（组装+轻验）→ 物化 → 序列化 | `spec.md` §2；`engine.mbt` |
| A2 | 双词法器同 Token 字母表（Moon/C 逐 token pin、span 全词含定界符） | `lexerc_parity_wbtest.mbt` |
| A3 | 单一实现面：RDF 1.2 逃逸检查与 n3v2/trig 共用 `@nquads.validate_escapes_unicode`（`scalar_only` 参数） | `validate_helper.mbt:530` |
| A4 | 2.0 数据面：`src/rdf/domain2/nquads_{base,domain}.toml` → `fsm_out/nquads_fsm.toml` → 产物 | `src/rdf/spec.md` §1/§2 |
| A5 | 门：IR **三腿对拍** + 反门 12 条 + **产物黄金门**（`nquads 产物黄金门`，ts `1788844502518`） | `src/rdf/adr.md` ADR-9 |
| A6 | 跨包扩展点真实存在：`pub(open) trait NQuadsActions`，quicktest 包以自有实现接 `step` | `quicktest/system.mbt:59-92`；生成器侧数据键 `[parser] actions_trait_open` |
| A7 | 套件 oracle：rdf-n-quads 89/89、rdf12-nt 29/29、rdf12-nq 27/27、ntriples 72/72、对比 72 段 mismatch 0 | `rdf_suite_wbtest.mbt` |

## 2 债务索引（冻结样本下"只登记、不改语义"）

| C | 事实 | 影响 | 处置 |
|---|---|---|---|
| C-N1 | `src/fsm/test_nquads.toml`（旧 v1 数组口径的快照）**已不存在**，`fsm_out/nquads_fsm.toml` 为唯一 IR | 无功能影响；文档锚点失效 | 见 C-N5（文档） |
| C-N2 | `nquads.bak`（8.5 KB，2026-09-04 手抄时代残留） | 目录噪声 | 归档或删除（冻结样本不阻塞） |
| C-N3 | `quick_machine` 双生成器并存（`gen_check/*` 旧词表） | 生成链重复面 | 归并属"另役"；本样本不动 |
| C-N4 | MoonBit 词法器落后 C 侧 2.3–2.6× | 性能 | 借用 trig 的词法优化役结果；本样本不单独做 |
| C-N5 | `src/md/FSM-toml-const.md`、`src/md/Tensor-evolution.md` 仍以 `test_nquads.toml` 为"mutable 产品"锚点 | 文档漂移 | 已在 `src/rdf/adr.md` ADR-9 登记；改文档属独立小役 |
| C-N6 | `types.mbt` 桩守卫依赖 CLI 首跑 bootstrap | 生成面维护债 | 与 C-N3 同批处置 |
| C-N7 | 旧 `todo.adr.md` 的 §2 规格 / §3 伪代码正文**待搬** `spec.md` | 文档完整性 | `ctx.md` R-N4（低风险机械搬移） |

## 3 明确不做（定位 B 的边界，防反复拉锯）

- **不做**：命名回灌（`Hooks → NQuadsActionsImpl`）、公共面收窄（`.mbti` 543 行 / 203 pub 行）、
  测试归位（内联 test）、RDF 1.2 开关改名（`scalar_only` 保持冻结参数名）。
- **只做**：**钉门**（IR/产物）、**清障**（挡门的重复件，如停役数组腿）、**修文档锚点**（C-N5）。

## 4 执行记录（滚动追加）

| 日期 | 事 | 范围 | 结果 / 验收数字 | 备注 |
|---|---|---|---|---|
| 2026-09-13 | **T21 立门** | nquads 产物黄金门 + `[parser] actions_trait_open` 数据驱动 + 数组腿退役 | `src/rdf` 23/23；`gen_nquads` 124/124；quicktest 照常编译 | `src/rdf/adr.md` ADR-9；立门首日抓到 `pub(open)` 漂移 |
| 2026-09-13 | **卷面整理** | `todo.adr.md` → `adr.md`（只留决策）；新建本卷 + `ctx.md`；白名单补 `!src/gen_nquads/*.md` | 文档改动，门未动 | 与 gen_trig 五卷口径对齐 |
