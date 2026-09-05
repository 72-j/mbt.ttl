# N3 数据类型与节点类型

N3 兼容 Turtle/N-Quads 的词项体系，并扩展公式、规则与变量语义。

---

## 1. RDF 节点类型（N3）

| 类型 | 语法表示 | 说明 |
|---|---|---|
| URI / IRI | `<http://...>` | 命名资源 |
| 字面量 | `"value"` | 文本值 |
| 空白节点 | `_:id` 或 `[...]` | 匿名资源 |

---

## 2. 字面量细分（N3）

- 纯字符串：`"Hello"`
- 带语言标签：`"Hello"@en`
- 带数据类型：`"42"^^xsd:integer`
- RDF 1.2 文本方向：`"مرحبا"@ar^rtl`

---

## 3. N3 特有组织形态

| 类型 | 说明 |
|---|---|
| Formula | `{ ... }` |
| Rule | `{ ... } => { ... }` |
| Variable | `?x` |
| Builtin | `math:quotient`, `log:implies` |
| Collection | `( a b c )` |
| BNodeProp | `[ ex:name "A" ]` |
| TripleTerm | `<<( <s> <p> <o> )>>` |

---

## 4. 示例

```text
@prefix : <http://example.org/> .

{ :Alice :likes :Bob }
  => { :Bob :friendOf :Alice } .

:Alice :hasFriend [ :name "Bob" ] .
:Alice :items ( <a> <b> <c> ) .
```
