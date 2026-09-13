# gen_nquads 架构规格（spec）

版本：v1.0.0
分工（五卷，2026-09-13 对齐 gen_trig 口径）：`const.md` 红线 / **本文件** 结构事实与已验证口径 /
`adr.md` 决策录（`ADR-NQ-nnn`，由 `todo.adr.md` 更名）/ `todo.md` 路线与账本 / `ctx.md` 整改上下文。
**定位 = B 冻结样本**（2026-09-13）：不演进功能、不做命名/公共面迁移；只做钉门 / 清障 / 修文档锚点。
首版动机：2026-09-05 词法事件槽位形状验证（三 term 事件是否拆 (span, span)）。

---

## 1. 数据面（已验证）

- QuadSpan 五槽（type.mbt）：subj / pred / obj 均单 `ArrayView[Byte]`，graph 可空，
  subj_type / obj_type 标词项类别——**字节保真单 span 槽**，无内部细分槽。
- QuadEmit（@nquads 物化模型）同口径：view 或指原 data（零拷贝）。
- literal.mbt 的 `LiteralContent::TypedLiteral(value, datatype)` 是规范化构造器，
  吃**已分离**的两段——它不重扫原始 span。

## 2. 词法事件槽位口径（2026-09-05 验证定案）

三个 term 事件 `NQuadsBlankNode / NQuadsLiteral / NQuadsPrefName` 均为**单 span**，
不拆 (span, span)。词法无脑扫出的词项内部分界线，由 validate 单点裁决与产出，
不进事件/槽位形状：

| 事件 | 裁决 | 证据 |
|---|---|---|
| NQuadsPrefName | 不拆：N-Quads 无 prefixed name，全包**零表行**（仅 nquads.mbt:13 枚举声明），永远 UnexpectedEvent | grep 全包唯一命中 |
| NQuadsBlankNode | 不拆：`_:` 定界固定 off+2 常量算术，无模糊性 | materialize / serialize 直写 label |
| NQuadsLiteral | 不拆（有真分界，但归属 validate 单点）：闭引号 → `@lang` / `^^<dt>` 分界已由 `validate_literal`（validate_helper.mbt）单遍扫出（scan_string_body → close），裁决后即弃——**门卫不出槽位** | materialize_quad 零 lang/^^ 处理；调用点仅主门与嵌套内层两处 |

- 拆事件的代价面：`span_of_event` → normalize 归位 → 生成表 payload → QuadSpan →
  QuadEmit 五道签名穿透，违反「词法无脑扫 / 引擎尾点归位 / 组装后 validate_helper」
  分层（const.md §4）——结构判断不得提前回词法/归位层。
- **与 gen_n3 的对照**（为何 n3 拆了、nquads 不拆）：n3 的 `N3Literal(span, lang)`
  双载荷是 Lexermoon 吞边界 + langtag 恰覆盖子标签的物化口径逼出来的（n3 物化层要发
  langString，需要 lang 精确 span）；nquads 物化层字节保真直写，无此需求。

## 3. 演进位（最小改动通道）

若将来物化/规范化需要两段内容（lang/dt 独立 span、canonicalization）：
**门卫升级为 splitter**——`validate_literal -> Result[Unit, ParseError]`
改富裁决 `Result[LiteralSplit, ParseError]`（在已算出 close 的位置顺手产出
value / suffix span），下游从门卫结果取两段。
词法事件形状与三层宪法边界一寸不动。

---

## 4 结构事实（2.0 前卷正文搬入，2026-09-13；正文保真）

> **来源**：旧卷 `todo.adr.md`（已更名 `adr.md`）的 §2/§3，按 `ctx.md` R-N4 搬入本卷。
> **现状增补（2026-09-13）**：① 生成面事实源 = `src/rdf/domain2/nquads_{base,domain}.toml` → `fsm_out/nquads_fsm.toml`
> → 产物（配方：`moon run src/fsm/cmd -- <fsm_out> --ts 1788844502518 -o <产物>` + `moon fmt`）；
> ② 产物侧有黄金门（`nquads 产物黄金门`，ADR-9）；③ 下文提及的 `test_nquads.toml` 为**旧输入件**（非事实源）；
> ④ RDF 1.2 开关的现代口径见 `validate_helper.mbt` 的 `rdf12`（1.2 默认）+ `scalar_only`（转义严格度）。

## 2 nquads 解析规则规格

五层管线：Lexermoon/Lexerc（词）→ token_to_event（适配）→ `step()`（nquads.mbt 生成表）
→ SliceParser（组装 + validate_helper 验证）→ materialize_quad（物化）→ serialize_nquads。

### 2.1 与 trig 的语法面差异（窄集）
- **无指令**：无 @prefix/@base/PREFIX/BASE（N-Quads 无前缀机制），
  PrefName token 照出词（词法无脑扫）但落表即 UnexpectedEvent 兜底。
- **无图块/无 GRAPH**：图名只能做第四元（ExpectDotOrGraph 收 IRI/BlankNode）。
- **无数值词项**：N-Quads 只有 IRI/BNode/Literal（+1.2 TripleTerm 宾位）；
  数字整词出 Unknown → 兜底。
- **行口径**：每行一记录，Dot 发射 ResetScope::All。

### 2.2 词法层（Lexermoon；语义以 C 版 lexerc_ffi.c 为标准对齐）
| 形态 | 产出 | 机械 |
|---|---|---|
| `"..."` `'...'` `"""..."""` | Literal | 转义对整对消费；^^/@ 后缀整词扫入；未闭壳宽容出词 |
| `<<( )>>` / `<< >>` | TripleTerm | 平衡深度扫描；字符串物理单元；RDF 1.2 只在宾位 |
| `_:name` | BlankNode | 名字含 `.`；多字节标签字符加宽 |
| 字母 / `:` 起头 | PrefName | 无脑扫加宽（`:`/内部 `.`/`\X`/`%HH`/多字节并入）；**尾部裸 `.` 回退** |
| 数字（可带±符号） | Unknown | nquads 无数值词项，整词兜底 |
| `.` `;` `,` | Dot/Semicolon/Comma | 结构标点 |
| `#` | — | 注释到行尾跳过；其余单字符一律 Unknown(1) |

### 2.3 引擎表（nquads.mbt，test_nquads.toml 生成）
- 5 状态线性链：ExpectSubject → ExpectPredicate → ExpectObject →
  ExpectDotOrGraph → ExpectDot，14 条转移边。
- 槽位动作：set_subject（Iri|BlankNode）/ set_predicate（**仅 Iri**）/
  set_object（Iri|BlankNode|Literal|TripleTerm）/ set_graph（Iri|BlankNode）。
- 发射边：ExpectDotOrGraph 与 ExpectDot 收 Dot → EmitQuad(All) 回环；
  `;` → PredObj / `,` → Object（TriG 预埋边）。
- 词项类型探测在组装层：QuadSpan 带 subj_type/obj_type（TermType）。

### 2.4 验证（validate_helper.mbt，组装后单遍）
- span 界检查（短路序：先界后索引）→ 切 view → 逐词项裁决：
  subject（IRI 壳/BNode 字符集）、predicate（必须 IRI）、
  object（三类 + TripleTerm）、graph（IRI/BNode）。
- 词项深验依赖同包文法件：iri.mbt（RFC 3987 解析）、langtag.mbt
  （子标签 span 语义、4 位语言拒绝、X- 不分大小写）、literal.mbt
  （转义集/ BaseDirection langdir）。
- `lenient` 开关跳过验证（链式调用场景）；`rdf12` 开关切 1.1 严格/1.2（langdir 等）。

### 2.5 物化与序列化
- materialize_quad：QuadSpan → QuadEmit（批量 materialize_all 逐条搬错误收集）；
  注：data 深验未接入（参数注释占位），与 trig 单遍四门口径对齐待做（§5）。
- serialize_nquads：旋钮正交不混轴——format（Triple/Quad 图名写不写）×
  graph_policy（Strict 报错阻断 / Drop 有损导出）× only_named_graph（行选择）。
  字节保真回写：**round-trip 不变量 serialize ∘ parse = 恒等**（Drop/行选择除外）。

## 3 必要伪代码

### 3.1 loop next()（生成器固定模板）
```
begin_record()                       // LoopPolicy：全清 + state 归位
loop:
  event = synth_dot ? Dot : lexer.next()
          // synth_dot：词内尾点剥离后单槽待发，下一轮合成 Dot 回灌
  lexer None -> return finish_at_end()   // EOF 判脏
  (event, dot) = normalize_term_span(event)
  match step(ctx, event, hooks):
    Continue        -> continue
    EmitQuad(scope) -> pending = ctx.snapshot(); ctx.reset(scope)
                       return Some(Ok(pending))
    Done            -> return None
    UnexpectedEvent -> recover(span_of_event 或 lexer.pos())
    BusinessFailed  -> return Some(Err(on_business_failed(msg)))
```

### 3.2 SliceParser::parse_next（加工层续链）
```
engine.next():
  None          -> last_error 落账（StructSyntaxErr 带行号）后 None
  Some(Err(e))  -> Some(Err(e))            // 引擎级错误上抛
  Some(Ok(pending)) -> assemble(pending):
      三槽齐备? 否 -> "Incomplete quad at emission"
      validate(pending): span 界检查 -> 切 view -> 逐词项裁决 -> QuadSpan
  组装/校验失败：记 errors 后 parse_next() 递归续链（记错继续下一条）
```

### 3.3 词内尾点归位（normalize_term_span）
```
词法无脑扫吞尾点：<'a'> . / _:o. / "x".
  trim_trailing_dot：词尾字节 == '.' -> span 减一 + 置 dot 标记
  loop 下轮合成 NQuadsDot 回灌转移表（决策仍在表，机械在引擎）
```

