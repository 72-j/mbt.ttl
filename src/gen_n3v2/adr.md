# gen_n3v2 本地役录（ADR）

v2 生产线役录自本文件起立卷（用户定案 2026-09-10）；役16/17 全文见
`bak/260910/gen_n3/todo.adr.md` §5.15–§5.16（役19 起 gen_n3 包退役归档，
历史卷随迁），后续 n3v2 涟漪（表/引擎/词法/物化/套件）一律落本卷。
表源再生径：外层仓 `src/rdf/n3gen`（`n3v2_base/n3v2_trans.toml` →
`n3v2_out.gen` → cp 本包 `n3.mbt`），改表先落 domain 层再生，禁手编 n3.mbt。
跨卷注记（R-12③，役26）：役21 Action Chaining（`[[actions]]` 全键 round-trip +
五门校验接活、`CodegenConfig.actions`/`codegen_trait` 退役、`src/fsm` 陈钉清零 95/95，
提交 `7630bf2`）落外层卷 `src/fsm/toml.md` §根级动作声明面 与 `src/rdf/adr.md`，
不在本卷重复立条。

## ADR-18：字面量贴路径解胶 + path_obj_close 双发（物化残差清零 2→0）——✅ 2026-09-10

**背景**：役17 收官时残差 2（path2.n3 / caret_pos.n3，报 "Malformed literal
suffix"）被框定为"物化前端 1:N 扩展步"欠账。探底翻案：路径 desugar 役3
ADR-006 引擎已全展开（每跳 EmitQuad(SPO)，fresh = 操作符 token span），双表
Bang/Caret 行全 Zones 就位，物化层零改——框架系误诊。真根因两层：

1. **词法 `^` 门**：共享词法 `Lexermoon::scan_literal_suffix` 后缀门把单 `^`
   当 `^^` 的门字节，`"lit"^:prop` 连 `:prop` 整段胶进字面量 span，引擎收不到
   N3Caret 事件，路径机器全盲。`!` 非门字节（`"lit"!p` 早已分词）。
2. **`path_obj_close` 只发跳边**：词法解胶后探针暴露第二层——Dot 已随收口行
   消费，pop 落位的外层语句 `(帧s, 帧p, 终尾)` 再无收口行可发。隔离语料槽位
   脏报 "Incomplete triple"；整文件语境被后续语句覆写**静默丢失**（path2 旧
   q=14 = 纯跳边计数 3+2+2+2+5，D 语句外层全蒸发）。矛盾破案键 = 隔离
   mat_chain 与整文件 suite 链行为差。

**裁决**：
- 词法门加 `^^` 判别：单 `^` 须后随第二 `^` 才进后缀扫；Moon
  （`gen_nquads/lexer_mbt.mbt`）+ C（`lexerc_ffi.c`）同步——C 侧陈旧连役16
  停扫集 `) ] }` 都缺，一并补齐（parity 套件 72 段零差裁判）。
- `path_obj_close` 双发纠偏：帧身份改指终尾（`Slot.open_span` 转 mut——多跳
  链末节点）+ Sequence 追加第二条 EmitQuad，**粒度随收口事件**：`,` Object
  粒度保 s/p 续位、`;` PredObj 保 s、`.` SPO 全清（首版恒 SPO 把 pop 恢复的
  s/p 抹掉、续位断，探针当场否决）。desugar 全展开：
  `S P (O!Q) ≡ S P _:1 . _:1 Q O`，`,`/`;` 续位语义免费继承。
- 定案留账：集合 rdf:first/rest 全展开 = ADR-003a 变更另立项（破坏
  emits==quads 不变量 + 动冻结 v1；datalog sink 走列表时天然驱动再启）；
  ADR-003b 显式 first/rest iver upcast 死位保留；负例缺口 3
  （thisadoc / qname-as-prefix-in-decl / bad_prefix2）validate 门另役。

**验证**：
- N3Tests sweep：pos+eval **205 clean / 0 mat-only / 0 parse-fail**，新钉
  `assert_eq(pos_mat_only, 0)`（收官钉）；neg 21ok/3miss 留账不变。
- path2.n3 q=14→16（+2 外层语句，与机械推演吻合）；caret_pos 翻 clean。
- 语义钉五形（engine_wbtest）：基本形（跳边+外层语句同一 fresh）/多跳链
  独立身份+语句归属终尾/`,` 续位各路径各得一语句/`;` 续组完好/bang 跳边
  字面量主语（`"v" <q> _:1`——役17 字面量主语臂免费兑现）。
- 全量回归：v2 109 / v1 108（冻结，print-sweep 观测）/ nquads 124（含 C
  parity 零差）/ trig 80 / n3gen 10 / 模块 **421 全绿**。

**后果**：
- 正面：物化面收官（mat-only 131→2→0，役17+18 两役清账）；N3Tests 正例
  全净；路径语义从"跳边蒸发"修正为 spec 全展开口径。
- 负面/未了：v1 gen_n3 print-sweep 观测其自身残差（69 clean/126 mat-only/
  10 parse-fail）——冻结差分 oracle 不随役推进，退役待条件（见 gen_n3
  spec §9：物化面已收官，差 print-sweep 对照归档一次）。
- 教训：长代码块手编在本役屡发自损（转义丢/幻觉片段掺入既有行）——降级
  小块 Edit + 行号 python 手术 + /tmp 中转 + 落盘 grep 机械验证才稳；
  探针先行二次兑现（词法解胶"预期零改"被探针否决，补出第二层缺口）。

## ADR-19：v1 gen_n3 退役执行（差分 oracle 除役，模块纯 v2）——✅ 2026-09-10

**背景**：spec §9（现随 bak 归档）预授权"v1 退役为条件驱动：v2 物化面收官 +
v1 print-sweep 对照归档一次"。役18 物化残差清零后条件全熟，用户当日手动执行
包迁移：`src/ttl/src/gen_n3` → `/home/thy/moonttl/bak/260910/gen_n3`（含
spec.md / const.md / todo.adr.md 历史卷 / N3Tests 语料 / v1 双表 n3.mbt）。

**涟漪清理（本役落两仓）**：
- 嵌套仓：① N3Tests/rdf-turtle/rdf12/examples 语料 15M 迁居
  `src/gen_n3v2/rdf-tests/`（v2 唯一消费者），三套件 wbtest 路径
  `src/gen_n3/rdf-tests` → `src/gen_n3v2/rdf-tests` 改写；② moon.pkg 头注
  v1 冻结表述退役。
- 外层仓：① n3gen G0 v1 黄金门删除（读 gen_n3/n3.mbt 对拍 + n3_out.gen
  工件落盘），**强幂等钉迁入 G9**（重复 build 零字节移动）；② G1–G8 编译器
  校验门改喂 v2 表（`n3_load()` 重指 n3v2_base/n3v2_trans.toml，13 个手术
  锚点逐一验在）；③ v1 表源 n3_base.toml / n3_trans.toml + n3_out.gen 工件
  删除；④ emit.mbt / moon.pkg 发射权威注释改指 v2（G9 port authority）。

**验证**：v2 109/109（sweep 205 clean / 0 mat-only / 0 parse-fail 不变）；
嵌套模块 **322/322**（−99 = v1 包测试随役）；外层 n3gen **9/9**（−G0）；
src/rdf **20/20**。

**后果**：
- 正面：模块纯 v2（单引擎/单表源/单黄金门）；再生线瘦身——
  `moon test src/rdf/n3gen; cp src/rdf/n3gen/n3v2_out.gen
  src/ttl/src/gen_n3v2/n3.mbt`；维护面减半。
- 未了：v1 print-sweep 对照归档未单独执行（包已切走，历史基线以役18 台账
  记载的 69 clean/126 mat-only/10 parse-fail 为准）；嵌套仓 git 面待用户
  提交（D gen_n3/* + rdf-tests 新增）；ADR-003b 死位、负例缺口 3 留账不变。

## ADR-20：负例缺口 3 收口（this 晋升门 + 账本验形门 + bad_prefix2 翻案 skip）——✅ 2026-09-10

**背景**：役16 钉住 `neg 21ok/3miss` 三缺口（thisadoc / qname-as-prefix-in-decl /
bad_prefix2），役18 定案"validate 门另役"。本役三案三裁断，全部 User 层——
零表改、零再生、零词法改（n3gen 9/9 原样绿实证）。

**三裁断**：
1. **thisadoc**：`this` 套件 deprecated（manifest "'this' keyword is deprecated
   - negative test"）。裸 `this` 本已被拒（Unknown 无表行）；唯一活路 =
   @keywords 台账晋升 Unknown→KeywordX（normalize_term_span Unknown 臂）。
   裁定：晋升门加 `is_deprecated_this` 4 字节嗅探（is_version_lit_form 同款
   helper 风格），`this` 永保 Unknown → perr，错误落使用点；`@keywords this .`
   声明本身仍合法。正例 ref 文件全用 @forAll、裸 `this` 零出现，零涟漪。
2. **qname-as-prefix-in-decl**：`@prefix foo:bar <>.` 声明名带本地部。零 quad
   文件 perrs 恒空 → 只能物化器 merrs 通道。裁定：materialize_all 入口账本
   验形门（声明名末字节须 `:`，nquads validate_helper 同层组装后 validate）；
   零 quad 也报。语料普查：正例声明名带本地部零命中；附带保险
   turtle-syntax-bad-prefix-05 族。
3. **bad_prefix2——役17 误诊翻案**：真因 = 前缀重定义（manifest 注释），
   非 `:bad:o` 空前缀（兄弟正例 good_prefix.n3 同 token `:bad:o`
   rdft:Approved 铁证）。而"重定义非法"规则本身被 WG rdft:Rejected，语料
   实证正例大量异-IRI 重定义（N3Tests qvars1/qvars2/path2/lstring/
   cwm_includes×5 + turtle prefix_reassigned_and_used——名字即官方语义、
   turtle-subm-25/27）：任何重定义拒收都打翻 5+ 官方正例。裁定：解析器
   不实现被否决的规则，**parser_index.tsv 改 skip 留账**（照 rdfcore-tests
   skip 先例，理由落 wbtest 头注 + 钉注释）。

**钉**：`neg_miss 3→0`、新钉 `neg_ok==23`（24−1 skip）；役20 语义钉四形
（this 晋升门 perr / 账本门零 quad 报 / 同-IRI 重声明全净 / 异-IRI 重定义
全净 + **值语义后声明胜** `<http://e/x>`——与构造注释"后声明覆盖先声明"及
cwm/Turtle 官方口径一致，resolve 扫描从尾返回）。sweep 终局：
**neg 23ok/0miss, pos+eval 205clean 0mat-only 0parse-fail**。

**验证**：v2 110/110（+1 钉）；嵌套模块 323/323；nquads 124（C parity 零差）、
trig 80、外层 n3gen 9/9（零再生实证）；turtle 316/316、rdf12 75/75
（手工验证块：n3_wbtest.mbt 尾部"役20 历史债三案"——this 事件面 Unk 钉 /
账本门错误串钉 / bad_prefix2 原文重定义宽容 + 拼接语义 worse.orgs 钉；v2 终局 111/111）
（账本门对 8 处 Materializer::new 调用点零误伤）。

**后果**：
- 正面：N3Tests 负例面收官（24 负例全裁决：23 拒 + 1 skip 留账）；正例
  205 持平全净；"重定义宽容 + 后声明胜"官方语义由钉锁死，防未来误收紧。
- 未了：声明名形状引擎侧提前拒收（guard 路线）不做——账本门已收口，不双设门。
- 教训：① Edit 幻觉片段自损两连（"never-used-placeholder" /
  "syntax_never_used2" 混入 new_string 毁 arm）——锚点定位 python 行手术
  （内容锚 + assert 邻距，不硬编码 CJK 行）为本役稳定路径；② 钉测试复踩
  役18 枚举坑（QuadEmit.subject 须 mat_subj 剥壳再 mat_vs）——台账坑要
  写前先翻。

## ADR-22：效果面接活（interpret 唯一解释器 + ②面收形 + 机械下沉 ctx）——✅ 2026-09-11

**裁决**：ctx.md §6 题1 = **A（全控形态）**。`N3EffectHandler.interpret`
（n3.mbt 套装默认体）成为唯一效果解释器；`engine.next` 退为纯控制流
（取事件 → step → interpret → KeepGoing 继续 / YieldQuad 上抛 / Stop 终止），
效果语义零残留。

**trait 收形**（R-02/②面）：
- 删四死件：`handle_continue`/`handle_done`/`dispatch`/`on_exit_graph`
  （全仓零外部引用，仅 n3.mbt 内部 16 处自指）。
- 留五 handle_* 观测位（emit_quad/reset/sequence/pop_bnp/open_slot），默认
  无操作，interpret 先通知后机械——覆盖即挂切面，零语义副作用。
- `snapshot` 默认 = `ctx.snapshot()`、`apply_scope` 默认 = `ctx.reset(scope)`
  （C-02 合一：粒度清槽唯一实现）。
- `on_pop_bnp`/`on_open_slot` 默认无机械；引擎覆盖注入
  `N3Actions::pop_bnode_prop` / `N3Actions::open_slot`（意图兑现机械在 action）。

**ctx 下沉**（engine.mbt → N3Context 方法，interpret/引擎共用同一入口）：
`under_formula`（ADR-002 压制位）、`settle_inversion`（役6 倒装清账半边）、
`settle_annotation`（役8 壳账收口半边）、`take_pending_quad` → `take_pending`
（快照 → 壳交换 → 倒装交换 → settle×2 → reset 五连一体）。私有可见，mbti 零膨胀。

**翻案（ADR-003a 单发认知）**：表内 Sequence 构造唯一（BnpAfterObject+Rbracket
= 单发 [EmitQuad(PredObj), PopBnp]）不等于全系统单发——役18 `path_obj_close`
（actions.mbt:929，用户层）动态构造**三发**
`[EmitQuad(SPO), PopBnp, EmitQuad(scope)]`。首版 interpret 单缓冲
（pending 覆盖式）丢首跳，役18 钉红实证（`1 != 2`）。裁定：`emit_queue`
下沉 `N3Context`（引擎字段退役），interpret Sequence 臂罩外 EmitQuad 逐条
FIFO 入队、队首即返、余者 next() 顶部排空——与旧引擎同构。单臂 EmitQuad
仍直返不走队列（主路径零中介，字节级等价）。

**fmt 幂等**：生成器输出须 fmt-clean——match 单语句臂折花括号形态
（`N3Effect::EmitQuad(scope) =>` 换行缩进 if/else）由模板直产，
G9 对拍即 fmt 幂等门。

**验证**：v2 **111/111**（含役6 15、役8 11、役18 1、役20 2 点名钉）；
N3Tests neg 23ok/0miss + pos+eval 205clean；turtle 316/316；rdf12 75/75；
外层 245/245；G9 字节一致 + `moon fmt` 幂等；mbti diff = 设计面原样
（删四死件 / ctx+emit_queue / engine-emit_queue）。
**后果**：双解释器消失，容灾/观测切面真接活（interpret 可被覆盖接管 emit/
降级）；R-08（题2 ②③ pub 可见性）留役28 复审。

## ADR-23：证据面补齐（三 runner 双判 + 绝对计数钉 + 影子缺口两族立项）——✅ 2026-09-11

**裁决**：R-07 落地，ctx.md §6 题6 = **A（双判）**——但双判形态不是
"两套判定链"而是**主判定链 + 影子扫描**：主链维持宽容口径（lenient=true，
套件数字不变硬约束），影子 = 同文件 lenient=false 严格组装校验重跑，
只统计不判定（STRICT-GAP 名单打印 + 基线钉冻结）。

**钉面四件**：
1. **绝对计数钉**（新增）：`expect_pass` 参数——turtle 316 / rdf12 75 /
   N3Tests pos_ok 205 / examples A-full 13。旧 closure 钉
   （`passed+failed==files.length()`）系自洽恒真式：加 good 文件不红，
   清单冻结必须靠绝对数。
2. **N3Tests 名单与闭合**：skip 名单钉（`cwm_other/rdfcore-tests.n3` +
   `extra/bad_prefix2.n3`，数组相等）；`unknown_kind==0`（kind 词表外行
   原本静默落 pos 桶）；桶闭合（六桶 + skip == tsv 非空行数 230）。
3. **examples 升格 pinned**：print-only 退役，桶闭合钉 + 三桶基线
   （A=13/B=0/C=0）。
4. **影子基线钉**：turtle 5 / rdf12 0 / N3Tests 123 / examples 13。

**影子缺口两族定性**（486+2 处严格翻脸，全部宽容零错）：
- **Undeclared prefix 族**（绝对主因）：validate_prefname "前缀必须先声明"
  门 vs N3/cwm 生态事实——内建前缀（log:/string:/math:/time:/list:）不声明
  即用 + 隐式空前缀（役17 同族）；**官方正例 good_prefix.n3 也翻**（套件
  自证宽容口径的正当性）。→ 立项 C-16/R-16。
- **`<=` raw 谓词族**（2 处，extras-10）：ADR-005 "操作符 token span =
  谓词身份" 被 validate_pred "IRI must be wrapped in <>" 拒——
  `=>` 同构但因先翻前缀门未露头。→ 立项 C-17/R-16。

**风险节纪律兑现**：不为绿回退 lenient（主链原样）；真缺口立项
（R-16 归属役29，语义修口同"单一实现"主题）；基线钉双向冻结——缺口
收窄（好事）也要显式翻钉，符合"钉是给当下教义的"仓训。

**验收演练**：加 good .ttl → 317 红（expect_pass 打破）；加 bad → failed=1 红；
examples 加 .n3 → 桶计数红；N3Tests tsv 加行缺文件 → 红；全还原 → 111/111 绿。
**数字**：111/111、turtle 316/316、rdf12 75/75、neg 23ok/0miss +
pos+eval 205clean 全部不变；mbti 零差；fmt 幂等；外层 245/245。

**教训**：grep 分桶统计跨 runner 混路径会错（N3Tests 123 曾误记 136 =
把 examples 13 混入）——分桶统计先 `sort -u` 全名单再数。

## ADR-24：表权威回归（R-01 机制收敛翻案 + R-03 归位清单）——✅ 2026-09-11

**题3 裁决**：R-01 原"三处直写迁进表（SetState 效果承载）"**不可达，翻案**。
侦察证据链三件：
1. **2 号 path_end_nested / 3 号 path_subj_end = 运行时链形异判**：同
   (from,on) 行内按 `ctx.path_fwd`/`ctx.path_src` 分派。表行 guard 的
   else 臂 = UnexpectedEvent（不 fallback 下一行）→ guard 分裂不可行；
   行分裂也不可行——主位/谓词两链形在 SubjTrailAfterStep **汇合**（谓词链
   path_step 每步同入，表行实证），表静态行无从分辨链形。
2. **1 号 pop_bnode_prop**：pop 由 interpret 的 PopBnp 臂调（役22 架构，
   handler 返 Unit）——SetState 效果无返回通道；Err 短路路径（2 号）效果
   同样无从返回。**SetState 变体三处零可行实例，不立项**（投机面，役15
   守卫具名组裁断先例）。
3. **帧携带是表能表达"动态返回态"的唯一通道**：`mut ret_state` 先例
   （役14 path_obj_close 按事件改写）已在帧内。

**R-01 落地 = 机制收敛**：id 特例前移登记点——set_id_subject 刻帧时写
`fr.ret_state = N3BnpIdAfterClose`（as_subject 时），pop 兑现统一
`ctx.state = fr.ret_state` 无条件读帧。直写 3 处条件分叉 → 1 处机制位
+ 2 处登记破例（[R-03-1/2/3]）。验收口径改：`grep -c` = 3 且全带锚
（原"表内可推出全部转移"不可达——运行时数据依赖出表模型是 FSM 边界
本质，破例恒可数即达成）。

**R-03 落地 = 归位清单 §5.1**（A 直写 3 条 + B 引擎归位 4 条 + C 关键词
真相裁决），每条注明"为何表内表达不了"：
- [R-03-4] 尾标点三瓣：span 子手术 + 一词两事件，均出表 1:1 模型（根源
  C-04，根治 R-04）
- [R-03-5] version_lit_ok：**非破例**——嗅探写旗标、决策在表行 guard，
  合规机制形态（登记以正名分）
- [R-03-6/7] KeywordA 降级 / Unknown→KeywordX 晋升：**事件重分类在表
  上游**——表按事件种类查行，无法"把 A 事件当 PrefName 行处理"；裁决
  需台账字节比对（guard 只通 ctx）。`this` 门 = 套件裁决常数（役20）。
  **不上表**（"能上表的改由表行承载"翻案）。
- **C. 关键词真相收敛裁决**：三处正交非冗余——classify_prefname（静态
  保留词，事件产生侧）∥ ctx.kw_ledger（动态文档台账，唯一数据源）∥
  表行（消费行）。**C-03 写实修正**：原"物化层 bool_at"系误诊（bool_at
  是布尔字面量展开，C-15 家族），除名；收敛诉求降级为"已收敛"。

**改动面**：actions.mbt（+25/−11，纯用户层）、spec.md（§5.1 新节 +
C-01/C-03 写实 + R-01/R-03 状态 + §9 数字）、adr.md/ctx.md/todo.md。
**零生成链改动**：表源未动，n3.mbt 零 diff，无再生。

**验收**：111/111；四套件数字全不变（turtle 316/316 gap5、rdf12 75/75
gap0、N3Tests neg 23ok/0miss + 205clean gap123、examples A13 gap13）；
G9 过 + fmt 幂等 + mbti 零差（impl 签名未变）；外层 9/9。

**教训**：裁定"能否上表"先查**事件分类学**——表消费的是已分类事件，
凡改判事件种类/切分事件的机制天然在表上游；表行 guard 只能拒绝不能
改派。宽度侦察（"3 处直写"字面清单）要先问**每处的判别数据源**是否
表内可得，再定迁移方案。

## ADR-25：错误累积与 nil 验形（R-05 + R-06）——✅ 2026-09-11

**题4 裁决 = A（API 不变）**：`parse_all` 返回形状 `(Array[QuadSpan], Array[ParseError])`
保持；行号沿用 `line_before`（0 基）。

**R-05 错误累积（C-05 三缺陷清零）**：
- `last_error : Span?` 单槽 → `error_spans : Array[Span]` 累积——原多坏语句
  只报最后一条；错误序 = 产生序 = 语句序。
- **BusinessFailed 复位续解**：`recover` 拆两层（`recover` = record + cleanup；
  `recover_cleanup` = 清栈清账 + skip-to-Dot）。BusinessFailed 臂先产 ParseError
  再 cleanup 后 return——引擎不再带病停机，后续语句照常解析（UnexpectedEvent
  与 BusinessFailed 恢复语义同径）。
- **drain 三点**：parse_next 入口（上轮积累转报）+ Some(Err) 分支（业务错上报
  前先转报其前结构错——跨型保文件序）+ None 终态（清尾）。转换 =
  `StructSyntaxErr("Structure error", line_before(span.0), span)`，转后清空。

**R-06 nil 验形门（C-06 收口）**：零长 span = 空集合 rdf:nil 的 in-band 标记
（QuadSpan API 不变硬约束下的唯一通道），保留但**可验形化**——唯一构造点
pop_bnode_prop（offset 恒指 `(` 开括号原文位），物化层 materialize_quad 入口
双门：`len == 0 && data[offset] != '('` → ValidationErr（事故零长不再静默变
rdf:nil）。边缘：data[0]=='(' 且事故 span=(0,0) 会误认（真根除需 out-of-band
载体 = API 改，不取，登记）。

**改动面**：engine.mbt（字段/record_error/recover 拆层/BusinessFailed 臂）、
parser_slice.mbt（drain_engine_errors + parse_next 三点接入）、materialize_n3.mbt
（验形双门 +18 行）、actions.mbt（构造点注释升级）、engine_wbtest.mbt（五钉
+124 行）。零生成链改动。

**验收**：116/116（+5 钉：双坏语句逐条/业务错复位续解/混合两型文件序/事故
零长拒/空集合 nil 验形门零误伤）；四套件数字全不变（neg 23ok/0miss、205clean、
turtle 316、rdf12 75、影子 5/0/123/13）；G9+fmt 幂等；mbti diff = R-05 设计面
（last_error→error_spans）；外层 9/9。

**教训（探针战术 + 输入构造三查）**：
1. 坏语句测试输入**每行必须自带 Dot**——recover 的 skip-to-Dot 吞到下一 Dot，
   裸坏行会吞掉后续所有行（钉 1!=2 的真因不是机制是输入）。
2. 路径错误输入构造**先查表三件事**：触发态族（主位链 SubjTrail ∥ 宾位链
   Path——Bang/Caret 在 ExpectPredicate 走主位链、ExpectObject 走宾位链）、
   词法合并（`[]` 空属性列表合并为单 BlankNode 事件，path_end_nested 永不
   触发——非空 `[ ... ]` 才是复合节点事件）、span 回填形态（无载荷事件
   span_of_event=(0,0) → lexer.pos() 零长回填）。
3. 物化产物断言用 view_str 字节转字符串，禁 view.to_string()（ArrayView 的
   Show 产出 `[b'...', ...]` 调试形态）；词表 IRI 含尖括号 <>。

---

## ADR-26：清账与文档三件（R-09 + R-12）——✅ 2026-09-11

**裁决**：R-09 按"全模块 0 warning"执行（账面立项仅 gen_n3v2 锚点，实清扫 30 条含
examples/cmd/gen_trig——清账定义以 `moon check` 输出为准，不以卷面清单为准）。
死字段裁决：`variable_name`/`rule_side` 真死（声明+reset 初始化零消费者）→ 表源
`n3v2_base.toml` 删两行 → n3gen 再生 → cp `n3.mbt`（G9 路）；`RuleSide` 枚举连坐删。
`iri_upcast` **翻案为活机制**（`n3v2_trans.toml` expr 消费 + `iver` 快照回读），ctx 卷
原列死位系误诊，ARCHITECTURE.md 预留位清单正名登记。

**改动面**：嵌套仓 17 文件 +33/−88（engine 双 impl 块 `impl[L]` 去界 / trig `fn[L]` 去界 /
materialize 死 helper 删 + has_prefix×4 / serialize `_self` / rdf_suite 去 `name` 参 /
n3tests `to_owned` / 五 moon.pkg 减导 / types.mbt RuleSide+注释块删 / n3.mbt 再生 /
ARCHITECTURE.md 新增 / guides 两件 / mbti 刷新）；外层仓 n3v2_base.toml + n3v2_out.gen。

**文档三件**：①`ARCHITECTURE.md` 一页（五层/生成链/I-1..9/术语/预留位清单）；
②guides/n3 README+syntax 与 mbti 实形对齐（包名/`N3SliceParser`/`N3Materializer::new`
构造形/效果枚举实名/ctx 字段清单）；③役21 跨卷注记（役21 落外层 `src/fsm/toml.md`，
本卷不重复立条）。附带 spec §1 陈数同步（27 字段/116 测试/I-6 收敛后）。

**验收数字**：`moon check` 0 warning；gen_n3v2 116/116；turtle 316/316(gap5)、rdf12 75/75(gap0)、
trig 357/357、nquads 89/89+29/29+27/27+72/72、N3Tests neg 23ok/0miss + 205clean(gap123)、
examples A13(gap13)——全套件数字不变；G9 n3gen 9/9（再生链走通）；fmt 幂等；mbti = 死位删除面
（两字段 + RuleSide 枚举）。

**教训**：①`moon.pkg` 警告行号锚先 cat 对准再删（cmd :3 是 debug 非 argparse，错杀回补后
[0029]→[0071] 才现形真相）；②同 trait 多 impl 块约束一致（单块去界报 Inconsistent impl）；
③死字段定性先 grep 表源 expr（`iri_upcast` 活）；④guides 修示例以 mbti 为准逐条对
（`materialize_all` 旧自由函数形全仓无对应物；nquads/trig 同名 `SliceParser` 是实名）。

---

## ADR-27：役27a 测试归位 + fr 改名（R-11 全落 + R-10 部分）——✅ 2026-09-11

**范围**（勘察定案拆 27a/27b，本役只做零 API 抖动半）：`fr → frame`（actions.mbt 71 处词边界，
勘察 72 系 grep -c 数行不数处）；27 个内联 test 迁双新件（`materialize_n3_wbtest.mbt` 538 行 /
`serialize_n3_wbtest.mbt` 64 行），生产件 1396/101 行纯实现。

**命名实落微调**（对勘察命名表的偏离，均 0-warning/语义门强制）：
①`mat_vs` 未直换 `view_str`——两者语义不同（decode_lossy vs 逐字节 to_char，多字节必烂）；
先归一 view_str 本体为 decode_lossy 子视图解码（ASCII 站点输出不变，役24 多字节钉全绿证零涟漪），
再复用；②`mat_subj/mat_obj` 不止改名——收编为 `emit_subject/emit_object` 返 String，
直吸 `mat_vs∘mat_*` 73 组合，另立 `emit_predicate` 吸 32 处 `.predicate` 直取；
③`mat_empty` 组合收编后零消费者，0-warning 门强制除名（未立 empty_bytes）；
④`mat_deferred` 勘察时已亡（役17）。跨文件消费（n3_wbtest 4、engine_wbtest 6）同笔改。

**验收**：`moon info` 零 diff（fmt 后复验）+ `moon check` 0 warning + 116/116 + fmt 幂等；
mat_* 旧名残留 3 处均刻意史注。27b（`pver/bver/iver`、`Hooks`、trig 同笔）并役28 一次抖动。

**教训**：grep -c 数行不数处（断言用 findall 计数）；复用前先对语义（名异实异盲替 = 多字节断言
静默变 mojibake）；组合收编消灭双写（返 String 吸组合优于逐点 view_str 化）；迁移脚本原子纪律
（两次 assert 失败均零写盘）。

## ADR-28：役28 27b 改名 + R-08 公共面收窄 + R-13 组清（题2=B、题5=A）——✅ 2026-09-11

**27b 改名**：`pver/bver/iver → prefix_version/base_version/iri_version` 改表 3 行
（`n3v2_base.toml` snapshot_extras name，expr 引 `prefixes/bases/iri_upcast` 不涉自身）→ G9
再生 → cp；本包 70 处（勘察 112 系 grep 行数口径，findall 实数）。`Hooks → N3ActionsImpl`
102 处 + `engine.mbt` 字段 `hooks → actions`。**N3PendingQuad 不降**——`N3Engine::next`
公共载荷（27b 待裁项）。trig 同笔改 66 处（pver 26 + bver 40，无 iver）+ 三层表源同笔
（`fsm_out/trig_fsm` + `domain2/trig_base` + `domain/trig_domain`）；`trig.mbt` 冻结件手编
4 处（役8 手工领先先例，再生仍禁）。

**R-08（题2=B）**：FSM 机械全降包内。生成件经 emit.mbt 模板 `priv` 化再生交付（N3State/
N3Effect/N3Context/ResetScope/N3ActionError/N3Effect 族/三 trait/step；`priv fn` 不存在——
[3005]，函数默认包内即裸 fn）；用户层 `N3ActionsImpl`/Slot 族/`slice_span`/`n3_parser` 手降；
Engine/LexerAdapter 私有字段走字段级 `priv`（`priv mut pending` 等，mbti 出 `// private
fields` 段）。数据面保留：QuadSpan/N3PendingQuad/PredKind/N3Dialect/N3Event（LexerSource
pub 契约的载荷——LexerSource 是引擎泛型 bound，链式要求 Event pub）/LexerSource/ErrOut。
裁据：全仓零外部消费者 + 扩展面外部本不可达（from_bytes 内建 actions）；外部切面将来经
`with_actions` 纯增量开。

**R-13（题5=A）**：组清方法形式，表平铺生成器零改。`clear_annotation` 四件套 ×3 消费点
（settle_annotation/begin_record/recover_cleanup）+ `clear_path` 三槽 ×4 发射点；
keywords/directive/inversion 零成组清账现场不立项（役23 投机面判据）；[[context.groups]]
表分节 B 留账。

**死码顺带清**（pub 豁免消失后 [0001]/[0003] 暴露）：`IRIUpcastEvent`（零消费，机制故事留
iri_upcast 字段与 ARCHITECTURE 预留位）、`SlotNodeId`（零消费）、`Show for N3Event`（零消费，
`core/debug` 导入随之出包）、`EffectHandler::snapshot` 死套（trait 行+默认 impl，interpret
唯一解释器后无人调）。

**验收**：mbti `pub` 55→29 行，diff 一次性全对预期；0 warning 嵌套仓全模块；329/329；
套件钉全绿（turtle 316/316 gap5、rdf12 75/75 gap0、trig 357/357、nquads 89/89+29/29+27/27+
72/72、N3Tests neg 23ok/0miss + pos+eval 205clean gap123、examples A13 gap13）；G9 9/9；
fmt 幂等。外层 `src/fsm` 存量 111 警告非本役（stash 对照 HEAD 同数）。

---

## ADR-29：役29 R-15 数值/布尔单一实现 + R-04 短期补偿点单点台账——✅ 2026-09-11

**背景**：C-15 数值/布尔识别六处两套（`is_numeric_span` 字节孪生 ×2 + `bool_at` ×2 +
校验内联 ×2）；C-04 词法边界欠账"一次口径变动四处同步"（ADR-18 `^` 门实证）。

**裁断**：
1. **R-15 落 gen_nquads 而非账面建议的 n3v2 types.mbt**——侦察实证 trig
   `lexer_adapter.mbt:123` 有 `is_numeric_span` 字节孪生件，验收"has_digit 全仓一处"
   强制跨包；gen_nquads 是 gen_n3v2/gen_trig 公共依赖，识别件独此一份落 `numeric.mbt`
   （`is_numeric_span` 原文迁驻 + `is_boolean_word` 新增）。展开件 `expand_number`/
   `expand_boolean` 留驻各物化层——arena 发射是包内职责，识别才是共享面。
2. **`is_boolean_word` 收编六处布尔识别**：n3v2 adapter `eq_lower` 双臂并一、n3v2
   validate_term 内联 16 行、n3v2 `bool_at` 及其四处调用；trig adapter 内联双臂并一、
   trig validate_term 内联 16 行、trig `bool_at` 及其两处调用。`bool_at` ×2 删除（死码门）。
3. **R-04 短期 = 台账不搬家**：补偿点单点台账落 `lexer_adapter.mbt` 头注（六点地图
   ①[] merge ②?x peek ③@kw: 拆分 ④<- 拆字 ⑤langtag 拆分 ⑥engine trim_trailing_punct
   三瓣 + 各自钉面清单）；engine `normalize_term_span` 交叉引用回指。
   **不移 trim**——engine 七臂与 kw_a_live/version_lit_ok 旗标交织，移动无益于欠账本体
   （欠账 = Lexermoon 口径变动波及四层，可见性才是短期解）；**不动 Lexermoon/C**——
   C 侧 2026-09-04 分歧口径已冻结，parity 电池不含分歧形态，扩容无收益。

**改动面**：gen_nquads/numeric.mbt（新建）；n3v2 lexer_adapter（台账头注 + 收编 + 删
本地件）/parser_slice/materialize_n3（删 bool_at）/engine（交叉引用）；trig lexer_adapter
（收编 + 删本地件）/parser_slice/materialize_trig（删 bool_at）；nquads
pkg.generated.mbti +2 行（两 pub fn）。

**验收**：`rg "has_digit" src` 全仓单点；parity 零差（对比 72 段 mismatch=0）；
nquads 124/124（89/89+29/29+27/27+72/72）、trig 357/357、n3v2 116/116（turtle 316
gap5、rdf12 75 gap0）、模块 329/329；0 warning；fmt 幂等；三套件数字不变。

## ADR-30：役30 状态爆炸治理选型（R-14：A 生成器侧组合为主轴，B 否决，C 之门吸收）——✅ 2026-09-12

**背景**：spec §10（役30a）量化实证——交叉族态 36/55 = 65%、求积产物 232/384 = 60%；
边际成本每新语境窗 ≈ +10 态 +50~80 行；声明面 `N3StateDef = { name, is_initial }`
无嵌套/语境元数据。手列模式与"加特性乘性改表"绑定，R-14 立案。

**三方案**：

- **A（采纳，主轴）——构建期 compose**：表源新增可选子机声明 + 接线挂点，
  n3gen 在 parse 之后 validate 之前增一个 **纯函数 compose 阶段（IR→IR 求积展开）**，
  把子机实例化为平表转移行，再走既有 validate/codegen。**产物 n3.mbt 字节不变（G9 锁）**。
  本质：子机 = 转移行生成宏，展开发生在构建期，运行时实体仍是 384 行平表——
  引擎、效果面、错误面零接触。
- **B（否决）——混合架构（语句核心表驱动 + `{}`/`()`/`[]` 运行时递归子自动机）**。
- **C（吸收为门 + 兜底）——不重构 + 分析门**：表保持手列，仅加 G10/G11 两门。

**B 否决理由（三条，均硬）**：
1. **违反红线**：重构产物必须逐字节等价（todo 红线，G9 即判据）——运行时递归改变
   生成件结构，n3.mbt 非字节等价，红线一票否决。
2. **平表假设遍布已收口的面**：R-02 interpret 唯一解释器（scope_chains + Sequence
   挂转移行）、R-05 error_spans/recover/drain、R-01 §5.1 归位清单（ret_state 直写 +
   pop 链形）全部以"平表 + 栈帧"为前提；递归子机 = 三面重写，风险与收益倒挂。
3. **行数不省**：子机仍需物化成转移（384 行一行不少），只是把复杂度从构建期
   （G 门可判、可复算、失败即红）移入运行时（失败后移到套件运行期）——纯劣化。

**变体一并否决**：MoonBit 宏编译期组合（宏面窄已裁；n3gen 本就是构建器，宏不增表达力）；
TOML 引用语法交 quick_machine 运行时解释（运行时解释器未落地，且同样非字节等价）。

**C 的处置**：两门独立于 A 成立、必做（30e）——G10 族声明装配门（交叉族状态必须能由
机制×窗求积解释，防手列漂移）+ G11 可达性门（自初始态全 55 态可达、384 行无死行；
移植外层 `src/fsm/analyze.mbt`）。**兜底条款**：30c 探针若 G9 判不等价或求积引入行为差，
立即停 A 转 C（仅落 30e 两门，30d 全量迁移取消）。

**探针切片定义（30c）**：量化窗子机 = **5 态 13 行**（顶层：`QuantExpectVar`/
`QuantExpectVarOrDot` 2 态 + 接线 5 行；公式：`FormulaDirectiveKind`/`FormulaQuantExpectVar`/
`FormulaQuantExpectVarOrDot` 3 态 + 接线 8 行——行清单见 spec §10.1 复算脚本同源，
`from/to` 触量化族∪公式指令头共 13 行）。子机声明 + 删 13 行手列 → compose 求积还原 →
G9 黄金门直接判字节等价。

**回灌条款（役30 明确要求）**：探针通过后，compose 概念回灌外层 `src/fsm` 生成器线——
`StateMeta` 的 `is_nestable`/`exit_event` 元数据位已备而未用，src/fsm 侧缺的正是构建器
求积；回灌 = n3gen compose 经验反哺 src/fsm 构建器 + `src/fsm/toml.md` 键文档同步。

**改动面**：30b 本步零代码。后续 30c/30d 改 `src/rdf/n3gen/n3v2_base.toml`（新键全可选，
TOML 契约兼容）+ n3gen 构建器（compose 纯函数）+ `n3v2_trans.toml`（手列行按族退役，
最后一步才删）；30e 加 `src/fsm/analyze.mbt` 移植。

**验收**：本 ADR 落卷；30c 探针 G9 字节等价或触发兜底条款；30d 每族一步 G9 + 329/329；
30e 后 G1–G11 全绿；终态"新增特性只增子机声明 + 接线、零手列交叉态"。
