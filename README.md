# MoonTTL

MoonTTL 是一个使用 MoonBit 语言编写的高性能 RDF 解析与序列化库。本项目参考自 Rust 生态中的优秀库 Oxttl，旨在为 MoonBit 生态提供一套标准化、轻量级的语义网数据处理引擎。

## 特性

  - **多格式支持**：完整支持 Turtle, TriG, N-Triples, N-Quads 和 N3 格式的解析与序列化——
    现役三方言：**N-Quads/N-Triples**（`gen_nquads`）、**TriG/Turtle**（`gen_trig`，Turtle 由运行时方言开关裁决）、
    **N3**（`gen_n3v2`，含公式/规则/操作符谓词/集合/属性列表）。
  - **RDF 1.2 兼容**：全面支持最新的 RDF 1.2 国际标准规范；每方言带语法版本开关
    （`rdf12`：转义标量口径 + 方向性语言标签 `--ltr/--rtl`；1.1 侧显式关闭）。
  - **高性能**：基于状态机的词法分析器设计，双词法器（MoonBit `Lexermoon` / C FFI `Lexerc`）同字母表、
    逐 token parity 钉死；提供分层基准（词法 / 转换 / 状态机 / 完整引擎）。
  - **生成器纪律**：三方言均由**表/TOML 数据**驱动生成（生成契约 = Trait / 枚举 / Context；
    Actions / EffectHandler / Supervisor 三面接线），生成物 `*.mbt` 禁手编、有黄金对拍门。
  - **轻量级**：专注于核心解析功能，保持依赖最小化。

## 安装

确保你的环境中已经安装了 MoonBit 工具链。

在你的 `moon.mod.json` 中添加依赖：

```json
{
  "name": "your_username/your_project",
  "deps": [
    "thy1016/moonttl"
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
- `<input>` - 直接输入 N-Quads 格式的字符串

## N-Quads 格式说明

N-Quads 是一种简洁的 RDF 四元组格式，每行一个语句：


<subject> <predicate> <object> <graph> .


其中 graph 部分可选，默认为默认图。

示例：

```
<http://example.org/s> <http://example.org/p> <http://example.org/o> .

```

## 示例代码

```moonbit
let content = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
let data = @utf8.encode(content).to_array()

let lexer = @lib.Lexer::Lexer(
  @lib.RdfLexer::RdfLexer(@lib.RdfMode::NTriples, false, []),
  data,
  true,
  @lib.MIN_BUFFER_SIZE,
  @lib.MAX_BUFFER_SIZE,
  Some(b"#"),
  0,
  0,
)

let logger = @lib.make_console_logger()

let machine = @lib.NQuadsRecognizer::{
  current_state: @lib.NQuadsState::ExpectSubject,
  stack: [@lib.NQuadsState::ExpectSubject],
  emit_quad: false,
  temp_literal: None,
  lenient: false,
  debug_logger: logger,
  last_range: @lib.Range::default(),
  errors: [],
}

let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
  with_graph_name: true,
  lexer_options: { base_iri: None },
})

let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
  machine,
  context,
  debug_logger=logger,
)
let parser = @lib.Parser::{
  lexer,
  engine: generic_machine,
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
├── gen_nquads/       # N-Quads/N-Triples 解析器（生成契约 + 用户层；含词法器/物化/序列化/套件）
├── gen_trig/         # TriG/Turtle 解析器（同上；TriG 超集 + Turtle 方言开关）
├── gen_n3v2/         # N3 解析器（同上；公式/规则/量化/路径/@keywords）
├── cmd/main/         # 命令行工具（`moon run src/cmd/main -- <file>`）
├── examples/         # 三方言可运行示例：nquads / trig / n3
├── benchmark/        # 基准程序
└── quick_machine/    # 快测机（表驱动的模型执行对照）
```

每个方言包内并列五卷文档（`const.md` 红线 / `spec.md` 结构事实 / `adr.md` 决策 /
`todo.md` 路线账本 / `ctx.md` 整改上下文；`gen_n3v2` 另有 `ARCHITECTURE.md` 一页导读）；
生成面（表源/生成器）在主仓 `src/rdf`、`src/fsm`。


## Examples

### 解析 N-Quads 文件

运行示例程序：

```bash
moon run src/examples/nquads
```
输出示例：


```text
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

### 解析 TriG 文件（图块 / GRAPH / Turtle 方言）

```bash
moon run src/examples/trig
```

八个 case 覆盖：基础默认图、`@prefix`/`@base`、命名图与 `GRAPH` 关键字、集合与嵌套、
相对 IRI 按 base 解析、**Turtle 方言**（禁图块区）、序列化旋钮（Strict/Drop）、`@` 风格指令。
管线：`TrigEngine::from_bytes` → `TrigSliceParser` → `TrigMaterializer` → `TrigSerializer`。

### 解析 N3 文件（公式 / 规则 / 操作符 / `@keywords`）

```bash
moon run src/examples/n3
```

六个 case 覆盖：朴素三元组、`@prefix`+`@base`、**公式 `{ ... }` + 规则 `=>`**、
**集合 `( ... )` 与属性列表 `[ ... ]`**（fresh `_:genid*`）、**操作符谓词 `=>` / `<=` / `=`**、
`@keywords a .` 与 `a` → `rdf:type`。管线：`N3Engine::from_bytes` → `N3SliceParser` →
`N3Materializer` → `N3Serializer`。

### 测试与验证

```bash
moon test                     # 全模块：330/330
moon test src/gen_nquads      # 124/124（W3C N-Quads 89/89、rdf12-nt 29/29、rdf12-nq 27/27、ntriples 72/72）
moon test src/gen_trig        # 80/80（rdf-trig 357/357、rdf-turtle 316/316、rdf12 36/36 + 75/75）
moon test src/gen_n3v2        # 117/117（turtle 316/316、rdf12 75/75、N3Tests neg 23ok/0miss + pos+eval 205 clean）
```

三方言的**生成物**（`nquads.mbt` / `trig.mbt` / `n3.mbt`）都有黄金对拍门：钉死头横幅 ts、
经工具链 `moon fmt` 后与 check-in 产物**逐字节**相等且强幂等（`n3.mbt` 由 `src/rdf/n3gen` 的 G9 门把关）。

 ### 许可证声明

  W3C 测试套件中的测试文件在以下两种许可证下分发，使用时由被许可方二选一：

  - W3C 3-clause BSD License — 允许修改和集成到开发工具中，但禁止对修改后的测试断言性能声明或规范一致性。
  - W3C Test Suite License — 要求测试文件保持未修改状态，方可对外发布性能声明。

  本项目在开发测试和 CI 回归测试中采用 BSD 许可证 使用这些测试用例，并根据项目需求对测试框架进行了适配包装。如需了解
  完整版权条款，请参阅 W3C Test Suites Licenses 官方页面。

  ### 测试覆盖范围

  当前 W3C 测试套件的覆盖情况：

   测试类别            总数    通过    状态
  ━━━━━━━━━━━━━━━━━━  ━━━━━━  ━━━━━━  ━━━━━━━━━━━━━
   N-Quads（段级）     89      89      ✅ 全部通过
  ──────────────────  ──────  ──────  ─────────────
   N-Triples（循环读） 72      72      ✅ 全部通过
  ──────────────────  ──────  ──────  ─────────────
   rdf12-nt / rdf12-nq 29 / 27 29 / 27 ✅ 全部通过
  ──────────────────  ──────  ──────  ─────────────
   TriG / Turtle       357 / 316 357 / 316 ✅ 全部通过
  ──────────────────  ──────  ──────  ─────────────
   rdf12-trig / -turtle 36 / 75 36 / 75 ✅ 全部通过
  ──────────────────  ──────  ──────  ─────────────
   N3Tests（neg/pos+eval）23ok/205clean 23ok/205clean ✅ 全部通过

  ## 性能基准

  ### 基准测试环境

   项目        版本/说明
  ━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   CPU         Intel/AMD (测试环境)
  ──────────  ────────────────────────────
   内存        8GB+
  ──────────  ────────────────────────────
   测试文件    1000 条 N-Quads (约 100KB)

  ### 性能对比
  ```
   实现                  解析时间    每秒解析     每条耗时
  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━  ━━━━━━━━━━━  ━━━━━━━━━━━
   MoonTTL (MoonBit)     1.76 ms     568,612      0.0018 ms
  ────────────────────  ──────────  ───────────  ───────────
   Oxigraph (Rust)       2.00 ms     500,000      0.0020 ms
  ────────────────────  ──────────  ───────────  ───────────
   rdflib (Python)       17.89 ms    55,900       0.0179 ms
  ────────────────────  ──────────  ───────────  ───────────
   Apache Jena (Java)    2,734 ms    36,576       0.0273 ms
  ────────────────────  ──────────  ───────────  ───────────
   no-brain-scan (C)     0.16 ms     6,250,000    0.0002 ms

  ### MoonTTL 性能分析

  === MoonBit 解析 test_1000.nq ===
  文件: test_1000.nq
  文件大小: 103670 bytes

  === 性能数据 ===
  Lexer:       515.532 µs (5000 tokens)
  ParserE:     575.14 µs (1000 quads)
  验证:        1448.353 µs (1000 quads, 0 errors)
  物化:        310.314 µs (1000 quads, 0 errors)

  === 总计 ===
  总时间:      1.76 ms
  三元组数量:  1000
  每秒解析:    568,612
  每三元组:    0.0018 ms

  ```
  ### 运行基准测试

  ```bash
  cd src/benchmark
  ./run_all.sh
  ```

  ### 性能优化特性

  - 零拷贝设计：词法分析器基于字节数组切片，避免不必要的内存分配
  - 状态机驱动：使用有限状态机进行语法解析，保证 O(n) 时间复杂度
  - 前瞻解析：减少函数调用开销
  - 批量物化：验证和物化分离，支持批量处理
  - 错误恢复：遇到错误自动跳过当前行，继续解析后续内容

  ## 贡献指南

  欢迎贡献代码、报告问题或提出建议！

  1. Fork 本仓库
  2. 创建您的特性分支 (git checkout -b feature/amazing-feature)
  3. 提交您的更改 (git commit -m 'Add some amazing feature')
  4. 推送到分支 (git push origin feature/amazing-feature)
  5. 开启一个 Pull Request

  ## 开发环境设置

  # 克隆仓库
  git clone https://github.com/thy1016/moonttl.git
  cd moonttl

  # 安装依赖
  moon update

  # 运行测试
  moon test

  # 构建项目
  moon build


## 许可证

本项目采用以下许可证：

* Apache License, Version 2.0, ([LICENSE-APACHE](../LICENSE-APACHE) or
  `<http://www.apache.org/licenses/LICENSE-2.0>`)


您可自行选择适用的许可证。

## 贡献

除非您另有明确声明，否则您有意提交给 MoonTTL 的任何贡献（按 Apache-2.0 许可证的定义）均应按上述方式双重许可，不附加任何其他条款或条件。
