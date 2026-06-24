pub fn[RL : TokenRecognizer] Lexer::parse_next(
  self : Lexer[RL],
  options : LexerOptions?,
) -> Result[LocatedTokenOrLineJump, TokenRecognizerError]? { // 修改返回类型以匹配 LocatedN3Token
  if self.is_ending && self.position.buffer_offset >= self.data.length() {
    return None
  }

  // 1. 跳过空白和注释
  match self.skip_whitespaces_and_comments() {
    Some(true) => {
      // 遇到换行符，更新 previous_position 为换行后的位置
      self.previous_position = self.position
      // 注意：LineJump 通常不需要携带 Token 数据，这里可能需要适配 TokenOrLineJump 的定义
      // 假设 TokenOrLineJump::LineJump 不包含泛型数据，或者需要特殊处理
      // 如果 LineJump 必须携带类型，可能需要调整为 Ok(TokenOrLineJump::LineJump) 且泛型兼容
      // 此处假设 TokenOrLineJump[T] 中 LineJump 变体不依赖 T，或者 T 为 Unit/Option
      // 若编译错误，需检查 TokenOrLineJump 定义。通常 LineJump 是独立变体。
      return Some(Ok(LocatedTokenOrLineJump::LineJump(self.position.global_line))) 
    }
    Some(false) => () // 继续
    None => return None // 需要更多数据
  }

  // 2. 记录 Token 起始状态
  self.previous_position = self.position
  let token_start_pos = self.position_from_position(self.previous_position)

  // 获取当前剩余数据的视图
  let view = self.data[self.position.buffer_offset:]

  // 3. 调用识别器
  match self.parser.recognize_next_token(view, self.is_ending, options) {
    Some((consumed, result)) => {
      debug_assert(() => consumed > 0)
      
      // 4. 更新 Lexer 内部状态 (Position)
      let consumed_view = self.data[self.position.buffer_offset:self.position.buffer_offset + consumed]
      let (new_line_jumps, new_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(consumed_view)
      
      if new_line_jumps > 0 {
        self.position.line_start_buffer_offset = self.position.buffer_offset + new_line_start
      }
      self.position.buffer_offset += consumed
      self.position.global_offset += consumed
      self.position.global_line += new_line_jumps

      // 5. 记录 Token 结束状态
      let token_end_pos = self.position_from_position(self.position)

      // 6. 处理结果
      Some(
        result
        .map(fn(t ) {
          // 构建 LocatedN3Token，仅包含定义的字段 token 和 range
          match t.into_token() {
            Some(t) => LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(
              t,
              Range::Range(token_start_pos.offset, token_end_pos.offset)
            ))
            None => LocatedTokenOrLineJump::LineJump(self.position.global_line)
          }
          // LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(
          //   t.into_token().unwrap(),
          //   Range::Range(token_start_pos.offset, token_end_pos.offset)
          //   // 移除了不存在的 start_pos 和 end_pos 字段
          // ))
        })
        .map_err(fn(e) {
          // 优化错误位置计算
          match e {
            TokenRecognizerError::InvalidToken(_, range) => {
              let global_start = token_start_pos.offset + range.start
              let global_end = token_start_pos.offset + range.end
              
              TokenRecognizerError::InvalidToken(
                self.data[token_start_pos.offset:global_end],
                Range::Range(global_start, global_end)
              )
            }
            _ => {
              debug("Lexer error at \{token_start_pos}: \{e.to_string()}")
              e 
            }
          }
        }),
      )
    }
    None => None
  }
}

// ///|
// pub fn[RL : TokenRecognizer] Lexer::parse_next(
//   self : Lexer[RL],
//   options : LexerOptions?,
// ) -> Result[TokenOrLineJump[N3Token], TokenRecognizerError]? {
//   if self.is_ending && self.position.buffer_offset >= self.data.length() {
//     return None
//   }
//   // ✅ 记录 token 起始位置

//   self.current_token_start = self.current_offset()

//   match self.skip_whitespaces_and_comments() {
//     Some(true) => {
//       debug("DEBUG: Skipped line jump")

//       self.previous_position = self.position
//       // ✅ 记录 token 结束位置
//       self.current_token_end = self.current_offset()
//       return Some(Ok(TokenOrLineJump::LineJump))
//     }
//     Some(false) => () // 继续执行后续逻辑
//     None => return None // 需要更多数据
//   }
//   self.previous_position = self.position

//   // 获取当前剩余数据的视图
//   let view = self.data[self.position.buffer_offset:]

//   // 修复点：使用 match 完整处理 Option 返回值
//   match self.parser.recognize_next_token(view, self.is_ending, options) {
//     Some((consumed, result)) => {
//       debug_assert(() => consumed > 0)
//       debug_assert(() => {
//         self.position.buffer_offset + consumed <= self.data.length()
//       })
//       debug("Lexer returned: consumed \{consumed} \{result.unwrap()}")
//       let consumed_view = self.data[self.position.buffer_offset:self.position.buffer_offset +
//         consumed]

//       let (new_line_jumps, new_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(
//         consumed_view,
//       )
//       if new_line_jumps > 0 {
//         self.position.line_start_buffer_offset = self.position.buffer_offset +
//           new_line_start
//       }
//       self.position.buffer_offset += consumed
//       self.position.global_offset += consumed
//       self.position.global_line += new_line_jumps
//       // ✅ 记录 token 结束位置
//       self.current_token_end = self.current_offset()

//       Some(
//         result
//         .map(t => t)
//         .map_err(fn(e) {

//           // 注意：此处原代码逻辑可能有误，e.location 通常需要转换为全局位置或保持原样
//           // 这里保留原代码的占位逻辑，实际应根据 TokenRecognizerError 定义调整
//           match e {
//             TokenRecognizerError::InvalidToken(view, range) =>
//               TokenRecognizerError::InvalidToken(
//                 view,
//                 Range::Range(
//                   self.previous_position.global_offset + range.start,
//                   self.previous_position.global_offset + range.end,
//                 ),
//               )
//             e => {
//               debug("Lexer returned an error: \{e.to_string()}")
//               TokenRecognizerError::Invalid
//             }
//           }
//           // TokenRecognizerError::InvalidToken(Range::new(0,0), "e.message")
//         }),
//       )
//     }
//     None =>
//       // 如果识别器返回 None，通常意味着需要更多数据才能确定下一个 token
//       // 或者当前没有更多 token 可识别
//       None
//   }
// }
