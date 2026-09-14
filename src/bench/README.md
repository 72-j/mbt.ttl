# RDF N-Quads 性能基准与交叉测试

对比不同语言实现的 N-Quads 解析性能，并做**跨实现计数交叉校验**。
日期：**2026-09-14**（环境：Linux / gcc -O3 / Rust release / JVM / Python 3.13 + rdflib 7.6.0 / MoonBit native）。

## 测试数据

| 文件 | 规模 | 说明 |
|------|------|------|
| `test_1000.nq` | 1,000 行 | 纯合法语料（五实现计数一致） |
| `test_10000.nq` | 10,000 行 | 纯合法语料（五实现计数一致） |
| `test_collected.nq` | 235 行 | **混合语料**（含裸数字等 N-Quads 非法行）——用于错误处理对照，不做性能对比 |

## 实测结果（10 万字节级、单次计时，非多轮取优）

| 实现 | 1,000 行 | 10,000 行 | 口径（重要） |
|---|---|---|---|
| **C**（`nqparser -O3`，`full`） | **0.13 ms** / 7.81M quads/s | **1.09 ms** / 9.14M quads/s | 行扫描 + 结构计数；**不建图、不做深验**（基线） |
| **Rust**（Oxigraph `bulk_loader` → `Store`） | 2 ms / 500k quads/s | 24 ms / 417k quads/s | 解析 + **建图**（内存 Store） |
| **MoonBit**（`parse_all` + `materialize_all`，native） | 3.4–3.7 ms / ~280k quads/s | 35.2 ms / ~284k quads/s | 词法 + 表驱动 step + 轻验 + **深验四门 + 物化**；**不建图** |
| **Python**（rdflib 7.6.0 `Dataset.parse`） | 19.5 ms / 51k quads/s | 173 ms / 58k quads/s | 解析 + **建图** |
| **Java**（Jena `RDFDataMgr` → Dataset + 收集 List） | 672 ms / 1.5k quads/s | 687 ms / 14.6k quads/s | 解析 + 建图 + 额外 List 收集；1k 档含 JVM 启动 |

> 读表要点：**口径不同不可直接比**——C 是"扫描计数"基线；Oxigraph/Jena/rdflib 建图；MoonBit 走完整
> 轻验 + 深验 + 物化但不建图。同口径下：MoonBit 约为 Rust Oxigraph 的 **1.5×**（10k：35 vs 24 ms），
> 比 Python rdflib 快 **~5×**，比 Jena 快 **~20×**。

## 交叉测试（正确性对照）

- **合法语料**（1k / 10k）：五实现计数**逐项一致** —— 1000 / 10000 ✓
  （`nqparser full` / Oxigraph `store.len()` / MoonBit `quads.length()` / rdflib 三图合计 / Jena Quad 遍历）。
- **混合语料**（`test_collected.nq`）：分道属**预期**——
  - MoonBit：67 quads ok / **9 errors**（轻验 + 深验逐条报错，续解后续行）；
  - rdflib：**抛 `ParserError`**（首行非法即停，如 `<s> <p> 1 .` 裸数字不是 N-Quads）；
  - C(`full`)：95（宽松计数，不裁决词项合法性）。
  ⇒ 该文件用于**错误处理口径对照**，不用于吞吐对比。

## 如何运行

```bash
# MoonBit 基准：native-only（第一段计时对照 C FFI 词法器 Lexerc）——工作目录用模块根
cd src/ttl
moon run src/bench/nquads-benchmark --target native                          # 1k（默认）
moon run src/bench/nquads-benchmark --target native src/bench/test_10000.nq   # 10k

# 其它实现——工作目录 src/ttl/src/bench
cd src/ttl/src/bench

# C（gcc -O3；fast=快速计数 / full=结构解析）
gcc -O3 -o nqparser nqparser.c
./nqparser test_1000.nq full

# Python（rdflib；脚本内跑 1k + 10k）
python3 test_rdflib.py

# Java（Jena；参数为文件路径）
cd jena-benchmark && mvn -q -o compile \
  && mvn -q -o exec:java -Dexec.mainClass=JenaBenchmark -Dexec.args="../test_10000.nq" && cd ..

# Rust（Oxigraph；release，脚本内跑 1k + 10k）
cd oxigraph-benchmark && cargo run --release && cd ..

# 一把跑（README 记录口径；缺工具的环境请按需跳过）
./run_all.sh
```

## 已知限制

- 全部为**单次计时**（非多轮取优/中位数），噪声主要影响 1k 档（如 JVM 启动、首次页缓存）。
- C harness 只做**扫描/计数**，不与其它实现的语义校验强度对齐；要严格对比应把它的 `parse_line`
  升级为词项级校验（或改为消费 MoonBit 的深验口径）。
- MoonBit 侧基准**第一段计时走 C FFI 词法器（Lexerc）**，故整包 `supported_targets = "native"`：
  wasm/js 上量到的是宿主开销，计时基准在那里没有意义。若要比 `Lexermoon`（纯 MoonBit）版本，
  见 `src/gen_nquads/nquads_bench_wbtest.mbt` 与 `src/gen_trig/trig_bench_wbtest.mbt` 的双词法器对照。
