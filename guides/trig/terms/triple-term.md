# TripleTerm

> 指南：[索引](../../README.md) ｜ 方言：[TriG](../README.md) ｜ [语法](../syntax.md) ｜ [术语](README.md) ｜ [数据类型](../datatypes.md) ｜ [对照](../comparison.md)

TripleTerm 可在主语或宾语位置表达引用三元组，支持嵌套到图块中。

---

## 语法

```text
<<( <s> <p> <o> )>>
```

---

## 位置

- 主语、宾语。
- 可出现在 `GRAPH` 块内。

---

## 示例

```text
<<( <s> <p> <o> )>> <http://example.org/mentioned> "true" .
```
