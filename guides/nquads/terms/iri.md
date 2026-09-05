# IRI

IRI 是 N-Triples / N-Quads 中表示资源的标识符。

---

## 语法

- `<scheme:...>` 形式。
- 内容可为任意合法 IRI 文本，实际由解析器校验。

---

## 位置

- 主语、谓语、宾语均可。
- 图名位可为 IRI。

---

## 验证

- 严格模式校验 scheme、字符、路径、authority 等。
- 宽松模式放宽部分校验。

---

## 示例

```text
<http://example.org/s>
<urn:isbn:0451450523>
```
