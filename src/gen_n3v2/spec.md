# gen_n3v2 架构规格（spec）

版本：v1.0.0（2026-09-11 立卷；役21 之后 = 评审 + 整改基线）

卷面分工：

- `adr.md` = 战役记录与 ADR（历史卷，讲"为什么"；役18/19/20 在卷）。
- 本文件 `spec.md` = 结构事实 + 已验证口径（讲"现在怎么运转"）+ 冲突写实（C 台账）+ 整改裁决（R 台账，讲"接下来怎么改"）。
- `ctx.md` = 整改工作上下文（锚点、证据、动作步骤、验收、风险、待裁题）。
- `todo.md` = 2026-09-11 原始评审底稿（未整理，仅参考；结论已并入本文件与 `ctx.md`）。

**评审纠偏（2026-09-11 用户定案）**：原始评审把 `N3EffectHandler` 判为"死模板 / 建议删除"。
用户定案翻转：该层是**架构维度的扩展位**（效果面切面挂点），定案 = **保留 + 简化 + 接活**，
不得删除；`N3LoopPolicy` 定案 = **第三条业务面**，将来承载 **Test & Fallback（容灾）** 与
**Observability（可观测）** 切面。本文件与 `ctx.md` 一律按此口径书写。

仓界事实（改代码前先确认落到哪个仓）：本包在**嵌套仓** `src/ttl`（独立 `.git`）；
生成器与表源在**外层仓** `src/rdf/n3gen`。跨仓改动分两笔提交；`n3.mbt` 只许再生，不许手编（G9 黄金门）。

基线（2026-09-11 实测）：

- `cd src/ttl && moon test src/gen_n3v2` → **111/111**；`moon check src/gen_n3v2` → 0 error / 11 warning。
- 套件：rdf-turtle **316/316**、rdf12-turtle **75/75**、N3Tests **neg 23ok/0miss + pos+eval 205clean/0mat-only/0parse-fail**、examples 13 文件全 A-full。

---

## 1. 分层与文件映射

| 层 | 文件 | 职责 | 产出 |
|---|---|---|---|
| 词法复用 | `@nquads.Lexermoon`（gen_nquads 包） | bytes → token；与 C 版 `lexerc_ffi.c` 同型同宽 | `Token` |
| 事件适配 | `lexer_adapter.mbt` | token → 事件；`?x`/`[]` 合并、`@prefix:`/`<-` 拆字、langtag 子 span | `N3Event` |
| 状态机（生成） | `n3.mbt` | 41 事件 × 55 状态 × 384 转移的 `step`；类型/ctx/三业务面 trait | `N3Effect` |
| 主循环（用户） | `engine.mbt` | 驱动 step、解释 Effect、尾标点合成、错误恢复、EOF 判脏 | `N3PendingQuad` |
| 语义实现（用户） | `actions.mbt` | 48 个 action：落槽 / 压栈 / 路径 desugar / 倒装 / 注解 | 槽位与账本 |
| 组装校验 | `parser_slice.mbt` | 缺槽检测 + 轻验（IRI/BNode/PrefName/TT 壳） | `QuadSpan` |
| 物化 | `materialize_n3.mbt` | span → `QuadEmit`；四门深验在构词点就地执行 | `QuadEmit` |
| 序列化 | `serialize_n3.mbt` | 字节保真回写；拒绝 PrefName/图名残留 | `String` |
| 类型面 | `types.mbt` | `Slot`/`SlotType`/`QuadSpan`/`IRIUpcastEvent`/`ErrOut`/方言开关 | — |

数据流一行图：

```
Lexermoon(@nquads) → N3LexerAdapter(LexerSource) → N3Engine.next → step(表)
  → N3Effect → [解释器] → N3PendingQuad → assemble/validate → QuadSpan
  → N3Materializer(四门) → QuadEmit → N3Serializer → 文本
```

生成链一行图：

```
src/rdf/n3gen/{n3v2_base.toml, n3v2_trans.toml}
  → n3gen_build(parse → validate G1–G8 → emit)
  → src/rdf/n3gen/n3v2_out.gen
  → cp → src/ttl/src/gen_n3v2/n3.mbt   （G9 逐字节黄金门 + 强幂等）
```

规模事实：41 事件 / 55 状态 / 384 转移 / 48 动作 / 27 ctx 字段（役26 删 variable_name/rule_side）/ 5 快照 extras
（`pk`/`pver`/`bver`/`iver`/`subj_shell`）/ capabilities 14 项。生成面 2.2k 行、用户面约 5.2k 行、
测试 116 个 test 块 + 4 个套件 runner。

---

## 2. 三个业务面（生成契约 = 架构扩展维）

| 面 | trait | 生成锚点 | 实现锚点 | 定位 | 扩展意图 |
|---|---|---|---|---|---|
| ① 语义落点 | `N3Actions`（48 方法） | `n3.mbt:301` | `actions.mbt` 全文 | 只写槽位/账本，返回意图；永不重置 ctx、拿不到数据视图 | 新语义优先扩 action，不动 Gen 枚举 |
| ② 效果执行面 | `N3EffectHandler`（14 方法） | `n3.mbt:2045`（套装 `emit.mbt:1083` verbatim 定格） | **当前无实现**（`engine.next` 自建解释器，见 C-02） | **架构维度扩展位**（用户定案）：效果执行阶段的切面挂点；形态可简化 | 观测（emit 埋点）、容灾（效果降级/丢弃/改写）、审计 |
| ③ 控制流面 | `N3LoopPolicy`（4 钩子） | `n3.mbt:284` | `engine.mbt:345/364/416/447` | **第三条业务面**（用户定案）：主循环领域钩子 | **Test & Fallback（容灾）+ Observability** 切面 |

切面挂点表（要挂什么 → 挂哪个面 → 现状能不能挂）：

| 切面需求 | 挂点 | 现状 |
|---|---|---|
| 语句计数 / 吞吐 / 耗时 | `LoopPolicy.begin_record` / `finish_at_end` | 部分（无 emit 计数） |
| 错误分类、容灾决策（跳过/重同步/降级） | `LoopPolicy.recover` / `on_business_failed` | 可以（但恢复策略目前写死） |
| 截断 / 脏尾 / 输入损坏兜底 | `LoopPolicy.finish_at_end` | 可以 |
| 每 quad 观测（emit 埋点） | `EffectHandler`（`EmitQuad` 执行点） | **不可以**——`engine.next` 绕过 EffectHandler |
| 效果降级（`EmitQuad` 丢弃/改写） | `EffectHandler` | **不可以**（同上） |
| 步级 trace `(state,event,effect)` | 需新钩子（挂 ② 或 ③） | 不可以（无钩子） |

**关键推论**：观测/容灾切面要在效果面生效，前提是 `engine.next` 重新经 `interpret()` 走
`N3EffectHandler`（R-02）。"保留扩展维"与"消除双解释器"不是矛盾，而是同一动作的两面。

---

## 3. 不变量清单（I）

| 编号 | 不变量 | 状态 |
|---|---|---|
| I-1 | span `(offset,len)` 是词项唯一身份；fresh 节点身份 = 开括号/操作符 token span | 成立（路径/集合/公式/倒装身份全依赖） |
| I-2 | arena append-only；早先取出的 view 永久有效 | 成立 |
| I-3 | 正例 `emits.length == quads.length`（物化不丢项） | 成立（套件判据） |
| I-4 | EOF 合法送达一次，其后 `None` = 枯竭 | 成立（`n3_wbtest` 钉） |
| I-5 | 错误恢复只停 Dot → 归位 `ExpectSubject`，并清栈/清注解账 | 成立（`engine.mbt:381`） |
| I-6 | **状态转移由转移表唯一管理** | **成立 + 2 登记破例**（役23 机制收敛：id 特例前移刻帧，pop 无条件读帧；path_end_nested/path_subj_end 链形异判以 [R-03-2/3] 锚登记，C-01 转设计） |
| I-7 | 生成物禁手编；表变 → 再生 | 成立（G9 字节对拍 + 强幂等） |
| I-8 | TOML 契约兼容演进（新键可选、未知键忽略、删键需同改手写文件） | 成立（AGENTS.md 宪法） |
| I-9 | 错误通道单一（结构错误与组装错误同源同序） | **成立（役24 清偿 C-05：error_spans 累积 + drain 同序）** |

---

## 4. 生成物权属与再生管线

- 表源（外层仓）：`src/rdf/n3gen/n3v2_base.toml`（493 行，声明面）+ `n3v2_trans.toml`（2676 行，转移面）。
- 门（`src/rdf/n3gen/n3gen_test.mbt`）：
  G1 未知顶层段/键；G2 重名与 `is_initial` 恰一个；G3 `from/on/to/effect` 引用存在性与 `(from,on)` 唯一；
  G4 guard/assign 白名单；G5 `[[actions]]` 按名升序 + chain reset 字段合法；G6 自由文本引号与 extras self 门；
  G7 行内未知键；G8 `action_args` 封闭词表；**G9 黄金门**（先落 `n3v2_out.gen` 再与 check-in `n3.mbt`
  逐字节对拍）+ 强幂等（重复 build 零字节移动）。
- 再生三段（两仓）：

```sh
cd /home/thy/moonttl && moon test src/rdf/n3gen          # 落 n3v2_out.gen（失配红 = 表已领先，需交付）
cp src/rdf/n3gen/n3v2_out.gen src/ttl/src/gen_n3v2/n3.mbt
cd src/ttl && moon info && moon fmt && moon test src/gen_n3v2
```

- emit 面锚点：`src/rdf/n3gen/emit.mbt:657`（LoopPolicy 模板）、`emit.mbt:1083`（`n3_emit_handler_suite`：
  EffectHandler 套装 verbatim 固化——**改它的形态 = 改 emit + 再生 + 对拍显式翻新**）。
- 耦合提示：表内嵌 MoonBit 字面量（`assign = "directive_at=..."`、`action_args = ["payload","false","state:ExpectObject"]`、
  `"SlotType::BnodeProp"`），重命名枚举/状态/字段必须同改表（见 R-10 影响面）。

---

## 5. 机械约束（写表 / 改引擎前必读）

- **guard 只通 `ctx.` 前缀**：事件字节进不了表行守卫。需要按词项形态裁决时，引擎归位点做词法嗅探写
  ctx 旗标（先例 `version_lit_ok`），表行 `guard_def = "ctx.xxx"` 消费。这条制度正是 C-03 的根源。
- **EOF 不进表**（数据边界）；无 payload 事件绑 `(0,0)`，错误位置由 loop 用词法位置回填。
- 未列举组合 → `UnexpectedEvent` / `BusinessFailed` → `recover`。
- **ctx 新字段守门**：优先"事件载荷化 > 台账后置"；类型化子 struct 仅在"单子系统 ≥4 联动清槽字段"或
  "总字段 >40" 时触发；禁运行时扩展袋。当前 **29 字段 / 6 特性轴**——R-13 已落地（役28：组清方法形式，题5=A；字段分节 B 留账）。
- 词法共享口径：`Lexermoon` 吞边界（`,`/`.`/`;` 入 span 且标点事件丢失）→ 引擎 `trim_trailing_punct`
  三瓣剥离 + 合成事件回灌（`engine.mbt:84`），见 C-04；补偿点单点台账 = `lexer_adapter.mbt`
  头注六点地图（役29 R-04 短期，含钉面清单）。

### 5.1 权威破例归位清单（R-03，2026-09-11 役23 定案；条目只减不增）

表权威的边界写实：**表 = (state, event) → action 的静态映射**；运行时数据依赖
（帧字段、链形、词项字节、文档台账）表达不进静态行——以下破例点**全部显式登记**，
每条注明"为何表内表达不了"。改表/改引擎前先核对本清单；新增破例须入册。

**A. ctx.state 直写（R-01 收敛后余量：恰 3 处）**

| 编号 | 位置 | 触发 | 为何表内表达不了 |
|---|---|---|---|
| [R-03-1] | `actions.mbt:171`（pop_bnode_prop） | 区域弹栈兑现 | **机制位**：state 兑现统一读 `fr.ret_state`（帧携带，OpenSlot ret 同机制）；id 形特例已前移 set_id_subject 刻帧（役23 R-01）。帧值运行时才定，表行 `to=` 是常量——帧携带是表能表达"动态返回态"的唯一通道 |
| [R-03-2] | `actions.mbt:528`（path_end_nested 拒绝臂） | 反向链 `^` 终于复合节点 | 同 (from,on) 行内按链形（`ctx.path_fwd`）异判；表行 guard 的 else 臂 = UnexpectedEvent（不 fallback 下一行），行分裂不可行——两链形同 from 态 |
| [R-03-3] | `actions.mbt:718`（path_subj_end None 臂） | 动词位链终原子 | 同 [R-03-2]：主位/谓词两链形在 SubjTrailAfterStep 汇合（谓词链 path_step 每步同入，表行实证），按 `ctx.path_src` 分派 |

**B. 引擎归位点（normalize_term_span 家族）**

| 编号 | 位置 | 触发 | 为何表内表达不了 |
|---|---|---|---|
| [R-03-4] | `engine.mbt:83` trim_trailing_punct | 词尾吞标点（七类 payload 事件） | ① span 子手术（剥尾字节）非表能力；② 一词两事件（剥离 + 合成 Dot/Comma/Semicolon 回灌）破坏表 1 事件→1 转移模型。根源 C-04，根治 R-04（词法收口） |
| [R-03-5] | `engine.mbt:104` is_version_lit_form | VERSION 指令字面量形态 | guard 只通 `ctx.` 前缀（本节首条制度）；嗅探写旗标、**决策在表行 guard**——合规机制形态，非破例（登记以正名分） |
| [R-03-6] | `engine.mbt:220` KeywordA 臂 | @keywords 后未列出的裸 `a` | **事件重分类**（KeywordA→PrefName）发生在表上游：表按事件种类查行，无法"把 A 事件当 PrefName 行处理"；裁决需台账字节比对 + 声明区 state——字节比对是词法操作（guard 只通 ctx），state 依赖可表行化但重分类本身出表模型。kw_a_live 熄火为横切记账（七类谓词事件同做），上表 = 48 行重复 |
| [R-03-7] | `engine.mbt:246` Unknown 晋升臂 | 台账命中裸词 + `this` 门 | 同 [R-03-6] 事件重分类（Unknown→KeywordX）；`this` 硬编码 = 套件裁决常数（役20，manifest 判负口径，WG 否决的规则不实现），非语言规则故无表行 |

**C. 关键词真相收敛裁决（C-03 写实修正）**

三处**正交非冗余**，各自单一数据源，无收敛欠账：
`classify_prefname`（adapter，静态语言保留词：a/true/false/version/prefix/base/is/of——事件产生侧）
∥ `ctx.kw_ledger`（引擎，动态文档台账：@keywords listed 词——重分类侧，唯一数据源）
∥ 表行（KeywordA/KeywordX 消费行）。C-03 原文"物化层 bool_at"系误诊：bool_at 是布尔
字面量展开（C-15 家族），不参与关键词裁决。KeywordA 降级/this 门**不上表**（理由见
[R-03-6]/[R-03-7]，事件重分类出表模型）。

---

## 6. 已定语义口径（合理面总结，固化）

语义裁决（ADR 卷）：

| 编号 | 口径 |
|---|---|
| ADR-002 | 公式 `{}` = 不透明 GraphTerm，内容不默认断真；帧型 `SlotType::Formula`；罩内 `EmitQuad` 降级为纯收拾 |
| ADR-003a | 集合 `( ... )` = 单一 BNode（身份 = `(` span），不发 `rdf:first/rest` 链；空集合 = `rdf:nil` 标记 |
| ADR-003b | 显式链物化预留死位：`PredKind::RDFFirst/RDFRest` + `iver` 快照槽（当前 tick 恒 0，物化不读） |
| ADR-004 | 变量 `?x` 只记身份（不展开、不绑定、不前缀解析）；谓词位变量显式拒绝 |
| ADR-005 | `=`/`=>`/`<=` 只作谓词身份：`=` → `owl:sameAs`（`pk=SameAs`），`=>`/`<=` 原文保真直出 |
| ADR-006 | 路径 `!`/`^` = fresh 中间节点链（身份 = 操作符 span），每跳急发 `EmitQuad(SPO)`，末跳交既有收口行 |

役次口径（`adr.md` 详载）：役3 路径 / 役4 规则 / 役5 `@keywords` 台账与 `pk=KwA` / 役6 `is..of` 倒装
（交换键 `is_src` + 槽深 `is_depth`）/ 役7 `=` 等同 / 役8 注解壳（`<<锚三元组原文>>` TT，壳账四字段）/
役10 词位扩展（`verb ::= expression`）/ 役11 `has` 与 `[]` 谓词位 / 役12 罩内 `is/of` / 役13 量化指令 /
役16 `id`/`<-` + 尾随路径 / 役18 词法 `^` 门 + `path_obj_close` 双发 / 役20 负例缺口 3 收口（`this` 晋升门、
声明名验形门、`bad_prefix2` 翻案 skip）。

物化口径：`arena` 展开 + `view` 零拷贝直引；`gate_iri/gate_bnode/gate_tt/gate_literal` 四门就地深验；
`formula_body_end` 配对扫描（串/IRI/注释/两字节操作符跳过）；字面量主语臂；谓词 raw 集（字面量/变量/
`[`/`{`/`=`/`<=`/`=>`）；隐式空前缀绑定（账本 miss + 词首 `:` → base 解析）。

---

## 7. 冲突写实台账（C）

性质取值：**[设计]** 有意取舍（需登记而非修改）、**[债]** 应整改、**[制度]** 由生成器/宪法机制导致的副作用。

| 编号 | 事实（写实） | 证据锚点 | 后果 | 性质 |
|---|---|---|---|---|
| C-01 | 状态双权威：action 直写 `ctx.state`，与表 `to=` 并存。**役23 R-01 收敛**：3 处条件分叉 → 1 处无条件机制位（pop 读 `fr.ret_state`，id 特例前移刻帧）+ 2 处破例（链形异判，表静态行表达不了）；全部入册 §5.1 清单 | `actions.mbt:171/528/718`；清单 §5.1-A | 运行时数据依赖出表模型是 FSM 边界本质——破例恒可数、每条有"为何"，可达性分析按清单扣除 | [债]→**[设计]（役23 收敛后）** |
| C-02 | 效果语义双实现：`engine.next` 手写解释器 vs 生成面 `interpret/dispatch/handle_*`；`apply_scope` 与 `ctx.reset` 同逻辑两写 | `engine.mbt:533`↔`n3.mbt:2168`；`n3.mbt:2144`↔`n3.mbt:218` | 两处语义可漂移；② 面切点（观测/降级）形同虚设 | [债]（**用户定案保留 ② 面**） |
| C-03 | 引擎归位点做词法/语法重分类：`KeywordA→PrefName` 依 `ctx.state`/台账改判；`this` 4 字节常量硬编码 | `engine.mbt:220/246`；清单 §5.1-B | **役23 写实修正**：原"关键词真相散在三处（含物化 bool_at）"系误诊——bool_at 是布尔字面量（C-15），三处实为正交分层（保留词/文档台账/消费行），各自单一数据源（§5.1-C） | [制度]（guard 只通 ctx 的下游；事件重分类出表模型） |
| C-04 | 词法边界欠账：adapter 五处手术（`[]` 合并 / `?x` peek / `@kw:` 拆字 / `<-` 拆字 / langtag 拆）+ 引擎尾标点合成 `Dot/Comma/Semicolon` | `lexer_adapter.mbt` 头注台账（役29 单点化，六点地图 + 钉面清单）；`engine.mbt:84` | ~~一次词法口径变动须四处同步、补偿点散装无单~~ 台账单点 + 识别件 R-15 单点（役29）；长期方言感知词法器仍立案 | [债]→**短期已收口（役29）** |
| C-05 | 错误通道二制：~~`last_error` 单槽~~ **役24 整改**：`error_spans` 累积数组 + BusinessFailed 复位续解 + drain 三点（入口/Some(Err)/终态）——多坏语句逐条落账且文件序 | `engine.mbt`（字段/recover_cleanup）；`parser_slice.mbt`（drain_engine_errors） | ~~多坏语句只报最后一条、业务错带病停机~~ 双通道语义对齐 | [债]→**已清偿（役24）** |
| C-06 | 零长 span（`len == 0`）重载为 `rdf:nil` 标记——**役24 验形门收口**：in-band 通道保留（API 不变），物化层双门 `data[offset]=='('` 校验，事故零长 ValidationErr | `materialize_n3.mbt`（materialize_quad 入口）；构造点 `actions.mbt` pop_bnode_prop（唯一） | ~~事故静默变 nil~~ 合法标记可验形、事故报错 | [债]→**已收口（役24）** |
| C-07 | 证据面缺口：三 runner 全 `lenient=true`（旁路 `validate_term`）；N3Tests 有断言无桶闭合；examples print-only | `rdf_suite_wbtest.mbt:114`、`n3tests_suite_wbtest.mbt:40`、`examples_wbtest.mbt:16` | 316/75/205 这些数字不覆盖校验层；文件清单漂移不报警 | [债] |
| C-08 | 公共面过宽：`.mbti` 暴露 `N3Context`（29 mut 字段）、`N3Actions`（48 方法）、`N3EffectHandler`、`N3LoopPolicy`、`N3Engine` | `pkg.generated.mbti` 全量 38 个 `pub` 项 | 内部重构 = 破坏性 API 变更；公共面无法收敛 | [债]→**已收口（役28，题2=B）** |
| C-09 | 死字段/死 helper/警告：`variable_name`/`rule_side` 永不被读；`iri_upcast` 只写不自增；`mat_graph`/`mat_has_graph` 未用；`bench` 导入未用；4×`starts_with`、`serialize_n3.mbt:84` 未用 `self`、`engine.mbt:467/481` 多余 trait bound | 编译 11 warning | 阅读噪声；表声明字段与实现脱钩 | [债] |
| C-10 | 命名与宪法冲突：`pver/bver/iver`（应为 `prefix_version/base_version/iri_version`）、`fr`、`mat_*`、`Hooks`（实为 action 语义实现体） | `types.mbt:50`（QuadSpan）、`actions.mbt:14` | 违反"名字自带语义"；跨包重命名是原子变更 | [债] |
| C-11 | 测试位置：`materialize_n3.mbt` 内联 23 个 test + 约 500 行测试辅助；`serialize_n3.mbt` 内联 4 个 | `materialize_n3.mbt:1380` 起 | 与"测试进 `_test`/`_wbtest`"约定不符；生产文件被辅助污染 | [债] |
| C-12 | 文档漂移：`guides/n3/README.md` 11 处仍写 `@gen_n3`/`SliceParser`；`syntax.md` 旧分层；ADR 最后为 ADR-20 而代码已到役21；无稳定架构页 | `guides/n3/README.md:3`、`syntax.md:49`；`adr.md`；提交 `7630bf2` | 新人按文档接不上代码 | [债] |
| C-13 | ctx 大对象：29 字段混 6 个特性轴（directive/prefix+base、slot_stack、path、inversion、annotation、keywords）+ 3 个死字段 | `n3.mbt:140-170`；`n3v2_base.toml:440-468` | reset 语义复杂、子系统的"联动清槽"靠人记 | [债] |
| C-14 | 状态爆炸：55 状态含 `FormulaX`/`QuantX`/`SubjTrailX`/`ListPathX` 交叉族（手列） | `n3v2_base.toml` states 段 | 加特性 = 状态数乘性增长，错误面同步放大 | [设计]/[债] |
| C-15 | 数值/布尔识别两套：`is_numeric_span`（adapter/校验）与 `expand_number`+`bool_at`（物化）——**役29 收编**：识别件独此一份 `gen_nquads/numeric.mbt`（`is_numeric_span` + `is_boolean_word`），八消费点三面（adapter/校验/物化，两包）限定名收编；`bool_at` ×2 删除；展开件（expand_*）留驻各物化层（arena 发射非识别） | `gen_nquads/numeric.mbt`（唯一权威）；消费点全图见各 adapter/parser_slice/materialize | ~~同一规则两处实现，易漂移~~ `has_digit` 全仓单点 | [债]→**已清偿（役29）** |
| C-16 | 前缀预绑定缺位：validate_prefname 拒未声明前缀，N3/cwm 内建前缀（log:/string:/...）不声明即用，官方正例 good_prefix.n3 也翻 | 役25 影子扫描 486 处 STRICT-GAP | 宽容主链正确性靠 lenient 跳过校验维持，校验层无法升格 | [债]（役25 立项） |
| C-17 | `<=` raw 谓词被 validate_pred 拒（ADR-005 操作符=谓词身份 vs "IRI must be wrapped in <>"） | 役25 影子扫描 extras-10（`=>` 同构未露头） | 操作符谓词语义与组装校验冲突 | [债]（役25 立项） |

---

## 8. 整改裁决台账（R）

状态取值：**定案**（用户已裁，执行即可）、**建议**（待用户裁）、**立案**（需单独立项/另役）。
每条验收都必须落在命令 + 数字上（见 §9）。

| 编号 | 结论 | 状态 | 动作 | 验收 | 关联 |
|---|---|---|---|---|---|
| R-01 | **状态权威回归表**。**役23 翻案定案（ADR-24）**："三处迁进表"不可达——侦察实证 2/3 号是运行时链形异判（同 (from,on) 行内，guard else=UnexpectedEvent 不 fallback；两链形 SubjTrailAfterStep 汇合），1 号 pop 经 interpret PopBnp 臂（handler 返 Unit，役22 架构）。落地 = **机制收敛**：id 特例前移 set_id_subject 刻帧（`mut ret_state` 先例役14 path_obj_close），pop 无条件读帧；SetState 效果变体不立项（三处零可行实例，投机面）。验收改口径：直写恰 3 处且全数入册 §5.1-A | **✅ 已落地（役23，ADR-24）** | actions.mbt 收敛（111/111 不降，id 形语义无恙） | `grep -c "ctx.state = " actions.mbt` = 3 且带 [R-03-N] 锚 | C-01、I-6、§5.1 |
| R-02 | **接活效果面（②）**：`N3EffectHandler` 保留为扩展维；`interpret` 成为唯一解释器，`engine.next` 调它；`apply_scope` 与 `ctx.reset` 合一；`handle_*` 精简（`continue/done` 并入默认）；`take_pending_quad` 的倒装/壳交换下沉为 `N3Context` 级函数供两面共用 | **✅ 已落地**（役22：题1=A 全控；ADR-22） | 改 `emit.mbt`（`1083` 套装）+ engine + 再生 | emit 点有真实挂点；双实现消失；套件数字不变 | C-02、§2 切点表 |
| R-03 | **引擎归位点台账化**。**役23 落地（ADR-24）**：清单 §5.1（A 直写 3 条 + B 引擎归位 4 条 + C 关键词真相裁决）；"能上表的改由表行承载"翻案——KeywordA 降级/this 门是**事件重分类**，发生在表上游（表按事件种类查行，重分类出表模型），登记不上表（§5.1-B/C）；"关键词真相收敛一份数据"修正为写实（三处正交各单一源，bool_at 系误诊除名） | **✅ 已落地（役23，ADR-24）** | spec §5.1 + C-01/C-03 写实更新（引擎零代码改动，纯裁决收口） | 清单条目只减不增；每条有"为何表内表达不了" | C-03、C-04、§5.1 |
| R-04 | **词法收口**：`?x`/`[]`/`@kw:`/`<-`/尾标点上移词法层（方言感知）；短期先做"补偿点单点台账 + parity 钉" | **✅ 短期已落地（役29，ADR-29）**：补偿点单点台账（`lexer_adapter.mbt` 头注六点地图 + 钉面清单）；长期方言感知词法器仍立案 | 本包 adapter 头注 + engine 交叉引用（零 Lexermoon/C 接触） | parity 零差（nquads 对比 72 段 mismatch=0）；套件数字不变（329/329） | C-04、C-15 |
| R-05 | **错误累积**：`error_spans : Array[Span]` 累积 + recover 拆层（record/cleanup）+ BusinessFailed 臂 cleanup 后 return（复位续解）+ drain 三点保文件序 | **✅ 已落地（役24，ADR-25）** | engine.mbt + parser_slice.mbt | 双坏语句 `errors.length()==2` 行序正确（钉）；业务错后续语句照出（钉）；116/116 | C-05 |
| R-06 | **nil 标记验形**：~~显式标记~~ API 不变约束下 in-band 通道保留，物化层验形双门（`len==0 && data[offset]!='('` → ValidationErr）；构造点唯一（pop_bnode_prop） | **✅ 已落地（役24，ADR-25）** | materialize_n3.mbt + actions.mbt 注释 | 人为事故零长 span 报错（钉）；空集合 rdf:nil 照常（钉） | C-06 |
| R-07 | **证据面补齐**：三 runner 双判（主判定链 + 影子扫描）；绝对计数钉（316/75/205/13）；N3Tests skip 名单 + 桶闭合；examples 升格 pinned | **✅ 已落地（役25，ADR-23）** | 三个 `*_suite_wbtest.mbt` | 加/删文件即红（演练过）；影子缺口基线冻结（5/0/123/13） | C-07、C-16、C-17 |
| R-08 | **公共面收窄**：FSM 机械全降包内（生成件经 emit.mbt 模板 `priv` 化再生；用户层 `N3ActionsImpl`/Slot 族手降；`N3Engine`/`N3LexerAdapter` 字段级 `priv`）；mbti 只留入口（Engine/SliceParser/Materializer/Serializer）+ 数据面（QuadSpan/N3PendingQuad/PredKind/N3Event/N3Dialect/LexerSource/ErrOut）；题2=B（零外部消费者 + 扩展面外部本不可达） | **✅ 已落地（役28，ADR-28）** | emit.mbt + lexer_adapter/actions/types + `moon info` 对 diff | mbti `pub` 55→29 行；0 warning；329/329 | C-08 |
| R-09 | **清账**：删死字段/死 helper/未用导入；修 4×`starts_with`、未用 `self`、2 处多余 trait bound | 建议 | 见 ctx.md R-09 锚点表 | `moon check` 0 warning | C-09 |
| R-10 | **重命名**（原子）：`pver/bver/iver → prefix_version/base_version/iri_version`；`fr → frame`；`Hooks → N3ActionsImpl`（或去 trait 化）；`mat_*` 测试辅助随测试归位改名 | **✅ 已落地（役27a fr + 役28 余项，经表源再生）** | 本包 types/materialize/parser_slice/tests + `.mbti` 同笔 | `moon info` diff 只含预期重命名 | C-10 |
| R-11 | **测试归位**：`materialize_n3.mbt`/`serialize_n3.mbt` 的内联 test 移入 `_wbtest.mbt`；`mat_*` 辅助抽到测试支持文件 | 建议 | 新建 `materialize_n3_wbtest.mbt` 等 | 生产文件只剩实现；`moon test` 计数不减 | C-11 |
| R-12 | **文档三件**：新增 `gen_n3v2/ARCHITECTURE.md`（一页：五层图 + 生成链 + 不变量 + 术语表 + 预留位清单）；修 `guides/n3` 的 `@gen_n3`/`SliceParser`；ADR 补役21 条目（提交 `7630bf2`，或注明归 `src/rdf` 卷） | 建议 | 三处 md | 文档与 `.mbti`/代码名一致 | C-12 |
| R-13 | **ctx 分组**：组清方法形式落地（题5=A，表平铺生成器零改）——`clear_annotation`（四件套；settle/begin_record/recover 三消费点）+ `clear_path`（src/tail/pend 三槽；四发射点）；keywords/directive 零成组清账不立项；字段分节 B 留账 | **✅ 已落地（役28，ADR-28）** | engine.mbt ctx 方法区 + actions.mbt | 清账清单按组表达；116/116；0 warning | C-13、I-6 |
| R-14 | **状态爆炸治理（生成器侧）**：由子 FSM 自动组合交叉状态，替代手列 55 态；或混合架构（语句核心表驱动 + 递归结构子自动机）。量化基座已落 §10（役30a）：交叉族 36 态/232 行，求积上限 61% | 立案 | `src/fsm` + `src/rdf/n3gen` | 新增特性不再乘性改表 | C-14、§10 |
| R-15 | **单一实现**：数值/布尔识别合并为共享 helper（adapter/校验/物化同源） | **✅ 已落地（役29，ADR-29）**：`gen_nquads/numeric.mbt`（`is_numeric_span` + `is_boolean_word`，两包公共依赖故落此；账面原建议 n3v2 types.mbt 不成立——trig 有字节孪生件）；n3v2/trig 八消费点三面收编；`bool_at` ×2 删除；展开件 expand_* 留驻各物化层 | gen_nquads/numeric.mbt + 两包 adapter/parser_slice/materialize 六件 | `rg "has_digit" src` 全仓单点；数值/布尔正负例套件不变（357/316/75） | C-15 |
| R-16 | **影子缺口修口**：N3/cwm 内建前缀预绑定（或校验层方言豁免）+ `<=`/`=>` raw 谓词 validate_pred 白名单；清零后影子钉升 0 并考虑升格主判定 | 立案（役25） | parser_slice validate_* | strict-gap 5/0/123/13 → 0/0/0/0；校验层进主判定链 | C-16、C-17 |

**依赖序（执行建议，与 `todo.md` §4 战役路线一致）**：R-07（可并行）∥ R-02 →（R-03 / R-01）→
（R-05 / R-06）→（R-09 / R-12）→（R-10 / R-11）→（R-13 / R-08）；R-04 / R-14 / R-15 另役。
理由：R-02 决定"效果面"落点，R-01/R-03 决定"表权威"，两者不改，后面的清理会建在双事实源上。

---

## 9. 验收口径（命令 + 当前数字）

```sh
# 包内（嵌套仓）
cd /home/thy/moonttl/src/ttl
moon check src/gen_n3v2          # 目标：0 error / 0 warning（当前 12：4×starts_with、
                                 # mat_* 2、interpret 隐式提升（役22 已知）、trait bound、
                                 # to_owned、bench、name、self——R-09 清）
moon test src/gen_n3v2           # 目标：≥111/111（当前 116/116，役24 +5 钉）
moon info && moon fmt            # .mbti diff 必须只含预期项

# 生成链（外层仓）
cd /home/thy/moonttl
moon test src/rdf/n3gen          # G1–G9；G9 = 黄金门 + 强幂等
```

套件判据（当前，役25 双判钉后）：rdf-turtle 316/316（pin，strict-gap 5）、rdf12-turtle 75/75
（pin，`scalar_only`，strict-gap 0）、N3Tests `neg 23ok/0miss` + `pos+eval 205clean/0mat-only/
0parse-fail` + skip 名单冻结 + 桶闭合 + 影子 strict-gap 123、examples 13 文件桶闭合
A13/B0/C0 + 影子 strict-gap 13。R-01 专项：`grep -c "ctx.state = " actions.mbt` = 3（全带 [R-03-N] 锚）。

改动后必查：`emits.length == quads.length`（正例，I-3）；`neg_miss == 0`；`pos_parse_fail == 0`；`pos_mat_only == 0`。

---

## 10. 状态爆炸实测与增长模型（役30a，R-14 量化基座）

**结论先行**：384 行转移中 **232 行（60%）是"机制 × 语境窗"求积的手列产物**；
手列模式下每开一个新语境窗 ≈ **+7~11 态 +34~75 行**，每加一个多窗特性 ≈ **+2 态/窗 +6~15 行/窗**。
本节全部数字可由下列命令复算（验收口径）。

### 10.1 基线与族分布

```sh
cd /home/thy/moonttl/src/rdf/n3gen
grep -c '^\[\[states\]\]' n3v2_base.toml        # 55 态
grep -c '^\[\[events\]\]'  n3v2_base.toml        # 41 事件
grep -c '^\[\[transitions\]\]' n3v2_trans.toml   # 384 转移行
```

族分布（按状态名前缀归族；`from` 归族计行）：

| 族 | 态 | 行 | 行/态 | 组成（机制分解见 §10.2） |
|---|---|---|---|---|
| Core | 17 | 142 | 8.4 | 顶层指令 7 + 语句核心 7 + is/of 顶层 2 + 尾件 1 |
| Formula | 11 | 75 | 6.8 | 公式 `{…}` 窗：核心 4 + is/of 2 + 量化 3 + 路径 2 |
| SubjTrail | 6 | 39 | 6.5 | 路径×主位：顶层 3 + 公式 3 |
| Bnp | 7 | 34 | 4.9 | bnp `[…]` 窗：核心 3 + is/of 2 + id 2 |
| Annot | 4 | 27 | 6.8 | 注解体 `{| |}` 窗（特性本体） |
| List | 2 | 27 | 13.5 | 集合 `(…)` 窗本体 |
| Path | 2 | 15 | 7.5 | 路径×宾位·顶层 |
| ListPath | 2 | 15 | 7.5 | 路径×集合窗 |
| ObjTrail | 2 | 7 | 3.5 | 路径×宾位基动词 |
| Quant | 2 | 3 | 1.5 | 量化×顶层窗（本体位） |
| **合计** | **55** | **384** | 7.0 | |

复算命令（块作用域解析，防 `name =` 误吸 events/actions 段）：

```sh
python3 - << 'EOF'
import re, collections
base = open('/home/thy/moonttl/src/rdf/n3gen/n3v2_base.toml', encoding='utf-8').read()
blocks = re.findall(r'^\[\[(states|events)\]\]\n(.*?)(?=^\[\[|\Z)', base, re.M | re.S)
agg = collections.defaultdict(str)
for t, c in blocks: agg[t] += c
states = re.findall(r'name = "([A-Za-z]+)"', agg["states"])
fam_order = ["Formula","Bnp","SubjTrail","Annot","Quant","Path","ListPath","List","ObjTrail"]
fam = lambda n: next((f for f in fam_order if n.startswith(f)), "Core")
trans = open('/home/thy/moonttl/src/rdf/n3gen/n3v2_trans.toml', encoding='utf-8').read()
cs, ct = collections.Counter(map(fam, states)), collections.Counter(map(fam, re.findall(r'^from = "(\w+)"', trans, re.M)))
for f in fam_order + ["Core"]: print(f, cs[f], ct[f])
print("TOTAL", sum(cs.values()), sum(ct.values()))
EOF
```

**交叉族口径**（与 todo 事实确认表一致）：交叉族态 **36/55 = 65%**（`Formula*` 11、`Bnp*` 7、
`SubjTrail*` 6、`Annot*` 4、`Quant*` 2、`Path*` 2、`ListPath*` 2、`List*` 2）；交叉族转移
**232/384 = 60%**（上列前七族行之和，`Quant*` 顶层 3 行为本体接线行不计入）。最热从态：
`FormulaExpectPredicate` 与 `ExpectPredicate` 各 18 行——谓词位是最大乘性热点。

### 10.2 机制 × 语境窗矩阵（态数，按名可复算）

| 机制 | 顶层 | bnp `[…]` | 公式 `{…}` | 集合 `(…)` | 注解 `{| |}` | 态计 |
|---|---|---|---|---|---|---|
| 指令（@prefix/@base/@version/@keywords） | 7 | — | 1（指令头） | — | — | 8 |
| 语句核心（主/谓/宾/动词链） | 7 | 3 | 4 | — | — | 14 |
| is/of 罩内性质 | 2 | 2 | 2 | — | — | 6 |
| 量化 ∀∃ | 2 | — | 2 | — | — | 4 |
| 路径链 `!` `^` | 7（主 3 + 宾 4） | — | 5（主 3 + 宾 2） | 2 | — | 14 |
| id `[[…]]` | — | 2 | — | — | — | 2 |
| 注解本体 | — | — | — | — | 4 | 4 |
| 集合本体 | — | — | — | 2 | — | 2 |
| 尾件 `~` 标签 | 1 | — | — | — | — | 1 |
| **列计（=窗规模）** | **26** | **7** | **14** | **4** | **4** | **55** |

读法：窗规模 = 该窗承载的机制镜像之和。公式窗 11 态（Formula 族）是最大单窗；
bnp 窗 7 态次之。**新窗的入场价 = 核心镜像 3~4 态起步**，之后每个多窗机制再各乘一次。

### 10.3 历史每特性成本（git 可复算点 + 台账引用）

```sh
cd /home/thy/moonttl/src/ttl
git show 50c72d9:src/n3gen/n3_trans.toml   | grep -c '^\[\[transitions\]\]'  # 376（09-09 录14 表即文件）
git show b39136c:src/n3gen/n3v2_trans.toml | grep -c '^\[\[transitions\]\]'  # 384（09-10 录16 v2 收官，至今未变）
```

| 时点 | 役 | 特性 | Δ态 | Δ行 | 证据级 |
|---|---|---|---|---|---|
| 09-09 | 录14 | v1 表即文件（数组→TOML，零新特性） | — | 376 封存 | git 可复算 |
| 09-10 | 录16 | id 形 `[[…]]`（B 桶，bnp 窗） | +2（BnpExpectIdNode/BnpIdAfterClose） | 376→384 | git 可复算 |
| 台账 | 录10 | 词位扩展（谓词位 ×~6） | 0 | +35（243→278，数组时代） | 台账引用 |
| 台账 | 录12 | is/of 罩内（bnp+公式两窗） | +4 | +12 | 台账引用 |
| 台账 | 录13 | 量化（顶层+公式两窗，含指令头） | +5 | +13 | 台账引用 |

> v2 两张表自录16 一次封版（外层仓单提交 `7630bf2`），录10-13 为 v1 数组时代，无逐役 git 差可引——
> 以台账引用为证；376/384 两锚点 git 可复算。

### 10.4 外推公式与代入示例

特性 F 在语境位集 W(F)（窗 × 语法位）上合法时：

```
Δ态(F) = Σ_{w∈W(F)} m(F, w)      # m = 机制 F 在语境位 w 的镜像态数
Δ行(F) ≈ Σ_{w∈W(F)} r(F, w)      # r = 接线行数，实测 r/m ≈ 1.5~7（族表 行/态 列）
```

机制单价（录12/13/16 实测校准）：

| 机制 | 新开一窗典型成本 | 校准出处 |
|---|---|---|
| is/of | +2 态 +6 行 | 录12（两窗合 +4 态 +12 行） |
| 量化 | +2~3 态 +6~7 行 | 录13（两窗合 +5 态 +13 行，公式窗含指令头） |
| id | +2 态 +4 行 | 录16 B 桶 |
| 路径链 | +2~3 态 +7~15 行 | 现状：ObjTrail 2/7、ListPath 2/15 |
| 新 term-kind 进谓词位 | 0 态 +~6 行/位 | 录10（6 位 +35 行） |
| **新语句窗（新壳类型）** | **+7~11 态 +34~75 行** | 窗对照：bnp 7/34、公式 11/75 |

代入示例：

1. R-16 前缀预绑定（校验层动作，非表特性）：Δ态=0，Δ行=0——**不是所有特性都乘窗**，反例对照。
2. is/of 开注解体窗：+2 态 +6 行 → 57 态 / 390 行。
3. `<< >>` 嵌套引用升级为完整语句窗：核心 3 + is/of 2 + 量化 2~3 + 路径 2 ≈ **+10~11 态 +60~75 行** → 65 态 / ~455 行。
4. 新谓词位 term-kind ×3 窗：+0 态 +~18 行。

### 10.5 增长结论（30b 选型的量化依据）

- 当前 384 行中 **232 行（60%）为求积产物** → 生成器侧组合（方案 A）的理论压缩上限 ≈ 61%（232+3 量化接线）。
- 手列模式的边际成本：**每新语境窗 ≈ +10 态 +50~80 行**（示例 3）；**每多窗特性 ≈ +2 态/窗 +6~15 行/窗**。
- W3C N3 剩余特性（R-16）之外，方言演化（注解体嵌套、`<< >>` 完整化）按"每窗一乘"增长，
  与 I-6/A-2 的声明面缺口（`N3StateDef` 无嵌套元数据）叠加——机制选型见役30 ADR（30b）。

---

## 11. 演进序（P 级映射）

- **P0（低风险高收益）**：R-02（定案）、R-03、R-05、R-07、R-09。
- **P1（结构性）**：R-01、R-06、R-08、R-10、R-11、R-12、R-13——✅ 全清（役23-28）。
- **P2（长期）**：R-04（长期方言感知词法器）、R-14。

另记（非整改、需知情）：生成本包的包名仍为 `gen_n3v2`（`pkg.generated.mbti` 头），
用户指南写 `gen_n3`——R-12 一并处理；外层仓 `src/fsm/codegen.mbt`、`prune.mbt` 有未提交改动（役21 收尾）。

## 12. 可达性判据与表外入口登记（役31 / ADR-31）

**可达源三源**（G11 判据；缺一即假红）：

1. **表边** `to = "X"`（compose 已把子机模板 `$param` 展开为真名）；
2. **表行 `state:X` 参数**（`action_args` 携带的开帧 `ret_state` → 入帧 → 运行时经
   `ctx.state = frame.ret_state` 兑现；n3v2 侧 `actions.mbt:172`）；
3. **`[[state_entries]]` 手写锚点登记**（可选段，缺省 = 空）：

```toml
[[state_entries]]
state  = "BnpIdAfterClose"                       # 必须是已声明态
anchor = "src/ttl/src/gen_n3v2/actions.mbt:200"  # file:line（首版只形检）
note   = "set_id_subject 改写 frame.ret_state；pop_bnode_prop(:172) 兑现"
```

**门位**（两门）：

- **G11 可达性门**：`src/rdf/n3gen/validate.mbt` 的 `n3_check_reachable`（门序末位）；
  三源之外才报"真不可达"；guard 按无条件边保守近似。
- **G13 锚点登记门**（役31 step2）：`src/rdf/n3gen/n3gen_test.mbt`——
  对每条登记做「文件存在 + 行号在界内 + 该行含 `ctx.state` / `frame.ret_state` / 该条目 state 名」轻校验，
  防**登记漂移**（登记说"这里写 state"，那行已改作他用而 G11 仍假绿）。探针：改错任一 anchor 行号 → G13 必红。

**当前登记册**（3 条）：

| state（**表侧名**） | anchor | 性质 |
|---|---|---|
| `BnpIdAfterClose` | `actions.mbt:200` | 唯一表外入口（`frame.ret_state` 写状态字面量） |
| `ExpectDotOrGraph` | `actions.mbt:529` | 直写既有态（表边亦可达；登记用于防写点漂移） |
| `ExpectDotOrGraph` | `actions.mbt:719` | 同上 |

⚠ **命名口径**：登记册用**表侧名**（无 `N3` 前缀，如 `ExpectDotOrGraph`），
而代码里是生成名（`N3ExpectDotOrGraph`）——首版误填生成名时 G11 当场以
"登记了未声明态"咬住（2026-09-12 实证）。

另有两点**不是种子**，但属同一机制位，登记册 note 中说明即可：
`actions.mbt:172`（`ctx.state = frame.ret_state` 帧兑现）、`actions.mbt:976`（`frame.ret_state = ret_state` 参数透传）。

**`terminal_states`（可选 meta 键；ADR-31 前置 B）**：

```toml
[meta]
terminal_states = ["<干净终局态>", ...]   # 可选；缺省 = 空 = 旧口径
```

- **死态判据**：`可达 ∧ 无出边 ∧ 未声明为终止态` → 报 `G11: 死态 [...]（可达、无出边、未声明 terminal_states）`；
- 名字必须**已声明**（形检，防 typo 让豁免失效）；
- **现状（2026-09-12 实测）**：当前表**零死态**，未声明也不报——该键作为前置保留；
- 制度位对应 `src/fsm/analyze.mbt` 的 `dead_states`（其 `terminal_states` 兜底同义）。

**顺序前置（ADR-31 前置 A）**：模板 `$param` 必须**先展开再建边**——由 `n3gen_build` 的固定顺序
`parse → compose → validate → emit`（`emit.mbt:1287/1291`）保证；`validate.mbt` 另有显式门
"子机标记未展开（须先过 n3gen_compose）"。

**step3 探针（验收留痕）**：删掉 `ExpectTildeEnd` 的 7 条出行 →
G11 报 `死态 [ExpectTildeEnd]`；在同一探针态下声明 `terminal_states = ["ExpectTildeEnd"]` →
死态报警消失（豁免生效）；还原 → `moon test src/rdf/n3gen` **11/11**。

**分级（step4 落地，ADR-31 §3）——警告级 + 显式钳制开关**：

- 实现拆两层：`n3_reachability_report(state_names, seeds, terminals, trans) -> (不可达, 死态)`
  **纯函数**（无 TOML 夹具即可单测）+ `n3_check_reachable` 包装（形检 / 种子装配 / 分级）。
- **形检 = 错误级**（配置 typo 直接拒）：登记 state 未声明、`anchor` 非 `file:line`、`terminal_states` 未声明态。
- **可达性发现 = 警告级**（首版）：命中时打印
  `G11(warn): …（ADR-31 首版警告级；无假报后翻 n3_g11_strict=true 钳为错误级）`，**不阻断构建/生成**。
- **钳制开关**：`let n3_g11_strict : Bool = false`（`validate.mbt` 顶部）；
  跑满 30c/30d 与四套件**无假报**后翻 `true` → 同一发现改走 `Err`（阻断）。
- **单测**（`validate.mbt` 内联，零夹具）：三源种子命中 / 死态判定 / `terminal_states` 豁免 / 空源全不可达。
- **step4 探针（验收留痕）**：删 `ExpectTildeEnd` 7 条出行 → 打印
  `G11(warn): 死态 [ExpectTildeEnd]…`，**构建不阻断**（唯一红是 G9 字节对拍，因行被删）；
  还原 → `moon test src/rdf/n3gen` **12/12**。

**源件关系**：`src/fsm/analyze.mbt` 仅借 BFS 骨架——其"只按表边建边"的输入假设**被 ADR-31 否决**
（该源件当前无调用者，且未建模手写写入态）。
