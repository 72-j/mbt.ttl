# gen_nquads 整改上下文（ctx）

版本：v1.0.0（2026-09-13 立卷；**锚点行号为 2026-09-13 实测**）

**时效与定位**：临时账本——某项整改"怎么做"的工作上下文；只对 `src/ttl/src/gen_nquads/` 有效；
**不记决策**（→`adr.md`）、**不记红线**（→`const.md`）、**不重复结构事实**（→`spec.md`）。
**本包定位 = B 冻结样本**（用户定 2026-09-13）：不演进功能、不做命名/公共面迁移；
本卷只承载"钉门 / 清障 / 修文档锚点"三类动作的上下文（见 `todo.md` §3 边界）。

---

## 1 坐标与基线

```
外层仓 /home/thy/moonttl
├── src/rdf/domain2/nquads_{base,domain}.toml   ← 2.0 数据面（唯一事实源）
├── src/rdf/fsm_out/nquads_fsm.toml             ← IR（v1 形态，codegen 输入契约）
├── src/fsm/cmd                                 ← 再生入口（`--ts` 钉头横幅）
└── src/ttl/src/gen_nquads/
    ├── nquads.mbt        ⚠ 生成物（禁手编）；入库形 = `moon fmt(生成器原始形)`
    ├── engine.mbt / actions.mbt / parser_slice.mbt / validate_helper.mbt
    ├── materialize_quad.mbt / serialize_nquads.mbt / lexer_mbt.mbt / lexerc_ffi.c
    └── quicktest/        （独立包；`impl NQuadsActions for EngineActions` ⇒ `pub(open)` 的载荷面）
```

| 项 | 值（2026-09-13 实测） |
|---|---|
| 门 · IR | `src/rdf` 三腿对拍（2.0 编译 ≡ 管线路由 ≡ 盘上基线）+ 反门 12 条 |
| 门 · 产物 | `nquads 产物黄金门`：钉 ts `1788844502518` + `moon fmt` ≡ `nquads.mbt` 逐字节 + 强幂等 |
| 测试 | `gen_nquads` **124/124**；`quicktest` 编译通过；模块 330/330 |
| 套件 | rdf-n-quads 89/89、rdf12-nt 29/29、rdf12-nq 27/27、ntriples 72/72、对比 72/72 mismatch 0 |
| 公共面 | `.mbti` **543 行 / 203 pub 行**（冻结：不做收窄） |
| 再生配方 | `moon run src/fsm/cmd -- src/rdf/fsm_out/nquads_fsm.toml --ts 1788844502518 -o <产物>` → `moon fmt <产物>` |

## 2 契约成员（注解）

| 成员 | 声明 | 实现 | 备注 |
|---|---|---|---|
| `NQuadsActions`（语义落点） | `nquads.mbt`（**`pub(open)`**，由 `[parser] actions_trait_open` 数据驱动） | `actions.mbt` 的 `Hooks`；**quicktest 包**的 `EngineActions`（跨包） | `(open)` 是载荷面（ADR-9），不是残留 |
| `NQuadsEffectHandler`（效果面） | `nquads.mbt` | 生成默认（`handle_*`） | 引擎当前自行解释效果意图（与 trig T11 前的形态相同）；**冻结样本不接活** |
| `NQuadsLoopPolicy`（控制流面） | `nquads.mbt` | `engine.mbt` | 世界词表正名为 `Supervisor`；按定位 B **不改名** |

## 3 术语（本包私有）

| 词 | 含义 |
|---|---|
| 定稿样板 | 历史上手写、现为 check-in 生成物的 `nquads.mbt`（首个样板，trig 由其推广） |
| 停役数组腿 | `compile_nquads_arrays_toml()`（役13 数组口径快照）——ADR-9 后退役，仅留档 |
| `scalar_only` | `validate_escapes_unicode` 的 RDF 1.2 转义严格参数（nquads 侧**冻结名**；n3v2/trig 的 `rdf12` 由它承载） |

## 4 存活项上下文

### R-N1 文档锚点修复 `[✅ 收口 2026-09-13]`

- 目标：消除 `src/md/*` 对已不存在文件的引用。
- 锚点：`src/md/FSM-toml-const.md:6`（`src/fsm/test_nquads.toml` 已删）、`src/md/Tensor-evolution.md:12`
  （把 `src/gen_nquads/test_nquads.toml` 当 mutable 产品再生命令）。
- 动作：二选一——① 改为指向 2.0 配方（domain2 → fsm_out → CLI `--ts` → `moon fmt`）；
  ② 标注"历史快照，非事实源"。
- 验收：`rg "test_nquads.toml" src/md` 命中处均已改口径；无悬空引用。
- 风险：无（纯文档）。

### R-N2 `nquads.bak` 归档 `[✅ 收口 2026-09-13]`

- 锚点：`src/gen_nquads/nquads.bak`（8.5 KB）。
- 动作：归档到 `bak/` 或删除（git 历史即留档）。
- 验收：`ls src/gen_nquads/*.bak` 为空。

### R-N3（不做，登记）命名 / 公共面 / 测试归位

- 内容：`Hooks → NQuadsActionsImpl`、`.mbti` 203 pub 行收窄、内联 test 归位。
- 处置：**定位 B 明确不做**（见 `todo.md` §3）；若将来 nquads 重新"跟随主线"，本条即为开工清单。

### R-N4 旧卷正文搬移 `[✅ 收口 2026-09-13]`

- 背景：`adr.md` 更名时，旧 `todo.adr.md` 的 §2 规格 / §3 伪代码去向已登记为"待搬"
  （`adr.md` 卷首去向表）——现有 `spec.md` 只含数据面 / 词法事件槽位 / 演进位三节。
- 动作：把旧 §2（五层管线规格、词法层表、适配层、引擎表、组装+轻验、物化+序列化）与
  §3（loop `next` / `materialize_quad` 槽位路由 / TT 拆壳三段伪代码）按现有口径搬进 `spec.md`。
- 验收：`spec.md` 覆盖 2.0 前记录的全部结构事实；`adr.md` 卷首"待搬"字样删除。
- 风险：纯文档机械搬移；行号锚点按当日实测刷新。

## 5 检查清单（本包任何改动前）

- [ ] 确认改的是**生成面**（`src/rdf/domain2/*`、`src/fsm`）还是**装配层**（本包 `.mbt`）。
- [ ] 生成面改动后：`moon test src/rdf`（三腿 + 反门 + **产物黄金门**）→ 按配方再生 → `moon fmt`。
- [ ] `moon test src/gen_nquads` 124/124 且套件数字（89/29/27/72）不变。
- [ ] `moon check src/gen_nquads/quicktest`（`(open)` 载荷面的直接哨兵）。
- [ ] 手编产物 `nquads.mbt` **禁止**：入库形 = `moon fmt(生成器原始形)`。

## 6 锚点索引（2026-09-13 实测）

| 主题 | 锚点 |
|---|---|
| 契约三成员 | `nquads.mbt:146`（Actions，`pub(open)`）、`:245`（EffectHandler）、`:129`（LoopPolicy） |
| 主循环 | `engine.mbt:290`（`step` 调用）、`:320`（便捷入口 `rdf12?`）、`:157`（`from_bytes`） |
| 校验层开关 | `parser_slice.mbt:8/17`（`rdf12`）、`validate_helper.mbt:427/491`（langdir）、`:530`（`scalar_only`） |
| 物化 / 序列化 | `materialize_quad.mbt`（构造与槽位路由）、`serialize_nquads.mbt`（旋钮 + round-trip） |
| 跨包扩展点 | `quicktest/system.mbt:59-92`（`impl NQuadsActions for EngineActions`） |
| 门 | `src/rdf/nquads_domain_toml_gen.mbt`（三腿 + **产物黄金门**）、`src/rdf/adr.md` ADR-9 |

## 7 P1 词法性能役上下文（2026-09-14）

**目标**：Lexermoon（纯 MoonBit 词法器）提速，并给出可复现的性能口径。

**锚点**

| 主题 | 锚点 |
|---|---|
| 测量仪（本役新立） | `lexer_bench_wbtest.mbt`（1k/10k 纯词法双词法器对照，native-only） |
| 被测对象 | `lexer_mbt.mbt:247`（`Lexermoon::next`，**终态零改动**）、`lexer_mbt.mbt:175`（`utf8_name_advance`）——**2026-09-24 重钉**：P2 刀 a 重排后原 `:198`/`:129` 已漂（锚点门首跑抓到）；并改**全形**写法（弃 `:NNN` 缩写，缩写不在门视野内） |
| 对照 | `lexerc.mbt:124`（`Lexerc::next`：清零 12B + FFI + `read_int32`×3） |
| 管线口径 | `src/bench/nquads-benchmark/main.mbt`（native + release 正式口径） |

**证据（release / native / 10k 真实语料）**

| 项 | 数 |
|---|---|
| 管线总计（Lexermoon） | 7.41–7.49 ms（≈1.34M quads/s） |
| 管线总计（同码 debug） | 34.07 ms（4.6× 慢） |
| 纯词法 Lexermoon / Lexerc | 1505 / 3039 µs（33.2 / 16.5 M tok/s） |
| 纯扫描（无 Token 构造） | 543–552 µs（≈0.55 ns/byte） |
| 造 Token 税 | 931–986 µs（占词法 63%） |
| 每 token 表示税（微基准） | 8.1 ns = tuple 4.8 + enum 3.2（`Option` ≈ 0） |
| 同口径对手 | Rust Oxigraph 21 ms（含建图）⇒ 我们快 **~2.7×** |

**动作**：① 立测量仪；② 口径纠偏（release + Lexermoon，`src/bench` 探针二选一退役）；
③ 三项热路径改造 A/B 后**全部回退**（详见 ADR-NQ-010）；④ 门全绿复核。

**验收**：`gen_nquads` 124/124（debug）、137/137（native release）；parity 门 72 段 mismatch 0；
`gen_n3v2` 117/117；`gen_trig` 80/80；模块 330/330、native 346/346；外层 `n3gen` 12/12。

**风险 / 边界**：`lexer_mbt.mbt` 零改动 ⇒ 词法语义风险为零；口径变更只影响文档与脚本。
**未做（另立役）**：`Span`/`Token` 表示层紧凑化（跨三方言原子改动）。
