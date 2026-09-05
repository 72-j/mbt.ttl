# Literal

字面量表示带类型的文本值。

---

## 语法

- 基本：`"string"`。
- 转义与引号按 RDF 字面量规则。
- 语言标签：`"text"@lang`。
- 数据类型：`"text"^^<dt>`。

---

## 语义

- 默认类型为 xsd:string。
- 数字与布尔可由数据类型说明其类型。

---

## 示例

```text
"hello"
"42"^^xsd:integer
true
"2001-08-10"^^xsd:date
```
