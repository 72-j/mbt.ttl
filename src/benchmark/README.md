# RDF N-Triples 性能基准测试

对比不同语言实现的 N-Triples 解析器性能。

## 测试数据

| 文件 | 规模 |
|------|------|
| `test_1000.nq` | ~1,000 条 |
| `test_10000.nq` | ~10,000 条 |
| `test_collected.nq` | 收集的边界用例 |

## 实现对比

| 语言 | 工具 | 目录 |
|------|------|------|
| **MoonBit** | `moon run nquads-benchmark` | `nquads-benchmark/` |
| **C** | `./nqparser` | `nqparser.c` |
| **Python** | `python3 test_rdflib.py` | rdflib |
| **Java** | Jena | `jena-benchmark/` |
| **Rust** | Oxigraph | `oxigraph-benchmark/` |

## 快速开始

```bash
# 运行所有基准测试
./run_all.sh

# 单独运行 MoonBit
moon run nquads-benchmark

# 单独运行 C
gcc -O3 -o nqparser nqparser.c && ./nqparser test_1000.nq full
```
