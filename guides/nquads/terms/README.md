# N-Triples / N-Quads 术语总览

本文概览 N-Triples / N-Quads 中出现的主要术语类型，并说明它们在语法中的位置与约束。

---

## 1. 术语目录

- [IRI](./iri.md)
- [Blank Node](./blank-node.md)
- [Literal](./literal.md)
- [LangTag](./langtag.md)
- [TripleTerm](./triple-term.md)
- [GraphName](./graph-name.md)
- [Variable 与保留位置](./variable-reserved.md)

---

## 2. 快速对照

| 类型 | 示例 | 说明 |
|---|---|---|
| IRI | `<http://example.org/s>` | 绝对资源标识 |
| Blank Node | `_:label` | 匿名节点 |
| Literal | `"hello"` | 文本值 |
| Literal + lang | `"hello"@en` | 带语言标签 |
| Literal + dt | `"1"^^xsd:integer` | 带数据类型 |
| Triple Term | `<<( <s> <p> <o> )>>` | 引用三元组 |
| Graph Name | `<g>` / `_:g` | N-Quads 图名 |

---

## 3. 版本差异

- RDF 1.1 不允许 TripleTerm、不支持文本方向。
- RDF 1.2 增加 TripleTerm、语言方向 `@lang^dir`、版本指令。
