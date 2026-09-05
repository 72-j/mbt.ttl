# TriG 语法说明

TriG 是 Turtle 的扩展语法，专门用于表达命名图。

---

## 1. 基本结构

与 Turtle 相同，支持：

- 前缀声明
- Base
- 三元组
- 省略主语/谓语（; / ,）
- 集合 `( ... )`
- 空白节点属性列表 `[ ... ]`

## 2. TriG 特有结构

### 2.1 GRAPH 块

```text
GRAPH <http://example.org/g> {
  <s> <p> <o> .
}
```

- `GRAPH` 后跟随图名。
- 图块内可按 Turtle 语法写三元组。

### 2.2 默认图

不带 `GRAPH` 语句的三元组属于默认图。

### 2.3 图块嵌套

允许图块内出现集合、属性列表、TripleTerm 等复杂结构。

---

## 3. 空白节点

TriG 支持两种形式：

- `_:label`
- `[ ex:p "v" ]`

---

## 4. 集合

```text
<book> <author> ( <a> <b> <c> ) .
```

---

## 5. TripleTerm

```text
<<( <s> <p> <o> )>> <http://example.org/mentioned> "true" .
```

---

## 6. 注释与空白

与 Turtle 相同。

---

## 7. RDF 1.1 / RDF 1.2

- `VERSION "1.2"` 可选声明。
- TripleTerm、语言方向必须在解析器开启 RDF 1.2 特性时接受。

---

## 8. 与本仓库实现的对应关系

- `TrigDialect` 决定是否接受图块。
- `QuadSpan` 携带 `pk / pver / bver`，用于集合和前缀账本。
- `materialize_trig.mbt` 负责集合展开和 BNode 标签生成。
