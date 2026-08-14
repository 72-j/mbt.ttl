///|
pub struct PendingQuad {
  mut subj : Span
  mut pred : Span
  mut obj : Span
  mut graph : Span // 图名 span，错误时保存错误 span
  mut has_dot : Bool
  mut state : PendingState
  // mut line : Int
  // mut error_span : Span // 错误发生的位置
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
    subj: (0, 0),
    pred: (0, 0),
    obj: (0, 0),
    graph: (0, 0),
    has_dot: false,
    state: ExpectSubject,
    // line: 0,
    // error_span: (0, 0),
    // has_err: false,
  }
}

///|
/// 检查是否完整
pub fn PendingQuad::is_complete(self : PendingQuad) -> Bool {
  self.has_dot || self.state == Complete
}

///|
/// 获取总 span
pub fn PendingQuad::compute_span(self : PendingQuad) -> Span {
  let start = self.subj.0
  let end = if self.graph.0 != 0 || self.graph.1 != 0 {
    end_offset(self.graph)
  } else {
    end_offset(self.obj)
  }
  (start, end - start)
}

///|
/// 获取错误 span（如有）
// pub fn PendingQuad::error_span(self : PendingQuad) -> Span? {
//   if self.has_err {
//     Some(self.graph)
//   } else {
//     None
//   }
// }

///|
/// 重置状态
pub fn PendingQuad::reset(self : PendingQuad) -> Unit {
  self.subj = (0, 0)
  self.pred = (0, 0)
  self.obj = (0, 0)
  self.graph = (0, 0)
  self.has_dot = false
  self.state = ExpectSubject
  // self.line = 0
  // self.error_span = (0, 0)
  // self.has_err = false
}

///|
/// 获取 span 的结束偏移
pub fn end_offset(span : Span) -> Int {
  let (offset, length) = span
  offset + length
}

///|
/// Quad 组装状态机
pub(all) enum PendingState {
  ExpectSubject
  ExpectPredicate
  ExpectObject
  ExpectDotOrGraph // 期望 . 或 <graph>
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
    // 期望主语
    (ExpectSubject, Iri(span) | BlankNode(span)) => {
      pending.subj = span
      pending.state = ExpectPredicate
      Continue
    }
    (ExpectSubject, PrefName(span)) => SkipError(span)
    (ExpectSubject, Unknown(_)) => Continue

    // 期望谓语
    (ExpectPredicate, Iri(span)) => {
      pending.pred = span
      pending.state = ExpectObject
      Continue
    }
    (ExpectPredicate, token) => SkipError(ParseError::span(token))

    // 期望宾语
    (ExpectObject, Iri(span) | Literal(span) | BlankNode(span)) => {
      pending.obj = span
      pending.state = ExpectDotOrGraph
      Continue
    }
    (ExpectObject, token) => SkipError(ParseError::span(token))

    // 期望 . 或 图名
    (ExpectDotOrGraph, Dot(_)) => {
      pending.has_dot = true
      pending.state = Complete
      // pending.line += 1
      Emit
    }
    (ExpectDotOrGraph, Iri(span)) => {
      pending.graph = span
      pending.state = ExpectDot
      Continue
    }
    (ExpectDotOrGraph, PrefName(span)) => SkipError(span)
    (ExpectDotOrGraph, Unknown(_)) => {
      pending.has_dot = true
      pending.state = Complete
      Emit
    }

    // 期望 . (在图名之后)
    (ExpectDot, Dot(_)) => {
      pending.has_dot = true
      pending.state = Complete
      // pending.line += 1
      Emit
    }
    (ExpectDot, token) => SkipError(ParseError::span(token))

    // 已完成
    (Complete, token) => SkipError(ParseError::span(token))

    // 默认跳过
    _ => SkipLine
  }
}

///|
pub impl ParserEngine for NQuadsEngine with fn recognize_end(
  _self : NQuadsEngine,
  pending : PendingQuad,
  results : Array[Span],
) -> Unit {
  results.push(pending.compute_span())
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
      subj: (0, 0),
      pred: (0, 0),
      obj: (0, 0),
      graph: (0, 0),
      has_dot: false,
      state: PendingState::ExpectSubject,
      // line: 0,
      // error_span: (0, 0),
      // has_err: false,
    },
  }
}
