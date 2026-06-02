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
// pub fn NQuadsParser::for_slice(self : NQuadsParser, slice : _) -> SliceNQuadsParser {
//   { inner: NQuadsRecognizer::new_parser(slice, true, true, self.lenient) }
// }
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

// pub struct SliceNQuadsParser {
//   inner : SliceIterator[NQuadsRecognizer]
// }
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
) -> Result[LexOutput, TurtleError]? {
  self.parser.parse_next()
}

///|
pub struct NQuadsSerializer {} derive(Default)

///|
pub fn NQuadsSerializer::new() -> NQuadsSerializer {
  ...
}

///|
pub fn NQuadsSerializer::for_writer(
  self : NQuadsSerializer,
  writer : &Writer,
) -> WriterNQuadsSerializer {
  { writer, low_level_writer: self.low_level() }
}

///|
pub fn NQuadsSerializer::for_async_writer(
  self : NQuadsSerializer,
  writer : &Writer,
) -> AsyncWriterNQuadsSerializer {
  { writer, low_level_writer: self.low_level(), buffer: [] }
}

///|
pub fn NQuadsSerializer::low_level(
  self : NQuadsSerializer,
) -> LowLevelNQuadsSerializer {
  ...
}

///|
pub struct WriterNQuadsSerializer {
  writer : &Writer
  low_level_writer : LowLevelNQuadsSerializer
}

///|
pub fn WriterNQuadsSerializer::serialize_quad(
  self : WriterNQuadsSerializer,
  q : StringBuilder,
) -> Result[String, Unit] {
  self.low_level_writer.serialize_quad(q, self.writer)
}

///|
pub fn WriterNQuadsSerializer::finish(self : WriterNQuadsSerializer) -> &Writer {
  self.writer
}

///|
pub struct AsyncWriterNQuadsSerializer {
  writer : &Writer
  low_level_writer : LowLevelNQuadsSerializer
  buffer : Array[Byte]
}

///|
pub fn AsyncWriterNQuadsSerializer::serialize_quad(
  self : AsyncWriterNQuadsSerializer,
  q : StringBuilder,
) -> Result[Unit, Unit] {
  // LowLevel 的 serialize_quad 实际上返回序列化的字符串，第二个参数 writer 在其内部未被使用
  // 因此传入 self.writer 仅为了满足类型检查，实际数据从返回值获取
  let serialized_str = self.low_level_writer
    .serialize_quad(q, self.writer)
    .unwrap()

  // 将序列化后的字符串字节追加到缓冲区
  self.buffer.append(BytesView::to_array(@utf8.encode(serialized_str)))

  Ok(())
  // self.low_level_writer.serialize_quad(q, self.buffer)
  // self.writer.write_all(self.buffer)
  // self.buffer.clear()
  // Ok(())
}

///|
pub fn AsyncWriterNQuadsSerializer::finish(
  self : AsyncWriterNQuadsSerializer,
) -> &Writer {
  self.writer
}

///|
pub struct LowLevelNQuadsSerializer {}

///|
pub fn LowLevelNQuadsSerializer::serialize_quad(
  self : LowLevelNQuadsSerializer,
  q : StringBuilder,
  writer : &Writer,
) -> Result[String, Unit] {
  // writeln(writer , "{} ." , q)
  let res = StringBuilder::new()
  res.write_object(q)
  res.write_string(" .\n")
  Ok(res.to_string())
}
