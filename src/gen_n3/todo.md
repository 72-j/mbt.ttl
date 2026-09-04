# gen_n3 战役待办

基座裁决（2026-09-04）：
- 词法/数据结构复用 gen_nquads（`pub using @nquads` 在 types.mbt：Token / Lexermoon /
  ParseError / Span / TermType——非 pub using 是文件作用域，跨文件不可见）；
- N3 作为方言做在 gen_n3 包，管线同源 trig（n3_domain.toml + domain_to_ir n3 臂 →
  fsm_out → CLI 再生）；
- ADR-003 拆分：**003a** 集合语法 `( ... )` → 单一 BNode（不展开 rdf:first/rest，
  **不 skolemize**）；**003b** 显式链（文档显式写 rdf:first/rdf:rest）→
  iver/IRIUpcastEvent 适用（快照槽仅服务此路径）；
- N3Literal 双载荷 = 文本 + 语言标签（词法期拆分，与集合解耦）；`^^dt` 折文本 span
  物化层拆；
- 类型面冻结先于词法先行；状态面只落顶层骨架（嵌套族随表役词表落）。

---

## Step 1 基础面冻结（n3.mbt）——✅ 2026-09-04

- [x] N3Event 31 变体（对照 TrigEvent 34 对账：删 GraphKw/VersionKw/Tilde/
      AnnotStart/End，增 Variable/Equals/Anon/Comma/Semicolon/Dot/BaseKw/
      ForAllKw/ForSomeKw/KeywordsKw/Unknown/EOF）
- [x] N3Context（trig [[context]] 基座 11 字段 + variable_name/path_chain/
      rule_side/iri_upcast）+ RuleSide 枚举
- [x] ADR-003a/b 注释落裁：PredKind 恒 Normal（无合成链，保留为管线同源布局）；
      IRIUpcastEvent 仅显式链；SlotType::Collection 单一 BNode 不 skolemize
- [x] N3Literal(Span, Span?) 双载荷口径注释
- [x] 状态面：顶层 6 态骨架（ExpectSubject 族）+ 待表役注释

## Step 2 词法先行（lexer_adapter.mbt）——✅ 2026-09-04

- [x] 克隆 trig 7 函数：token_to_n3_event / classify_structural / is_numeric_span /
      classify_prefname / at_style_kw / eq_lower / eq_ignore_case
- [x] N3 增量：`?x` 三则判定（`?x`→Variable、裸 `?`→Unknown、`??x`→不吞词；
      peek 失配 token 转事件入 pending 槽不丢）；langtag 词法期拆分（收引号锚定，
      恰覆盖子标签不含 @；三引号含 lone-quote 退化不拆，物化层权威）；
      `[]` → N3Anon peek-merge（trig 战役①同款）；
      `@forAll/@forSome/@keywords` → *Kw；裸 `is`/`of` 保 PrefName
- [x] LexerSource impl（engine.mbt trait；next / pos / byte_at，EOF 单次送达，
      @ 指令冒号拆分槽）

## Step 3 wbtest 事件流钉死——✅ 2026-09-04（7/7，探针实测口径）

- [x] N3 特有流：?x / 裸 ? / ??x / `:a!:b` / `:a^:b` / `=>` / `<=` / `=` /
      `{ } => { } .` / langtag 拆分（含 en-GB / 单引号 / 空串 / 三引号退化 /
      内容 @）/ ^^dt 折文本 / `[]` / `( )` / bnode / TT / @prefix 零空格拆分槽 /
      @base / @forAll / @forSome / @keywords / is·of / 垃圾词降 Unknown / `~`→Unk
- [x] turtle 核回归流（`,`/`;` 链、数值、布尔、EOF 单次枯竭）
- 探针实测三事实（probe_tmp 已删，口径入 wbtest 注释）：`?x` = Unk+邻接 Pref 两
  token；Literal token span 整段吞 `@lang`/`^^dt`；**Lexermoon 吞边界是故意口径**
  （词法自测 747 行钉死：langtag/数值零空格后随 `,`/`.` 字节入 span 且标点事件
  丢失；turtle 套件零命中故 trig 未踩）

## Step 4 表役：trig 词表克隆 → n3 词表（进管线）——✅ 管线半役 2026-09-04

- [x] domain_to_ir 加 n3 臂：17 状态 / 31 事件 / 7 效果 / **87 行转移**
      （trig 195 减图块/注解/~ /VERSION 四族；Literal 双载荷
      `N3Literal(Span, Span?)` 派发模式 `(payload0, _)` 只绑文本 span）
- [x] n3_domain.toml 人类域层（15 动作 = 13 表驱动 + 2 声明面直调
      pop_bnode_prop/open_slot；15 字段；4 快照槽 pk/pver/bver/iver；
      2 枚举）+ n3_domain_toml_gen.mbt 对照（手工 ≡ 词表生成，doc 逐字对账）
- [x] 管线三新件：①codegen 多载荷事件补齐（枚举变体逐字段实参、模式
      `(payload0, _)` 忽略尾、动作参数取首字段——arity-1 字节不变，
      trig 再生 diff 仅时间戳行硬证明）；②emit_enums 管线
      （domain toml [[dialect.X.enums]] → fsm toml → 生成文件，
      恒发 derive(Eq)——PredKind 需 Eq 支撑 N3PendingQuad）；
      ③**枚举 emit 开关**（emit = false = 仅记账不发射，手写面持有防类型
      冲突；N3Dialect 归还 types.mbt 成活例，PredKind 生成器发射成对照；
      domain_config_matches 逐枚举对账含 emit）
- [x] CLI 再生 n3.mbt（780 行）；diff 冻结稿对账收敛：状态变体 N3 前缀化、
      生成枚举无 derive 之外的注释差、QuadSpan/SlotType/Slot/IRIUpcastEvent/
      RuleSide/SlotNodeId 手写面归 types.mbt
- [x] 回归全绿：rdf 16/16；gen_n3 7/7（wbtest 事件流过再生契约）；
      gen_trig+gen_nquads 210/210（含 W3C 89/89）；trig_fsm.toml 增
      [dialect.trig] 段而 trig.mbt 字节稳定（fsm 既有债 9 失败同 HEAD）
- [ ] **引擎半役（下一役）**：engine.mbt 补 normalize_term_span +
      trim_trailing_dot（**扩 Comma/Semicolon 合成**——trig 只 trim dot，
      `"x"@en,` 吞逗号套件没踩过，N3 objectList 必踩）；actions/slice/
      materializer 克隆（~3000 行）
- [ ] 验收 = W3C turtle 套件过 gen_n3 引擎（复用 gen_trig/rdf-tests/rdf-turtle）

## Step 5 N3 特性逐战役走表

- [ ] formula `{}`（ADR-002 不断言）→ variable `?x`（ADR-004）→
      path `!/^`（ADR-006）→ rule `=>/<=`（ADR-005）→ `@keywords`
- [ ] 每役 = 表行 + action 声明 + 手写 action 体（trig ★8 后三役打法）

## Step 6 管线收尾

- [ ] 再生幂等验证（时间戳行外字节稳定，trig ★8 方法论）——n3 侧首证已落：
      Step 4 trig 再生 diff 仅时间戳行；n3 待引擎半役后同法复验
- [x] gen.md §5.2 "后坐力任务"措辞随 ADR-003a 定案退役（2026-09-04）
