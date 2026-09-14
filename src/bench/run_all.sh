#!/bin/bash

echo "=========================================="
echo "RDF 解析性能对比测试"
echo "=========================================="

echo ""
echo ">>> 1. Python (rdflib) 测试（1k / 10k）"
python3 test_rdflib.py

echo ""
echo ">>> 2. Java (Jena) 测试（1k / 10k；1k 档含 JVM 启动）"
cd jena-benchmark
mvn compile -q
mvn -q exec:java -Dexec.mainClass="JenaBenchmark" -Dexec.args="../test_1000.nq"
mvn -q exec:java -Dexec.mainClass="JenaBenchmark" -Dexec.args="../test_10000.nq"
cd ..

echo ""
echo ">>> 3. Rust (Oxigraph) 测试（1k / 10k）"
cd oxigraph-benchmark
cargo run --release
cd ..

echo ""
echo ">>> 4. MoonBit 测试（native + release = 正式计时口径；词法段 = 纯 MoonBit Lexermoon；1k）"
moon run nquads-benchmark --target native --release test_1000.nq

echo ""
echo ">>> 5. C 测试（gcc -O3；full = 行级结构解析；1k）"
gcc -O3 -o nqparser nqparser.c
./nqparser test_1000.nq full

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
