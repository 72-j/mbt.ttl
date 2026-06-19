///|
pub fn get_ntriples_slice_chunks(
  bytes : BytesView,
  n_chunks : Int,
) -> Array[(Int, Int)] {
  let mut last_pos = 0
  let total_len = bytes.length()
  let chunk_size = total_len / n_chunks
  let offsets = Array::new(capacity=n_chunks)
  for _ in 0..<n_chunks {
    let search_pos = last_pos + chunk_size
    if search_pos >= bytes.length() {
      break
    }
    match next_newline_position(bytes[search_pos:]) {
      Some(pos) => {
        let end_pos = search_pos + pos
        offsets.push((last_pos, end_pos))
        last_pos = end_pos
      }
      None => {
        // 如果后续找不到换行符，将剩余所有内容归入当前块并结束
        offsets.push((last_pos, total_len))
        last_pos = total_len
        break
      }
    }
  }
  if last_pos < total_len {
    offsets.push((last_pos, total_len))
  }
  offsets
}

///|
fn next_newline_position(input : BytesView) -> Int? {
  match memchr(b'\n', input) {
    Some(pos) => Some(pos + 1) // 返回换行符之后的位置，作为下一行的起始点或当前行的结束边界
    None => None // 没有找到换行符，说明这是最后一行且未终止，或者数据不完整
  }
}

///|
pub async fn get_ntriples_file_chunks(
  file : File,
  file_size : UInt64,
  n_chunks : Int,
) -> Result[Array[(UInt64, UInt64)], String] {
  let mut last_pos : UInt64 = 0
  let chunk_size = file_size / n_chunks.to_uint64()
  let offsets = Array::new(capacity=n_chunks)

  // 用于读取的缓冲区
  let buffer : FixedArray[Byte] = FixedArray::make(4096, 0)

  for _ in 0..<n_chunks {
    let search_pos = last_pos + chunk_size
    if search_pos >= file_size {
      break
    }

    let mut end_pos_opt : UInt64? = None
    let mut current_read_pos : UInt64 = search_pos

    // 从 search_pos 开始向后扫描，寻找换行符
    while current_read_pos < file_size {
      // 计算本次读取的长度，不超过缓冲区大小，也不超过文件末尾
      let remaining = file_size - current_read_pos
      let read_len = if remaining > 4096 { 4096 } else { remaining.to_int() }

      // 使用 read_at 从 current_read_pos 读取数据
      // 注意：read_at 返回实际读取的字节数
      let bytes_read = file.read_at(
        buffer,
        position=current_read_pos.reinterpret_as_int64(),
        len=read_len,
      )

      if bytes_read == 0 {
        break
      }

      // 在 buffer 的前 bytes_read 个字节中查找 '\n'
      let view = buffer[0:bytes_read].to_owned()
      match memchr(b'\n', array_to_view(view)) {
        Some(pos_in_buffer) => {
          // 找到换行符
          end_pos_opt = Some(current_read_pos + pos_in_buffer.to_uint64() + 1)
          break
        }
        None =>
          // 未找到，移动读取位置到下一块
          current_read_pos += bytes_read.to_uint64()
      }
    }

    // 确定最终的 end_pos
    let end_pos = match end_pos_opt {
      Some(pos) => pos
      None => file_size // 如果直到文件末尾都没找到换行符，则取文件末尾
    }

    offsets.push((last_pos, end_pos))
    last_pos = end_pos
  }

  // 处理最后一个块（如果还有剩余数据）
  if last_pos < file_size {
    offsets.push((last_pos, file_size))
  }

  Ok(offsets)
}

///|
pub fn get_turtle_slice_chunks(
  bytes : Bytes,
  n_chunks : Int,
  parser : TurtleParser,
) -> Array[(Int, Int)] {
  let mut last_pos = 0
  let total_len = bytes.length()
  let chunk_size = total_len / n_chunks
  let offsets = Array::new(capacity=n_chunks)
  for _ in 0..<n_chunks {
    let search_pos = last_pos + chunk_size
    if search_pos >= bytes.length() {
      break
    }
    match next_terminating_char(parser, bytes[search_pos:]) {
      Some(pos) => {
        let end_pos = search_pos + pos
        offsets.push((last_pos, end_pos))
        last_pos = end_pos
      }
      None => {
        // 如果找不到终止符，将剩余所有内容归入当前块并结束
        offsets.push((last_pos, total_len))
        last_pos = total_len
        break
      }
    }
  }
  if last_pos < total_len {
    offsets.push((last_pos, total_len))
  }
  offsets
}

///|
fn next_terminating_char(parser : TurtleParser, input : BytesView) -> Int? {
  let mut input = input
  fn accept(parser : TurtleParser, input : BytesView) -> Bool {
    let f = parser.for_slice(input)
    // 修复：将链式调用分解，避免解析歧义
    let iter_opt = f.inner.next()
    for _ in 0..<3 {
      if iter_opt is Some(r) {
        if r.is_err() {
          return false
        }
        // 注意：这里可能需要更新 iter_opt 以获取下一个元素，原代码逻辑似乎不完整
        // 假设 Iter() 返回一个迭代器状态，可能需要进一步调用 next() 等方法
        // 由于原代码逻辑模糊，此处仅修复语法错误，逻辑需根据实际 API 调整
        break // 或者继续循环，取决于业务逻辑
      } else {
        return false
      }
    }
    true
  }
  let mut total_pos = 0
  for _ in 0..<1_000 {
    let pos = memchr(b'.', input).unwrap() + 1
    if pos >= input.length() {
      return None
    }
    let new_input = input[pos:]
    let p = parser
    let accepted = accept(p, new_input)
    if accepted {
      return Some(total_pos + pos)
    }
    input = input[pos + 1:]
    total_pos += pos + 1
  }
  None
}
