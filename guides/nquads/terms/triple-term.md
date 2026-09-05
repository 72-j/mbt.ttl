# TripleTerm

TripleTerm 允许将三元组包成一个资源，即引用三元组。

---

## 语法

```text
<<( <s> <p> <o> )>>
```

---

## 位置

- 主语或宾语。
- 不进入谓语位。

---

## 版本差异

- RDF 1.1 不支持。
- RDF 1.2 支持，等价 RDF-star 风格术语。

---

## 示例

```text
<<( <s> <p> <o> )>> <http://example.org/mentioned> "true" .
```
