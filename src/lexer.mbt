///|
// pub enum LexerOptions {
//   N3LexerOptions(N3LexerOptions)
//   TriGLexerOptions(TriGLexerOptions)
//   //  mut base_iri : Iri?
// } derive(Debug)
// struct LexerOptions(N3LexerOptions)

///|
pub struct LexerOptions {
  mut base_iri : Iri?
} derive(Debug)

///|
fn LexerOptions::default(base_iri : Iri?) -> LexerOptions {
  { base_iri, }
}

///|
pub struct Lexer[RL] {
  parser : RL
  data : Array[Byte]
  position : Position
  mut previous_position : Position
  mut is_ending : Bool
  min_buffer_size : Int
  max_buffer_size : Int
  line_comment_start : Bytes?
  mut current_token_start : Int
  mut current_token_end : Int
}

///|
struct Position {
  mut line_start_buffer_offset : Int
  mut buffer_offset : Int
  mut global_offset : Int
  mut global_line : Int
} derive(Debug, Default)

///|
pub struct SourcePosition {
  line : Int
  column : Int
  offset : Int
} derive(Debug)

///|
fn SourcePosition::default() -> SourcePosition {
  SourcePosition(0, 0, 0)
}

///|
fn SourcePosition::SourcePosition(
  line : Int,
  column : Int,
  offset : Int,
) -> SourcePosition {
  { line, column, offset }
}

///|
pub fn SourcePosition::end_position(
  self : Self,
  consumed_bytes : Int,
) -> SourcePosition {
  // 注意：这里简化处理，假设消耗的都是单字节 ASCII 或者你希望在字节层面计算 offset
  // 如果需要精确的 UTF-8 列号计算，需要扫描 data[start..start+consumed]
  SourcePosition::SourcePosition(
    self.line,
    self.column + consumed_bytes, // 简化列计算，实际可能需要 utf8 解析
    self.offset + consumed_bytes,
  )
}

///|
pub fn SourcePosition::start_position(self : Self) -> SourcePosition {
  SourcePosition::SourcePosition(self.line, self.column, self.offset)
}

///|
impl Show for SourcePosition with fn output(self, logger : &Logger) -> Unit {
  logger.write_string("[")
  logger.write_string(self.line.to_string())
  logger.write_string(":")
  logger.write_string(self.column.to_string())
  logger.write_string(":")
  logger.write_string(self.offset.to_string())
  logger.write_string("]")
}

///|
pub fn[RL] Lexer::Lexer(
  parser : RL,
  data : Array[Byte],
  is_ending : Bool,
  min_buffer_size : Int,
  max_buffer_size : Int,
  line_comment_start : Bytes?,
  current_token_start : Int,
  current_token_end : Int,
) -> Lexer[RL] {
  {
    parser,
    data,
    position: Position::default(),
    previous_position: Position::default(),
    is_ending,
    min_buffer_size,
    max_buffer_size,
    line_comment_start,
    current_token_start,
    current_token_end,
  }
}

///|
pub fn[RL] Lexer::extend_from_slice(self : Lexer[RL], other : Bytes) -> Unit {
  self.shrink_data()
  self.data.append(BytesView::to_array(other))
}

///|
pub fn[RL] Lexer::end(self : Lexer[RL]) -> Unit {
  self.is_ending = true
}

///|
pub async fn[RL] Lexer::extend_from_reader(
  self : Lexer[RL],
  reader : &Reader,
) -> Result[Int, LexerError] {
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
    return Ok(0)
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

  Ok(read)
}

///|
pub async fn[RL] Lexer::extend_from_async_read(
  self : Lexer[RL],
  reader : &Reader,
) -> Result[Int, LexerError] {
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
    return Ok(0)
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

  Ok(read)
}

///|
// pub fn[RL] Lexer::shrink_data(self : Lexer[RL]) -> Unit {
//   if self.position.line_start_buffer_offset > 0 {
//     self.shrink_data_by(self.position.line_start_buffer_offset)
//   }
//   if self.position.buffer_offset > self.max_buffer_size / 2 {
//     self.shrink_data_by(self.position.buffer_offset)
//   }
// }

///|
pub fn[RL] Lexer::shrink_data(self : Lexer[RL]) -> Unit {
  // 策略1: 如果行起始偏移量大于0，说明前面有完整的行可以丢弃
  if self.position.line_start_buffer_offset > 0 {
    self.shrink_data_by(self.position.line_start_buffer_offset)
    // 策略2: 如果缓冲区使用超过一半，尝试收缩已处理的部分
    // 注意：这里通常收缩到 current_token_start 或者 position.buffer_offset
    // 原代码使用 position.buffer_offset，意味着丢弃所有已消耗的字符
  } else if self.position.buffer_offset > self.max_buffer_size / 2 {
    self.shrink_data_by(self.position.buffer_offset)
  }
}

///|
fn[RL] Lexer::shrink_data_by(self : Lexer[RL], shift_amount : Int) -> Unit {
  if shift_amount <= 0 {
    return
  }

  let current_len = self.data.length()

  // 安全检查：确保不移动超出数组范围的数据
  if shift_amount > current_len {
    // 理论上不应发生，除非逻辑有误
    return
  }

  let new_len = current_len - shift_amount

  // 1. 数据移动：将 [shift_amount .. current_len) 移动到 [0 .. new_len)
  // Moonbit ArrayView::blit_to(src, dst, src_offset, dst_offset, len) 
  // 注意：不同版本 API 可能略有不同，假设 blit_to 签名如下：
  // src.blit_to(dst, src_offset, dst_offset, length)
  // 或者静态方法 ArrayView::blit_to(src, dst, src_offset, dst_offset, length)

  // 假设使用实例方法或标准库推荐方式：
  // 将 self.data 从 shift_amount 开始的内容，拷贝到 self.data 从 0 开始的位置
  // self.data.blit_to(

  //   src_offset=shift_amount, 
  //   dst_offset=0, 
  //   len=new_len,
  //   self.data
  // )
  let _ = ArrayView::blit_to(self.data, self.data, dst_offset=shift_amount)
  // 2. 截断数组
  self.data.truncate(new_len)

  // 3. 更新相对偏移量 (Buffer Offsets)
  // 这些是数组索引，必须减去移走的字节数
  self.position.buffer_offset -= shift_amount
  self.position.line_start_buffer_offset -= shift_amount

  // 确保 line_start_buffer_offset 不为负（虽然逻辑上 shift_amount <= line_start_buffer_offset 时才调用，或者针对 buffer_offset）
  if self.position.line_start_buffer_offset < 0 {
    self.position.line_start_buffer_offset = 0
  }
  if self.position.buffer_offset < 0 {
    self.position.buffer_offset = 0
  }

  // 4. 【关键】绝对偏移量 (Global Offsets) 保持不变
  // self.position.global_offset 不变
  // self.position.global_line 不变

  // 5. 更新 previous_position
  // 如果 previous_position 用于指向“上一个处理完的位置”，它应该跟随当前的 position 状态
  // 因为 position 已经更新为收缩后的新索引，previous_position 也应反映这一变化
  // 注意：previous_position 中的 global_offset 和 global_line 也应保持不变（因为它们来自 position 的副本或独立维护）
  // 如果 previous_position 是 Position 结构体，它也包含 buffer_offset 等相对字段，必须同样调整

  self.previous_position.buffer_offset -= shift_amount
  self.previous_position.line_start_buffer_offset -= shift_amount

  if self.previous_position.line_start_buffer_offset < 0 {
    self.previous_position.line_start_buffer_offset = 0
  }
  if self.previous_position.buffer_offset < 0 {
    self.previous_position.buffer_offset = 0
  }

  // previous_position 的 global_offset 和 global_line 也不需要变，因为它们代表历史绝对位置
}

///|
// fn[RL] Lexer::shrink_data_by(self : Lexer[RL], shift_amount : Int) -> Unit {
//   if shift_amount <= 0 {
//     return
//   }

//   let current_len = self.data.length()
//   let new_len = current_len - shift_amount

//   // 1. 将 data[shift_amount .. current_len] 的数据拷贝到 data[0 .. new_len]
//   // Array::blit_to(src, dst, len, src_offset, dst_offset)
//   // 注意：blit_to 是实例方法，调用者是源数组
//   ArrayView::blit_to(self.data, self.data, dst_offset=shift_amount)

//   // 2. 截断数组，移除末尾多余的数据
//   self.data.truncate(new_len)

//   // 3. 更新位置信息
//   self.position.buffer_offset -= shift_amount
//   self.position.line_start_buffer_offset = if self.position.line_start_buffer_offset >=
//     shift_amount {
//     self.position.line_start_buffer_offset - shift_amount
//   } else {
//     0
//   }
//   // 4. 更新 previous_position (保持与当前 position 一致，或者根据逻辑重置)
//   // 原代码中直接赋值，这里保持一致
//   self.previous_position = self.position
// }
// fn[RL] Lexer::shrink_data_by(self : Lexer[R], shift_amount : Int) -> Unit {
//   self.data.copy_within(shift_amount..<, 0)
//   self.data.truncate(self.data.length() - shift_amount)
//   self.position.buffer_offset -= shift_amount
//   self.position.line_start_buffer_offset = self.position.line_start_buffer_offset.saturating_sub(shift_amount)
//   self.previous_position = self.position
// }

///|
pub fn[RL] Lexer::location_from_buffer_offset_range(
  self : Lexer[RL],
  offset_range : Range,
) -> SourceRange {
  let start_offset = self.previous_position.buffer_offset + offset_range.start
  let view = self.data[self.previous_position.buffer_offset:self.previous_position.buffer_offset +
    start_offset]
  let (start_extra_line_jumps, start_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(
    view,
  )
  let start_line_start = if start_extra_line_jumps > 0 {
    start_line_start + self.previous_position.buffer_offset
  } else {
    self.previous_position.line_start_buffer_offset
  }
  let end_offset = self.previous_position.buffer_offset + offset_range.end
  let view = self.data[self.previous_position.buffer_offset:self.previous_position.buffer_offset +
    end_offset]

  let (end_extra_line_jumps, end_line_start) = Lexer::find_number_of_line_jumps_and_start_of_last_line(
    view,
  )
  let end_line_start = if end_extra_line_jumps > 0 {
    end_line_start + self.previous_position.buffer_offset
  } else {
    self.previous_position.line_start_buffer_offset
  }

  SourceRange::SourceRange(
    SourcePosition::SourcePosition(
      self.previous_position.global_line + start_extra_line_jumps,
      Lexer::column_from_bytes(self.data[start_line_start:start_offset]),
      self.previous_position.global_offset + offset_range.start,
    ),
    SourcePosition::SourcePosition(
      self.previous_position.global_line + end_extra_line_jumps,
      Lexer::column_from_bytes(self.data[end_line_start:end_offset]),
      self.previous_position.global_offset + offset_range.end,
    ),
  )
}

///|
pub fn[RL] Lexer::current_token_start_location(
  self : Lexer[RL],
) -> SourcePosition {
  self.position_from_position(self.previous_position)
  //  SourcePosition::new(self.position_from_position(self.previous_position),
  //  self.position_from_position(self.position),
  //  )
}

///|
/// 获取当前 Token 的**结束**位置 (即 Lexer 指针当前位置)
pub fn[RL] Lexer::current_token_end_location(
  self : Lexer[RL],
) -> SourcePosition {
  self.position_from_position(self.position)
}

///|
/// 获取当前 Token 的完整范围
pub fn[RL] Lexer::current_token_source_range(self : Lexer[RL]) -> SourceRange {
  SourceRange::SourceRange(
    self.current_token_start_location(),
    self.current_token_end_location(),
  )
}

///|
fn[RL] Lexer::position_from_position(
  self : Lexer[RL],
  position : Position,
) -> SourcePosition {
  let view = self.data[position.line_start_buffer_offset:position.buffer_offset]

  {
    line: position.global_line,
    column: Lexer::column_from_bytes(view),
    offset: position.global_offset,
  }
}

///|
pub fn[RL] Lexer::last_token_source(self : Lexer[RL]) -> String {
  let arr_view = self.data[self.previous_position.buffer_offset:self.position.buffer_offset]
  let bytes : Bytes = Bytes::from_array(arr_view) // 假设有此 API，或者 Bytes::of_array_view
  @utf8.decode_lossy(bytes)
}

///|
pub fn[RL] Lexer::is_end(self : Lexer[RL]) -> Bool {
  self.is_ending && self.data.length() == self.position.buffer_offset
}

///|
fn[RL] Lexer::skip_whitespaces(self : Lexer[RL]) -> Bool? {
  let data = self.data
  let mut pos = self.position.buffer_offset
  let len = data.length()

  while pos < len {
    match data[pos] {
      b' ' | b'\t' => pos += 1
      b'\r' => {
        // 处理 CR 或 CRLF
        let mut incr = 1
        if pos + 1 < len {
          if data[pos + 1] == b'\n' {
            incr = 2
          }
        } else if !self.is_ending {
          // 如果后面可能还有数据，需要等待
          return None
        }

        self.position.buffer_offset = pos + incr
        self.position.line_start_buffer_offset = self.position.buffer_offset
        self.position.global_offset += incr
        self.position.global_line += 1
        return Some(true)
      }
      b'\n' => {
        // 处理 LF
        self.position.buffer_offset = pos + 1
        self.position.line_start_buffer_offset = self.position.buffer_offset
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
fn[RL] Lexer::skip_whitespaces_and_comments(self : Lexer[RL]) -> Bool? {
  // 首先跳过空白字符
  match self.skip_whitespaces() {
    Some(true) => return Some(true)
    Some(false) => ()
    None => return None
  }

  // 检查是否有行注释
  match self.line_comment_start {
    Some(comment_start) => {
      let buf = self.data[self.position.buffer_offset:]

      // 检查是否以注释开始
      if !array_view_has_prefix(buf, comment_start) {
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
          self.position.global_offset += comment_size
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
fn Lexer::find_line_end(buf : ArrayView[Byte], start : Int) -> Int? {
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
  bytes : ArrayView[Byte],
) -> (Int, Int) {
  let mut jumps : Int = 0
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
fn Lexer::column_from_bytes(bytes : ArrayView[Byte]) -> Int {
  let mut count : Int = 0
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

///|
fn[T] Lexer::current_offset(self : Lexer[T]) -> Int {
  self.position.buffer_offset + self.position.line_start_buffer_offset
}

///|
/// 获取当前行号
fn[T] Lexer::current_line(self : Lexer[T]) -> Int {
  self.position.global_line
}

///|
/// 获取当前列号
fn[T] Lexer::current_column(self : Lexer[T]) -> Int {
  let offset = self.current_offset()
  let line_start = self.position.line_start_buffer_offset
  offset - line_start + 1
}

///|
/// 获取当前位置（完整信息）
fn[T] Lexer::current_position(self : Lexer[T]) -> SourcePosition {
  SourcePosition::SourcePosition(
    self.position.global_line,
    self.current_column(),
    self.current_offset(),
  )
}

///|
/// 获取 token 范围
fn[T] Lexer::current_token_range(self : Lexer[T]) -> Range {
  Range::Range(self.current_token_start, self.current_token_end)
}

///|
/// 记录 token 起始
fn[T] Lexer::record_token_start(self : Lexer[T]) -> Unit {
  // 使用 global_offset 确保位置在数据收缩后依然有效
  self.current_token_start = self.position.global_offset
}

///|
/// 记录 token 结束
fn[T] Lexer::record_token_end(self : Lexer[T]) -> Unit {
  // 使用 global_offset 确保位置在数据收缩后依然有效
  self.current_token_end = self.position.global_offset
}

///|
// fn[RL] Lexer::position_at_offset(
//   self : Lexer[RL],
//   offset : Int,
// ) -> SourcePosition {
//   // 需要从 buffer 中计算行号
//   // 这需要 line_starts 或扫描 buffer
//   // 简化版本：使用当前位置估算
//   // 更准确的方法：维护 line_starts 数组
//   SourcePosition::SourcePosition(
//     self.position.global_line,
//     offset - self.position.line_start_buffer_offset + 1,
//     offset,
//   )
// }

///|
/// 获取上一个 token 的起始位置（解析完成后）
pub fn[RL] Lexer::last_token_start(self : Lexer[RL]) -> SourcePosition {
  self.position_from_position(self.previous_position)
}

///|
/// 获取上一个 token 的结束位置
pub fn[RL] Lexer::last_token_end(self : Lexer[RL]) -> SourcePosition {
  self.position_from_position(self.position)
}

///|
pub fn[RL] Lexer::last_token_range(self : Lexer[RL]) -> SourceRange {
  SourceRange(self.last_token_start(), self.last_token_end())
}
/// 获取当前 token 的起始位置（解析进行中）
// pub fn[RL] Lexer::current_token_start_pos(self : Lexer[RL]) -> SourcePosition {
//   self.position_at_offset(self.current_token_start)
// }
// fn[T] Lexer::add_global_offset(self: Lexer[T], delta: Int) -> Unit {
//   let new_offset = self.position.global_offset + delta
//   // 仅在调试模式下检查（生产环境无性能损失）
//   debug_assert(new_offset >= 0, "Offset underflow")
//   debug_assert(new_offset < 9_223_372_036_854_775_807, "Offset overflow")
//   self.position.global_offset = new_offset
// }

// fn[T] Lexer::add_global_line(self: Lexer[T], delta: Int) -> Unit {
//   let new_line = self.position.global_line + delta
//   debug_assert(new_line >= 0, "Line underflow")
//   debug_assert(new_line < 9_223_372_036_854_775_807, "Line overflow")
//   self.position.global_line = new_line
// }
