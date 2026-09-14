# RDF N-Quads 性能基准与交叉测试

对比不同语言实现的 N-Quads 解析性能，并做**跨实现计数交叉校验**。

日期：**2026-09-14**（同机同批重跑）。环境：Linux / gcc -O3 / Rust release（Oxigraph）/
JVM + Jena / Python 3.13 + rdflib 7.6.0 / MoonBit `moon 0.1.20260904`。

> **口径第一条**：MoonBit 侧正式数字一律取 **`--target native --release`**。同一份代码
> **debug 档慢 4.6×**（10k 总计 34.07 → 7.41 ms）——历史版本的本表是 debug 数字，已作废。
> 其余实现各取其优化档（gcc -O3 / cargo --release / JVM / CPython）。

> **口径第二条**：五个实现的语义强度不同，**不可直接比**——C 只做行级扫描；Oxigraph / Jena /
> rdflib 解析并**建图**；MoonBit 走轻验 + **RDF 1.2 深验四门** + 物化，**不建图**。

## 测试数据

| 文件 | 规模 | 说明 |
|------|------|------|
| `test_1000.nq` | 1,000 行 / 103,670 B | 纯合法语料（五实现计数一致） |
| `test_10000.nq` | 10,000 行 / 1,066,670 B | 纯合法语料（五实现计数一致） |
| `test_collected.nq` | 235 行 / 8,854 B | **混合语料**（含裸数字等 N-Quads 非法行）——错误处理口径对照，不做吞吐对比 |

## 实测结果

| 实现 | 1,000 行 | 10,000 行 | 口径（重要） |
|---|---|---|---|
| **C**（`nqparser -O3`，`full`） | **0.12 ms** / 8.33M quads/s | **1.16 ms** / 8.61M quads/s | 行级结构解析（三词项 + 可选图）；**不建图、不做词项级深验**（基线） |
| **Rust**（Oxigraph `bulk_loader` → `Store`） | 2.28 ms / 439k quads/s | 25.9 ms / 386k quads/s | 解析 + **建图**（内存 Store） |
| **MoonBit**（native **release**，`parse_all` + `materialize_all`） | **0.75 ms** / 1.33M quads/s | **7.66 ms** / 1.31M quads/s | 词法 + 表驱动 step + 轻验 + **深验四门 + 物化**；**不建图** |
| **Python**（rdflib 7.6.0 `Dataset.parse`） | 17.9 ms / 56k quads/s | 150.6 ms / 66k quads/s | 解析 + **建图** |
| **Java**（Jena `RDFDataMgr` → Dataset + 收集 List） | 546 ms / 1.8k quads/s | 722 ms / 13.9k quads/s | 解析 + 建图 + 额外 List 收集；1k 档含 JVM 启动 |

读表要点：

- 10k 量级排序（同批中位）：C 1.16 < **MoonBit 7.66** < Oxigraph 25.9 < rdflib 151 < Jena 722 ms。
  同口径（release）下 MoonBit 比 Oxigraph **快 ~3.4×**、比 rdflib **快 ~20×**、比 Jena **快 ~94×**；
  距 C 的"只扫不算"基线 6.4×，而那 6.4× 正是深验四门 + 物化的质量成本。
- 与 Oxigraph 的对比要记住两点：它**建图**（我们不建），我们**做 RDF 1.2 深验**（它不做）。

### 不物化 / 不建图 同档对照（2026-09-14 同批中位）

"不物化"省掉的到底是多少？把两边都退到**纯解析**档量（MoonBit `parse_all` 出 `QuadSpan`；
Oxigraph `RdfParser` 迭代出 `Quad`，不插 Store）：

| 口径 | MoonBit（native release） | Oxigraph（release） | 倍数 |
|---|---|---|---|
| 1k 纯解析 | **0.59 ms**（parse_all） | 0.79 ms（RdfParser 迭代） | 快 **1.34×** |
| 10k 纯解析 | **6.18 ms**（parse_all） | 8.19 ms（RdfParser 迭代） | 快 **1.33×** |
| 1k 解析 + 物化 / 建图 | **0.75 ms** | 2.28 ms | 快 **3.0×** |
| 10k 解析 + 物化 / 建图 | **7.66 ms** | 25.9 ms | 快 **3.4×** |

读法：

- **不物化这一档我们本来就赢**（1.33×），且这 6.18 ms 里还包含 RDF 1.2 **深验四门**（Oxigraph 不做）。
- 物化只占我们的 **19%**（1.48 / 7.66 ms）；Oxigraph 的建图占 **~68%**（17.7 / 25.9 ms）。
  所以"省掉物化"对我们的相对回报小，对它是大头——**同档比我们赢，装上容器后我们赢更多**。
- 极限档参考：连深验也省掉（只跑表驱动引擎）10k ≈ **3.3 ms**，约为 Oxigraph 纯解析的 **1/2.5**。
- 注意产物形态不同：我们的 `QuadSpan` 是**零拷贝视图**，Oxigraph 的 `Quad` 是 **owned**（每词项
  一个 `String`）。所以"纯解析"这一档更像"半成品 vs 成品"，倍数只作量级参照。

### MoonBit 分段（native；release 为正式口径）

| 档 | 词法（独立遍） | 引擎（独立遍） | 轻验 + 深验 | 物化 | **总计** |
|---|---|---|---|---|---|
| 1k / release | 0.148 ms | 0.331 ms | 0.588 ms | 0.151 ms | **0.739 ms** |
| 10k / release | 1.47–1.53 ms | 3.12–3.28 ms | 5.99–6.18 ms | 1.31–1.42 ms | **7.41–7.49 ms** |
| 10k / debug（对照） | 5.41 ms | 16.2 ms | 32.2 ms | 1.85 ms | **34.07 ms** |

- **总计 = `parse_all`（轻验+深验）+ `materialize_all`**；"词法""引擎"两列是各自独立引擎的对照遍，
  **不计入总计**（四列相加大于总计是正常的）。
- 10k / release 的大头是**验证段 5.99 ms**（RDF 1.2 深验四门）与**引擎 3.2 ms**；词法只占 1.5 ms。

## 词法器：默认用纯 MoonBit（P1 役结论，2026-09-14）

本仓有两只词法器、同一 token 字母表：纯 MoonBit `Lexermoon` 与 C FFI `Lexerc`（`gen_nquads` 内）。
性能役 P1 实测（release / 10k / 纯词法）：

| 词法器 | 10k 耗时 | 吞吐 | 备注 |
|---|---|---|---|
| **`Lexermoon`（纯 MoonBit）** | **1505 µs** | 33.2M tok/s | 各目标都有；**本 bench 默认** |
| `Lexerc`（C FFI，native-only） | 3039 µs | 16.5M tok/s | 每 token 一次跨界（+12B 清零 + 3×`read_int32`）比 C 扫描省下的更贵 |

⇒ "C 版更快"在 release 下**不成立**（debug 档才成立，那也是历史结论的来源）。`Lexerc` 保留为
**语义对齐源**（`gen_nquads/lexerc_parity_wbtest.mbt` 逐 token pin）与**性能对照**，不再作为计时路径。
双词法器纯词法对照的正式入口：`moon test --target native --release src/gen_nquads -f "*词法役 P1*"`。

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
# MoonBit 基准——工作目录用模块根；正式口径 = native + release
cd src/ttl
moon run src/bench/nquads-benchmark --target native --release                          # 1k
moon run src/bench/nquads-benchmark --target native --release src/bench/test_10000.nq   # 10k
# 裸命令（默认 wasm 档）也能跑，但那是宿主口径，不作性能结论
moon run src/bench/nquads-benchmark

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

# 一把跑（Python → Jena → Oxigraph → MoonBit native release → C；缺工具的环境按需跳过）
./run_all.sh
```

## 文件清单

| 路径 | 角色 |
|---|---|
| `nquads-benchmark/` | MoonBit harness（`main.mbt` + `moon.pkg`；词法段 = `Lexermoon`，全目标可跑） |
| `nqparser.c` | C harness：`fast` 纯计数 / `full` 行级结构解析 |
| `test_rdflib.py` | Python（rdflib）harness，跑 1k + 10k |
| `nquads.py` | 语料生成器（`generate_nquads_file`），未接入 `run_all.sh` |
| `jena-benchmark/` | Java / Maven（Jena） |
| `oxigraph-benchmark/` | Rust / Cargo（Oxigraph；一趟打印两档：**解析+建图** / **只解析不建图**） |
| `run_all.sh` | 一把跑全部 |
| `test_*.nq` | 语料（见上表） |

> 二进制不入库（2026-09-14 取消跟踪）：`nqparser` 由 `nqparser.c` 现编；`lexer_test`（旧 C 词法器
> token dump）源码已不在树内，等同废弃物。

## 已知限制

- 全部为**单次计时**（非多轮取优 / 中位数），噪声主要影响 1k 档；本表 10k 档取两次跑的区间。
- **debug 数字不作结论**：MoonBit debug 档同一份代码慢 4.6×（历史版本的本表因此低估了我们）。
- C harness 只做**行级扫描 / 计数**，缺 `.` 也放过；要严格对比应把它的 `parse_line` 升级为词项级校验。
- wasm/js 口径：裸 `moon run`（wasm）测的是**宿主**，只作"能不能跑"的冒烟，不作性能结论；
  本仓 js 目标还被 `@fs` 挡在门外（既有限制，与 bench 无关）。
- 词法层的下一步杠杆（另立役）：`Token`/`Span` 的 tuple 表示为每 token 带来 ≈8.1 ns 纯表示税
  （占纯词法成本 ~27%），紧凑化属跨三方言的原子改动。
