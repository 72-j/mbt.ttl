# 发版清单（release checklist）— thy1016/moonttl 0.3.0

**状态（09-24）：发版候选达成——run #101 四 job 全绿；发布路径已裁 = 用户本机 `moon publish`（Claude 侧不执行发布）；发布前预检全绿（见 §发布前预检），余项 = 用户择时发布。**

**发版判据不是"动作执行了"，是"第三方能按账复现出同一结论"。**
红线 8 条（见 §红线）逐条对，缺一不发。清单本身可复核：每项带判据与取证位置。

## 第一段：CI 遗留确认（挡发版硬条件）

| # | 项 | 判据 | 状态 / 取证 |
|---|---|---|---|
| 1 | N6 宿主 CI 接线 | 推送即有 run；不跑则换宿主或降级叙事（写清） | ☑ **推送即有 run**：d41e339 → Test run #101（N6 端到端持续通） |
| 2 | CI perf 步首跑 | 绿 + perf 门有牙（相对判据 false 即 diff 红；吞吐阈值真实断言） | ☑ 本地原样预演绿 ✓ + **远端首跑绿**（run #101 Static gates success，判据体逐字节复现） |
| 3 | CI coverage 逐字节比对首跑 | 绿 | ☑ 本地冷口径逐字节一致 ✓（10176/11193）+ **远端首跑绿**（run #101 static 内逐字节比对过） |
| 4 | W18 按档跑（native 档） | native 档绿；wasm 绿 ≠ native 绿已入册 | ☑ 子仓 3 OS 双档常驻（run #101 三 OS 绿）；**主仓本笔补 native 档**（本地 291/291 ✓） |
| 5 | 覆盖率分母不缩水钉子 | 常驻 CI，缩水即红 | ☑ static「Reachable command-name coverage」步：`分母缩水 total < 基线 ⇒ exit 1`（+ permille 棘轮步） |

## 第二段：发版账收口

| # | 项 | 判据 | 状态 / 取证 |
|---|---|---|---|
| 6 | 发版清单 | 清单本身可复核（每项有判据） | ☑ 本文件 |
| 7 | 版本 bump | **版本号三处一致**：moon.mod = CHANGELOG = README | ☑ moon.mod `0.3.0`；☑ CHANGELOG `## 0.3.0`；README 依赖示例不带版本号（语义化引用），版本沿革块指向 CHANGELOG。【勘出并修】moon.mod `readme` 指针 `README.mbt.md`（不存在）→ `README.md` |
| 8 | 对外变更日志 | 区别内部 review.md；对外可读 | ☑ `CHANGELOG.md` 立档（破坏性变更 / 性能 / 语义 / 工程 四节） |
| 9 | README 更新 | 能力面 / 性能 / 套件通过率；引用同一数字源 | ☑ 测试计数归位（507/507 + native 521/521；三方言 146/105/122）；性能节引用 `perf-review.txt`（3.3× 口径不变；新读数 ~1.84M quads/s 推高对外口径**留用户裁**） |
| 10 | 复核面收口 | 附复现命令 + 冷跑留证 + target（见下方 §复核面矩阵） | ☑ 四面口径齐 |

## 第三段：发版动作

| # | 项 | 判据 | 状态 / 取证 |
|---|---|---|---|
| 11 | publish.yml manual dispatch | 触发后能跑通；**不自动触发**；注释写清"为什么不自动" | ☑ `.github/workflows/publish.yml`（`workflow_dispatch` Only）；【09-24 预检修正】dry-run 步改认验收文本不认退出码（CLI 怪癖，见 §发布前预检）+ 真发布步加注册表回查为成功判据 |

## 发布前预检（09-24，HEAD = 发版候选笔）

1. **四门 verbatim 本机全绿**：版本三处一致门（sed/grep 原样）✓ · `moon check --deny-warn` ✓ · `moon fmt --warn` 无违规 ✓ · `moon publish --dry-run` 服务器 **202 Accepted**（"Dry run completed successfully…for package thy1016/moonttl version 0.3.0"）✓
2. **CLI 怪癖定性（探针法）**：`--dry-run` 在服务器验收成功后仍 **exit 255**；最小 scratch 包（thy1016/moonttl-dryrun-probe 0.0.1）同判 ⇒ 系 moon 0.1.20260920 CLI 把 202 尾步当失败，**与本包元数据无关**。推论：**发布成功与否不能拿退出码当判据**——判输出验收行（dry-run）/ 注册表回查（真发布）。
3. **注册表槽位**：`https://mooncakes.io/api/v0/search?kw=moonttl` 现最新 = **0.2.2**（39 下载，yanked=false）⇒ 0.3.0 槽位空闲，无版本冲突。
4. **网络**：mooncakes.io **直连通**（HTTP 200，1.2s，无需代理）——本机发布不用挂代理。
| 12 | GH 三 OS 复跑实证 | Linux / macOS / Windows 全绿；**Windows 黄金门逐字节绿**（CI-2 治本为真；红则先分型：行尾/路径/大小写，不混治） | ☑ **run #101 三 OS 全绿**（ubuntu/macos/windows success）——Windows 黄金门逐字节绿 = CI-2 治本为真 |
| 13 | 两仓成对提交推送 | 子仓 → 主仓指针，远端 gitlink 成对；主仓 import 号随 publish 跟跳（0.2.2 → 0.3.0，publish 成功后同笔） | ☑ 子仓推送 ✓（88f317d..d41e339）；主仓已推 74f8cc1（**此后缓推**，用户 09-24 令）；主仓 import 0.2.2→0.3.0 = publish 成功后跟跳 |

## 复核面矩阵（item 10 收口：对外可复现形态）

| 面 | 表 | 口径 / target | 复现命令（cwd = 子仓根） | 冷跑留证 |
|---|---|---|---|---|
| 面一 套件自报行 | `suite-review.txt` | 默认档 | `for d in n3v2 nquads trig; do echo "[$d]"; moon test src/gen_$d 2>&1 \| grep -oE '=== [^"]+ ===' \| sed 's/^=== //;s/ ===$//' \| sort -u; done` | 09-24 逐字节不变 ✓ |
| 面三 覆盖率 | `coverage-review.txt` | 冷口径（`moon clean && moon coverage clean && moon test --enable-coverage`） | 表头「生成命令」原样复跑 | **10176/11193 = 909‰**（09-24 冷口径） |
| 面四 性能（比较体） | `perf-review.txt` | `--target native --release` · 10k | `moon run src/bench/nquads-benchmark --target native --release src/bench/test_10000.nq` + `moon test --target native --release src/gen_nquads -f "*词法役 P1*"` | 09-24 判据体逐字节复现 ✓（留证：物化 824µs / 吞吐 1.84M quads/s） |
| 面二 产物/IR | `../gen-review.txt`（主仓侧） | 主仓口径 | 主仓 CI「复核面·产物/IR」步 | 09-23 零差（面一补漏役复核） |

缺口解释：`review.md` §1.2（每条 [设计]/[立案] + 理由 + 重评估条件）。

## 红线（缺一不发）

1. 门全绿 + 冷缓存复测 + 按 target 跑——三者齐。
2. CI 常驻（N6 观测绿）——不是"文件层面绿"。
3. 缺口有解释——所有未闭项有 [设计]/[立案] + 理由 + 重评估条件。
4. 复核面可对外复现——附复现命令。
5. 版本号 + CHANGELOG + README——对外三件齐，且**版本号三处一致**。
6. publish.yml manual dispatch——不自动触发，注释写清理由。
7. GH 三 OS 全绿——**Windows 黄金门逐字节绿**。
8. 两仓成对提交推送——远端 gitlink 成对。

## 发版日序（本机发布路径；**用户择时**，Claude 侧不执行发布）

> 2026-09-24 发版准备役补：新增**一条命令预检** `ci/release-check.sh`（12 项全 ✓ 实测），
> 并**删除重复工作流** `.github/workflows/copilot-setup-steps copy.yml`（其 `persist-credentials: false`
> 硬化已并回正式件）——发版日只剩下面五步。

1. **预检（一条命令）**：`sh ci/release-check.sh` ⇒ 必须**全 ✓**（版本三处一致 / `check --deny-warn` /
   `fmt --warn` 零 offender / `.mbti` 无漂移 / 面一 + 面三复现逐字节 / 覆盖率棘轮 909‰ /
   三方言可达缺口全 0 / wasm 507 + native 521 / dry-run 服务器验收 / 注册表可达 /
   **语料完整性**（`SHA256SUMS` 2414 件）/ **文档门**（`guides/**`：H1 · 导航 · 零死链 · 命名 · 无孤岛））。
   **任一 ✗ = 缺一不发**。
2. **凭据在位**：`~/.moon/credentials.json`（`moon login` 产物）。本地发布**不依赖** CI secret。
3. **真发布**：`moon publish`。**判据 = 注册表回查**（`curl -s 'https://mooncakes.io/api/v0/search?kw=moonttl'`
   出现 **`0.3.0`**）；**不认退出码**（202-后-255 怪癖，见 §发布前预检 2）。
4. **发后两件**：① 主仓 `import thy1016/moonttl` 跟跳 **0.2.2 → 0.3.0**（现缓推中，届时同笔推）；
   ② 可选打标签：`git tag v0.3.0 && git push origin v0.3.0`。
5. **发后复核**：`sh ci/netcheck.sh crlf`（净检出元门）+ 推送后看 GH **Test** run 复跑（推送即成 run）。

**准备役勘定（同笔实证）**：清单数字与实况**逐项对齐**——wasm **507/507**、native **521/521**、
冷口径覆盖率 **10176/11193 = 909‰**（= `coverage-baseline.txt` 字段）· 面一/面三复现**逐字节一致** ·
版本三处一致（`moon.mod 0.3.0` / `CHANGELOG ## 0.3.0` / README 指向 CHANGELOG）· 红线 **8 条齐**。
