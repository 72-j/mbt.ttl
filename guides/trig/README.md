# TriG 用户指南

本文面向使用 `gen_trig` 包解析、物化与序列化 TriG 数据的开发者与集成者。文档聚焦三件事：`TriG` 与 `Turtle` / `N-Quads` 的关系、`TrigDialect` 方言开关，以及对外 API 的用法。

---

## 1. 格式说明

`TriG` 是 `RDF` 的基于行的“三元组 + 命名图”语法，常用于数据交换与转储。它可视为 `Turtle` 的扩展：在 `Turtle` 基础上增加了命名图块语法。

### 1.1 Triple / Quad / TriG 的区别

| 特性 | N-Triples | N-Quads | TriG |
|---|---|---|---|
| 记录单元 | triple | quad | triple / quad（图块内） |
| 图名 | 不支持，隐含默认图 | 支持 | 支持，可由 `GRAPH` 块说明 |
| 多图组织 | 无 | 平铺四元组 | 分组图块 + 共享图命名 |
| 兼容性 | 无图名的 N-Quads 退化 | TriG 的超集退化 | 向下兼容 `Turtle` 子集 |

示例：

```text
# N-Triples：没有图名
<http://example.org/s> <http://example.org/p> <http://example.org/o> .

# N-Quads：一行一个图名
<http://example.org/s> <http://example.org/p> <http://example.org/o> <http://example.org/g> .

# TriG：使用图块语法
<http://example.org/g> {
  <http://example.org/s> <http://example.org/p> <http://example.org/o> .
}
```

实现者常把 TriG 视为“按图分组的 Quad 集合”。

### 1.2 结构

- 基础记录结构与 `N-Triples` 共享：主语 + 谓语 + 宾语 + `.`。
- 图块由 `GRAPH <g> { ... }` 表示。
- 同一图内支持省略主语/谓语 (`;` / `,`)。
- 允许空白节点属性列表 `[...]` 与集合 `(...)`。

### 1.3 组成元素

- `IRI`：形如 `<scheme:path>`。
- `Blank Node`：形如 `_:label` 或 `[...]`。
- `Literal`：形如 `"string"`，可带语言标签或数据类型。
- `Prefixed Name`：`prefix:local`。
- `Graph Block`：`GRAPH <g> { ... }`。
- `Collection`：`( a b c )`。
- `TripleTerm`：`<<( <s> <p> <o> )>>`。

### 1.4 宽松与严格模式

解析时接受 `lenient` 参数：

- 严格模式下会校验 `IRI` 前缀、字面量语法、空白节点标签等。
- 宽松模式下可以接收某些不严格语法，适合流式或容错导入场景。

---

## 2. 架构说明

`gen_trig` 将语法切分为词法、状态机、切片解析器、验证、物化、序列化等层级，方便在可维护性、性能与语义之间独立权衡。

### 2.1 分层职责

| 文件 | 分层 | 职责 |
|---|---|---|
| `trig.mbt` | 生成契约层 | `TrigEvent`、`TrigState`、`ResetScope`、`TrigContext`、`step()`。 |
| `engine.mbt` | 机械层 | 驱动 `step` 状态机；提供词法器抽象；处理尾点的归位与错误恢复。 |
| `parser_slice.mbt` | 加工层 | 将 `TrigPendingQuad` 的 span 视图组装成 `QuadSpan`，负责验证调度和行号统计。 |
| `lexer_mbt.mbt` | 词法层 | TriG / Turtle 词法实现；生成 `TrigEvent`。 |
| `actions.mbt` | 业务热路径 | 处理槽位写入与副作用回调。 |
| `materialize_trig.mbt` | 物化层 | 生成 `QuadSpan -> QuadEmit`；处理集合链、BNodeProp、graph 语义。 |
| `serialize_trig.mbt` | 序列化层 | 把物化后的四元组回写为 `N-Triples`、`N-Quads` 或 `TriG` 文本。 |

### 2.2 方言开关

本包提供 `TrigDialect`：

- `TrigDialect::TriG`：完整 TriG，接受命名图块。
- `TrigDialect::Turtle`：关闭图块区，`Lbrace` 走未知路径恢复。

典型入口：

```moonbit
let engine = @gen_trig.NTrigEngine::from_bytes(data, dialect=@gen_trig.TrigDialect::TriG)
let slice = @gen_trig.SliceParser::new(engine, data[:])
```

词法事件与 `NQuads` 齐头并进：`TrigEvent` 扩充图块和集合相关事件，不破坏既有分层。

### 2.3 生成状态机核心

- `step()` 获得当前事件后写入 `TrigContext` 的当前槽位，并根据转移表决定下一步状态。
- 循环模板只做：`begin_record` -> `lexer.next()` -> `step()` -> `Effect 分发` -> 错误恢复 -> `finish_at_end()`。
- 词法层的 EOF 会被吞掉成 `None`；不完整四元组由 `finish_at_end` 集中报告。

### 2.4 切片组装与物化分工

- 词法阶段只产出 `Span`，不负责类型语义；类型信息在 `QuadSpan` 中由验证层决定。
- 物化层从 `QuadSpan` 读取子类型，转换为 `QuadEmit` 的结构体表示。
- 序列化层只接受 `QuadEmit`，能写文本，但不参与语法决策。

### 2.5 错误模型

`ParseError` 结构化上报：

- `StructSyntaxErr(msg, line, span)`：带有行号的词法/结构错误。
- `SyntaxErr(msg, span)`：纯偏移的结构错误。
- `ValidationErr(msg)`：语义或约束检验失败。
- `IriErr(...)`：`IRI` 解析错误。

---

## 3. API 使用

### 3.1 解析全部输入（TriG 方言）

```moonbit
let input : Array[Byte] = ...
let engine = @gen_trig.NTrigEngine::from_bytes(input, dialect=@gen_trig.TrigDialect::TriG)
let slice = @gen_trig.SliceParser::new(engine, input[:])
let (quads, errors) = slice.parse_all()
```

### 3.2 解析全部输入（Turtle 方言）

```moonbit
let engine = @gen_trig.NTrigEngine::from_bytes(input, dialect=@gen_trig.TrigDialect::Turtle)
let slice = @gen_trig.SliceParser::new(engine, input[:])
let (quads, errors) = slice.parse_all()
```

### 3.3 逐条解析

```moonbit
let engine = @gen_trig.NTrigEngine::from_bytes(input)
let slice = @gen_trig.SliceParser::new(engine, input[:])
match slice.parse_next() {
  Some(Ok(quad)) => ...
  Some(Err(e)) => ...
  None => // 输入结束
}
```

### 3.4 宽松模式

```moonbit
let slice = @gen_trig.SliceParser::new(engine, input[:], lenient=true)
```

宽松模式下会跳过部分 `IRI` 和词法验证，适合容错导入。

### 3.5 物化

```moonbit
let (emits, materialize_errors) = @gen_trig.materialize_all(quad_spans)
```

物化阶段会检查词项子类型、主语合法性、图名类型，并在语义不合法时收集错误。

### 3.6 序列化

| 输出模型 | 构造器参数 | 用途 |
|---|---|---|
| `N-Triples` | `Serializer::new(format=Triple)` | 标准三元组输出，默认拒绝图名。 |
| `N-Quads` | `Serializer::new(format=Quad)` | 输出四元组，含图名场。 |
| `TriG` | 待支持 | 当前版本可先物化为 Quad，再另行格式化。 |
| 显式丢弃图名 | `Serializer::new(graph_policy=Drop)` | 导出时静默去掉图名。 |
| 仅图名 | `Serializer::new(only_named_graph=true)` | 只输出带有图名的四元组。 |

```moonbit
let s = @gen_trig.Serializer::new(format=@gen_trig.SerializeFormat::Quad)
match s.serialize_all(emits) {
  Ok(output) => ...
  Err(err) => ...
}
```

序列化器以字节保真原则原样拷贝已验证输入，不重新编码。

### 3.7 方言与自定义词法

如需定制词法或增量输出，可以直接使用泛型引擎：

```moonbit
let engine : NTrigEngine[MyLexer] = @gen_trig.NTrigEngine::new(my_lexer, dialect=...)
let slice = @gen_trig.SliceParser::new(engine, data[:])
```

通过提供不同的词法器实现或 `LoopPolicy`、`Actions`，可切换解析策略或追加副作用。

---

## 4. 常见用法

### 4.1 最小使用示例

```moonbit
/// 最小示例：解析 TriG 图块并打印结果数量
fn main {
  let content =
    #|GRAPH <http://example.org/g> {
    #|  <http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #|}
  let data = @utf8.encode(content).to_array()
  let engine = @gen_trig.NTrigEngine::from_bytes(
    data,
    dialect=@gen_trig.TrigDialect::TriG,
  )
  let slice = @gen_trig.SliceParser::new(engine, data[:])
  let (quads, errors) = slice.parse_all()
  println("parsed \{quads.length()} quads, \{errors.length()} errors")
}
```

### 4.2 解析 TriG

```moonbit
let engine = @gen_trig.NTrigEngine::from_bytes(data, dialect=@gen_trig.TrigDialect::TriG)
let slice = @gen_trig.SliceParser::new(engine, data[:])
let (quads, errors) = slice.parse_all()
```

### 4.3 解析 Turtle（关闭图块）

```moonbit
let engine = @gen_trig.NTrigEngine::from_bytes(data, dialect=@gen_trig.TrigDialect::Turtle)
let slice = @gen_trig.SliceParser::new(engine, data[:])
let (quads, errors) = slice.parse_all()
```

### 4.4 物化与序列化

```moonbit
let (emits, mat_errors) = @gen_trig.materialize_all(quads)
let s = @gen_trig.Serializer::new(format=@gen_trig.SerializeFormat::NQuads)
match s.serialize_all(emits) {
  Ok(output) => ...
  Err(err) => ...
}
```

---

## 5. 与其他格式的关系

- `Turtle` 是 `N-Triples` 的超集：支持前缀、集合和 BNode 属性列表。
- `TriG` 是 `Turtle` 的超集：在 `Turtle` 基础上增加 `GRAPH` 图块。
- `TriG` 是 `N-Quads` 的“结构加强版”：将多个命名图组织在一个文件中。
- 当前 `gen_trig` 序列化支持 `N-Triples` / `N-Quads`；原生 TriG 文本可借助物化结果另行组织。

---

## 6. 约定与稳定性说明

- `TrigDialect` 对外接口稳定；词法器与状态机接口保持作者不变。
- `TrigContext`、`QuadSpan`、`SlotStack` 属于生成契约；外部应优先使用公开 API。
- 方言差异已封装在词法与状态转移层，物化层保持同一 `QuadEmit` 形态。

---

## 7. FAQ

1. 在什么情况下用 `Turtle` 方言？  
   需要兼容部分 Turtle 输入或固定禁用图块时。  
   注意：`Turtle` 方言遇到 `{` 会按错误处理路径执行，不会解析图块。

2. TriG 中的空白节点与 Turtle 有何不同？  
   本实现一律记录 `BNode` 语义；TriG 允许 `[...]` 进入属性列表，状态机已同步支持。

3. 如何把 TriG 转成 N-Quads？  
   先解析为 quad 集合，再用 `Serializer::new(format=Quad)` 输出。

4. 集合和列表关系是什么？  
   `(...)` 是 List，扩展为 `rdf:first / rdf:rest` 链；同时支持嵌套、非列表属性等。
