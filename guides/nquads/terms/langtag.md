# LangTag

> 指南：[索引](../../README.md) ｜ 方言：[N-Quads](../README.md) ｜ [语法](../syntax.md) ｜ [术语](README.md) ｜ [数据类型](../datatypes.md) ｜ [对照](../comparison.md)

语言标签描述字面量的自然语言属性。

---

## 语法

- RDF 1.1：`@en`。
- RDF 1.2：`@en^ltr`，增加文本基础方向。

---

## 语义

- 语言标签只对字面量合法。
- 方向为可选项，改善从左到右、从右到左文本渲染。

---

## 示例

```text
"hello"@en
"مرحبا"@ar^rtl
```
