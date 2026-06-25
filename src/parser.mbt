///|
pub(all) enum RdfContext {
  TriGRecognizerContext(TriGRecognizerContext)
  NQuadsRecognizerContext(NQuadsRecognizerContext)
  N3RecognizerContext(N3RecognizerContext)
}

///|
pub(all) enum RdfStatement {
  Quad(Quad)
  Triple(Triple)
  N3Quad(N3Quad)
} derive(Debug)

///|
impl Show for RdfStatement with fn output(self, logger : &Logger) -> Unit {
  match self {
    Quad(quad) => logger.write_object(quad)
    Triple(triple) => logger.write_object(triple)
    N3Quad(n3_quad) => logger.write_object(n3_quad)
  }
}

///|
pub fn RdfStatement::new(quad : Quad) -> RdfStatement {
  Quad(quad)
}

///|
pub struct Parser[TR, RR] {
  lexer : Lexer[TR]
  mut state : RR?
  context : RdfContext
  results : Array[RdfStatement]
  errors : Array[RuleRecognizerError]
}

///|
pub fn[TR, RR] Parser::Parser(
  lexer : Lexer[TR],
  recognizer : RR,
  context : RdfContext,
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
) -> Result[RdfStatement, TurtleError]? {
  for ;; {
    // 1. 优先处理错误
    if self.errors.pop() is Some(e) {
      return Some(
        Err(
          TurtleError::InvalidToken(
            self.lexer.last_token_start(),
            "- \{self.lexer.last_token_source()}\{e.to_string()} - TOKEN is not allowed here",
          ),
        ),
      )
    }

    // 2. 优先返回已缓冲的结果
    if self.results.pop() is Some(result) {
      return Some(Ok(result))
    }

    // 3. 尝试从 Lexer 获取下一个 Token
    match self.lexer.parse_next(RR::lexer_options(self.context)) {
      // Some(Ok(token)) => {
      //   self.state = self.state.map(fn(state) {
      //     state.recognize_next(token, self.context, self.results, self.errors)
      //   })
      //   continue
      // }
      Some(Ok(token)) => {
        match self.state {
          Some(state) => {
            let new_state = state.recognize_next(
              token,
              self.context,
              self.results,
              self.errors,
            )
            self.state = Some(new_state)
          }
          None => ()
        }
        continue
      }
      Some(Err(e)) => {
        self.state = self.state.map(fn(s) { RR::error_recovery_state(s) })
        return Some(
          Err(
            TurtleError::InvalidToken(
              self.lexer.last_token_start(),
              "- \{self.lexer.last_token_source()} \{e.to_string()}- TOKEN is not allowed here.",
            ),
          ),
        )
      }
      None =>
        if self.lexer.is_end() {
          // 处理结束逻辑
          match self.state {
            Some(state) => {
              state.recognize_end(self.context, self.results, self.errors)
              self.state = None
              // 继续循环，让下一轮返回 results 或 errors
              continue
            }
            None =>
              // 没有状态，没有结果，没有错误，真正结束
              return None
          }
        } else {
          return None
        }
    }
  }
  // Lexer 需要更多数据
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
pub fn[TR, RR] Parser::for_reader(
  self : Parser[TR, RR],
  reader : &Reader,
) -> ReaderIterator[TR, RR] {
  { reader, parser: self }
}

///|
pub fn[TR, RR] Parser::for_async_reader(
  self : Parser[TR, RR],
  reader : &Reader,
) -> AsyncReaderIterator[TR, RR] {
  { reader, parser: self }
}

///|
pub struct ReaderIterator[TR, RR] {
  reader : &Reader
  parser : Parser[TR, RR]
}

///|
pub async fn[RR : RuleRecognizer] ReaderIterator::next(
  self : ReaderIterator[RdfLexer, RR],
) -> Result[RdfStatement, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next() is Some(result) {
      debug("Parser::parse_next: \{result}")
      return Some(
        result.map_err(e => {
          LexerError::SyntaxError("Syntax Error: \{e.to_string()}")
        }),
      )
    }

    // 尝试从 Reader 填充数据
    match self.parser.lexer.extend_from_reader(self.reader) {
      Ok(_) => ()
      // if bytes_read == 0 {
      // 【关键修复】如果读取了 0 字节，说明到达 EOF
      // 必须通知 Lexer/Parser 数据已结束
      // self.parser.lexer.end() 
      // 再次尝试解析，让 Parser 处理剩余的缓冲区或结束状态
      // }

      Err(e) =>
        return Some(
          Err(LexerError::IoReadError("IO Read Error: \{e.to_string()}")),
        )
    }
  }
  None
}

///|
pub struct AsyncReaderIterator[TR, RR] {
  reader : &Reader
  parser : Parser[TR, RR]
}

///|
pub async fn[TR : TokenRecognizer, RR : RuleRecognizer] AsyncReaderIterator::next(
  self : AsyncReaderIterator[TR, RR],
) -> Result[RdfStatement, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next() is Some(result) {
      // 修复：将 TurtleError 转换为 String
      return Some(
        result.map_err(e => {
          LexerError::SyntaxError("Syntax Error: \{e.to_string()}")
        }),
      )
    }
    if self.parser.lexer.extend_from_async_read(self.reader) is Err(e) {
      return Some(
        Err(LexerError::IoReadError("IO Read Error: \{e.to_string()}")),
      )
    }
  }
  None
}

///|
pub(all) struct SliceIterator[TR, RR] {
  parser : Parser[TR, RR]
}

///|
pub fn[TR : TokenRecognizer, RR : RuleRecognizer] SliceIterator::next(
  self : SliceIterator[TR, RR],
) -> Result[RdfStatement, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next() is Some(result) {
      // 修复：将 TurtleError 转换为 String
      return Some(
        result.map_err(e => {
          LexerError::SyntaxError("Syntax Error: \{e.to_string()}")
        }),
      )
    }
    // 对于 slice 迭代器，数据已经在 parser 中，不需要额外读取
    break
  }
  None
}
