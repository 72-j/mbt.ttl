# gen_trig todo（2026-09-03 重写；旧 T-1..T-9 清单已全部落地，归档见 git 历史）

## 1 宪法 const

### 1.1 生成契约三条线（与 gen_nquads 同宪法，gen_trig 为第二样板）
- **决策在表**：step 只产出 Effect 意图；发射意图 `EmitQuad(ResetScope)` 携带收拾粒度，
  "发完怎么收拾"写在转移行上。`Sequence` 只是意图的串列打包。
- **机械在模板**：主循环 = 生成器固定模板（engine.mbt 的 `next`，所有 FSM 同形），
  无策略只有机械：切片组装与 `ctx.reset(scope)` 都在 loop 发生，引擎/表不触碰槽位。
- **业务在 trait**：领域钩子收敛为两个 trait——
  `TrigLoopPolicy`（begin_record / recover / finish_at_end / on_business_failed）
  与 `TrigEffectHandler`（handle_emit_quad / handle_enter_graph / handle_exit_graph）。

### 1.2 口径铁律
- **action 统一 Span 口径**：所有 action 参数一律 Span；`enter_graph` 的 label 为
  `Span?`（None = 默认图）；无 payload 的事件固定绑 `(0,0)`；错误兜底位置由 loop 用 `lexer.pos()` 补。
- **EOF 是数据边界不进表**：由 loop 判脏收尾（finish_at_end）；Complete/done 死码已移除，
  Dot 发射后由表直接转回 ExpectSubject 回环。
- **未列举组合 → UnexpectedEvent 兜底**：loop 按 SkipError 口径记录并消费到 Dot/Rbrace。
- **Effect 面向演进只加变体**：nquads 三件套（Continue/EmitQuad/Done）+ trig 追加
  EnterGraph/ExitGraph/Sequence，不改既有签名。
- **图块区域与顶层彻底分离**：TrigGraphExpect* 无 Lbrace 出边 = 嵌套图块不可达，
  表即合法性裁决者；TriG 无四元组语法，graph 槽位只由 enter_graph 填。
- **全文件 TOML 可表达**：枚举/ctx 槽位/action 面/step 表四段，无任何表外逻辑
  （词内尾点合成 Dot、token 分类都在适配层/loop 模板）。

### 1.3 数据与生命周期
- **Span/View/Arena 双源不变量**：`data` 只读原串；`arena` 只追加
  （push_view / push_byte / `blit_to` 自动扩容）；物化产物 span 可能指向 arena
  （如 ^^PrefName 展开串），消费方不假设单源。
- **prefixes 生命周期由调用方保证，解析后只读**（materializer `new()` 文档注明）。
- **单遍口径：轻嗅探 + 按需深验**：四门 `gate_iri/gate_bnode/gate_tt/gate_literal`
  融合在物化构词点；`deep_validate` 标志由 `materialize_all(deep_validate)` 设定；
  suite runner 与 mat_chain 传 `lenient=true` 条件性跳过轻验（深验仍在）。
- **命名宪法 AGENTS.md 四条**：规范术语保规范拼写（BNode 保留）；
  空前缀 IRI = DefaultPrefixIRI。

### 1.4 action / effect 边界
- action = 修改解析器内部状态（状态转移、槽位写、栈操作）：纯内部、确定性、可重放。
- effect = 跨边界可观测：仅两族——`err` 向上游（解析失败），`emit/on_*` 向下游（输出结果）。
- 压栈/弹栈、reset、fresh bnode 全是 action；发射与报错才是 effect。

## 2 trig 解析规则规格

五层管线：Lexermoon（词）→ lexer_adapter（token→事件）→ TrigEngine（表）→
TrigSliceParser（组装 + 轻验）→ TrigMaterializer（span→QuadEmit + 深验）→ @serializer。

### 2.1 词法层（Lexermoon；与 C Lexerc 在 trig_bench_test 中逐 token pin 一致）
| 形态 | 产出 | 机械 |
|---|---|---|
| `"..."` `'...'` `"""..."""` | Literal | 引号内字符串物理单元；^^/@ 后缀整词扫入（无脑扫到空白收束） |
| `<<( ... )>>` | TripleTerm | 平衡深度扫描；`<<` 裸壳同族先于普通 IRI；未闭合宽容出词 |
| `_:x` | BlankNode | 名字含 `.`；多字节标签字符加宽 |
| 字母 / `:` 起头 | PrefName | PN_LOCAL 加宽：内部 `.`、`:`、`\X` 转义对、`%HH` 对、多字节 UTF-8；**尾部裸 `.` 回退**（`\X` 转义点不回退） |
| 数值整词 | Unknown | `+/-/.5/1.5/1.0e3/123.E+1` 整词；`1.` = INTEGER + 语句点；`is_numeric_span` 整词形态裁决在适配层 |
| `{|` `|}` | Unknown（两字词） | 注解定界符整词出 |
| `.` `;` `,` | Dot/Semicolon/Comma | 结构标点 |
| `#` | — | 注释到行尾跳过 |

### 2.2 适配层（lexer_adapter）
- token → 事件：classify_structural（`@` 邻接关键词 @prefix/@base；裸词 PREFIX/BASE/VERSION/GRAPH/a）、
  classify_prefname（无冒号 prefname → Unknown 走兜底）。
- `_:x` 含冒号：形判定先排除 `_:` 再嗅探 PrefName（防混淆）。
- `<<` 同族先于 `<` 判定。

### 2.3 引擎表（trig.toml + 生成的 trig.mbt）
- **指令双风格**：`@prefix`/`@base`（精确小写，Dot 收尾）与 `PREFIX`/`BASE`/`VERSION`
  （SPARQL 风格，无 Dot）；均要求精确小写拼写。
- **链式重置粒度**：`,` 清宾语 / `;` 清谓宾 / `.` 全清——落成 EmitQuad 的 ResetScope。
- **图块**：`[graphName] { ... }`；`GRAPH` 关键字；顶层裸 `{}` = 默认图块；
  TrigGraphExpect* 区域无嵌套出边。
- **Enter/ExitGraph 双路由**（engine.mbt 头注差异点 5）：
  (a) 动作路径：exit_graph action → dispatch → handle_exit_graph（`}` 在 GraphExpectSubject，
  空块/点后闭合）；(b) 序列路径：`[EmitQuad(SPO), ExitGraph]` → interpret → on_exit_graph
  （`}` 带挂起发射）。EnterGraph 恒走动作路径。维持现状不引入 action_args。
- **引用三元组**：`<< s p o >>` 打包为值不发射（可作主/宾，不可作谓）；
  `<<( )>>` 括号壳宾位；`~reifier` reifier 事件；`{| |}` 注解（annotation 事件）。

### 2.4 组装 + 轻验（parser_slice）
- 缺槽检测：ExpectSubject 上遇 Dot 等即 StructSyntaxErr。
- **TT 拆壳**：独立 `<< s p o >> .` 语句拆成三槽 plain 判定 → lenient 负值（数值主语等）
  在槽位即拒，不到深验。
- light validate_term：形态嗅探（IRI 壳 / bnode 字符集 / prefname 冒号分账 /
  数值整词 / 字面量引号壳），不做全量文法。

### 2.5 物化 + 深验（materialize_trig，单遍）
- **槽位路由 iri_term**：`<...>` → 绝对 / 相对（base 解析 memo：`base_parsed : Iri?`，
  错误不 memo）/ `_:` → BNode / prefname → `resolve_prefname`。
- **resolve_prefname**：语法折叠 + ledger 单查（prefix_iri_of 双查找已重构掉）；
  `Ok(None)` = 前缀未声明，`Err` = 语法坏；`write_prefname_iri` / `expand_prefname` 组合复用。
- **字面量族**：引号壳解码（转义集 scalar_only_escapes）；`a` → rdf:type；
  数值三型（integer/decimal/double → xsd）；布尔；`^^PrefName` 展开（arena 组装）；
  `@lang`（4 位语言拒绝、X- 不分大小写、span 恰覆盖子标签）/ `--ltr`/`--rtl`；
  三引号长串。
- **深验四门**：`gate_iri` = scheme 嗅探（view_has_scheme，与 parse_scheme 同文法、
  digit 可起头）+ `validate_iri_body(view, 0, 1, len)`，不全 parse；
  `gate_literal` = deep_check_literal（含 datatype 递归 gate_iri）。
- **@base 已知缺陷**：ctx.base 单槽，文档中途改 @base 后相对 IRI 全按最终 base 改写
  （详见 §5）。

## 3 必要伪代码

### 3.1 loop next()（模板骨架，所有 FSM 同形）
```
loop:
  event = adapter.token_to_event(lexer.next())     // EOF 不进表
  match engine.step(state, event):
    Continue                 -> 推进 state
    EmitQuad(scope)          -> quad = assemble(ctx 槽位 span)   // 组装在 loop
                                on_quad(quad); ctx.reset(scope)  // 发射与收拾在 loop
    EnterGraph(label_span?)  -> ctx.graph = label                 // 动作路径
    ExitGraph                -> handle_exit_graph（双路由见 §2.3）
    Sequence([effects])      -> 逐个 interpret
    UnexpectedEvent          -> policy.recover（消费到 Dot/Rbrace）
  lexer EOF -> policy.finish_at_end（判脏收尾）
```

### 3.2 materialize_quad 槽位路由（单遍四门）
```
for slot in [s, p, o, g]:
  首字节路由:
    '<'  -> iri_term: 绝对 / 相对(base_parsed memo) -> gate_iri
    '_:' -> bnode -> gate_bnode
    字母/':' -> resolve_prefname:
        Ok(Some((iri, colon))) -> write_prefname_iri 展开 -> gate_iri
        Ok(None)               -> ValidationErr("undeclared prefix")
        Err(e)                 -> e（语法坏）
    '"'/"'" -> literal 路由: 'a'→rdf:type / 数值三型(is_numeric_span 整词裁决) /
               布尔 / ^^PrefName(arena 组装) / @lang / 三引号 -> gate_literal
  全部槽位展开后 push QuadEmit（blit 批量拷贝进 arena）
```

### 3.3 TT 拆壳（parser_slice.assemble）
```
quad.o 形如 << ... >> 且语句无图名位:
  triple_term_inner_terms 按顶层空白切项（字符串物理单元）
  -> (s, p, o) 三槽各自走 plain 判定（lenient 负值在此即拒）
  壳仅作主语形式时 gate_tt 兜底
```

## 4 变更收集（2026-08-31 ~ 09-03）

- **T-1..T-9 全链落地**（事件词表/Effect/State/转移表/ContextProtocol/Action/
  EffectHandler/对拍/Turtle 方言）——旧清单已删，归档在 git 历史。
- **单遍化重构（0902-0903）**：`deep_validate_quad` 两遍扫描删除 → 四门融合进
  materialize_quad 构词点；IRI 深验改 scheme 嗅探 + validate_iri_body（不全 parse）；
  base memo（`base_parsed`，错误不 memo）；blit 批量拷贝；prefname API 三件
  （resolve_prefname/write_prefname_iri/expand_prefname，prefix_iri_of 双查找重构掉）；
  suite/chain `lenient=true` 条件跳轻验；`is_numeric_span` 防数值-first 垃圾误入
  PrefName 分支；TT 拆壳落 parser_slice。
- **性能（单遍化后）**：简单 1000 quads：词法 1.15 / 引擎 1.27 / 轻验 1.57 /
  物化 2.13 ms（物化原 6.86 ms = **3.2×**）；复杂 2258 quads：1.56 / 2.25 / 5.12 /
  7.49 ms（原 13.2 ms = **1.76×**）。
- **双词法 bench（0903）**：trig_bench_test 新增 Lexermoon vs C Lexerc 逐 token
  `(分类, 偏移, 长度)` pin 断言——简单 4006 tokens、复杂 9046 tokens **全一致**；
  C 侧 434/907 µs vs MoonBit 1117/2056 µs（**2.6× / 2.3×** 差距，优化空间见 §5）。
- **文档收口**：Enter/ExitGraph 双路由写入 engine.mbt 头注（决策：维持现状，
  不引入 action_args）；materializer `new()` 注明 prefixes 生命周期与 @base 缺陷。
- **套件 pin**：rdf-trig 286/286、rdf-turtle 258/258、rdf12-trig 28/28、
  rdf12-turtle 67/67（deferred 71/59/8/9）；单元 49/49。
- **★3 阶段3 `()` 集合落地 + deferred 回收（2026-09-04）**：PredKind 合成谓词
  标记（RDFFirst/RDFRest，快照即消费——snapshot 读后归 Normal）+ QuadSpan/
  TrigPendingQuad 带 pk；ListExpectElemOrEnd/AfterElem 两态区域 + 六路入口行
  （顶层/指令后/图块主位、顶层/图块宾位、bnp 宾位）+ 嵌套行；链节点身份
  Span(open.0, k+1)（node0 = `(` token 自身 span，长度承载序号）；list_first/
  next/nil/step + *_nested 五 action + ListStep/OpenSlot effect（嵌套元素开帧
  延后到链发射后兑现）；空集合 pop 特判写 Span(open.0, 0) = rdf:nil 标记（长度
  0 = 无字节词项，轻验放行/物化层合成词表 IRI）；合成 quad p 槽 (0,0) 占位过
  缺槽检测（物化按 pk 分派，永不读 p 字节）；fresh 标签 `_:genid{off}n{k}`，
  fresh_ids memo 键改全 Span（链节点同 offset 互撞）；**emit_queue**（Sequence
  多条 EmitQuad 逐条 FIFO 上抛——rest+first 双发射单步多 quad，旧单 pending
  覆盖丢 quad）；skip 守卫收窄只认 `[`（集合独立成句非法，bad-list-01 口径）。
- **回收出槽三桩 + 回归四桩（2026-09-04）**：①词法后缀门——`scan_literal_suffix`
  紧邻字节须 `^`/`@` 才进后缀扫描（旧"只认空白收束"把 `"a")` 闭括号吞进词项，
  lists-05 集合元素位失配；`"text".` 尾点出独立 Dot，C 版 Lexerc FFI 冻结保留
  旧行为，该形态移出共享电池记录分歧）；②PrefName 相对展开按 base 解析
  （`@prefix : <#>` 展开仍是相对 IRI，subm-01 口径；无 base 报错与 `<rel>` 词项
  同径）；③fn_remove_dot_segments 尾斜杠保留（RFC 5.2.4 尾空段不可弃，旧口径
  base /a/ 上解析 #x 误得 /a#x）；④`] }` 图块无点收口行 + 集合主位 ret 改
  ExpectPredicate/GraphExpectPredicate（集合头裸节点谓语必接，bad-list-03/04 与
  collection-graph-bad 表即裁决）+ 新态 TrigExpectVerbRequired（顶层集合主位，
  无 Lbrace/Dot 出边——`(1 2) {` 集合做图名拒，`<g> {` 主形态走 ExpectPredicate
  行不受扰）+ 指令后 DirectiveEnd TripleTerm 主位行（turtle12-bnode-03；括号壳
  `<<(` 不接，NT reifier 形态只许宾位）。wbtest +4 回归钉（后缀门/相对展开/
  sole-badlist 对偶/指令后壳主位）。
- **套件新账（2026-09-04 回收后）**：rdf-trig 345/345（deferred 12）、rdf-turtle
  315/315（deferred 2）、rdf12-trig 31/31（deferred 5）、rdf12-turtle 70/70
  （deferred 6）；单元 gen_trig 67 + gen_nquads 136 全绿。
- **第三轮撤桶（2026-09-04）**：trig-turtle-01..06/bad-01/02 + minimal-whitespace-01
  九文件整族出槽（当初 ★3 前打包入桶未逐条诊断，[]/() 落地后全走通）。minimal-whitespace
  揪出一真坑：**@ 风格指令名零空格直连冒号**（`@prefix:<iri>`）——词法整词扫出
  `prefix:`（冒号是名字字符），关键词臂只认 6 字节整词 → 表外报错。修法：适配层
  单槽 pending 拆分（@ 邻接位精确 "prefix:"/"base:"/"version:" → 关键词事件 +
  冒号声明名 PrefName 先入后兑；"kw:foo" 带本地部不拆仍拒，term 位 `prefix:x`
  无 @ 邻接不命中）。wbtest +1 回归钉（四向：拆分通过/@base: 拒/@prefix:foo 拒/
  term 位 pname 不受扰）。rdf-trig 354/354（deferred 3）、单元 204/204 全绿。
- **★1 @base per-quad 快照落地（2026-09-04）**：`ctx.base` 单槽 → append-only
  base 链 `ctx.bases`（set_base 落尾）；EmitQuad 快照带出 `pver`（前缀账本长）+
  `bver`（base 链长）进 TrigPendingQuad/QuadSpan；物化层 resolve_prefname 回扫
  上界钳 pver（前缀重声明不污染历史 quad）、`base_at(bver)` 折叠 chain[0..bver]
  （绝对 @base 重置累计值，相对 @base 对累计值/链空落 fallback 按 RFC 3986 5.2
  合并——subm-27 `@base <foo/>` 相对链式依赖此语义；bver 键 memo，错误不 memo
  逐 quad 重报；bver=0 → fallback → 皆无报错，绝对文档零开销）。wbtest +2 回归钉
  （中途换 base/前缀重声明 + 相对链/相对前缀声明随 base 改写）。
  **subm-27 ×2 出槽**：rdf-trig 355/355（deferred 2）、rdf-turtle 316/316
  （deferred 1）、单元 204+2 全绿。
- **★8 回灌完成（2026-09-04）**：手改面全部回灌生成管线——domain 层
  （trig_domain.toml：36 态/33 事件/10 效果/184 行 + [[context.snapshot_extras]]
  pk/pver/bver 读后归 + 18 动作词表 = 表驱动 15 + params 声明面 3）→
  domain_to_ir 推导（手改臂序逐行落表；PopBnp/ListStep/OpenSlot 落 semantics =
  "hook"）→ fsm_out/trig_fsm.toml → fsm CLI 再生 trig.mbt。配套机械（fsm 包）：
  [[context.snapshot_extras]] 解析（键归 context 节，发射器同位）+ 根 [[actions]]
  声明面动作 + codegen 多参签名按位统一（payload/Bool/SlotType/state:X 词表）+
  binding 词表 state:/:: 直通 + trait 方法 fn 前缀补正（生成物首回真编译暴露）。
  **再生收敛**：regen vs 手稿 diff 仅余化妆差（枚举/行注释不发射、单行 vs 折行、
  canonical 绑定名 elem/span/typ/ret_state、自环行死写 ctx.state、dispatch 钩子
  臂序）——四套件 355/2、316/1、31/5、70/6 全绿证行为等价，单元 206/206。
  **"生成器回灌前禁再生"解除**：trig.mbt 自此生成器所有（再生成：moon test
  -p rdf 落 fsm_out/trig_fsm.toml → moon run src/fsm/cmd -- <toml> -o trig.mbt）；
  遗留 src/gen_trig/trig.toml（旧 20 事件声明，无管线引用）已删（2026-09-04 收官
  退役；probe_tmp_test.mbt 刮痕同批清，场景归 wbtest 指令后 TT 壳主位）。
- **N3 战役增量（0903，步 1-2）**：词法加字词 `=>`/`<=` 整词 Unknown(2)
  （`{|`/`|}` 同机械，双词法器同改，`>=` 无规范依据不加）+ 微测试双词法器
  逐 token pin（nquads_test）；TrigEvent 手扩 7 变体（Bang/Caret/Implies/
  ImpliedBy/ForAllKw/ForSomeKw/KeywordsKw，落 span_of_event/Show/兜底）；
  classify_structural 加 `!`/`^` 单字与 `=>`/`<=` 双字节判别，classify_prefname
  加 @forAll/@forSome/@keywords（at_style_kw + eq_lower 精确拼写）；
  wbtest pin 全分类序列。表未接，新事件全走兜底，四套件不变。
- **★3 `[]` 属性列表落地（2026-09-03，路线甲阶段1+2）**：Slot/SlotType 契约 +
  ctx.slot_stack；TrigLbracket/TrigLparen 载荷化（开括号 span = fresh 身份）；
  BnpExpectPredicate/Object/AfterObject 三态区域 + 5 个入口行（顶层/图块/指令后
  主位、顶层/图块宾位）+ 嵌套行；open/pop_bnode_prop 双 action（帧携返回状态，
  pop 兑现——state 由表管理的唯一例外）；PopBnp effect 变体（loop 顶层 + Sequence
  内直调 action，对齐 ExitGraph 口径）；轻验放行 `[`/`(` 首字节；物化 fresh_ids
  memo（`_:genid{offset}`，免深验）；组装层空 fresh 独立成句跳过；recover 清栈、
  finish_at_end 栈脏判脏 + 自排水同清栈（否则排水被重新点燃 = 错误无限循环，
  wbtest 压测抓到）。主位收口返回 = VerbOrDot（`[ :q :r ] .` 与 TT 主语语法位
  同构）。wbtest 5 用例：主位/宾位/空形式/分号链嵌套/图块+EOF 判脏。

## 5 未完成 step 与事项

| 优先 | 事项 | 现状/修法 |
|---|---|---|
| ★2 | **`<< >>` 壳内 `^^datatype` 误拒** | triple_term_inner_terms 按顶层空白切项，`^^xsd:date` 被拆成第 4 项。修法：切项时引号单元闭壳后右扩 @lang/^^ 后缀（bench 语料已规避） |
| ★3 | **`[]` + `()` 全部落地（路线甲，见 §5.1/§5.2）；deferred 桶收官（2026-09-04 六轮）** |三桩真堵全平：③壳内 `~` reifier ×4——`triple_term_inner_terms` 三项后吞 `~ [reifier]` 尾巴（分写/连写/裸 ~/IRI 形，tail_seen 门防双 ~，粘第 3 项尾就地断项），三层共用一函数（validate_term/tt_shell_terms/deep_check_tt）；①`[]` 图标签 ×2——词法把空 ANON 立成单事件 TrigAnon（`[]` 本就是 BlankNode 终结符非开括号；数据面跳空白窥 `]`，anon_swallow 吞槽，注释不合并），七路 term 位行直落（主位×3/宾位×2/集合元素/图标签），`[] { }` 顶层复用宾位 Lbrace 行（ExpectPredicate+Lbrace→enter_graph(ctx.subject)）兑现图标签解释，`[] .` 由静默吞收紧为拒；②注解体宾位 fresh ×2——AnnotExpectObject/GraphAnnotExpectObject 补 Lbracket（嵌套帧快照注解体 s/p/g，弹帧回 AnnotExpectEnd）+ Anon 行。表规模 36 态/34 事件/10 效果/195 行；`[] .` 口径收紧致两条旧 wbtest 改写（适配器事件流 8→7、空形式测试）。manifest 控制文件（W3C harness 测试入口清单，非测试用例）转过滤层排除不入账，trig_suite_deferred 谓词整体退役，deferred 计数撤销。**四套件终账：357/0、316/0、36/0、75/0，deferred 全零**。subm-27 ×2 已随 ★1 出槽（2026-09-04） |
| 4 | 三引号规范化转正 | serializer 目前原样保真回写，规范化待设计 |
| 5 | MoonBit 词法优化 | 落后 C 侧 2.3-2.6×；候选：主循环字节分派表、span 直写、减少 Token 枚举构造 |
| 6 | deferred 细项归因（2026-09-04 ★1 出槽后 2/1/5/6） | rdf-trig 2：kw-graph-07 + anonymous_blank_node_graph（`[]` 图标签，需 ExpectGraphLabel 接 fresh）；rdf-turtle 1：manifest（永久桶）；rdf12 各 5/6：annotation-2 + syntax-inside（壳内/注解内 fresh 嵌套）+ manifest |
| 7 | RDF 1.2 注解体内 [] 嵌套 | 依赖 ★3 |
| 9 | @keywords 语义豁免 | 适配层无跨 token 状态，@keywords 模式下 'a' 仍出 KeywordA；语义豁免归表/物化层，接表时定案 |

### 5.1 ★3 定案（2026-09-03 评审后落地）：`[]` 属性列表（`()` 集合见 §5.2）

**帧设计（Slot，types.mbt）**：
- `SlotType = BnodeProp | List | Formula`；`Slot = { typ, open_span, subject,
  predicate, graph, ret_state, as_subject, prev_node, mut node_seq }`。
- `elements` 数组移除——区域内三元组照常走 EmitQuad 发射，帧只存"外层快照 + 身份 + 返回"。
- `open_span` = 开括号 token 自身 span，fresh 节点身份（offset 全文档唯一）；
  Span 不编码额外信息（物化层 memo `_:genid{offset}`，图同构比对只需文档内一致）。
- 集合链（阶段3）：链节点身份 = Span(open_span.0, node_seq) 打包，seq 逐节点递增。

**区域分裂与返回状态**：
- 区域状态按"待收什么"分裂（BnpExpectPredicate/Object/AfterObject 三态共用），
  主/宾位不分裂区域——位置语义进帧（as_subject）；**返回状态由开括号转移行定夺
  写入帧，pop 时兑现**（帧携带的是表已做的决策；顶层/图块/嵌套层各写各的，
  避免 GraphExpect* 区域倍增）。这是 state 由表管理的唯一例外。
- 主位收口返回 = ExpectVerbOrDot（`[ :q :r ] .` 点合法，与 TT 主语语法位同构；
  宾位收口返回 = ExpectDotOrGraph / BnpAfterObject（嵌套）。

**压栈/弹栈是 action（§1.4 边界）**：`open_bnode_prop`（外层 s/p/g+ret_state 入帧，
fresh 占 s 槽、p 清空）/ `pop_bnode_prop`（恢复外层 s/p/g，fresh 落 as_subject 定的
目标槽，state=ret_state）。

**收口发射序**：`[` 与 `]` 之间有挂起内层三元组 → `Sequence([EmitQuad(PredObj),
PopBnp])`；空形式/尾 `;` → 裸 `PopBnp`。emit 先 snapshot 后收拾，PopBnp 恢复值取自
帧，不受 PredObj 收拾波及。PopBnp 是新 effect 变体（演进只加变体）；loop 顶层与
Sequence 内各一臂，直调 pop action（对齐 ExitGraph 意图兑现口径）。

**策略交互（栈不在 ResetScope）**：`reset` 不碰栈；`begin_record`/`recover` 清栈
（错误即弃外层挂起语句）；`finish_at_end` 栈非空 = dirty（EOF 未闭合报错）。

**周边配套**：
- TrigLbracket/TrigLparen 载荷化（span = 开括号自身；事件载荷 span 口径）。
- 轻验放行 `[`/`(` 首字节（语法闭合由表+EOF判脏保证）；物化层 fresh_ids memo
  （offset → arena `_:genid<N>`，可信构造免深验）；组装层空 fresh 独立成句
  （`[] .`）静默跳过（零三元组，不进缺槽报错）。
- 谓词位无 `[` 出边：bnode 不可作谓词（表即裁决）。

### 5.2 ★3 阶段3 定案（2026-09-04 落地）：`()` 集合链 + 回收

**合成谓词（PredKind）**：链节点 rdf:first/rdf:rest 在数据中无字节——表在合成
发射行写 `ctx.pred_kind`，`TrigContext::snapshot` 读后归 Normal（快照即消费，
恰覆盖一次发射）；pk 随 TrigPendingQuad/QuadSpan 带出，物化层按 pk 合成词表
IRI（永不读 p 字节）。合成 quad p 槽 None → 组装层归一 `Some((0,0))` 占位过
缺槽检测。begin_record/recover/finish_at_end 三处归零（快照窗口外不得残留）。

**链节点身份**：node_k = `Span(open.0, k+1)`——node0 = `(` token 自身 span
(off,1) = 集合头，pop 写 fr.open_span 天然落位；长度承载序号。空集合 pop 特判
`fr.typ is List && fr.node_seq == 0` → 写 `Span(open.0, 0)` = rdf:nil 标记
（长度 0 = 无字节词项：轻验放行 n==0，物化层 s.1==0/o.1==0 → push_vocab(rdf_nil)；
真实词项长度恒 ≥1）。物化 fresh 标签 `_:genid{off}n{k}`；fresh_ids memo 键 =
全 Span（链节点同 offset 只按 offset 键互撞）。

**发射机械**：list_next = Sequence([EmitQuad(rest-link), ListStep(elem),
EmitQuad(first-link)])——单 step 多 quad，engine `emit_queue`（无 mut Array）
FIFO，next() 顶部优先排空（旧"单 pending 覆盖"丢 quad，rest-link 被覆盖）。
嵌套元素（`[`/`(` 作元素）：first/rest 链必须在开帧前发射（快照要拍到链节点，
开帧覆写 s）→ OpenSlot(Span, SlotType, TrigState) 在 EmitQuad 后兑现（loop 顶层
+ Sequence 内各一臂直调 open_slot action）。

**入口行与返回状态（六路）**：位置定 ret（帧携）、区域状态由行写入——
顶层/指令后主位 ret=TrigExpectVerbRequired（新态：仅谓语出边——集合头是裸节点
谓语必接，bad-list-01/02 `(1 2) .`、collection-graph-bad `(1 2) {` 表即裁决；
`[]` 完整 predObjList 的 VerbOrDot 相分）、图块主位 ret=GraphExpectPredicate
（bad-list-03/04 `( 1 2 3 ) }` 拒）、宾位 ret=ExpectDotOrGraph/
GraphExpectDotOrGraph/BnpAfterObject。

**回收（2026-09-04）**：deferred 22 桶（71 文件）→ 回收 61 文件出槽，迭代中
出槽五桩（词法后缀门/PrefName 相对展开/尾斜杠/`] }`/指令后壳主位，见 §4）；
第三轮撤桶 trig-turtle 族 + minimal-whitespace 九文件（@ 风格指令名零空格直连
冒号拆分，见 §4），
★1 per-quad 快照落地后再出槽 subm-27 ×2，余桶 2/1/5/6（账目见 §5 表 item 6）。skip 守卫收窄只认 `[`：`[] .` 独立成句
合法静默跳过，`( 1 2 3 ) .` 集合独立成句非法必须进组装报错（bad-list-01 口径）。
