# TriG 数据类型与节点类型

TriG 兼容 Turtle 的词项体系，并新增图块组织语义。

---

## 1. RDF 节点类型（TriG）

| 类型 | 语法表示 | 说明 |
|---|---|---|
| URI / IRI | `<http://...>` | 命名资源，全局唯一标识 |
| 字面量 (Literal) | `"value"` | 文本值，可附加语言或类型 |
| 空白节点 (Blank Node) | `_:id` 或 `[...]` | 匿名资源，可组织属性列表 |

---

## 2. 字面量细分（TriG）

- 纯字符串：`"Hello"`
- 带语言标签：`"Hello"@en`
- 带数据类型：`"42"^^xsd:integer`
- RDF 1.2 文本方向：`"مرحبا"@ar^rtl`

---

## 3. XML Schema 常用类型

与 N-Quads 共用同一套 XSD 类型写法：

| 类型 | 示例 |
|---|---|
| xsd:string | `"text"` |
| xsd:boolean | `"true"` |
| xsd:integer | `"42"` |
| xsd:double | `"3.14E0"` |
| xsd:dateTime | `"2024-08-30T14:30:00Z"` |
| xsd:anyURI | `"http://example.org"` |

---

## 4. TriG 特有组织形态

| 类型 | 说明 |
|---|---|
| Graph | `GRAPH <g> { ... }` |
| Collection | `( <a> <b> <c> )` |
| BNodeProp | `[ ex:p "v" ]` |
| TripleTerm | `<<( <s> <p> <o> )>>` |

---

## 5. 示例

```text
@prefix ex: <http://example.org/> .

GRAPH <http://example.org/g> {
  ex:s ex:p ex:o ;
      ex:name "Alice"@en ;
      ex:knows [ ex:name "Bob" ] .

  ex:s ex:items ( <a> <b> <c> ) .
}
```
