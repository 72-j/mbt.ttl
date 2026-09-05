# N-Quads 用户指南

本文面向使用 `gen_nquads` 包解析、物化与序列化 N-Quads 数据的开发者与集成者。文档聚焦三件事：`N-Quads` 格式本身、`gen_nquads` 的实现架构，以及对外 API 的用法。

---

## 目录

- [格式说明](#1-格式说明)
- [架构说明](#2-架构说明)
- [API 使用](#3-api-使用)
- [常见用法](#4-常见用法)
- [与其他格式的关系](#5-与其他格式的关系)
- [约定与稳定性说明](#6-约定与稳定性说明)
- [FAQ](#7-faq)

补充文档：

- [N-Triples / N-Quads 语法说明](./syntax.md)
- [N-Triples / N-Quads 术语总览](./terms/README.md)
  - [IRI](./terms/iri.md)
  - [Blank Node](./terms/blank-node.md)
  - [Literal](./terms/literal.md)
  - [LangTag](./terms/langtag.md)
  - [TripleTerm](./terms/triple-term.md)
  - [GraphName](./terms/graph-name.md)
  - [Variable 与保留位置](./terms/variable-reserved.md)
- [N-Triples / N-Quads 术语与版本对照](./comparison.md)
- [N-Triples / N-Quads 数据类型与节点类型](./datatypes.md)

---

## 1. 格式说明

`N-Quads` 是 `RDF` 的基于行的”三元组/四元组”语法，常用于数据交换与转储。

### 1.1 Triple 与 Quad 的区别与对照

`N-Triples` 与 `N-Quads` 共享同一词法和结构语义，但记录粒度不同：

| 特性 | N-Triples | N-Quads |
|---|---|---|
| 记录元素 | subject predicate object | subject predicate object graph |
| 行尾终止 | `.` | `.` |
| 图名 | 不支持，隐含默认图 | 支持，可省略 |
| 可互换性 | 每个合法 N-Triples 文件都可视为无图名的 N-Quads 文件 | 输出到 N-Triples 需要显式占位 |

输入示例：

```text
# N-Triples（三列）
<http://example.org/s> <http://example.org/p> <http://example.org/o> .

# N-Quads（四列）
<http://example.org/s> <http://example.org/p> <http://example.org/o> <http://example.org/g> .
```

当实现层需要兼容两种格式时，可把 `Quad` 视为 `Triple + graph` 的同态扩展。

### 1.2 结构

- 标准 `N-Triples` 写主语、谓语、宾语，以 `.` 结尾。
- `N-Quads` 在此基础上增加可选的图名，形成 `subject predicate object graph .` 这一行式四元组。

示例：

```text
<http://example.org/s> <http://example.org/p> <http://example.org/o> .
<http://example.org/s> <http://example.org/p> <http://example.org/o> <http://example.org/g> .
_:b1 <http://example.org/p> "hello" .
_:b1 <http://example.org/p> "中文"@zh .
_:b1 <http://example.org/p> "1"^^<http://example.org/dt> .
```

行尾 `.` 为一个完整 `quad` 的终止标记。超长、可重复的宾语链也可写在同一谓语下：

```text
<http://example.org/s> <http://example.org/p> <http://example.org/o1> ,
  <http://example.org/o2> ,
  <http://example.org/o3> .
```

图名也可以通过 `;` 复用：

```text
<http://example.org/s> <http://example.org/p> <http://example.org/o1> ;
  <http://example.org/p2> <http://example.org/o2> .
```

### 1.2 组成词项

- `IRI`：形如 `<scheme:path>`，可以有更复杂的 URI 结构。
- `Blank Node`：形如 `_:label`。
- `Literal`：形如 `"string"`，可带语言标签 `"string"@lang` 或数据类型 `"string"^^<dt>`。
- `Prefixed Name`（只用于 `RDF 1.1 N-Triples` / `N-Quads` 的某些解析上下文）：通常由外部前缀表驱动，否则按字面词法处理。

### 1.3 宽松与严格模式

解析时接受 `lenient` 参数：

- 严格模式下会校验 `IRI` 前缀、字面量语法、空白节点标签等。
- 宽松模式下可以接收某些不严格语法，适合流式或容错导入场景。

---

## 2. 架构说明

`gen_nquads` 将语法切分为词法、状态机、切片解析器、验证、物化、序列化等层级，方便在可维护性、性能与语义之间独立权衡。

### 2.1 分层职责

| 文件 | 分层 | 职责 |
|---|---|---|
| `engine.mbt` | 机械层 | 驱动 `step` 状态机；提供 `LexerSource` 抽象；处理尾点的归位与错误恢复。 |
| `nquads.mbt` | 生成契约层 | FSM 生成器产物：`NQuadsEvent`、`NQuadsState`、`ResetScope`、`NQuadsContext`、`step()`、事件与副作用枚举。 |
| `parser_slice.mbt` | 加工层 | 将 `NQuadsPendingQuad` 的 span 视图组装成 `QuadSpan`，负责验证调度和行号统计。 |
| `validate_helper.mbt` | 验证层 | 对主语、谓语、宾语、图名及字面量等进行约束校验。 |
| `actions.mbt` | 业务热路径 | `Hooks` 单载体双 trait，处理槽位写入与副作用回调。 |
| `materialize_quad.mbt` | 物化层 | `QuadSpan -> QuadEmit`，将字节范围转换成对外模型。 |
| `serialize_nquads.mbt` | 序列化层 | 把物化后的四元组回写为 `N-Triples` 或 `N-Quads` 文本。 |
| `lexer_mbt.mbt` / `lexerc.mbt` | 词法层 | 提供 `Lexermoon`（纯 MoonBit 词法器）和 `Lexerc`（C FFI 词法器）两种实现。 |

### 2.2 双层词法设计

- `Lexermoon`：纯 MoonBit，便于与构建链和跨平台编译保持一致。
- `Lexerc`：`C FFI` 版本，作为同一状态机的兼容实现，适合本地原生构建或性能敏感场景。

词法事件通过 `token_to_event` 统一映射，不再重复适配业务逻辑。引擎与切片解析都不依赖具体词法器。

### 2.3 生成状态机核心

- `step()` 获得当前事件后写入 `NQuadsContext` 的当前槽位，并根据 `step()` 规则决定下一步状态。
- 循环模板只做：`begin_record` -> `lexer.next()` -> `step()` -> `Effect 分发` -> 错误恢复 -> `finish_at_end()`。
- 词法层的 EOF 会被吞掉成 `None`；不完整四元组由 `finish_at_end` 集中报告，避免状态机表内嵌入边界逻辑。

### 2.4 切片组装与物化分工

- 词法阶段只产出 `Span`，不负责类型语义；类型信息在 `QuanSpan` 中由验证层决定。
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

### 3.1 解析全部输入

```moonbit
let input : Array[Byte] = ...
let engine = @gen_nquads.NQuadsEngine::from_bytes(input)
let slice = @gen_nquads.SliceParser::new(engine, input[:])
let (quad_spans, parse_errors) = slice.parse_all()
```

一次性返回全部四元组和结构层面的语法错误。`quad_spans` 为 `Array[QuadSpan]`，`parse_errors` 为错误集合。

### 3.2 逐条解析

```moonbit
let engine = @gen_nquads.NQuadsEngine::from_bytes(input)
let slice = @gen_nquads.SliceParser::new(engine, input[:])
match slice.parse_next() {
  Some(Ok(quad)) => ...
  Some(Err(e)) => ...
  None => // 输入结束
}
```

### 3.3 宽松模式

```moonbit
let slice = @gen_nquads.SliceParser::new(engine, input[:], lenient=true)
```

或

```moonbit
let (quads, errors) = @gen_nquads.nquads_parser(input, lenient=true)
```

宽松模式下会跳过部分 `IRI` 验证，适合容错导入。

### 3.4 C FFI 词法入口

```moonbit
let fa = @utf8.encode(input).to_fixedarray()
let (quads, errors) = @gen_nquads.nquads_parser_c(fa, lenient=true)
```

词法器与词法事件口径保持同步，与纯 `MoonBit` 版本可做一致性断言。

### 3.5 物化

```moonbit
let (emits, materialize_errors) = @gen_nquads.materialize_all(quad_spans)
```

将 `QuadSpan` 转成 `QuadEmit`，期间可报告语义错误。

### 3.6 序列化

| 输出模型 | 构造器参数 | 用途 |
|---|---|---|
| `N-Triples` | `Serializer::new(format=Triple)` | 标准三元组输出，默认拒绝图名。 |
| `N-Quads` | `Serializer::new(format=Quad)` | 输出四元组，含图名场。 |
| 显式丢弃图名 | `Serializer::new(graph_policy=Drop)` | 导出时静默去掉图名。 |
| 仅图名 | `Serializer::new(only_named_graph=true)` | 只输出带有图名的四元组。 |

```moonbit
let s = @gen_nquads.Serializer::new(format=@gen_nquads.SerializeFormat::Quad)
match s.serialize_all(emits) {
  Ok(output) => ...
  Err(err) => ...
}
```

序列化器以字节保真原则原样拷贝已验证输入，不重新编码。

### 3.7 自定义词法器与钩子

如需定制词法或增量输出，可以直接使用泛型引擎：

```moonbit
let engine : NQuadsEngine[MyLexer] = @gen_nquads.NQuadsEngine::new(my_lexer)
let slice = @gen_nquads.SliceParser::new(engine, data[:])
```

通过提供不同的 `LexerSource` 实现或 `LoopPolicy`、`Actions`，可切换解析策略或追加副作用。

---

## 4. 常见用法

### 4.1 最小使用示例

```moonbit
///
/// 最小可运行示例：解析两行 N-Quads，打印结果数量
fn main {
  let content =
    #|<http://example.org/s> <http://example.org/p> <http://example.org/o> .
    #|<http://example.org/s> <http://example.org/p> <http://example.org/o> <http://example.org/g> .
  let data = @utf8.encode(content).to_array()
  let (quads, errors) = @gen_nquads.nquads_parser(data)
  println("parsed \{quads.length()} quads, \{errors.length()} errors")
}
```

说明：

- `nquads_parser` 接受原始字节，可再用 `lenient=true` 忽略部分校验错误。
- 解析结果先用 `QuadSpan` 的 `view` 字段保留零拷贝字节视图，必要时再转字符串。

### 4.2 解析

**全部解析**

```moonbit
let content =
  #|<http://example.org/s> <http://example.org/p> <http://example.org/o> .
  #|<http://example.org/s> <http://example.org/p> <http://example.org/o> <http://example.org/g> .
let data = @utf8.encode(content).to_array()
let (quads, errors) = @gen_nquads.nquads_parser(data)
```

**逐条解析**

```moonbit
let engine = @gen_nquads.NQuadsEngine::from_bytes(input)
let slice = @gen_nquads.SliceParser::new(engine, input[:])
match slice.parse_next() {
  Some(Ok(quad)) => ...
  Some(Err(e)) => ...
  None => // 输入结束
}
```

**宽松模式**

```moonbit
let (quads, errors) = @gen_nquads.nquads_parser(data, lenient=true)
```

宽松模式下会跳过部分 `IRI` 和词法验证，适合容错导入。

### 4.3 物化

解析得到 `QuadSpan` 后，可批量物化为 `QuadEmit`：

```moonbit
let (emits, materialize_errors) = @gen_nquads.materialize_all(quads)
```

物化阶段会检查词项子类型、主语合法性、图名类型，并在语义不合法时收集错误。

### 4.4 序列化

**N-Triples / N-Quads 输出**

```moonbit
let s = @gen_nquads.Serializer::new(
  format=@gen_nquads.SerializeFormat::Quad
)
match s.serialize_all(emits) {
  Ok(output) => ...
  Err(err) => ...
}
```

常见格式选项：

- `Triple`：输出 `N-Triples`，默认拒绝带图名记录。
- `Quad`：输出 `N-Quads`。
- `GraphPolicy::Drop`：在 `Triple` 模式下静默丢弃图名。
- `only_named_graph=true`：只输出带图名记录。

序列化器保持字节保真：`QuadSpan` 的原始字节被原样拷贝，不会重编码。

### 4.5 C FFI 词法

原生场景下可切换为 `C FFI` 词法：

```moonbit
let fa = @utf8.encode(input).to_fixedarray()
let (quads, errors) = @gen_nquads.nquads_parser_c(fa, lenient=true)
```

`Lexerc` 与 `Lexermoon` 词法事件口径对齐，可互相替换。

### 4.6 自定义词法器与钩子

如需定制词法或增量输出，可直接使用泛型引擎：

```moonbit
let engine : NQuadsEngine[MyLexer] = @gen_nquads.NQuadsEngine::new(my_lexer)
let slice = @gen_nquads.SliceParser::new(engine, data[:])
```

通过提供不同的 `LexerSource`、`LoopPolicy` 或 `Actions`，可切换解析策略或追加副作用。

### 4.7 只输出带图名内容

```moonbit
let s = @gen_nquads.Serializer::new(
  format=@gen_nquads.SerializeFormat::Quad,
  only_named_graph=true)
```

---

## 5. 与其他格式的关系

- `N-Quads` 是 `N-Triples` 的超集：每个有效 `N-Triples` 文件都一定是合法的 `N-Quads` 文件（无图名即可）。
- `TriG` 在 `N-Quads` 基础上增加嵌套图块，`gen_nquads` 不负责 `TriG` 解析，但其状态机设计可复用到类似实现。
- `N3` 语法包含前缀名与公式；`gen_nquads` 只处理 `N-Triples` / `N-Quads` 语法，不做 `N3` 特性扩展。

---

## 6. 约定与稳定性说明

- 词法器和状态机对外保持稳定接口：`LexerSource`、`NQuadsEvent`、`NQuadsEffect`。
- 物化和序列化层的访问点建议按文档中的公共 API 使用，避免直接依赖生成器与内部 `step()`。
- `NQuadsEngine`、`SliceParser`、`Hooks` 等数据结构已在测试中验证 `W3C` 与内部回归用例；接口预示为 `pub` 或 `pub(all)` 时才适合对外调用。

---

## 7. FAQ

1. 解析结果无法直接用字符串比较？  
   答案是使用 `QuadSpan` 的 `subj/pred/obj/graph` 等 `view` 字段访问原始 `UTF-8` 字节视图。若需字符串，可以用 `@utf8.decode_lossy(...)` 转换。

2. 如何处理错误行？  
   `parse_all` 返回 `quads` 与 `parse_errors`，后者保留失败记录的行号与偏移，方便提示或后续修复。

3. 如何切换词法实现？  
   通过 `@gen_nquads.nquads_parser` 使用纯 `MoonBit` 词法，或 `@gen_nquads.nquads_parser_c` 使用 `C FFI` 词法。行为一致时，可互相替换。
