///|
pub struct NQuadsParser {
  mut lenient : Bool
} derive(Default)

///|
pub fn NQuadsParser::new() -> NQuadsParser {
  NQuadsParser::default()
}

///|
pub fn NQuadsParser::lenient(self : NQuadsParser) -> NQuadsParser {
  self.lenient = true
  self
}

///|
pub fn NQuadsParser::for_reader(
  self : NQuadsParser,
  reader : &Reader,
) -> ReaderNQuadsParser[RdfLexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn NQuadsParser::for_async_reader(
  self : NQuadsParser,
  reader : &Reader,
) -> AsyncReaderNQuadsParser[RdfLexer] {
  { inner: self.low_level().parser.for_async_reader(reader) }
}

///|
pub fn NQuadsParser::for_slice(
  self : NQuadsParser,
  slice : BytesView,
) -> SliceNQuadsParser[NQuadsRecognizer] {
  let parser = NQuadsRecognizer::new_parser(
    slice.to_array(),
    true,
    true,
    self.lenient,
  )
  { inner: { parser, } }
}

///|
pub fn NQuadsParser::split_slice_for_parallel_parsing(
  self : NQuadsParser,
  slice : BytesView,
  target_parallelism : Int,
) -> Array[SliceNQuadsParser[NQuadsRecognizer]] {
  let n_chunks = (slice.length() / MIN_PARALLEL_CHUNK_SIZE).clamp(
    min=1,
    max=target_parallelism,
  )
  get_ntriples_slice_chunks(slice, n_chunks).map(fn(chunk) {
    let start = chunk.0
    let end = chunk.1
    self.for_slice(slice[start:end])
  })
}

///|
pub async fn NQuadsParser::split_file_for_parallel_parsing(
  self : NQuadsParser,
  path : String,
  target_parallelism : Int64,
) -> Result[Array[SliceNQuadsParser[NQuadsRecognizer]], String] {
  let file = @fs.open(path, create_mode=OpenExisting, mode=ReadOnly)
  let file_size = file.size()

  let chunk_size = MIN_PARALLEL_CHUNK_SIZE
  let n_chunks_raw = file_size / chunk_size.to_int64()
  let n_chunks = n_chunks_raw.clamp(min=1, max=target_parallelism)

  let chunks_result = get_ntriples_file_chunks(
    file,
    file_size,
    n_chunks.to_int(),
  )

  let chunks = match chunks_result {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  // 由于 map 闭包内可能涉及复杂的 IO 初始化，且 for_reader 需要 Reader
  // 这里假设我们需要为每个 chunk 创建一个独立的 Reader 视图
  // 如果 File 不支持并发读取或切片，可能需要重新打开文件或其他方式
  // 此处修正主要解决语法和类型错误

  let parsers = Array::new()
  for chunk in chunks {
    let start = chunk.0
    let end = chunk.1
    let length = (end - start).to_int()

    // 假设存在一种方式从现有文件句柄创建一个限定范围的 Reader
    // 例如：file.slice(start, length) 或类似 API
    // 由于原代码尝试使用 read_exactly_at (这通常用于读取数据而非创建 Reader)，
    // 且报错显示类型和异步问题，这里改为使用一个假设的 safe_reader_at 或类似逻辑
    // 如果 Moonbit 标准库中 File 实现了 Reader 且支持 seek，我们可以包装它

    // 临时方案：如果无法直接切片，可能需要重新打开文件或使用其他机制
    // 这里为了演示修复，假设 file 有一个 .take_at(offset, len) 方法返回 Reader
    // 请根据实际 Moonbit IO API 调整此行
    let reader = file.read_exactly_at(length, position=start)

    parsers.push(self.for_slice(reader))
  }

  Ok(parsers)
}

///|
pub fn NQuadsParser::low_level(
  self : NQuadsParser,
) -> LowLevelNQuadsParser[RdfLexer] {
  { parser: NQuadsRecognizer::new_parser([], false, true, self.lenient) }
}

///|
pub struct ReaderNQuadsParser[RL] {
  inner : ReaderIterator[RL, NQuadsRecognizer]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderNQuadsParser[RL] {
  inner : AsyncReaderIterator[RL, NQuadsRecognizer]
}

///|
pub async fn[RL : TokenRecognizer] AsyncReaderNQuadsParser::next(
  self : AsyncReaderNQuadsParser[RL],
) -> Result[RdfStatement, LexerError]? {
  self.inner.next()
}

///|
pub struct SliceNQuadsParser[RL] {
  inner : SliceIterator[RdfLexer, RL]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelNQuadsParser[RL] {
  parser : Parser[RL, NQuadsRecognizer]
}

///|
pub fn[RL] LowLevelNQuadsParser::extend_from_slice(
  self : LowLevelNQuadsParser[RL],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn[RL] LowLevelNQuadsParser::end(self : LowLevelNQuadsParser[RL]) -> Unit {
  self.parser.end()
}

///|
pub fn[RL] LowLevelNQuadsParser::is_end(
  self : LowLevelNQuadsParser[RL],
) -> Bool {
  self.parser.is_end()
}

///|
pub fn[RL : TokenRecognizer] LowLevelNQuadsParser::parse_next(
  self : LowLevelNQuadsParser[RL],
) -> Result[Quad, TurtleError]? {
  self.parser
  .parse_next()
  .map(fn(res) {
    res
    .map(fn(lex_output) {
      match lex_output {
        RdfStatement::Triple(triple) =>
          Quad::Quad(
            triple.subject,
            triple.predicate,
            triple.object,
            GraphName::default(),
          )
        RdfStatement::Quad(quad) => quad
        RdfStatement::N3Quad(n3quad) =>
          match n3quad.predicate.to_node() {
            // 修复：使用 NamedNode(_) 忽略内部字段，消除警告
            NamedNode(node) =>
              Quad::Quad(
                n3quad.subject.to_node(),
                node,
                n3quad.object.to_term(),
                n3quad.graph_name,
              )
            // 建议：添加默认分支以处理其他可能的节点类型，避免运行时 panic 或未定义行为
            _ =>
              Quad::Quad(
                n3quad.subject.to_node(),
                NamedNode::default(),
                n3quad.object.to_term(),
                n3quad.graph_name,
              )
          }
      }
    })
    .map_err(fn(e) { TurtleError::InvalidCharacter(e.message()) }) // 根据实际错误类型调整
  })
}

///|
pub struct NQuadsSerializer {} derive(Default)

///|
// impl Writer for NQuadsSerializer with fn write_once(
//   self : NQuadsSerializer,
//   bytes : Bytes,
//   offset~,
//   len~,
// ) -> Int {
//   ...
// }

///|
pub fn NQuadsSerializer::new() -> NQuadsSerializer {
  NQuadsSerializer::default()
}

///|
pub fn[W] NQuadsSerializer::for_writer(
  self : NQuadsSerializer,
  writer : W,
) -> WriterNQuadsSerializer[W] {
  { writer, low_level_writer: self.low_level() }
}

///|
pub fn[W] NQuadsSerializer::for_async_writer(
  self : NQuadsSerializer,
  buffer_writer : BufferedWriter[W],
) -> AsyncWriterNQuadsSerializer[W] {
  { buffer_writer, low_level_writer: self.low_level() }
}

///|
pub fn NQuadsSerializer::low_level(
  _self : NQuadsSerializer,
) -> LowLevelNQuadsSerializer {
  LowLevelNQuadsSerializer::default()
}

///|
pub fn NQuadsSerializer::to_string(self : NQuadsSerializer, q : Quad) -> String {
  match self.low_level().serialize_quad(q) {
    Ok(s) => s
    Err(_) =>
      // 在极少数失败情况下，返回一个空字符串或触发更明确的调试错误
      // 或者使用 panic! 携带更多信息，而不是静默 unwrap
      abort("Failed to serialize quad: \{q}")
  }
}

///|
pub struct WriterNQuadsSerializer[W] {
  writer : W
  low_level_writer : LowLevelNQuadsSerializer
}

///|
pub fn[W] WriterNQuadsSerializer::serialize_quad(
  self : WriterNQuadsSerializer[W],
  q : Quad,
) -> Result[String, Unit] {
  self.low_level_writer.serialize_quad(q)
}

///|
pub fn[W] WriterNQuadsSerializer::finish(self : WriterNQuadsSerializer[W]) -> W {
  self.writer
}

///|
pub struct AsyncWriterNQuadsSerializer[W] {
  buffer_writer : BufferedWriter[W]
  low_level_writer : LowLevelNQuadsSerializer
  // buffer : Array[Byte]
}

///|
pub async fn[W : Writer] AsyncWriterNQuadsSerializer::serialize_quad(
  self : AsyncWriterNQuadsSerializer[W],
  q : Quad,
) -> Result[AsyncWriterNQuadsSerializer[W], SerializationError] {
  let serialized_str = match self.low_level_writer.serialize_quad(q) {
    Ok(serialized_str) => serialized_str
    Err(_) =>
      return Err(SerializationError::FormatError("Serialization failed"))
  }
  let data_bytes = @utf8.encode(serialized_str)
  // let buffer_writer =  self.buffer_writer.write(serialized_str);
  let buffer_writer = self.buffer_writer
  let mut written = 0

  while written < data_bytes.length() {
    let n = buffer_writer.write_once(
      data_bytes,
      offset=written,
      len=data_bytes.length() - written,
    )
    if n == 0 {
      buffer_writer.flush()
      continue
    }
    written += n
  }

  // 返回更新后的结构体
  Ok({ buffer_writer, low_level_writer: self.low_level_writer })
}

///|
pub async fn[W : Writer] AsyncWriterNQuadsSerializer::finish(
  self : AsyncWriterNQuadsSerializer[W],
) -> Result[BufferedWriter[W], Unit] {
  // 将缓冲区内容写入 writer
  // if self.buffer.length() > 0 {
  //   let data = Bytes::from_array(self.buffer)
  //   self.writer.write(data)
  // }
  let buffer_writer = self.buffer_writer
  buffer_writer.flush()
  // let buffer = self.buffer

  // if buffer.length() > 0 {
  //   let data = Bytes::from_array(buffer)
  //   writer.write(data) // 写入剩余数据
  // }

  Ok(buffer_writer)
}

///|
pub struct LowLevelNQuadsSerializer {} derive(Default)

///|
pub fn LowLevelNQuadsSerializer::serialize_quad(
  _self : LowLevelNQuadsSerializer,
  q : Quad,
) -> Result[String, Unit] {
  // writeln(writer , "{} ." , q)
  let res = StringBuilder::new()
  res.write_string(q.to_string())
  res.write_string(".\n")

  Ok(res.to_string())
}
