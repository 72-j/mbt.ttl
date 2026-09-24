# GraphBlock

> 指南：[索引](../../README.md) ｜ 方言：[TriG](../README.md) ｜ [语法](../syntax.md) ｜ [术语](README.md) ｜ [数据类型](../datatypes.md) ｜ [对照](../comparison.md)

图块是 TriG 与 Turtle、N-Quads 最核心的区分。

---

## 语法

```text
GRAPH <g> {
  <s> <p> <o> .
}
```

---

## 语义

- TriG 通过图块组织命名图。
- 图块内允许省略写法、集合、空白节点属性列表。
- 文档级可包含多个图块。

---

## 示例

```text
GRAPH <http://example.org/g1> {
  <http://example.org/s> <http://example.org/p> <http://example.org/o> .
}
```
