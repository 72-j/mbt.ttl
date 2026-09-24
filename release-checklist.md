# 发版清单（release checklist）— thy1016/moonttl 0.3.0

**发版判据不是"动作执行了"，是"第三方能按账复现出同一结论"。**
红线 8 条（见 §红线）逐条对，缺一不发。清单本身可复核：每项带判据与取证位置。

## 第一段：CI 遗留确认（挡发版硬条件）

| # | 项 | 判据 | 状态 / 取证 |
|---|---|---|---|
| 1 | N6 宿主 CI 接线 | 推送即有 run；不跑则换宿主或降级叙事（写清） | ☐ 推送后观测（N6 已证通：78025e9 三 OS 全绿 + 四次抓红 71ed3ab/22d206d/9a16510/面三复现） |
| 2 | CI perf 步首跑 | 绿 + perf 门有牙（相对判据 false 即 diff 红；吞吐阈值真实断言） | ☐ 本地原样预演绿 ✓（判据体逐字节 ≡ perf-review.txt）；远端首跑待推送 |
| 3 | CI coverage 逐字节比对首跑 | 绿 | ☐ 本地冷口径重生成逐字节一致 ✓（10176/11193）；§AP.14 已实证抓红=有牙；远端待推送 |
| 4 | W18 按档跑（native 档） | native 档绿；wasm 绿 ≠ native 绿已入册 | ☑ 子仓 test 作业 3 OS 双档常驻；**主仓本笔补 native 档**（本地 291/291 ✓）；远端待推送 |
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
| 11 | publish.yml manual dispatch | 触发后能跑通；**不自动触发**；注释写清"为什么不自动" | ☑ `.github/workflows/publish.yml`（`workflow_dispatch` Only） |
| 12 | GH 三 OS 复跑实证 | Linux / macOS / Windows 全绿；**Windows 黄金门逐字节绿**（CI-2 治本为真；红则先分型：行尾/路径/大小写，不混治） | ☐ 推送后观测 |
| 13 | 两仓成对提交推送 | 子仓 → 主仓指针，远端 gitlink 成对；主仓 import 号随 publish 跟跳（0.2.2 → 0.3.0，publish 成功后同笔） | ☐ 收尾 |

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
