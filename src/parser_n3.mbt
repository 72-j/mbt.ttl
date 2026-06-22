///|
pub enum N3Term {
  NamedNode(NamedNode)
  BlankNode(BlankNode)
  Literal(Literal)
  Triple(Triple)
  Variable(String)
} derive(Eq, Debug, Hash)

///|
fn N3Term::to_term(self : N3Term) -> Term {
  match self {
    N3Term::NamedNode(term) => Term::NamedNode(term)
    N3Term::BlankNode(term) => Term::BlankNode(term)
    N3Term::Literal(term) => Term::Literal(term)
    N3Term::Triple(term) => Term::Triple(term)
    N3Term::Variable(_term) => Term::BlankNode(BlankNode::default())
  }
}

///|
fn N3Term::to_node(self : N3Term) -> NamedOrBlankNode {
  match self {
    N3Term::NamedNode(term) => NamedOrBlankNode::NamedNode(term)
    N3Term::BlankNode(term) => NamedOrBlankNode::BlankNode(term)
    N3Term::Literal(_term) => NamedOrBlankNode::BlankNode(BlankNode::default())
    N3Term::Triple(_term) => NamedOrBlankNode::BlankNode(BlankNode::default())
    N3Term::Variable(_term) => NamedOrBlankNode::BlankNode(BlankNode::default())
  }
}

///|
impl Show for N3Term with fn output(self : N3Term, f : &Logger) -> Unit {
  match self {
    N3Term::NamedNode(term) => f.write_object(term)
    N3Term::BlankNode(term) => f.write_object(term)
    N3Term::Literal(term) => f.write_object(term)
    N3Term::Triple(term) => f.write_object(term)
    N3Term::Variable(term) => f.write_object(term)
  }
}
// pub fn N3Term::as_n3quad(self : N3Term) -> N3Quad {
//   match self {
//     N3Term::NamedNode(term) => N3Term::NamedNode(term)
//     N3Term::BlankNode(term) => N3Term::BlankNode(term)
//     N3Term::Literal(term) => N3Term::Literal(term)
//     N3Term::Triple(term) => N3Term::Triple(term)
//     N3Term::Variable(term) => N3Term::Variable(term)
//   }
// }

// impl From for N3Term with from(self : N3Term, node : NamedNode) -> N3Term {
//   N3Term::NamedNode(node)
// }

// impl From for N3Term with from(self : N3Term, node : NamedNodeRef) -> N3Term {
//   N3Term::NamedNode(node.into_owned())
// }

// impl From for N3Term with from(self : N3Term, node : BlankNode) -> N3Term {
//   N3Term::BlankNode(node)
// }

// impl From for N3Term with from(self : N3Term, literal : Literal) -> N3Term {
//   N3Term::Literal(literal)
// }

// impl From for N3Term with from(self : N3Term, triple : Triple) -> N3Term {
//   N3Term::Triple(triple)
// }

// impl From for N3Term with from(self : N3Term, node : Triple) -> N3Term {
//   N3Term::Triple(node)
// }

// impl From for N3Term with from(self : N3Term, node : NamedOrBlankNode) -> N3Term {
//   match node {
//     NamedOrBlankNode::NamedNode(node) => node.into()
//     NamedOrBlankNode::BlankNode(node) => node.into()
//   }
// }

// impl From for N3Term with from(self : N3Term, node : Term) -> N3Term {
//   match node {
//     Term::NamedNode(node) => node.into()
//     Term::BlankNode(node) => node.into()
//     Term::Literal(node) => node.into()
//     Term::Triple(triple) => N3Term::Triple(triple)
//   }
// }

// impl From for N3Term with from(self : N3Term, variable : Variable) -> N3Term {
//   N3Term::Variable(variable)
// }

///|
pub struct N3Quad {
  subject : N3Term
  predicate : N3Term
  object : N3Term
  graph_name : GraphName
} derive(Eq, Debug, Hash)

///|
fn N3Quad::N3Quad(
  subject : N3Term,
  predicate : N3Term,
  object : N3Term,
  graph_name : GraphName,
) -> N3Quad {
  { subject, predicate, object, graph_name }
}

// fn N3Quad::to_quad(
//   subject : N3Term,
//   predicate : N3Term,
//   object : N3Term,
//   graph_name : GraphName,
// ) -> Quad {

//   Quad::{ subject, predicate, object, graph_name }
// }

///|
///|
impl Show for N3Quad with fn output(self : N3Quad, f : &Logger) -> Unit {
  // 输出 Subject
  self.subject.output(f)
  f.write(" ")
  
  // 输出 Predicate
  self.predicate.output(f)
  f.write(" ")
  
  // 输出 Object
  self.object.output(f)
  
  // 如果 Graph Name 不是默认图，则输出 Graph Name
  if self.graph_name != GraphName::DefaultGraph {
    f.write(" ")
    self.graph_name.output(f)
  }
}

// impl From for N3Quad with from(self : N3Quad, quad : Quad) -> N3Quad {
//   { subject: quad.subject.into(), predicate: quad.predicate.into(), object: quad.object.into(), graph_name: quad.graph_name }
// }

///|
pub struct N3Parser {
  mut lenient : Bool
  mut base_iri : Iri?
  prefixes : Map[String, Iri]
} derive(Default)

///|
pub fn N3Parser::new() -> N3Parser {
  N3Parser::default()
}

///|
pub fn N3Parser::lenient(self : N3Parser) -> N3Parser {
  self.lenient = true
  self
}

///|
pub fn N3Parser::with_base_iri(
  self : N3Parser,
  base_iri : IriRef,
) -> Result[N3Parser, IriError] {
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
pub fn N3Parser::with_prefix(
  self : N3Parser,
  prefix_name : String,
  prefix_iri : IriRef,
) -> Result[N3Parser, IriError] {
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
pub fn N3Parser::for_reader(
  self : N3Parser,
  reader : &Reader,
) -> ReaderN3Parser[RdfLexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn N3Parser::for_async_reader(
  self : N3Parser,
  reader : &Reader,
) -> AsyncReaderN3Parser[RdfLexer] {
  { inner: self.low_level().parser.for_async_reader(reader) }
}

///|
pub fn N3Parser::for_slice(
  self : N3Parser,
  slice : Bytes,
) -> SliceN3Parser[N3Recognizer] {
  let parser = N3Recognizer::new_parser(
    slice.to_array(),
    false,
    self.lenient,
    self.base_iri,
    self.prefixes,
  )
  { inner: { parser, } }
}

///|
pub fn N3Parser::low_level(self : N3Parser) -> LowLevelN3Parser[RdfLexer] {
  {
    parser: N3Recognizer::new_parser(
      [],
      false,
      self.lenient,
      self.base_iri,
      self.prefixes,
    ),
  }
}

///|
pub struct ReaderN3Parser[RL] {
  inner : ReaderIterator[RL, N3Recognizer]
}

///|
pub fn[RL] ReaderN3Parser::prefixes(
  self : ReaderN3Parser[RL],
) -> N3PrefixesIter {
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
pub fn[RL] ReaderN3Parser::base_iri(self : ReaderN3Parser[RL]) -> String? {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderN3Parser[RL] {
  inner : AsyncReaderIterator[RL, N3Recognizer]
}

///|
pub async fn[RL : TokenRecognizer] AsyncReaderN3Parser::next(
  self : AsyncReaderN3Parser[RL],
) -> Result[N3Quad, TurtleError]? {
  self.inner
  .next()
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
          ).as_n3quad()
        RdfStatement::Quad(quad) => quad.as_n3quad()
        RdfStatement::N3Quad(n3quad) => n3quad
      }
    })
    .map_err(fn(e) { TurtleError::InvalidCharacter(e.message()) }) // 根据实际错误类型调整
  })
}

///|
pub fn[RL] AsyncReaderN3Parser::prefixes(
  self : AsyncReaderN3Parser[RL],
) -> N3PrefixesIter {
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
pub fn[RL] AsyncReaderN3Parser::base_iri(
  self : AsyncReaderN3Parser[RL],
) -> String? {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
pub struct SliceN3Parser[RL] {
  inner : SliceIterator[RdfLexer, RL]
}

///|
pub fn SliceN3Parser::prefixes(
  self : SliceN3Parser[RdfLexer],
) -> N3PrefixesIter {
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
pub fn SliceN3Parser::base_iri(self : SliceN3Parser[RdfLexer]) -> String? {
  match self.inner.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelN3Parser[RL] {
  parser : Parser[RL, N3Recognizer]
}

///|
pub fn[RL] LowLevelN3Parser::extend_from_slice(
  self : LowLevelN3Parser[RL],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn[RL] LowLevelN3Parser::end(self : LowLevelN3Parser[RL]) -> Unit {
  self.parser.end()
}

///|
pub fn[RL] LowLevelN3Parser::is_end(self : LowLevelN3Parser[RL]) -> Bool {
  self.parser.is_end()
}

///|
pub fn[RL : TokenRecognizer] LowLevelN3Parser::parse_next(
  self : LowLevelN3Parser[RL],
) -> Result[RdfStatement, TurtleError]? {
  self.parser.parse_next()
}

///|
pub fn[RL] LowLevelN3Parser::prefixes(
  self : LowLevelN3Parser[RL],
) -> N3PrefixesIter {
  match self.parser.context {
    RdfContext::N3RecognizerContext(ctx) => { inner: ctx.prefixes.iter() }
    _ =>
      // 假设存在一个空的 Map 或数组可以生成匹配的 Iter2[String, IriRef]
      { inner: {}.iter() }
  }
}

///|
pub fn[RL] LowLevelN3Parser::base_iri(self : LowLevelN3Parser[RL]) -> String? {
  match self.parser.context {
    RdfContext::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
enum Predicate {
  Regular(N3Term)
  Inverted(N3Term)
}

///|
pub struct N3PrefixesIter {
  inner : Iter2[String, Iri]
}
// Iterator impl converted: use .iter() method or for-in loop
