// ===== 装配层补充（Assembly）：解析引擎主循环（薄机械层，与 nquads 同模板） =====
// 职责切分（与 nquads engine.mbt 同宪法）：
//   - 本文件只做状态机机械：驱动 step、按 Effect 意图执行（发射 snapshot+按
//     scope 重置、Enter/ExitGraph 通知）、错误恢复、EOF 判脏收尾。
//   - 切片组装/验证/物化全部上移 SliceParser；层间只传 span 快照（TrigPendingQuad）。
//   - trig 与 nquads 模板的差异点（均有据可查）：
//     1) 无 per-next begin_record：TriG 状态连续（图块/前缀账本跨 quad 存续），
//        begin_record 仅在引擎构造时调用一次（Supervisor 契约不变，实现换语义）。
//     2) Sequence 意图串列：loop 顺序解释，EmitQuad 组装上抛后继续执行余下意图
//        （`}` 前省点 = [EmitQuad(SPO), ExitGraph]）。
//     3) 恢复停在 Dot 或 Rbrace：图块内保 graph 槽位回 GraphExpectSubject；
//        顶层回 TrigExpectSubject。停在不消费的 Rbrace 前界，下一轮表格闭合图块。
//     4) EOF 判脏自排水：finish_at_end 报错后自清 ctx，防 parse_all 无限重报
//        （nquads 靠 begin_record 复位，trig 无 per-next 反向复位点，自清）。
//     5) Enter/ExitGraph 双语义收口（2026-09-02 定案：维持现状，文档收口，不引入
//        action_args 机制保持 TOML 表简洁）：ExitGraph 有两条路由——
//        a) 动作路径：TrigActions::exit_graph 直接返回该 effect → dispatch →
//           handle_exit_graph（`}` 前省点无待发射时）；
//        b) 串列路径：`}` 前省点有待发射 = Sequence([EmitQuad(SPO), ExitGraph])
//           → interpret 顺序解释，emit 组装上抛后经 on_exit_graph 钩子退图。
//        两条路由语义同源（退图通知），只是"有无 pending 发射"的机械差异；
//        EnterGraph 无 Sequence 嵌入形态，恒走动作路径。

///|
/// 词法源 trait：仅约束"逐 token 推进"的运行时接口
/// 实现：TrigLexerAdapter（lexer_adapter.mbt，包 @nquads.Lexermoon）
pub trait LexerSource {
  fn next(Self) -> TrigEvent? // 换行/注释已过滤；数据尾以 TrigEOF 合法送达一次，其后 None=枯竭兜底
  fn pos(Self) -> Int // 当前词法位置（兜底错误定位用）
  fn byte_at(Self, Int) -> Byte // 数据直查（词内尾点裁决用）
}

///|
/// 事件载荷 span 提取：无 payload 事件给 (0,0)（UnexpectedEvent 兜底定位，
/// loop 会再用 lexer.pos() 补全真实位置）
fn span_of_event(event : TrigEvent) -> Span {
  match event {
    TrigIri(span) => span
    TrigBlankNode(span) => span
    TrigLiteral(span) => span
    TrigPrefName(span) => span
    TrigTripleTerm(span) => span
    TrigBracketTripleTerm(span) => span
    TrigKeywordA(span) => span
    TrigLbracket(span) => span
    TrigAnon(span) => span
    TrigLparen(span) => span
    TrigAt
    | TrigPrefixKw
    | TrigBaseKw
    | TrigGraphKw
    | TrigVersionKw
    | TrigTilde
    | TrigAnnotStart
    | TrigAnnotEnd
    | TrigComma
    | TrigSemicolon
    | TrigDot
    | TrigLbrace
    | TrigRbrace
    | TrigRbracket
    | TrigRparen
    | TrigBang
    | TrigCaret
    | TrigImplies
    | TrigImpliedBy
    | TrigForAllKw
    | TrigForSomeKw
    | TrigKeywordsKw
    | TrigUnknown
    | TrigEOF => (0, 0)
  }
}

///|
/// 词内尾点裁决：无脑扫把语句点吞进词尾（<s>. / _:o.）时剥离尾点，
/// 由 loop 合成 Dot 事件回灌转移表（决策仍在表，机械在此）。
fn[L : LexerSource] trim_trailing_dot(lexer : L, span : Span) -> (Span, Bool) {
  let (off, len) = span
  if len > 0 && lexer.byte_at(off + len - 1) == b'.' {
    ((off, len - 1), true)
  } else {
    (span, false)
  }
}

///|
fn[L : LexerSource] TrigEngine::normalize_term_span(
  self : TrigEngine[L],
  event : TrigEvent,
) -> (TrigEvent, Bool) {
  match event {
    TrigIri(span) => {
      let (s2, dot) = trim_trailing_dot(self.lexer, span)
      (TrigIri(s2), dot)
    }
    TrigBlankNode(span) => {
      let (s2, dot) = trim_trailing_dot(self.lexer, span)
      (TrigBlankNode(s2), dot)
    }
    TrigLiteral(span) => {
      let (s2, dot) = trim_trailing_dot(self.lexer, span)
      (TrigLiteral(s2), dot)
    }
    TrigPrefName(span) => {
      let (s2, dot) = trim_trailing_dot(self.lexer, span)
      (TrigPrefName(s2), dot)
    }
    TrigTripleTerm(span) => {
      let (s2, dot) = trim_trailing_dot(self.lexer, span)
      (TrigTripleTerm(s2), dot)
    }
    TrigKeywordA(span) => {
      let (s2, dot) = trim_trailing_dot(self.lexer, span)
      // 役35 A1（R-T13/C-T13，照 n3v2 口径）：**N3 档**下，`@keywords` 已受理后
      // `a` **失效** —— 改写为 `TrigPrefName`（物化层按默认前缀展开），
      // 不再走 turtle 的 `a` = `rdf:type` 简写。TriG/Turtle 档**恒不失效**
      //（未声明档位口径 = `a` 仍是 `rdf:type` 简写；负例钉钉这个）。
      if self.dialect is N3 && self.kw_directive_seen {
        (TrigPrefName(s2), dot)
      } else {
        (TrigKeywordA(s2), dot)
      }
    }
    other => (other, false)
  }
}

///|
/// 指令位字节守卫（trim_trailing_dot 同族：词内字节裁决，决策仍归表/恢复）。
/// 状态相关、无状态适配器不可判的项落此处；不过 → UnexpectedEvent 同径恢复：
///   - 版本字面量只收短字符串：引号定界且非三连引号开壳（数值/布尔/长串拒——
///     version-bad-01..06 口径；同款 token 在宾语位合法，守卫须按状态裁）
fn[L : LexerSource] TrigEngine::directive_ok(
  self : TrigEngine[L],
  ctx : TrigContext,
  event : TrigEvent,
) -> Bool {
  match (ctx.state, event) {
    (TrigState::TrigExpectVersionLiteral, TrigEvent::TrigLiteral((off, len))) => {
      if len < 2 {
        return false
      }
      let q = self.lexer.byte_at(off)
      if q != b'"' && q != b'\'' {
        return false // 数值/布尔形态（词法整词出，首字节裁决）
      }
      // `""`/`''` 空短串 vs 长串开壳：长串整词 >= 6 且第三字节仍引号
      if self.lexer.byte_at(off + 1) == q &&
        len >= 6 &&
        self.lexer.byte_at(off + 2) == q {
        return false
      }
      true
    }
    _ => true
  }
}

///|
/// 统一取数：先取恢复推回的单 token，再问词法器
///（TrigEOF 合法送达一次由适配器保证；推回槽只存结构 token，永不存 TrigEOF）
fn[L : LexerSource] TrigEngine::pull(self : TrigEngine[L]) -> TrigEvent? {
  match self.pending {
    Some(ev) => {
      self.pending = None
      Some(ev)
    }
    None => self.lexer.next()
  }
}

///|
/// **谓词候选态**（役35 A1）：表上 `KeywordA` 有行的那 12 个状态——即"这一位可以出现谓词"。
/// 引擎用**表管的 state** 判定"本事件是否落在谓词位"，据此归属 `pk`（`a` ⇒ `KwA`，其余 ⇒ `Normal`）。
/// 名单**与表源逐名对照**（表源增删 `KeywordA` 行时本名单须同笔跟）。
fn predicate_state(state : TrigState) -> Bool {
  match state {
    TrigExpectPredicate
    | TrigExpectVerbOrEnd
    | TrigExpectVerbRequired
    | TrigExpectVerbOrDot
    | TrigBnpExpectPredicate
    | TrigGraphExpectPredicate
    | TrigGraphExpectVerbOrDot
    | TrigGraphExpectVerbOrEnd
    | TrigAnnotExpectVerb
    | TrigAnnotExpectVerbTail
    | TrigGraphAnnotExpectVerb
    | TrigGraphAnnotExpectVerbTail => true
    _ => false
  }
}

///|
/// TrigEngine[L] - 驱动生成的 step 状态机（薄机械层，不持有 data）
/// 词法器可插拔：L = TrigLexerAdapter（当前唯一实现）
pub struct TrigEngine[L] {
  lexer : L
  priv actions : TrigActionsImpl
  priv ctx : TrigContext // mutable 契约：ctx 原地推进（reset/step 原地写）
  dialect : TrigDialect // 方言开关（默认 TriG 超集；Turtle 禁图块区）
  priv mut last_error : Span? // 最近一次错误位置（行号由上层按 data 统计）
  priv mut pending : TrigEvent? // 恢复推回的单 token（"停 Rbrace 前界"的兑现机制）
  // 役35 A1（R-T13/C-T13）：N3 档 `@keywords` **指令已受理**标记。
  // 口径 = n3v2 同源"引擎侧纯形态标记"：只置旗 + 归位点事件改写，**词性决策仍留表行**
  //（`a` 失效后走既有 `PrefName` 行；本档当前不建列表区 ⇒ 列表词处理归 A2）。
  priv mut kw_directive_seen : Bool
  // 役35 **A2**（列表区层）：N3 档 `@keywords` 之后的**声明列表区**——区内的词是**声明**
  //（不入表、不出 quad），只等 `.` 收区。零表源实现（同 A1 路线：引擎守卫 + 状态机自治）。
  // 口径：区内**一切事件吞掉**；`Dot` ⇒ 收区并归位语句起点。
  priv mut kw_list_mode : Bool
}

///|
/// 创建引擎（词法器由调用方注入；begin_record 仅此一次——TriG 状态连续）
pub fn[L : LexerSource] TrigEngine::new(
  lexer : L,
  dialect? : TrigDialect = TriG,
) -> TrigEngine[L] {
  let engine = TrigEngine::{
    lexer,
    actions: TrigActionsImpl::new(),
    ctx: TrigContext::new(),
    dialect,
    last_error: None,
    pending: None,
    kw_directive_seen: false,
    kw_list_mode: false,
  }
  engine.begin_record()
  engine
}

///|
/// 纯 MoonBit 词法（TrigLexerAdapter 包 @nquads.Lexermoon）版
pub fn TrigEngine::from_bytes(
  data : Array[Byte],
  dialect? : TrigDialect = TriG,
) -> TrigEngine[TrigLexerAdapter] {
  TrigEngine::new(TrigLexerAdapter::new(data[:]), dialect~)
}

///|
/// 上下文当前覆盖范围（错误报告定位）
fn ctx_span(ctx : TrigContext) -> Span {
  let subj = ctx.subject.unwrap_or((0, 0))
  let obj = ctx.object.unwrap_or((0, 0))
  let start = subj.0
  let end = obj.0 + obj.1
  (start, end - start)
}

///|
/// 记录错误位置（行号不在此统计：engine 不持有 data，由 SliceParser 计）
fn[L] TrigEngine::record_error(self : TrigEngine[L], span : Span) -> Unit {
  self.last_error = Some(span)
}

///|
/// TrigSupervisor 实现（Engine 持有 lexer/ctx/last_error，钩子落在此处）

///|
/// 入口重置策略：仅构造时一次（空 ctx 已是初始态；保留位——流式重建时用）
impl[L : LexerSource] TrigSupervisor for TrigEngine[L] with fn begin_record(
  self : TrigEngine[L],
) -> Unit {
  self.ctx.reset(ResetScope::All)
  self.ctx.prefix_name = None
  self.ctx.slot_stack.clear()
  self.ctx.pred_kind = Normal
  self.ctx.state = TrigState::TrigExpectSubject
}

///|
/// 错误恢复策略：登记 → 消费到 Dot 或 Rbrace → 按"出错时是否在图块内"归位。
/// state 归位是恢复语义的一部分；不经转移表（错误不在表中表达）。
impl[L : LexerSource] TrigSupervisor for TrigEngine[L] with fn recover(
  self : TrigEngine[L],
  span : Span,
) -> Unit {
  self.record_error(span)
  self.ctx.slot_stack.clear()
  self.ctx.pred_kind = Normal
  // 役9：注解壳账随错回收（带病续跑不出幽灵壳）
  self.ctx.annot_close = false
  self.ctx.subj_shell = false
  self.ctx.annot_s = None
  self.ctx.annot_o = None
  self.consume_to_recover_point()
}

///|
/// 恢复消费机械：图块内停在不消费的 Rbrace 前界（下一轮表格闭合图块）或 Dot
/// （回 GraphExpectSubject，graph 槽位保留）；顶层只停 Dot（回 TrigExpectSubject），
/// 顶层散落的 Rbrace 一并吞掉。EOF 兜底归 finish_at_end。
fn[L : LexerSource] TrigEngine::consume_to_recover_point(
  self : TrigEngine[L],
) -> Unit {
  let was_graph = self.ctx.state is TrigState::TrigGraphExpectSubject ||
    self.ctx.state is TrigState::TrigGraphExpectPredicate ||
    self.ctx.state is TrigState::TrigGraphExpectObject ||
    self.ctx.state is TrigState::TrigGraphExpectDotOrGraph
  let mut synth_dot = false
  for ;; {
    let event = if synth_dot {
      synth_dot = false
      TrigEvent::TrigDot
    } else {
      match self.pull() {
        None | Some(TrigEvent::TrigEOF) => {
          // EOF：归位交 finish_at_end 判脏；此处只收拾槽位
          if was_graph {
            self.ctx.state = TrigState::TrigGraphExpectSubject
          } else {
            self.ctx.state = TrigState::TrigExpectSubject
          }
          self.ctx.reset(ResetScope::SPO)
          return
        }
        Some(ev) => {
          let (ev2, dot) = self.normalize_term_span(ev)
          synth_dot = dot
          ev2
        }
      }
    }
    if event is TrigEvent::TrigDot {
      if was_graph {
        self.ctx.state = TrigState::TrigGraphExpectSubject
        self.ctx.reset(ResetScope::SPO)
      } else {
        self.ctx.state = TrigState::TrigExpectSubject
        self.ctx.reset(ResetScope::All)
      }
      return
    }
    if event is TrigEvent::TrigRbrace && was_graph {
      // 停在 Rbrace 前界：推回单 token 槽（词法器已推进，推回才是真"不消费"），
      // 下一轮 next() 从槽里取到它，交给转移表走 exit_graph 闭合
      self.pending = Some(event)
      self.ctx.state = TrigState::TrigGraphExpectSubject
      self.ctx.reset(ResetScope::SPO)
      return
    }
  }
}

///|
/// EOF 判脏策略：state 未归位或槽位脏 → 报错并自清（防 parse_all 无限重报：
/// nquads 靠 begin_record 复位，trig 无 per-next 复位点，finish 自排水）
impl[L : LexerSource] TrigSupervisor for TrigEngine[L] with fn finish_at_end(
  self : TrigEngine[L],
) -> Result[TrigPendingQuad, ParseError]? {
  // DirectiveEnd 算干净终态：SPARQL 风格指令可无点直接收文件
  let state_ok = self.ctx.state is TrigState::TrigExpectSubject ||
    self.ctx.state is TrigState::TrigExpectDirectiveEnd
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
    self.ctx.annot_close = false
    self.ctx.subj_shell = false
    self.ctx.annot_s = None
    self.ctx.annot_o = None
    self.ctx.state = TrigState::TrigExpectSubject
    Some(Err(err))
  } else {
    None
  }
}

///|
/// 错误装配策略：BusinessFailed 消息 → ParseError
impl[L : LexerSource] TrigSupervisor for TrigEngine[L] with fn on_business_failed(
  self : TrigEngine[L],
  message : String,
) -> ParseError {
  ParseError::SyntaxErr(message, ctx_span(self.ctx))
}

///|
/// 模板内方法可见性：把 Supervisor 四钩子提升为 TrigEngine 的扩展方法
extend TrigEngine with TrigSupervisor::{
  recover,
  begin_record,
  finish_at_end,
  on_business_failed,
}

///|
/// 主循环（生成器固定模板 = 纯控制流分发器）：
/// 入口/终止 → step 步进 → Effect 分发 → 错误降级，四节点零领域逻辑。
/// 与 nquads 模板的唯一差异：Sequence 意图串列的顺序解释（先组装后退图）。
pub fn[L : LexerSource] TrigEngine::next(
  self : TrigEngine[L],
) -> Result[TrigPendingQuad, ParseError]? {
  // 发射队列优先排空：Sequence 内多条 EmitQuad 逐条回吐（parse_next 再进 next()
  // 时从队列续取，事件流不丢不重）
  // 役11（T11）：队列下沉 ctx（与 n3v2 役22 同构）
  if self.ctx.emit_queue.length() > 0 {
    return Some(Ok(self.ctx.emit_queue.remove(0)))
  }
  let mut synth_dot = false
  for ;; {
    let event = if synth_dot {
      synth_dot = false
      TrigEvent::TrigDot
    } else {
      match self.pull() {
        None | Some(TrigEvent::TrigEOF) => return self.finish_at_end()
        Some(ev) => {
          let (ev2, dot) = self.normalize_term_span(ev)
          synth_dot = dot
          ev2
        }
      }
    }
    // 指令位字节守卫：不过按 UnexpectedEvent 同径恢复（整段消费，待发 Dot 作废）
    if !self.directive_ok(self.ctx, event) {
      synth_dot = false
      self.recover(span_of_event(event))
      continue
    }
    // 方言守卫：Turtle 禁图块区——裸 `{ … }` 与 `<g> { … }` 皆 TriG 特有
    //（bad-struct-01 口径）；`{|` 注解壳是双字节 token 不中。字面量内 `{`
    // 已被词法整词吞并，不产 TrigLbrace 事件
    if self.dialect is Turtle && event is TrigEvent::TrigLbrace {
      synth_dot = false
      self.recover(span_of_event(event))
      continue
    }
    // 役35 A1（R-T13/C-T13）：**N3 档 `@keywords` 受理层**——
    //   本档收到 `TrigKeywordsKw` ⇒ 置"已受理"旗并**吞掉本事件**（不进表、不出 quad）。
    //   **列表词处理不在本层**（A2 建列表区；A1 期间名单词按常规路径解析，已由
    //   §AS.2 钉清单第 3/4 条与本层边界共同钉住）。
    //   TriG/Turtle 档**维持现状**：表上无该行 ⇒ `UnexpectedEvent` 干净拒 + 恢复
    //（W3C `bad-n3-extras-07/13` 负例口径不变）。
    if self.dialect is N3 && event is TrigEvent::TrigKeywordsKw {
      synth_dot = false
      self.kw_directive_seen = true
      self.kw_list_mode = true // A2：进入声明列表区（见下方守卫）
      // A1 受理层收尾：`@keywords` 是 **`@`（At 行→ExpectDirectiveKind）+ 本事件** 两拍，
      // 故受理后须把状态归位到**语句起点**（等价"指令已结束"）；列表区与尾随 `.` 的
      // 正确处理归 **A2**（A1 期间 `@keywords` 之后的词按常规语句解析，见 §AS.2 钉 2/3）。
      self.ctx.state = TrigState::TrigExpectSubject
      self.ctx.directive_at = false
      continue
    }
    // 役35 **A2 列表区守卫**（N3 档）：`@keywords` 之后到 `.` 之间的词是**声明**——
    // 一律吞掉（不入表、不出 quad）；`Dot` 收区并归位语句起点。零表源（同 A1 路线）。
    if self.dialect is N3 && self.kw_list_mode {
      synth_dot = false
      if event is TrigEvent::TrigDot {
        self.kw_list_mode = false
      }
      self.ctx.state = TrigState::TrigExpectSubject
      continue
    }
    // 役35 A1（R-T13/C-T13）：**谓词位 `pk` 归属**（与语义决策同层；零表源改动）。
    // 判据：**位置由表管状态给**（`predicate_state`），本事件若落在谓词候选态，
    // 则按事件种类记 `pk`——`TrigKeywordA` ⇒ `KwA`（`a` 保留 = turtle `rdf:type` 简写），
    // 其余 ⇒ `Normal`（含"N3 档已受理后 `a` 被改写为 PrefName"的失效支）。
    // 口径：`pred_kind` 由 `snapshot` 读出即归 `Normal`（spec **I-8**），跨语句不残留；
    // n3v2 把这一步放在手写 action（其 ctx 有 `kw_a_live` 旗）——trig 无该字段且
    // 加字段须动表源，故改用"**表管状态 ⇒ 引擎按状态定归属**"的等价形（pk 面逐字同形）。
    if predicate_state(self.ctx.state) {
      self.ctx.pred_kind = match event {
        TrigEvent::TrigKeywordA(_) => PredKind::KwA
        _ => PredKind::Normal
      }
    }
    match step(self.ctx, event, self.actions) {
      Ok(effect) =>
        // 役11（T11，与 n3v2 役22 同构）：解释在 interpret（套装默认体），
        // 此处只兑现 loop 控制流；效果语义全数移驻 handler
        match TrigEffectHandler::interpret(self, self.ctx, effect) {
          KeepGoing => continue
          YieldQuad(quad) => return Some(Ok(quad))
          Stop => return None
        }
      Err(TrigActionError::UnexpectedEvent(_, event)) => {
        // 无转移兜底：取事件载荷位置（缺失则词法位置）；恢复策略在 Supervisor
        synth_dot = false // 恢复消费整段，待发 Dot 一并作废
        let span = span_of_event(event)
        let span = if span == (0, 0) { (self.lexer.pos(), 0) } else { span }
        self.recover(span)
        continue
      }
      Err(TrigActionError::BusinessFailed(message)) =>
        return Some(Err(self.on_business_failed(message)))
    }
  }
}

///|
/// 便捷入口：解析全部 trig
pub fn trig_parser(
  input : Array[Byte],
  lenient? : Bool = false,
  dialect? : TrigDialect = TriG,
) -> (Array[QuadSpan], Array[ParseError]) {
  let engine = TrigEngine::from_bytes(input, dialect~)
  let slice = TrigSliceParser::new(engine, input[:], lenient~)
  slice.parse_all()
}

///|
/// 役9 注解壳主语结算：体区旗真且主语 = 锚主语（span 身份交换键，役6 is_src
/// 同教义——嵌套 bnp/集合内层 fresh 主语天然错键）时换壳 span：锚主语起点→
/// 锚宾语终点的原文连续区间，物化层据此合成 <<原文>> TT 壳。
/// 错键支强制旗落假：subj_shell 是 ctx 直引 extra，不落旗内层 quad 无条件继承
/// 壳旗被误包（役8 教训）。
fn TrigContext::settle_shell(
  self : TrigContext,
  pending : TrigPendingQuad,
) -> TrigPendingQuad {
  if pending.subj_shell {
    if pending.subj == self.annot_s {
      match (self.annot_s, self.annot_o) {
        (Some(s), Some(o)) =>
          return { ..pending, subj: Some((s.0, o.0 + o.1 - s.0)), }
        (_, _) => ()
      }
    }
    return { ..pending, subj_shell: false, }
  }
  pending
}

///|
/// 役9 收口旗消费：annot_close 置真时清壳账（发射位快照之后、reset 之前调用；
/// PredObj reset 保锚主语在槽——`|} ; …` 续锚口径）
fn TrigContext::settle_annotation(self : TrigContext) -> Unit {
  if self.annot_close {
    self.annot_close = false
    self.subj_shell = false
    self.annot_s = None
    self.annot_o = None
  }
}

// ===== 役11（T11）：效果面接活——引擎兑现 handler 的真实挂点 =====
// interpret（套装默认体）为唯一解释器；snapshot 负责壳旗结算与收口旗消费，
// on_* 把意图兑现机械（action）接回；其余成员用套装默认。

///|
/// snapshot 覆盖：壳旗结算 + 收口旗消费（役9 口径），产出待上抛的 pending quad
impl[L] TrigEffectHandler for TrigEngine[L] with fn snapshot(
  self : TrigEngine[L],
  ctx : TrigContext,
) -> TrigPendingQuad {
  ignore(self)
  let pending = ctx.settle_shell(ctx.snapshot())
  ctx.settle_annotation()
  pending
}

///|
/// ExitGraph 意图兑现：退图机械在 action（直连行的 exit_graph 已在 step 内执行，
/// 序列内嵌意图由 loop 经本钩子补调）
impl[L] TrigEffectHandler for TrigEngine[L] with fn on_exit_graph(
  self : TrigEngine[L],
) -> Unit {
  let _ = TrigActions::exit_graph(self.actions, self.ctx)
}

///|
impl[L] TrigEffectHandler for TrigEngine[L] with fn on_pop_bnp(
  self : TrigEngine[L],
  ctx : TrigContext,
) -> Unit {
  let _ = TrigActions::pop_bnode_prop(self.actions, ctx)
}

///|
impl[L] TrigEffectHandler for TrigEngine[L] with fn on_list_step(
  self : TrigEngine[L],
  ctx : TrigContext,
  elem : Span,
) -> Unit {
  let _ = TrigActions::list_step(self.actions, ctx, elem)
}

///|
impl[L] TrigEffectHandler for TrigEngine[L] with fn on_open_slot(
  self : TrigEngine[L],
  ctx : TrigContext,
  span : Span,
  typ : SlotType,
  ret_state : TrigState,
) -> Unit {
  let _ = TrigActions::open_slot(self.actions, ctx, span, typ, ret_state)
}
