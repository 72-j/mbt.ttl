///|
pub struct NTriplesParser {
  mut lenient : Bool
} derive(Default)

///|
pub fn NTriplesParser::new() -> NTriplesParser {
  NTriplesParser::default()
}

///|
pub fn NTriplesParser::lenient(self : NTriplesParser) -> NTriplesParser {
  self.lenient = true
  self
}

///|
pub fn NTriplesParser::for_reader(
  self : NTriplesParser,
  reader : &Reader,
) -> ReaderNTriplesParser[NxLexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn NTriplesParser::for_async_reader(
  self : NTriplesParser,
  reader : &Reader,
) -> AsyncReaderNTriplesParser[NxLexer] {
  { inner: self.low_level().parser.for_async_reader(reader) }
}

///|
pub fn NTriplesParser::for_slice(
  self : NTriplesParser,
  slice : Bytes,
) -> SliceNTriplesParser[NQuadsRecognizer] {
  let parser = NQuadsRecognizer::new_parser(
    slice.to_array(),
    true,
    true,
    self.lenient,
  )
  { inner: { parser, } }
}
// pub fn NTriplesParser::split_slice_for_parallel_parsing(self : NTriplesParser, slice : _, target_parallelism : Int) -> Array[SliceNTriplesParser] {
//   let slice = slice
//   let n_chunks = (slice.length() / MIN_PARALLEL_CHUNK_SIZE).clamp(1, target_parallelism)
//   // 修复：将 fn((start, end)) 改为 fn(pair)，并在内部解构
//   get_ntriples_slice_chunks(slice, n_chunks).map(fn(pair) {
//     let (start, end) = pair
//     self.for_slice(slice[start:end])
//   })
// }
// pub fn NTriplesParser::split_file_for_parallel_parsing(self : NTriplesParser, path : AsRef, target_parallelism : Int) -> Result[Array[ReaderNTriplesParser[Take[File]]]] {
//   let path = path
//   let mut file = File::open(path)
//   let file_size = file.metadata()!.length()
//   let n_chunks = Int::try_from(file_size / UInt64::try_from(MIN_PARALLEL_CHUNK_SIZE).map_err(io::Error::other)!).map_err(io::Error::other)!.clamp(1, target_parallelism)
//   get_ntriples_file_chunks(file, file_size, n_chunks)!.map(fn((start, end)) {   let mut file = File::open(path)!
//   file.seek(SeekFrom::Start(start))!
//   Ok(self.for_reader(file.take(end - start))) })
// }

///|
pub fn NTriplesParser::low_level(
  self : NTriplesParser,
) -> LowLevelNTriplesParser[NxLexer] {
  { parser: NQuadsRecognizer::new_parser([], false, false, self.lenient) }
}

///|
pub struct ReaderNTriplesParser[LR] {
  inner : ReaderIterator[LR, NQuadsRecognizer]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderNTriplesParser[LR] {
  inner : AsyncReaderIterator[LR, NQuadsRecognizer]
}

///|
pub async fn[LR : TokenRecognizer] AsyncReaderNTriplesParser::next(
  self : AsyncReaderNTriplesParser[LR],
) -> Result[LexOutput, LexerError]? {
  self.inner.next()
}

///|
pub struct SliceNTriplesParser[LR] {
  inner : SliceIterator[NxLexer, LR]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelNTriplesParser[LR] {
  parser : Parser[LR, NQuadsRecognizer]
}

///|
pub fn LowLevelNTriplesParser::extend_from_slice(
  self : LowLevelNTriplesParser[NxLexer],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn LowLevelNTriplesParser::end(
  self : LowLevelNTriplesParser[NxLexer],
) -> Unit {
  self.parser.end()
}

///|
pub fn LowLevelNTriplesParser::is_end(
  self : LowLevelNTriplesParser[NxLexer],
) -> Bool {
  self.parser.is_end()
}

///|
pub fn[LR : TokenRecognizer] LowLevelNTriplesParser::parse_next(
  self : LowLevelNTriplesParser[LR],
) -> Result[Triple, TurtleError]? {
  self.parser
  .parse_next()
  .map(fn(res) {
    res
    .map(fn(lex_output) {
      match lex_output {
        LexOutput::Triple(t) => t
        LexOutput::Quad(q) => Triple::Triple(q.subject, q.predicate, q.object)
        LexOutput::N3Quad(n3quad) =>
          match n3quad.predicate.to_node() {
            NamedNode(node) =>
              Triple::Triple(
                n3quad.subject.to_node(),
                node,
                n3quad.object.to_term(),
              )
            _ =>
              Triple::Triple(
                n3quad.subject.to_node(),
                NamedNode::default(),
                n3quad.object.to_term(),
              )
          }
      }
    })
    .map_err(fn(e) { TurtleError::InvalidToken(TextPosition::default(),e.to_string()) }) // 根据实际错误类型调整
  })
}

///|
pub struct NTriplesSerializer {} derive(Default)

///|
pub fn NTriplesSerializer::new() -> NTriplesSerializer {
  NTriplesSerializer::default()
}

///|
pub fn[W] NTriplesSerializer::for_writer(
  self : NTriplesSerializer,
  writer : W,
) -> WriterNTriplesSerializer[W] {
  { writer, low_level_writer: self.low_level() }
}

///|
pub fn[W] NTriplesSerializer::for_async_writer(
  self : NTriplesSerializer,
  buffer_writer : BufferedWriter[W],
) -> AsyncWriterNTriplesSerializer[W] {
  { buffer_writer, low_level_writer: self.low_level() }
}

///|
pub fn NTriplesSerializer::low_level(
  _self : NTriplesSerializer,
) -> LowLevelNTriplesSerializer {
  LowLevelNTriplesSerializer::default()
}

///|
pub fn NTriplesSerializer::to_string(
  self : NTriplesSerializer,
  t : Triple,
) -> String {
  self.low_level().serialize_triple(t).unwrap()
}

///|
pub struct WriterNTriplesSerializer[W] {
  writer : W
  low_level_writer : LowLevelNTriplesSerializer
}

///|
pub fn[W] WriterNTriplesSerializer::serialize_triple(
  self : WriterNTriplesSerializer[W],
  t : Triple,
) -> Result[String, Unit] {
  self.low_level_writer.serialize_triple(t)
}

///|
pub fn[W] WriterNTriplesSerializer::finish(
  self : WriterNTriplesSerializer[W],
) -> W {
  self.writer
}

///|
pub struct AsyncWriterNTriplesSerializer[W] {
  buffer_writer : BufferedWriter[W]
  low_level_writer : LowLevelNTriplesSerializer
}

///|
pub fn[W] AsyncWriterNTriplesSerializer::serialize_triple(
  self : AsyncWriterNTriplesSerializer[W],
  t : Triple,
) -> Result[String, Unit] {
  self.low_level_writer.serialize_triple(t)
}

///|
pub async fn[W : Writer] AsyncWriterNTriplesSerializer::finish(
  self : AsyncWriterNTriplesSerializer[W],
) -> Result[BufferedWriter[W], Unit] {
  let buffer_writer = self.buffer_writer
  buffer_writer.flush()
  Ok(buffer_writer)
}

///|
pub struct LowLevelNTriplesSerializer {} derive(Default)

///|
pub fn LowLevelNTriplesSerializer::serialize_triple(
  _self : LowLevelNTriplesSerializer,
  t : Triple,
) -> Result[String, Unit] {
  // writeln(writer , "{} ." , t . into ())
  let res = StringBuilder::new()
  res.write_string(t.to_string())
  res.write_string(".\n")

  Ok(res.to_string())
}
