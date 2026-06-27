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
  //mut  pending_token : LocatedTokenOrLineJump? // ← 新增
}

///|
pub fn[TR, RR] Parser::Parser(
  lexer : Lexer[TR],
  recognizer : RR,
  context : RdfContext,
) -> Parser[TR, RR] {
  { lexer, state: Some(recognizer), context, results: [], errors: [] }
  // pending_token: None,
}

///|
pub fn[TR, RR] Parser::is_end(self : Parser[TR, RR]) -> Bool {
  self.state is None && self.results.is_empty() && self.errors.is_empty()
}
///|
pub fn[TR : TokenRecognizer, RR : RuleRecognizer] Parser::parse_next(
  self : Parser[TR, RR],
) -> Result[RdfStatement, TurtleError]? {
  while true {
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

    // 2. 优先返回已缓冲的结果
    if self.results.pop() is Some(result) {
      return Some(Ok(result))
    }

    // 3. 尝试从 Lexer 获取下一个 Token
    match self.lexer.parse_next(RR::lexer_options(self.context)) {
      Some(Ok(token)) => {
        debug("Parser: token before = \{token}")

        match self.state {
          Some(state) => {
            let new_state = state.recognize_next(
              token,
              self.context,
              self.results,
              self.errors,
            )
            debug("Parser: token after = \{token}")

            self.state = Some(new_state)
          }
          None => ()
        }
        // 继续循环，处理可能产生的新结果或错误，或者获取下一个 token
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
          // Lexer 需要更多数据，暂时无法继续解析
          return None
        }
    }
  }
  // 添加此行以满足编译器对 while 循环必须有返回值的要求
  // 逻辑上此行不可达
  return None
}
///|
// pub fn[TR : TokenRecognizer, RR : RuleRecognizer] Parser::parse_next(
//   self : Parser[TR, RR],
// ) -> Result[RdfStatement, TurtleError]? {
//   for ;; {
//     // 1. 优先处理错误
//     if self.errors.pop() is Some(e) {
//       return Some(
//         Err(
//           TurtleError::InvalidToken(
//             self.lexer.last_token_start(),
//             "\{self.lexer.last_token_source()}\{e.to_string()} - TOKEN is not allowed here",
//           ),
//         ),
//       )
//     }

//     // 2. 优先返回已缓冲的结果
//     if self.results.pop() is Some(result) {
//       return Some(Ok(result))
//     }

//     // 3. 尝试从 Lexer 获取下一个 Token
//     match self.lexer.parse_next(RR::lexer_options(self.context)) {
//       // Some(Ok(token)) => {
//       //   self.state = self.state.map(fn(state) {
//       //     state.recognize_next(token, self.context, self.results, self.errors)
//       //   })
//       //   continue
//       // }
//       Some(Ok(token)) => {
//         debug("Parser: token before = \{token}")

//         match self.state {
//           Some(state) => {
//             let new_state = state.recognize_next(
//               token,
//               self.context,
//               self.results,
//               self.errors,
//             )
//             debug("Parser: token after = \{token}")

//             self.state = Some(new_state)
//           }
//           None => ()
//         }
//         continue
//       }
//       Some(Err(e)) => {
//         self.state = self.state.map(fn(s) { RR::error_recovery_state(s) })
//         return Some(
//           Err(
//             TurtleError::InvalidToken(
//               self.lexer.last_token_start(),
//               "- \{self.lexer.last_token_source()} \{e.to_string()}- TOKEN is not allowed here.",
//             ),
//           ),
//         )
//       }
//       None =>
//         if self.lexer.is_end() {
//           // 处理结束逻辑
//           match self.state {
//             Some(state) => {
//               state.recognize_end(self.context, self.results, self.errors)
//               self.state = None
//               // 继续循环，让下一轮返回 results 或 errors
//               continue
//             }
//             None =>
//               // 没有状态，没有结果，没有错误，真正结束
//               return None
//           }
//         } else {
//           return None
//         }
//     }
//   }
//   // Lexer 需要更多数据
// }
// pub fn[TR : TokenRecognizer, RR : RuleRecognizer] Parser::parse_next(
//   self : Parser[TR, RR],
// ) -> Result[RdfStatement, TurtleError]? {
//   for ;; {
//     // 1. 优先处理错误
//     if self.errors.pop() is Some(e) {
//       return Some(
//         Err(
//           TurtleError::InvalidToken(
//             self.lexer.last_token_start(),
//             "\{self.lexer.last_token_source()}\{e.to_string()} - TOKEN is not allowed here",
//           ),
//         ),
//       )
//     }

//     // 2. 优先返回已缓冲的结果
//     if self.results.pop() is Some(result) {
//       return Some(Ok(result))
//     }

//     // 3. 获取 token（如果有待处理的，用待处理的）
//     match self.pending_token {
//       Some(token) => {
//         self.pending_token = None
//         // 重用 pending_token，逻辑与下方获取新 token 后一致
//         match self.state {
//           Some(state) => {
//             let old_sig = RR::stack_signature(state).unwrap_or((0, None))

//             let new_state = state.recognize_next(
//               token,
//               self.context,
//               self.results,
//               self.errors,
//             )
//             self.state = Some(new_state)
//             let new_sig = RR::stack_signature(new_state).unwrap_or(
//               (0, None),
//             )
//             // 如果签名变了（压入了新状态），用同一个 token 继续
//             if old_sig != new_sig {
//               self.pending_token = Some(token)
//             }
//           }
//           None => ()
//         }
//         continue
//       }
//       None =>
//         match self.lexer.parse_next(RR::lexer_options(self.context)) {
//           Some(Ok(token)) => {
//             match self.state {
//               Some(state) => {
//                 let old_sig = RR::stack_signature(state).unwrap_or((0, None))

//                 let new_state = state.recognize_next(
//                   token,
//                   self.context,
//                   self.results,
//                   self.errors,
//                 )
//                 self.state = Some(new_state)
//                 let new_sig = RR::stack_signature(new_state).unwrap_or(
//                   (0, None),
//                 )
//                 // 如果签名变了（压入了新状态），用同一个 token 继续
//                 if old_sig != new_sig {
//                   self.pending_token = Some(token)
//                 }
//               }
//               None => ()
//             }
//             continue
//           }
//           Some(Err(e)) => {
//             self.state = self.state.map(fn(s) { RR::error_recovery_state(s) })
//             return Some(
//               Err(
//                 TurtleError::InvalidToken(
//                   self.lexer.last_token_start(),
//                   "- \{self.lexer.last_token_source()} \{e.to_string()}- TOKEN is not allowed here.",
//                 ),
//               ),
//             )
//           }
//           None =>
//             if self.lexer.is_end() {
//               // 处理结束逻辑
//               match self.state {
//                 Some(state) => {
//                   state.recognize_end(self.context, self.results, self.errors)
//                   self.state = None
//                   // 继续循环，让下一轮返回 results 或 errors
//                   continue
//                 }
//                 None =>
//                   // 没有状态，没有结果，没有错误，真正结束
//                   return None
//               }
//             } else {
//               return None
//             }
//         }
//     }
//   }
//   // Lexer 需要更多数据
// }

///|
// pub fn[TR : TokenRecognizer, RR : RuleRecognizer] Parser::parse_next(
//   self : Parser[TR, RR],
// ) -> Result[RdfStatement, TurtleError]? {
//   for ;; {
//     debug(" Parser::parse_next Panding token \{self.pending_token} ")
//     // 1. 优先处理错误
//     if self.errors.pop() is Some(e) {
//       return Some(
//         Err(
//           TurtleError::InvalidToken(
//             self.lexer.last_token_start(),
//             "\{self.lexer.last_token_source()}\{e.to_string()} - TOKEN is not allowed here",
//           ),
//         ),
//       )
//     }

//     // 2. 优先返回已缓冲的结果
//     if self.results.pop() is Some(result) {
//       return Some(Ok(result))
//     }

//     // 3. 获取 token（如果有待处理的，用待处理的）
//     match self.pending_token {
//       Some(_t) => {
//         self.pending_token = None
//         // t
//       }
//       None =>
//         match self.lexer.parse_next(RR::lexer_options(self.context)) {
//           // Some(Ok(token)) => {
//           //   self.state = self.state.map(fn(state) {
//           //     state.recognize_next(token, self.context, self.results, self.errors)
//           //   })
//           //   continue
//           // }
//           Some(Ok(token)) => {
//             match self.state {
//               Some(state) => {
//                 let old_sig = RR::stack_signature(state).unwrap_or((0, None))

//                 let new_state = state.recognize_next(
//                   token,
//                   self.context,
//                   self.results,
//                   self.errors,
//                 )
//                 self.state = Some(new_state)
//                 let new_sig = RR::stack_signature(new_state).unwrap_or(
//                   (0, None),
//                 )
//                 // 如果签名变了（压入了新状态），用同一个 token 继续
//                 if old_sig != new_sig {
//                   self.pending_token = Some(token)
//                 }
//               }
//               None => ()
//             }
//             continue
//           }
//           Some(Err(e)) => {
//             self.state = self.state.map(fn(s) { RR::error_recovery_state(s) })
//             return Some(
//               Err(
//                 TurtleError::InvalidToken(
//                   self.lexer.last_token_start(),
//                   "- \{self.lexer.last_token_source()} \{e.to_string()}- TOKEN is not allowed here.",
//                 ),
//               ),
//             )
//           }
//           None =>
//             if self.lexer.is_end() {
//               // 处理结束逻辑
//               match self.state {
//                 Some(state) => {
//                   state.recognize_end(self.context, self.results, self.errors)
//                   self.state = None
//                   // 继续循环，让下一轮返回 results 或 errors
//                   continue
//                 }
//                 None =>
//                   // 没有状态，没有结果，没有错误，真正结束
//                   return None
//               }
//             } else {
//               return None
//             }
//         }
//     }
//   }
//   // Lexer 需要更多数据
// }

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

// fn Parser::stack_signature(self: Parser[RdfLexer,TriGRecognizer]) -> Option[(Int, Option[TriGState])] {
//   match self.state {
//     Some(state) => Some((state.stack.length(), state.stack.last()))
//     None => None
//   }
// }
