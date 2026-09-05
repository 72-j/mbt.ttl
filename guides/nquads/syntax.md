# N-Triples / N-Quads 语法说明

本文把 `N-Triples` 与 `N-Quads` 的语法拆开说明，方便对照实现边界与解析细节。

---

## 1. 整体结构

- `N-Triples`：一行一条三元组。
- `N-Quads`：一行一条四元组。

两者都采用 **行式终止**：一条记录以 `.` 结束。

```text
subject predicate object .
subject predicate object graph .
```

行末只认一个 `.`，多余的 `.` 属于下一次记录或错误。

---

## 2. 词项

### 2.1 IRI

- 首尾用 `<` `>` 包围。
- 内容可以是任意合法的 IRI/URI 文本。
- 严格模式下会校验 scheme、非法字符、路径等。
- 宽松模式下可接受部分不严格输入。

### 2.2 Blank Node

- 形如 `_:label`。
- 标签是解析器接受的本地标识，不允许空格。
- BNode 可以出现在主语、宾语和图名位。

### 2.3 Literal

- 基本形式：`"string"`。
- 语言标签：`"string"@lang`。
- 数据类型：`"string"^^<dt>`。

注意：

- 解析对字面量内引号转义采用标准 RDF 字面量规则。
- 语言标签形如 `@tag`，通常允许子标签。
- 若字面量没有语言标签，则数据类型可省略，等价于 `xsd:string`。

### 2.4 图名（N-Quads 专有）

- 只能是 `IRI` 或 `Blank Node`，不允许字面量、Prefixed Name。
- 若不想写图名，则省略即可：

```text
subject predicate object .
```

此时该记录属于默认图。

---

## 3. 终止与组合

### 3.1 行终止

每条记录由 `.` 终止：

```text
<s> <p> <o> .
<s> <p> <o> <g> .
```

### 3.2 同一主语重复

可以用 `;` 省略主语：

```text
<s> <p1> <o1> ;
    <p2> <o2> .
```

### 3.3 同一主语/谓语重复

可以用 `,` 省略主语/谓语：

```text
<s> <p> <o1> ,
    <o2> ,
    <o3> .
```

这两种写法都等价于多条完整记录。

---

## 4. 注释与空白

- 行首 `#` 到行尾为注释。
- 注释不影响解析，不产生结果。
- 空白仅用于分词，不参与数据语义。

---

## 5. 编码与字节规则

- 文件应为 `UTF-8` 编码。
- 不对 IRI 或字面量重新编码。
- 序列化遵循字节保真：若输入已合法，原样写回。

---

## 6. N-Triples 与 N-Quads 的差异

- `N-Triples` 只含主语、谓语、宾语，没有图名字段。
- `N-Quads` 增加图名，因此 `N-Triples` 可视为 `N-Quads` 的无图名子集。
- 若把 `N-Quads` 序列化为 `N-Triples`，已支持的策略是显式丢弃图名或报错。

---

## 7. 典型示例

```text
# 三元组
<http://example.org/s> <http://example.org/p> <http://example.org/o> .

# 四元组
<http://example.org/s> <http://example.org/p> <http://example.org/o> <http://example.org/g> .

# 空白节点主语
_:b1 <http://example.org/p> "hello" .

# 字面量带语言标签
_:b1 <http://example.org/p> "中文"@zh .

# 字面量带数据类型
_:b1 <http://example.org/p> "1"^^<http://example.org/dt> .

# 省略主语
<http://example.org/s> <http://example.org/p1> <http://example.org/o1> ;
                    <http://example.org/p2> <http://example.org/o2> .

# 省略主语和谓语
<http://example.org/s> <http://example.org/p> <http://example.org/o1> ,
                                      <http://example.org/o2> .
```

---

## 8. 合法性与常见错误

- 缺少终止符 `.` 视为不完整记录。
- 谓语位出现字面量、空白节点等非法词项，属于结构错误。
- 同一行多次出现图名不属于本格式语法。
- 图名若使用字面量，属于语义非法，一般不进入 `N-Quads` 接受范围。

---

## 9. RDF 1.1 与 RDF 1.2 差异

以下差异影响词法、验证和物化层的实现边界。

### 9.1 版本声明

- `RDF 1.1`：无版本指令。
- `RDF 1.2`：允许显式 `VERSION "1.2"` 声明，帮助解析器启用新特性。

### 9.2 三元组术语

- `RDF 1.1`：不支持。
- `RDF 1.2`：引入 `<<( ... )>>` 形式的 Triple Term，可作为主语或宾语出现，实现引用三元组。

### 9.3 语言标签与文本方向

- `RDF 1.1`：语言标签为 `@lang`。
- `RDF 1.2`：扩展为 `@lang^dir`，允许指定基础文本方向（例如 `@en^ltr`）。

### 9.4 空白节点标签字符规则

- `RDF 1.1`：允许标签内出现 `:`。
- `RDF 1.2`：为与 Turtle 对齐，移除 `:` 作为合法标签字符，标签改为由 `PN_CHARS_U` 风格字符组成。

### 9.5 与本仓库实现的对应关系

- `gen_nquads` 的 `rdf12` 参数用于切换语法版本和验证策略。
- 词法器保持同一 token 形态；版本差异由验证层和物化层根据 `rdf12` 开关处理。
- Triple Term、语言方向、空白节点标签合法集等边界，分别落在验证和类型映射处，而不是词法事件形态。

- `gen_nquads` 的词法只扫出原始 token span，不做语义决策。
- 字面量的语言标签、数据类型边界统一在验证层裁决。
- 图名首字节探测只在物化层做类型映射，词法层只看成普通 token。
