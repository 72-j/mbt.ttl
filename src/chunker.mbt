///|
const CHUNK_SIZE : Int = 64 * 1024

///|
pub fn get_ntriples_slice_chunks(
  bytes : BytesView,
  n_chunks : Int,
) -> Array[(Int, Int)] {
  if n_chunks <= 0 {
    return [(0, bytes.length())]
  }

  let total_len = bytes.length()
  if total_len == 0 {
    return []
  }

  // 收集所有换行符的位置（换行符之后的位置）
  let line_ends = []
  let mut pos = 0
  while memchr(b'\n', bytes[pos:]) is Some(p) {
    pos += p + 1
    line_ends.push(pos)
  }

  // 如果没有换行符，整个文件作为一个块
  if line_ends.length() == 0 {
    return [(0, total_len)]
  }

  // 按换行符位置分割成 N 块
  let total_lines = line_ends.length()
  let lines_per_chunk = (total_lines / n_chunks).max(1)
  let mut last_pos = 0
  let offsets = []

  for i in 0..<n_chunks {
    // 计算当前块的结束行索引
    let end_line_idx = ((i + 1) * lines_per_chunk).min(total_lines) - 1
    let end_pos = line_ends[end_line_idx]

    offsets.push((last_pos, end_pos))
    last_pos = end_pos

    if last_pos >= total_len {
      break
    }
  }

  // 如果还有剩余内容（通常是最后一行的换行符导致），添加到最后一个块
  if last_pos < total_len {
    // 合并到最后一个块
    match offsets.pop() {
      Some((start, _)) => offsets.push((start, total_len))
      None => offsets.push((0, total_len)) // 理论上不会发生，但处理了 None 情况
    }
  }

  offsets
}

///|
/// 在指定范围内搜索换行符，返回换行符的绝对位置
fn find_newline_in_range(bytes : BytesView, start : Int, end : Int) -> Int? {
  for i in start..<end {
    if bytes[i] == b'\n' {
      return Some(i)
    }
  }
  None
}

///|

///|
pub async fn get_ntriples_file_chunks(
  file : File,
  file_size : Int64,
  n_chunks : Int,
) -> Result[Array[(Int64, Int64)], String] {
  let mut last_pos : Int64 = 0
  let chunk_size = file_size / n_chunks.to_int64()

  let offsets = Array::new(capacity=n_chunks)

  // 用于读取的缓冲区
  let buffer : FixedArray[Byte] = FixedArray::make(CHUNK_SIZE, 0)

  for _ in 0..<n_chunks {
    let search_pos = last_pos + chunk_size
    if search_pos >= file_size {
      break
    }

    let mut end_pos_opt : Int64? = None
    let mut current_read_pos : Int64 = search_pos

    // 从 search_pos 开始向后扫描，寻找换行符
    while current_read_pos < file_size {
      // 计算本次读取的长度，不超过缓冲区大小，也不超过文件末尾
      let remaining = file_size - current_read_pos
      let read_len = if remaining > 4096 { 4096 } else { remaining.to_int() }

      // 使用 read_at 从 current_read_pos 读取数据
      // 注意：read_at 返回实际读取的字节数
      let bytes_read = file.read_at(
        buffer,
        position=current_read_pos,
        len=read_len,
      )

      if bytes_read == 0 {
        break
      }

      // 在 buffer 的前 bytes_read 个字节中查找 '\n'
      let view = buffer[0:bytes_read]
      match array_view_memchr(b'\n', view) {
        Some(pos_in_buffer) => {
          // 找到换行符
          end_pos_opt = Some(current_read_pos + pos_in_buffer.to_int64() + 1)
          break
        }
        None =>
          // 未找到，移动读取位置到下一块
          current_read_pos += bytes_read.to_int64()
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
// pub fn get_turtle_slice_chunks(
//   bytes : BytesView,
//   n_chunks : Int,
//   parser : TurtleParser,
// ) -> Array[(Int, Int)] {
//   // 边界检查
//   if n_chunks <= 0 {
//     return [(0, bytes.length())]
//   }

//   let total_len = bytes.length()
//   if total_len == 0 {
//     return []
//   }

//   // 最小块大小至少为 1
//   let chunk_size = (total_len / n_chunks).max(1)

//   let mut last_pos = 0
//   let offsets = Array::new(capacity=n_chunks)

//   for _ in 0..<n_chunks {
//     let search_pos = last_pos + chunk_size
//     if search_pos >= total_len {
//       break
//     }

//     // 从 search_pos 开始搜索到末尾
//     let remaining = bytes[search_pos:total_len]
//     match next_terminating_char(parser, remaining) {
//       Some(pos) => {
//         // pos 是相对于 search_pos 的偏移
//         let end_pos = search_pos + pos
//         offsets.push((last_pos, end_pos))
//         last_pos = end_pos
//       }
//       None => {
//         // 找不到终止符：将剩余所有内容作为最后一块
//         offsets.push((last_pos, total_len))
//         last_pos = total_len
//         break
//       }
//     }
//   }

//   // 添加最后一块
//   if last_pos < total_len {
//     offsets.push((last_pos, total_len))
//   }

//   offsets
// }
pub fn get_turtle_slice_chunks(
  bytes : BytesView,
  n_chunks : Int,
) -> Array[(Int, Int)] {
  // 按换行符分割，简单高效
  get_ntriples_slice_chunks(bytes, n_chunks)
}

///|
fn next_terminating_char(parser : TurtleParser, input : BytesView) -> Int? {
  let mut input = input
  let mut total_pos = 0

  for _ in 0..<1_000 {
    // 安全地查找 '.'
    match memchr(b'.', input) {
      Some(dot_index) => {
        let pos = dot_index + 1
        if pos >= input.length() {
          return None
        }
        let new_input = input[pos:]
        let p = parser
        let accepted = accept(p, new_input)
        if accepted {
          return Some(total_pos + pos)
        }
        // 如果未接受，跳过这个 '.' 继续寻找下一个
        input = input[pos:] // 注意：这里应该是 pos 还是 pos+1 取决于逻辑，原代码是 pos+1
        total_pos += pos
      }
      None =>
        // 如果没有找到 '.'，则无法在此处分割
        return None
    }
  }
  None
}

///|
fn accept(parser : TurtleParser, input : BytesView) -> Bool {
  let f = parser.for_slice(input)
  let iter_opt = f.inner.next()
  for _ in 0..<3 {
    if iter_opt is Some(_r) {
      // ... 只检查第一个结果
      break
    } else {
      return false
    }
  }
  true
}
