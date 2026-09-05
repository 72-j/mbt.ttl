# Collection

集合提供有序列表结构，在 TriG 中可出现在主语/谓语/宾语/图内容中。

---

## 语法

```text
( <a> <b> <c> )
```

---

## 语义

- 成员顺序保留。
- 语义上不等同于重复谓语，而是单一集合值。
- 可进入图块或属性列表。

---

## 示例

```text
<http://example.org/book> <http://example.org/author> ( <a> <b> <c> ) .
```
