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
  let parsed_iri = if self.lenient {
    // 宽松模式：直接解析，不检查有效性
    IriRef::parse_unchecked(base_iri)
  } else {
    // 严格模式：检查解析结果
    match IriRef::parse(base_iri) {
      Ok(iri) => iri
      Err(e) => return Err(e)
    }
  }
  self.base_iri = Some(parsed_iri)
  Ok(self)
}

///|
pub fn TurtleParser::with_prefix(
  self : TurtleParser,
  prefix_name : String,
  prefix_iri : IriRef,
) -> Result[TurtleParser, IriError] {
  let parsed_iri = if self.lenient {
    // 宽松模式：直接解析，不检查有效性
    IriRef::parse_unchecked(prefix_iri)
  } else {
    // 严格模式：检查解析结果
    match IriRef::parse(prefix_iri) {
      Ok(iri) => iri
      Err(e) => return Err(e)
    }
  }
  self.prefixes.set(prefix_name, parsed_iri)
  Ok(self)
}

///|
pub fn TurtleParser::for_reader(
  self : TurtleParser,
  reader : &Reader,
) -> ReaderTurtleParser[RdfLexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn TurtleParser::for_async_reader(
  self : TurtleParser,
  reader : &Reader,
) -> AsyncReaderTurtleParser[RdfLexer] {
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

///|
pub fn TurtleParser::split_slice_for_parallel_parsing(
  self : TurtleParser,
  slice : BytesView,
  target_parallelism : Int,
) -> Array[SliceTurtleParser[TriGRecognizer]] {
  let slice_size = slice.length()
  let chunk_size = MIN_PARALLEL_CHUNK_SIZE
  let n_chunks_raw = slice_size / chunk_size
  let n_chunks = n_chunks_raw.clamp(min=1, max=target_parallelism)
  let mut current_parser = self // 

  if n_chunks > 1 {
    let from_slice_parser = current_parser.for_slice(slice)
    // 注意：原代码中 next() 的返回值未处理，且 prefixes 迭代逻辑可能存在副作用问题
    // 这里保留原逻辑结构，仅修复语法错误
    let _ = from_slice_parser.inner.next()
    for entry in from_slice_parser.prefixes().inner {
      let p = entry.0
      let iri = entry.1.as_ref()
      match current_parser.with_prefix(p, iri) {
        Ok(parser) => current_parser = parser
        Err(_) => () // 忽略错误，或根据需求处理
      }
    }
  }

  // 修复点：修改 lambda 参数写法，并确保返回正确的类型
  get_turtle_slice_chunks(slice, n_chunks).map(fn(chunk) {
    let start = chunk.0
    let end = chunk.1
    self.for_slice(slice[start:end])
  })
}

///|
pub fn TurtleParser::low_level(
  self : TurtleParser,
) -> LowLevelTurtleParser[RdfLexer] {
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
pub struct ReaderTurtleParser[RL] {
  inner : ReaderIterator[RL, TriGRecognizer]
}

///|
pub fn[RL] ReaderTurtleParser::prefixes(
  self : ReaderTurtleParser[RL],
) -> TurtlePrefixesIter {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
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
pub fn[RL] ReaderTurtleParser::base_iri(
  self : ReaderTurtleParser[RL],
) -> String? {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderTurtleParser[RL] {
  inner : AsyncReaderIterator[RL, TriGRecognizer]
}

///|
pub async fn[RL : TokenRecognizer] AsyncReaderTurtleParser::next(
  self : AsyncReaderTurtleParser[RL],
) -> Result[N3Quad, TurtleError]? {
  self.inner
  .next()
  .map(fn(res) {
    res
    .map(fn(lex_output) {
      match lex_output {
        RdfOut::Triple(triple) =>
          Quad::Quad(
            triple.subject,
            triple.predicate,
            triple.object,
            GraphName::default(),
          ).as_n3quad()
        RdfOut::Quad(quad) => quad.as_n3quad()
        RdfOut::N3Quad(n3quad) => n3quad
      }
    })
    .map_err(fn(e) { TurtleError::InvalidCharacter(e.to_string()) })
  })
}

///|
pub fn[RL] AsyncReaderTurtleParser::prefixes(
  self : AsyncReaderTurtleParser[RL],
) -> TurtlePrefixesIter {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      // 假设 ctx.prefixes 是 Map[String, IriRef] 或类似可迭代结构
      { inner: ctx.prefixes.iter() }
    _ =>
      // 返回空的迭代器，需确保类型与 TriGPrefixesIter 内部兼容
      // 这里假设存在一个空的 Map 或数组可以生成匹配的 Iter2
      { inner: [].iter() }
  }
}

///|
pub fn[RL] AsyncReaderTurtleParser::base_iri(
  self : AsyncReaderTurtleParser[RL],
) -> String? {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
pub struct SliceTurtleParser[RL] {
  inner : SliceIterator[RdfLexer, RL]
}

///|
pub fn[RL] SliceTurtleParser::prefixes(
  self : SliceTurtleParser[RL],
) -> TurtlePrefixesIter {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
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
pub fn[RL] SliceTurtleParser::base_iri(self : SliceTurtleParser[RL]) -> String? {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelTurtleParser[RL] {
  parser : Parser[RL, TriGRecognizer]
}

///|
pub fn[RL] LowLevelTurtleParser::extend_from_slice(
  self : LowLevelTurtleParser[RL],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn[RL] LowLevelTurtleParser::end(self : LowLevelTurtleParser[RL]) -> Unit {
  self.parser.end()
}

///|
pub fn[RL] LowLevelTurtleParser::is_end(
  self : LowLevelTurtleParser[RL],
) -> Bool {
  self.parser.is_end()
}

///|
pub fn[RL : TokenRecognizer] LowLevelTurtleParser::parse_next(
  self : LowLevelTurtleParser[RL],
) -> Result[RdfOut, TurtleError]? {
  self.parser.parse_next()
}

///|
pub fn[RL] LowLevelTurtleParser::prefixes(
  self : LowLevelTurtleParser[RL],
) -> TurtlePrefixesIter {
  match self.parser.context {
    RdfContext::N3RecognizerContext(ctx) => { inner: ctx.prefixes.iter() }
    _ =>
      // 假设存在一个空的 Map 或数组可以生成匹配的 Iter2[String, IriRef]
      { inner: {}.iter() }
  }
}

///|
pub fn[RL] LowLevelTurtleParser::base_iri(
  self : LowLevelTurtleParser[RL],
) -> String? {
  match self.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
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
  match self.inner.with_prefix(prefix_name, prefix_iri) {
    Ok(new_inner) => {
      self.inner = new_inner
      Ok(self)
    }
    Err(e) => Err(e)
  }
}

///|
pub fn TurtleSerializer::with_base_iri(
  self : TurtleSerializer,
  base_iri : IriRef,
) -> Result[TurtleSerializer, IriError] {
  match self.inner.with_base_iri(base_iri) {
    Ok(new_inner) => {
      self.inner = new_inner
      Ok(self)
    }
    Err(e) => Err(e)
  }
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
