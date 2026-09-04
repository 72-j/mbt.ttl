// ===== 用户部分：解析引擎主循环（薄机械层） =====
// 参考手写版 src/moon_ttl/src/parser_nquads.mbt 的 NQuadsEngine::next：
//   lexer.next() → EOF 由词法器吞掉（None），loop 判脏收尾
// 与手写版的差异：状态转移表来自生成的 step()（见 nquads.mbt）。
// 职责切分（engine_c.mbt 薄适配层标准的推广）：
//   - 本文件只做状态机机械：驱动 step、按 EmitQuad 意图的 scope 粒度重置、
//     错误恢复（record_error 登记 + 消费到句点 + 状态归位）、EOF 判脏收尾。
//   - 切片组装/类型探测/格式验证/物化全部上移 SliceParser（parser_slice.mbt）；
//     层间只传 span 快照（NQuadsPendingQuad：offset,length），不传物化产物、
//     不共享可变状态（重置仍在本 loop，FSM 不带脏状态跨 next()）。
//   - 本文件不持有 data 视图；行号统计由持有 data 的 SliceParser 完成。
//   - next 是生成器固定模板：入口/终止 → step 步进 → Effect 分发 → 错误降级
//     四节点纯分发；入口重置/恢复/EOF 判定/错误装配下沉 NQuadsLoopPolicy
//     （trait 声明在 nquads.mbt 契约文件，本文件提供 Engine 实现）。

///|
/// 词法源 trait：仅约束"逐 token 推进"的运行时接口（构造/释放在各实现处显式做）
/// 实现：Lexermoon（lexer_mbt.mbt，纯 MoonBit）/ Lexerc（lexerc.mbt，C FFI）
trait LexerSource {
  fn next(Self) -> NQuadsEvent? // 下一个事件；换行/注释/EOF 已过滤，None = 输入结束
  fn pos(Self) -> Int // 当前词法位置（兜底错误定位用）
  fn byte_at(Self, offset : Int) -> Byte // 数据直查（词内尾点裁决用，见 normalize_term_span）
}

///|
/// Lexermoon 实现 LexerSource（纯 MoonBit 词法器；Token 与 C 版同型同宽）
pub impl LexerSource for Lexermoon with fn next(self : Lexermoon) -> NQuadsEvent? {
  match Lexermoon::next(self) {
    None => None // 保留给异常分支；正常 EOF 由词法器以 EOF 变体告知
    Some(token) =>
      if token is Token::EOF(_) {
        None
      } else {
        Some(token_to_event(token))
      }
  }
}

///|
pub impl LexerSource for Lexermoon with fn pos(self : Lexermoon) -> Int {
  self.current_pos()
}

///|
pub impl LexerSource for Lexermoon with fn byte_at(
  self : Lexermoon,
  offset : Int,
) -> Byte {
  self.view[offset]
}

///|
// pub impl LexerSource for Lexermoon with fn destroy(_self : Lexermoon) -> Unit {
//   () // 纯 MoonBit 词法器无需释放
// }

///|
/// Token(offset,length) → 事件载荷 Span —— 两套词法器（Lexermoon/Lexerc）共用，
/// 词法适配层已把 span 统一为全词含定界符，此处零补偿直接透传
fn token_to_event(token : Token) -> NQuadsEvent {
  match token {
    Token::Iri(span) => NQuadsEvent::NQuadsIri(span)
    Token::BlankNode(span) => NQuadsEvent::NQuadsBlankNode(span)
    Token::Literal(span) => NQuadsEvent::NQuadsLiteral(span)
    Token::PrefName(span) => NQuadsEvent::NQuadsPrefName(span)
    Token::TripleTerm(span) => NQuadsEvent::NQuadsTripleTerm(span)
    Token::Dot(_) => NQuadsEvent::NQuadsDot
    Token::Comma(_) => NQuadsEvent::NQuadsComma
    Token::Semicolon(_) => NQuadsEvent::NQuadsSemicolon
    Token::Unknown(_) => NQuadsEvent::NQuadsUnknown
    Token::EOF(_) => NQuadsEvent::NQuadsEOF // 已被 LexerSource 过滤，保底映射
  }
}

///|
/// 事件载荷 span 提取：无载荷事件给 (0,0)（UnexpectedEvent 兜底定位用，
/// loop 会再用 lexer.pos() 补全真实位置）
fn span_of_event(event : NQuadsEvent) -> Span {
  match event {
    NQuadsIri(span) => span
    NQuadsBlankNode(span) => span
    NQuadsLiteral(span) => span
    NQuadsPrefName(span) => span
    NQuadsEvent::NQuadsTripleTerm(span) => span
    NQuadsComma | NQuadsSemicolon | NQuadsDot | NQuadsUnknown | NQuadsEOF =>
      (0, 0)
  }
}

///|
/// 词内尾点裁决：无脑扫把语句点吞进词尾（"x". / _:o.）时剥离尾点，
/// 由 loop 合成 Dot 事件走转移表（决策仍在表，机械在此）。
/// Iri/PrefName 自带定界/分隔收束不会吞点，统一处理求稳。
fn[L : LexerSource] trim_trailing_dot(lexer : L, span : Span) -> (Span, Bool) {
  let (off, len) = span
  if len > 0 && lexer.byte_at(off + len - 1) == b'.' {
    ((off, len - 1), true)
  } else {
    (span, false)
  }
}

///|
fn[L : LexerSource] NQuadsEngine::normalize_term_span(
  self : NQuadsEngine[L],
  event : NQuadsEvent,
) -> (NQuadsEvent, Bool) {
  match event {
    NQuadsIri(span) => {
      let (span2, dot) = trim_trailing_dot(self.lexer, span)
      (NQuadsIri(span2), dot)
    }
    NQuadsBlankNode(span) => {
      let (span2, dot) = trim_trailing_dot(self.lexer, span)
      (NQuadsBlankNode(span2), dot)
    }
    NQuadsLiteral(span) => {
      let (span2, dot) = trim_trailing_dot(self.lexer, span)
      (NQuadsLiteral(span2), dot)
    }
    NQuadsPrefName(span) => {
      let (span2, dot) = trim_trailing_dot(self.lexer, span)
      (NQuadsPrefName(span2), dot)
    }
    NQuadsTripleTerm(span) => {
      let (span2, dot) = trim_trailing_dot(self.lexer, span)
      (NQuadsTripleTerm(span2), dot)
    }
    other => (other, false)
  }
}

///|
/// NQuadsEngine[L] - 驱动生成的 step 状态机（薄机械层，不持有 data）
/// 词法器可插拔：L = Lexermoon（纯 MoonBit）或 Lexerc（C FFI，见 engine_c.mbt）；
/// hooks 为单载体双 trait（step 的 actions + EffectHandler 回调面）
pub struct NQuadsEngine[L] {
  lexer : L
  hooks : Hooks
  ctx : NQuadsContext // mutable 契约：ctx 原地推进（reset/step 原地写）
  mut last_error : Span? // 最近一次行错误位置（行号由上层按 data 统计）
}

///|
/// 创建引擎（词法器由调用方注入）
pub fn[L] NQuadsEngine::new(lexer : L) -> NQuadsEngine[L] {
  NQuadsEngine::{
    lexer,
    hooks: Hooks::new(),
    ctx: NQuadsContext::new(),
    last_error: None,
  }
}

///|
/// 纯 MoonBit 词法（Lexermoon）版
pub fn NQuadsEngine::from_bytes(data : Array[Byte]) -> NQuadsEngine[Lexermoon] {
  NQuadsEngine::new(Lexermoon::new(data[:]))
}

///|
/// 上下文当前覆盖范围（参考手写: NQuadsPendingQuad::compute_span）
fn ctx_span(ctx : NQuadsContext) -> Span {
  let subj = ctx.subject.unwrap_or((0, 0))
  let obj = ctx.object.unwrap_or((0, 0))
  let graph = ctx.graph.unwrap_or((0, 0))
  let start = subj.0
  let end = if graph.0 != 0 || graph.1 != 0 {
    graph.0 + graph.1
  } else {
    obj.0 + obj.1
  }
  (start, end - start)
}

///|
/// 记录跳过的错误位置（行号不在此统计：engine 不持有 data，由 SliceParser 计）
fn[L] NQuadsEngine::record_error(self : NQuadsEngine[L], span : Span) -> Unit {
  self.last_error = Some(span)
}

///|
/// NQuadsLoopPolicy 实现（Engine 持有 lexer/ctx/last_error，钩子落在此处）：
/// 四个领域钩子的 nquads 策略；trig 生成同形 trait 换实现即可。

///|
/// 入口重置策略：每条记录从空槽开始（mutable 契约原地写，零分配）
impl[L : LexerSource] NQuadsLoopPolicy for NQuadsEngine[L] with fn begin_record(
  self : NQuadsEngine[L],
) -> Unit {
  self.ctx.reset(ResetScope::All)
  // 记录边界 = 状态归位：reset 按正交设计只清槽位不复位 state，
  // 若不复位，EOF 脏记录会在 finish_at_end 无限重报（parse_all 死循环）
  self.ctx.state = NQuadsState::NQuadsExpectSubject
}

///|
/// 行错误恢复策略：登记 → 消费到句点并完全重置（槽位归零 + 状态归位）。
/// state 归位是恢复语义的一部分：错误行整体作废，从新行重新开始。
/// 不经转移表（错误不在表中表达），由本钩子独占这段机械。
impl[L : LexerSource] NQuadsLoopPolicy for NQuadsEngine[L] with fn recover(
  self : NQuadsEngine[L],
  span : Span,
) -> Unit {
  self.record_error(span)
  self.consume_to_dot()
  self.ctx.state = NQuadsState::NQuadsExpectSubject
}

///|
/// 消费整行直到 . 或 EOF（错误恢复的消费机械，参考手写 SkipError 分支）
fn[L : LexerSource] NQuadsEngine::consume_to_dot(
  self : NQuadsEngine[L],
) -> Unit {
  for ;; {
    match self.lexer.next() {
      None => break
      Some(event) => if event is NQuadsEvent::NQuadsDot { break }
    }
  }
  self.ctx.reset(ResetScope::All)
}

///|
/// EOF 判脏策略：state 未归位或任一槽位残留 → 不完整四元组错误
/// （EOF 是数据边界，收尾判据是领域知识，不在状态机表里）
impl[L : LexerSource] NQuadsLoopPolicy for NQuadsEngine[L] with fn finish_at_end(
  self : NQuadsEngine[L],
) -> Result[NQuadsPendingQuad, ParseError]? {
  if !(self.ctx.state is NQuadsState::NQuadsExpectSubject) ||
    self.ctx.has_pending() {
    Some(
      Err(
        ParseError::SyntaxErr(
          "Incomplete triple at end of input",
          ctx_span(self.ctx),
        ),
      ),
    )
  } else {
    None
  }
}

///|
/// 错误装配策略：BusinessFailed 消息 → ParseError（发射点槽位算术在此，
/// loop 模板不触碰 ctx 字段）
impl[L : LexerSource] NQuadsLoopPolicy for NQuadsEngine[L] with fn on_business_failed(
  self : NQuadsEngine[L],
  message : String,
) -> ParseError {
  ParseError::SyntaxErr(message, ctx_span(self.ctx))
}

///|
/// 模板内方法可见性：把 LoopPolicy 四钩子提升为 NQuadsEngine 的扩展方法，
/// next 模板里直接 self.begin_record()/self.recover(...) 调用
extend NQuadsEngine with NQuadsLoopPolicy::{
  recover,
  begin_record,
  finish_at_end,
  on_business_failed,
}

///|
/// 主循环（生成器固定模板 = 纯控制流分发器）：
/// 入口/终止 → step 步进 → Effect 分发 → 错误降级，四节点零领域逻辑。
/// 高频业务在 Actions（槽位写入，热路径）；冷路径业务在 EffectHandler（下游
/// 输出）与 LoopPolicy（恢复/收尾策略）；数据加工在 SliceParser（组装/验证）。
pub fn[L : LexerSource] NQuadsEngine::next(
  self : NQuadsEngine[L],
) -> Result[NQuadsPendingQuad, ParseError]? {
  self.begin_record()
  // 单槽待发 Dot：词内尾点剥离后在此合成事件回灌转移表
  let mut synth_dot = false
  for ;; {
    let event = if synth_dot {
      synth_dot = false
      NQuadsEvent::NQuadsDot
    } else {
      match self.lexer.next() {
        None => return self.finish_at_end()
        Some(ev) => {
          let (ev2, dot) = self.normalize_term_span(ev)
          synth_dot = dot
          ev2
        }
      }
    }
    match step(self.ctx, event, self.hooks) {
      Ok(NQuadsEffect::Continue) => continue
      Ok(NQuadsEffect::EmitQuad(scope)) => {
        // 发射：snapshot 契约 helper 打包槽位 span，按 scope 粒度重置后上抛；
        // 切片组装与缺槽检测上移 SliceParser，本 loop 不碰数据
        let pending = self.ctx.snapshot()
        self.ctx.reset(scope)
        return Some(Ok(pending))
      }
      Ok(NQuadsEffect::Done) => return None
      Err(NQuadsActionError::UnexpectedEvent(_, event)) => {
        // 无转移兜底：取事件载荷位置（缺失则词法位置）；恢复策略在 LoopPolicy
        synth_dot = false // 恢复消费整行，待发 Dot 一并作废
        let span = span_of_event(event)
        let span = if span == (0, 0) { (self.lexer.pos(), 0) } else { span }
        self.recover(span)
        continue
      }
      Err(NQuadsActionError::BusinessFailed(message)) =>
        // 错误装配策略在 LoopPolicy
        return Some(Err(self.on_business_failed(message)))
    }
  }
}

///|
/// 便捷入口：解析全部（参考手写 src/moon_ttl/src/parser.mbt 的 nquads_parser）
pub fn nquads_parser(
  input : Array[Byte],
  lenient? : Bool = false,
  rdf12? : Bool = true,
) -> (Array[QuadSpan], Array[ParseError]) {
  let engine = NQuadsEngine::from_bytes(input)
  let slice = SliceParser::new(engine, input[:], lenient~, rdf12~)
  slice.parse_all()
}
