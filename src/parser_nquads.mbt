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
) -> ReaderNQuadsParser[N3Lexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn NQuadsParser::for_async_reader(
  self : NQuadsParser,
  reader : &Reader,
) -> AsyncReaderNQuadsParser[N3Lexer] {
  { inner: self.low_level().parser.for_async_reader(reader) }
}
pub fn NQuadsParser::for_slice(self : NQuadsParser, slice : Bytes) -> SliceNQuadsParser[NQuadsRecognizer] {
  
  let parser = NQuadsRecognizer::new_parser(slice.to_array(), true, true, self.lenient)
  { inner: { parser: parser } }   
}
// pub fn NQuadsParser::split_slice_for_parallel_parsing(self : NQuadsParser, slice : _, target_parallelism : Int) -> Array[SliceNQuadsParser] {
//   let slice = slice
//   let n_chunks = (slice.length() / MIN_PARALLEL_CHUNK_SIZE).clamp(1, target_parallelism)
//   get_ntriples_slice_chunks(slice, n_chunks).map(fn((start, end)) { self.for_slice(slice[start..<end]) })
// }
// pub fn NQuadsParser::split_file_for_parallel_parsing(self : NQuadsParser, path : AsRef, target_parallelism : Int) -> Result[Array[ReaderNQuadsParser[Take[File]]]] {
//   let path = path
//   let mut file = File::open(path)!
//   let file_size = file.metadata()!.length()
//   let n_chunks = Int::try_from(file_size / UInt64::try_from(MIN_PARALLEL_CHUNK_SIZE).map_err(io::Error::other)!).map_err(io::Error::other)!.clamp(1, target_parallelism)
//   get_ntriples_file_chunks(file, file_size, n_chunks)!.map(fn((start, end)) {   let mut file = File::open(path)!
//   file.seek(SeekFrom::Start(start))!
//   Ok(self.for_reader(file.take(end - start))) })
// }

///|
pub fn NQuadsParser::low_level(
  self : NQuadsParser,
) -> LowLevelNQuadsParser[N3Lexer] {
  { parser: NQuadsRecognizer::new_parser([], false, true, self.lenient) }
}

///|
pub struct ReaderNQuadsParser[TR] {
  inner : ReaderIterator[TR, NQuadsRecognizer]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderNQuadsParser[TR] {
  inner : AsyncReaderIterator[TR, NQuadsRecognizer]
}

///|
pub async fn[TR : TokenRecognizer] AsyncReaderNQuadsParser::next(
  self : AsyncReaderNQuadsParser[TR],
) -> Result[LexOutput, LexerError]? {
  self.inner.next()
}

pub struct SliceNQuadsParser[TR] {
  inner : SliceIterator[N3Lexer,TR]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelNQuadsParser[TR] {
  parser : Parser[TR, NQuadsRecognizer]
}

///|
pub fn[TR] LowLevelNQuadsParser::extend_from_slice(
  self : LowLevelNQuadsParser[TR],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn[TR] LowLevelNQuadsParser::end(self : LowLevelNQuadsParser[TR]) -> Unit {
  self.parser.end()
}

///|
pub fn[TR] LowLevelNQuadsParser::is_end(
  self : LowLevelNQuadsParser[TR],
) -> Bool {
  self.parser.is_end()
}

///|
pub fn[TR : TokenRecognizer] LowLevelNQuadsParser::parse_next(
  self : LowLevelNQuadsParser[TR],
) -> Result[Quad, TurtleError]? {
  self.parser
  .parse_next()
  .map(fn(res) {
    res
    .map(fn(lex_output) {
      match lex_output {
        LexOutput::Triple(triple) => Quad::new(triple.subject, triple.predicate, triple.object, GraphName::default())
        LexOutput::Quad(quad) => quad
      }
    })
    .map_err(fn(_e) { TurtleError::InvalidEscapeSequence })
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
  self.low_level().serialize_quad(q).unwrap()
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
