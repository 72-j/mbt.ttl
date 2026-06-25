pub fn[RL : TokenRecognizer] Lexer::parse_next(
  self : Lexer[RL],
  options : LexerOptions?,
) -> Result[LocatedTokenOrLineJump, TokenRecognizerError]? {
  if self.is_ending && self.position.buffer_offset >= self.data.length() {
    return None
  }

  // 1. 跳过空白和注释
  match self.skip_whitespaces_and_comments() {
    Some(true) => {
      self.previous_position = self.position
      return Some(Ok(LocatedTokenOrLineJump::LineJump(self.position.global_line))) 
    }
    Some(false) => ()
    None => return None
  }

  // 2. 记录 Token 起始状态
  self.previous_position = self.position
  // token_start_pos 包含了起始的全局偏移量、行号等信息
  let token_start_pos = self.position_from_position(self.previous_position)

  // 获取当前剩余数据的视图
  let view = self.data[self.position.buffer_offset:]

  // 【修正点】构造包含真实起始位置的上下文
  // 假设 SourcePosition 可以从 PositionInfo (token_start_pos 的类型) 转换或直接构建
  // 如果 SourcePosition 定义包含 offset, line, column 等，请在此处填入 token_start_pos 的对应字段
  let location_ctx = SourcePosition ::SourcePosition(
    token_start_pos.offset,
     token_start_pos.line,     // 假设 PositionInfo 有 line 字段
     token_start_pos.column, // 假设 PositionInfo 有 column 字段
    // 其他必要字段...
  )

  // 3. 调用识别器，传入真实的 location_ctx
  match self.parser.recognize_next_token(view, self.is_ending, options, location_ctx) {
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
        .map(fn(t) {
          match t.into_token() {
            Some(t) => LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(
              t,
              Range::Range(token_start_pos.offset, token_end_pos.offset)
            ))
            None => LocatedTokenOrLineJump::LineJump(self.position.global_line)
          }
        })
        .map_err(fn(e) {
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