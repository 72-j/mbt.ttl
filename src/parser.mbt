// ============================================================
// N-Triples 解析器
// 基于词法分析器 + 状态机引擎
// ============================================================

///|
/// N-Triples 解析器
pub struct Parser[E] {
  lexer : Lexerc // 词法分析器
  engine : E // 解析引擎
  pending : PendingQuad // 当前处理的三元组
  data : ArrayView[Byte]
  mut last_error : (Span, Int)? // (错误位置, 行号)
  mut line : Int
}

///|
/// 创建解析器
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
  }
}

///|
/// 从字节数组创建
pub fn[E : ParserEngine] Parser::from_bytes(
  data : FixedArray[Byte],
  engine : E,
) -> Parser[E] {
  Parser::new(Lexerc::new(data), engine, data)
}

///|
/// 创建 N-Triples 专用解析器
pub fn nquads_parser(data : FixedArray[Byte]) -> Parser[NQuadsEngine] {
  Parser::from_bytes(data, NQuadsEngine::new())
}

///|
/// 获取原始数据
pub fn[E] Parser::data(self : Parser[E]) -> ArrayView[Byte] {
  self.data
}

// ============================================================
// 辅助函数
// ============================================================

///|
fn is_eof_token(token : Token) -> Bool {
  token is Token::EOF(_)
}

///|
fn is_dot_token(token : Token) -> Bool {
  token is Token::Dot(_)
}

///|
/// 解析步骤结果
pub(all) enum StepResult {
  Continue // 继续解析
  Emit // 触发输出
  SkipLine // 跳过当前行
  SkipError(Span) // 带错误信息跳过
  Error(ParseError)
}

///|
/// 解析引擎 trait
pub trait ParserEngine {
  fn error_recovery_state(Self) -> Self
  fn create_pending(Self) -> PendingQuad
  fn step(Self, pending : PendingQuad, token : Token) -> StepResult
  fn is_complete(Self, pending : PendingQuad) -> Bool
  fn recognize_end(Self, pending : PendingQuad, results : Array[Span]) -> Unit
}

// ============================================================
// 主解析循环
// ============================================================

///|
/// 获取下一个三元组
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
