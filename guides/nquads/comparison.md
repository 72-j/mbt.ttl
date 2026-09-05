# N-Triples / N-Quads 术语与版本对照

本文件为术语与版本差异的对照总表。

---

## 1. 语法属性总表

| 术语 / 特性 | N-Triples | N-Quads RDF 1.1 | N-Quads RDF 1.2 | 备注 |
|---|---|---|---|---|
| 主语 | IRI / BNode / Literal（受限） | IRI / BNode | 同左 | 主语不可为字面量 |
| 谓语 | IRI | IRI | 同左 | 谓语仅 IRI |
| 宾语 | IRI / BNode / Literal | 同左 | 同左 | 宾语最宽 |
| 图名 | 无 | IRI / BNode | 同左 | N-Quads 专有 |
| TripleTerm | 无 | 无 | 支持 | RDF 1.2 |
| 语言方向 | 无 | 无 | `@lang^dir` | RDF 1.2 |
| 空白节点冒号 | 允许 | 允许 | 移除 | RDF 1.2 对齐 Turtle |
| 版本指令 | 无 | 无 | `VERSION "1.2"` | RDF 1.2 |

---

## 2. 术语位置总览

| 类型 | 主语 | 谓语 | 宾语 | 图名 |
|---|---|---|---|---|
| IRI | 支持 | 支持 | 支持 | 支持 |
| Blank Node | 支持 | 不支持 | 支持 | 支持 |
| Literal | 一般不允许 | 不支持 | 支持 | 不支持 |
| TripleTerm | RDF 1.2 支持 | 不支持 | RDF 1.2 支持 | 不支持 |
| Variable | 不支持 | 不支持 | 不支持 | 不支持 |
| GraphName | 无 | 无 | 无 | IRI / BNode |

---

## 3. 版本快速列表

- RDF 1.1：
  - 无版本声明。
  - 无 TripleTerm。
  - 无文本方向。
  - BNode label 允许 `:`。
- RDF 1.2：
  - 允许 `VERSION "1.2"`。
  - 支持 TripleTerm。
  - 语言标签可附方向。
  - BNode label 禁止 `:`，改为 PN_CHARS_U 风格。
