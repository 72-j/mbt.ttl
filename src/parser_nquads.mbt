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
/// 解析步骤
fn NQuadsEngine::step(self : NQuadsEngine, token : Token) -> StepResult {
  match (self.pending.state, token) {
    // 期望主语
    (ExpectSubject, Iri(span) | BlankNode(span)) => {
      self.pending.subj = span
      self.pending.state = ExpectPredicate
      Continue
    }
    (ExpectSubject, PrefName(span)) => SkipError(span)
    (ExpectSubject, Unknown(_)) => Continue

    // 期望谓语
    (ExpectPredicate, Iri(span)) => {
      self.pending.pred = span
      self.pending.state = ExpectObject
      Continue
    }
    (ExpectPredicate, token) => SkipError(ParseError::span(token))

    // 期望宾语
    (ExpectObject, Iri(span) | Literal(span) | BlankNode(span)) => {
      self.pending.obj = span
      self.pending.state = ExpectDotOrGraph
      Continue
    }
    (ExpectObject, token) => SkipError(ParseError::span(token))

    // 期望 . 或 图名
    (ExpectDotOrGraph, Dot(_)) => {
      self.pending.has_dot = true
      self.pending.state = Complete
      Emit
    }
    (ExpectDotOrGraph, Iri(span)) => {
      self.pending.graph = span
      self.pending.state = ExpectDot
      Continue
    }
    (ExpectDotOrGraph, PrefName(span)) => SkipError(span)
    (ExpectDotOrGraph, Unknown(_)) => {
      self.pending.has_dot = true
      self.pending.state = Complete
      Emit
    }

    // 期望 . (在图名之后)
    (ExpectDot, Dot(_)) => {
      self.pending.has_dot = true
      self.pending.state = Complete
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
/// NQuadsEngine - 直接对接 Lexerc，管理 PendingQuad 组装和错误收集
pub(all) struct NQuadsEngine {
  mut pending : PendingQuad
  lexer : Lexerc
  data : ArrayView[Byte]
  mut last_error : (Span, Int)? // (错误位置, 行号)
  mut line : Int
}

///|
/// 创建空 NQuadsEngine
pub fn NQuadsEngine::new(
  lexer : Lexerc,
  data : ArrayView[Byte],
) -> NQuadsEngine {
  NQuadsEngine::{
    pending: PendingQuad::{
      subj: (0, 0),
      pred: (0, 0),
      obj: (0, 0),
      graph: (0, 0),
      has_dot: false,
      state: PendingState::ExpectSubject,
    },
    lexer,
    data,
    last_error: None,
    line: 0,
  }
}

///|
/// 从字节数组创建
pub fn NQuadsEngine::from_bytes(data : FixedArray[Byte]) -> NQuadsEngine {
  NQuadsEngine::new(Lexerc::new(data), data)
}

///|
/// 获取原始数据
pub fn NQuadsEngine::data(self : NQuadsEngine) -> ArrayView[Byte] {
  self.data
}

// ============================================================
// 主解析循环
// ============================================================

///|
/// 获取下一个三元组
pub fn NQuadsEngine::next(
  self : NQuadsEngine,
) -> Result[PendingQuad, ParseError]? {
  self.pending.reset()

  for ;; {
    match self.lexer.next() {
      None => {
        if self.pending.state != ExpectSubject {
          return Some(
            Err(
              ParseError::SyntaxErr(
                "Incomplete triple at end of input",
                self.pending.compute_span(),
              ),
            ),
          )
        }
        return None
      }
      Some(token) =>
        if is_eof_token(token) {
          if self.pending.state != ExpectSubject {
            return Some(
              Err(
                ParseError::SyntaxErr(
                  "Incomplete triple at end of input",
                  self.pending.compute_span(),
                ),
              ),
            )
          }
          return None
        } else {
          match self.step(token) {
            Continue => continue
            Emit => {
              let result = self.pending
              self.line += 1
              return Some(Ok(result))
            }
            SkipLine => {
              self.line += 1
              self.pending.reset()
              continue
            }
            SkipError(span) => {
              self.last_error = Some((span, self.line))
              // 消费整行直到 . 或 EOF
              for ;; {
                match self.lexer.next() {
                  None => break
                  Some(t) =>
                    if is_dot_token(t) {
                      self.line += 1
                      break
                    } else if is_eof_token(t) {
                      break
                    }
                }
              }
              self.pending.reset()
              continue
            }
            Error(err) => {
              self.pending.reset()
              return Some(Err(err))
            }
          }
        }
    }
  }
}
