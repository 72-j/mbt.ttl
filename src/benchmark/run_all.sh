#!/bin/bash

echo "=========================================="
echo "RDF 解析性能对比测试"
echo "=========================================="

# 1. 生成测试数据
echo ""
echo ">>> 生成测试数据"
python3 generate_data.py

# 2. Python 测试
echo ""
echo ">>> Python (rdflib) 测试"
python3 test_rdflib.py

# 3. Java 测试
echo ""
echo ">>> Java (Jena) 测试"
cd jena-benchmark
mvn compile -q
mvn exec:java -Dexec.mainClass="JenaBenchmark"
cd ..

# 4. Rust 测试
echo ""
echo ">>> Rust (Oxigraph) 测试"
cd oxigraph-benchmark
cargo run --release 
cd ..
# 5. moonbit 测试
echo ""
echo "moonbit 测试"
moon run nquads-benchmark
echo ">>> 测试结束"
# 6. c语言测试(无脑扫)
echo ""
echo ">>> C语言 (no-brain-scan) 测试"
gcc -O3 -o nqparser nqparser.c
./nqparser  test_1000.nq full  

echo ""
echo "=========================================="
echo "测试完成"