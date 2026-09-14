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
| C-N1 | `src/fsm/test_nquads.toml` 已不存在，`fsm_out/nquads_fsm.toml` 为唯一 IR | 无功能影响 | **已收口**：`src/md/*` 两处锚点改现代口径（R-N1） |
| C-N2 | 遗留件（`nquads.bak` 8.5 KB、`test_nquads.toml` 326 行 v1 输入、`plan-retire-owned-terms.md` 94 行已执行方案、`quicktest/todo.md` 空件） | 目录噪声 | **已清（2026-09-13，ADR-NQ-008）**：两件归档 `bak/gen_nquads/`、两件删除（git 历史留档） |
| C-N3 | `quick_machine` 双生成器并存（`gen_check/*` 旧词表） | 生成链重复面 | 归并属"另役"；本样本不动 |
| C-N4 | ~~MoonBit 词法器落后 C 侧 2.3–2.6×~~ | 性能 | **已收口（P1 役，2026-09-14）**：该结论是 **debug 档假象**；release 下 Lexermoon **反超** C FFI ~2×。见 §5 与 ADR-NQ-009 |
| C-N5 | ~~`src/md/*` 以 `test_nquads.toml` 为产品锚点~~ | 文档漂移 | **已收口**（R-N1，2026-09-13）：两处改指 2.0 事实源与再生配方 |
| C-N6 | `types.mbt` 桩守卫依赖 CLI 首跑 bootstrap | 生成面维护债 | 与 C-N3 同批处置 |
| C-N7 | 旧 `todo.adr.md` 的 §2/§3 正文 | 文档完整性 | **已搬**入 `spec.md` §4（R-N4，2026-09-13） |

## 3 明确不做（定位 B 的边界，防反复拉锯）

- **不做**：命名回灌（`Hooks → NQuadsActionsImpl`）、公共面收窄（`.mbti` 543 行 / 203 pub 行）、
  测试归位（内联 test）、RDF 1.2 开关改名（`scalar_only` 保持冻结参数名）。
- **只做**：**钉门**（IR/产物）、**清障**（挡门的重复件，如停役数组腿）、**修文档锚点**（C-N5）。
- **性能役例外**（2026-09-14 用户开役）：只允许"以实测为准"的**测量与口径修正**；
  词法/协议**语义不动**（P1 终态：`lexer_mbt.mbt` 零改动）。跨方言的表示层重构另行立项。

## 4 执行记录（滚动追加）

| 日期 | 事 | 范围 | 结果 / 验收数字 | 备注 |
|---|---|---|---|---|
| 2026-09-13 | **T21 立门** | nquads 产物黄金门 + `[parser] actions_trait_open` 数据驱动 + 数组腿退役 | `src/rdf` 23/23；`gen_nquads` 124/124；quicktest 照常编译 | `src/rdf/adr.md` ADR-9；立门首日抓到 `pub(open)` 漂移 |
| 2026-09-13 | **卷面整理** | `todo.adr.md` → `adr.md`（只留决策）；新建本卷 + `ctx.md`；白名单补 `!src/gen_nquads/*.md` | 文档改动，门未动 | 与 gen_trig 五卷口径对齐 |
| 2026-09-13 | **软项清理** | R-N1 文档锚点（`src/md/*` 两处）+ R-N2 `.bak` 归档 + R-N4 旧卷正文搬入 `spec.md` §4 | 文档/文件整理，门未动：`gen_nquads` 124/124、模块 330/330 | ctx 三项转 ✅；`adr.md` 去向表更新 |
| 2026-09-13 | **目录瘦身** | `plan-retire-owned-terms.md` / `quicktest/todo.md` 删除；`test_nquads.toml` 归档 `bak/gen_nquads/` | 门未动：`gen_nquads` 124/124、模块 330/330 | ADR-NQ-008；另修 `src/rdf` trig 数组留档删除（ADR-12） |
| 2026-09-14 | **P1 立测量仪** | 新建 `lexer_bench_wbtest.mbt`（1k/10k 纯词法双词法器对照，native-only）+ `moon.pkg` targets 登记 | release 基线（10k）：Lexermoon 1505 µs / Lexerc 3039 µs | 见 ADR-NQ-009；debug 同跑 14027 µs |
| 2026-09-14 | **P1 口径纠偏** | bench 正式口径改 `--target native --release` + `Lexermoon`；`src/bench` 词法探针二选一退役 | 10k 总计 debug 34.07 → release **7.41 ms**（4.6×）；同口径比 Oxigraph 21 ms **快 2.7×** | `src/bench/README.md` 同步改写 |
| 2026-09-14 | **P1 微改造判定** | 三项热路径改造 A/B（pos 本地化 / `<` 优先分派 / 表驱动扫描） | release 实测 **−15% / −7.6% / −4%** ⇒ 全部回退 | ADR-NQ-010；负结果留档防反复 |
| 2026-09-14 | **P1 验收** | 门全绿 | `gen_nquads` 124/124（debug）/ **137/137（native release）**；`gen_n3v2` 117/117；`gen_trig` 80/80；模块 330/330、native 346/346；外层 `n3gen` 12/12 | parity 门（72 段 mismatch 0）未动 |

---

## 5 性能役 P1（Lexermoon，2026-09-14）

**结论**：`C-N4` 的"落后 C 侧 2.3–2.6×"是 **debug 档假象**。三条事实（10k 真实语料 / native）：

| # | 事实 | 数字 |
|---|---|---|
| P1-F1 | debug / release 差 **4.6×**，此前全部对外数字取自 debug | 总计 34.07 ms → **7.41 ms**；验证段 32.2 → 5.99 ms；引擎 16.2 → 3.2 ms |
| P1-F2 | release 下**纯 MoonBit Lexermoon 反超 C FFI Lexerc ~2×** | 1505 µs（33.2M tok/s）vs 3039 µs（16.5M tok/s） |
| P1-F3 | 词法成本 **63% 是"造 Token"**，扫描只占 37% | 纯扫描 543 µs vs 造 token 1483 µs |

**token 表示税**（微基准，release，50 万次）：tuple `(Int,Int)` **+4.8 ns**、enum 变体 **+3.2 ns**、
`Option` **+0.1 ns**（免费）⇒ 每 token ≈ **8.1 ns** 纯表示开销，占 Lexermoon 单 token 成本 ~27%。

**正式口径与复现**：

```sh
moon test --target native --release src/gen_nquads -f "*词法役 P1*"       # 双词法器纯词法对照
moon run src/bench/nquads-benchmark --target native --release src/bench/test_10000.nq
```

**下一步（另立役，跨方言，需授权）**：把 `pub type Span` 与 `Token` 载荷从 tuple 换成紧凑表示，
释放那 63% —— 属 `gen_nquads / gen_trig / gen_n3v2` + parity 门的**原子改动**，不在本样本冻结边界内。

---

## 6 指标口径样板（quicktest，2026-09-14）

`src/ttl/src/gen_nquads/quicktest/` 定为 quick machine 的**指标口径样板**——三方言生成后照此对齐。
事实源：`quicktest/metrics.mbt` 文件头 + 下表。

| # | 指标 | 门槛（"怎么算够"） | 事实源 / 门 |
|---|---|---|---|
| ① | 命令覆盖 | 全部**可达**命令名（转移表有出边）= 8 个；不可达（`PrefName`/`EOF`）显式标"不适用" | `runner.coverage_gate_config` → `required_command_names` |
| ② | 语义路径覆盖 | label 分档 `resp:continue` / `resp:emit` / `resp:emit:default` / `resp:emit:graph` 全覆盖 | `nquads_quicktest.quick_state_machine(label=)` + `required_labels` |
| ③ | 转移覆盖 | 5 状态 × 10 命令 = **50 对逐对判定**：合法 14（目标态 + 槽位不变量）、非法 36（Error(0) + 模型不推进） | `metrics.mbt` 转移覆盖测试（数据化镜像表） |
| ④ | 收缩收敛 | 注入"系统丢图名"后 `shrinks > 0`；**已知边界**：删命令收缩无效（序列受转移表约束），反例长度不缩短 | `metrics.mbt` 收缩测试 + 收缩机制直测 |
| ⑤ | 重映射 | `remap_command` 恒等保留（含非空 scope）；它是 ④ 能进行的前提（返回 None 会否决整个候选） | `metrics.mbt` remap 测试 |

**跑法**：`moon test src/gen_nquads/quicktest`（**21/21**）。

**两条登记边界**（是口径，不是缺陷）：

- `resp:error` 只出现在未定义转移，而生成器被 valid 过滤 ⇒ 不列进 `required_labels`（列进去必红）。
- 反例"长度缩短"在本 FSM 不可达：qcs 的收缩候选只有"删一条"与"用户 shrinker 替换"两类，
  而删掉任何中间命令都会让后续命令在前置条件上非法，`shrink_and_validate` 直接否决。

**下一步（生成器侧 G7，未开）**：把 `metrics.mbt` 这四张门做成**发射模板**，随
`business.mbt` / `runner.mbt` 一并产出；否则每个方言都要手抄一遍口径。
