# N3 用户指南

本文面向使用 `gen_n3` 包解析、物化与序列化 N3 数据的开发者与集成者。文档聚焦三件事：N3 格式本身、N3 与 Turtle/TriG/N-Quads 的关系，以及 `gen_n3` 的对外 API。

---

## 1. 格式说明

N3 是 `RDF` 的“超集”语法，在 `Turtle` 基础上增加公式、规则、资源路径、变量与内置谓词，用于表达更丰富的知识与推理约束。

### 1.1 Triple / Quad / TriG / N3 的区别

| 特性 | N-Triples / N-Quads | Turtle | TriG | N3 |
|---|---|---|---|---|
| 基础单元 | triple / quad | triple | triple / quad（图块） | triple / formula |
| 图组织 | 平铺图名 | 无 | `GRAPH` 图块 | 公式块 `{ ... }` |
| 前缀 | 无 | `PREFIX` | `PREFIX` | `PREFIX` / `@prefix` |
| 集合 | 无 | `( ... )` | `( ... )` | `( ... )` |
| 属性列表 | 无 | `[ ... ]` | `[ ... ]` | `[ ... ]` |
| 规则 | 无 | 无 | 无 | `{ ... } => { ... }` |
| 变量 | 无 | 无 | 无 | `?x` |
| 内置谓词 | 无 | 无 | 无 | `math:`, `log:`, `string:` |
| 资源路径 | 无 | 无 | 无 | `!`, `^` |

示例：

```text
# Turtle：三元组
<http://example.org/s> <http://example.org/p> <http://example.org/o> .

# TriG：命名图块
GRAPH <http://example.org/g> {
  <http://example.org/s> <http://example.org/p> <http://example.org/o> .
}

# N3：公式 + 规则
{ <http://example.org/s> <http://example.org/p> <http://example.org/o> }
  => { <http://example.org/s> <http://example.org/q> "true" } .

?x a :SuperHero => { ?x a :Legend } .

<http://example.org/s> <http://example.org/p> (
  <http://example.org/a> <http://example.org/b>
) .
```

N3 实现层通常把公式视为“不直接断言为真但参与规则推理的图”。

### 1.2 结构

- 基础记录与 `Turtle` 共享：主语 + 谓语 + 宾语 + `.`。
- 支持前缀声明 `@prefix ex: <...> .` 和 `BASE`。
- 支持省略主语/谓语：使用 `;` 和 `,`。
- 公式块 `{ ... }` 常用于规则前提/结论。
- 集合 `( ... )` 与属性列表 `[ ... ]` 作为一等术语出现。

### 1.3 组成元素

- `IRI`：`<http://...>` 或 `prefix:local`。
- `Blank Node`：`_:label` 或 `[...]`。
- `Literal`：`"text"`，可带语言标签或数据类型。
- `Collection`：`( a b c )`。
- `Formula`：`{ ... }`。
- `Variable`：`?x`。
- `Builtin`：`math:quotient(...)` 等。
- `TripleTerm`：`<<( <s> <p> <o> )>>`。

### 1.4 轻量命名速查（N3 常见概念）

这些本库不做术语规约，也不强制作语义解释。

| 名称 | 描述 |
|---|---|
| Formula | 前提/结论里的 `{ ... }` |
| Rule | `{ ... } => { ... }` |
| Builtin | `math:quotient`, `log:implies` 等 |
| Resource Path | `!`, `^` 用于宾/主位路径 |

### 1.5 N3 超集入 → 三元组出（降级规则）

| 从文档进入的 N3 特性 | 解析器接受情况 | 物化器处理 | 输出端表现 |
|---|---|---|---|
| 前缀局部名 | 接受 | 展开为全 IRI（PrefName 不是输出契约） | 逐行 s p o . 中的 IRI 原文 |
| `@prefix` / `BASE` | 接受 | 不保留化简 | 不回写为简写 |
| 集合 `( ... )` | 接受 | ADR-003a：退化为单一 BNode 身份 | 只输出身份节点，不保留结构糖 |
| 公式 `{ ... }` | 接受 | 按公式语义决定（不直接断言为真） | 只输出被断言的三元组 |
| 规则 `{ ... } => { ... }` | 语法接受 | 不执行、不断言 | 不输出规则 |
| 变量 `?x` | 词法接受 | 结构检查 | 结构保留（g 槽）= 当前输出端按约定报错 |
| TripleTerm | rdf12=true 时才接受 | 语义保留 | 输出为标准三元组/quad |
| 不可识别的 N3 特性 | 解析报错 | 不入流 | 不吞错误 |

讲得更直白一点：

- `Serializer` 目前**只有 `N-Triples`** 是正式的序列化出口。
- “图名槽存在”立即违规；即使允许图名视角，PrefName 也没有“回写”步骤。
- 已接表的不透明结构（集合链、公式内容）统一折叠成 identity node，不算语法还原。

### 1.6 RDF 1.1 / 1.2

- `RDF 1.1` 不支持 `VERSION`、`TripleTerm`。
- `RDF 1.2` 支持 `VERSION "1.2"`、`TripleTerm`、语言方向（本实现按 `rdf12` 开关控制）。

---

## 2. 架构说明

`gen_n3` 采用与 `gen_trig` 一致的生成契约分层：生成状态机 + 用户实现层 + 调度模板。

### 2.1 分层职责

| 文件 | 分层 | 职责 |
|---|---|---|
| `n3.mbt` | 生成契约层 | `N3Event` / `N3State` / `N3Context` / `step()` / 副作用枚举。 |
| `engine.mbt` | 机械层 | 主循环模板；方言处理；错误恢复；公式/集合/规则触发。 |
| `parser_slice.mbt` | 加工层 | `N3PendingQuad -> QuadSpan` 组装；验证调度；行号统计。 |
| `lexer_*.mbt` | 词法层 | 生成 `N3Event`。 |
| `actions.mbt` | 业务热路径 | 槽位写入与副作用回调。 |
| `materialize_n3.mbt` | 物化层 | 生成 `QuadSpan -> QuadEmit`；公式、集合、变量语义处理。 |
| `serialize_n3.mbt` | 序列化层 | 当前仅输出 `N-Triples`；`Quad` / 原生 `N3` 语法糖均未实现，PrefName 不复写。 |

### 2.2 方言开关

本包提供 `N3Dialect`：

- `N3Dialect::N3`：完整 N3，接受规则、公式、变量。
- `N3Dialect::RDFStarOff`：关闭 RDF-star 相关术语（当前预留）。

典型入口：

```moonbit
let engine = @gen_n3.N3Engine::from_bytes(data, dialect=@gen_n3.N3Dialect::N3)
let slice = @gen_n3.SliceParser::new(engine, data[:])
```

### 2.3 生成状态机核心

- `step()` 写入 `N3Context` 并根据转移表决定下一步。
- `N3Context` 新增：`prefixes / bases / slot_stack / pred_kind / variable_name / rule_side / iri_upcast / version_lit_ok`。
- 循环模板解释 `N3Effect`，新增 `Reset` / `Sequence` / `PopBnp` / `OpenSlot`，用于公式进入退出、属性列表收尾、集合链管理。

### 2.4 切片组装与物化分工

- 词法阶段只产出 `Span`。
- 物化层处理公式是否断言、`rdf:first/rdf:rest` 提升、BNode 标签生成。

### 2.5 错误模型

与 `gen_nquads` 相同：`StructSyntaxErr`、`SyntaxErr`、`ValidationErr`、`IriErr`。

---

## 3. API 使用

### 3.1 解析全部输入

```moonbit
let input : Array[Byte] = ...
let engine = @gen_n3.N3Engine::from_bytes(input, dialect=@gen_n3.N3Dialect::N3)
let slice = @gen_n3.SliceParser::new(engine, input[:])
let (quads, errors) = slice.parse_all()
```

### 3.2 物化（第一遍）

```moonbit
let (emits, materialize_errors) = @gen_n3.materialize_all(quad_spans)
```

物化后得到的是「已降到 RDF 视图」的 QuadEmit：
- 语法定量（前缀/BNode 标签/集合链）按 ADR-003a/b 处理，
- 未被理解的 N3 变量属性（变量规则、通用量化）会在物化阶段拒收。

### 3.3 二次物化（读取到自己知道的位置）

如果你需要按图的局域/全局规则合入事实，可在第一遍物化后再做一回剪枝合入。

### 3.4 格式化输出

- 当前只有 `N-Triples`（逐行 `s p o .`）已落地；
- 写 Quad / 写 N3 语法当前不实现：图名出现直接按约定报错，PrefName 残留同样拒。

---

## 4. 与其他格式的关系

- `N3` 是 `Turtle` 的超集：支持公式、规则、变量、路径、集合。
- `N3` 包含 `TriG` 的图块概念（以公式表达），但语义上“不强制断言图内为真”。
- 当前 `gen_n3` 以四元组管线输出；公式与规则面可在物化层展开为普通 Quad 集合。

---

## 5. 最小使用示例

```moonbit
fn main {
  let content =
    #|@prefix : <http://example.org/> .
    #|:Alice :knows [ :name "Bob" ] .
    #|{ :Alice :likes :Bob }
    #|  => { :Bob :friendOf :Alice } .
  let data = @utf8.encode(content).to_array()
  let engine = @gen_n3.N3Engine::from_bytes(data, dialect=@gen_n3.N3Dialect::N3)
  let slice = @gen_n3.SliceParser::new(engine, data[:])
  let (quads, errors) = slice.parse_all()
  println("parsed \{quads.length()} quads, \{errors.length()} errors")
}
```

---

## 6. 常见用法

### 6.1 公式（Formula）

```text
{ <http://example.org/s> <http://example.org/p> <http://example.org/o> }
```

### 6.2 规则

```text
{ ?x a :SuperHero } => { ?x a :Legend } .
```

### 6.3 集合

```text
<http://example.org/book> <http://example.org/author> ( <a> <b> <c> ) .
```

### 6.4 内置谓词

```text
{ (?heightCm 100) math:quotient ?heightM } => { ... } .
```

---

## 7. 约定与稳定性说明

- `N3Dialect` 对外接口稳定；事件与效果枚举保持作者不变。
- `N3ActionError` / `N3EffectError` 用于内部回收。
- 外部优先使用 `parse_all` / `parse_next` / `materialize_all`。

---

## 8. FAQ

1. N3 与 TriG 如何选择？  
   若只需要命名图组织，选 `TriG`。  
   若需要规则、公式、变量、内置信赖，选 `N3`。

2. 公式块何时被断言？  
   默认不直接断言；物化层可根据需求选择展开或保留。

3. 变量 `?x` 的生命周期如何？  
   `?x` 在规则前提/结论范围内有效；当前 `gen_n3` 不做规则执行，只负责语法与物化。

4. `math:`, `log:` 等内置谓词如何表示？  
   作为普通 IRI 或前缀写法出现在谓语位，下游可识别并评估。

5. N3 能不能原样回写？  
   不能。解析面接受 N3 超集，但输出只有 N-Triples；集合与公式的糖衣结构不保留。

6. 当前输出为什么只有三元组？  
   这是当前约定边界：图名槽存在会触发约定错误，PrefName 不参与回写，集合链和公式内容只保留身份节点。
