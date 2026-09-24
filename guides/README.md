# RDF 文本格式用户文档

本目录收录 `N-Quads`、`TriG`、`N3` 相关用户指南与补充说明。

**读者路径（建议顺序）**：先读目标格式的 [语法说明](./n3/syntax.md)（TriG 见 [trig/syntax.md](./trig/syntax.md)、
N-Quads 见 [nquads/syntax.md](./nquads/syntax.md)）→ 再翻该族的 [术语总览](./n3/terms/README.md)
→ 需要跨格式对照时读 [对照](./n3/comparison.md)。**每页顶部都有一行导航**（指南索引 / 方言 / 语法 / 术语 /
数据类型 / 对照），可随时横跳；三族页面**同构**（同目录同名文件）。

**语言 / 更新 / 许可**：本目录是**中文**指南（英文总览见仓根 `README-en.md`）；自 **0.3.0** 起定稿维护，
更新历史见 git；本指南为**原创文本**，适用本项目根 `LICENSE`（Apache-2.0）。
⚠️ **不覆盖** `.rdf-tests/**` 下的 W3C 测试**语料**——那是第三方素材、适用其自带 W3C dual license
（见 `.rdf-tests/README.md` 的 Modifications & attribution）。

---

## 文档索引

- [术语对照：代码注释里的"黑话" → 大白话](./terminology.md)（读代码注释 / 提交信息 / CI 报错前先看这页）
- [N3](./n3/README.md)
  - [N3 / Turtle / TriG / N-Quads 对照](./n3/comparison.md)
  - [语法说明](./n3/syntax.md)
  - [数据类型与节点类型](./n3/datatypes.md)
  - [术语总览](./n3/terms/README.md)
- [N-Quads](./nquads/README.md)
  - [语法说明](./nquads/syntax.md)
  - [术语总览](./nquads/terms/README.md)
  - [术语与版本对照](./nquads/comparison.md)
  - [数据类型与节点类型](./nquads/datatypes.md)
- [TriG](./trig/README.md)
  - [语法说明](./trig/syntax.md)
  - [术语总览](./trig/terms/README.md)
  - [TriG / Turtle / N-Quads 对照](./trig/comparison.md)
  - [数据类型与节点类型](./trig/datatypes.md)
