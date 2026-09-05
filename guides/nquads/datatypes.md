# N-Triples / N-Quads 数据类型与节点类型

本文按“节点类型 -> 字面量细分 -> 常用 XSD 类型 -> RDF 内置特殊类型 -> 图相关概念 -> 格式间对照”的顺序整理，方便实现层快速查阅。

---

## 1. RDF 节点类型（三大类）

| 类型 | 语法表示 | 说明 |
|---|---|---|
| URI / IRI | `<http://...>` | 命名资源，全局唯一标识 |
| 字面量 (Literal) | `"value"` | 文本值，可附加类型或语言 |
| 空白节点 (Blank Node) | `_:id` 或 `[]` | 匿名资源，无全局标识 |

---

## 2. 字面量的细分类型

### 2.1 纯字符串（无类型）

```text
"Hello World"
```

### 2.2 带语言标签

```text
"Hello"@en
"你好"@zh
"Bonjour"@fr
```

### 2.3 带数据类型（Typed Literal）

```text
"42"^^<http://www.w3.org/2001/XMLSchema#integer>
"3.14"^^<http://www.w3.org/2001/XMLSchema#double>
"true"^^<http://www.w3.org/2001/XMLSchema#boolean>
```

---

## 3. XML Schema (XSD) 常用类型

RDF 字面量默认常用如下类型：

| 类型 | 示例 | 说明 |
|---|---|---|
| xsd:string | `"text"` | 字符串 |
| xsd:boolean | `"true"` | 布尔值 |
| xsd:integer | `"-42"` | 整数 |
| xsd:decimal | `"3.14159"` | 十进制小数 |
| xsd:double | `"3.14E0"` | 双精度浮点 |
| xsd:float | `"3.14"` | 单精度浮点 |
| xsd:long | `"9223372036854775807"` | 长整数 |
| xsd:int | `"2147483647"` | 32 位整数 |
| xsd:short | `"32767"` | 16 位整数 |
| xsd:byte | `"127"` | 8 位整数 |
| xsd:nonNegativeInteger | `"0"` | 非负整数 |
| xsd:positiveInteger | `"1"` | 正整数 |
| xsd:date | `"2024-08-30"` | 日期 |
| xsd:time | `"14:30:00"` | 时间 |
| xsd:dateTime | `"2024-08-30T14:30:00Z"` | 日期时间 |
| xsd:dateTimeStamp | `"2024-08-30T14:30:00Z"` | 带时区的日期时间 |
| xsd:duration | `"P1Y2M3DT4H5M6S"` | 持续时间 |
| xsd:gYear | `"2024"` | 年份 |
| xsd:gMonth | `"--08"` | 月份 |
| xsd:gDay | `"---30"` | 日期 |
| xsd:anyURI | `"http://example.org"` | URI 字符串 |
| xsd:base64Binary | `"SGVsbG8="` | Base64 编码 |
| xsd:hexBinary | `"0FB7"` | 十六进制 |

---

## 4. RDF 内置特殊类型

| 类型 | IRI | 说明 |
|---|---|---|
| XMLLiteral | rdf:XMLLiteral | XML 片段作为字面量 |
| HTML | rdf:HTML | HTML 内容作为字面量 |
| JSON | rdf:JSON | JSON 字符串作为字面量 |
| Plain Literal | (无类型) | 旧版 RDF 中的纯文本 |
| langString | rdf:langString | 带语言标签的字符串的隐式类型 |

---

## 5. 图相关类型（RDF 1.1 / N-Quads）

| 类型 | 说明 |
|---|---|
| 默认图 (Default Graph) | 无名称的三元组集合 |
| 命名图 (Named Graph) | 用 IRI 标识的三元组集合 |
| 四元组 (Quad) | (subject, predicate, object, graph) |

---

## 6. 各序列化格式中的类型写法对比

| 类型 | N-Triples / N-Quads | Turtle | JSON-LD |
|---|---|---|---|
| URI | `<http://a>` | `<http://a>` 或 prefix:local | `"@id": "http://a"` |
| 字面量 | `"text"` | `"text"` | `"text"` |
| 类型字面量 | `"42"^^<xsd:int>` | `"42"^^xsd:int` | `{"@value": "42", "@type": "xsd:int"}` |
| 语言标签 | `"text"@en` | `"text"@en` | `{"@value": "text", "@language": "en"}` |
| 空白节点 | `_:b0` | `_:b0` 或 `[]` | `{"@id": "_:b0"}` |

---

## 7. N-Quads 合法示例（完整）

```text
# ============================================
# 基础三元组（无 graph，退化为 N-Triples）
# ============================================
<http://example.org/person/alice> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
<http://example.org/person/alice> <http://xmlns.com/foaf/0.1/name> "Alice Smith" .
<http://example.org/person/alice> <http://xmlns.com/foaf/0.1/age> "30"^^<http://www.w3.org/2001/XMLSchema#integer> .

# ============================================
# 带命名图的四元组
# ============================================
<http://example.org/person/bob> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> <http://example.org/graphs/employees> .
<http://example.org/person/bob> <http://xmlns.com/foaf/0.1/name> "Bob Jones" <http://example.org/graphs/employees> .
<http://example.org/person/bob> <http://xmlns.com/foaf/0.1/age> "25"^^<http://www.w3.org/2001/XMLSchema#integer> <http://example.org/graphs/employees> .

# ============================================
# 空白节点作为 subject 和 object
# ============================================
_:b0 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Organization> <http://example.org/graphs/companies> .
_:b0 <http://xmlns.com/foaf/0.1/name> "Acme Corp" <http://example.org/graphs/companies> .
<http://example.org/person/alice> <http://xmlns.com/foaf/0.1/worksFor> _:b0 <http://example.org/graphs/employment> .

# ============================================
# 带语言标签的字面量
# ============================================
<http://example.org/book/1> <http://purl.org/dc/terms/title> "The Great Adventure" <http://example.org/graphs/books> .
<http://example.org/book/1> <http://purl.org/dc/terms/title> "伟大的冒险"@zh <http://example.org/graphs/books> .
<http://example.org/book/1> <http://purl.org/dc/terms/title> "La Grande Aventure"@fr <http://example.org/graphs/books> .

# ============================================
# 带数据类型的字面量（XML Schema）
# ============================================
<http://example.org/book/1> <http://purl.org/dc/terms/issued> "2024-08-30"^^<http://www.w3.org/2001/XMLSchema#date> <http://example.org/graphs/books> .
<http://example.org/book/1> <http://purl.org/dc/terms/price> "29.99"^^<http://www.w3.org/2001/XMLSchema#decimal> <http://example.org/graphs/books> .
<http://example.org/book/1> <http://purl.org/dc/terms/pages> "342"^^<http://www.w3.org/2001/XMLSchema#integer> <http://example.org/graphs/books> .
<http://example.org/book/1> <http://example.org/ns/isAvailable> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> <http://example.org/graphs/books> .

# ============================================
# 空白节点作为 graph label（较少见但合法）
# ============================================
<http://example.org/person/carol> <http://xmlns.com/foaf/0.1/name> "Carol White" _:g1 .
<http://example.org/person/carol> <http://xmlns.com/foaf/0.1/age> "28"^^<http://www.w3.org/2001/XMLSchema#integer> _:g1 .

# ============================================
# 多类型声明
# ============================================
<http://example.org/person/alice> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Agent> <http://example.org/graphs/roles> .
<http://example.org/person/alice> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/ProjectLeader> <http://example.org/graphs/roles> .

# ============================================
# 复杂对象关系
# ============================================
<http://example.org/project/p1> <http://xmlns.com/foaf/0.1/name> "Project Alpha" <http://example.org/graphs/projects> .
<http://example.org/project/p1> <http://example.org/ns/leader> <http://example.org/person/alice> <http://example.org/graphs/projects> .
<http://example.org/project/p1> <http://example.org/ns/budget> "100000.00"^^<http://www.w3.org/2001/XMLSchema#decimal> <http://example.org/graphs/projects> .

# ============================================
# 不同空白节点标识符
# ============================================
_:node1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
_:node1 <http://purl.org/dc/terms/format> "application/pdf" .
_:node2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
_:node2 <http://purl.org/dc/terms/format> "text/html" .

# ============================================
# 特殊字符转义（字面量中）
# ============================================
<http://example.org/person/bob> <http://xmlns.com/foaf/0.1/nick> "Bobby \"The Brain\" Jones" <http://example.org/graphs/employees> .
<http://example.org/person/bob> <http://xmlns.com/foaf/0.1/bio> "Line 1\nLine 2\nLine 3" <http://example.org/graphs/employees> .
```

---

## 8. 语法要素速查

| 要素 | 示例 | 说明 |
|---|---|---|
| 完整 URI | `<http://example.org/a>` | 必须用 `< >` 包裹 |
| 空白节点 | `_:b0` | `_:` 前缀 + 标签 |
| 纯字面量 | `"text"` | 双引号包裹 |
| 语言标签 | `"text"@en` | `@` + 语言代码 |
| 类型字面量 | `"42"^^<xsd:integer>` | `^^` + 类型 URI |
| 命名图 | 第 4 个元素 | 可选，URI 或空白节点 |
| 语句结束 | `.` | 每行必须以点号结尾 |

---

## 9. 本仓库实现要点

- 词法只产出术语 span，不做类型判断。
- 字面量语言标签、数据类型、TripleTerm 等边界落在验证层。
- 图名类型映射只在物化层判断 IRI / BNode。
