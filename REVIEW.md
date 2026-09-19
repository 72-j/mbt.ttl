# MoonTTL 评审结论卷（入库）

版本：**v1.0**（2026-09-19）
定位：**评审结论与现状门的入库快照**。红线在 `const`、决策在 `adr`、结构事实在 `spec`；
本卷只收录"跨人需要看到"的结论与门清单，**不是**新判据的来源（判据见各 `const` 与 CI 文件）。
配套活账（不入库、随工作树走）：`todo.md`（本轮全部收账的原始账）；世界卷：`bangto/world/const.md` §6。

---

## 1 现状门清单（两仓，2026-09-19 实测）

| 仓 | 门 | 判据 | 现状 |
| --- | --- | --- | --- |
| 子仓 `thy1016/moonttl` | 编译告警 | `moon check --deny-warn` | **0 条** |
| 子仓 | 格式 | `moon fmt --warn`（**全路径，无豁免**） | **0 offender** |
| 子仓 | 公开面漂移 | `moon info` 后 `git status --porcelain -- '*.mbti'` | **空** |
| 子仓 | 行覆盖棘轮 | `coverage-baseline.txt`（floor 口径） | **871‰ = 基线**（冷跑两次同值） |
| 子仓 | 默认臂计数 | `TODO(P0):` 计数（`model_exec.mbt`） | **trig 30 / n3v2 49**（与 CI 常数一致） |
| 子仓 | **可达命令名覆盖** | 分母 = BFS 派生；分子 = 执行记录并集；缺口清零 | **trig 25/25、nquads 8/8、n3v2 40/40，缺口 0** |
| 子仓 | 测试 | 本机 | **436/436** |
| 主仓 `thy7/BitBang` | 编译 + 测试 | `moon test --deny-warn` | **285/285**，`check --deny-warn` 0 |
| 主仓 | 格式 | `moon fmt --warn`（**全路径，无豁免**） | **0 offender** |

两条格式豁免（`src/fsm/gen_check/gen.mbt`、`src/gen_n3v2/quicktest/`）已于本轮**清零**（§3 N5）。

## 2 役序状态（评审回灌 → 落地）

| 役 | 内容 | 状态 |
| --- | --- | --- |
| 1 | `--deny-warn` 归零（两仓） | ✅ |
| 2 | 公开面收口（`TrigProbe` 6 → 3 面） | ✅ |
| 3 | trig 随机门多种子 | ✅ |
| 4 | 随机门反例固定成脚本（16 步） | ✅ |
| 5 | 单一数字源（ctx 只留指针） | ✅ |
| 6 | 默认臂双半门（名单 + CI 计数） | ✅ |
| 7 | 引擎侧独立普查（trig 1224 / n3v2 2214 对，0 分道） | ✅ |
| 8 | 外仓门常驻（CI + 格式门 + 整包 check 取代子进程编译验证） | ✅（宿主是否真跑 Actions **待观测**，见 N6） |
| 9 | 生成器模板硬化（按需 helper / 死门 / 手抄名单清零） | ✅ |
| 10 | 三表 ⟷ 引擎对拍（**集合级** + 负控；值级未做） | ✅（集合级） |
| 11 | 物化守卫统一（标记 + fail-loud；CLI 认 `.hand-maintained`） | ✅ |
| 12 | 同形断言强度对称（多枚/压帧臂 + 实例 `list_next_arm` 逐 token golden） | ✅ |
| 13 | n3v2 四钉（@arm / 留位 / token golden / 负向断言） | ✅ |
| 14 | n3v2 两门（路径驱动覆盖率门 + 多种子随机门 + 结构钉） | ✅ |
| 15 | R-17/R-18 缺口清偿（债点 0 / 违例 0；余深片权重可放宽） | ✅（大体） |

## 3 评审发现（N 系列）状态

| 编号 | 发现 | 状态 |
| --- | --- | --- |
| N1 | CLI（`quick-gen quick`）不认 `.hand-maintained` | ✅ 已收口（标记在且无 `--force` ⇒ 拒绝写盘 + 非零退出） |
| N2 | md 物化不经格式化通道（每跑测试脏工作区） | ✅ 已收口：写盘走 `write_through_fmt` + 强幂等门 |
| N3 | 冷缓存掩盖 `--deny-warn`（主仓 6→28、内仓 9→17） | ✅ 已写进纪律（冷缓存复测） |
| N4 | 役 12 断言强度仍是子串级 | ✅ 已收口：逐 token golden + 两条负控 |
| N5 | 两条"格式豁免"是两个口径来源 | ✅ 已收口：**勘误**——不是"两套口径"，是 n3v2 实例**没跟工具链格式化**（trig 实例 scratch-fmt 零变化；n3v2 `model_exec` 现行口径 1119→4659 行）。已统一重排，两仓格式门**无豁免** |
| N6 | CI 首跑未观测 | ⬜ **未闭**：gitlink 是 SPA，无匿名 API/token，本机无法读取远端 run 状态 |
| N7 | 活账不入库、结论只在本地 | ✅ **本卷即收口**：跨人结论入 `REVIEW.md`（本文件）；活账继续作本地原始账 |

## 4 五类危险病（复议后现状）

| 病 | 现状 |
| --- | --- |
| 假绿 | 大幅下降：变异实证覆盖 役 7（引擎侧普查抓状态漂移）、役 10（集合门负控）、役 12（旧子串门 vs 新金串）、可达覆盖门（缺口清零 + 分母棘轮，两条负控） |
| 假红 | 基本无；新增"冷缓存掩蔽"属假绿方向（N3），已入纪律 |
| 纸上红线 | 大幅收紧：CI 五门 + 两仓漂移门 + 物化守卫（N1）+ md 格式通道（N2）+ 两条豁免清零（N5）；剩余纸面：**值级三表对拍**、N6 观测 |
| 账本分叉 | 已收口：数字单一源（ctx 指针化、基线文件唯一）；本卷 = 结论入库；活账仍为本地原始账（决策已知） |
| 靠人记 | 下降：默认臂有门、三表有集合门、普查有引擎真件；**剩余：三表值级仍靠人抄**（役 10 值级项） |

## 5 未闭项（跨人可见）

1. **数据面 ⟷ 引擎 的值级对拍**（役 10 值级；2026-09-19 前置确认收窄口径，见活账 §AM）：
   缺的是 **TOML 数据面**（`[actions].returns/writes/frame`、`[effects]`、`[[scope_chains]]`）与**引擎真件**的值级对拍——
   R-20 的"值级"（**模型 ⟷ 引擎**）已收口（六族清偿、台账 0）。
   现状：**n3v2 首片已落地**（2026-09-19，见活账 §AN）：外仓 `actions_truth_test.mbt` 产出快照
   `gen_n3v2/quicktest/actions_truth.gen` + 金样（快照 ≡ TOML）；子仓 `data_face.mbt` 按行复现见证路径、
   用 `N3Probe::slots()` 逐槽对拍 ⇒ 行 314、**可比 248、违例 0、债点 0**，不可比 128（面外 54 / 序敏感 66 / 条件式 8）在册。
   首跑 8 处债点（`path_subj_end·predicate`）已**定向裁定**：真分歧 0、TOML 错 0、引擎 bug 0——
   根因是门缺"**发射即清槽**"（`EmitQuad(Scope)` 后按 scope 复位），已折进期望（`scope_reset_slots`）。
   **trig 上半已回灌**（2026-09-19，见活账 §AN.3）：`TrigProbe::slots`/`TrigSlotSnapshot` 已开（只读四槽，
   `.mbti` 恰新增所开面），`gen_trig/quicktest/actions_truth.gen`（136 行）与 n3v2 同列同口径、有金样；
   **trig 内门（逐槽对拍）待落**——配方照抄 n3v2 的 `data_face.mbt`，四处适配（四槽 SlotView / `ref_id_of` /
   trig 见证路径 / 行数 136）。
2. **N6 宿主 CI 观测**：需在 gitlink UI 或带 token 的环境确认 static/test 作业真跑且绿。
3. **役 15 余量**：深片排除项的权重放宽（表/IR 侧），不属于门缺陷。

## 6 引用索引

- 红线：`src/ttl` 各 `const.md`；世界卷 `bangto/world/const.md` §5/§6
- 决策：`src/quick_machine/adr.md`、`src/gen_*/adr.md`
- 结构事实：`src/gen_*/spec.md`、`src/quick_machine/spec.md`
- 活账（不入库）：`src/ttl/todo.md`、各 `quicktest/{todo,ctx}.md`
- 覆盖率账：`coverage-baseline.txt`（行覆盖）、`reachable-coverage-baseline.txt`（可达命令名覆盖）
