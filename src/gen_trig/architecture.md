# gen_trig 架构一页

> **定位**：本卷是**入口导读**（一页看懂）：只速查、不落正文。结构事实看 `spec.md`，决策看 `adr.md`，
> 红线看 `const.md`，门与数字看各门文件与基线文件（模板：`bangto/world/architecture-template.meta.md`）。
> **卷名沿革**：本卷 2026-09-20 由 `ARCHITECTURE.md` 更名 `architecture.md`（世界宪法 v2.6「实例卷名一律小写规范名」
> + v2.8 立 `architecture` 卷位）；`adr.md` 里旧名出现处为**历史语境**，按规保留。

版本：v1.0.0（2026-09-12 立页，T16 卷面补全产物）

本页是**导读**：一页看懂 trig 解析器的分层、生成链、门与不变量。详细事实在 `spec.md`，
红线在 `const.md`，决策在 `adr.md`，路线在 `todo.md`，整改上下文在 `ctx.md`。

## 五层管线

```
Lexermoon / Lexerc(C)      词法器：无脑扫（加宽口径），Token 与 span 口径两器一致
      ↓ token_to_event
lexer_adapter.mbt          适配层：结构分类 / 裸词 / @ 邻接指令名（零空格拆分）
      ↓ TrigEvent
TrigEngine（表驱动）        step()：唯一决策点；EmitQuad(ResetScope) 携带收拾粒度
      ↓ TrigPendingQuad（组装在 loop）
TrigSliceParser            parser_slice.mbt：组装（帧携带返回态）+ 轻验 + TT 拆壳
      ↓ QuadSpan（含 pk/pver/bver 快照）
TrigMaterializer           物化 + 深验四门（单遍；arena 只追加）
      ↓ QuadEmit
serialize_trig.mbt         序列化：字节保真回写 + 图归并
```

> **装配层共享件**：`../gen_shared/`（14 项纯函数，T17 / C-T8 抽件；包级 `using @gs` 引入，调用点零改写）。
> 语义层（`validate_term` / `classify_structural` / `classify_prefname` / `span_of_event`）与方言 ctx 件**有意分叉**，
> 逐条理由见 `spec.md` §7.1（trig 侧）/ 对侧 ADR-TRIG-017。

## 生成链（三方言里最绕的一条）

```
src/rdf/domain/trig_domain.toml
   → src/rdf/domain_to_ir.mbt          （域推导：状态/事件/效果/动作）
   → src/rdf/fsm_out/trig_fsm.toml     （IR）
   → src/fsm/cmd（fsm-gen CLI）        （v1 codegen）
   → src/ttl/src/gen_trig/trig.mbt     （⚠ 生成物，禁手编）
```

- **IR 侧门**：`moon test src/rdf` 的「双文件编译 ≡ `fsm_out/trig_fsm.toml`」（四腿对照）。
- **产物侧门**：**尚缺**（T10 立）——`trig.mbt:4` 的 `Generated at:` 是墙钟值 ⇒ 再生不可复现，
  当前一致性靠 `domain_to_ir.mbt` 的人工"逐行对齐"注释（`const.md` §5 因此禁止无对拍改生成面）。

## 契约成员（声明属 Contract，实现属 Assembly）

| 成员 | 声明 | 实现 | 现状 |
|---|---|---|---|
| `TrigActions`（语义落点） | `trig.mbt:240` | `actions.mbt`（`Hooks`） | 已接活 |
| `TrigEffectHandler`（效果面 Hook） | `trig.mbt:1138` + 默认 impl `:1172` 起 | **无**（引擎自带效果语义） | **孤儿挂点**（T11） |
| `TrigSupervisor`（控制流 Hook，正名 `Supervisor`；T13 已落地） | `trig.mbt:223` | `engine.mbt:227/240/314/344` + `extend:353` | 已接活 |

## 不变量（速查，详 `spec.md` §3）

I-1 表是唯一转移权威（例外 = pop 兑现帧携带返回态）｜I-2 `emits.length == quads.length`｜
I-3 `serialize ∘ parse = 恒等`｜I-4 fresh 身份 = 开括号 offset，集合链 = `Span(open.0, k+1)`｜
I-5 `data` 只读 / `arena` 只追加（span 可能指向 arena）｜I-6 图块区域封闭（无 `Lbrace` 出边）｜
I-7 单遍深验｜I-8 合成谓词 `pk` 读出即归 `Normal`。

## 验收门（只引出处，不抄数字）

| 门 | 判据 / 命令 | 数字出处 |
|---|---|---|
| 单元 | `cd src/ttl && moon test src/gen_trig` | CI `test` 作业日志（命令即判据：0 failed） |
| 警告 | `moon check --deny-warn` | CI `static` 作业（0 条即绿） |
| 套件（四套 `pin=true`） | `moon test src/gen_trig`（自报行 `=== … ===`） | **复核表 `../suite-review.txt`**（`[trig]` 节；同命令可复现） |
| IR 侧 | `cd moonttl && moon test src/rdf` | CI/home 日志（0 failed） |
| 产物侧 | — | **缺**（`spec.md` §8 C-T10 族 `[立案]`） |

> 口径：**数字不落在导读卷**（`bangto/world/const.md` §5.6.3 单一数字源）；门清单只写"判据/命令 + 出处"，
> 数字与自报行一律看**复核表**（`../suite-review.txt`）与**基线文件**（`../coverage-baseline.txt`、
> `../reachable-coverage-baseline.txt`）。

## 已知缺陷 / 预留下（详 `spec.md` §7 台账）

- `<< >>` 壳内 `^^datatype` 误拒（R-T10 [立案]，bench 语料规避）
- 三引号规范化未设计（R-T11 [立案]）
- MoonBit 词法落后 C 侧 2.3–2.6×（R-T12 [立案]）
- `@keywords` 语义豁免未接表（R-T13 [立案]）
- 包内 5 个 `.bak`、生产文件 21 个内联 test、公共面未收窄（T14/T15/T12）

## 与 gen_n3v2 的关键差异

| 维度 | gen_n3v2 | gen_trig |
|---|---|---|
| 生成链 | 自含（`src/rdf/n3gen` parse→validate→emit） | 三层（domain → IR → fsm CLI） |
| 产物门 | **G9 黄金门**（ts 钉 + 逐字节 + 强幂等） | **无**（仅 IR 侧门 + 人工对齐） |
| 方言特性 | N3（公式/量化/路径/倒装） | TriG（图块/GRAPH/注解区/集合） |
| 图形语义 | 无图块 | `EnterGraph`/`ExitGraph` 双路由（ADR-TRIG-008） |
