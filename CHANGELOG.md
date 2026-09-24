# Changelog

本文件面向**使用者**，记录每版对外可见的变化（API / 性能 / 语义修正 / 工程）。
内部战役账（役录、复核面、勘误沿革）见 `todo.md` / `review.md`，不在此重复。

数字单一来源纪律：性能数字一律引用 `perf-review.txt`（面四），本文件只转述、不另立。

## 0.3.0（2026-09-24）

本版跨度 2026-08-21 → 09-24（自 0.2.2 起 198 笔），主线 = 三方言引擎/物化全面重建 +
性能三役（P4 词法 / P2 扫描器直产 / P3 产物模型）。

### 破坏性变更

- **`QuadEmit` 平化**（产物模型 P3）：`Subject` / `Object` / `GraphName` 三个带载荷
  枚举除名，改为 **`TermKind`（8 常量臂：Iri/BNode/PrefName/TripleTerm/Variable/
  Literal/Formula/DefaultGraph）+ 逐位 `s_kind`/`s_view`、`o_kind`/`o_view`、
  `g_kind`/`g_view` 直挂**。每 quad 分配从 5 箱（具名图）降到 1 箱。
  - **图位封闭门**：图名位只接受 `Iri` / `BNode` / `DefaultGraph`；其余 kind
    （如 Literal 塞图名位）一律 `Err`，任何格式/策略（含 Turtle Drop）不豁免。
- **扫描器直产事件**（P2 刀 a）：`Lexermoon::next` 直接产出 `NQuadsEvent?`
  （`Token` 类型仅存 C-FFI 词法器面）；跨包 span 供给走 `last_unknown_span` 单槽。
- 物化/序列化 API 随 `QuadEmit` 形态联动更新（三方言 `materialize_*` /
  `serialize_*` 签名不变，构造/匹配面按 kind 重排）。

### 性能

（口径 = `--target native --release` · 10k 语料；复现条件与沿革见 `perf-review.txt`）

- **物化段稳态 −23%**（同探针交错 A/B：293–368 → 214–300 µs）。
- **词法电池 10k 累计 −31%**（1723 → 1114 µs；字节类表驱动 + 热循环局部化 +
  扫描器直产，事件分母新带）。
- 端到端 bench 千行 0.000614 → **0.000565 ms/三元**；对外对端口径仍为
  **≈3.3× 量级参照**（vs Oxigraph 公开读数，非同口径对拍，见 README「性能实测」节）。

### 语义 / 修正

- **N-Quads 环级恢复道入声明面**：`[type_mapping.recovery_close]`（Dot/EOF → All）
  与引擎恢复行为同源落盘，生成器可复现。
- **语言标签 span 语义**：span 恰覆盖子标签；4 位语言拒绝；`X-` 前缀大小写不敏感。
- **PrefName / bnode 冒号混淆修正**：`_:x` 含冒号，形判定先排除 `_:` 再嗅探 PrefName。
- **`@keywords` 表源化**：受理层/声明列表区层/词位全部入表，生成器同源再生。
- **RDF 1.2 注解与 Triple Term**：注解 fresh 语义 + Tail 双生态；TT 黑盒单槽组装。

### 工程 / CI

- CI 双档（wasm + native）× 三 OS；覆盖率棘轮 + 可达命令名分母棘轮；
  perf / coverage / suite 三张复核表逐字节复现门；净检出（crlf）元门。
- 测试规模：**507/507**（默认档）· **521/521**（native 档）。
- W3C 套件：N-Quads 89/89 · TriG 357/357 · Turtle 316/316 · N3Tests
  neg 23ok/0miss + pos+eval 205 clean · rdf12 全绿（四套件逐字钉）。

## 0.2.2（2026-08-21）

基线版。三方言（N-Quads/N-Triples、TriG/Turtle、N3）解析 + 序列化 + 物化；
RDF 1.2 语法开关；双词法器 parity；表/TOML 驱动生成器与黄金对拍门。
