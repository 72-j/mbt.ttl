///|
pub(all) enum RdfContext {
  TriGRecognizerContext(TriGRecognizerContext)
  NQuadsRecognizerContext(NQuadsRecognizerContext)
  N3RecognizerContext(N3RecognizerContext)
}

///|
pub(all) enum RdfOut {
  Quad(Quad)
  Triple(Triple)
  N3Quad(N3Quad)
} derive(Debug)

///|
pub impl Show for RdfOut with fn output(self, logger : &Logger) -> Unit {
  match self {
    Quad(quad) => logger.write_object(quad)
    Triple(triple) => logger.write_object(triple)
    N3Quad(n3_quad) => logger.write_object(n3_quad)
  }
}

///|
pub fn RdfOut::new(quad : Quad) -> RdfOut {
  Quad(quad)
}

///|
pub fn[TR : TokenRecognizer, RR : RuleRecognizer + StateMachine] SliceIterator::next(
  self : SliceIterator[TR, RR],
  data_world : DataWorld,
) -> Result[RdfOut, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next(data_world) is Some(result) {
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
pub fn[TR : TokenRecognizer, M : StateMachine + RuleRecognizer] Parser::parse_next(
  self : Parser[TR, M],
  data_world : DataWorld,
) -> Result[RdfOut, TurtleError]? {
  for ;; {
    // 1. 优先处理错误
    if self.errors.pop() is Some(e) {
      return Some(
        Err(
          TurtleError::InvalidToken(
            self.lexer.last_token_start(),
            "\{self.lexer.last_token_source()}\{e.to_string()}",
          ),
        ),
      )
    }

    // 2. ✅ 从状态机获取输出
    if self.try_output() is Some(result) {
      return Some(result)
    }

    // 3. 尝试从 Lexer 获取下一个 Token
    let ctx = M::lexer_options(self.context)
    // let ctx = self.lexer_options()
    match self.lexer.parse_next(ctx) {
      Some(Ok(located_token)) => {
        let previous_state = self.engine.current_state()
        self.engine.debug_logger.info("Parser::parse_token = \{located_token}")

        // ✅ 驱动状态机
        self.engine = self.engine.step(located_token, data_world)

        // ✅ 检查是否状态变化（token 没被消费）
        if self.engine.current_state() == previous_state {
          // 状态没变 = token 没被消费，重新用同一个 token 调用
          // 防止无限循环：最多重试一次
          self.engine = self.engine.step(located_token, data_world)
        }

        // ✅ 检查是否完成
        if self.try_finish() is Some(result) {
          return Some(result)
        }

        continue
      }
      // Some(Ok(located_token)) => {
      //   let result = self.engine.step(located_token)

      //   // 检查是否 transition 成功
      //   match
      //     self.engine.transition(
      //       self.engine.current_state(),
      //       located_token,
      //       self.engine.context(),
      //     ) {
      //     Err(e) => {
      //       // transition 失败，跳过此 token
      //       self.errors.push(e)
      //       self.engine = self.engine.reset()
      //       continue
      //     }
      //     Ok((new_machine, _, _)) => self.engine = new_machine
      //   }
      // }
      Some(Err(e)) => {
        // 词法错误
        self.engine = self.engine.reset()
        return Some(
          Err(
            TurtleError::InvalidToken(
              self.lexer.last_token_start(),
              "- \{self.lexer.last_token_source()} \{e.to_string()} - TOKEN is not allowed here.",
            ),
          ),
        )
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
                "Maybe end of input",
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
pub fn[TR, M : StateMachine] Parser::is_end(self : Parser[TR, M]) -> Bool {
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
) -> Result[RdfOut, TurtleError]? {
  if self.engine.outputs.length() > 0 {
    // ✅ 使用 get(0) 获取第一个元素
    let output = match self.engine.outputs.get(0) {
      Some(o) => o
      None => return None
    }
    self.engine = self.engine.remove_first_output()
    return Some(Ok(output))
  }
  None
}

///|
/// 检查并处理完成状态
pub fn[TR, M : StateMachine] Parser::try_finish(
  self : Parser[TR, M],
) -> Result[RdfOut, TurtleError]? {
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
    // self.engine.debug_logger.warn(
    //   "Parser: Engine is accepting but no output generated yet.",
    // )

    // 尚未接受，属于中间状态，继续获取下一个 Token
    return None
  }
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
// pub fn[TR, RR] Parser::lexer_options(
//   self : Parser[TR, RR]
// ) -> LexerOptions? {
//   match self.context {
//     NQuadsRecognizerContext(ctx) => Some(ctx.lexer_options)
//     TriGRecognizerContext(_) => ...
//     N3RecognizerContext(_) => ...
//   }
// }

///|
pub struct ReaderIterator[TR, RR] {
  reader : &Reader
  parser : Parser[TR, RR]
}

///|
pub async fn[RR : RuleRecognizer + StateMachine] ReaderIterator::next(
  self : ReaderIterator[RdfLexer, RR],
  data_world : DataWorld,
) -> Result[RdfOut, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next(data_world) is Some(result) {
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
pub async fn[TR : TokenRecognizer, RR : StateMachine + RuleRecognizer] AsyncReaderIterator::next(
  self : AsyncReaderIterator[TR, RR],
  data_world : DataWorld,
) -> Result[RdfOut, LexerError]? {
  while !self.parser.is_end() {
    if self.parser.parse_next(data_world) is Some(result) {
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
