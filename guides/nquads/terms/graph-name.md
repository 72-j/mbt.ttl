# GraphName

> 指南：[索引](../../README.md) ｜ 方言：[N-Quads](../README.md) ｜ [语法](../syntax.md) ｜ [术语](README.md) ｜ [数据类型](../datatypes.md) ｜ [对照](../comparison.md)

图名是 N-Quads 中专有的术语位置。

---

## 语法

- IRI：`<g>`。
- Blank Node：`_:g`。

---

## 限制

- 不允许字面量。
- 不允许 Prefixed Name。

---

## 示例

```text
<s> <p> <o> <http://example.org/g> .
<s> <p> <o> _:g .
```
