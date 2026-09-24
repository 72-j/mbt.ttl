# BnodeProp

> 指南：[索引](../../README.md) ｜ 方言：[TriG](../README.md) ｜ [语法](../syntax.md) ｜ [术语](README.md) ｜ [数据类型](../datatypes.md) ｜ [对照](../comparison.md)

空白节点属性列表为匿名节点批量赋予属性。

---

## 语法

```text
[ ex:name "A" ; ex:age 25 ]
```

---

## 语义

- 相当于创建一个匿名 BNode，并对其多次断言。
- 可嵌套于主语、宾语、图内容中。

---

## 示例

```text
<http://example.org/s> <http://example.org/knows> [ ex:name "B" ] .
```
