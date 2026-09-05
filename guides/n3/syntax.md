# N3 语法说明

N3 在 Turtle 基础上增加规则、公式、集合与资源路径。

---

## 1. 基本结构

- 前缀 / Base / 三元组都兼容 Turtle。
- 公式块 `{ ... }` 可作为主语或宾语出现。
- 省略主语与谓语的写法和 Turtle 一致。

## 2. 公式与规则

```text
{ <s> <p> <o> } => { <s> <q> "true" } .
```

- 前提/结论都使用公式块形式。
- 支持变量 `?x`。

## 3. 集合与属性列表

```text
<s> <p> ( <a> <b> <c> ) .

<s> <p> [ ex:name "A" ] .
```

## 4. 变量

```text
?x a :SuperHero => { ?x a :Legend } .
```

## 5. 内置谓词

```text
{ (?heightCm 100) math:quotient ?heightM } => { ?heightM 1 } .
```

## 6. RDF 1.1 / 1.2

- 支持 `VERSION "1.2"` 可选声明。
- TripleTerm 由 `rdf12` 开关控制。

## 7. 与本仓库实现的对应关系

- `gen_n3` 沿用 `nquads` 分层：`N3Context` 增加公式与规则专用字段。
- 物化层负责公式语义（断言/保留）与集合展开/拒绝（ADR-003a/b）。
