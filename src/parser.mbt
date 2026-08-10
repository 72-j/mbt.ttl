///|
pub struct Parser[E] {
  lexer : Lexerc
  engine : E
  pending : PendingQuad
  errors : Array[ParseError]
  data : ArrayView[Byte]
  // line : Int // 当前行号
}

///|
pub fn[E : ParserEngine] Parser::new(
  lexer : Lexerc,
  engine : E,
  data : ArrayView[Byte],
  // line : Int,
) -> Parser[E] {
  { lexer, engine, pending: engine.create_pending(), errors: [], data }
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
fn is_eof_token(token : Token) -> Bool {
  match token {
    Token::EOF(_) => true
    _ => false
  }
}

///|
/// 解析步骤结果
pub(all) enum StepResult {
  Continue // 继续解析下一个 token
  Emit // 触发输出（emit pending）
  SkipLine // 跳过当前行（遇到错误时）
  Error(ParseError) // 遇到错误
}

///|
pub trait ParserEngine {
  ///| 获取错误恢复状态
  fn error_recovery_state(Self) -> Self

  ///| 创建初始的 PendingQuad
  /// 返回 None 表示当前不需要开始一个新的 Quad（如遇到空行或注释）
  fn create_pending(Self) -> PendingQuad

  ///| 消费一个 token，返回解析结果
  fn step(Self, pending : PendingQuad, token : Token) -> StepResult

  ///| 检查 pending 是否完整（可用于最终验证）
  fn is_complete(Self, pending : PendingQuad) -> Bool

  ///| 处理结束
  /// 当输入结束时调用，用于处理最后一个未完成的 pending
  fn recognize_end(Self, pending : PendingQuad, results : Array[Span]) -> Unit

  ///| 获取引擎特定的 LexerOptions（可选）
  // fn lexer_options() -> RdfMode
}

///|
pub fn[E] Parser::get_errors(self : Parser[E]) -> Array[ParseError] {
  self.errors
}

///|
pub fn[E : ParserEngine] Parser::next(
  self : Parser[E],
) -> Result[PendingQuad, ParseError]? {
  self.pending.reset()

  for ;; {
    match self.lexer.next() {
      None => {
        if self.pending.state != ExpectSubject &&
          (
            self.pending.subj is Some(_) ||
            self.pending.pred is Some(_) ||
            self.pending.obj is Some(_)
          ) {
          self.errors.push(
            ParseError::InvalidToken(
              "Incomplete triple at end of input",
              self.pending.compute_span(),
            ),
          )
        }
        return None
      }
      Some(token) =>
        if is_eof_token(token) {
          if self.pending.state != ExpectSubject &&
            (
              self.pending.subj is Some(_) ||
              self.pending.pred is Some(_) ||
              self.pending.obj is Some(_)
            ) {
            self.errors.push(
              ParseError::InvalidToken(
                "Incomplete triple at end of input",
                self.pending.compute_span(),
              ),
            )
          }
          return None
        } else {
          match self.engine.step(self.pending, token) {
            Continue => continue
            Emit => {
              let result = self.pending
              return Some(Ok(result))
            }
            SkipLine => {
              self.pending.reset()
              continue
            }
            Error(err) => {
              self.errors.push(err)
              self.pending.reset()
              let error_result = Some(Err(err))
              // 返回错误后，调用者决定是否继续
              return error_result
              // return Some(Err(err))
            }
          }
        }
    }
  }
}
