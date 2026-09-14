#!/usr/bin/env python3
"""
生成测试用的 N-Quads 文件
"""

import os


def generate_nquads_file(n: int = 1000, base: str = "http://example.org/", filename: str = "test.nq"):
    """生成 N-Quads 文件"""
    with open(filename, 'w', encoding='utf-8') as f:
        for i in range(n):
            line = f"<{base}s{i}> <{base}p{i}> <{base}o{i}> .\n"
            f.write(line)
    
    size = os.path.getsize(filename)
    print(f"生成文件: {filename}")
    print(f"三元组数量: {n}")
    print(f"文件大小: {size} 字节 ({size/1024:.1f} KB)")
    return filename


if __name__ == "__main__":
    # 生成不同规模的测试文件
    for n in [1000, 10000, 100000]:
        generate_nquads_file(n, filename=f"test_{n}.tl")