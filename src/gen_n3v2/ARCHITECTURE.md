# gen_n3v2 架构一页

N3 解析包（模块 `thy1016/moonttl`，嵌套仓 `src/ttl`）。生成状态机 + 用户实现层；
生成件 `n3.mbt` 由外层仓表源再生，禁手编。细节卷：`spec.md`（架构规格）、`adr.md`（役录裁决）、
`todo.md`（整改立项）、`ctx.md`（上下文与工程经验）。用户指南：`guides/n3/`。

## 五层

```
词法复用   @nquads.Lexermoon            bytes → Token（与 C 版同型同宽）
事件适配   lexer_adapter.mbt            Token → N3Event（?x/[] 合并、@prefix:/<- 拆字）
状态机     n3.mbt（生成·G9 禁手编）      41 事件 × 55 状态 × 384 转移的 step；类型/ctx/业务面 trait
用户机械   engine.mbt + actions.mbt     主循环/效果解释/恢复 + 48 action 落槽/压栈/路径 desugar
组装下游   parser_slice → materialize_n3 → serialize_n3
           QuadSpan（轻验）→ QuadEmit（四门深验）→ N-Triples 文本（拒 PrefName/图名残留）
```

数据流：`Lexermoon → N3LexerAdapter → N3Engine.next → step(表) → N3Effect → interpret
→ N3PendingQuad → assemble/validate → QuadSpan → N3Materializer → QuadEmit → N3Serializer`。

## 生成链（黄金门 G9）

```
外层仓 src/rdf/n3gen/{n3v2_base.toml, n3v2_trans.toml}
  → n3gen_build（parse → validate G1–G8 → emit）→ n3v2_out.gen
  → cp src/ttl/src/gen_n3v2/n3.mbt（G9 逐字节对拍 + 强幂等）
```

表变 → 再生 → cp；手编 `n3.mbt` 会被 G9 判红。生成器测试 `moon test src/rdf/n3gen`。

## 不变量（I-1..I-9，详 spec §3）

| # | 一句话 |
|---|---|
| I-1 | span `(offset,len)` 是词项唯一身份；fresh 节点 = 开括号/操作符 token span |
| I-2 | arena append-only；早先取出的 view 永久有效 |
| I-3 | 正例 `emits.length == quads.length`（物化不丢项） |
| I-4 | EOF 合法送达一次，其后 `None` = 枯竭 |
| I-5 | 错误恢复只停 Dot → 归位 `ExpectSubject`，清栈/清注解账 |
| I-6 | 状态转移由转移表唯一管理（+2 登记破例，役23 机制收敛） |
| I-7 | 生成物禁手编；表变 → 再生（G9） |
| I-8 | TOML 契约兼容演进（新键可选、未知键忽略、删键需同改手写文件） |
| I-9 | 错误通道单一：`error_spans` 累积 + drain 同序（役24） |

## 术语

Span（`(offset,len)` 对）/ 槽（`Slot`，bnp/集合/公式帧）/ 快照四槽（`pk`/`pver`/`bver`/`iver`）
/ PrefName（`prefix:local` 局部名，输出端展开为全 IRI 不回写）/ TT（`<<...>>` TripleTerm 壳）。
全卷：`spec.md` §术语、`guides/n3/README.md` §1。

## 预留位清单（仅登记、不接语义，动前先读 ADR）

| 位 | 状态 | 说明 |
|---|---|---|
| `QuadEmit.graph` 恒 `None` | 预留 | N3 无图语法；serializer 见图名即报错，物化层不产图名 |
| `PredKind::RDFFirst/RDFRest` | 预留 | ADR-003b 显式链物化位；默认集合走 ADR-003a 单一 BNode，恒 `Normal`/`KwA`/`SameAs` |
| `N3Dialect::RDFStarOff` | 预留 | 方言开关；当前仅 `N3` 开放 |
| `iri_upcast`（ctx 字段） | 活机制 | 显式 `rdf:first/rest` 书写时版本提升账本（ADR-003b 回扫用），非死位 |
| `variable_name` / `rule_side` | **已删（役26）** | 声明后从未接线；自表源删除并再生，`RuleSide` 枚举连坐删（ADR-005 语义保留在 spec） |
| `TripleTerm` 门 | 开关 | `rdf12` 能力开关控制（默认关）；开时接受 `<<...>>` |
