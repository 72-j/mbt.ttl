# Blank Node

> 指南：[索引](../../README.md) ｜ 方言：[N-Quads](../README.md) ｜ [语法](../syntax.md) ｜ [术语](README.md) ｜ [数据类型](../datatypes.md) ｜ [对照](../comparison.md)

空白节点表示匿名资源，不具全局标识。

---

## 语法

- `_:label`。

---

## 位置

- 主语、宾语、图名均可。
- 不允许出现在谓语位。

---

## 版本差异

- RDF 1.1：标签允许 `:`。
- RDF 1.2：移除 `:`，改用 PN_CHARS_U 风格字符。

---

## 示例

```text
_:b0
_:user-123
```
