#!/usr/bin/env python3
"""
rdflib 解析测试（修复版）
"""

import time
from rdflib import Dataset


def test_rdflib(filename: str):
    """测试 rdflib 解析性能"""
    print(f"\n=== rdflib 解析 {filename} ===")
    
    # 使用 Dataset 替代 Graph，支持 N-Quads
    ds = Dataset()
    
    start = time.time()
    ds.parse(filename, format='nquads')
    elapsed = (time.time() - start) * 1000
    
    # 统计所有图（包括默认图和命名图）中的三元组
    count = 0
    for graph in ds.graphs():
        count += len(graph)
    
    print(f"解析时间: {elapsed:.2f} ms")
    print(f"图数量: {len(list(ds.graphs()))}")
    print(f"三元组数量: {count}")
    
    if count > 0:
        print(f"每秒解析: {count / elapsed * 1000:.0f}")
        print(f"每三元组: {elapsed / count:.4f} ms")
    else:
        print("警告: 未解析到三元组")
    
    # 显示一些示例
    if count > 0:
        for i, graph in enumerate(ds.graphs()):
            if len(graph) > 0:
                triple = list(graph)[0]
                print(f"示例 [图{i}]: {triple}")
                break
    
    ds.close()
    return elapsed, count


if __name__ == "__main__":
    for f in ["test_1000.nq", "test_100.nq"]:
        try:
            test_rdflib(f)
        except Exception as e:
            print(f"错误: {e}")
            import traceback
            traceback.print_exc()