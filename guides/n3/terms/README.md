# N3 术语总览

本文概览 N3 中出现的主要术语类型，并说明它们在语法中的位置与约束。

---

## 1. 术语目录

- [IRI](./iri.md)
- [Blank Node](./blank-node.md)
- [Literal](./literal.md)
- [LangTag](./langtag.md)
- [TripleTerm](./triple-term.md)
- [PrefixedName](./prefixed-name.md)
- [Collection](./collection.md)
- [BnodeProp](./bnode-prop.md)
- [Formula](./formula.md)
- [Variable](./variable.md)
- [Builtin](./builtin.md)
- [ResourcePath](./resource-path.md)

---

## 2. 快速对照

| 类型 | 示例 | 说明 |
|---|---|---|
| IRI | `<http://example.org/s>` | 绝对资源标识 |
| Blank Node | `_:label` / `[...]` | 匿名资源或属性列表 |
| Literal | `"hello"` | 文本值 |
| Literal + lang | `"hello"@en` | 带语言标签 |
| Literal + dt | `"1"^^xsd:integer` | 带数据类型 |
| TripleTerm | `<<( <s> <p> <o> )>>` | 引用三元组 |
| Prefixed Name | `ex:name` | 前缀名 |
| Collection | `( <a> <b> <c> )` | 列表语义 |
| BNodeProp | `[ ex:name "A" ]` | 属性列表 |
| Formula | `{ ... }` | 公式块 |
| Variable | `?x` | 规则变量 |
| Builtin | `math:quotient(...)` | 内置谓词 |
| ResourcePath | `!`, `^` | 宾/主位路径 |

---

## 3. 版本差异

- RDF 1.1 不支持 `TripleTerm`、不支持语言方向。
- RDF 1.2 支持 `TripleTerm`、语言方向、版本指令。
- N3 扩展语法本身不依赖版本切换，但受 rdf12 开关约束的词项需对齐上述规则。
