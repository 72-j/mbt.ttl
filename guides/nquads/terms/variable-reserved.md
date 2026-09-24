# Variable 与保留位置

> 指南：[索引](../../README.md) ｜ 方言：[N-Quads](../README.md) ｜ [语法](../syntax.md) ｜ [术语](README.md) ｜ [数据类型](../datatypes.md) ｜ [对照](../comparison.md)

N-Triples / N-Quads 语言本身并不使用变量。

---

## 说明

- 变量 `?x` 不出现在标准语法中。
- 若需要在规则或查询层扩展，属于上层语言职责。

---

## 相关说明

- 本实现不解析 N3 规则或 SPARQL 变量。
- `<<( ... )>>` 仍属于 TripleTerm，不是变量。
