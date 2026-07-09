# MoonTTL

MoonTTL 是一个使用 MoonBit 语言编写的高性能 RDF 解析与序列化库。本项目移植自 Rust 生态中的优秀库 Oxttl，旨在为 MoonBit 生态提供一套标准化、轻量级的语义网数据处理引擎。

## 特性

- **多格式支持**：完整支持 Turtle, TriG, N-Triples, N-Quads 和 N3 格式的解析与序列化。
- **RDF 1.2 兼容**：除 N3 外，全面支持最新的 RDF 1.2 国际标准规范。
- **高性能**：基于 MoonBit 的高性能编译后端，提供低内存占用的流式解析能力。
- **纯 MoonBit 实现**：利用 MoonBit 的原生类型系统和 GC 机制，提供简洁的 API 体验。

## 安装

确保你的环境中已经安装了 MoonBit 工具链。

在你的 `moon.mod.json` 中添加依赖：

```json
{
  "name": "your_username/your_project",
  "deps": [
    "thy7/moonttl"
  ]
}
```

## 命令行工具

### 从字符串解析

```bash
moon run src/cmd/main -- "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
```

### 从文件解析

```bash
echo '<http://example.org/s> <http://example.org/p> <http://example.org/o> .' > test.nq
moon run src/cmd/main -- -f test.nq
```

### 详细输出模式

```bash
moon run src/cmd/main -- -v -f test.nq
```

## 命令行选项

- `-f, --file <path>` - 指定输入文件路径
- `-v, --verbose` - 启用详细输出模式
- `<input>` - 直接输入 N-Quads 格式的字符串（注意末尾需要换行符）

## N-Quads 格式说明

N-Quads 是一种简洁的 RDF 四元组格式，每行一个语句：

```
<subject> <predicate> <object> <graph> .
```

其中 graph 部分可选，默认为默认图。

示例：
```
<http://example.org/s> <http://example.org/p> <http://example.org/o> .
```

## 示例代码

```moonbit
let content = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
let data = @utf8.encode(content)

let lexer = @lib.Lexer::Lexer(
  @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
  data.to_array(),
  true,
  @lib.MIN_BUFFER_SIZE,
  @lib.MAX_BUFFER_SIZE,
  Some(b"#"),
  0,
  0,
)

let machine = @lib.NQuadsRecognizer::{
  stack: [@lib.NQuadsState::ExpectSubject],
  subjects: [],
  predicates: [],
  objects: [],
  lenient: false,
  debug_logger: @lib.make_mute_logger(),
  last_range: @lib.Range::default(),
  errors: [],
}

let context = @lib.RdfContext::NQuadsRecognizerContext(
  @lib.NQuadsRecognizerContext::{
    with_graph_name: false,
    lexer_options: { base_iri: None },
  },
)

let parser = @lib.ParserM::{
  lexer,
  engine: @lib.GenericStateMachine::{ machine, context, outputs: [] },
  context,
  errors: [],
}

for ;; {
  match parser.parse_next() {
    Some(Ok(quad)) => println("Parsed: \{quad}")
    Some(Err(e)) => println("Error: \{e}")
    None => break
  }
}
```

## 项目结构

```
src/
├── lexer_*.mbt      # 词法分析器
├── parser*.mbt      # 语法分析器
├── nquads_*.mbt     # N-Quads 格式支持
├── turtle_*.mbt     # Turtle 格式支持
├── trig_*.mbt       # TriG 格式支持
├── n3_*.mbt         # N3 格式支持
├── iri.mbt          # IRI 处理
├── literal.mbt      # 字面量处理
├── langtag.mbt      # 语言标签处理
└── tests/           # 测试文件
```

## 许可证

本项目采用以下任一许可证：

* Apache License, Version 2.0, ([LICENSE-APACHE](../LICENSE-APACHE) or
  `<http://www.apache.org/licenses/LICENSE-2.0>`)
* MIT license ([LICENSE-MIT](../LICENSE-MIT) or
  `<http://opensource.org/licenses/MIT>`)

您可自行选择适用的许可证。

## 贡献

除非您另有明确声明，否则您有意提交给 MoonTTL 的任何贡献（按 Apache-2.0 许可证的定义）均应按上述方式双重许可，不附加任何其他条款或条件。

## Examples

### 解析 N-Quads 文件

运行示例程序：

```bash
moon run src/examples/nquads
```

输出示例：

```
Written N-Quads content to: ./example.nq
Parsing N-Quads file...
[1] Quad<http://example.org/s1, http://example.org/p1, http://example.org/o1>
[2] Quad<http://example.org/s2, http://example.org/p2, http://example.org/o2>
[3] Quad<http://example.org/s3, http://example.org/p3, http://example.org/o3>
[4] Error: InvalidTurtleToken - Unexpected end of input turtle .

=== Summary ===
Total quads parsed: 3
```

该示例展示了：
- 从字符串创建 N-Quads 内容并写入文件
- 从文件读取并解析为二进制数据
- 使用词法分析器和状态机解析 RDF 四元组
- 错误处理和结果汇总
