# gen_trig 架构规格（spec）

版本：v1.0.0（2026-09-12 自 `todo.md` §2/§3 拆出，并补 C/R 台账与验收口径）

**卷面分工**（同一信息只在一处详写）：`const.md` = 红线（冻结）；**本卷** = 结构事实 + 不变量 +
机械约束 + 已定语义口径 + C/R 台账 + 验收口径；`ctx.md` = 整改项工作上下文（锚点/证据/动作/验收/风险）；
`adr.md` = 决策（为什么）；`todo.md` = 战役路线与账本；`ARCHITECTURE.md` = 一页导读。
术语以 `bangto/world/vocabulary.spec.md` 为准（契约成员 = `Actions` / `EffectHandler` / `Supervisor`）。

---

## 1 分层与文件映射

五层管线：`Lexermoon`（词）→ `lexer_adapter`（token→事件）→ `TrigEngine`（表驱动 `step`）→
`TrigSliceParser`（组装 + 轻验）→ `TrigMaterializer`（span→QuadEmit + 深验）→ `@serializer`。

| 文件 | 层 | 行数（2026-09-12） | 职责 |
|---|---|---|---|
| `trig.mbt` | 生成契约（⚠ 生成物，禁手编） | 1356 | Event / State / ResetScope / Effect / ActionError / Context / PendingQuad / 三 trait / `step()` |
| `engine.mbt` | 机械层 | 531 | loop 模板 `next` + `LexerSource` + 词内尾点裁决 + Supervisor 四钩子实现 |
| `lexer_adapter.mbt` | 适配层 | 333 | token→事件分类（结构/裸词/`@` 邻接） |
| `parser_slice.mbt` | 加工层 | 603 | 组装（PendingQuad→QuadSpan）+ 轻验 + 行号统计 + TT 拆壳 |
| `materialize_trig.mbt` | 物化层 | 1645 | span→QuadEmit + 深验四门（单遍） |
| `serialize_trig.mbt` | 序列化层 | 375 | 只吃 QuadEmit，字节保真回写 + 图归并 |
| `actions.mbt` | 契约实现层 | 417 | `Hooks` 单载体（`TrigActions` + `TrigEffectHandler`） |
| `types.mbt` | 契约补充 | 160 | `Slot` / `SlotType` / `PredKind` 等用户侧类型 |
| `trig_wbtest.mbt` / `trig_annotation_wbtest.mbt` / `trig_bench_wbtest.mbt` / `rdf_suite_wbtest.mbt` | 测试面 | 944 / 132 / 401 / 140 | 白盒钉 / 注解钉 / 双词法 bench / 四套件 runner |

用户层（除生成物与测试）合计 **4064 行**；`trig.mbt` 由生成面产出，**唯一允许的修改路径是改生成面 + 再生**。

## 2 生成链与再生

```
src/rdf/domain2/trig_base.toml    （骨架：ctx/events/states/effects/chains/hooks/direct_actions）
src/rdf/domain2/trig_domain.toml  （行为：195 行 [[parser.transitions]]）
        └─(compile_domain2_files, src/rdf/domain_toml_2.mbt)→ src/rdf/fsm_out/trig_fsm.toml
                                                                        └─(src/fsm/cmd)→ gen_trig/trig.mbt
```

> **改表落点 = 上面这对 domain2 文件**（ADR-3 翻转 + ADR-5）：v1
> `domain/trig_domain.toml` 自 2026-09-13 起**冻结**，只作方言探测与留档。

再生命令（外层仓根）：

```sh
moon test -p rdf                                              # 1) 外仓测试落 fsm_out/trig_fsm.toml
moon run src/fsm/cmd -- src/rdf/fsm_out/trig_fsm.toml -o src/ttl/src/gen_trig/trig.mbt   # 2) 再生产物
cd src/ttl && moon test src/gen_trig                          # 3) 子仓回归
```

**门现状（2026-09-13 更新）**：

- **IR 侧有门**——`src/rdf/trig_domain_toml_gen.mbt`：**三腿对拍**「domain2 双文件编译 ≡
  管线路由 ≡ 盘上 `fsm_out/trig_fsm.toml`」+ 增量校验门 6 条。
  原"停役数组腿"（v1 `domain/trig_domain.toml` + 冻结数组）已**退役**
  （`src/rdf/adr.md` **ADR-5**）：v1 TOML 只服务 nquads；trig 的 2.0 数据面为唯一事实源。
- **产物侧门已立（T10 ✅ 2026-09-13，src/rdf ADR-6）**——`trig 产物黄金门`：
  ① `src/fsm` 增 `generate_with_ts(ir, config, ts)`（`generate` 缺省行为不变）+ CLI `--ts`；
  ② 形态口径 = **原始形 + 工具链 `moon fmt`**（禁进程内 fmt 包——实测与工具链输出不一致）；
  ③ 门 = 钉 ts 再生 + `moon fmt` ≡ check-in `trig.mbt` **逐字节** + 强幂等
  （金样 ts = `1788654011855`，与 n3v2 G9 同法）；证伪探针：改一行表 → 门红。
- **注解面已追平（2026-09-13）**：役9 的四字段/四动作/20 行行型已回灌 `domain2/trig_*`
  （`src/rdf/adr.md` **ADR-4**）——此前"盘上 2.0 数据落后产物、再生会抹注解"的预存分歧
  **已解除**；2.0 再生与产物的残差从 337 行降到 **250 行，且全部是 fmt 形 + 头横幅 ts**
  （48 hunk：单语句臂去花括号 / 超宽签名折行 / 空行与 `///|` / `Generated at:`）。
- ✅ **Turtle 路径已翻 2.0（T18，2026-09-13，src/rdf ADR-8）**：`DomainDialectKind::Turtle`
  与 Trig 同路路由到 `domain2/trig_*`（方言差异在运行时开关 `TrigDialect::Turtle` 禁图块区），
  数据面**单一**；钉子「Turtle 路由 ≡ domain2 trig 双文件」在 `src/rdf`（**22/22**）。
  ⇒ 本包全方言（Trig / Turtle）再生只走一条链，不再有"按方言走旧数组口径"的分叉。
（对照：n3v2 的 `n3_emit_banner(ts)` 把 ts 显式注入 ⇒ 可逐字节对拍。）

## 3 不变量清单（I）

| 编号 | 不变量 | 证据 |
|---|---|---|
| I-1 | **表是唯一转移权威**：除"pop 兑现帧携带的返回态"外，state 只由表行 `to=` 决定 | `const.md` §1.1；`ctx.md` 锚点 |
| I-2 | **`emits.length == quads.length`**（正例）：每条 EmitQuad 恰产出一个 QuadSpan | 套件 357/316/36/75 全绿 |
| I-3 | **字节保真**：`serialize ∘ parse = 恒等`（图归并/行选择旋钮除外） | `serialize_trig.mbt` round-trip 钉 |
| I-4 | **span 身份唯一**：fresh 节点身份 = 开括号 token 的 `offset`（全文档唯一）；集合链节点 = `Span(open.0, k+1)` | `types.mbt` `Slot`；T-★3 定案 |
| I-5 | **双源不变量**：`data` 只读、`arena` 只追加；物化 span 可能指向 arena | `const.md` §3 |
| I-6 | **图块区域封闭**：`TrigGraphExpect*` 无 `Lbrace` 出边 ⇒ 嵌套图块不可达（表即裁决者） | 表行；`bad-list`/`collection-graph-bad` 套件 |
| I-7 | **单遍深验**：四门在物化构词点就地执行，不再有第二遍扫描 | `materialize_trig.mbt` 门函数 |
| I-8 | **合成谓词即消费**：`ctx.pred_kind` 经 `snapshot` 读出即归 `Normal`，快照窗口外不得残留 | 表 `[[context.snapshot_extras]]` `pk` |

## 4 机械约束（改表/改引擎前必读）

- **guard 只通 `ctx`**：表行 guard 不得读 `data`/`arena`（词法字节判断属适配层/物化层）。
- **EOF 不进表**：`None` 分支归 loop 收尾；词法器结尾 `Some(EOF(pos))`。
- **ctx 新字段守门**：新增 ctx 字段须同时声明 reset 粒度归属（`ResetScope` 四档之哪档）与
  `[[context.snapshot_extras]]`（若需随 quad 带出），否则 `moon test src/rdf` 的表/生成器对照会红。
- **表外入口登记**：任何"表推不出的状态写入"必须在 `ctx.md` 登记锚点（T10 后由 G-门类机制兜底）。

## 5 已定语义口径（合理面总结，固化）

### 5.1 词法层（Lexermoon；与 C Lexerc 在 `trig_bench_wbtest.mbt` 逐 token pin 一致）

| 形态 | 产出 | 机械 |
|---|---|---|
| `"..."` `'...'` `"""..."""` | Literal | 引号内是字符串物理单元；`^^` / `@` 后缀整词扫入（扫到空白收束） |
| `<<( ... )>>` / `<< ... >>` | TripleTerm | 平衡深度扫描；`<<` 裸壳同族先于普通 IRI；未闭合宽容出词 |
| `_:x` | BlankNode | 名字含 `.`；多字节标签字符加宽 |
| 字母 / `:` 起头 | PrefName | PN_LOCAL 加宽：内部 `.`/`:`、`\X` 转义对、`%HH`、多字节 UTF-8；**尾部裸 `.` 回退**（`\X` 转义点不回退） |
| 数值整词 | Unknown | `+/-/.5/1.5/1.0e3/123.E+1` 整词；`1.` = INTEGER + 语句点；`is_numeric_span` 整词形态裁决在适配层/物化层（单点实现：`gen_nquads/numeric.mbt`） |
| `{\|` `\|}` | Unknown（两字词） | 注解定界符整词出 |
| `=>` `<=` | Unknown(2) | N3 扩展词（`>=` 无规范依据不加）；表未接 ⇒ 兜底 |
| `.` `;` `,` | Dot/Semicolon/Comma | 结构标点 |
| `#` | — | 注释到行尾跳过 |

### 5.2 适配层（`lexer_adapter.mbt`）

- token→事件：`classify_structural`（`@` 邻接关键词 `@prefix`/`@base`；裸词 `PREFIX`/`BASE`/`VERSION`/`GRAPH`/`a`、
  `!`/`^` 单字、`=>`/`<=` 双字节）、`classify_prefname`（无冒号 prefname → Unknown 走兜底）。
- `_:x` 含冒号：形判定**先排除 `_:`** 再嗅探 PrefName（防混淆）；`<<` 同族先于 `<` 判定。
- 零空格指令名拆分：`@prefix:<iri>` 在 `@` 邻接位精确命中 `prefix:`/`base:`/`version:` 才拆
  （`kw:foo` 带本地部不拆，term 位 `prefix:x` 不受扰）。

### 5.3 引擎表（`src/rdf/fsm_out/trig_fsm.toml`；规模 36 态 / 34 事件 / 10 效果 / 195 转移）

- **指令双风格**：`@prefix` / `@base`（精确小写，Dot 收尾）与 `PREFIX` / `BASE` / `VERSION`
  （SPARQL 风格，无 Dot）；两者都要求精确小写拼写。
- **链式重置粒度**：`,` 清宾语 / `;` 清谓宾 / `.` 全清——落成 `EmitQuad` 的 `ResetScope`。
- **图块**：`[graphName] { ... }`、`GRAPH` 关键字、顶层裸 `{}` = 默认图块；`TrigGraphExpect*` 无嵌套出边。
- **Enter/ExitGraph 双路由**（维持现状，不引入 `action_args`）：
  (a) 动作路径：`exit_graph` action → dispatch → `handle_exit_graph`（`}` 在 GraphExpectSubject、空块/点后闭合）；
  (b) 序列路径：`[EmitQuad(SPO), ExitGraph]` → `interpret` → `on_exit_graph`（`}` 带挂起发射）。`EnterGraph` 恒走动作路径。
- **引用/注解**：`<< s p o >>` 打包为值不发射（可作主/宾，不可作谓）；`<<( )>>` 括号壳宾位；
  `~reifier` reifier 事件；`{| |}` 注解（`TrigAnnot*`/`GraphAnnot*` 双区各 10 行）。

### 5.4 组装 + 轻验（`parser_slice.mbt`）

- 缺槽检测：`ExpectSubject` 上遇 Dot 等即 `StructSyntaxErr`。
- **TT 拆壳**：独立 `<< s p o >> .` 语句拆成三槽 plain 判定 → lenient 负值（数值主语等）在槽位即拒，不到深验。
- 轻验 `validate_term`：形态嗅探（IRI 壳 / bnode 字符集 / prefname 冒号分账 / 数值整词 / 字面量引号壳），
  不做全量文法；`lenient=true` 跳过它。

### 5.5 物化 + 深验（`materialize_trig.mbt`，单遍）

- **槽位路由** `iri_term`：`<...>` → 绝对 / 相对（base memo：`base_memo : Map[Int, Iri]`，错误不 memo）；
  `_:` → BNode；prefname → `resolve_prefname`。
- **`resolve_prefname`**：语法折叠 + ledger 单查；`Ok(None)` = 前缀未声明，`Err` = 语法坏；
  `write_prefname_iri` / `expand_prefname` 组合复用。前缀账本按 `prefix_version` 上界钳（后声明不污染历史 quad）。
- **@base per-quad 快照（★1，2026-09-04 落地）**：`ctx.base` 单槽 → append-only `ctx.bases`；
  `EmitQuad` 快照带 `base_version`；`base_at(base_version)` 折叠链前缀（绝对 @base 重置累计值，
  相对 @base 按 RFC 3986 5.2 合并）⇒ **中途换 @base 不再污染历史 quad**（旧"最终 base 改写全部"缺陷已修，ADR-TRIG-005）。
- **字面量族**：引号壳解码（转义集 `scalar_only_escapes`）；`a` → `rdf:type`；数值三型（integer/decimal/double → xsd）；
  布尔；`^^PrefName` 展开（arena 组装）；`@lang`（4 位语言拒绝、`X-` 不分大小写、span 恰覆盖子标签）/
  `--ltr` / `--rtl`；三引号长串。
- **RDF 1.2 单一模式开关 `rdf12 : Bool`（ADR-TRIG-014）**：一个开关管两件事——
  ① **转义**：`true` ⇒ `\u/\U` 代理一律拒（成对也不收），`false` ⇒ 1.1 宽容（成对合法）；
  ② **方向后缀**：`true` ⇒ `--ltr/--rtl` 拆后缀后验基础标签（放行），`false` ⇒ **显式拒**
  （`Language direction suffix (--ltr/--rtl) requires RDF 1.2`）。
  **默认值（2026-09-13 对齐 nquads）**：构造 `rdf12? : Bool = **true**`（语法版本默认 RDF 1.2）；
  1.1 侧显式传 `false`（套件 runner 同参默认 `true`，`rdf-trig`/`rdf-turtle` 显式 `false`）。
  与 nquads 共享的转义检查按名传参 `@nquads.validate_escapes_unicode(..., scalar_only=rdf12)`
  （nquads 侧参数名不动，冻结口径）。套件侧 `rdf12? : Bool = false`，rdf12 两套件传 `true`。
- **深验四门**：`gate_iri` = scheme 嗅探（与 `parse_scheme` 同文法，digit 可起头）+ `validate_iri_body(view,0,1,len)`，
  不做全 parse；`gate_literal` = `deep_check_literal`（含 datatype 递归 `gate_iri`）。

### 5.6 序列化（`serialize_trig.mbt`）

- 旋钮正交：format（默认图/命名图写法）× 图归并（首次出现序）× 行选择；字节保真回写（I-3）。
- 三引号目前**原样保真**（规范化未设计 → R-T11 [立案]）。

## 6 必要伪代码

### 6.1 loop `next()`（模板骨架，所有 FSM 同形）

```
loop:
  event = adapter.token_to_event(lexer.next())     // EOF 不进表
  match engine.step(state, event):
    Continue                 -> 推进 state
    EmitQuad(scope)          -> quad = assemble(ctx 槽位 span)   // 组装在 loop
                                on_quad(quad); ctx.reset(scope)  // 发射与收拾在 loop
    EnterGraph(label_span?)  -> ctx.graph = label                 // 动作路径
    ExitGraph                -> handle_exit_graph（双路由见 §5.3）
    Sequence([effects])      -> 逐个 interpret（emit_queue FIFO）
    UnexpectedEvent          -> supervisor.recover（消费到 Dot/Rbrace）
  lexer EOF -> supervisor.finish_at_end（判脏收尾）
```

### 6.2 `materialize_quad` 槽位路由（单遍四门）

```
for slot in [s, p, o, g]:
  首字节路由:
    '<'  -> iri_term: 绝对 / 相对(base_memo) -> gate_iri
    '_:' -> bnode -> gate_bnode
    字母/':' -> resolve_prefname:
        Ok(Some((iri, colon))) -> write_prefname_iri 展开 -> gate_iri
        Ok(None)               -> ValidationErr("undeclared prefix")
        Err(e)                 -> e（语法坏）
    '"'/"'" -> literal 路由: 'a'→rdf:type / 数值三型 / 布尔 / ^^PrefName(arena) / @lang / 三引号 -> gate_literal
  全部槽位展开后 push QuadEmit（blit 批量拷贝进 arena）
```

### 6.3 TT 拆壳（`parser_slice.assemble`）

```
quad.o 形如 << ... >> 且语句无图名位:
  triple_term_inner_terms 按顶层空白切项（字符串物理单元，闭壳后右扩 @lang/^^ 后缀）
  -> (s, p, o) 三槽各自走 plain 判定（lenient 负值在此即拒）
  壳仅作主语形式时 gate_tt 兜底
```

## 7 冲突写实台账（C）

性质取值：**[债]** 应整改 / **[设计]** 有意取舍 / **[制度]** 由生成器或宪法机制导致的副作用。

| 编号 | 事实（写实） | 证据锚点 | 性质 |
|---|---|---|---|
| C-T1 | ~~效果面孤儿~~ **已收口（T11，2026-09-13）**：`interpret` 成唯一解释器（`engine.mbt:404` 调用点）；`emit_queue` 下沉 ctx；引擎实现 `snapshot`/`on_*` 真实挂点（`:476/489/496/504/513`）——观测/容灾切面可挂 | `engine.mbt:404`（调用点）+ `:476/489/496/504/513`（impl）；`domain2/trig_base.toml`（`emit_queue`）；ADR-TRIG-013 | [债]→**已收口（T11）** |
| C-T2 | ~~产物无黄金门~~ **已收口（T10，2026-09-13）**：`Generated at:` 墙钟值改由 `generate_with_ts` 显式注入（CLI `--ts`）；形态差由工具链 `moon fmt` 在管线末端收敛——钉 ts 再生 + `moon fmt` ≡ check-in `trig.mbt` 逐字节，门在 `src/rdf/trig_domain_toml_gen.mbt`。**遗留**：nquads 同类形态差 68 行（其 check-in 同为 fmt 形），产物门待补（另役） | 门：`trig 产物黄金门`；`src/fsm/codegen.mbt`（`generate_with_ts`）；`src/rdf/adr.md` ADR-6 | [债]→**已收口（T10）** |
| C-T3 | 公共面过宽：`.mbti` 349 行 / 54 顶层 `pub` 行——FSM 机械（Context/State/Event/Effect/三 trait/Engine）全 `pub` | `pkg.generated.mbti`（对照 n3v2 收窄后 166 行 / 29 pub 行） | [债]（R-T3 / T12） |
| C-T4 | ~~命名未回灌~~ **已收口（T13，2026-09-13）**：`TrigSupervisor`（数据键 `[meta] policy_trait_name`）+ `TrigActionsImpl`（`actions.mbt`）+ 字段 `actions`；产物已再生 | `trig.mbt`（trait 头）；`engine.mbt`；ADR-TRIG-015 / src/rdf ADR-10 | [债]→**已收口（T13）** |
| C-T5 | 包内死件：5 个 `.bak`（`trig.mbt.bak` 36 KB、`engine.mbt.bak` 15 KB、`lexer_mbt*.bak` ×2、`nquads_test.mbt.bak`） | `ls *.bak` | [债]（R-T5 / T15） |
| C-T6 | 测试位置：生产文件内联 21 个 test（`materialize_trig.mbt` 16 + `serialize_trig.mbt` 5） | `grep -c '^test '` 两文件 | [债]（R-T6 / T14） |
| C-T7 | 卷面违规（**2026-09-12 已收口**）：`todo.md` 曾同时承载宪法（§1）与规格（§2） | 旧 `todo.md` §1/§2；`bangto/world/const.md` §5.2 | [债]→**已收口（T16）** |
| C-T8 | 双包重复：与 gen_n3v2 用户层同名 helper 交集 20 个；用户层体量 ≈4064 vs ≈4381 行 | `ctx.md` §4 T17 清单 | [债]（R-T8 / T17 [立案]） |
| C-T9 | `moon.pkg:1` 头注漂移：仍写"gen_nquads：…"（复制残留） | `moon.pkg:1` | [债]（R-T9，微） |
| C-T10 | `<< >>` 壳内 `^^datatype` 误拒：`triple_term_inner_terms` 按顶层空白切项，`^^xsd:date` 被拆成第 4 项 | `parser_slice.mbt`（`triple_term_inner_terms`）；bench 语料规避 | [债]（R-T10 [立案]） |
| C-T11 | 三引号规范化未设计：serializer 原样保真回写 | `serialize_trig.mbt` | [设计]→R-T11 [立案] |
| C-T12 | MoonBit 词法落后 C 侧 2.3–2.6×（简单 4006 token：434 µs vs 1117 µs；复杂 9046：907 vs 2056） | `trig_bench_wbtest.mbt` | [债]（R-T12 [立案]） |
| C-T13 | `@keywords` 语义豁免未接：适配层无跨 token 状态，`@keywords` 下 `'a'` 仍出 KeywordA | `lexer_adapter.mbt`；表未接 | [设计]→R-T13 [立案] |
| C-T14 | 陈数已澄清：旧 `todo.md` §5 item 6 记 deferred 2/1/5/6（predates ★1/★3 收口）；实测四套件 deferred 全零 | 套件输出 357/316/36/75，failed 0 | [债]→**已澄清（T16）** |

## 8 整改裁决台账（R）

状态：**定案**（用户已裁，执行即可）/ **建议**（待裁）/ **立案**（需单独立项）。

| 编号 | 结论 | 状态 | 归属役 | 关联 |
|---|---|---|---|---|
| R-T1 | 效果面接活：`interpret` 成唯一解释器，`engine.next` 调它；套装收形；`emit_queue` 下沉 ctx | 建议 | T11 | C-T1 |
| R-T2 | 产物黄金门 ✅（形态口径按 ADR-6 修正为"原始形 + 工具链 `moon fmt`"，非进程内直产 fmt 形） | **✅ 已落地（T10，2026-09-13）** | T10 | C-T2、src/rdf ADR-4/ADR-6 |
| R-T3 | 公共面收窄：FSM 机械降包内，留入口与数据面 | 建议 | T12 | C-T3 |
| R-T4 | 命名回灌：`TrigLoopPolicy → TrigSupervisor`；`Hooks → TrigActionsImpl` | **✅ 已落地（T13）** | T13 | C-T4、world `ADR-NAMING-001`、src/rdf ADR-10 |
| R-T5 | 清包内死件：5 个 `.bak` 归档（禁静默删） | 建议 | T15 | C-T5 |
| R-T6 | 测试归位：16+5 个内联 test 迁 `_wbtest.mbt`，辅助去重 | 建议 | T14 | C-T6 |
| R-T7 | 卷面补全：拆 const/spec/adr，todo 只留役与账本 | **✅ 已落地（T16，2026-09-12）** | T16 | C-T7 |
| R-T8 | 双包重复治理：共享用户层件 或 有意分叉入 spec | 立案 | T17 | C-T8 |
| R-T9 | `moon.pkg` 头注改 gen_trig 实况 | 建议 | T15（搭车） | C-T9 |
| R-T10 | `<< >>` 内 `^^datatype` 修口：切项时闭壳后右扩后缀 | 立案 | — | C-T10 |
| R-T11 | 三引号规范化设计（serializer 侧） | 立案 | — | C-T11 |
| R-T12 | MoonBit 词法性能（字节分派表 / span 直写 / 少 Token 构造） | 立案 | — | C-T12 |
| R-T13 | `@keywords` 语义豁免（接表时定案） | 立案 | — | C-T13 |

## 9 验收口径（命令 + 当前数字，2026-09-12 实测）

```sh
cd /home/thy/moonttl
moon test src/rdf            # 20/20（含 IR 侧 trig 对照门）
moon test src/rdf/n3gen      # 12/12（G1–G13；与本包无耦合，动外仓时兜底）
cd /home/thy/moonttl/src/ttl
moon check src/gen_trig      # 0 error / 0 warning
moon test src/gen_trig       # 80/80（单元）
moon info && moon fmt        # .mbti diff 逐行审（当前 349 行 / 54 pub 行）
```

套件判据（四套 `pin=true`，failed 必须 0、deferred 必须 0）：

| 套件 | 数字 | 锚点 |
|---|---|---|
| rdf-trig | **357/357** | `rdf_suite_wbtest.mbt:108` 起 |
| rdf-turtle | **316/316** | `rdf_suite_wbtest.mbt:115` 起 |
| rdf12-trig | **36/36** | `rdf_suite_wbtest.mbt:123` 起 |
| rdf12-turtle | **75/75** | `rdf_suite_wbtest.mbt:131` 起 |

改动后必查：`I-2`（emits == quads，正例）、`I-3`（round-trip 恒等）、套件四数字不变、`.bak` 零新增。
