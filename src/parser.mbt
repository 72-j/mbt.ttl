///|
pub struct Parser[E] {
  lexer : Lexerc
  engine : E
  pending : PendingQuad
  data : ArrayView[Byte]
  mut last_error : (Span, Int)? // (span, line)  mut line : Int
  mut line : Int
}

///|
pub fn[E : ParserEngine] Parser::new(
  lexer : Lexerc,
  engine : E,
  data : ArrayView[Byte],
) -> Parser[E] {
  {
    lexer,
    engine,
    pending: engine.create_pending(),
    data,
    last_error: None,
    line: 0,
    // err_line: 0,
  }
}

///|
pub fn[E : ParserEngine] Parser::from_bytes(
  data : FixedArray[Byte],
  engine : E,
) -> Parser[E] {
  Parser::new(Lexerc::new(data), engine, data)
}

///|
pub fn nquads_parser(data : FixedArray[Byte]) -> Parser[NQuadsEngine] {
  let engine = NQuadsEngine::new()
  Parser::from_bytes(data, engine)
}

///|
pub fn[E] Parser::data(self : Parser[E]) -> ArrayView[Byte] {
  self.data
}

///|
// pub fn[E] Parser::get_error(self : Parser[E]) -> ParseError? {
//   self.last_error
// }

///|
fn is_eof_token(token : Token) -> Bool {
  match token {
    Token::EOF(_) => true
    _ => false
  }
}

///|
fn is_dot_token(token : Token) -> Bool {
  match token {
    Token::Dot(_) => true
    _ => false
  }
}

///|
/// 解析步骤结果
pub(all) enum StepResult {
  Continue // 继续解析下一个 token
  Emit // 触发输出（emit pending）
  SkipLine // 跳过当前行（遇到错误时）
  SkipError(Span) // 带错误 span 跳过
  Error(ParseError) // 遇到错误
}

///|
pub trait ParserEngine {
  ///| 获取错误恢复状态
  fn error_recovery_state(Self) -> Self

  ///| 创建初始的 PendingQuad
  fn create_pending(Self) -> PendingQuad

  ///| 消费一个 token，返回解析结果
  fn step(Self, pending : PendingQuad, token : Token) -> StepResult

  ///| 检查 pending 是否完整
  fn is_complete(Self, pending : PendingQuad) -> Bool

  ///| 处理结束
  fn recognize_end(Self, pending : PendingQuad, results : Array[Span]) -> Unit
}

///|
// pub fn[E] Parser::get_errors(self : Parser[E]) -> Array[ParseError] {
//   self.errors
// }

///|
pub fn[E : ParserEngine] Parser::next(
  self : Parser[E],
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
          match self.engine.step(self.pending, token) {
            Continue => continue
            Emit => {
              let result = self.pending
              self.line += 1 // ← 正常三元组，行号 +1
              return Some(Ok(result))
            }
            SkipLine => {
              // 正常跳过，reset 后继续
              self.line += 1
              self.pending.reset()
              continue
            }
            SkipError(span) => {
              // 消费整行，收集错误
              // debug("skip error line \{self.pending.line}")
              self.last_error = Some((span, self.line))
              // self.err_line=self.line
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
              // self.line += 1
              self.pending.reset()
              return Some(Err(err))
            }
          }
        }
    }
  }
}
