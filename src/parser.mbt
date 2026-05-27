///|
type TriGRecognizerContext

///|
type NQuadsRecognizerContext

///|
pub(all) enum Context {
  TriGRecognizerContext(TriGRecognizerContext)
  NQuadsRecognizerContext(NQuadsRecognizerContext)
}

///|
pub(all) enum LexOutput {
  Quad(Quad)
}

///|
pub fn LexOutput::new(quad : Quad) -> LexOutput {
  Quad(quad)
}

///|
pub struct Parser[TR, RR] {
  lexer : Lexer[TR]
  mut state : RR?
  context : Context
  results : Array[LexOutput]
  errors : Array[RuleRecognizerError]
}

///|
pub fn[TR, RR] Parser::new(
  lexer : Lexer[TR],
  recognizer : RR,
  context : Context,
) -> Parser[TR, RR] {
  { lexer, state: Some(recognizer), context, results: [], errors: [] }
}

///|
pub fn[TR, RR] Parser::is_end(self : Parser[TR, RR]) -> Bool {
  self.state is None && self.results.is_empty() && self.errors.is_empty()
}

///|
pub fn[TR : TokenRecognizer, RR : RuleRecognizer] Parser::parse_next(
  self : Parser[TR, RR],
) -> Result[LexOutput, TurtleError]? {
  for ;; {
    // 1. 优先处理错误
    if self.errors.pop() is Some(_error) {
      return Some(
        Err(
          TurtleError::InvalidToken(
            self.lexer.last_token_location(),
            "TOKEN is \{self.lexer.last_token_source()} is not allowed here",
          ),
        ),
      )
    }

    // 2. 优先返回已缓冲的结果
    if self.results.pop() is Some(result) {
      return Some(Ok(result))
    }

    // 3. 尝试从 Lexer 获取下一个 Token
    if self.lexer.parse_next(RR::lexer_options(self.context))
      is Some(lex_result) {
      match lex_result {
        Ok(token) => {
          //  let token = TokenOrLineJump::Token(token)
          self.state = self.state.map(fn(state) {
            state.recognize_next(token, self.context, self.results, self.errors)
          })
          continue
        }
        Err(_e) => {
          self.state = self.state.map(fn(s) { RR::error_recovery_state(s) })
          return Some(
            Err(
              TurtleError::InvalidToken(
                self.lexer.last_token_location(),
                "TOKEN is \{self.lexer.last_token_source()} is not allowed here",
              ),
            ),
          )
        }
      }
      // Lexer 需要更多数据
    } else if self.lexer.is_end() {
      // 处理结束逻辑
      match self.state {
        Some(state) => {
          // 修复：补全 results 参数，且 recognize_end 返回 Unit，无需赋值给变量
          state.recognize_end(self.context, self.results, self.errors)
          self.state = None
          // 注意：如果 recognize_end 内部向 self.results 添加了内容，这里不需要额外 push
          // 如果之前的逻辑依赖 final_outputs，请确认 recognize_end 是否已通过副作用更新了 self.results
        }
        None => ()
      }
    } else {
      return None // 需要更多输入
    }
  }
}

///|
pub fn[TR, RR] Parser::end(self : Parser[TR, RR]) -> Unit {
  self.lexer.end()
}

///|
pub fn[TR, RR] Parser::extend_from_slice(
  self : Parser[TR, RR],
  other : Bytes,
) -> Unit {
  self.lexer.extend_from_slice(other)
}

///|
pub fn[B, RR] Parser::for_reader(
  self : Parser[B, RR],
  reader : &Reader,
) -> ReaderIterator[B, RR] {
  { reader, parser: self }
}

///|
pub fn[B, RR] Parser::for_async_reader(
  self : Parser[B, RR],
  reader : &Reader,
) -> AsyncReaderIterator[B, RR] {
  { reader, parser: self }
}

///|
pub struct ReaderIterator[B, RR] {
  reader : &Reader
  parser : Parser[B, RR]
}

///|
pub struct AsyncReaderIterator[B, RR] {
  reader : &Reader
  parser : Parser[B, RR]
}

///|
pub async fn[TR : TokenRecognizer, RR : RuleRecognizer] AsyncReaderIterator::next(
  self : AsyncReaderIterator[TR, RR],
) -> Result[LexOutput, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next() is Some(result) {
      // 修复：将 TurtleError 转换为 String
      return Some(
        result.map_err(_e => LexerError::SyntaxError("Syntax Error: ")),
      )
    }
    if self.parser.lexer.extend_from_async_read(self.reader) is Err(_e) {
      return Some(Err(LexerError::IoReadError("IO Read Error: ")))
    }
  }
  None
}

///|
pub(all) struct SliceIterator[RR] {
  parser : Parser[Array[Byte], RR]
}
