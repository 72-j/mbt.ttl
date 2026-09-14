# RDF N-Quads 性能基准与交叉测试

对比不同语言实现的 N-Quads 解析性能，并做**跨实现计数交叉校验**。

日期：**2026-09-14**（同机同批重跑）。环境：Linux / gcc -O3 / Rust release（Oxigraph）/ JVM + Jena /
Python 3.13 + rdflib 7.6.0 / MoonBit `moon 0.1.20260904`（native 与 wasm 双档）。

> 全部为**单次计时**（非多轮取优 / 中位数）。读数字前先读"口径"列——五个实现的语义强度不同，**不可直接比**。

## 测试数据

| 文件 | 规模 | 说明 |
|------|------|------|
| `test_1000.nq` | 1,000 行 / 103,670 B | 纯合法语料（五实现计数一致） |
| `test_10000.nq` | 10,000 行 / 1,066,670 B | 纯合法语料（五实现计数一致） |
| `test_collected.nq` | 235 行 / 8,854 B | **混合语料**（含裸数字等 N-Quads 非法行）——错误处理口径对照，不做吞吐对比 |

## 词法器与目标（MoonBit 侧）

`nquads-benchmark` 包是**目标中立**的：`main.mbt` 只调一对探针函数，词法器由 `moon.pkg` 的
`targets` 互斥编译二选一。

| 目标 | 编入文件 | 词法段用 | 定位 |
|---|---|---|---|
| `native` | `lexer_probe_native.mbt` | C FFI `Lexerc` | **正式计时口径**（下表 MoonBit 行的数字） |
| `wasm` / `wasm-gc` | `lexer_probe_portable.mbt` | 纯 MoonBit `Lexermoon` | 兜底：裸 `moon run` 也能跑 |

- 程序会打印 `词法器: …`，一眼看出这一跑用的是哪只词法器。
- 段 2/3/4（引擎 / 轻验 / 深验+物化）不含词法器；但 wasm 档整体比 native 慢 ~1.9×，**只有 native 是正式口径**。
- 设计取向：门槛用**数据**表达（探针二选一），不用"跑不了的目标"表达。早先整包
  `supported_targets = "native"` 会让裸 `moon run` 直接报 `does not support target backend 'wasm'`
  （2026-09-14 修正）。

## 实测结果

| 实现 | 1,000 行 | 10,000 行 | 口径（重要） |
|---|---|---|---|
| **C**（`nqparser -O3`，`full`） | **0.12 ms** / 8.33M quads/s | **1.16 ms** / 8.61M quads/s | 行级结构解析（三词项 + 可选图）；**不建图、不做词项级深验**（基线） |
| **Rust**（Oxigraph `bulk_loader` → `Store`） | 2 ms / 500k quads/s | 21 ms / 476k quads/s | 解析 + **建图**（内存 Store） |
| **MoonBit**（native，`parse_all` + `materialize_all`） | 3.26 ms / 306k quads/s | 33.62 ms / 297k quads/s | 词法 + 表驱动 step + 轻验 + **深验四门 + 物化**；**不建图** |
| **Python**（rdflib 7.6.0 `Dataset.parse`） | 17.9 ms / 56k quads/s | 150.6 ms / 66k quads/s | 解析 + **建图** |
| **Java**（Jena `RDFDataMgr` → Dataset + 收集 List） | 546 ms / 1.8k quads/s | 722 ms / 13.9k quads/s | 解析 + 建图 + 额外 List 收集；1k 档含 JVM 启动 |

读表要点：

- **口径不同不可直接比**：C 是行级扫描基线；Oxigraph / Jena / rdflib 建图；MoonBit 走轻验 + 深验 + 物化但不建图。
- 10k 量级排序：C 1.16 < Oxigraph 21 < **MoonBit 33.6** < rdflib 151 < Jena 722 ms。
  MoonBit ≈ Oxigraph 的 1.6×（但 Oxigraph 建图、我们不建图）；比 rdflib 快 **~4.5×**，比 Jena 快 **~21×**。

### MoonBit 分段（同一次跑；总计与独立遍的口径差）

| 档 | 词法（独立遍） | 引擎（独立遍） | 轻验 + 深验 | 物化 | **总计** |
|---|---|---|---|---|---|
| 1k / native（Lexerc） | 0.52 ms | 1.50 ms | 3.08 ms | 0.18 ms | **3.26 ms** |
| 10k / native（Lexerc） | 5.24 ms | 15.5 ms | 31.8 ms | 1.82 ms | **33.62 ms** |
| 1k / wasm（Lexermoon 兜底） | 6.22 ms | 4.46 ms | 5.66 ms | 0.59 ms | **6.25 ms** |

- **总计 = `parse_all`（轻验+深验）+ `materialize_all`**；"词法""引擎"两列是各自独立引擎的对照遍，
  **不计入总计**（所以四列相加大于总计是正常的）。
- 10k / native 的独立词法遍只有 5.24 ms，**真正的大头是验证段 31.8 ms**（RDF 1.2 深验四门）。
- 词法段跨档差 ~12×（Lexermoon 6.22 vs Lexerc 0.52 ms）——这正是保留 C FFI 词法器的收益所在。

## 交叉测试（正确性对照）

- **合法语料**（1k / 10k）：五实现计数**逐项一致** —— 1000 / 10000 ✓
  （`nqparser full` / Oxigraph `store.len()` / MoonBit `quads.length()` / rdflib 图合计 / Jena Quad 遍历）。
- **混合语料**（`test_collected.nq`，235 行）：分道属**预期**——
  - MoonBit：轻验 + 深验 **67 quads ok / 9 errors**（逐条报错，续解后续行）；
  - C（`full`）：95 成功 / 9 失败（行级扫描，不裁决词项合法性）；
  - rdflib：**抛 `ParserError`**（首行非法即停：`<http://example/s> <http://example/p> 1 .` 裸数字不是 N-Quads）。
  ⇒ 该文件用于**错误处理口径对照**，不用于吞吐对比。

## 如何运行

```bash
# MoonBit 基准——工作目录用模块根。裸命令（默认 wasm 档）也能跑：词法段退到纯 MoonBit
# Lexermoon；正式计时口径给 --target native（词法段走 C FFI Lexerc）。
cd src/ttl
moon run src/bench/nquads-benchmark                                          # 1k（wasm 兜底口径）
moon run src/bench/nquads-benchmark --target native src/bench/test_10000.nq  # 10k（native 正式口径）

# 其它实现——工作目录 src/ttl/src/bench
cd src/ttl/src/bench

# C（gcc -O3；fast=纯计数 / full=行级结构解析）
gcc -O3 -o nqparser nqparser.c
./nqparser test_1000.nq full

# Python（rdflib；脚本内跑 1k + 10k）
python3 test_rdflib.py

# Java（Jena；参数为文件路径）
cd jena-benchmark && mvn -q -o compile \
  && mvn -q -o exec:java -Dexec.mainClass=JenaBenchmark -Dexec.args="../test_10000.nq" && cd ..

# Rust（Oxigraph；release，脚本内跑 1k + 10k）
cd oxigraph-benchmark && cargo run --release && cd ..

# 一把跑（Python → Jena → Oxigraph → MoonBit native → C；缺工具的环境按需跳过）
./run_all.sh
```

## 文件清单

| 路径 | 角色 |
|---|---|
| `nquads-benchmark/` | MoonBit harness：`main.mbt` + 两只词法探针（native / portable）+ `moon.pkg` |
| `nqparser.c` | C harness：`fast` 纯计数 / `full` 行级结构解析 |
| `test_rdflib.py` | Python（rdflib）harness，跑 1k + 10k |
| `nquads.py` | 语料生成器（`generate_nquads_file`），未接入 `run_all.sh` |
| `jena-benchmark/` | Java / Maven（Jena） |
| `oxigraph-benchmark/` | Rust / Cargo（Oxigraph） |
| `run_all.sh` | 一把跑全部 |
| `test_*.nq` | 语料（见上表） |

> 二进制不入库（2026-09-14 取消跟踪）：`nqparser` 由 `nqparser.c` 现编；`lexer_test`（旧 C 词法器
> token dump）源码已不在树内，等同废弃物。

## 已知限制

- 全部为**单次计时**（非多轮取优 / 中位数），噪声主要影响 1k 档（如 JVM 启动、首次页缓存）。
- C harness 只做**行级扫描 / 计数**，缺 `.` 也放过；要严格对比应把它的 `parse_line` 升级为词项级校验
  （或改为消费 MoonBit 的深验口径）。
- MoonBit 词法器按目标二选一（见上）；本仓 js 目标被 `@fs` 挡在门外（既有限制，与 bench 无关）。
- 双词法器同表对照另见 `src/gen_nquads/nquads_bench_wbtest.mbt` 与 `src/gen_trig/trig_bench_wbtest.mbt`
  （native-only 白盒：`moon test --target native` 时打印 MoonBit vs C Lexerc 两档词法耗时）。
