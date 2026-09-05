# GraphName

图名是 N-Quads 中专有的术语位置。

---

## 语法

- IRI：`<g>`。
- Blank Node：`_:g`。

---

## 限制

- 不允许字面量。
- 不允许 Prefixed Name。

---

## 示例

```text
<s> <p> <o> <http://example.org/g> .
<s> <p> <o> _:g .
```
