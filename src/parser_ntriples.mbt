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
) -> ReaderNTriplesParser[RdfLexer] {
  //   let parser = NQuadsRecognizer::new_parser(
  //   [],        // 空初始缓冲区
  //   true,      // skip_whitespace: true
  //   true,      // allow_comments/lenient_features: true
  //   self.lenient,
  // )
  // 调用 parser.mbt 中的 Parser::for_reader
  // { inner: parser.for_reader(reader) }
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn NTriplesParser::for_async_reader(
  self : NTriplesParser,
  reader : &Reader,
) -> AsyncReaderNTriplesParser[RdfLexer] {
  //   let parser = NQuadsRecognizer::new_parser(
  //   [],
  //   true,
  //   true,
  //   self.lenient,
  // )
  // { inner: parser.for_async_reader(reader) }
  { inner: self.low_level().parser.for_async_reader(reader) }
}

///|
pub fn NTriplesParser::for_slice(
  self : NTriplesParser,
  slice : BytesView,
) -> SliceNTriplesParser[NQuadsRecognizer] {
  let parser = NQuadsRecognizer::new_parser(
    slice.to_array(),
    true,
    self.lenient,
  )
  { inner: { parser, } }
}

///|
pub fn NTriplesParser::split_slice_for_parallel_parsing(
  self : NTriplesParser,
  slice : BytesView,
  target_parallelism : Int,
) -> Array[SliceNTriplesParser[NQuadsRecognizer]] {
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
pub async fn NTriplesParser::split_file_for_parallel_parsing(
  self : NTriplesParser,
  path : String,
  target_parallelism : Int64,
) -> Result[Array[SliceNTriplesParser[NQuadsRecognizer]], String] {
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

  let parsers = Array::new()
  for chunk in chunks {
    let start = chunk.0
    let end = chunk.1
    let length = (end - start).to_int()

    let reader = file.read_exactly_at(length, position=start)

    parsers.push(self.for_slice(reader))
  }

  Ok(parsers)
}

///|
pub fn NTriplesParser::low_level(
  self : NTriplesParser,
) -> LowLevelNTriplesParser[RdfLexer] {
  { parser: NQuadsRecognizer::new_parser([], false, self.lenient) }
}

///|
pub struct ReaderNTriplesParser[RL] {
  inner : ReaderIterator[RL, NQuadsRecognizer]
}

///|
pub struct AsyncReaderNTriplesParser[RL] {
  inner : AsyncReaderIterator[RL, NQuadsRecognizer]
}

///|
pub async fn[RL : TokenRecognizer] AsyncReaderNTriplesParser::next(
  self : AsyncReaderNTriplesParser[RL],
) -> Result[RdfOut, LexerError]? {
  self.inner.next()
}

///|
pub struct SliceNTriplesParser[RL] {
  inner : SliceIterator[RdfLexer, RL]
}

///|
pub struct LowLevelNTriplesParser[RL] {
  parser : Parser[RL, NQuadsRecognizer]
}

///|
pub fn LowLevelNTriplesParser::extend_from_slice(
  self : LowLevelNTriplesParser[RdfLexer],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn LowLevelNTriplesParser::end(
  self : LowLevelNTriplesParser[RdfLexer],
) -> Unit {
  self.parser.end()
}

///|
pub fn LowLevelNTriplesParser::is_end(
  self : LowLevelNTriplesParser[RdfLexer],
) -> Bool {
  self.parser.is_end()
}

///|
pub fn[RL : TokenRecognizer] LowLevelNTriplesParser::parse_next(
  self : LowLevelNTriplesParser[RL],
) -> Result[Triple, TurtleError]? {
  self.parser
  .parse_next()
  .map(fn(res) {
    res
    .map(fn(lex_output) {
      match lex_output {
        RdfOut::Triple(t) => t
        RdfOut::Quad(q) => Triple::Triple(q.subject, q.predicate, q.object)
        RdfOut::N3Quad(n3quad) =>
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
    .map_err(fn(e) {
      TurtleError::InvalidToken(SourcePos::default(), e.to_string())
    }) // 根据实际错误类型调整
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
  match self.low_level().serialize_triple(t) {
    Ok(s) => s
    Err(_) => "" // 或者处理错误，例如 panic!("Serialization failed")
  }
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
  let res = StringBuilder::new()
  res.write_string(t.to_string())
  res.write_string(".\n")

  Ok(res.to_string())
}
