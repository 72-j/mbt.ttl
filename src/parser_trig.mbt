///|
pub struct TriGParser {
  mut lenient : Bool
  mut base_iri : Iri?
  prefixes : Map[String, Iri]
} derive(Default)

///|
pub fn TriGParser::new() -> TriGParser {
  TriGParser::default()
}

///|
pub fn TriGParser::lenient(self : TriGParser) -> TriGParser {
  self.lenient = true
  self
}

///|
pub fn TriGParser::with_base_iri(
  self : TriGParser,
  base_iri : IriRef,
) -> Result[TriGParser, IriError] {
  self.base_iri = Some(IriRef::parse(base_iri).unwrap())
  Ok(self)
}

///|
pub fn TriGParser::with_prefix(
  self : TriGParser,
  prefix_name : String,
  prefix_iri : IriRef,
) -> Result[TriGParser, IriError] {
  self.prefixes.set(prefix_name, IriRef::parse(prefix_iri).unwrap())
  Ok(self)
}

///|
pub fn TriGParser::for_reader(
  self : TriGParser,
  reader : &Reader,
) -> ReaderTriGParser[NxLexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn TriGParser::for_async_reader(
  self : TriGParser,
  reader : &Reader,
) -> AsyncReaderTriGParser[NxLexer] {
  { inner: self.low_level().parser.for_async_reader(reader) }
}

///|
pub fn TriGParser::for_slice(
  self : TriGParser,
  slice : Bytes,
) -> SliceTriGParser[TriGRecognizer] {
  let parser = TriGRecognizer::new_parser(
    slice.to_array(),
    true,
    true,
    self.lenient,
    self.base_iri,
    self.prefixes,
  )
  { inner: { parser, } }
}

///|
pub fn TriGParser::low_level(self : TriGParser) -> LowLevelTriGParser[NxLexer] {
  {
    parser: TriGRecognizer::new_parser(
      [],
      false,
      true,
      self.lenient,
      self.base_iri,
      self.prefixes,
    ),
  }
}

///|
pub struct ReaderTriGParser[LR] {
  inner : ReaderIterator[LR, TriGRecognizer]
}

///|
pub fn[LR] ReaderTriGParser::prefixes(
  self : ReaderTriGParser[LR],
) -> TriGPrefixesIter {
  match self.inner.parser.context {
    Context::TriGRecognizerContext(ctx) =>
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
pub fn[LR] ReaderTriGParser::base_iri(self : ReaderTriGParser[LR]) -> String? {
  match self.inner.parser.context {
    Context::TriGRecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderTriGParser[LR] {
  inner : AsyncReaderIterator[LR, TriGRecognizer]
}

///|
pub async fn[LR : TokenRecognizer] AsyncReaderTriGParser::next(
  self : AsyncReaderTriGParser[LR],
) -> Result[Quad, TurtleError]? {
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
          )
        LexOutput::Quad(quad) => quad
        LexOutput::N3Quad(n3quad) =>
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
    .map_err(fn(_e) { TurtleError::InvalidEscapeSequence }) // 根据实际错误类型调整
  })
}

///|
pub fn[LR] AsyncReaderTriGParser::prefixes(
  self : AsyncReaderTriGParser[LR],
) -> TriGPrefixesIter {
  match self.inner.parser.context {
    Context::TriGRecognizerContext(ctx) =>
      // 假设 ctx.prefixes 是 Map[String, IriRef] 或类似可迭代结构
      { inner: ctx.prefixes.iter() }
    _ =>
      // 返回空的迭代器，需确保类型与 TriGPrefixesIter 内部兼容
      // 这里假设存在一个空的 Map 或数组可以生成匹配的 Iter2
      { inner: [].iter() }
  }
}

///|
pub fn[LR] AsyncReaderTriGParser::base_iri(
  self : AsyncReaderTriGParser[LR],
) -> String? {
  match self.inner.parser.context {
    Context::TriGRecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
pub struct SliceTriGParser[LR] {
  inner : SliceIterator[NxLexer, LR]
}

///|
pub fn SliceTriGParser::prefixes(
  self : SliceTriGParser[NxLexer],
) -> TriGPrefixesIter {
  match self.inner.parser.context {
    Context::TriGRecognizerContext(ctx) =>
      // 假设 ctx.prefixes 是 Map[String, IriRef] 或类似结构
      { inner: ctx.prefixes.iter() }
    _ =>
      // 返回空迭代器，需确保类型匹配 Iter2[String, IriRef]
      // 这里假设存在一个空的 Map 或数组可以生成匹配的 Iter2
      { inner: [].iter() }
  }
}

///|
pub fn SliceTriGParser::base_iri(self : SliceTriGParser[NxLexer]) -> String? {
  match self.inner.parser.context {
    Context::TriGRecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelTriGParser[LR] {
  parser : Parser[LR, TriGRecognizer]
}

///|
pub fn[LR] LowLevelTriGParser::extend_from_slice(
  self : LowLevelTriGParser[LR],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn[LR] LowLevelTriGParser::end(self : LowLevelTriGParser[LR]) -> Unit {
  self.parser.end()
}

///|
pub fn[LR] LowLevelTriGParser::is_end(self : LowLevelTriGParser[LR]) -> Bool {
  self.parser.is_end()
}

///|
pub fn[LR : TokenRecognizer] LowLevelTriGParser::parse_next(
  self : LowLevelTriGParser[LR],
) -> Result[Quad, TurtleError]? {
  self.parser
  .parse_next()
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
          )
        LexOutput::Quad(quad) => quad
        LexOutput::N3Quad(n3quad) =>
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
    .map_err(fn(_e) { TurtleError::InvalidEscapeSequence })
  })
}

///|
pub fn[LR] LowLevelTriGParser::prefixes(
  self : LowLevelTriGParser[LR],
) -> TriGPrefixesIter {
  match self.parser.context {
    Context::TriGRecognizerContext(ctx) => { inner: ctx.prefixes.iter() }
    _ =>
      // 假设存在一个空的 Map 或数组可以生成匹配的 Iter2[String, IriRef]
      { inner: {}.iter() }
  }
}

///|
pub fn[LR] LowLevelTriGParser::base_iri(
  self : LowLevelTriGParser[LR],
) -> String? {
  match self.parser.context {
    Context::TriGRecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
pub struct TriGPrefixesIter {
  inner : Iter2[String, Iri]
}
// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct TriGSerializer {
  mut base_iri : Iri?
  prefixes : Map[String, Iri]
} derive(Default)

///|
pub fn TriGSerializer::new() -> TriGSerializer {
  { base_iri: None, prefixes: {} }
}

///|
pub fn TriGSerializer::with_prefix(
  self : TriGSerializer,
  prefix_name : String,
  prefix_iri : IriRef,
) -> Result[TriGSerializer, IriError] {
  self.prefixes.set(prefix_name, IriRef::parse(prefix_iri).unwrap())
  Ok(self)
}

///|
pub fn TriGSerializer::with_base_iri(
  self : TriGSerializer,
  base_iri : IriRef,
) -> Result[TriGSerializer, IriError] {
  self.base_iri = Some(IriRef::parse(base_iri).unwrap())
  Ok(self)
}

///|
pub fn[W] TriGSerializer::for_writer(
  self : TriGSerializer,
  writer : W,
) -> WriterTriGSerializer[W] {
  { writer, low_level_writer: self.low_level() }
}

///|
pub fn[W] TriGSerializer::for_async_writer(
  self : TriGSerializer,
  writer : BufferedWriter[W],
) -> AsyncWriterTriGSerializer[W] {
  { buffer_writer: writer, low_level_writer: self.low_level() }
}

///|
pub fn TriGSerializer::low_level(
  self : TriGSerializer,
) -> LowLevelTriGSerializer {
  let sorted_prefixes = sort_prefixes(self.prefixes)
  {
    prefixes: sorted_prefixes,
    base_iri: self.base_iri,
    prelude_written: false,
    current_graph_name: GraphName::DefaultGraph,
    current_subject_predicate: None,
  }
}

///|
pub struct WriterTriGSerializer[W] {
  writer : W
  low_level_writer : LowLevelTriGSerializer
}

///|
pub fn[W] WriterTriGSerializer::serialize_quad(
  self : WriterTriGSerializer[W],
  q : Quad,
) -> Result[String, Unit] {
  self.low_level_writer.serialize_quad(q)
}

///|
pub fn[W] WriterTriGSerializer::finish(self : WriterTriGSerializer[W]) -> W {
  // self.low_level_writer.finish(self.writer)
  self.writer
}

///|
pub struct AsyncWriterTriGSerializer[W] {
  buffer_writer : BufferedWriter[W]
  low_level_writer : LowLevelTriGSerializer
}

///|
pub async fn[W : Writer] AsyncWriterTriGSerializer::serialize_quad(
  self : AsyncWriterTriGSerializer[W],
  q : Quad,
) -> Result[AsyncWriterTriGSerializer[W], SerializationError] {
  // self.low_level_writer.serialize_quad(q, self.writer)
  // self.writer.write(self.buffer)
  // self.buffer.clear()
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

  Ok({ buffer_writer, low_level_writer: self.low_level_writer })
}

///|
pub async fn[W : Writer] AsyncWriterTriGSerializer::finish(
  self : AsyncWriterTriGSerializer[W],
) -> Result[BufferedWriter[W], Unit] {
  //  let _= self.low_level_writer.finish(self.buffer)
  // self.writer.write(self.buffer)
  // self.buffer.clear()
  let buffer_writer = self.buffer_writer
  buffer_writer.flush()
  Ok(buffer_writer)
}

///|
pub struct LowLevelTriGSerializer {
  prefixes : Array[(String, String)]
  base_iri : Iri?
  mut prelude_written : Bool
  mut current_graph_name : GraphName
  mut current_subject_predicate : (NamedOrBlankNode, NamedNode)?
}

///|
pub fn LowLevelTriGSerializer::serialize_quad(
  self : LowLevelTriGSerializer,
  q : Quad,
) -> Result[String, Unit] {
  let writer = StringBuilder::new()

  if !self.prelude_written {
    self.prelude_written = true
    if self.base_iri is Some(base_iri) {
      writer.write("@base <\{base_iri}> .")
    }
    for _item in self.prefixes {
      let (prefix_name, prefix_iri) = _item
      // writer.write("@prefix \{prefix_name}: <{}> .")
      writer.write("@prefix ")
      writer.write(prefix_name)
      writer.write(": <")
      writer.write(relative_iri(prefix_iri, Some(self.base_iri.unwrap())))
      writer.write("> .")
    }
  }
  // let q = q.into_owned()
  if q.graph_name == self.current_graph_name {
    if self.current_subject_predicate
      is Some((current_subject, current_predicate)) {
      if q.subject == current_subject {
        if q.predicate == current_predicate {
          self.current_subject_predicate = Some(
            (current_subject, current_predicate),
          )
          // writer.write(",{}",self.term (q.object))
          writer.write(",")
          writer.write(self.term(q.object).to_string())
          Ok(writer.to_string())
        } else {
          self.current_subject_predicate = Some((current_subject, q.predicate))
          writer.write(" ;")
          if !self.current_graph_name.is_default_graph() {
            writer.write("\t")
          }
          // writer.write("\t{} {}",self.predicate (q.predicate),self.term (q.object))
          writer.write("\t")
          writer.write(self.predicate(q.predicate).to_string())
          writer.write(" ")
          writer.write(self.term(q.object).to_string())
          Ok(writer.to_string())
        }
      } else {
        self.current_subject_predicate = Some((q.subject, q.predicate))
        writer.write(" .")
        if !self.current_graph_name.is_default_graph() {
          writer.write("\t")
        }
        // writer.write("{} {} {}",self.term (q.subject),self.predicate (q.predicate),self.term (q.object))
        writer.write(self.term(q.subject.as_term()).to_string())
        writer.write(" ")
        writer.write(self.predicate(q.predicate).to_string())
        writer.write(" ")
        writer.write(self.term(q.object).to_string())
        Ok(writer.to_string())
      }
    } else {
      self.current_subject_predicate = Some((q.subject, q.predicate))
      if !self.current_graph_name.is_default_graph() {
        writer.write("\t")
      }
      // writer.write("{} {} {}",self.term (q.subject),self.predicate (q.predicate),self.term (q.object))
      writer.write(self.term(q.subject.as_term()).to_string())
      writer.write(" ")
      writer.write(self.predicate(q.predicate).to_string())
      writer.write(" ")
      writer.write(self.term(q.object).to_string())
      Ok(writer.to_string())
    }
  } else {
    if self.current_subject_predicate.is_some() {
      writer.write(" .")
    }
    if !self.current_graph_name.is_default_graph() {
      writer.write("}}")
    }
    self.current_graph_name = q.graph_name.into_owned()
    self.current_subject_predicate = Some((q.subject, q.predicate))
    match self.current_graph_name {
      GraphName::NamedNode(g) => {
        // writer.write("{} {{",self.term (g))
        writer.write(self.term(Term::NamedNode(g)).to_string())
        writer.write(" {{")
        writer.write("\t")
      }
      GraphName::BlankNode(g) => {
        // writer.write("{} {{",self.term (g))
        writer.write(self.term(Term::BlankNode(g)).to_string())
        writer.write(" {")
        writer.write("\t")
      }
      GraphName::DefaultGraph => ()
    }
    // writer.write("{} {} {}",self.term (q.subject),self.predicate (q.predicate),self.term (q.object))
    writer.write(self.term(q.subject.as_term()).to_string())
    writer.write(" ")
    writer.write(self.predicate(q.predicate).to_string())
    writer.write(" ")
    writer.write(self.term(q.object).to_string())
    Ok(writer.to_string())
  }
}

///|
fn LowLevelTriGSerializer::predicate(
  self : LowLevelTriGSerializer,
  named_node : NamedNode,
) -> TurtlePredicate {
  {
    named_node: named_node.as_ref(),
    prefixes: self.prefixes,
    base_iri: self.base_iri,
  }
}

///|
fn LowLevelTriGSerializer::term(
  self : LowLevelTriGSerializer,
  term : Term,
) -> TurtleTerm {
  TurtleTerm::{ term, prefixes: self.prefixes, base_iri: self.base_iri }
}

///|
pub async fn[W : Writer] LowLevelTriGSerializer::finish(
  self : LowLevelTriGSerializer,
  writer : BufferedWriter[W],
) -> Result[Unit, Unit] {
  if self.current_subject_predicate is Some(_) {
    writer.write(" .")
  }
  if !self.current_graph_name.is_default_graph() {
    writer.write("}}")
  }
  Ok(())
}

///|
priv struct TurtlePredicate {
  named_node : NamedNodeRef
  prefixes : Array[(String, String)]
  base_iri : Iri?
}

///|
impl Show for TurtlePredicate with fn output(
  self : TurtlePredicate,
  f : &Logger,
) -> Unit {
  if self.named_node == lwTYPE {
    f.write_string("a")
  } else {
    f.write_string(
      {
        term: Term::NamedNode(self.named_node.into_owned()),
        prefixes: self.prefixes,
        base_iri: self.base_iri,
      }.to_string(),
    )
  }
}

///|
priv struct TurtleTerm {
  term : Term
  prefixes : Array[(String, String)]
  base_iri : Iri?
}

///|
impl Show for TurtleTerm with fn output(self : TurtleTerm, logger : &Logger) -> Unit {
  match self.term {
    Term::NamedNode(v) => {
      for _item in self.prefixes {
        let (prefix_name, prefix_iri) = _item
        if v.to_string().strip_prefix(prefix_iri) is Some(local_name) {
          if local_name.is_empty() {
            logger.write_string("\{prefix_name}:")
          } else if escape_local_name(local_name) is Some(escaped_local_name) {
            logger.write_string("\{prefix_name}:\{escaped_local_name}")
          }
        }
      }
      logger.write_string(
        "<\{relative_iri(v.to_string(), Some(self.base_iri.unwrap()))}>",
      )
    }
    Term::BlankNode(v) => logger.write_string("\{v}")
    Term::Literal(v) => {
      let value = v.value()
      let dt = v.datatype()
      let is_plain = dt == lwSTRING ||
        dt == lwLANG_STRING ||
        dt == lwDIR_LANG_STRING
      // v.datatype() is (lwSTRING | lwLANG_STRING)
      if is_plain {
        logger.write_string("\{v}")
      } else {
        let inline = if dt == lwBOOLEAN {
          is_turtle_boolean(value)
        } else if dt == lwINTEGER {
          is_turtle_integer(value)
        } else if dt == lwDECIMAL {
          is_turtle_decimal(value)
        } else if dt == lwDOUBLE {
          is_turtle_double(value)
        } else {
          false
        }
        if inline {
          logger.write_string(value)
        } else {
          let literal = LiteralRef::new_simple_literal(v.value()).to_string()
          let turtle = TurtleTerm::{
            term: Term::NamedNode(dt.into_owned()),
            prefixes: self.prefixes,
            base_iri: self.base_iri,
          }.to_string()
          logger.write_string("\{literal}")
          logger.write_string("^^")
          logger.write_string("\{turtle}")
        }
      }
    }
    Term::Triple(t) => {
      //  logger.write_string("<<( {} {} {} )>>")
      logger.write_string("<<( ")
      logger.write_string(
        {
          term: t.subject.as_term(),
          prefixes: self.prefixes,
          base_iri: self.base_iri,
        }.to_string(),
      )
      logger.write_string(" ")
      logger.write_string(
        {
          term: Term::NamedNode(t.predicate),
          prefixes: self.prefixes,
          base_iri: self.base_iri,
        }.to_string(),
      )
      logger.write_string(" ")
      logger.write_string(
        { term: t.object, prefixes: self.prefixes, base_iri: self.base_iri }.to_string(),
      )
      logger.write_string(" )>>")
    }
  }
}

///|
fn relative_iri(iri : String, base_iri : Iri?) -> String {
  if base_iri is Some(base_iri) {
    let base_iri = IriRef::parse(base_iri.as_ref(), unchecked=true).unwrap()
    match base_iri.as_ref().resolve(iri) {
      Ok(resolved) => resolved.into_string()
      Err(_) => iri
    }
  } else {
    iri
  }
}

///|
fn is_turtle_boolean(value : StringView) -> Bool {
  value is ("true" | "false")
}

///|
fn is_turtle_integer(value : StringView) -> Bool {
  let mut value = @utf8.encode(value).to_array()[:]
  if value.strip_prefix(Bytes::to_array(b"+")) is Some(v) {
    value = v
  } else if value.strip_prefix(Bytes::to_array(b"-")) is Some(v) {
    value = v
  }
  !value.is_empty() && value.all(a => Byte::to_char(a).is_ascii_digit())
}

///|
fn is_turtle_decimal(value : StringView) -> Bool {
  let mut value = @utf8.encode(value).to_array()[:]
  if value.strip_prefix(Bytes::to_array(b"+")) is Some(v) {
    value = v
  } else if value.strip_prefix(Bytes::to_array(b"-")) is Some(v) {
    value = v
  }
  while value.get(0) is Some(_) &&
        value.all(a => Byte::to_char(a).is_ascii_digit()) {
    value = value[1:]
  }
  match value.strip_prefix(Bytes::to_array(b".")) {
    Some(v) => {
      value = v
      !value.is_empty() && value.all(a => Byte::to_char(a).is_ascii_digit())
    }
    None => false
  }
}

///|
fn is_turtle_double(value : StringView) -> Bool {
  let mut value = @utf8.encode(value).to_array()[:]

  if value.strip_prefix(Bytes::to_array(b"+")) is Some(v) {
    value = v
  } else if value.strip_prefix(Bytes::to_array(b"-")) is Some(v) {
    value = v
  }
  let mut with_before = false
  while value.get(0) is Some(a) && Byte::to_char(a).is_ascii_digit() {
    value = value[1:]
    with_before = true
  }
  let mut with_after = false
  if value.strip_prefix(Bytes::to_array(b".")) is Some(v) {
    value = v
    while value.get(0) is Some(a) && Byte::to_char(a).is_ascii_digit() {
      value = value[1:]
      with_after = true
    }
  }
  if value.strip_prefix(Bytes::to_array(b"e")) is Some(v) {
    value = v
  } else if value.strip_prefix(Bytes::to_array(b"E")) is Some(v) {
    value = v
  } else {
    return false
  }
  if value.strip_prefix(Bytes::to_array(b"+")) is Some(v) {
    value = v
  } else if value.strip_prefix(Bytes::to_array(b"-")) is Some(v) {
    value = v
  }
  (with_before || with_after) && !value.is_empty()
}

///|
fn escape_local_name(value : StringView) -> String? {
  let output = StringBuilder::new(size_hint=value.length())
  // let mut chars = value.iter()
  let first = value.get_char(0)
  if NxLexer::is_possible_pn_chars_u(first.unwrap()) ||
    first == Some(':') ||
    first == Some('.') {
    output.write_char(first.unwrap())
  } else if can_be_escaped_in_local_name(first.unwrap()) {
    output.write_char('\'')
    output.write_char(first.unwrap())
  } else {
    return None
  }
  for c in value {
    if NxLexer::is_possible_pn_chars(c) ||
      c == ':' ||
      (c == '.' && !value.is_empty()) {
      output.write_char(c)
    } else if can_be_escaped_in_local_name(c) {
      output.write_char('\'')
      output.write_char(c)
    } else {
      return None
    }
  }
  Some(output.to_string())
}

///|
fn can_be_escaped_in_local_name(c : Char) -> Bool {
  c
  is ('_'
  | '~'
  | '.'
  | '-'
  | '!'
  | '$'
  | '&'
  | '\''
  | '('
  | ')'
  | '*'
  | '+'
  | ','
  | ';'
  | '='
  | '/'
  | '?'
  | '#'
  | '@'
  | '%')
}
