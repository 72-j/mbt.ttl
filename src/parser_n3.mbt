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
impl Show for N3Quad with fn output(self : N3Quad, f : &Logger) -> Unit {
  if self.graph_name == GraphName::DefaultGraph {
    // write(f , "{} {} {}" , self . subject , self . predicate , self . object)
    f.write_object(self)
  } else {
    f.write_object(self)
    // write(f , "{} {} {} {}" , self . subject , self . predicate , self . object , self . graph_name)
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
  self.base_iri = Some(IriRef::parse(base_iri).unwrap())
  Ok(self)
}

///|
pub fn N3Parser::with_prefix(
  self : N3Parser,
  prefix_name : String,
  prefix_iri : IriRef,
) -> Result[N3Parser, IriError] {
  self.prefixes.set(prefix_name, IriRef::parse(prefix_iri).unwrap())
  Ok(self)
}

///|
pub fn N3Parser::for_reader(
  self : N3Parser,
  reader : &Reader,
) -> ReaderN3Parser[NxLexer] {
  { inner: self.low_level().parser.for_reader(reader) }
}

///|
pub fn N3Parser::for_async_reader(
  self : N3Parser,
  reader : &Reader,
) -> AsyncReaderN3Parser[NxLexer] {
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
pub fn N3Parser::low_level(self : N3Parser) -> LowLevelN3Parser[NxLexer] {
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
pub struct ReaderN3Parser[TR] {
  inner : ReaderIterator[TR, N3Recognizer]
}

///|
pub fn[TR] ReaderN3Parser::prefixes(
  self : ReaderN3Parser[TR],
) -> N3PrefixesIter {
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
pub fn[TR] ReaderN3Parser::base_iri(self : ReaderN3Parser[TR]) -> String? {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct AsyncReaderN3Parser[TR] {
  inner : AsyncReaderIterator[TR, N3Recognizer]
}

///|
pub async fn[TR : TokenRecognizer] AsyncReaderN3Parser::next(
  self : AsyncReaderN3Parser[TR],
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
    .map_err(fn(e) { TurtleError::InvalidCharacter(e.message()) }) // 根据实际错误类型调整
  })
}

///|
pub fn[TR] AsyncReaderN3Parser::prefixes(
  self : AsyncReaderN3Parser[TR],
) -> N3PrefixesIter {
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
pub fn[TR] AsyncReaderN3Parser::base_iri(
  self : AsyncReaderN3Parser[TR],
) -> String? {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

///|
pub struct SliceN3Parser[TR] {
  inner : SliceIterator[NxLexer, TR]
}

///|
pub fn SliceN3Parser::prefixes(self : SliceN3Parser[NxLexer]) -> N3PrefixesIter {
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
pub fn SliceN3Parser::base_iri(self : SliceN3Parser[NxLexer]) -> String? {
  match self.inner.parser.context {
    Context::N3RecognizerContext(ctx) =>
      ctx.lexer_options.base_iri.map(fn(iri) { iri.to_string() })
    _ => None
  }
}

// Iterator impl converted: use .iter() method or for-in loop

///|
pub struct LowLevelN3Parser[TR] {
  parser : Parser[TR, N3Recognizer]
}

///|
pub fn[TR] LowLevelN3Parser::extend_from_slice(
  self : LowLevelN3Parser[TR],
  other : Bytes,
) -> Unit {
  self.parser.extend_from_slice(other)
}

///|
pub fn[TR] LowLevelN3Parser::end(self : LowLevelN3Parser[TR]) -> Unit {
  self.parser.end()
}

///|
pub fn[TR] LowLevelN3Parser::is_end(self : LowLevelN3Parser[TR]) -> Bool {
  self.parser.is_end()
}

///|
pub fn[TR : TokenRecognizer] LowLevelN3Parser::parse_next(
  self : LowLevelN3Parser[TR],
) -> Result[LexOutput, TurtleError]? {
  self.parser.parse_next()
}

///|
pub fn[TR] LowLevelN3Parser::prefixes(
  self : LowLevelN3Parser[TR],
) -> N3PrefixesIter {
  match self.parser.context {
    Context::N3RecognizerContext(ctx) => { inner: ctx.prefixes.iter() }
    _ =>
      // 假设存在一个空的 Map 或数组可以生成匹配的 Iter2[String, IriRef]
      { inner: {}.iter() }
  }
}

///|
pub fn[TR] LowLevelN3Parser::base_iri(self : LowLevelN3Parser[TR]) -> String? {
  match self.parser.context {
    Context::N3RecognizerContext(ctx) =>
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
struct N3Recognizer {
  stack : Array[N3State]
  terms : Array[N3Term]
  predicates : Array[Predicate]
  contexts : Array[BlankNode]
}

///|
struct N3RecognizerContext {
  lexer_options : LexerOptions
  prefixes : Map[String, Iri]
}

///|
impl RuleRecognizer for N3Recognizer with fn error_recovery_state(
  self : N3Recognizer,
) -> N3Recognizer {
  self.stack.clear()
  self.terms.clear()
  self.predicates.clear()
  self.contexts.clear()
  self
}

///|
impl RuleRecognizer for N3Recognizer with fn recognize_next(
  self : N3Recognizer,
  token : TokenOrLineJump[N3Token],
  context : Context,
  results : Array[LexOutput],
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
  while true {
    // let TokenOrLineJump::Token(token) = token

    match self.stack.pop() {
      Some(rule) =>
        match rule {
          N3State::N3Doc => {
            self.stack.push(N3State::N3Doc)
            match token {
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "base",
                ) => {
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "prefix",
                ) => {
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="prefix", direction=None)
              ) => {
                self.stack.push(N3State::N3DocExpectDot)
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="base", direction=None)
              ) => {
                self.stack.push(N3State::N3DocExpectDot)
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              _ => {
                self.stack.push(N3State::N3DocExpectDot)
                self.stack.push(N3State::Triples)
              }
            }
          }
          N3State::N3DocExpectDot => {
            if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) {
              return self
            }
            errors.push(
              RuleRecognizerError::SyntaxError(
                "A dot is expected at the end of N3 statements",
                TextPosition::default(),
              ),
            )
          }
          N3State::BaseExpectIri =>
            if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
              match context {
                Context::N3RecognizerContext(ctx) =>
                  ctx.lexer_options.base_iri = Some(Iri::Iri(iri))
                _ => ()
              }
              // context.lexer_options.base_iri = Some(Iri::Iri(iri))
              return self
            } else {
              return self.error(
                errors,
                RuleRecognizerError::SyntaxError(
                  "The BASE keyword should be followed by an IRI",
                  TextPosition::default(),
                ),
              )
            }
          N3State::PrefixExpectPrefix =>
            return match token {
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, ..)
              ) if localx.is_empty() => {
                self.stack.push(N3State::PrefixExpectIri(name=prefix))
                self
              }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "The PREFIX keyword should be followed by a prefix like 'ex:'",
                    TextPosition::default(),
                  ),
                )
            }
          N3State::PrefixExpectIri(name~) =>
            return if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
              match context {
                Context::N3RecognizerContext(ctx) =>
                  ctx.prefixes.set(name, Iri::Iri(iri))
                _ => ()
              }
              self
            } else {
              self.error(
                errors,
                RuleRecognizerError::SyntaxError(
                  "The PREFIX declaration should be followed by a prefix and its value as an IRI",
                  TextPosition::default(),
                ),
              )
            }
          N3State::Triples => {
            self.stack.push(N3State::TriplesMiddle)
            self.stack.push(N3State::Path)
          }
          N3State::TriplesMiddle =>
            if token
              is TokenOrLineJump::Token(
                N3Token::Punctuation("." | "]" | "}" | ")")
              ) {

            } else {
              self.stack.push(N3State::TriplesEnd)
              self.stack.push(N3State::PredicateObjectList)
            }
          N3State::TriplesEnd => {
            let _ = self.terms.pop()
          }
          N3State::PredicateObjectList => {
            self.stack.push(N3State::PredicateObjectListEnd)
            self.stack.push(N3State::ObjectsList)
            self.stack.push(N3State::Verb)
          }
          N3State::PredicateObjectListEnd => {
            let _ = self.predicates.pop()
            if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
              self.stack.push(N3State::PredicateObjectListPossibleContinuation)
              return self
            }
          }
          N3State::PredicateObjectListPossibleContinuation =>
            if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
              self.stack.push(N3State::PredicateObjectListPossibleContinuation)
              return self
            } else if token
              is TokenOrLineJump::Token(
                N3Token::Punctuation(";" | "." | "}" | "]" | ")")
              ) {

            } else {
              self.stack.push(N3State::PredicateObjectListEnd)
              self.stack.push(N3State::ObjectsList)
              self.stack.push(N3State::Verb)
            }
          N3State::ObjectsList => {
            self.stack.push(N3State::ObjectsListEnd)
            self.stack.push(N3State::Path)
          }
          N3State::ObjectsListEnd => {
            let object = self.terms.pop().unwrap()
            let subject = self.terms.last().unwrap()
            results.push(
              match self.predicates.last().unwrap() {
                Predicate::Regular(predicate) =>
                  LexOutput::N3Quad(self.quad(subject, predicate, object))
                Predicate::Inverted(predicate) =>
                  LexOutput::N3Quad(self.quad(object, predicate, subject))
              },
            )
            if token == TokenOrLineJump::Token(N3Token::Punctuation(",")) {
              self.stack.push(N3State::ObjectsListEnd)
              self.stack.push(N3State::Path)
              return self
            }
          }
          N3State::Verb =>
            match token {
              TokenOrLineJump::Token(N3Token::PlainKeyword("a")) => {
                self.predicates.push(Predicate::Regular(lwTYPE.as_n3term()))
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("has")) => {
                self.stack.push(N3State::AfterRegularVerb)
                self.stack.push(N3State::Path)
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("is")) => {
                self.stack.push(N3State::AfterVerbIs)
                self.stack.push(N3State::Path)
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("=")) => {
                self.predicates.push(
                  Predicate::Regular(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2002/07/owl#sameAs",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("=>")) => {
                self.predicates.push(
                  Predicate::Regular(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2000/10/swap/log#implies",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("<=")) => {
                self.predicates.push(
                  Predicate::Inverted(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2000/10/swap/log#implies",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("<-")) => {
                self.stack.push(N3State::AfterInvertedVerb)
                self.stack.push(N3State::Path)
                return self
              }
              _ => {
                self.stack.push(N3State::AfterRegularVerb)
                self.stack.push(N3State::Path)
              }
            }
          N3State::AfterRegularVerb =>
            self.predicates.push(Predicate::Regular(self.terms.pop().unwrap()))
          N3State::AfterInvertedVerb =>
            self.predicates.push(Predicate::Inverted(self.terms.pop().unwrap()))
          N3State::AfterVerbIs =>
            return match token {
              TokenOrLineJump::Token(N3Token::PlainKeyword("of")) => {
                self.predicates.push(
                  Predicate::Inverted(self.terms.pop().unwrap()),
                )
                self
              }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "The keyword 'is' should be followed by a predicate then by the keyword 'of'",
                    TextPosition::default(),
                  ),
                )
            }
          N3State::Path => {
            self.stack.push(N3State::PathFollowUp)
            self.stack.push(N3State::PathItem)
          }
          N3State::PathFollowUp =>
            match token {
              TokenOrLineJump::Token(N3Token::Punctuation("!")) => {
                self.stack.push(N3State::PathAfterIndicator(is_inverse=false))
                self.stack.push(N3State::PathItem)
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("^")) => {
                self.stack.push(N3State::PathAfterIndicator(is_inverse=false))
                self.stack.push(N3State::PathItem)
                return self
              }
              _ => ()
            }
          N3State::PathAfterIndicator(is_inverse~) => {
            let predicate = self.terms.pop().unwrap()
            let previous = self.terms.pop().unwrap()
            let current = BlankNode::default().as_n3term()
            results.push(
              if is_inverse {
                LexOutput::N3Quad(self.quad(current, predicate, previous))
              } else {
                LexOutput::N3Quad(self.quad(previous, predicate, current))
              },
            )
            self.terms.push(current)
            self.stack.push(N3State::PathFollowUp)
          }
          N3State::PathItem =>
            return match token {
              TokenOrLineJump::Token(N3Token::Iri(iri)) => {
                self.terms.push(NamedNodeRef::new_unchecked(iri).as_n3term())
                self
              }
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
              ) =>
                match context {
                  Context::N3RecognizerContext(ctx) =>
                    match
                      resolve_local_name(
                        prefix,
                        localx,
                        might_be_invalid_iri,
                        ctx.prefixes,
                      ) {
                      Ok(t) => {
                        self.terms.push(t.as_n3term())
                        self
                      }
                      Err(e) =>
                        return self.error(
                          errors,
                          RuleRecognizerError::SyntaxError(
                            e,
                            TextPosition::default(),
                          ),
                        )
                    }
                  _ =>
                    self.error(
                      errors,
                      RuleRecognizerError::SyntaxError(
                        "Invalid context for prefix resolution",
                        TextPosition::default(),
                      ),
                    )
                }
              TokenOrLineJump::Token(N3Token::BlankNodeLabel(bnode)) => {
                self.terms.push(BlankNodeRef::new_unchecked(bnode).as_n3term())
                self
              }
              TokenOrLineJump::Token(N3Token::Variable(name)) => {
                self.terms.push(N3Term::Variable(name))
                self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
                self.stack.push(N3State::PropertyListMiddle)
                self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
                self.stack.push(N3State::CollectionBeginning)
                self
              }
              TokenOrLineJump::Token(N3Token::String(value))
              | TokenOrLineJump::Token(N3Token::LongString(value)) => {
                self.stack.push(N3State::LiteralPossibleSuffix(value~))
                self
              }
              TokenOrLineJump::Token(N3Token::Integer(v)) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar(v),
                    lwINTEGER,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::Decimal(v)) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar(v),
                    lwDECIMAL,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::Double(v)) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar(v),
                    lwDOUBLE,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar("true"),
                    lwBOOLEAN,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar("false"),
                    lwBOOLEAN,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("{")) => {
                self.contexts.push(BlankNode::default())
                self.stack.push(N3State::FormulaContent)
                self
              }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "TOKEN is not a valid RDF value",
                    TextPosition::default(),
                  ),
                )
            }
          N3State::PropertyListMiddle =>
            match token {
              TokenOrLineJump::Token(N3Token::Punctuation("]")) => {
                self.terms.push(BlankNode::default().as_n3term())
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("id")) => {
                self.stack.push(N3State::IriPropertyList)
                return self
              }
              _ => {
                self.terms.push(BlankNode::default().as_n3term())
                self.stack.push(N3State::PropertyListEnd)
                self.stack.push(N3State::PredicateObjectList)
              }
            }
          N3State::PropertyListEnd =>
            if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
              return self
            } else {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "blank node property lists should end with a ']'",
                  TextPosition::default(),
                ),
              )
            }
          N3State::IriPropertyList =>
            return match token {
              TokenOrLineJump::Token(N3Token::Iri(id)) => {
                self.terms.push(NamedNodeRef::new_unchecked(id).as_n3term())
                self.stack.push(N3State::PropertyListEnd)
                self.stack.push(N3State::PredicateObjectList)
                self
              }
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
              ) =>
                match context {
                  Context::N3RecognizerContext(ctx) =>
                    match
                      resolve_local_name(
                        prefix,
                        localx,
                        might_be_invalid_iri,
                        ctx.prefixes,
                      ) {
                      Ok(t) => {
                        self.terms.push(t.as_n3term())
                        self
                      }
                      Err(e) =>
                        self.error(
                          errors,
                          RuleRecognizerError::SyntaxError(
                            e,
                            TextPosition::default(),
                          ),
                        )
                    }
                  _ =>
                    return self.error(
                      errors,
                      RuleRecognizerError::SyntaxError(
                        "Invalid context for prefix resolution",
                        TextPosition::default(),
                      ),
                    )
                }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "The '[ id' construction should be followed by an IRI",
                    TextPosition::default(),
                  ),
                )
            }
          N3State::CollectionBeginning =>
            if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
              self.terms.push(lwNIL.as_n3term())
              return self
            } else {
              let root = BlankNode::default()
              self.terms.push(root.as_n3term())
              self.terms.push(root.as_n3term())
              self.stack.push(N3State::CollectionPossibleEnd)
              self.stack.push(N3State::Path)
            }
          N3State::CollectionPossibleEnd => {
            let value = self.terms.pop().unwrap()
            let old = self.terms.pop().unwrap()
            results.push(
              LexOutput::N3Quad(self.quad(old, lwFIRST.as_n3term(), value)),
            )
            if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
              results.push(
                LexOutput::N3Quad(
                  self.quad(old, lwREST.as_n3term(), lwNIL.as_n3term()),
                ),
              )
              return self
            }
            let new = BlankNode::default()
            results.push(
              LexOutput::N3Quad(
                self.quad(old, lwREST.as_n3term(), new.as_n3term()),
              ),
            )
            self.terms.push(new.as_n3term())
            self.stack.push(N3State::CollectionPossibleEnd)
            self.stack.push(N3State::Path)
          }
          N3State::LiteralPossibleSuffix(value~) =>
            match token {
              TokenOrLineJump::Token(N3Token::LangTag(language~, direction~)) => {
                if direction is Some(_) {
                  return self.error(
                    errors,
                    RuleRecognizerError::SyntaxError(
                      "rdf:dirLangString is not supported in N3",
                      TextPosition::default(),
                    ),
                  )
                }
                self.terms.push(
                  Literal::new_language_tagged_literal_unchecked(
                    value,
                    language.to_lower(),
                  ).as_n3term(),
                )
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("^^")) => {
                self.stack.push(N3State::LiteralExpectDatatype(value~))
                return self
              }
              _ =>
                self.terms.push(Literal::new_simple_literal(value).as_n3term())
            }
          N3State::LiteralExpectDatatype(value~) =>
            match token {
              TokenOrLineJump::Token(N3Token::Iri(datatype)) => {
                let datatype = NamedNodeRef::new_unchecked(datatype)
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    datatype.into_datatype(value),
                    datatype,
                  ).as_n3term(),
                )
                return self
              }
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
              ) =>
                match context {
                  Context::N3RecognizerContext(ctx) =>
                    match
                      resolve_local_name(
                        prefix,
                        localx,
                        might_be_invalid_iri,
                        ctx.prefixes,
                      ) {
                      Ok(datatype) => {
                        self.terms.push(
                          LiteralRef::new_typed_literal(
                            datatype.into_datatype(value),
                            datatype,
                          ).as_n3term(),
                        )
                        return self
                      }
                      Err(e) =>
                        return self.error(
                          errors,
                          RuleRecognizerError::SyntaxError(
                            e,
                            TextPosition::default(),
                          ),
                        )
                    }
                  _ =>
                    return self.error(
                      errors,
                      RuleRecognizerError::SyntaxError(
                        "Invalid context for prefix resolution",
                        TextPosition::default(),
                      ),
                    )
                }
              _ =>
                return self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "Unexpected token in formula content",
                    TextPosition::default(),
                  ),
                )
            }
          N3State::FormulaContent =>
            match token {
              TokenOrLineJump::Token(N3Token::Punctuation("}")) => {
                self.terms.push(self.contexts.pop().unwrap().as_n3term())
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "base",
                ) => {
                self.stack.push(N3State::FormulaContent)
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "prefix",
                ) => {
                self.stack.push(N3State::FormulaContent)
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="prefix", direction=None)
              ) => {
                self.stack.push(N3State::FormulaContentExpectDot)
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="base", direction=None)
              ) => {
                self.stack.push(N3State::FormulaContentExpectDot)
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              _ => {
                self.stack.push(N3State::FormulaContentExpectDot)
                self.stack.push(N3State::Triples)
              }
            }
          N3State::FormulaContentExpectDot =>
            match token {
              TokenOrLineJump::Token(N3Token::Punctuation("}")) => {
                self.terms.push(self.contexts.pop().unwrap().as_n3term())
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation(".")) => {
                self.stack.push(N3State::FormulaContent)
                return self
              }
              _ => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "A dot is expected at the end of N3 statements",
                    TextPosition::default(),
                  ),
                )
                self.stack.push(N3State::FormulaContent)
              }
            }
        }
      _ => break
    }
  }
  if token == TokenOrLineJump::Token(Punctuation(".")) {
    self.stack.push(N3State::N3Doc)
    self
  } else {
    self
  }
}

///|
impl RuleRecognizer for N3Recognizer with fn recognize_end(
  self : N3Recognizer,
  _state : Context,
  _results : Array[LexOutput],
  errors : Array[RuleRecognizerError],
) -> Unit {
  match self.stack {
    [] | [N3State::N3Doc] => ()
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          TextPosition::TextPosition(0, 0, 0),
        ),
      )
  }
}

///|
impl RuleRecognizer for N3Recognizer with fn lexer_options(context : Context) -> LexerOptions? {
  // context.lexer_options
  match context {
    N3RecognizerContext(context) => Some(context.lexer_options)
    _ => None
  }
}

///|
pub fn N3Recognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  unchecked : Bool,
  base_iri : Iri?,
  prefixes : Map[String, Iri],
) -> Parser[NxLexer, N3Recognizer] {
  // 注意：参数 prefixes 类型已修正为 Map[String, IriRef] 以匹配 Context 定义
  Parser::Parser(
    Lexer::Lexer(
      NxLexer::NxLexer(NxLexerMode::N3, unchecked),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
    ),
    { stack: [N3State::N3Doc], terms: [], predicates: [], contexts: [] },
    // 修复点：使用 Context::N3RecognizerContext 包装记录
    Context::N3RecognizerContext({ lexer_options: { base_iri, }, prefixes }),
  )
}

///|
fn N3Recognizer::error(
  self : N3Recognizer,
  errors : Array[RuleRecognizerError],
  msg : RuleRecognizerError,
) -> N3Recognizer {
  errors.push(msg)
  self.stack.clear()
  self
}

///|
fn N3Recognizer::quad(
  self : N3Recognizer,
  subject : N3Term,
  predicate : N3Term,
  object : N3Term,
) -> N3Quad {
  {
    subject,
    predicate,
    object,
    graph_name: self.contexts
    .last()
    .map_or(GraphName::DefaultGraph, fn(g) { GraphName::BlankNode(g) }),
  }
}

///|
enum N3State {
  N3Doc
  N3DocExpectDot
  BaseExpectIri
  PrefixExpectPrefix
  PrefixExpectIri(name~ : String)
  Triples
  TriplesMiddle
  TriplesEnd
  PredicateObjectList
  PredicateObjectListEnd
  PredicateObjectListPossibleContinuation
  ObjectsList
  ObjectsListEnd
  Verb
  AfterRegularVerb
  AfterInvertedVerb
  AfterVerbIs
  Path
  PathFollowUp
  PathAfterIndicator(is_inverse~ : Bool)
  PathItem
  PropertyListMiddle
  PropertyListEnd
  IriPropertyList
  CollectionBeginning
  CollectionPossibleEnd
  LiteralPossibleSuffix(value~ : String)
  LiteralExpectDatatype(value~ : String)
  FormulaContent
  FormulaContentExpectDot
} derive(Debug)

///|
pub struct N3PrefixesIter {
  inner : Iter2[String, Iri]
}
// Iterator impl converted: use .iter() method or for-in loop
