// ===== 用户补充：N3 主循环引擎（薄机械层，trig engine.mbt 同模板） =====
// 职责切分（与 trig/nquads engine.mbt 同宪法）：
//   - 本文件只做状态机机械：驱动 step、按 Effect 意图执行（发射 snapshot+按
//     scope 重置、PopBnp/OpenSlot 意图兑现）、错误恢复、EOF 判脏收尾。
//   - 切片组装/验证/物化全部上移 SliceParser；层间只传 span 快照（N3PendingQuad）。
//   - 与 trig 模板的差异点（均有据可查）：
//     1) 无图块/注解/VERSION 族：recover 只停 Dot（N3 无 Rbrace 前界语义，
//        Rbrace 无表行）；无 directive_ok（无版本字面量状态）。
//     2) **扩 Comma/Semicolon 合成**（2026-09-05 定案）：Lexermoon 吞边界口径
//        下 langtag/数值零空格后随 `,`/`.`/`;` 字节入 span 且标点事件丢失
//        （词法自测 747 行钉死；trig 只 trim dot，N3 objectList/predicateObjectList
//        必踩）——trim_trailing_punct 三瓣裁决 + synth 事件回灌转移表。
//     3) Sequence 串列：顺序解释（BnpAfterObject+Rbracket =
//        [EmitQuad(PredObj), PopBnp]）；集合族无链发射（ADR-003a），串列更薄。
//     4) EOF 判脏自排水：同 trig（无 per-next 反向复位点，finish 自清防无限重报）。

///|
/// 词法源 trait：仅约束"逐 token 推进"的运行时接口（trig engine.mbt 同款）
/// 实现：N3LexerAdapter（lexer_adapter.mbt，包 @nquads.Lexermoon）
pub trait LexerSource {
  fn next(Self) -> N3Event? // 换行/注释已过滤；数据尾以 N3EOF 合法送达一次，其后 None=枯竭兜底
  fn pos(Self) -> Int // 当前词法位置（兜底错误定位用）
  fn byte_at(Self, Int) -> Byte // 数据直查（词内尾点裁决用）
}

///|
/// 事件载荷 span 提取：无 payload 事件给 (0,0)（UnexpectedEvent 兜底定位，
/// loop 会再用 lexer.pos() 补全真实位置）
fn span_of_event(event : N3Event) -> Span {
  match event {
    N3Iri(span) => span
    N3BlankNode(span) => span
    N3Literal(span, _) => span // 双载荷取文本 span（langtag 子 span 随行）
    N3PrefName(span) => span
    N3TripleTerm(span) => span
    N3BracketTripleTerm(span) => span
    N3KeywordA(span) => span
    N3KeywordX(span) => span // 役5：listed 裸词（引擎合成，span 即词）
    N3Variable(span) => span
    N3Lbracket(span) => span
    N3Anon(span) => span
    N3Lparen(span) => span
    N3Lbrace(span) => span
    N3Bang(span) => span // 路径操作符 span = 中间节点 fresh 身份（役3）
    N3Caret(span) => span
    N3Implies(span) => span // 规则操作符 span = 规则谓词身份（役4）
    N3ImpliedBy(span) => span
    N3Equals(span) => span // 役7：= token span 占谓词槽（pk=SameAs 身份）
    N3Is
    // 役6 倒装引导符（bare，错误兜底位置由词法位置回填）；Has 役11 同款 bare
    | N3Of
    | N3Has
    | N3Id
    // 役16 B 桶：id 引导符（bare）
    | N3Invert
    // 役16 A 桶：`<-` 倒装引导符（bare）
    | N3At
    | N3PrefixKw
    | N3BaseKw
    | N3VersionKw
    | N3Tilde
    | N3AnnotStart
    | N3AnnotEnd
    | N3ForAllKw
    | N3ForSomeKw
    | N3KeywordsKw
    | N3Comma
    | N3Semicolon
    | N3Dot
    | N3Rbrace
    | N3Rbracket
    | N3Rparen
    | N3EOF => (0, 0)
    N3Unknown(span) => span // 役5 载荷化：兜底词项 span 供台账比对
  }
}

///|
/// 词内尾标点裁决（trig trim_trailing_dot 扩 Comma/Semicolon 三瓣）：
/// 无脑扫把语句点/逗号/分号吞进词尾（`<s>.` / `"x"@en,` / `1;`）时剥离尾字节，
/// 由 loop 合成对应事件回灌转移表（决策仍在表，机械在此）。
/// 返回 (剥后 span, 待合成事件?)。
fn[L : LexerSource] trim_trailing_punct(
  lexer : L,
  span : Span,
) -> (Span, N3Event?) {
  let (off, len) = span
  if len > 0 {
    match lexer.byte_at(off + len - 1) {
      b'.' => ((off, len - 1), Some(N3Event::N3Dot))
      b',' => ((off, len - 1), Some(N3Event::N3Comma))
      b';' => ((off, len - 1), Some(N3Event::N3Semicolon))
      _ => (span, None)
    }
  } else {
    (span, None)
  }
}

///|
/// versionSpec 形态嗅探（RDF 1.2：STRING_LITERAL_QUOTE | SINGLE_QUOTE）：
/// 单/双引号起头（同字符配对）、非三引号、无 @lang/^^dt 后缀。仅写旗标
/// 不决策——消费点在表行 guard（ExpectVersionLiteral），守卫不过与缺行同径。
fn[L : LexerSource] is_version_lit_form(
  lexer : L,
  span : Span,
  lang : Span?,
) -> Bool {
  let (off, len) = span
  let q = lexer.byte_at(off)
  if len < 2 || !(q == b'"' || q == b'\'') {
    return false
  }
  if len >= 3 && lexer.byte_at(off + 1) == q && lexer.byte_at(off + 2) == q {
    return false
  }
  if lang is Some(_) {
    return false
  }
  let mut i = off + 1
  let end = off + len
  while i < end {
    let c = lexer.byte_at(i)
    if c == b'@' || c == b'^' {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// 役5 台账命中：候选词与台账某条目字节全等（@keywords listed 词判定）。
/// 纯机械比对——词性决策仍在表行（KeywordX 行 / 兜底 UnexpectedEvent 同径）。
fn[L : LexerSource] N3Engine::kw_ledger_hits(
  self : N3Engine[L],
  word : Span,
) -> Bool {
  let (off, len) = word
  if len == 0 {
    return false
  }
  let mut k = 0
  while k < self.ctx.kw_ledger.length() {
    let (loff, llen) = self.ctx.kw_ledger[k]
    if llen == len {
      let mut same = true
      let mut i = 0
      while i < len {
        if self.lexer.byte_at(off + i) != self.lexer.byte_at(loff + i) {
          same = false
          break
        }
        i = i + 1
      }
      if same {
        return true
      }
    }
    k = k + 1
  }
  false
}

///|
/// 役20 负例收口：`this` 为套件 deprecated 关键词（manifest "'this' keyword
/// is deprecated - negative test"）——@keywords 台账命中也拒绝晋升，永远保
/// Unknown（无表行 → UnexpectedEvent，错误落使用点）。正例 ref 文件全用
/// @forAll，裸 `this` 零出现，零涟漪。
fn[L : LexerSource] is_deprecated_this(lexer : L, span : Span) -> Bool {
  let (off, len) = span
  if len != 4 {
    return false
  }
  let word = b"this"
  let mut i = 0
  while i < 4 {
    if lexer.byte_at(off + i) != word[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// 吞边界口径的引擎层修正：七类带 payload 术语事件做尾标点三瓣裁决，
/// 其余事件原样直通（结构 token 词法干净，无吞并口径）。
/// 返回 (修正后事件, 待合成事件?)——待合成事件由 loop 在本事件处理完后喂表。
fn[L : LexerSource] N3Engine::normalize_term_span(
  self : N3Engine[L],
  event : N3Event,
) -> (N3Event, N3Event?) {
  match event {
    N3Iri(span) => {
      let (s2, synth) = trim_trailing_punct(self.lexer, span)
      self.ctx.kw_a_live = false // 役5：他谓词到场即熄（set_predicate 消费制）
      (N3Iri(s2), synth)
    }
    N3BlankNode(span) => {
      let (s2, synth) = trim_trailing_punct(self.lexer, span)
      self.ctx.kw_a_live = false
      (N3BlankNode(s2), synth)
    }
    N3Literal(span, lang) => {
      // 文本 span 裁决；langtag 子 span 恰覆盖子标签不含 @，不触标点
      let (s2, synth) = trim_trailing_punct(self.lexer, span)
      // VERSION guard 旗标：引擎归位点词法嗅探（纯形态标记，决策仍在表行 guard）
      self.ctx.version_lit_ok = is_version_lit_form(self.lexer, s2, lang)
      self.ctx.kw_a_live = false
      (N3Literal(s2, lang), synth)
    }
    N3PrefName(span) => {
      let (s2, synth) = trim_trailing_punct(self.lexer, span)
      self.ctx.kw_a_live = false
      (N3PrefName(s2), synth)
    }
    N3TripleTerm(span) => {
      let (s2, synth) = trim_trailing_punct(self.lexer, span)
      self.ctx.kw_a_live = false
      (N3TripleTerm(s2), synth)
    }
    N3KeywordA(span) => {
      let (s2, synth) = trim_trailing_punct(self.lexer, span)
      // 役5：a 失效——@keywords 声明后未列出 → 裸名降 PrefName（物化层按
      // DefaultPrefixIRI 展开）。声明列表区内不重裁定（收词原样入账）
      if !(self.ctx.state is N3State::N3ExpectKeywordsList) &&
        self.ctx.kw_directive_seen &&
        !self.kw_ledger_hits(s2) {
        self.ctx.kw_a_live = false
        (N3PrefName(s2), synth)
      } else {
        // 活性随行记账：kept → set_predicate 消费落 pk=KwA；声明列表区内
        // passthrough 不置位（declare_keyword 非谓词消费）
        self.ctx.kw_a_live = !(self.ctx.state is N3State::N3ExpectKeywordsList)
        (N3KeywordA(s2), synth)
      }
    }
    N3Unknown(span) => {
      let (s2, synth) = trim_trailing_punct(self.lexer, span)
      // 役5：listed 裸词再分类——台账命中即 KeywordX（词性 = 词，决策仍在表
      // 行；未列入台账保 Unknown 兜底，bad-*-05 口径不变）
      self.ctx.kw_a_live = false
      // 役20：`this` 已 deprecated（manifest 判负口径），台账命中也不晋升
      if self.kw_ledger_hits(s2) && !is_deprecated_this(self.lexer, s2) {
        (N3KeywordX(s2), synth)
      } else {
        (N3Unknown(s2), synth)
      }
    }
    other => (other, None)
  }
}

///|
/// 统一取数：先取恢复推回的单 token，再问词法器
///（N3EOF 合法送达一次由适配器保证；推回槽只存结构 token，永不存 N3EOF）
fn[L : LexerSource] N3Engine::pull(self : N3Engine[L]) -> N3Event? {
  match self.pending {
    Some(ev) => {
      self.pending = None
      Some(ev)
    }
    None => self.lexer.next()
  }
}

///|
/// N3Engine[L] - 驱动生成的 step 状态机（薄机械层，不持有 data）
/// 词法器可插拔：L = N3LexerAdapter（当前唯一实现）
pub struct N3Engine[L] {
  lexer : L
  hooks : Hooks
  ctx : N3Context // mutable 契约：ctx 原地推进（reset/step 原地写）
  dialect : N3Dialect // 方言开关（N3 默认扩展；RDFStarOff 暂不开放，预留构造位）
  mut last_error : Span? // 最近一次错误位置（行号由上层按 data 统计）
  mut pending : N3Event? // 恢复推回的单 token（预留：恢复前界机制的兑现位）
  emit_queue : Array[N3PendingQuad] // Sequence 多发射队列：FIFO，next() 顶部优先排空
}

///|
/// 创建引擎（词法器由调用方注入；begin_record 仅此一次——N3 状态连续，
/// 前缀/Base 账本跨语句存续，与 trig 同口径）
pub fn[L : LexerSource] N3Engine::new(
  lexer : L,
  dialect? : N3Dialect = N3,
) -> N3Engine[L] {
  let engine = N3Engine::{
    lexer,
    hooks: Hooks::new(),
    ctx: N3Context::new(),
    dialect,
    last_error: None,
    pending: None,
    emit_queue: [],
  }
  engine.begin_record()
  engine
}

///|
/// 纯 MoonBit 词法（N3LexerAdapter 包 @nquads.Lexermoon）版
pub fn N3Engine::from_bytes(
  data : Array[Byte],
  dialect? : N3Dialect = N3,
) -> N3Engine[N3LexerAdapter] {
  N3Engine::new(N3LexerAdapter::new(data[:]), dialect~)
}

///|
/// 上下文当前覆盖范围（错误报告定位）
fn ctx_span(ctx : N3Context) -> Span {
  let subj = ctx.subject.unwrap_or((0, 0))
  let obj = ctx.object.unwrap_or((0, 0))
  let start = subj.0
  let end = obj.0 + obj.1
  (start, end - start)
}

///|
/// 记录错误位置（行号不在此统计：engine 不持有 data，由 SliceParser 计）
fn[L] N3Engine::record_error(self : N3Engine[L], span : Span) -> Unit {
  self.last_error = Some(span)
}

///|
/// ADR-002 引擎不变量：slot_stack 存在 Formula 帧 = 处在公式内容区。
/// 罩内 EmitQuad 意图降级为纯收拾（只 reset 不 snapshot 上抛）——公式
/// 状态自身零 EmitQuad 行（决策在表），此为共享区域行（Bnp/集合收口
/// Sequence、Comma/Semicolon 穿罩复用）的单点压制位，机械归模板。
fn under_formula(ctx : N3Context) -> Bool {
  for f in ctx.slot_stack {
    if f.typ is SlotType::Formula {
      return true
    }
  }
  false
}

///|
/// N3LoopPolicy 实现（Engine 持有 lexer/ctx/last_error，钩子落在此处）

///|
/// 入口重置策略：仅构造时一次（空 ctx 已是初始态；保留位——流式重建时用）
impl[L : LexerSource] N3LoopPolicy for N3Engine[L] with fn begin_record(
  self : N3Engine[L],
) -> Unit {
  self.ctx.reset(ResetScope::All)
  self.ctx.prefix_name = None
  self.ctx.slot_stack.clear()
  self.ctx.pred_kind = Normal
  self.ctx.state = N3ExpectSubject
  self.ctx.annot_s = None
  self.ctx.annot_o = None
  self.ctx.subj_shell = false
  self.ctx.annot_close = false
}

///|
/// 错误恢复策略：登记 → 消费到 Dot → 归位 ExpectSubject。
/// N3 无图块：Rbrace/Rparen 均无前界语义（Rbrace 无表行；Rparen 只在集合区域
/// 合法，区域随 slot_stack 清空失效）。state 归位是恢复语义的一部分；
/// 不经转移表（错误不在表中表达）。
impl[L : LexerSource] N3LoopPolicy for N3Engine[L] with fn recover(
  self : N3Engine[L],
  span : Span,
) -> Unit {
  self.record_error(span)
  self.ctx.slot_stack.clear()
  self.ctx.pred_kind = Normal
  self.ctx.is_src = None // 役6：倒装交换键随错回收
  self.ctx.annot_s = None // 役8：注解壳账随错回收
  self.ctx.annot_o = None
  self.ctx.subj_shell = false
  self.ctx.annot_close = false
  self.consume_to_recover_point()
}

///|
/// 恢复消费机械：只停 Dot（回 ExpectSubject，语句全清）。EOF 兜底归 finish_at_end。
fn[L : LexerSource] N3Engine::consume_to_recover_point(
  self : N3Engine[L],
) -> Unit {
  let mut synth : N3Event? = None
  for ;; {
    let event = if synth is Some(ev) {
      let ev = ev
      synth = None
      ev
    } else {
      match self.pull() {
        None | Some(N3Event::N3EOF) => {
          // EOF：归位交 finish_at_end 判脏；此处只收拾槽位
          self.ctx.state = N3ExpectSubject
          self.ctx.reset(ResetScope::SPO)
          return
        }
        Some(ev) => {
          let (ev2, synth_ev) = self.normalize_term_span(ev)
          synth = synth_ev
          ev2
        }
      }
    }
    if event is N3Event::N3Dot {
      self.ctx.state = N3ExpectSubject
      self.ctx.reset(ResetScope::All)
      return
    }
  }
}

///|
/// EOF 判脏策略：state 未归位或槽位脏 → 报错并自清（防 parse_all 无限重报：
/// 无 per-next 复位点，finish 自排水）
impl[L : LexerSource] N3LoopPolicy for N3Engine[L] with fn finish_at_end(
  self : N3Engine[L],
) -> Result[N3PendingQuad, ParseError]? {
  // DirectiveEnd 算干净终态：SPARQL 风格指令可无点直接收文件
  let state_ok = self.ctx.state is N3State::N3ExpectSubject ||
    self.ctx.state is N3State::N3ExpectDirectiveEnd
  if !state_ok || self.ctx.has_pending() || self.ctx.slot_stack.length() > 0 {
    let err : ParseError = ParseError::SyntaxErr(
      "Incomplete triple at end of input",
      ctx_span(self.ctx),
    )
    // 自排水：报告一次即归零，下一次 next() 返回 None 终止 parse_all
    //（栈必须同清：否则栈脏判定把排水重新点燃 = 错误无限循环）
    self.ctx.reset(ResetScope::All)
    self.ctx.prefix_name = None
    self.ctx.slot_stack.clear()
    self.ctx.pred_kind = Normal
    self.ctx.is_src = None
    self.ctx.annot_s = None
    self.ctx.annot_o = None
    self.ctx.subj_shell = false
    self.ctx.annot_close = false
    self.ctx.state = N3ExpectSubject
    Some(Err(err))
  } else {
    None
  }
}

///|
/// 错误装配策略：BusinessFailed 消息 → ParseError
impl[L : LexerSource] N3LoopPolicy for N3Engine[L] with fn on_business_failed(
  self : N3Engine[L],
  message : String,
) -> ParseError {
  ParseError::SyntaxErr(message, ctx_span(self.ctx))
}

///|
/// 模板内方法可见性：把 LoopPolicy 四钩子提升为 N3Engine 的扩展方法
extend N3Engine with N3LoopPolicy::{
  recover,
  begin_record,
  finish_at_end,
  on_business_failed,
}

///|
/// is/of 倒装清账半边（役6）：非 Object 粒度且槽深与登记时齐平 = 语句级推进
///（分号续谓词 / Dot 收口 / 罩内同层收拾）——交换键归零；嵌套内层发射（槽深
/// 更深）不动外层账，倒装宾位的嵌套结构出账后外层照常互换。
fn[L : LexerSource] N3Engine::settle_inversion(
  self : N3Engine[L],
  scope : ResetScope,
) -> Unit {
  if !(scope is ResetScope::Object) &&
    self.ctx.slot_stack.length() == self.ctx.is_depth {
    self.ctx.is_src = None
  }
}

///|
/// 注解壳账收口半边（役8）：末体 quad 出账点（take）或公式罩内压位点消费
/// annot_close 旗——还原即清账（收口行 PredObj 粒度本就保锚主语在槽，`;` 续锚
/// 直落现状；体区旗/壳账四件套齐清，防旗漏后语句）
fn[L : LexerSource] N3Engine::settle_annotation(self : N3Engine[L]) -> Unit {
  if self.ctx.annot_close {
    self.ctx.annot_close = false
    self.ctx.subj_shell = false
    self.ctx.annot_s = None
    self.ctx.annot_o = None
  }
}

///|
/// 发射出账机械（役6 收口）：快照打包槽位 span；倒装交换键在场且挂起主语即
/// 倒装主语 → 主宾互换（`X is P of Y` grammar 序槽位、语义序 `Y P X` 出账
/// ——span 全局唯一 ⇒ 嵌套 bnp/集合内层 fresh 主语天然错键不换）；随后按
/// scope 粒度重置并走清账半边（逗号 Object 粒度保键连换）。
fn[L : LexerSource] N3Engine::take_pending_quad(
  self : N3Engine[L],
  scope : ResetScope,
) -> N3PendingQuad {
  let pending = self.ctx.snapshot()
  // 役8 注解壳交换：体区旗在场且挂起主语 == 锚主语（span 身份键，嵌套内层
  // fresh 主语错键不换）→ 主语改指壳 span（锚 s 起点至锚 o 终点的连续原文，
  // 物化层合成 <<原文>> TT 壳）；先壳交换后倒装交换，两键互斥不叠加
  let pending = if self.ctx.subj_shell && pending.subj == self.ctx.annot_s {
    match (self.ctx.annot_s, self.ctx.annot_o) {
      (Some(s), Some(o)) =>
        // 命中：主语改指壳 span + 壳旗随账（extra 直引已真，显式保真）
        { ..pending, subj: Some((s.0, o.0 + o.1 - s.0)), subj_shell: true, }
      (_, _) => pending
    }
  } else if self.ctx.subj_shell {
    // 错键不换（嵌套 bnp/集合内层 fresh 主语，役6 同款）：壳旗强制落假——
    // extra 直引自 ctx 会把体区旗漏挂到内层 quad 上
    { ..pending, subj_shell: false, }
  } else {
    pending
  }
  let pending = if self.ctx.is_src is Some(_) && pending.subj == self.ctx.is_src {
    { ..pending, subj: pending.obj, obj: pending.subj, }
  } else {
    pending
  }
  self.settle_inversion(scope)
  self.settle_annotation()
  self.ctx.reset(scope)
  pending
}

///|
/// 主循环（生成器固定模板 = 纯控制流分发器）：
/// 入口/终止 → step 步进 → Effect 分发 → 错误降级，四节点零领域逻辑。
/// 与 trig 模板的差异：无 EnterGraph/ExitGraph/ListStep 臂（N3 无图块，
/// 集合族 ADR-003a 无链推进）；扩 Comma/Semicolon synth 事件。
pub fn[L : LexerSource] N3Engine::next(
  self : N3Engine[L],
) -> Result[N3PendingQuad, ParseError]? {
  // 发射队列优先排空：Sequence 内多条 EmitQuad 逐条回吐（parse_next 再进 next()
  // 时从队列续取，事件流不丢不重）
  if self.emit_queue.length() > 0 {
    return Some(Ok(self.emit_queue.remove(0)))
  }
  let mut synth : N3Event? = None
  for ;; {
    let event = if synth is Some(ev) {
      let ev = ev
      synth = None
      ev
    } else {
      match self.pull() {
        None | Some(N3Event::N3EOF) => return self.finish_at_end()
        Some(ev) => {
          let (ev2, synth_ev) = self.normalize_term_span(ev)
          synth = synth_ev
          ev2
        }
      }
    }
    match step(self.ctx, event, self.hooks) {
      Ok(N3Effect::Continue) => continue
      Ok(N3Effect::PopBnp) => {
        // 弹栈恢复：`]` 空形式/空集合收口的裸意图，恢复机械在 action（帧携带返回状态）
        let _ = N3Actions::pop_bnode_prop(self.hooks, self.ctx)
        continue
      }
      Ok(N3Effect::OpenSlot(sp, typ, ret)) => {
        // 嵌套元素开帧：意图兑现机械在 action
        let _ = N3Actions::open_slot(self.hooks, self.ctx, sp, typ, ret)
        continue
      }
      Ok(N3Effect::Reset(scope)) => {
        // 纯收拾意图：不发射，仅按粒度重置槽位
        self.ctx.reset(scope)
        continue
      }
      Ok(N3Effect::EmitQuad(scope)) => {
        if under_formula(self.ctx) {
          // ADR-002：公式帧罩内发射意图 = 内容不断言——只收拾不上抛
          //（同层倒装账随壳消费：settle 清账半边，防 stale 键出罩）
          self.settle_inversion(scope)
          self.settle_annotation()
          self.ctx.reset(scope)
          continue
        }
        // 发射：take 打包槽位 span（倒装键在场 = 主宾互换，役6），按 scope
        // 粒度重置后上抛
        let pending = self.take_pending_quad(scope)
        return Some(Ok(pending))
      }
      Ok(N3Effect::Sequence(effects)) => {
        // 意图串列：顺序解释；EmitQuad 逐条入队（BnpAfterObject+Rbracket =
        // [EmitQuad(PredObj), PopBnp]：emit 先 snapshot 后收拾，恢复值来自帧），
        // 循环后队首上抛
        for effect in effects {
          match effect {
            N3Effect::EmitQuad(scope) =>
              if under_formula(self.ctx) {
                // ADR-002：公式帧罩内发射意图 = 内容不断言——只收拾不上抛
                //（同层倒装账随壳消费，防 stale 键出罩）
                self.settle_inversion(scope)
                self.settle_annotation()
                self.ctx.reset(scope)
              } else {
                let item = self.take_pending_quad(scope)
                self.emit_queue.push(item)
              }
            N3Effect::Reset(scope) => self.ctx.reset(scope)
            N3Effect::PopBnp => {
              // 意图兑现：`]` 收口序列的弹栈恢复，机械在 action
              let _ = N3Actions::pop_bnode_prop(self.hooks, self.ctx)
            }
            N3Effect::OpenSlot(sp, typ, ret) => {
              let _ = N3Actions::open_slot(self.hooks, self.ctx, sp, typ, ret)
            }
            N3Effect::Done => break
            N3Effect::Continue | N3Effect::Sequence(_) => ()
          }
        }
        if self.emit_queue.length() > 0 {
          return Some(Ok(self.emit_queue.remove(0)))
        }
        continue
      }
      Ok(N3Effect::Done) => return None
      Err(N3ActionError::UnexpectedEvent(_, event)) => {
        // 无转移兜底：取事件载荷位置（缺失则词法位置）；恢复策略在 LoopPolicy
        synth = None // 恢复消费整段，待发 synth 事件一并作废
        let span = span_of_event(event)
        let span = if span == (0, 0) { (self.lexer.pos(), 0) } else { span }
        self.recover(span)
        continue
      }
      Err(N3ActionError::BusinessFailed(message)) =>
        return Some(Err(self.on_business_failed(message)))
    }
  }
}
