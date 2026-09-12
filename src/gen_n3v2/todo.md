# gen_n3v2 待办与战役路线（todo）

版本：v1.0.0（2026-09-11 立卷）

卷面分工（四份文件各管一件事，别互相抄）：

- `spec.md` = 结构事实 + 已定口径 + **C 台账**（冲突写实）+ **R 台账**（整改裁决）。
- `ctx.md` = 每项整改的工作上下文（锚点、证据、动作、验收、风险、待裁题）。
- `adr.md` = 历史 ADR（讲"为什么"）。
- **本文件** = 做什么、按什么序、什么算完成；末尾**执行记录**滚动追加。

编号约定：R-xx / C-xx 与 `spec.md` 一一对应；战役号续 `adr.md` 的役21 → 本卷从**役22**起；
ADR 编号随役次（役21 补记 → ADR-21，役22 起每役一条）。

原始底稿：2026-09-11 评审全文（67 行长文）已精简进本文件 §1–§3，证据链在 `spec.md` §7 与 `ctx.md` §4；
底稿副本在 `/tmp/todo.md.review-bak`。

---

## 1. 现状可信面（简化：这些是资产，不动）

1. **分层单一职责**：词法（共享 Lexermoon）→ 事件适配 → 表驱动 `step` → 主循环 → 动作语义 → 组装校验 → 物化 → 序列化；生成物 `n3.mbt` 与用户层边界清晰。
2. **span 唯一身份 + 零拷贝**：`(offset,len)` 是词项与 fresh 节点的身份（路径/集合/公式/倒装全依赖）；`ArrayView[Byte]` 直引 + `arena` append-only 展开。
3. **表驱动 + 生成期门**：384 转移以数据可评审；G1–G8 把引用完整性/唯一性/白名单前移；G9 逐字节黄金门 + 强幂等。
4. **三业务面契约**（Actions / EffectHandler / LoopPolicy）：既是接线点也是扩展维（用户定案，见 §3 R-02）。
5. **外部 oracle 齐备**：W3C turtle 316/316、rdf12 75/75、N3Tests（neg 23ok/0miss、pos+eval 205 clean）、Moon/C 词法 parity；并用 Turtle 套件反向验证 N3 超集。
6. **语义口径一致且有钉**：ADR-002 公式不透明 / 003a 集合单一 BNode / 003b 显式链预留 / 004 变量只记身份 / 005 `=`·`=>`·`<=` 谓词身份 / 006 路径 fresh 链，役5–役20 逐条有测试兜底。
7. **深验单遍**：四门（iri/bnode/tt/literal）在物化构词点就地执行，不做第二遍扫描。
8. **记录纪律**：ADR 留账、skip 留账、缺口计数（负例缺口 3 收口）——同级项目普遍缺失。

---

## 2. 待办：不合理的地方（描述）

按主题四组；每条给出"一句话 + 证据位置"，细节见 `spec.md` §7 / `ctx.md` §4。

### A. 权威性（最要紧：表不再是唯一事实源）

| 编号 | 描述 | 证据 |
|---|---|---|
| C-01 | action 直写 `ctx.state` 3 处，注释自称"唯一例外"；表无法独立推出全部转移 → 可达性/极小化分析失效 | `actions.mbt:166/517/704` |
| C-02 | 效果语义双实现：`engine.next` 手写解释器 vs 生成面 `interpret/dispatch`；`apply_scope` 与 `ctx.reset` 同逻辑两写 → ② 面切点形同虚设 | `engine.mbt:533` ↔ `n3.mbt:2168`；`n3.mbt:2144` ↔ `:218` |

### B. 证据与错误

| 编号 | 描述 | 证据 |
|---|---|---|
| C-05 | 错误通道二制（`last_error` 单槽只报一条 vs `errors` 数组逐条）；多坏语句文件只暴露最后一条；`BusinessFailed` 不复位 ctx | `engine.mbt:322/416/533`；`parser_slice.mbt:545/591` |
| C-07 | 三个套件 runner 全 `lenient=true`，校验层不在 316/75/205 这些数字里；N3Tests 无桶闭合钉、examples 仍 print-only → 清单漂移不报警 | `rdf_suite_wbtest.mbt:114`、`n3tests_suite_wbtest.mbt:40`、`examples_wbtest.mbt:16` |

### C. 清洁度（死码 / 命名 / 测试位置 / 重复实现）

| 编号 | 描述 | 证据 |
|---|---|---|
| C-03 | 引擎归位点做词法/语法重分类（`KeywordA→PrefName` 依 ctx 状态改判；`this` 4 字节硬编码）→ 与"决策在表"矛盾，关键词真相散三处 | `engine.mbt:190/223/170`；`lexer_adapter.mbt:153` |
| C-09 | 11 个编译警告 + 死字段 `variable_name`/`rule_side`（永不读）、`iri_upcast`（只写不自增）、`mat_graph`/`mat_has_graph`、未用 `bench` 导入 | `moon check`；`n3.mbt:161/166/167` |
| C-10 | 命名违反自家宪法：`pver/bver/iver`、`fr`、`mat_*`、`Hooks`（实为 action 语义体） | `types.mbt:50`、`actions.mbt:14` |
| C-11 | 测试位置：`materialize_n3.mbt` 内联 23 个 test + 约 500 行辅助；`serialize_n3.mbt` 内联 4 个 | `materialize_n3.mbt:1380` 起 |
| C-15 | 数值/布尔识别两套实现（adapter/校验 vs 物化） | `lexer_adapter.mbt:172`、`materialize_n3.mbt:512/992` |
| C-16 | 前缀预绑定缺位：validate_prefname "先声明"门 vs N3/cwm 内建前缀（log:/string:/... 不声明即用）+ 隐式空前缀——影子缺口 486 处主因，官方正例 good_prefix.n3 也翻 | 役25 影子扫描 STRICT-GAP 名单 |
| C-17 | `<=` raw 谓词（ADR-005 操作符=谓词身份）被 validate_pred "IRI must be wrapped in <>" 拒——影子缺口次因 2 处 | `rdf_suite_wbtest` 影子 extras-10 |

### D. 结构与文档

| 编号 | 描述 | 证据 |
|---|---|---|
| C-04 | 词法边界欠账堆在适配层与引擎层（`[]`/`?x`/`@kw:`/`<-` 合并拆字 + 引擎合成 `Dot/Comma/Semicolon`）→ 一次词法改动四处同步（ADR-18 `^` 门即实证） | `lexer_adapter.mbt:339` 起；`engine.mbt:83` |
| C-06 | 零长 span 被重载为 `rdf:nil` 标记 → 事故静默变词表 IRI 而非报错 | `materialize_n3.mbt:703/858`；`actions.mbt:152` |
| C-08 | 公共面过宽：`.mbti` 暴露 29 字段的 `N3Context`、48 方法的 `N3Actions`、三个 trait、`N3Engine` → 内部重构即破坏性变更 | `pkg.generated.mbti`（38 个 `pub`） |
| C-12 | 文档漂移：guides 11 处 `@gen_n3`/`SliceParser`；ADR 停在 ADR-20 而代码已到役21；无稳定架构页 | `guides/n3/README.md:3`、`syntax.md:49`；提交 `7630bf2` |
| C-13 | ctx 是 6 特性轴合成的大对象（29 字段 + 3 死字段）→ reset/recover 清账清单靠人记 | `n3.mbt:140-170`；`n3v2_base.toml:440-468` |
| C-14 | 状态爆炸：55 态含 `FormulaX`/`QuantX`/`SubjTrailX`/`ListPathX` 交叉族（手列）→ 加特性乘性增长 | `n3v2_base.toml` states 段 |

---

## 3. 整理建议（R 台账速览）

状态：**[定案]** 用户已裁 / **[建议]** 待裁 / **[立案]** 需另役。完整动作/验收/风险见 `spec.md` §8 + `ctx.md` §4。

| R | 一句话建议 | 状态 | 归属役 |
|---|---|---|---|
| R-02 | 接活效果面：② 面保留为扩展维，`interpret` 成唯一解释器，`engine.next` 调它；`apply_scope` 与 `ctx.reset` 合一；`take_pending_quad` 下沉为 ctx 级函数；emit 侧加接活钉 | **[✅ 已落地 役22]** | — |
| R-01 | 状态权威回归表：~~新增状态改写承载迁走三处直写~~ **役23 翻案**：迁表不可达（链形异判/Err 短路），落地=机制收敛（id 特例前移刻帧 + pop 无条件读帧），SetState 不立项（零可行实例） | [✅ 役23] | 役23 |
| R-03 | 归位点台账化：清单 §5.1 落地（A3+B4+C 裁决）；~~能上表的改表行承载~~ 翻案：KeywordA 降级/this 门系事件重分类，出表模型，登记不上表；关键词三处正交已收敛（C-03 误诊修正） | [✅ 役23] | 役23 |
| R-05 | 错误累积：`error_spans` 数组落地 + BusinessFailed 复位续解（recover 拆层）+ drain 三点保文件序 | [✅ 役24] | 役24 |
| R-06 | nil 标记：~~显式标记~~ 验形门落地（零长 span 保留 in-band 通道 + `data[offset]=='('` 可验形 + 事故零长报错） | [✅ 役24] | 役24 |
| R-07 | 证据面补齐：三 runner 双判（严格 + 宽容）；N3Tests/examples 加桶闭合钉 | **[✅ 已落地 役25]** | — |
| R-09 | 清账：0 warning、删死字段/死 helper/未用导入（死字段须先改表再生） | ✅ 已落地（役26，30 警告全模块清零） | 役26 |
| R-12 | 文档三件：`ARCHITECTURE.md`（一页）+ 修 guides + 补役21 ADR 条目 | ✅ 已落地（役26；役21 跨卷注记） | 役26 |
| R-10 | 重命名（原子）：`pver/bver/iver → prefix_version/base_version/iri_version`；`fr → frame`；`Hooks → N3ActionsImpl` | ✅（役27a fr 71 + 役28 pver 族 76 + Hooks 102 + trig 同笔 66） | 役27a/28 |
| R-11 | 测试归位：内联 test 移入 `_wbtest.mbt`，辅助抽测试支持文件 | ✅ 已落地（役27a：27 test 迁双新件，mbti 零 diff） | 役27a |
| R-13 | ctx 分组：directive / path / inversion / annotation / keywords 五组，reset 随组 | ✅（役28 组清形式，题5=A；B 留账） | 役28 |
| R-08 | 公共面收窄：FSM 机械降包内可见，`.mbti` 只留入口与数据面（扩展维可见性先裁） | ✅（役28，题2=B；mbti 55→29 pub 行） | 役28 |
| R-04 | 词法收口：合并/拆字上移词法层（方言感知）；短期先做补偿点单点台账 + parity 钉 | ✅ 短期（役29：台账头注六点地图+钉面清单）；长期方言感知词法器 [立案] | 役29 |
| R-15 | 数值/布尔单一实现（随 R-04） | ✅（役29：gen_nquads/numeric.mbt 单点，八消费点两包三面收编，bool_at ×2 删） | 役29 |
| R-16 | 前缀预绑定 + 操作符谓词校验修口：N3/cwm 内建前缀不声明即用（预绑定词表或校验豁免）、`<=`/`=>` raw 谓词过 validate_pred 白名单 | [立案]（役25 影子缺口立项） | 役29 |
| R-14 | 状态爆炸治理：子 FSM 自动组合交叉状态（**落地=构建期 compose 求积**），混合架构（B）已否决 | **[✅ 完成·役30（30a–30f）]** | 役30 |

---

## 4. 战役路线（役22 → 役31）

总图（`→` = 前置；`∥` = 可并行）：

```
役25 证据面 ∥ 役22 效果面接活 ─┬→ 役23 表权威 ─┐
                              ├→ 役24 错误与 nil ┴→ 役27 命名与测试归位 → 役28 ctx 分组与公共面
                              └→ 役26 清账与文档                      → 役29 词法收口 → 役30 状态爆炸治理
```

统一验收（每役都跑，缺一不可）：

```sh
cd /home/thy/moonttl && moon test src/rdf/n3gen    # 动表才需要：G1–G9 绿，再 cp 交付
cd /home/thy/moonttl/src/ttl
moon check src/gen_n3v2        # 0 error / 0 warning（役26 起强制）
moon test src/gen_n3v2         # ≥111/111；套件四项数字不变
moon info && moon fmt          # .mbti diff 逐行审
```

### 役22 效果面接活（R-02）**[✅ 已完成 2026-09-11]** — P0（ADR-22：interpret 唯一解释器；翻案=path_obj_close 三发 Sequence → emit_queue 下沉 N3Context；题1=A 落地，题2 留役28）

- 范围：`emit.mbt:1083` 套装 + `engine.mbt:533` + `n3.mbt` 再生；`handle_*` 精简（`continue/done` 并入默认）；`snapshot`/`apply_scope` 归位到 `N3Context`；`take_pending_quad`（倒装 + 注解壳交换）下沉为 ctx 级函数。
- 交付：唯一解释器；emit 点成为真实观测/容灾挂点；`N3EffectHandler` 有 impl + 调用点（不再零引用）。
- 验收：`rg "N3EffectHandler" src/ttl/src/gen_n3v2` 出现 impl 与调用点；役6/役8 倒装与注解钉全绿；套件数字不变。
- 风险：`take_pending_quad` 迁移若错，静默产生错主语（役8/役18 踩过）——先探针后落地。
- 待裁：`ctx.md` §6 题 1（A 全控 / B 观察者）+ 题 2（扩展维是否 `pub`）。

### 役23 表权威回归（R-01 + R-03）**[✅ 已完成 2026-09-11]** — P0+P1（ADR-24：R-01 翻案定案=机制收敛（id 特例前移 set_id_subject 刻帧 + pop 无条件读帧，直写 3 处全带 [R-03-N] 锚）；SetState 不立项（链形异判/Err 短路零可行实例）；R-03 清单 spec §5.1 落地（A3+B4+C，事件重分类出表模型裁决）；C-03 写实修正（bool_at 误诊除名，三处正交已收敛）；题3=机制收敛+登记，零生成链改动）

- 范围：~~状态改写承载~~ 机制收敛 + 归位点台账化。
- 验收：`grep -c "ctx.state = " actions.mbt` = 3（原"为空"不可达——动态上下文依赖是 FSM 边界本质）；清单只减不增；111/111；`bad-*-05` 仍拒。
- 结果：actions.mbt +25/−11 纯用户层；n3.mbt 零 diff 无再生；G9+fmt 幂等+mbti 零差。

### 役24 错误面与 nil 语义（R-05 + R-06）**[✅ 已完成 2026-09-11]** — P0+P1（ADR-25：题4=A API 不变；R-05 = error_spans 累积 + BusinessFailed 复位续解（recover 拆 cleanup 层）+ drain 三点（入口/Some(Err)/终态）保文件序；R-06 = nil 验形门（零长 span in-band 通道保留 + `data[offset]=='('` 验形 + 事故零长 ValidationErr）；五钉 +124 行；零生成链改动）

- 范围：错误累积 + 失败复位 + nil 验形。
- 验收：双坏语句 `errors.length()==2` 且行序正确 ✓；业务错后续语句照出 ✓；人为事故零长 span 报错 ✓；空集合仍出 rdf:nil ✓；116/116；套件四项不变。
- 结果：engine/parser_slice/materialize/actions 五文件 +215/−31；G9+fmt 幂等；mbti diff = R-05 设计面。

### 役25 证据面补齐（R-07）**[✅ 已完成 2026-09-11]** — P0（ADR-23：主判定链+影子扫描双判、绝对计数钉 316/75/205/13、skip 名单+桶闭合钉；影子缺口两族立项 C-16/C-17 → R-16 役29；题6=A 落地）

- 范围：三 runner 双判（严格判定 + 宽容扫描）；N3Tests 加 `pos_ok` 与 skip 名单钉；examples 加桶闭合钉。
- 验收：往 `rdf-tests` 加一个文件 → 测试必须红；去掉 → 绿；校验层进入判定链。
- 风险：双判会暴露真实校验缺口——真缺口另立小役，不许为绿回退 `lenient`。
- 待裁：`ctx.md` §6 题 6（双判成本）。

### 役26 清账与文档三件（R-09 + R-12）— ✅ 2026-09-11

- 结果：`moon check` **0 warning**（30 条全模块清零：17 unused_package 五包 moon.pkg / 3 unused_trait_bound
  去界 `impl[L]`+`fn[L]`——同 trait 双 impl 块约束须一致 / 6 deprecated——`has_prefix`×4 + `to_owned` +
  `N3EffectHandler::interpret` 限定调用 / 4 unused_value——`mat_graph`/`mat_has_graph` 删、`n3_suite_verdict`
  去 `name` 参、`serialize` 未用 `self`→`_self`）。
- 死字段（先表源再生）：`n3v2_base.toml` 删 `variable_name`/`rule_side` 两行 → n3gen 9/9 → cp `n3.mbt`；
  `RuleSide` 枚举连坐删（types.mbt，ADR-005 语义保留 spec）；`iri_upcast` **活机制**（trans expr + iver
  快照）保留——ctx 表原误列死位，已正名（ARCHITECTURE.md 预留位清单）。
- 文档三件：①`ARCHITECTURE.md` 一页（五层/生成链/I-1..9/术语/预留位清单）；②guides/n3 README 8 处
  `@gen_n3`→`@gen_n3v2` + 3 处 `N3SliceParser` + ctx 字段清单/效果枚举实名/物化 API 实形
  （`N3Materializer::new(data, prefixes, bases=)`）+ syntax.md 分层描述；③adr.md 卷首跨卷注记
  （役21 落 `src/fsm/toml.md`，不重复立条）。
- 附带：spec §1 陈数同步（27 ctx 字段 / 116 测试 / I-6 收敛后状态）；types.mbt 注释 PredKind 副本删。

### 役27 命名与测试归位（R-10 + R-11）— P1，前置：役24 ✅（拆 27a / 27b；**27a ✅ 2026-09-11**）

**勘察（2026-09-11 实测，本包 116/116 / 0 warning / .mbti 406 行·38 pub 项）**：

| 对象 | 计数 | 分布 | 穿生成链？ | 公共面？ |
|---|---|---|---|---|
| `pver` / `bver` / `iver` | 36 / 48 / 28 = **112** | `materialize_n3` 37、`parser_slice` 8、`n3.mbt` 6、`types` 4、`engine_wbtest` 6、`actions` 1 | **是**：表 `n3v2_base.toml:474/479/484` → `n3.mbt:247-249` 字段 / `:271-273` 快照映射 | **是**：`QuadSpan`、`N3PendingQuad` 均 `pub(all)` |
| `Hooks` | **93** | `actions` 91、`engine` 2 | 否 | **是**：`pub struct Hooks` + `Hooks::new` |
| `fr` | **72** | `actions.mbt` 局部帧变量（`list_top(ctx)` 结果） | 否 | 否（局部） |
| `mat_*` + 内联 test | 辅助 **267** + **27 个 test** | `materialize_n3`（23 test + 7 辅助）、`serialize_n3`（4 test） | 否 | 否（私有） |
| 跨包同名 | trig **52 处**（types 2 / materialize_trig 35 / parser_slice 6 / trig 4 / wbtest 5） | `gen_trig` | 是（trig 自己的表） | 是 |

**拆分定案（避免两次 `.mbti` 抖动）**：

- **役27a（零 API 抖动，可立即开工）**：`fr → frame`（72 处局部，`moon ide rename` 按 `--loc` 分批）
  + **R-11 测试归位**（27 个内联 test 迁入新建 `materialize_n3_wbtest.mbt` / `serialize_n3_wbtest.mbt`，
  267 处辅助随迁并改名）：
  - `mat_bytes` / `mat_vs` → **删除并复用** `engine_wbtest.mbt` 已有的 `bytes_of` / `view_str`
    （同包 `_wbtest` 共命名空间，重名即编译错）；
  - 其余辅助改名：`mat_chain → parse_materialize`、`mat_subj → emit_subject`、`mat_obj → emit_object`、
    `off_of → first_offset_of`、`mat_empty → empty_bytes`、`mat_deferred → deferred_files`。
  - **判据（关键）**：`moon info` **零 diff**（证明未碰公共面）+ `moon check` 0 warning +
    `moon test` **116/116** + `moon fmt` 幂等；生产文件（`materialize_n3.mbt` / `serialize_n3.mbt`）只剩实现。
- **27a 执行结果（✅ 2026-09-11）**：`fr → frame` **71 处**（词边界正则一遍；勘察 72 系行/处混计）；
  27 test 迁双新件（materialize_n3_wbtest 538 行 / serialize_n3_wbtest 64 行），生产件 1396/101 行纯实现；
  **命名实落微调**：`mat_bytes→bytes_of` 复用 ✓；`mat_vs` 删 ✓ 但**未直换 view_str**——两者语义不同
  （mat_vs=decode_lossy，view_str=逐字节 to_char，多字节必烂）——先归一 view_str 本体为 decode_lossy
  （ASCII 站点输出不变），再收编；`mat_subj/mat_obj` 收编为 **emit_subject/emit_object 返 String**
  （`mat_vs∘mat_*` 73 组合直吸），另立 `emit_predicate`（32 处 `.predicate` 直取同型）；
  `mat_chain→parse_materialize`、`off_of→first_offset_of` ✓；`mat_empty` 零消费者**亡**（组合收编后
  0-warning 强制内联，未立 empty_bytes）；`mat_deferred` 勘察时已亡（役17 退役）。跨文件消费
  （n3_wbtest 4 处、engine_wbtest 6 处）同笔改。四门全过：mbti 零 diff（fmt 后复验）+ 0 warning +
  116/116 + fmt 幂等；mat_* 旧名残留 = 3 处刻意史注。
- **役27b（并入役28「公共面与命名」，一次抖动）**：
  - `pver/bver/iver → prefix_version / base_version / iri_version`：**改表 3 行 → `moon test src/rdf/n3gen`（G9 落 `n3v2_out.gen`）→ cp 交付 `n3.mbt` → 本包 112 处替换**；顺带定 `N3PendingQuad` 是否降为包内（内部快照，只有 `QuadSpan` 需保留公共字段名）。
  - `Hooks → N3ActionsImpl`（93 处）+ 定其是否继续 `pub`（R-08）；`engine.mbt` 字段 `hooks → actions`（与 `N3Actions` 对齐）。
  - 判据：`.mbti` diff **一次性**只含预期改名与收窄项。
- **待裁（trig）**：同名 52 处 → 建议**同笔改**（宪法：跨包重命名是原子变更；两包 `QuadSpan` 同构，分叉会长期存在）；
  若限缩体量则立 **役27c**，并在本包 `spec.md` 注明「有意分叉」。

**命名建议**：

| 现名 | 建议 | 备选 | 理由 |
|---|---|---|---|
| `pver` / `bver` / `iver` | `prefix_version` / `base_version` / `iri_version` | `prefix_ver` | 文档口径即"账本版本 / 链长快照"；语义自解释 |
| `Hooks` | `N3ActionsImpl` | `N3Hooks` | 它是 `N3Actions` 的实现载体；`Impl` 作类型名后缀不涉保留字（"`impl` 块"才是语言构造） |
| `fr` | `frame` | `slot_frame` | 它是 `Slot` 栈帧，短且不与生成器词表冲突 |
| `mat_*` | 去前缀 + 复用/改名（见 27a） | — | 测试私有，唯一硬约束是同包不重名 |

**边界纪律**：ctx 字段名统一（`kw_a_live` / `is_src` / `is_depth` / `annot_*` 等）**不在本役**，
归役28 的 ctx 分组——避免表改两次。

### 役28 ctx 分组与公共面收窄（R-13 + R-08 **+ 役27b**）— P1 **[✅ 已完成 2026-09-11]**

- 范围：ctx 五子结构（directive / path / inversion / annotation / keywords）；reset 语义随组；公共面逐个判定，`.mbti` 只留入口与数据面。
- 验收：分组后 reset/recover 清账清单按组表达；`.mbti` 行数显著下降且不含 FSM 内部类型；套件不变。
- 风险：分组是否连带改表 schema（跨仓 + 生成器 + G 门）——先裁后动。
- 待裁：`ctx.md` §6 题 5（表是否分节）→ **题5=A 落地、题2=B 落地**（ADR-28）。
- **执行结果**：27b 改名（表 3 行再生 + 本包 70 + Hooks→N3ActionsImpl 102 + hooks→actions；N3PendingQuad 不降——next() 公共载荷）；trig 同笔 66 + 三层表源同笔；R-08 降级（生成件 priv 化再生 + 用户层手降 + 字段级 priv）+ 死码四件清（IRIUpcastEvent/SlotNodeId/Show for N3Event/EffectHandler::snapshot 死套）；R-13 组清 clear_annotation×3 + clear_path×4。**mbti 55→29 pub 行、0 warning、329/329、套件钉全绿、G9 9/9、fmt 幂等**。

### 役29 词法收口与单一实现（R-04 + R-15）— P2 **[✅ 已完成 2026-09-11]**

- 范围：`?x`/`[]`/`@kw:`/`<-`/尾标点上移词法层（方言感知）或先做补偿点单点台账；数值/布尔识别合并为共享 helper；Moon + C 同步。
- 验收：`lexerc_parity_wbtest` 零差；nquads/trig/n3v2 三套件数字不变；该规则全仓一处实现。
- 风险：动共享词法影响三包——先盘依赖面再开役。
- 裁断：单役两件、零 Lexermoon/C 接触。R-15 识别件落 `gen_nquads/numeric.mbt`（非账面
  n3v2 types.mbt——trig 有字节孪生件，`has_digit` 全仓一处强制跨包，gen_nquads 是两包
  公共依赖）；`is_boolean_word` 新增收编六处布尔识别，`bool_at` ×2 删；展开件 expand_*
  留驻各物化层。R-04 短期 = `lexer_adapter.mbt` 头注补偿点六点地图 + 钉面清单，
  engine `normalize_term_span` 回指；**不移 trim**（七臂旗标交织，移动无益于欠账本体）；
  C 侧冻结不动（2026-09-04 分歧口径，电池不含分歧形态）。
- **执行结果**：新件 1 + 收编 12 消费点（n3v2/trig × adapter/parser_slice/materialize）
  + 死件删 2。**parity 零差（对比 72 段 mismatch=0）、nquads 124/124（89+29+27+72）、
  trig 357/357、n3v2 116/116、模块 329/329、0 warning、fmt 幂等、nquads mbti 仅 +2 行**。
  长期方言感知词法器留账 [立案]（R-04 长期半）。

### 役30 状态爆炸治理（R-14）— P2 **[✅ 完成 2026-09-12（30a–30f 收官，ADR-30）]**，前置：外层仓生成器立项（2026-09-12 立项勘察，拆分 30a–30f）

**事实确认（2026-09-12 实测）**：

| 指标 | 值 | 证据（可复算） |
|---|---|---|
| 状态数 | **55** | `grep -c '^\[\[states\]\]' src/rdf/n3gen/n3v2_base.toml` |
| 事件数 | **41** | 同上（`^\[\[events\]\]`） |
| 转移数 | **384** | `grep -c '^\[\[transitions\]\]' src/rdf/n3gen/n3v2_trans.toml` |
| **交叉族态** | **36 / 55 = 65%** | 族分布：`Formula*` 11、`Bnp*` 7、`SubjTrail*` 6、`Annot*` 4、`Quant*` 2、`Path*` 2、`ListPath*` 2、`List*` 2 |
| **交叉族转移** | **232 / 384 = 60%** | `Formula*` 75、`SubjTrail*` 39、`Bnp*` 34、`List*` 27、`Annot*` 27、`Path*` 15、`ListPath*` 15 |
| 声明面缺口 | `N3StateDef = { name, is_initial }` | `src/rdf/n3gen/types.mbt`——**无**嵌套/语境元数据（对比 `src/fsm` 的 `StateMeta.is_nestable/exit_event` 仅到元数据） |

**风险注记修正（重要，原记不成立）**：原写"`emit` 家族被 trig/gen_md 共用"——实测三条生成链彼此独立：

- n3v2 = `src/rdf/n3gen`（自含，`moon.pkg` 只依赖 toml：parse → validate → emit 直产）；
- trig = `src/rdf/domain_to_ir.mbt` → `src/rdf/fsm_out/trig_fsm.toml` → `src/fsm/cmd`（v1 IR + codegen）；
- md = `src/gen_md/gen`（自有编译器）。

→ **役30 改动面 = `src/rdf/n3gen/` + `n3v2_*.toml` + 产物 `n3.mbt` + G9 门**，不牵动 trig / gen_md。

**红线（本役安全阀）**：重构必须**产物逐字节等价**——G9 黄金门即判据。等价期内"手列行"与"组合生成"两份并存，
由 G9 锁等价，**最后一步才删手列行**。

**拆步**：

- **30a 定量与建模**（零代码，半天）：族分布表 + 语境窗计数（每族在几个语境里各写一套态/转移）+ 历史成本
  （役10 +35 行、役13 +5 态、役16 +2 态…按 `git log` 量）+ 外推公式"加一个特性 ≈ +N 态 / +M 转移"；
  落 `spec.md` 新节「状态爆炸实测与增长模型」。验收：数字可由命令复算（命令写进该节）。
- **30b 机制选型（ADR）**：三候选 —— **A** 生成器侧组合（n3gen 增 `compose` 阶段：TOML 声明"子自动机 × 语境窗 × 接线"，
  emit 自动求积）；**B** 混合架构（`{}`/`()`/`[]` 退出扁平表，改递归子机，语句核心仍表驱动）；
  **C** 维持扁平表 + 加分析门（不可达检测 + 规模预算告警），不重构。
  判据：产物等价性 / 改动面 / 新增特性成本曲线 / 回归风险 / 与 `world/macro-spec.spec.md` 的组装口径一致。
  产物 = `adr.md` 新 ADR（含被否方案与被否理由）。
- **30c 探针（最小切片，建议先做）**：取 **`Quant*`（2 态 / 13 转移）** 做原型——TOML 声明"量化窗"子机 + 接线 →
  生成器求积 → **与现状逐字节相同**（G9 直接给判据）。若 A 走不通，立即转 **C**（一天可收，不亏）。
  **✅ 已完成**（`quant` 机器 4 段 + 实例 `quant_top` / `quant_formula`；G9 字节等价）。
- **30d 全量迁移（仅 A 通过才做）**：族序 `Bnp → List → Annot → Path → SubjTrail → Formula`，一族一步；
  每步 G9 字节等价 + 模块 329/329（当前总数）；**最后一步**才删手列行。
  **✅ 2026-09-12 完成**：`bnp_window`(12 段) / `list_window`(5) / `annot_window`(5) / `path_window`(3) /
  `subjtrail_window`(1) / `formula_window`(19) 六族已子机化；本轮补齐**最后两族**——
  `listpath_window`(5 段) 收 `ListPath*` 15 行、`objtrail_window`(3 段) 收 `ObjTrail*` 7 行
  （族入口行留核心块，与既有 idiom 一致）。
  **终局事实**：`n3v2_trans.toml` 非标记行**只剩核心态**（`ExpectSubject/Predicate/Object/VerbOrEnd/VerbOrDot/
  VerbRequired/DirectiveEnd/TildeEnd/DotOrGraph/KeywordsList/IsProp/IsOf` 与指令态）——
  **零手列交叉族**；标记行 59、子机段 57、实例 10。
  **验收**：`moon test src/rdf/n3gen` **12/12**（G9 逐字节等价 ⇒ 求积产物 ≡ 原手列 384 行）、
  `moon test src/rdf` 20/20、子仓 `gen_n3v2` 116/116、`gen_trig` 80/80。
  ⚠ 附带修复：G8 负例门的**手术锚点**原指向 `trans` 里的 ListPath 行，迁移后锚点失配 ⇒ replace 静默变成
  no-op ⇒ 负例门假绿。新增 `n3_neg_patch(base, trans, old, new)`（两文件都试、命中即改）并改 G8 三处探针——
  与 G13 的"锚点漂移"同源教训：**探针锚点必须可证伪**。
- **30e 门扩展**：新增 **G10 族声明装配门**（子机 / 语境窗 / 接线引用完整性 + 求积唯一性）与
  **G11 可达性门**。⚠ TOML 契约兼容：新键一律可选、旧文件仍可读、未知键忽略（按 AGENTS「TOML 是持久契约」）。
  **✅ 2026-09-12 完成**：
  - **G11** 已在**役31**完整落地（三源可达 + 死态 + 分级 + 漂移门 G13）；
  - **G10 族声明装配门**（本轮）：判据 = **死段**（`[[submachines]]` 段声明了却无任何
    "赋给该机器的实例"标记接线）+ **死实例**（`[[submachine_instances]]` 实例从未被标记引用）；
    **调用点 = `n3gen_build` 的 compose 之前**（标记行 compose 后即被消费，validate 见不到）；
    实测现状：57 段 / 10 实例 / 59 标记，**死段 0、死实例 0、重复引用 0**。
  - **不重设的门**（避免双设）：标记的实例/机器/段**存在性**归 `n3gen_compose`（未知实例/未知机器/
    bind 键未消费）；**求积唯一性**（展开后 `(from,on)` 不重复）由既有唯一性门在 compose 之后覆盖。
  - **探针实证**：临时加 `bnp_window.ghost_seg` + 未引用实例 `ghost_window` →
    `G10: 死段 [bnp_window.ghost_seg]（…无标记接线）；死实例 [ghost_window]（…无标记引用）`；还原 → 绿。
  - ⚠ 顺序提示：G10 在 `n3gen_build` 里**先于** G1–G8 触发（fail-fast）——若真表出现未接线段，
    其它门的消息会被它遮住（探针期实测到此现象）。

  **⚠ G11 已移交役31**（2026-09-12）：首版门已实测**红**——`moon test src/rdf/n3gen` 9/10，
  报 `G11: 不可达态 [ExpectVerbRequired, BnpIdAfterClose]`，二者皆为**表外入口**（详见下节判据修正与
  `adr.md` **ADR-31**）。**判据未修好之前，G11 不得 pin、compose 侧改动不得入库**。

  **G11 判据修正（2026-09-12，用户指正；ADR-30 原句"移植 `analyze.mbt` 的不可达检测"不足以采信）**：

  - **事实**：`src/fsm/analyze.mbt` 的可达性**只从转移行建边**（`from → to`），且是**警告级**打印
    （`print_analysis_warnings`：不阻断生成；靠 `meta.terminal_states` 兜底"无出边非终止"）。
    更关键：**它当前没有任何调用者**（`grep -rn 'analyze_fsm_paths\|print_analysis_warnings' src/` 除自身与测试零命中）。
  - **直接移植的假红量（实测）**：n3v2 会有 **6 个**声明态被误报不可达——5 个来自**模板占位行**
    （`n3v2_base.toml` 的 `{from = "$directive", to = "$var"},`，9 处含 `$` 占位行），1 个是**手写锚点**
    `N3BnpIdAfterClose`（入口 = `actions.mbt:200` `frame.ret_state = N3BnpIdAfterClose`，兑现在 `:172`）；
    trig 侧同样有 **1 个**（`ExpectVerbRequired`，入口 = 表行 `state:…` 参数 → `open_collection` → 帧 → `ctx.state = fr.ret_state`）。
  - **G11 正确判据 = 三源可达 ∪ + 两前置**：
    1. `to = "X"` **表边**（含**模板行展开后**为真名的那些——5 个量化态即此类）；
    2. 表行 **`state:X` 参数**（`action_args` 携带 → `OpenSlot/open_collection` 入帧 → `:172` 兑现；现表内 **51 处**，n3v2 12 个不同态）；
    3. **手写锚点登记**（`ctx.state = …` 直写 2 处 + `frame.ret_state = …` 改写 2 处，共 4 点：`actions.mbt:172/200/529/719/976`），
       要求每条锚点在表源或 `spec.md` **登记**（state ← 写入点 `file:line` + 一句语义）；
    - 前置 A：`terminal_states` **可选声明**（n3gen 现无此键）——否则"无出边"态被判 dead；
      前置 B：模板 `$param` **先展开再建边**——否则占位态假红。
  - **分级**：三源之外才报"真不可达"（错在表）；G11 首版按**警告**落地（与 analyze 同级），
    跑满一轮（30c/30d 全程）无假报后再**钳为错误**入 G 门。
  - **30c 探针新增金标准用例**：`N3BnpIdAfterClose`（手写锚点）与 `QuantExpectVar` 族（模板占位）
    在**求积前后**都必须判"可达"——这是 compose 不引入假红的最小证据。
- **30f 回灌**：`spec.md`（组合声明面 + 实测节）、`ARCHITECTURE.md`（生成链加 `compose` 阶段）、
  `world/macro-spec.spec.md`（子自动机组装口径）、`ctx.md` / 本卷收口。
  **✅ 2026-09-12 完成**：① `spec.md` 新增 **§10.6 组合声明面（compose schema）**（submachines/instances/标记行三段样例 + 语义纪律 + 门映射）；② `ARCHITECTURE.md` 生成链改`parse → 装配门 → compose → validate → emit` 并加**门清单表**（G10/G11/G12/G13）；③ `world/macro-spec.spec.md` 新增 **§8 子自动机组装：落地实例（n3v2 compose）**（声明面 / 接线 / 求积语义 / 组织纪律 / 规模见证）；④ `ctx.md` 的 **R-14 由 [立案] 转 ✅**（30a–30f 全记录 + 原"emit 家族共用"风险注记纠正 + 钳制待触发项）。

**裁断结果（2026-09-12）**：题7 = **A 构建期 compose**（ADR-30，两硬判据：字节等价可锁 / 零手列交叉族）；
题8 = 探针族取 **`Quant`**（已落地 `quant_top`/`quant_formula`）；题9 = **是**，以"产物字节等价"为唯一判据（G9 逐字节门）；
题10 = **是**，可达性门常设 → 由**役31**承接（三源可达 + 分级 + G13 锚点漂移门）。

**验收（役收 ✅ 2026-09-12）**：新增一个特性只增"子机声明 + 接线"、**零手列交叉态**；
G9 字节等价贯穿 30c/30d（全量迁移后 12/12）；实测终局 **机器 9 族 / 段 57 / 实例 10 / 标记 59 / 非标记行 140**；
`moon test src/rdf/n3gen` 12/12、`src/rdf` 20/20、子仓 `gen_n3v2` 116/116、`gen_trig` 80/80。
（旧口径"模块 329/329"已随测试归位役27a 失效，以四门数字为准。）

---

---

### 役31 可达性门收口（G11；判据 = ADR-31）**[✅ step1–5 完成 2026-09-12（G11 已生效为错误级）]** — P0（**门级前置**），前置：无

**为什么独立成役**：G11 不依赖 compose（A 方案）即可成立（ADR-30 明言"两门独立必做"）；
但它需要一个**独立定案的判据**（ADR-31）与一次**实测校准**（现状表跑一遍），
塞进 30e 会让"探针判据"与"门判据"纠缠。且实测已证明它不是"照抄 analyze.mbt"就能绿的活。

**事实（2026-09-12 实测）**：

- 首版 G11（`src/rdf/n3gen/validate.mbt:479` 起，只按 `trans` 的 `from/to` 建边 + 自初始态 BFS）
  → **n3gen 门 9/10 红**：`G11: 不可达态 [ExpectVerbRequired, BnpIdAfterClose]`。
- 两个假红的入口（均**表外**）：
  - `ExpectVerbRequired` ← 表行 `action_args` 的 `state:…` 参数（现表内 **51 处 / 12 态**）→ `open_collection` 入帧 → `actions.mbt:172` 兑现；
  - `BnpIdAfterClose` ← `actions.mbt:200` 手写改写 `frame.ret_state` → 同点兑现（表内只有出边 `n3v2_trans.toml:550`）。
- 第三类危险源：模板占位行（`n3v2_base.toml` `{from="$directive", to="$var"}`，9 处含 `$`）——
  5 个量化态只能经**展开后**真名进入。
- 移植源事实：`src/fsm/analyze.mbt` 只按已展开 IR 行建边、**无手写写入态概念**、是**警告级**打印、
  靠 `meta.terminal_states` 兜底，且**当前无调用者**（休眠算法）。

**step**：

1. **补两源**（判据落地）：可达源改为「`to=` 表边（含模板展开后真名）∪ 表行 `state:X` 参数 ∪ 手写锚点登记」；
   `ExpectVerbRequired` / `BnpIdAfterClose` 必须由新源命中。
   **✅ 2026-09-12 完成**：`validate.mbt` 的 `n3_check_reachable` 落三源 + 锚点形检；
   `types.mbt` 新增 `N3StateEntryDef`（`state` / `anchor` / `note?`）与 `N3BaseDef.state_entries`；
   `parse.mbt` 解析可选段 `[[state_entries]]`（未知键忽略、缺省空）；表源加 1 条登记
   （`BnpIdAfterClose` ← `actions.mbt:200`）。**验收：`moon test src/rdf/n3gen` 10/10 绿**
   （原 9/10 红）；子仓 `moon test src/gen_n3v2` **116/116** 不变（产物零改，G9 锁）。
   判据入 `spec.md` §12；决策入 `adr.md` ADR-31。
2. **锚点登记制**：`actions.mbt:172/200/529/719/976` 四点逐条登记 `state ← 写入点 file:line + 一句语义`
   （表源可选 key 或 `spec.md` §5.1 归位清单同页）；门内做"行存在 + 关键字"轻校验，防登记漂移。
   **✅ 2026-09-12 完成**：登记册落表源 `[[state_entries]]` **3 条**（`BnpIdAfterClose` ← `:200`；
   `ExpectDotOrGraph` ← `:529` / `:719`）；新增 **G13 锚点登记门**（`n3gen_test.mbt`）：
   文件存在 + 行号在界内 + 该行含 `ctx.state` / `frame.ret_state` / 该条目 state 名。
   **探针实证**：把 `:529` 改成 `:530` → G13 红并点名
   `ANCHOR-DRIFT ExpectDotOrGraph @ ...actions.mbt:530`；复原 → 绿。验收：`moon test src/rdf/n3gen`
   **11/11**（G1–G13）；子仓 116/116 不变。
  ⚠ 口径记牢：登记册用**表侧名**（`ExpectDotOrGraph`），代码里是生成名（`N3ExpectDotOrGraph`）——
   填错时 G11 以"登记了未声明态"当场咬住（实证）。
3. **两前置**：模板 `$param` 先展开再建边；新增可选 `terminal_states`（缺省空 = 旧口径，不误判 dead）。
   **✅ 2026-09-12 完成**：前置 A（模板先展开）由 `n3gen_build` 固定顺序 `parse → compose → validate → emit`
   （`emit.mbt:1287/1291`）保证 + `validate.mbt` 显式门"子机标记未展开（须先过 n3gen_compose）"——
   **已在位，零改动**；前置 B（`terminal_states`）落 `[meta]` 可选键（parse 白名单 + 可选读 +
   `N3BaseDef.meta_terminal_states`），G11 加**死态判据**（可达 ∧ 无出边 ∧ 未声明 → 报死态）+ 名字形检。
   **实证**：现状表**零死态**（不声明也不报）；探针——删 `ExpectTildeEnd` 7 条出行 → 报
   `死态 [ExpectTildeEnd]`；同态声明 `terminal_states = ["ExpectTildeEnd"]` → 报警消失；还原 → **11/11**。
4. **分级落地**：首版**警告级**（打印不 pin）→ 对现状表跑一次，若"不可达"集合 ⊆ 登记锚点集（即无新增假报）
   → 再钳为**错误级**并入 G 门（G11 生效）。
   **✅ 2026-09-12 完成（题：推荐2 = 按 ADR-31 先警告级）**：G11 拆两层——
   `n3_reachability_report(...)` **纯函数**（无夹具单测：三源命中 / 死态 / terminal 豁免 / 空源全不可达）
   + `n3_check_reachable` 包装；**形检仍错误级**（登记/终止态名字 typo 直接拒），
   **可达性发现降为警告级**（打印 `G11(warn): …`，不阻断），钳制开关 `let n3_g11_strict : Bool = false`
   （跑满 30c/30d 无假报后翻 true）。
   **探针实证**：删 `ExpectTildeEnd` 7 条出行 → 打印告警且**构建不阻断**（唯一红是 G9 字节对拍，因行被删）；
   还原 → **12/12**。现状表零发现（无假报），满足 ADR-31 的钳制前置之一。
5. **钳制落地（G11 生效）**：`n3_g11_strict` 由 `false` 翻 `true` —— 可达性发现（不可达态 / 死态）
   改走 `Err`，**阻断构建**；**形检**（登记态未声明 / anchor 非 `file:line` / `terminal_states` typo）本就错误级。
   **✅ 2026-09-12 完成**：前置实测满足（30c/30d 全量迁移 + 四套件跑满，构建输出**零 `G11(warn)` 行**）。
   **探针实证（门真会咬人）**：表源临时加无入边幽灵态 `G11ProbeGhost` →
   `moon test src/rdf/n3gen` **11/12 红**，失败信息 `G11: 不可达态 [G11ProbeGhost]`；
   删幽灵态 → **12/12 绿**；`n3v2_out.gen` md5 `66a876c6…` 与探针前一致（产物零漂移，G9 锁）。
   **回退路径**：排障需降级时改回 `false`，并在 `validate.mbt` 开关注释处写明原因与恢复役次。
   判据入 `spec.md` §12（钳制节）。

**交付**：G11 判据（代码 + 登记册）；`moon test src/rdf/n3gen` 恢复 **10/10**（含 G12 compose 负例）；
`src/fsm/analyze.mbt` 的移植关系在注释里写实（移植 BFS 骨架、**不移植**输入假设；标注其当前无调用者）。

**验收**：门绿；对现状表零假报（警告级期实测零 `G11(warn)`）；把任一锚点登记删掉 → 门红（证明锚点源真的在生效）；
**钳制后**：新增不可达态 / 死态 → 构建红（step5 探针已证）；`cp` 交付后子仓 `moon test src/gen_n3v2` 116/116 不变。

**风险**：① 锚点漂移 ⇒ 门假绿（故 step2 的轻校验必须做）；② `terminal_states` 若被滥用成"消音开关"，
门会失去意义——只允许声明真终止态（如 `ExpectDirectiveEnd`）。**待裁**：题11 = 锚点登记落在表源（新可选 key）
还是 `spec.md` §5.1 清单（建议：表源 key，门可直接消费，spec 只引用）。

（役22/25/23/24/26/27a/28/29 ✅ 2026-09-11；役31 step1–5 ✅ 2026-09-12（G11 已生效为错误级）；**役30（30a–30f）✅ 2026-09-12 收官**；R-04 长期半与 R-16 [立案] 另役）。

---


---

## 5. P 步表（P 级 ↔ 役 ↔ R ↔ 前置）

| P | 步骤含义 | 役 | R | 前置 | 阻塞题 |
|---|---|---|---|---|---|
| **P0-1** | 效果面接活（架构维） | 役22 **✅** | R-02 已落地 | — | 题1 落地/题2 留役28 |
| **P0-2** | 证据面补齐（先证据后重构） | 役25 **✅** | R-07 已落地 | — | 题6=A 落地 |
| **P0-3** | 归位点台账化 | 役23（前半）**✅** | R-03 已落地 | 役22 | — |
| **P0-4** | 错误累积与失败复位 | 役24（前半）**✅** | R-05 已落地 | 役22 | 题4=A 落地 |
| **P0-5** | 清账（0 warning） | 役26（前半）**✅** | R-09 已落地 | — | — |
| **P1-1** | 状态权威回归表 | 役23（后半）**✅** | R-01 已落地（翻案：机制收敛） | 役22 | 题3=机制收敛+登记 |
| **P1-2** | nil 标记显式化 | 役24（后半）**✅** | R-06 已落地（验形门） | 役22 | — |
| **P1-3** | 文档三件 | 役26（后半）**✅** | R-12 已落地 | — | — |
| **P1-4** | 命名 + 测试归位（**拆 27a 零抖动 / 27b 并入役28**） | 役27a **✅** / 27b ✅（并役28） | R-10 ✅ / R-11 ✅ | 役24 ✅ | trig 同笔改 ✅（役28） |
| **P1-5** | ctx 分组 + 公共面收窄（**含 27b 改名**） | 役28 **✅** | R-13 / R-08 / R-10 ✅ | 役22–24 + 役27a ✅ | 题5=A 落地 / 题2=B 落地 |
| **P2-1** | 词法收口 + 单一实现 | 役29 **✅** | R-04 短期 ✅（长期 [立案]）/ R-15 ✅ | 盘依赖面 ✅ | 零 Lexermoon 接触 |
| **P2-2** | 状态爆炸治理（**拆 30a 建模 / 30b 选型 / 30c 探针 / 30d 迁移 / 30e 门 / 30f 回灌**） | 役30 **✅** | R-14 ✅ | 立项 ✅ / 30a–30f 全绿 ✅ | 题7=A 落地 / 题8=Quant 落地 / 题9=G9 字节等价 / 题10 → 役31 ✅ |
| **P0-0b** | 可达性门 G11 收口（判据 ADR-31；**门级前置**） | 役31 **✅（step1–5）** | R-14（门部分）✅ | — | 题11 已落地（登记落表源）；**钳制已触发 ✅（step5）** |

推荐执行序（**已走完**）：**役31（门级前置）✅ → 役30a ✅ → 30b ✅（题7 裁断=A）→ 30c ✅ → 30d ✅ → 30e（G10）✅ → 30f ✅**


## 6. 执行记录（滚动追加）

| 日期 | 役 | 范围 | 结果 / 验收数字 | 备注 |
|---|---|---|---|---|
| 2026-09-11 | — | 评审 + 立卷 | 基线：111/111、0e/11w、turtle 316/316、rdf12 75/75、N3Tests neg 23ok/0miss + pos+eval 205clean | `spec.md`/`ctx.md` 同日立卷；原始评审底稿存 `/tmp/todo.md.review-bak` |
| 2026-09-11 | **役22** | R-02 效果面接活（题1=A 全控） | 111/111、套件四项不变（neg 23ok/205clean、turtle 316、rdf12 75）、外层 245/245、G9+fmt 幂等、mbti 四死件删除+队列下沉 | **翻案**：path_obj_close 三发 Sequence 破单发预留位——emit_queue 下沉 N3Context；interpret 唯一解释器、engine.next 纯控制流；under_formula/settle×2/take_pending 下沉 ctx；见 adr.md ADR-22 |
| 2026-09-11 | **役25** | R-07 证据面补齐（题6=A） | 111/111、套件四项不变、加/删文件红绿演练全过、mbti 零差、外层 245/245 | 绝对计数钉（closure 钉系恒真式）；影子扫描 strict-gap 5/0/123/13 两族立项（C-16 前缀预绑定 486 处 / C-17 `<=` raw 谓词）→ R-16 役29；见 adr.md ADR-23 |
| 2026-09-11 | **役23** | R-01 机制收敛（翻案）+ R-03 归位清单（题3=机制收敛+登记） | 111/111、四套件数字不变、G9+fmt 幂等、mbti 零差、`grep -c` 直写=3 全带锚 | R-01 迁表不可达翻案：链形异判（SubjTrailAfterStep 汇合实证）+ Err 短路，SetState 零可行实例不立项；id 特例前移刻帧（`mut ret_state` 役14 先例）；R-03 清单 §5.1（A3+B4+C），KeywordA/this 门=事件重分类不上表；C-03 bool_at 误诊修正；零生成链改动；见 adr.md ADR-24 |
| 2026-09-11 | **役24** | R-05 错误累积 + R-06 nil 验形（题4=A） | 116/116（+5 钉）、套件四项不变、G9+fmt 幂等、mbti=R-05 设计面、外层 9/9 | error_spans 累积+BusinessFailed 复位续解（recover 拆层）+drain 三点保文件序；nil 验形门 `data[offset]=='('`（in-band 通道保留）；教训：坏行输入每行自带 Dot、路径错误输入先查表三件事（态族/词法合并/span 回填）、view 断言禁 to_string；见 adr.md ADR-25 |
| 2026-09-11 | **役26** | R-09 清账 + R-12 文档三件 | 0 warning（30 条全模块清零）、116/116、四套件数字不变、G9 9/9（表源再生链）、fmt 幂等、mbti=死位删除面 | unused_package×17/unused_trait_bound×3（同 trait 双 impl 约束须一致）/deprecated×6/unused_value×4；variable_name/rule_side 表源删+再生（RuleSide 枚举连坐；iri_upcast 活机制正名）；ARCHITECTURE.md 一页（含预留位清单）+ guides/n3 包名与 API 实形对齐 + 役21 跨卷注记（src/fsm/toml.md）；教训：pkg 警告删行先看文件内容勿按行号猜（argparse/debug 错杀回补） |
| 2026-09-11 | **役27a** | R-11 测试归位 + R-10 部分（fr→frame） | 116/116、mbti 零 diff、0 warning、fmt 幂等、四套件不动 | 71 处 fr→frame；27 test 迁双新件（生产件 1396/101 行纯实现）；view_str 归一 decode_lossy 后复用；emit_subject/emit_predicate/emit_object 三件套收编 105 处 mat_vs；mat_empty 零消费者亡；教训：grep -c 数行不数处（71≠55）；复用前先对语义（view_str≠mat_vs） |
| 2026-09-11 | **役28** | 27b 改名 + R-08 公共面收窄 + R-13 组清（题2=B、题5=A） | mbti 55→29 pub 行、0 warning 全模块、329/329、套件钉全绿（316/75/357/89/29/27/72、N3Tests 23ok/205clean、examples A13）、G9 9/9、fmt 幂等 | pver 族改名经表源再生（表 3 行→G9→cp→本包 70）；Hooks→N3ActionsImpl 102 + hooks→actions；N3PendingQuad 不降；trig 同笔 66 + 三层表源同笔（trig.mbt 冻结件手编 4 循役8 先例）；生成件 priv 化再生 + 用户层手降 + 字段级 priv；死码四件清；R-13 组清现实序列收编（annotation×3+path×4，keywords/directive/inversion 不立项）；外层 src/fsm 111 警告存量（stash 对照 HEAD 同数） |
| 2026-09-11 | **役29** | R-15 数值/布尔单一实现 + R-04 短期补偿点单点台账 | parity 零差（对比 72 段 mismatch=0）、nquads 124/124（89+29+27+72）、trig 357/357、n3v2 116/116、模块 329/329、0 warning、fmt 幂等、nquads mbti +2 行 | 识别件独一份落 gen_nquads/numeric.mbt（trig 字节孪生件实证 → 跨包单点；账面 n3v2 types.mbt 建议不成立）；is_boolean_word 收编六处、bool_at ×2 删、expand_* 留驻物化层；台账头注六点地图 + 钉面清单 + engine 回指；不移 trim（七臂旗标交织）、C 冻结不动；长期方言感知词法器留账 |
| 2026-09-12 | **役30a/30b** | R-14 量化基座（`spec.md` §10）+ 选型（`adr.md` ADR-30：A 构建期 compose 主轴 / B 否决 / C 吸收为门 + 兜底） | spec §10：55 态 / 384 行；交叉族 36 态（65%）/ 232 行（60%）；边际成本 ≈ +10 态 +50~80 行 / 窗。ADR-30 三条硬理由否决 B（字节等价红线 / 三面重写 / 行数不省） | **G11 判据修正（用户指正 2026-09-12）**：`src/fsm/analyze.mbt` 只按 `from→to` 表边建边、且**当前无任何调用者**；直接移植会假红 n3v2 **6 例**（模板占位 5 + 手写锚点 `N3BnpIdAfterClose` 1）、trig **1 例**（`ExpectVerbRequired`）→ 判据改为「三源可达（表边 ∪ 表行 `state:` 参数 ∪ 手写锚点登记）+ 模板展开先行 + `terminal_states` 声明 + 首版警告级」，详见 §役30e |
| 2026-09-12 | **役31 立案** | G11 可达性门收口（判据 = `adr.md` ADR-31） | 实测：首版 G11（`validate.mbt:479` 只按 `from→to` 建边）使 n3gen 门 **9/10 红**——`G11: 不可达态 [ExpectVerbRequired, BnpIdAfterClose]`，二者均表外入口（表行 `state:` 参数 ×51 处 / 手写 `frame.ret_state` 改写下 `actions.mbt:200`）；另 5 个量化态属模板占位行（`$var`）；移植源 `analyze.mbt` 只按已展开 IR 建边、警告级、**无调用者** | ADR-31 起草：可达源三源（表边 ∪ 表行 `state:` ∪ 手写锚点登记）+ 两前置（模板先展开 / `terminal_states` 可选）+ 首版警告级后钳错误级；役31 step1–4 见 §4；**判据未修好前 G11 不 pin、compose 改动不入库** |
| 2026-09-12 | **役31 step1** | G11 补两源（表行 `state:` + 手写锚点登记） | `moon test src/rdf/n3gen` **10/10**（原 9/10 红，`[ExpectVerbRequired, BnpIdAfterClose]` 两假红消失）；子仓 116/116 不变；产物零改（G9 幂等） | 改动面：`n3gen/{types,parse,validate}.mbt` + `n3v2_base.toml` 新增可选段 `[[state_entries]]`（1 条登记：`BnpIdAfterClose` ← `actions.mbt:200`）；判据入 `spec.md` §12。**旁证（非本役引入，2026-09-12 已修）**：外仓 `moon test src/rdf` 曾有 1 个既有红——`trig 对照：手工 trig_domain.toml ≡ 词表生成`（`trig_domain_toml_gen.mbt:215` **`domain_config_matches`**），已用 HEAD 只读 worktree 复现 ⇒ 由 `1152ca8`（役28 "trig 三层表源同笔"）引入，根因 = 三层 TOML 的 config 层漂移（字节层 `fsm_out/trig_fsm.toml` 三腿仍绿） |
| 2026-09-12 | **役31 step2** | 锚点登记册 + G13 锚点漂移门 | `moon test src/rdf/n3gen` **11/11**（G1–G13；新增 G13）；子仓 116/116 不变；探针：anchor 行号改错 → G13 红并点名（`ANCHOR-DRIFT …:530`），复原 → 绿 | 登记册 3 条落表源（`BnpIdAfterClose`←`:200`；`ExpectDotOrGraph`←`:529`/`:719`）；口径：登记用**表侧名**（无 `N3` 前缀），填生成名会被 G11 以"登记了未声明态"咬住（实证）；`spec.md` §12 同步（两门 + 登记册 + 非种子两点 `:172`/`:976`） |
| 2026-09-12 | **役31 step3** | 两前置：模板先展开（已在位）+ `terminal_states` 可选键与死态判据 | `moon test src/rdf/n3gen` **11/11**；子仓 116/116；探针：删 `ExpectTildeEnd` 7 条出行 → G11 报 `死态 [ExpectTildeEnd]（可达、无出边、未声明 terminal_states）`；同态声明 `terminal_states=["ExpectTildeEnd"]` → 报警消失；还原 → 绿 | 前置 A 零改动（compose 已在 validate 之前 + 显式未展开门）；前置 B 落 `[meta] terminal_states`（可选、缺省空）+ G11 死态判据 + 名字形检；**现状表零死态**（该键为前置保留）；判据入 `spec.md` §12；探针期间 G9 先落件导致 `.gen` 被重写，已还原并复核 |
| 2026-09-12 | **役31 step4** | 分级落地（推荐2：警告级 + 钳制开关） | `moon test src/rdf/n3gen` **12/12**（+纯函数单测）；子仓 116/116；探针：删 7 条出行 → 打印 `G11(warn): 死态 [ExpectTildeEnd]…` 且**不阻断构建**（唯一红 = G9 字节对拍），还原 → 绿 | G11 拆为「纯报告函数 + 包装（形检错误级 / 可达性警告级）」；钳制开关 `n3_g11_strict=false`；单测覆盖三源/死态/豁免/空源；判据入 `spec.md` §12；**役31 收官**（钳制为待触发项） |
| 2026-09-12 | **trig 修复（外仓）** | `moon test src/rdf` trig 对照红 → 20/20 | 根因 = 役28 `pver/bver → prefix_version/base_version` 改名漏第 4 层（词表生成器 `trig_domain_toml_gen.mbt` 的 `trig_domain_config()`）；修 2 处 `name` + 注释；验收：外仓 20/20、子仓 trig 80/80、n3v2 116/116 | 旁注：`n3_domain_toml_gen.mbt`/`domain/n3_domain.toml` 旧名属 **v1 冻结 oracle**（自洽），已在文件头加"命名冻结说明"，勿顺手改名 |
| 2026-09-12 | **役30d** | 全量迁移收官：ListPath(15 行)+ObjTrail(7 行) 子机化 | `moon test src/rdf/n3gen` **12/12**（G9 逐字节等价 ⇒ 求积 ≡ 原手列 384 行）；`src/rdf` 20/20；子仓 `gen_n3v2` 116/116、`gen_trig` 80/80 | 终局：非标记行只剩核心态与顶层特性入口，**零手列交叉族**；机器 9 族 / 段 57 / 实例 10 / 标记 59 / 非标记行 140；⚠ 附带修 G8 负例锚点失配（新增 `n3_neg_patch` 两文件手术助手）——与 G13 同源教训：探针锚点必须可证伪 |
| 2026-09-12 | **役30e** | G10 族声明装配门（死段/死实例）+ G11 归役31 说明 | `moon test src/rdf/n3gen` **12/12**；`src/rdf` 20/20；子仓 `gen_n3v2` 116/116、`gen_trig` 80/80 | G10 落地：判据=死段/死实例，调用点=**compose 前**（标记行 compose 后即消失——首版误放 validate 曾"全死"误报，现场纠正）；不重设存在性/唯一性两门；探针：加 `ghost_seg`+`ghost_window` → G10 双点名；实测段 57/实例 10/标记 59 全接线。教训：**门的调用点必须在数据可见的阶段** |
| 2026-09-12 | **役30f** | 回灌四件（spec §10.6 / ARCHITECTURE / world macro-spec §8 / ctx R-14） | 文档改动，门未动：`moon test src/rdf/n3gen` 12/12（复核）、`src/rdf` 20/20、子仓 116/116 + 80/80 不变 | 役30（30a–30f）**收官**；`ctx.md` R-14 转 ✅；`world/macro-spec.spec.md` 首次把"子自动机组装"落成生产实例样板 |
| 2026-09-12 | **役31 step5** | **G11 钳制**：`n3_g11_strict = false → true`（可达性发现由"打印告警"升为 `Err` 阻断） | `moon test src/rdf/n3gen` **12/12**；`src/rdf` **20/20**；子仓 `gen_n3v2` 116/116、`gen_trig` 80/80；产物 md5 `66a876c6…` 零漂移 | 前置实测满足（30c/30d + 四套件跑满，构建输出**零 `G11(warn)`**）；**探针**：加幽灵态 `G11ProbeGhost` → 11/12 红且报 `G11: 不可达态 [G11ProbeGhost]`，删后 12/12；回退路径写进开关注释；**役31 收官**（题11 落地） |
