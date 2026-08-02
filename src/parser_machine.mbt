///|
pub(all) enum RdfContext {
  NQuadsRecognizerContext(NQuadsRecognizerContext)
}

///|
pub(all) enum RdfOut {
  Quad(Quad)
  Triple(Triple)
} derive(Debug)

///|
pub impl Show for RdfOut with fn output(self, logger : &Logger) -> Unit {
  match self {
    Quad(quad) => logger.write_object(quad)
    Triple(triple) => logger.write_object(triple)
  }
}

///|
pub fn RdfOut::new(quad : Quad) -> RdfOut {
  Quad(quad)
}

///|
pub fn[TR : TokenRecognizer, RR : GenMachine] SliceIterator::next(
  self : SliceIterator[TR, RR],
) -> Result[RdfOut, LexerError]? {
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

///|
pub(all) struct Parser[TR, M] {
  mut lexer : Lexer[TR]
  mut engine : GenericStateMachine[M] // ← 泛型状态机引擎
  context : RdfContext
  errors : Array[RuleRecognizerError]
}

///|
pub fn[TR, M] Parser::Parser(
  lexer : Lexer[TR],
  engine : GenericStateMachine[M], // ← 泛型状态机引擎
  context : RdfContext,
) -> Parser[TR, M] {
  { lexer, engine, context, errors: [] }
  // pending_token: None,
}

///|
pub fn[TR : TokenRecognizer, M : GenMachine] Parser::parse_next(
  self : Parser[TR, M],
) -> Result[RdfOut, TokenRecognizerError]? {
  for ;; {
    // 1. 优先处理错误
    if self.errors.pop() is Some(e) {
      let range = self.lexer.current_token_range()
      let bytes = self.lexer.range_to_bytes(range)
      return Some(
        Err(TokenRecognizerError::InvalidToken(e.message(), bytes, range)),
      )
    }

    // 2. ✅ 从状态机获取输出
    if self.try_output() is Some(result) {
      return Some(result)
    }

    // 3. 尝试从 Lexer 获取下一个 Token
    let ctx = self.lexer_options()
    // let ctx = self.lexer_options()
    match self.lexer.parse_next(ctx) {
      Some(Ok(located_token)) => {
        let previous_state = self.engine.current_state()
        self.engine.debug_logger.info("Parser::parse_token = \{located_token}")

        // ✅ 驱动状态机
        self.engine = self.engine.step(located_token)

        // ✅ 检查是否状态变化（token 没被消费）
        if self.engine.current_state() == previous_state {
          // 状态没变 = token 没被消费，重新用同一个 token 调用
          // 防止无限循环：最多重试一次
          self.engine = self.engine.step(located_token)
        }

        // ✅ 检查是否完成
        if self.try_finish() is Some(result) {
          return Some(result)
        }

        continue
      }
      Some(Err(e)) => {
        // 词法错误
        self.engine = self.engine.reset()
        let range = self.lexer.current_token_range()
        let bytes = self.lexer.range_to_bytes(range)

        let range = self.lexer.current_token_range()
        // self.errors.push(RuleRecognizerError::SyntaxError(e.message(), range))
        self.engine.lexer_errors.push((e.message(), bytes, range))
        // 跳过至少一个字符
        // 消费并继续
        self.lexer.position.buffer_offset += bytes.length().max(1)
        self.engine = self.engine.reset()

        self.engine = self.engine.reset()
        // ★ 跳过到下一个空白或换行
        // while self.lexer.position.buffer_offset < self.lexer.data.length() {
        //   if self.lexer.data[self.lexer.position.buffer_offset] == b'\n' {
        //     self.lexer.position.buffer_offset += 1 // 跳过换行
        //     break
        //   }
        //   self.lexer.position.buffer_offset += 1
        // }
        continue
        // ★ 继续解析下一行！
        // return Some(
        //   Err(TokenRecognizerError::InvalidToken(e.message(), bytes, range)),
        // )
      }
      None =>
        if self.lexer.is_end() {
          // ✅ 结束处理

          if self.engine.is_accepting() {
            // 返回剩余输出
            if self.engine.outputs.length() > 0 {
              let output = match self.engine.outputs.pop() {
                Some(o) => o
                None => return None
              }
              self.engine = self.engine.remove_first_output()
              return Some(Ok(output))
            }
            return None
          } else {
            // 未完成
            self.errors.push(
              RuleRecognizerError::SyntaxError(
                "Unexpected end of last input",
                self.lexer.last_token_range().to_range(),
              ),
            )
            // return Some(
            //   Err(
            //     TurtleError::UnexpectedEndOfInput(
            //       self.lexer.last_token_end(),
            //       "Unexpected end of input.",
            //     ),
            //   ),
            // )
          }
        } else {
          return None
        }
    }
  }
}

// ===== Parser 辅助方法 =====

///|
pub fn[TR, M : GenMachine] Parser::is_end(self : Parser[TR, M]) -> Bool {
  self.lexer.is_end() &&
  self.engine.is_accepting() &&
  self.engine.outputs.is_empty() &&
  self.errors.is_empty()
}

///|
pub fn[TR, M] Parser::end(self : Parser[TR, M]) -> Unit {
  self.lexer.end()
}

///|
/// 尝试返回一个输出
pub fn[TR, M] Parser::try_output(
  self : Parser[TR, M],
) -> Result[RdfOut, TokenRecognizerError]? {
  // 先检查是否有输出
  if self.engine.outputs.length() > 0 {
    let output = match self.engine.outputs.get(0) {
      Some(o) => o
      None => return None
    }
    self.engine = self.engine.remove_first_output()

    // ★ 如果还有词法错误，记录到输出中（或者先清空）
    return Some(Ok(output))
  }

  // 没有输出了，检查词法错误
  if self.engine.lexer_errors.length() > 0 {
    let (msg, bytes, range) = self.engine.lexer_errors.pop().unwrap()
    return Some(Err(TokenRecognizerError::InvalidToken(msg, bytes, range)))
  }

  None
}

///|
/// 检查并处理完成状态
pub fn[TR, M : GenMachine] Parser::try_finish(
  self : Parser[TR, M],
) -> Result[RdfOut, TokenRecognizerError]? {
  if self.engine.is_accepting() {
    if self.engine.outputs.length() > 0 {
      let output = match self.engine.outputs.get(0) {
        Some(o) => o
        None => return None
      }
      self.engine = self.engine.remove_first_output()
      return Some(Ok(output))
    }
    // 已接受但无输出，可能是一个空的成功状态，继续解析
    return None
  } else {

    // 尚未接受，属于中间状态，继续获取下一个 Token
    return None
  }
}

///|
pub fn[TR, RR] Parser::extend_from_slice(
  self : Parser[TR, RR],
  other : Array[Byte],
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
pub fn[TR, RR] Parser::lexer_options(self : Parser[TR, RR]) -> LexerOptions? {
  match self.context {
    NQuadsRecognizerContext(ctx) => Some(ctx.lexer_options)
  }
}

///|
pub struct ReaderIterator[TR, RR] {
  reader : &Reader
  parser : Parser[TR, RR]
}

///|
pub async fn[RR : GenMachine] ReaderIterator::next(
  self : ReaderIterator[RdfLexer, RR],
) -> Result[RdfOut, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next() is Some(result) {
      debug("Parser::parse_next: \{@debug.to_string(result)}")
      return Some(
        result.map_err(e => {
          LexerError::SyntaxError("Syntax Error: \{e.to_string()}")
        }),
      )
    }

    // 尝试从 Reader 填充数据
    match self.parser.lexer.extend_from_reader(self.reader) {
      Ok(bytes_read) =>
        if bytes_read == 0 {
          // EOF reached
          self.parser.lexer.end()
          // 如果此时 parser 还没有结束，下一轮循环会处理结束逻辑或报错
        } else {
          // 成功读取数据，继续循环让 parse_next 尝试解析

        }
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
pub async fn[TR : TokenRecognizer, RR : GenMachine] AsyncReaderIterator::next(
  self : AsyncReaderIterator[TR, RR],
) -> Result[RdfOut, LexerError]? {
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
