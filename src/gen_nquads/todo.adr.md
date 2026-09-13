# gen_nquads todo（2026-09-03 整理；FSM 生成链路第一样板，gen_trig 为第二样板推广自此）

## 1 宪法 const

### 1.1 分层文件职责（宪法原文见 const.md，勘误记录见 §4）
- **nquads.mbt = 生成契约文件**（src/fsm 生成器产物，DO NOT EDIT）：
  Event / State / ResetScope / Effect / ActionError / Context / PendingQuad /
  LoopPolicy trait / Actions trait / `step()` / EffectHandler trait。
- **engine.mbt = 机械层**：主循环 `next` 是生成器固定模板——
  入口/终止 → step 步进 → Effect 分发 → 错误降级，四节点零领域逻辑；
  `LexerSource` trait 约束词法源运行时接口（next/pos/byte_at），
  Lexermoon（纯 MoonBit）/ Lexerc（C FFI）双实现可插拔。
- **parser_slice.mbt = 加工层**：组装（PendingQuad 快照 → QuadSpan）+
  验证（validate_helper.mbt，view 直查）+ 行号统计（engine 不持 data）。
- **actions.mbt = 业务热路径**：Hooks 单载体双 trait
  （同时实现 NQuadsActions + NQuadsEffectHandler），引擎只持一个实例，
  **单泛型轴**——泛型只落在词法器 L 上，trait 落到最底层。

### 1.2 三条线（与 gen_trig 同宪法）
- **决策在表**：step 只产出 Effect 意图；`EmitQuad(ResetScope)` 携带收拾粒度，
  "发完怎么收拾"写在转移行上。
- **机械在模板**：切片组装（snapshot → QuadSpan）与 `ctx.reset(scope)` 都在 loop；
  engine 绝不触碰槽位切片。
- **业务在 trait**：三业务面——`NQuadsActions`（槽位写入，热路径）、
  `NQuadsEffectHandler`（冷路径，下游输出）、`NQuadsLoopPolicy`
  （begin_record / recover / finish_at_end / on_business_failed，恢复与收尾策略）。

### 1.3 口径铁律
- **action 只写槽位返回 Continue**：永不重置 ctx、拿不到数据视图；
  切 span 组装、粒度重置都是引擎 loop 的独占机械。
- **action 统一 Span 口径**：全词含定界符；无 payload 事件固定绑 `(0,0)`，
  错误兜底位置由 loop 用 `lexer.pos()` 补。
- **EOF 是数据边界不进表**：LexerSource 在词法源层吞掉 EOF 变体回 None；
  loop 判脏收尾（finish_at_end：state 未归位或任一槽位残留 → 不完整记录）。
  EOF 协议：词法器结尾 `Some(EOF(pos))`，None 仅保留异常分支。
- **未列举组合 → UnexpectedEvent 兜底**：loop 登记（record_error）→
  consume_to_dot（消费整行 + 全清）→ state 归位。错误不经 action/effect 表达。
- **ResetScope 粒度正交**：每变体显式列出"清谁"，未列字段一律保留；
  粒度不回头写 state——state 由转移表 to= 负责，两者正交。
  现有四档：Object / PredObj / SPO（TriG 图块口径预埋）/ All（行口径）。
- **Effect 三件套只加变体**：Continue / EmitQuad / Done；trig 追加
  EnterGraph/ExitGraph/Sequence 不改既有签名。
- **词内尾点裁决（引擎归位点）**：词法无脑扫把语句点吞进词尾时，
  `trim_trailing_dot` 剥离 + loop 合成 Dot 事件回灌转移表（决策仍在表，机械在此）。

### 1.4 验证分层宪法（W3C 89/89 实证）
- 词法器保持**无脑扫（加宽口径）**：语法对错全部在 validate_helper.mbt 裁决
  （组装之后：span → view 切分完成，逐词项在 view 上校验）。
- 引擎只负责**尾点归位**与结构转移；错误 span 用全局偏移定位，
  行号由持 data 的 SliceParser 统计（line_before）。
- 错误四变体：StructSyntaxErr（带行号）/ SyntaxErr / ValidationErr / IriErr。

### 1.5 flavor 差异沉外层
- `;`/`,` 转移边为 TriG 复用预埋（表共享），nquads 语义下由组装层兜。
- triple/quad 开关放序列化层（format 旋钮）；.nt 72/72 实证口径无损。
- 双词法器同 Token 字母表（Token 与 span 口径完全对齐），
  `token_to_event` 映射共用、零补偿透传；词法语义以 C 版（lexerc_ffi.c）为标准对齐源。

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

## 4 变更收集

- **FSM 生成链路打通**：src/fsm 生成器（ir.toml/codegen*）+ test_nquads.toml
  → nquads.mbt（生成产物，DO NOT EDIT）；gen_nquads 为第一样板，
  生成契约三条线/ResetScope/Effect 三件套/LoopPolicy 全部推广至 gen_trig。
- **单泛型轴定案**：Hooks 单载体双 trait（NQuadsActions + NQuadsEffectHandler），
  泛型只落词法器 L；engine_c.mbt 薄适配复用同一 loop 与 token_to_event
  （nquads_parser_c 入口，构造/释放显式在入口做）。
- **双词法器同字母表**：Lexermoon 与 C Lexerc Token 同型同宽、span 全词含定界符，
  语义以 C 版为标准对齐源；EOF 协议统一（Some(EOF(pos)) / None 异常分支）。
- **套件 pin**：W3C rdf-n-quads 89/89（合并语料 all_combined.nq 单文件，
  "# >>> 段标记"切段，运行时零目录遍历）；ntriples 72/72（循环读文件 +
  整合文件对比双口径）；read_context 错误上下文诊断。
- **bench 双件**：fsm_bench（分层开销：Token→Event 转换 / step 重放 / 完整引擎）
  + nquads_bench_test（三阶段 + C Lexerc/引擎/SliceParser 对比六段计时）。
- **const.md 勘误（按实际代码修正）**：
  - "Complete/done 死码一并移除"——准确说法：**表中无转移产出 Done**，
    但 Done 变体保留（Effect 三件套之一），loop 保留 Done → return None 分支。
  - "loop 按 SkipError 口径记录"——SkipError 是手写版遗留称呼，
    现为 LoopPolicy 的 `recover` 钩子（登记 → consume_to_dot → state 归位）。
  - "nquads.mbt（生成契约）/engine.mbt（机械层）/parser_slice.mbt（加工层）"
    三行清单补全：actions.mbt（业务热路径）与 materialize/serialize 两层缺位。
  - "Effect 面向演进"已兑现：trig 追加 EnterGraph/ExitGraph/Sequence 未改签名。
  - 原文 "EmitQuad 携带 ResetScope" 表述含糊——实为 `EmitQuad(ResetScope)` 变体携参。

## 5 未完成 step 与事项

| 优先 | 事项 | 现状/修法 |
|---|---|---|
| ★1 | **materialize_quad 深验未接入** | data 参数注释占位；与 trig 单遍四门口径（scheme 嗅探 + gate 融合）对齐，复用同包 iri/literal/langtag 文法件即可 |
| ★2 | **test_nquads.toml 改名 nquads.toml** | 生成器测试期遗留命名；与 trig.toml 对齐，同步改 src/fsm 引用 |
| 3 | quick_machine 归并 | fsm 与 quick_machine 双生成器并存；适配债：gen_check/system.mbt 旧词表 11 错、EmitQuad 意图化映射待设计、fsm_toml 指向失效 |
| 4 | nquads.bak 清理 | 遗留备份文件（nquads.mbt 的旧手抄副本时代），删除 |
| 5 | MoonBit 词法优化 | trig 双词法 bench 实测落后 C 侧 2.3-2.6×，同机械适用 nquads；候选：字节分派表、span 直写、减少 Token 枚举构造 |
| 6 | types.mbt 桩守卫 | 人工维护面占位文件依赖 CLI 首跑 bootstrap 维持，生成器回灌后收口 |
