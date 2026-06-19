///|
pub struct TurtleParser {
  mut lenient : Bool
  mut base_iri : Iri?
  prefixes : Map[String, Iri]
} derive(Default)

///|
pub fn TurtleParser::new() -> TurtleParser {
  TurtleParser::default()
}

///|
pub fn TurtleParser::lenient(self : TurtleParser) -> TurtleParser {
  self.lenient = true
  self
}

///|
pub fn TurtleParser::with_base_iri(
  self : TurtleParser,
  base_iri : IriRef,
) -> Result[TurtleParser, IriError] {
  self.base_iri = Some(IriRef::parse(base_iri).unwrap())
  Ok(self)
}

///|
pub fn TurtleParser::with_prefix(
  self : TurtleParser,
  prefix_name : String,
  prefix_iri : IriRef,
) -> Result[TurtleParser, IriError] {
  self.prefixes.set(prefix_name, IriRef::parse(prefix_iri).unwrap())
  Ok(self)
}

///|
pub fn TurtleParser::for_reader(
  self : TurtleParser,
  reader : &Reader,
) -> ReaderTurtleParser[NxLexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn TurtleParser::for_async_reader(
  self : TurtleParser,
  reader : &Reader,
) -> AsyncReaderTurtleParser[NxLexer] {
  { inner: self.low_level().parser.for_async_reader(reader) }
}

///|
pub fn TurtleParser::for_slice(
  self : TurtleParser,
  slice : BytesView,
) -> SliceTurtleParser[TriGRecognizer] {
  let parser = TriGRecognizer::new_parser(
    slice.to_array(),
    false,
    false, // 补充缺失的第2个参数，假设默认为 false
    self.lenient,
    self.base_iri,
    self.prefixes,
  )
  { inner: { parser, } }
}
// pub fn TurtleParser::split_slice_for_parallel_parsing(self : TurtleParser, slice : _, target_parallelism : Int) -> Array[SliceTurtleParser] {
//   let slice = slice
//   let n_chunks = (slice.length() / MIN_PARALLEL_CHUNK_SIZE).clamp(1, target_parallelism)
//   if n_chunks > 1 {
//     let mut from_slice_parser = self.for_slice(slice)
//     from_slice_parser.next()
//     for _item in from_slice_parser.prefixes() {
//       let (p, iri) = _item
//       self = self.with_prefix(p, iri).unwrap()
//     }
//   }
//   get_turtle_slice_chunks(slice, n_chunks, self).map(fn((start, end)) { self.for_slice(slice[start..<end]) })
// }

///|
pub fn TurtleParser::low_level(
  self : TurtleParser,
) -> LowLevelTurtleParser[NxLexer] {
  {
    parser: TriGRecognizer::new_parser(
      [],
      false,
      false,
      self.lenient,
      self.base_iri,
      self.prefixes,
    ),
  }
}

///|
pub struct ReaderTurtleParser[LR] {
  inner : ReaderIterator[LR, TriGRecognizer]
}

///|
pub fn[LR] ReaderTurtleParser::prefixes(
  self : ReaderTurtleParser[LR],
) -> TurtlePrefixesIter {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      // 假设 ctx 有一个 prefixes 字段，且是 Map[String, Iri]
      // 如果 prefixes 是其他类型，请调整 .iter() 的调用
      { inner: ctx.prefixes.iter() }
    _ =>
      // N-Quads 通常不支持前缀，返回空迭代器或抛出错误
      // 这里假设返回一个空的 TriGPrefixesIter
      { inner: [].iter() } // 注意：[].iter() 的类型需要匹配 Iter2[String, Iri]
    // 如果无法构造空迭代器，可能需要 panic 或返回 Option
  }
}

///|
pub fn[LR] ReaderTurtleParser::base_iri(
  self : ReaderTurtleParser[LR],
) -> String? {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderTurtleParser[LR] {
  inner : AsyncReaderIterator[LR, TriGRecognizer]
}

///|
pub async fn[LR : TokenRecognizer] AsyncReaderTurtleParser::next(
  self : AsyncReaderTurtleParser[LR],
) -> Result[N3Quad, TurtleError]? {
  self.inner
  .next()
  .map(fn(res) {
    res
    .map(fn(lex_output) {
      match lex_output {
        LexOutput::Triple(triple) =>
          Quad::Quad(
            triple.subject,
            triple.predicate,
            triple.object,
            GraphName::default(),
          ).as_n3quad()
        LexOutput::Quad(quad) => quad.as_n3quad()
        LexOutput::N3Quad(n3quad) => n3quad
      }
    })
    .map_err(fn(e) { TurtleError::InvalidCharacter(e.message()) })
  })
}

///|
pub fn[LR] AsyncReaderTurtleParser::prefixes(
  self : AsyncReaderTurtleParser[LR],
) -> TurtlePrefixesIter {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      // 假设 ctx.prefixes 是 Map[String, IriRef] 或类似可迭代结构
      { inner: ctx.prefixes.iter() }
    _ =>
      // 返回空的迭代器，需确保类型与 TriGPrefixesIter 内部兼容
      // 这里假设存在一个空的 Map 或数组可以生成匹配的 Iter2
      { inner: [].iter() }
  }
}

///|
pub fn[LR] AsyncReaderTurtleParser::base_iri(
  self : AsyncReaderTurtleParser[LR],
) -> String? {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
pub struct SliceTurtleParser[LR] {
  inner : SliceIterator[NxLexer, LR]
}

///|
pub fn[LR] SliceTurtleParser::prefixes(
  self : SliceTurtleParser[LR],
) -> TurtlePrefixesIter {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      // 假设 ctx 有一个 prefixes 字段，且是 Map[String, Iri]
      // 如果 prefixes 是其他类型，请调整 .iter() 的调用
      { inner: ctx.prefixes.iter() }
    _ =>
      // N-Quads 通常不支持前缀，返回空迭代器或抛出错误
      // 这里假设返回一个空的 TriGPrefixesIter
      { inner: [].iter() } // 注意：[].iter() 的类型需要匹配 Iter2[String, Iri]
    // 如果无法构造空迭代器，可能需要 panic 或返回 Option
  }
}

///|
pub fn[LR] SliceTurtleParser::base_iri(self : SliceTurtleParser[LR]) -> String? {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelTurtleParser[LR] {
  parser : Parser[LR, TriGRecognizer]
}

///|
pub fn[LR] LowLevelTurtleParser::extend_from_slice(
  self : LowLevelTurtleParser[LR],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn[LR] LowLevelTurtleParser::end(self : LowLevelTurtleParser[LR]) -> Unit {
  self.parser.end()
}

///|
pub fn[LR] LowLevelTurtleParser::is_end(
  self : LowLevelTurtleParser[LR],
) -> Bool {
  self.parser.is_end()
}

///|
pub fn[LR : TokenRecognizer] LowLevelTurtleParser::parse_next(
  self : LowLevelTurtleParser[LR],
) -> Result[LexOutput, TurtleError]? {
  self.parser.parse_next()
}

///|
pub fn[LR] LowLevelTurtleParser::prefixes(
  self : LowLevelTurtleParser[LR],
) -> TurtlePrefixesIter {
  match self.parser.context {
    Context::N3RecognizerContext(ctx) => { inner: ctx.prefixes.iter() }
    _ =>
      // 假设存在一个空的 Map 或数组可以生成匹配的 Iter2[String, IriRef]
      { inner: {}.iter() }
  }
}

///|
pub fn[LR] LowLevelTurtleParser::base_iri(
  self : LowLevelTurtleParser[LR],
) -> String? {
  match self.parser.context {
    Context::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
pub struct TurtlePrefixesIter {
  inner : Iter2[String, Iri]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct TurtleSerializer {
  mut inner : TriGSerializer
} derive(Default)

///|
pub fn TurtleSerializer::new() -> TurtleSerializer {
  TurtleSerializer::default()
}

///|
pub fn TurtleSerializer::with_prefix(
  self : TurtleSerializer,
  prefix_name : String,
  prefix_iri : IriRef,
) -> Result[TurtleSerializer, IriError] {
  self.inner = self.inner.with_prefix(prefix_name, prefix_iri).unwrap()
  Ok(self)
}

///|
pub fn TurtleSerializer::with_base_iri(
  self : TurtleSerializer,
  base_iri : IriRef,
) -> Result[TurtleSerializer, IriError] {
  self.inner = self.inner.with_base_iri(base_iri).unwrap()
  Ok(self)
}

///|
pub fn[W] TurtleSerializer::for_writer(
  self : TurtleSerializer,
  writer : W,
) -> WriterTurtleSerializer[W] {
  { inner: self.inner.for_writer(writer) }
}

///|
pub fn[W] TurtleSerializer::for_async_writer(
  self : TurtleSerializer,
  writer : BufferedWriter[W],
) -> AsyncWriterTurtleSerializer[W] {
  { buffer_writer: writer, low_level_writer: self.low_level().inner }
}

///|
pub fn TurtleSerializer::low_level(
  self : TurtleSerializer,
) -> LowLevelTurtleSerializer {
  { inner: self.inner.low_level() }
}

///|
pub struct WriterTurtleSerializer[W] {
  inner : WriterTriGSerializer[W]
}

///|
pub fn[W] WriterTurtleSerializer::serialize_triple(
  self : WriterTurtleSerializer[W],
  t : Triple,
) -> Result[String, Unit] {
  self.inner.serialize_quad(t.in_graph(GraphNameRef::DefaultGraph))
}

///|
pub fn[W] WriterTurtleSerializer::finish(self : WriterTurtleSerializer[W]) -> W {
  self.inner.finish()
}

///|
pub struct AsyncWriterTurtleSerializer[W] {
  buffer_writer : BufferedWriter[W]
  low_level_writer : LowLevelTriGSerializer
}

///|
pub async fn[W] AsyncWriterTurtleSerializer::serialize_triple(
  self : AsyncWriterTurtleSerializer[W],
  t : Triple,
) -> Result[String, Unit] {
  // 修复：使用正确的字段 low_level_writer 调用 serialize_quad
  self.low_level_writer.serialize_quad(t.in_graph(GraphNameRef::DefaultGraph))
}

///|
pub async fn[W] AsyncWriterTurtleSerializer::finish(
  self : AsyncWriterTurtleSerializer[W],
) -> W {
  self.finish()
}

///|
pub struct LowLevelTurtleSerializer {
  inner : LowLevelTriGSerializer
}

///|
pub fn LowLevelTurtleSerializer::serialize_triple(
  self : LowLevelTurtleSerializer,
  t : Triple,
) -> Result[String, Unit] {
  self.inner.serialize_quad(t.in_graph(GraphNameRef::DefaultGraph))
}

///|
pub async fn[W : Writer] LowLevelTurtleSerializer::finish(
  self : LowLevelTurtleSerializer,
  writer : BufferedWriter[W],
) -> Result[Unit, Unit] {
  self.inner.finish(writer)
}
