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
pub fn[TR : TokenRecognizer, RR : RuleRecognizer] SliceIterator::next(
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
pub(all) struct ParserM[TR, M] {
  mut lexer : Lexer[TR]
  mut engine : GenericStateMachine[M] // ← 泛型状态机引擎
  context : RdfContext
  errors : Array[RuleRecognizerError]
}

///|
pub fn[TR, M] ParserM::ParserM(
  lexer : Lexer[TR],
  engine : GenericStateMachine[M], // ← 泛型状态机引擎
  context : RdfContext,
) -> ParserM[TR, M] {
  { lexer, engine, context, errors: [] }
  // pending_token: None,
}

///|
pub fn[TR : TokenRecognizer, M : StateMachine + RuleRecognizer] ParserM::parse_next(
  self : ParserM[TR, M],
) -> Result[RdfOut, TurtleError]? {
  for ;; {
    // 1. 优先处理错误
    if self.errors.pop() is Some(e) {
      return Some(
        Err(
          TurtleError::InvalidToken(
            self.lexer.last_token_start(),
            "\{self.lexer.last_token_source()}\{e.to_string()} - TOKEN is not allowed here",
          ),
        ),
      )
    }

    // 2. ✅ 从状态机获取输出
    if self.try_output() is Some(result) {
      return Some(result)
    }

    // 3. 尝试从 Lexer 获取下一个 Token
    match self.lexer.parse_next(M::lexer_options(self.context)) {
      Some(Ok(located_token)) => {
        // debug("ParserM: token = \{located_token}")
        // debug("ParserM: token raw = '\{self.lexer.last_token_source()}'")

        // ✅ 驱动状态机
        self.engine = self.engine.step(located_token)

        // ✅ 检查是否完成
        if self.try_finish() is Some(result) {
          return Some(result)
        }

        continue
      }
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
                "Unexpected end of input",
                self.lexer.last_token_range().to_range(),
              ),
            )
            return Some(
              Err(
                TurtleError::UnexpectedEndOfInput(
                  self.lexer.last_token_end(),
                  "Unexpected end of input.",
                ),
              ),
            )
          }
        } else {
          return None
        }
    }
  }
}

// ===== ParserM 辅助方法 =====

///|
pub fn[TR, M : StateMachine] ParserM::is_end(self : ParserM[TR, M]) -> Bool {
  self.lexer.is_end() &&
  self.engine.is_accepting() &&
  self.engine.outputs.is_empty() &&
  self.errors.is_empty()
}

///|
pub fn[TR, M] ParserM::end(self : ParserM[TR, M]) -> Bool {
  self.lexer.is_end()
}

///|
/// 尝试返回一个输出
pub fn[TR, M] ParserM::try_output(
  self : ParserM[TR, M],
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
pub fn[TR, M : StateMachine] ParserM::try_finish(
  self : ParserM[TR, M],
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
    // debug("ParserM: Engine is accepting but no output generated yet.")

    // 尚未接受，属于中间状态，继续获取下一个 Token
    return None
  }
}
