///|
pub fn[RL : TokenRecognizer] Lexer::parse_next(
  self : Lexer[RL],
  options : LexerOptions?,
) -> Result[LocatedToken, TokenRecognizerError]? {
  // 检查是否结束
  if self.is_ending && self.position.buffer_offset >= self.data.length() {
    return None
  }

  // 1. 记录跳过前的位置
  let before_offset = self.position.buffer_offset

  // 2. 跳过空白和注释
  if self.skip_whitespaces_and_comments() {
    // 返回 LineJump
    let range = Range::Range(before_offset, self.position.buffer_offset)

    return Some(Ok(LocatedToken(N3Token::LineJump, range)))
  }

  // 3. 没有空白需要处理，调用识别器
  let start_offset = self.position.buffer_offset
  let view = self.data[start_offset:]

  match
    self.parser.recognize_next_token(
      view,
      self.is_ending,
      options,
      SourcePos::default(),
    ) {
    Some((consumed, result)) => {
      let actual_consumed = if consumed <= 0 { 1 } else { consumed }

      self.position.buffer_offset += actual_consumed
      self.position.global_offset += actual_consumed

      // 统计换行
      let consumed_view = self.data[start_offset:start_offset + actual_consumed]
      let mut line_jumps = 0
      for b in consumed_view {
        if b == b'\n' {
          line_jumps += 1
        }
      }
      self.position.global_line += line_jumps

      match result {
        Ok(token) => {
          let range = Range::Range(start_offset, start_offset + actual_consumed)
          Some(Ok(LocatedToken(token.into_token(), range)))
        }
        Err(e) => Some(Err(e))
      }
    }
    None => None
  }
}

// /|
// pub fn[RL : TokenRecognizer] Lexer::parse_next(
//   self : Lexer[RL],
//   options : LexerOptions?,
// ) -> Result[LocatedToken, TokenRecognizerError]? {
//   if self.is_ending && self.position.buffer_offset >= self.data.length() {
//     return None
//   }

//   // 1. 跳过空白和注释
//   match self.skip_whitespaces_and_comments() {
//     Some(true) => {
//       self.previous_position = self.position
//       return Some(
//         Ok(
//           LocatedToken(
//             N3Token::LineJump,
//             self.current_token_source_range().to_range(),
//           ),
//         ),
//       )
//     }
//     Some(false) => ()
//     None => return None
//   }

//   // 2. 记录 Token 起始状态
//   // 【关键】在调用识别器之前，将当前位置保存为 previous_position
//   self.previous_position = self.position

//   // token_start_pos 包含了起始的全局偏移量、行号等信息
//   let token_start_pos = self.position_from_position(self.previous_position)

//   // 获取当前剩余数据的视图
//   let view = self.data[self.position.buffer_offset:]

//   // 使用命名参数确保 line, column, offset 对应正确
//   let location_pos = SourcePos::SourcePos(
//     token_start_pos.line,
//     token_start_pos.column,
//     token_start_pos.offset,
//   )

//   // 3. 调用识别器，传入真实的 location_pos
//   match
//     self.parser.recognize_next_token(
//       view,
//       self.is_ending,
//       options,
//       location_pos,
//     ) {
//     Some((consumed, result)) => {
//       // 【防御性检查】确保消耗了字符
//       let actual_consumed = if consumed == 0 {
//         debug("WARNING: Lexer recognized token with 0 consumption, forcing 1")
//         1  // 强制推进 1 个字符避免死循环
//       } else {
//         consumed
//       }

//       debug_assert(() => actual_consumed > 0)

//       // 4. 更新 Lexer 内部状态 (Position)
//       let consumed_view = self.data[self.position.buffer_offset:self.position.buffer_offset +
//         actual_consumed]
//       let (new_line_jumps, new_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(
//         consumed_view,
//       )

//       if new_line_jumps > 0 {
//         self.position.line_start_buffer_offset = self.position.buffer_offset +
//           new_line_start
//       }
//       self.position.buffer_offset += actual_consumed
//       self.position.global_offset += actual_consumed
//       self.position.global_line += new_line_jumps

//       // 5. 记录 Token 结束状态
//       let token_end_pos = self.position_from_position(self.position)

//       // 6. 处理结果
//       Some(
//         result
//         .map(fn(t) {
//           match t.into_token() {
//             t =>
//               LocatedToken(
//                 t,
//                 Range::Range(token_start_pos.offset, token_end_pos.offset),
//               )

//             // None => LocatedToken::LineJump(self.position.global_line)
//           }
//         })
//         .map_err(fn(e) {
//           match e {
//             TokenRecognizerError::InvalidToken(_, range) => {
//               let global_start = token_start_pos.offset + range.start
//               let global_end = token_start_pos.offset + range.end

//               // 注意：这里截取数据用于错误信息，确保范围有效
//               let error_snippet = if global_start < self.data.length() {
//                 let end_idx = Int::min(global_end, self.data.length())
//                 self.data[global_start:end_idx]
//               } else {
//                 []
//               }

//               TokenRecognizerError::InvalidToken(
//                 error_snippet,
//                 Range::Range(global_start, global_end),
//               )
//             }
//             _ => {
//               debug("Lexer error at \{token_start_pos}: \{e.to_string()}")
//               e
//             }
//           }
//         }),
//       )
//     }
//     None => None
//   }
// }
