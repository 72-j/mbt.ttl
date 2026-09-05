# TriG、Turtle、N-Quads、N-Triples 对照

本文为 TriG 与相邻格式的对照总表。

---

## 1. 格式关系总览

| 格式 | 支持图块 | 支持集合 | 支持 BNode 属性列表 | 支持前缀 | 兼容对象 |
|---|---|---|---|---|---|
| N-Triples | 无 | 无 | 无 | 无 | RDF triple |
| N-Quads | 无 | 无 | 无 | 无 | RDF quad |
| Turtle | 无 | 有 | 有 | 有 | RDF triple |
| TriG | 有 | 有 | 有 | 有 | RDF quad + named graph |

TriG 被实现为同时兼容平铺四元组与图块语法。

---

## 2. 术语位置对照

| 术语 / 特性 | TriG 主语 | TriG 谓语 | TriG 宾语 | Turtle 宾语 | TriG 图块内 | N-Quads 图名 |
|---|---|---|---|---|---|---|
| IRI | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 |
| Blank Node | 支持 | 不支持 | 支持 | 支持 | 支持 | 支持 |
| Literal | 一般不支持 | 不支持 | 支持 | 支持 | 支持 | 不支持 |
| TripleTerm (RDF 1.2) | 支持 | 不支持 | 支持 | 支持 | 支持 | 不支持 |
| Prefixed Name | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 |
| Collection | 支持 | 不支持 | 支持 | 支持 | 支持 | 不支持 |
| BNodeProp | 支持 | 不支持 | 支持 | 支持 | 支持 | 不支持 |
| GraphBlock | 无 | 无 | 无 | 无 | 支持顶层 | 不适用 |

---

## 3. 语法差异

| 特性 | Turtle | TriG |
|---|---|---|
| 前缀声明 | `@prefix ex: <...> .` | 同左 |
| 图块 | 不支持 | `GRAPH <g> { ... }` |
| 集合 | `( a b c )` | 同左 |
| 空白节点属性列表 | `[ ex:p "v" ]` | 同左 |
| TripleTerm | RDF 1.2 可选 | RDF 1.2 可选 |
| 平坦四元组 | 退化 | 支持 |
| 图名 | 无 | `GRAPH <g>` / 默认图 |

---

## 4. 方言开关说明

`gen_trig` 提供 `TrigDialect`：

- `TriG`：接受图块、`GRAPH`、前缀、集合、BNodeProp。
- `Turtle`：禁用图块进入；遇到 `{` 或图块语法按错误路径处理。
