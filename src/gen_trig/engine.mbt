// ===== 用户部分：解析引擎主循环（薄机械层，与 nquads 同模板） =====
// 职责切分（与 nquads engine.mbt 同宪法）：
//   - 本文件只做状态机机械：驱动 step、按 Effect 意图执行（发射 snapshot+按
//     scope 重置、Enter/ExitGraph 通知）、错误恢复、EOF 判脏收尾。
//   - 切片组装/验证/物化全部上移 SliceParser；层间只传 span 快照（TrigPendingQuad）。
//   - trig 与 nquads 模板的差异点（均有据可查）：
//     1) 无 per-next begin_record：TriG 状态连续（图块/前缀账本跨 quad 存续），
//        begin_record 仅在引擎构造时调用一次（LoopPolicy 契约不变，实现换语义）。
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
    | TrigAnon
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
      (TrigKeywordA(s2), dot)
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
/// TrigEngine[L] - 驱动生成的 step 状态机（薄机械层，不持有 data）
/// 词法器可插拔：L = TrigLexerAdapter（当前唯一实现）
pub struct TrigEngine[L] {
  lexer : L
  hooks : Hooks
  ctx : TrigContext // mutable 契约：ctx 原地推进（reset/step 原地写）
  dialect : TrigDialect // 方言开关（默认 TriG 超集；Turtle 禁图块区）
  mut last_error : Span? // 最近一次错误位置（行号由上层按 data 统计）
  mut pending : TrigEvent? // 恢复推回的单 token（"停 Rbrace 前界"的兑现机制）
  emit_queue : Array[TrigPendingQuad] // Sequence 多发射队列：FIFO，next() 顶部优先排空（集合链 rest+first 双发射的承载）
}

///|
/// 创建引擎（词法器由调用方注入；begin_record 仅此一次——TriG 状态连续）
pub fn[L : LexerSource] TrigEngine::new(
  lexer : L,
  dialect? : TrigDialect = TriG,
) -> TrigEngine[L] {
  let engine = TrigEngine::{
    lexer,
    hooks: Hooks::new(),
    ctx: TrigContext::new(),
    dialect,
    last_error: None,
    pending: None,
    emit_queue: [],
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
/// TrigLoopPolicy 实现（Engine 持有 lexer/ctx/last_error，钩子落在此处）

///|
/// 入口重置策略：仅构造时一次（空 ctx 已是初始态；保留位——流式重建时用）
impl[L : LexerSource] TrigLoopPolicy for TrigEngine[L] with fn begin_record(
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
impl[L : LexerSource] TrigLoopPolicy for TrigEngine[L] with fn recover(
  self : TrigEngine[L],
  span : Span,
) -> Unit {
  self.record_error(span)
  self.ctx.slot_stack.clear()
  self.ctx.pred_kind = Normal
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
impl[L : LexerSource] TrigLoopPolicy for TrigEngine[L] with fn finish_at_end(
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
    self.ctx.state = TrigState::TrigExpectSubject
    Some(Err(err))
  } else {
    None
  }
}

///|
/// 错误装配策略：BusinessFailed 消息 → ParseError
impl[L : LexerSource] TrigLoopPolicy for TrigEngine[L] with fn on_business_failed(
  self : TrigEngine[L],
  message : String,
) -> ParseError {
  ParseError::SyntaxErr(message, ctx_span(self.ctx))
}

///|
/// 模板内方法可见性：把 LoopPolicy 四钩子提升为 TrigEngine 的扩展方法
extend TrigEngine with TrigLoopPolicy::{
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
  if self.emit_queue.length() > 0 {
    return Some(Ok(self.emit_queue.remove(0)))
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
    match step(self.ctx, event, self.hooks) {
      Ok(TrigEffect::Continue) => continue
      Ok(TrigEffect::EnterGraph) | Ok(TrigEffect::ExitGraph) => continue
      Ok(TrigEffect::PopBnp) => {
        // 弹栈恢复：`]` 空形式收口的裸意图，恢复机械在 action（帧携带返回状态）
        let _ = TrigActions::pop_bnode_prop(self.hooks, self.ctx)
        continue
      }
      Ok(TrigEffect::ListStep(elem)) => {
        // 集合链推进：意图兑现机械在 action（对齐 PopBnp 口径）
        let _ = TrigActions::list_step(self.hooks, self.ctx, elem)
        continue
      }
      Ok(TrigEffect::OpenSlot(sp, typ, ret)) => {
        // 嵌套元素开帧：意图兑现机械在 action
        let _ = TrigActions::open_slot(self.hooks, self.ctx, sp, typ, ret)
        continue
      }
      Ok(TrigEffect::Reset(scope)) => {
        // 纯收拾意图：不发射，仅按粒度重置槽位
        self.ctx.reset(scope)
        continue
      }
      Ok(TrigEffect::EmitQuad(scope)) => {
        // 发射：snapshot 打包槽位 span，按 scope 粒度重置后上抛
        let pending = self.ctx.snapshot()
        self.ctx.reset(scope)
        return Some(Ok(pending))
      }
      Ok(TrigEffect::Sequence(effects)) => {
        // 意图串列：顺序解释；EmitQuad 逐条入队（集合链 rest+first 双发射 =
        // 单次 step 多 quad，旧"单 pending 覆盖"口径退役），循环后队首上抛
        for effect in effects {
          match effect {
            TrigEffect::EmitQuad(scope) => {
              let item = self.ctx.snapshot()
              self.ctx.reset(scope)
              self.emit_queue.push(item)
            }
            TrigEffect::Reset(scope) => self.ctx.reset(scope)
            TrigEffect::ExitGraph => {
              // 意图兑现：表内该行只产意图，exit_graph 意图由 loop 补调
              //（直连行的 exit_graph 已在 step 内执行，其返回的 ExitGraph 在上方 continue）
              let _ = TrigActions::exit_graph(self.hooks, self.ctx)
            }
            TrigEffect::PopBnp => {
              // 意图兑现：`]` 收口序列的弹栈恢复，机械在 action（对齐 ExitGraph 口径）
              let _ = TrigActions::pop_bnode_prop(self.hooks, self.ctx)
            }
            TrigEffect::ListStep(e) => {
              let _ = TrigActions::list_step(self.hooks, self.ctx, e)
            }
            TrigEffect::OpenSlot(sp, typ, ret) => {
              let _ = TrigActions::open_slot(self.hooks, self.ctx, sp, typ, ret)
            }
            TrigEffect::Done => break
            TrigEffect::Continue
            | TrigEffect::EnterGraph
            | TrigEffect::Sequence(_) => ()
          }
        }
        if self.emit_queue.length() > 0 {
          return Some(Ok(self.emit_queue.remove(0)))
        }
        continue
      }
      Ok(TrigEffect::Done) => return None
      Err(TrigActionError::UnexpectedEvent(_, event)) => {
        // 无转移兜底：取事件载荷位置（缺失则词法位置）；恢复策略在 LoopPolicy
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
