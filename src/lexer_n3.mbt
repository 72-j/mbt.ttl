///|
struct N3Recognizer {
  stack : Array[N3State]
  terms : Array[N3Term]
  predicates : Array[Predicate]
  contexts : Array[BlankNode]
  mut debug_logger : &DebugLogger
}

///|
struct N3RecognizerContext {
  lexer_options : LexerOptions
  prefixes : Map[String, Iri]
}

///|
fn N3RecognizerContext::as_ctx(self : N3RecognizerContext) -> RdfContext {
  RdfContext::N3RecognizerContext(self)
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
impl RuleRecognizer for N3Recognizer with fn[DL : DebugLogger] debug_logger(
  self : N3Recognizer,
  logger : DL,
) {
  self.debug_logger = logger
}

///|

///|
impl RuleRecognizer for N3Recognizer with fn recognize_end(
  self : N3Recognizer,
  _state : RdfContext,
  _results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> Unit {
  match self.stack {
    [] | [N3State::N3Doc] => ()
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          SourcePosition::SourcePosition(0, 0, 0),
        ),
      )
  }
}

///|
impl RuleRecognizer for N3Recognizer with fn lexer_options(context : RdfContext) -> LexerOptions? {
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
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> Parser[RdfLexer, N3Recognizer] {
  // 注意：参数 prefixes 类型已修正为 Map[String, IriRef] 以匹配 RdfContext 定义
  Parser::Parser(
    Lexer::Lexer(
      RdfLexer::RdfLexer(RdfLexerMode::N3, unchecked),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    ),
    {
      stack: [N3State::N3Doc],
      terms: [],
      predicates: [],
      contexts: [],
      debug_logger,
    },
    // 修复点：使用 RdfContext ::N3RecognizerContext 包装记录
    RdfContext::N3RecognizerContext({ lexer_options: { base_iri, }, prefixes }),
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
impl Show for N3State with fn output(self, logger : &Logger) -> Unit {
  match self {
    N3State::N3Doc => logger.write("N3 Document Start")
    N3State::N3DocExpectDot => logger.write("Expecting dot after N3 statement")
    N3State::BaseExpectIri => logger.write("Expecting IRI after BASE keyword")
    N3State::PrefixExpectPrefix =>
      logger.write("Expecting prefix name after PREFIX keyword")
    N3State::PrefixExpectIri(name~) =>
      logger.write("Expecting IRI for prefix '\{name}'")
    N3State::Triples => logger.write("Parsing Triples")
    N3State::TriplesMiddle => logger.write("Parsing Triples Middle")
    N3State::TriplesEnd => logger.write("Triples End")
    N3State::PredicateObjectList =>
      logger.write("Parsing Predicate Object List")
    N3State::PredicateObjectListEnd => logger.write("Predicate Object List End")
    N3State::PredicateObjectListPossibleContinuation =>
      logger.write("Checking Predicate Object List Continuation")
    N3State::ObjectsList => logger.write("Parsing Objects List")
    N3State::ObjectsListEnd => logger.write("Objects List End")
    N3State::Verb => logger.write("Parsing Verb")
    N3State::AfterRegularVerb => logger.write("After Regular Verb")
    N3State::AfterInvertedVerb => logger.write("After Inverted Verb")
    N3State::AfterVerbIs => logger.write("After 'is' keyword")
    N3State::Path => logger.write("Parsing Path")
    N3State::PathFollowUp => logger.write("Path Follow Up")
    N3State::PathAfterIndicator(is_inverse~) => {
      let desc = if is_inverse { "inverse" } else { "regular" }
      logger.write("Path After \{desc} Indicator")
    }
    N3State::PathItem => logger.write("Parsing Path Item")
    N3State::PropertyListMiddle =>
      logger.write("Parsing Property List Middle (Blank Node)")
    N3State::PropertyListEnd => logger.write("Property List End")
    N3State::IriPropertyList =>
      logger.write("Parsing IRI Property List ([ id ... ])")
    N3State::CollectionBeginning => logger.write("Collection Beginning")
    N3State::CollectionPossibleEnd =>
      logger.write("Checking Collection End or Continuation")
    N3State::LiteralPossibleSuffix(value~) =>
      logger.write("Expecting literal suffix for '\{value}'")
    N3State::LiteralExpectDatatype(value~) =>
      logger.write("Expecting datatype for literal '\{value}'")
    N3State::FormulaContent => logger.write("Parsing Formula Content")
    N3State::FormulaContentExpectDot =>
      logger.write("Expecting dot in Formula Content")
  }
}
