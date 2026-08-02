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
  let start_pos = SourcePos::default()
  self.current_token_start = start_offset // ★ 添加这行
  match
    self.parser.recognize_next_token(view, self.is_ending, options, start_pos) {
    Some((consumed, result)) => {
      let actual_consumed = if consumed <= 0 { 1 } else { consumed }

      self.position.buffer_offset += actual_consumed
      self.position.global_offset += actual_consumed
      self.current_token_start = start_offset
      self.current_token_end = start_offset + consumed
      let range = Range::Range(start_offset, start_offset + consumed)

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
          // debug("parse_next: token: \{token.into_token()}")
          Some(Ok(LocatedToken(token.into_token(), range)))
        }
        Err(e) => {
          let bytes = self.range_to_bytes(range)
          return Some(
            Err(TokenRecognizerError::InvalidToken(e.message(), bytes, range)),
          )
        }
      }
    }
    None => None
  }
}
