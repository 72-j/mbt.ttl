///|
pub struct PendingQuad {
  mut subj : Span?
  mut pred : Span?
  mut obj : Span?
  mut graph : Span? // 图名（可选）
  mut has_dot : Bool
  mut state : PendingState
  mut line : Int
} derive(Debug, Eq)

///|
pub impl Show for PendingQuad with fn output(
  self : PendingQuad,
  logger : &Logger,
) -> Unit {
  let span = self.compute_span()
  let (offset, length) = span
  logger.write_string(" \{offset}:\{length}: \{self.state}")
}

///|
pub fn PendingQuad::default() -> PendingQuad {
  {
    subj: None,
    pred: None,
    obj: None,
    graph: None,
    has_dot: false,
    state: ExpectSubject,
    line: 0,
  }
}

///|
/// 检查是否完整
pub fn PendingQuad::is_complete(self : PendingQuad) -> Bool {
  self.subj is Some(_) &&
  self.pred is Some(_) &&
  self.obj is Some(_) &&
  (self.has_dot || self.state == Complete)
}

///|
/// 获取总 span
pub fn PendingQuad::compute_span(self : PendingQuad) -> Span {
  let start = match self.subj {
    Some((offset, _)) => offset
    None => 0
  }
  let end = match (self.obj, self.graph) {
    (Some((offset, length)), _) => offset + length
    (_, Some((offset, length))) => offset + length
    _ => start
  }
  (start, end - start)
}

///|
/// 重置状态
pub fn PendingQuad::reset(self : PendingQuad) -> Unit {
  self.subj = None
  self.pred = None
  self.obj = None
  self.graph = None
  self.has_dot = false
  self.state = ExpectSubject
  self.line = 0
}

///|
/// 获取 span 的结束偏移
pub fn end_offset(span : Span) -> Int {
  let (offset, length) = span
  offset + length
}

///|
/// Quad 组装状态机
/// PendingQuad 的组装状态
pub(all) enum PendingState {
  ExpectSubject
  ExpectPredicate
  ExpectObject
  ExpectDotOrGraph // 期望 . 或 <graph>
  ExpectGraph // 期望图名
  ExpectDot // 期望 .
  Complete
} derive(Debug, Eq)

///|
pub impl Show for PendingState with fn output(
  self : PendingState,
  logger : &Logger,
) -> Unit {
  match self {
    ExpectSubject => logger.write_string("ExpectSubject")
    ExpectPredicate => logger.write_string("ExpectPredicate")
    ExpectObject => logger.write_string("ExpectObject")
    ExpectDotOrGraph => logger.write_string("ExpectDotOrGraph")
    ExpectGraph => logger.write_string("ExpectGraph")
    ExpectDot => logger.write_string("ExpectDot")
    Complete => logger.write_string("Complete")
  }
}
// ============================================================
// NQuadsEngine 主结构
// ============================================================

///|
pub impl ParserEngine for NQuadsEngine with fn error_recovery_state(
  _self : NQuadsEngine,
) -> NQuadsEngine {
  NQuadsEngine::new()
}

///|
pub impl ParserEngine for NQuadsEngine with fn create_pending(
  _self : NQuadsEngine,
) -> PendingQuad {
  PendingQuad::default()
}

///|
pub impl ParserEngine for NQuadsEngine with fn is_complete(
  _self : NQuadsEngine,
  pending : PendingQuad,
) -> Bool {
  pending.is_complete()
}

///|
pub impl ParserEngine for NQuadsEngine with fn step(
  _self : NQuadsEngine,
  pending : PendingQuad,
  token : Token,
) -> StepResult {
  match (pending.state, token) {
    // =====================
    // 期望主语
    // =====================
    (ExpectSubject, Iri(span) | BlankNode(span)) => {
      pending.subj = Some(span)
      pending.state = ExpectPredicate
      //  pending.term_type = Some(TermType::Iri)
      Continue
    }
    (ExpectSubject, PrefName(_)) =>
      // N-Quads 不支持前缀名作为主语
      Error(
        ParseError::InvalidToken(
          "N-Quads does not support prefixed names.",
          ParseError::span(token),
        ),
      )
    (ExpectSubject, Unknown(_)) => Continue

    // =====================
    // 期望谓语
    // =====================
    (ExpectPredicate, Iri(span)) => {
      pending.pred = Some(span)
      pending.state = ExpectObject
      //  pending.term_type = Some(TermType::Iri)

      Continue
    }
    (ExpectPredicate, PrefName(_)) =>
      Error(
        ParseError::InvalidToken(
          "Predicate must be an IRI",
          ParseError::span(token),
        ),
      )
    (ExpectPredicate, token) =>
      Error(
        ParseError::InvalidToken(
          "Expected predicate (IRI)",
          ParseError::span(token),
        ),
      )

    // =====================
    // 期望宾语
    // =====================
    (ExpectObject, Iri(span) | Literal(span) | BlankNode(span)) => {
      pending.obj = Some(span)
      pending.state = ExpectDotOrGraph
      Continue
    }
    (ExpectObject, PrefName(_)) =>
      // N-Quads 中前缀名当作 IRI
      Error(
        ParseError::InvalidToken(
          "N-Quads does not support prefixed names.",
          ParseError::span(token),
        ),
      )
    (ExpectObject, token) =>
      Error(
        ParseError::InvalidToken(
          "Expected object (IRI or Literal)",
          ParseError::span(token),
        ),
      )

    // =====================
    // 期望 . 或 图名
    // =====================
    (ExpectDotOrGraph, Dot(_)) => {
      pending.has_dot = true
      pending.state = Complete
      pending.line += 1
      Emit
    }
    (ExpectDotOrGraph, Iri(span)) => {
      // 图名
      pending.graph = Some(span)
      pending.state = ExpectDot
      Continue
    }
    (ExpectDotOrGraph, PrefName(_)) =>
      // 图名必须是完整 IRI
      Error(
        ParseError::InvalidToken(
          "Graph must be an IRI",
          ParseError::span(token),
        ),
      )
    (ExpectDotOrGraph, Unknown(_)) => {
      // . 可选
      pending.has_dot = true
      pending.state = Complete
      Emit
    }

    // =====================
    // 期望 . (在图名之后)
    // =====================
    (ExpectDot, Dot(_)) => {
      pending.has_dot = true
      pending.state = Complete
      pending.line += 1
      Emit
    }
    (ExpectDot, token) =>
      Error(ParseError::InvalidToken("Expected '.'", ParseError::span(token)))

    // =====================
    // 已完成
    // =====================
    (Complete, token) =>
      Error(
        ParseError::InvalidToken(
          "Unexpected token after complete triple",
          ParseError::span(token),
        ),
      )

    // =====================
    // 默认跳过
    // =====================
    _ => SkipLine
  }
}

///|
pub impl ParserEngine for NQuadsEngine with fn recognize_end(
  _self : NQuadsEngine,
  pending : PendingQuad,
  results : Array[Span],
) -> Unit {
  if pending.subj is Some(_) &&
    pending.pred is Some(_) &&
    pending.obj is Some(_) {
    results.push(pending.compute_span())
  }
}

///|
/// NQuadsEngine - 直接对接 Lexerc，管理 PendingQuad 组装和错误收集
pub(all) struct NQuadsEngine {
  mut pending : PendingQuad
}

///|
/// 创建空 NQuadsEngine
pub fn NQuadsEngine::new() -> NQuadsEngine {
  NQuadsEngine::{
    pending: PendingQuad::{
      subj: None,
      pred: None,
      obj: None,
      graph: None,
      has_dot: false,
      state: PendingState::ExpectSubject,
      line: 1,
    },
  }
}
