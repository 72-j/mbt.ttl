
///|
pub struct LexerOptions {
  base_iri : Iri[StringView]?
} derive(Default)


///|
pub struct Lexer[TR] {
  parser : TR
  data : Array[Byte]
  position : Position
  mut previous_position : Position
  mut is_ending : Bool
  min_buffer_size : Int
  max_buffer_size : Int
  line_comment_start : Bytes?
}

///|
struct Position {
  mut line_start_buffer_offset : Int
  mut buffer_offset : Int
  mut global_offset : UInt64
  mut global_line : UInt64
}

///|
pub struct TextPosition {
  line : UInt64
  column : UInt64
  offset : UInt64
}derive(Default)

fn TextPosition::TextPosition(
  line : UInt64,
  column : UInt64,
  offset : UInt64,
) -> TextPosition {
  { line, column, offset }
}

impl Show for TextPosition with fn output(self, logger : &Logger) -> Unit {
  logger.write_string("[")
  logger.write_string(self.line.to_string())
  logger.write_string(":")
  logger.write_string(self.column.to_string())
  logger.write_string(":")
  logger.write_string(self.offset.to_string())
  logger.write_string("]")
}


///|
pub fn[TR] Lexer::new(
  parser : TR,
  data : Array[Byte],
  is_ending : Bool,
  min_buffer_size : Int,
  max_buffer_size : Int,
  line_comment_start : Bytes?,
) -> Lexer[TR] {
  {
    parser,
    data,
    position: {
      line_start_buffer_offset: 0,
      buffer_offset: 0,
      global_offset: 0,
      global_line: 0,
    },
    previous_position: {
      line_start_buffer_offset: 0,
      buffer_offset: 0,
      global_offset: 0,
      global_line: 0,
    },
    is_ending,
    min_buffer_size,
    max_buffer_size,
    line_comment_start,
  }
}

///|
pub fn[TR] Lexer::extend_from_slice(self : Lexer[TR], other : Bytes) -> Unit {
  self.shrink_data()
  self.data.append(BytesView::to_array(other))
}

///|
pub fn[TR] Lexer::end(self : Lexer[TR]) -> Unit {
  self.is_ending = true
}

///|
pub async fn[TR] Lexer::extend_from_reader(
  self : Lexer[TR],
  reader : &Reader,
) -> Result[Unit, LexerError] {
  self.shrink_data()

  // 1. 检查容量限制
  if self.data.length() >= self.max_buffer_size {
    return Err(
      LexerError::OutOfMemory(
        "Reached the buffer maximal size of \{self.max_buffer_size}",
      ),
    )
  }

  // 2. 计算本次期望读取的大小
  let remaining_space = self.max_buffer_size - self.data.length()
  let want_read = Int::min(self.min_buffer_size, remaining_space)

  if want_read <= 0 {
    return Ok(())
  }

  let old_len = self.data.length()

  // 3. 预分配空间：将数组长度增加 want_read，新位置初始化为 0
  self.data.resize(old_len + want_read, 0)

  // 4. 获取指向新分配空间的可变视图 (MutArrayView)
  // 这样我们可以直接让 reader 写入这块内存，或者通过视图操作
  // 注意：Moonbit 的 io.Reader 通常接受 FixedArray 或 BytesMut。
  // 假设 reader.read 接受 FixedArray，我们需要先读入 FixedArray，再拷贝。

  let buf : FixedArray[Byte] = FixedArray::make(want_read, 0)

  // 5. 执行读取
  let read = reader.read(buf)

  // 6. 【核心修复】将 buf 中的数据拷贝到 self.data 的末尾
  // 使用 unsafe_blit 或者循环拷贝。这里使用安全的循环拷贝以确保兼容性。
  // 如果性能敏感，且 Moonbit 版本支持 Array::unsafe_blit_fixed，可以使用它。

  let mut i = 0
  while i < read {
    // 将 buf[i] 设置到 self.data[old_len + i]
    self.data.set(old_len + i, buf.at(i))
    i = i + 1
  }

  // 7. 截断多余预分配的空间（如果 read < want_read）
  self.data.truncate(old_len + read)

  // 8. 更新结束标志
  self.is_ending = read == 0

  Ok(())
}


///|
pub async fn[TR] Lexer::extend_from_async_read(
  self : Lexer[TR],
  reader : &Reader,
) -> Result[Unit, LexerError] {
  self.shrink_data()
  if self.data.length() >= self.max_buffer_size {
    return Err(
      LexerError::OutOfMemory(
        "Reached the buffer maximal size of \{self.max_buffer_size}",
      ),
    )
  }

  let remaining_space = self.max_buffer_size - self.data.length()
  let want_read = Int::min(self.min_buffer_size, remaining_space)

  if want_read <= 0 {
    return Ok(())
  }

  let old_len = self.data.length()
  self.data.resize(old_len + want_read, 0)

  let buf : FixedArray[Byte] = FixedArray::make(want_read, 0)
  // 假设 reader.read 是异步方法
  let read = reader.read(buf)

  let mut i = 0
  while i < read {
    self.data.set(old_len + i, buf.at(i))
    i = i + 1
  }

  self.data.truncate(old_len + read)
  self.is_ending = read == 0

  Ok(())
}


///|
pub fn[TR] Lexer::shrink_data(self : Lexer[TR]) -> Unit {
  if self.position.line_start_buffer_offset > 0 {
    self.shrink_data_by(self.position.line_start_buffer_offset)
  }
  if self.position.buffer_offset > self.max_buffer_size / 2 {
    self.shrink_data_by(self.position.buffer_offset)
  }
}

///|
fn[TR] Lexer::shrink_data_by(self : Lexer[TR], shift_amount : Int) -> Unit {
  if shift_amount <= 0 {
    return
  }

  let current_len = self.data.length()
  let new_len = current_len - shift_amount

  // 1. 将 data[shift_amount .. current_len] 的数据拷贝到 data[0 .. new_len]
  // Array::blit_to(src, dst, len, src_offset, dst_offset)
  // 注意：blit_to 是实例方法，调用者是源数组
  ArrayView::blit_to(self.data, self.data, dst_offset=shift_amount)

  // 2. 截断数组，移除末尾多余的数据
  self.data.truncate(new_len)

  // 3. 更新位置信息
  self.position.buffer_offset -= shift_amount
  self.position.line_start_buffer_offset = if self.position.line_start_buffer_offset >=
    shift_amount {
    self.position.line_start_buffer_offset - shift_amount
  } else {
    0
  }
  // 4. 更新 previous_position (保持与当前 position 一致，或者根据逻辑重置)
  // 原代码中直接赋值，这里保持一致
  self.previous_position = self.position
}
// fn[TR] Lexer::shrink_data_by(self : Lexer[R], shift_amount : Int) -> Unit {
//   self.data.copy_within(shift_amount..<, 0)
//   self.data.truncate(self.data.length() - shift_amount)
//   self.position.buffer_offset -= shift_amount
//   self.position.line_start_buffer_offset = self.position.line_start_buffer_offset.saturating_sub(shift_amount)
//   self.previous_position = self.position
// }

///|
pub fn[TR : TokenRecognizer] Lexer::parse_next(
  self : Lexer[TR],
  options : LexerOptions?,
) -> Result[TokenOrLineJump[N3Token], TokenRecognizerError]? {
  if self.skip_whitespaces_and_comments().unwrap() {
    self.previous_position = self.position
    return Some(Ok(TokenOrLineJump::LineJump))
  }
  self.previous_position = self.position

  // 获取当前剩余数据的视图
  let view : BytesView = array_to_view(
    self.data[self.position.buffer_offset:].to_owned(),
  )

  // 修复点：使用 match 完整处理 Option 返回值
  match
    self.parser.recognize_next_token(view.to_owned(), self.is_ending, options) {
    Some((consumed, result)) => {
      // debug_assert(consumed > 0, "The lexer must consume at least one byte each time")
      // debug_assert(self.position.buffer_offset + consumed <= self.data.length(), "The lexer tried to consumed {consumed} bytes but only {} bytes are readable", self.data.length() - self.position.buffer_offset)

      let consumed_view : BytesView = array_to_view(
        self.data[self.position.buffer_offset:self.position.buffer_offset +
        consumed].to_owned(),
      )

      let (new_line_jumps, new_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(
        consumed_view.to_owned(),
      )
      if new_line_jumps > 0 {
        self.position.line_start_buffer_offset = self.position.buffer_offset +
          new_line_start
      }
      self.position.buffer_offset += consumed
      self.position.global_offset += Int::to_uint64(consumed)
      self.position.global_line += new_line_jumps

      Some(
        result
        .map(t => t)
        .map_err(fn(e) {
          // 注意：此处原代码逻辑可能有误，e.location 通常需要转换为全局位置或保持原样
          // 这里保留原代码的占位逻辑，实际应根据 TokenRecognizerError 定义调整
          match e {
            TokenRecognizerError::InvalidToken(view, range) =>
              TokenRecognizerError::InvalidToken(
                view,
                Range::Range(
                  UInt64::to_int(self.previous_position.global_offset) +
                  range.start,
                  UInt64::to_int(self.previous_position.global_offset) +
                  range.end,
                ),
              )
            _ => TokenRecognizerError::Invalid
          }
          // TokenRecognizerError::InvalidToken(Range::new(0,0), "e.message")
        }),
      )
    }
    None =>
      // 如果识别器返回 None，通常意味着需要更多数据才能确定下一个 token
      // 或者当前没有更多 token 可识别
      None
  }
}

///|
pub fn[TR] Lexer::location_from_buffer_offset_range(
  self : Lexer[TR],
  offset_range : Range,
) -> TextRange {
  let start_offset = self.previous_position.buffer_offset + offset_range.start
  let view = array_to_view(
    self.data[self.previous_position.buffer_offset:self.previous_position.buffer_offset +
    start_offset].to_owned(),
  )
  let (start_extra_line_jumps, start_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(
    view,
  )
  let start_line_start = if start_extra_line_jumps > 0 {
    start_line_start + self.previous_position.buffer_offset
  } else {
    self.previous_position.line_start_buffer_offset
  }
  let end_offset = self.previous_position.buffer_offset + offset_range.end
  let view = array_to_view(
    self.data[self.previous_position.buffer_offset:self.previous_position.buffer_offset +
    end_offset].to_owned(),
  )
  let (end_extra_line_jumps, end_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(
    view,
  )
  let end_line_start = if end_extra_line_jumps > 0 {
    end_line_start + self.previous_position.buffer_offset
  } else {
    self.previous_position.line_start_buffer_offset
  }

  TextRange::{
    start: TextPosition::TextPosition(
      self.previous_position.global_line + start_extra_line_jumps,
      Lexer::column_from_bytes(
        array_to_view(self.data[start_line_start:start_offset].to_owned()),
      ),
      self.previous_position.global_offset + Int::to_uint64(offset_range.start),
    ),
    end: TextPosition::TextPosition(
      self.previous_position.global_line + end_extra_line_jumps,
      Lexer::column_from_bytes(
        array_to_view(self.data[end_line_start:end_offset].to_owned()),
      ),
      self.previous_position.global_offset + Int::to_uint64(offset_range.end),
    ),
  }

}

///|
pub fn[TR] Lexer::last_token_location(self : Lexer[TR]) -> TextPosition {
  self.text_position_from_position(self.previous_position)
  //  TextPosition::new(self.text_position_from_position(self.previous_position),
  //  self.text_position_from_position(self.position),
  //  )
}

///|
pub fn[TR] Lexer::current_token_location(self : Lexer[TR]) -> TextPosition {
  self.text_position_from_position(self.previous_position)
  //  TextPosition::new(self.text_position_from_position(self.previous_position),
  //  self.text_position_from_position(self.position),
  //  )
}

///|
fn[TR] Lexer::text_position_from_position(
  self : Lexer[TR],
  position : Position,
) -> TextPosition {
  let view = array_to_view(
    self.data[position.line_start_buffer_offset:position.buffer_offset].to_owned(),
  )
  {
    line: position.global_line,
    column: Lexer::column_from_bytes(view),
    offset: position.global_offset,
  }
}

///|
pub fn[TR] Lexer::last_token_source(self : Lexer[TR]) -> String {
  let arr_view = self.data[self.previous_position.buffer_offset:self.position.buffer_offset]
  let bytes : Bytes = Bytes::from_array(arr_view) // 假设有此 API，或者 Bytes::of_array_view
  @utf8.decode_lossy(bytes)
}

///|
pub fn[TR] Lexer::is_end(self : Lexer[TR]) -> Bool {
  self.is_ending && self.data.length() == self.position.buffer_offset
}


///|
fn[TR] Lexer::skip_whitespaces(self : Lexer[TR]) -> Bool? {
  let data = self.data
  let mut pos = self.position.buffer_offset
  let len = data.length()

  while pos < len {
    match data[pos] {
      b' ' | b'\t' => pos += 1
      b'\n' => {
        // 处理 LF 或 CRLF
        let incr = if pos + 1 < len && data[pos + 1] == b'\r' { 2 } else { 1 }
        self.position.buffer_offset = pos + incr
        self.position.line_start_buffer_offset = self.position.buffer_offset
        self.position.global_offset += incr.to_uint64()
        self.position.global_line += 1
        return Some(true)
      }
      b'\r' => {
        pos += 1
        self.position.buffer_offset = pos
        self.position.line_start_buffer_offset = pos
        self.position.global_offset += 1
        self.position.global_line += 1
        return Some(true)
      }
      _ => {
        self.position.buffer_offset = pos
        return Some(false)
      }
    }
  }

  self.position.buffer_offset = pos
  if self.is_ending {
    Some(false)
  } else {
    None
  }
}

///|
fn[TR] Lexer::skip_whitespaces_and_comments(self : Lexer[TR]) -> Bool? {
  // 首先跳过空白字符
  match self.skip_whitespaces() {
    Some(true) => return Some(true)
    Some(false) => ()
    None => return None
  }

  // 检查是否有行注释
  match self.line_comment_start {
    Some(comment_start) => {
      let buf = array_to_view(
        self.data[self.position.buffer_offset:].to_owned(),
      )

      // 检查是否以注释开始
      if !buf.has_prefix(comment_start) {
        // 不是注释，但可能是不完整的注释开始
        if !self.is_ending && buf.length() < comment_start.length() {
          return None
        }
        return Some(false)
      }

      // 查找注释结束位置（换行符）
      let start_len = comment_start.length()
      let end_pos = Lexer::find_line_end(buf, start_len)

      match end_pos {
        Some(end) => {
          let comment_size = end + 1
          self.position.buffer_offset += comment_size
          self.position.line_start_buffer_offset = self.position.buffer_offset
          self.position.global_offset += comment_size.to_uint64()
          self.position.global_line += 1
          Some(true)
        }
        None =>
          if self.is_ending {
            self.position.buffer_offset = self.data.length()
            Some(false)
          } else {
            None
          }
      }
    }
    None => return Some(false)
  }
}

///|
fn Lexer::find_line_end(buf : Bytes, start : Int) -> Int? {
  let mut i = start
  let len = buf.length()

  while i < len {
    match buf[i] {
      b'\n' => return Some(i)
      b'\r' => {
        // 检查是否是 CRLF
        if i + 1 < len && buf[i + 1] == b'\n' {
          return Some(i + 1)
        }
        return Some(i)
      }
      _ => i += 1
    }
  }

  None
}


///|
fn Lexer::find_number_of_line_jumps_and_start_of_last_line(
  bytes : Bytes,
) -> (UInt64, Int) {
  let mut jumps : UInt64 = 0
  let mut last_start : Int = 0
  let mut i : Int = 0

  while i < bytes.length() {
    match bytes[i] {
      b'\n' => {
        jumps += 1
        last_start = i + 1
        i += 1
      }
      b'\r' => {
        jumps += 1
        if i + 1 < bytes.length() && bytes[i + 1] == b'\n' {
          last_start = i + 2
          i += 2
        } else {
          last_start = i + 1
          i += 1
        }
      }
      _ => i += 1
    }
  }

  (jumps, last_start)
}


///|
fn Lexer::column_from_bytes(bytes : Bytes) -> UInt64 {
  let mut count : UInt64 = 0
  let mut i : Int = 0
  let len = bytes.length()

  while i < len {
    let b = bytes[i]
    if (b & 0x80) == 0 {
      // ASCII: 1 字节
      i += 1
    } else if (b & 0xE0) == 0xC0 {
      // 2 字节 UTF-8
      i += 2
    } else if (b & 0xF0) == 0xE0 {
      // 3 字节 UTF-8
      i += 3
    } else {
      // 4 字节 UTF-8
      i += 4
    }
    count += 1
  }

  count
}
