# TripleTerm

TripleTerm 可在主语或宾语位置表达引用三元组，支持嵌套到图块中。

---

## 语法

```text
<<( <s> <p> <o> )>>
```

---

## 位置

- 主语、宾语。
- 可出现在 `GRAPH` 块内。

---

## 示例

```text
<<( <s> <p> <o> )>> <http://example.org/mentioned> "true" .
```
