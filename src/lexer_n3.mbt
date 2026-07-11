///|
struct N3Recognizer {
  stack : Array[N3State]
  terms : Array[N3Term]
  predicates : Array[Predicate]
  contexts : Array[BlankNode]
  mut debug_logger : &DebugLogger
  last_range : Range
  errors : Array[RuleRecognizerError]
}

///|
struct N3RecognizerContext {
  lexer_options : LexerOptions
  prefixes : Map[String, Iri]
}

///|
pub fn N3RecognizerContext::as_ctx(self : N3RecognizerContext) -> RdfContext {
  RdfContext::N3RecognizerContext(self)
}

///|
pub impl RuleRecognizer for N3Recognizer with fn error_recovery_state(
  self : N3Recognizer,
) -> N3Recognizer {
  self.stack.clear()
  self.terms.clear()
  self.predicates.clear()
  self.contexts.clear()
  self
}

///|
pub impl RuleRecognizer for N3Recognizer with fn[DL : DebugLogger] debug_logger(
  self : N3Recognizer,
  logger : DL,
) {
  self.debug_logger = logger
}

///|
pub impl RuleRecognizer for N3Recognizer with fn recognize_end(
  self : N3Recognizer,
  _state : RdfContext,
  _results : Array[RdfOut],
) -> Unit {
  match self.stack {
    [] | [N3State::N3Doc] => ()
    _ =>
      self.errors.push(
        RuleRecognizerError::SyntaxError("Unexpected end", Range::default()),
      )
  }
}

///|
pub impl RuleRecognizer for N3Recognizer with fn lexer_options(
  context : RdfContext,
) -> LexerOptions? {
  match context {
    N3RecognizerContext(context) => Some(context.lexer_options)
    _ => None
  }
}

///|
pub fn N3Recognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  base_iri : Iri?,
  prefixes : Map[String, Iri],
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> Parser[RdfLexer, N3Recognizer] {
  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::Turtle, false),
    data,
    is_ending,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )
  let machine = N3Recognizer::{
    stack: [N3State::N3Doc],
    terms: [],
    predicates: [],
    contexts: [],
    debug_logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
    // in_collection: false,
    last_range: Range::default(),
    errors: [],
  }

  let context = RdfContext::N3RecognizerContext(N3RecognizerContext::{
    lexer_options: { base_iri, },
    prefixes,
  })

  let machine = GenericStateMachine::{
    machine,
    context,
    outputs: [],
    debug_logger,
  }

  let parser = Parser::Parser(lexer, machine, context)
  parser
}

///|
// fn N3Recognizer::error(self : N3Recognizer, msg : String) -> N3Recognizer {
//   self.errors.push(RuleRecognizerError::SyntaxError(msg, self.last_range))
//   self.stack.clear()

//   self
// }

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
} derive(Debug, Eq, Hash)

///|
impl StateWrapper for N3State with fn as_state_enum(self : N3State) -> RdfState {
  RdfState::N3State(self)
}

///|
impl Show for N3State with fn output(self, logger : &Logger) -> Unit {
  match self {
    N3State::N3Doc => logger.write("N3Doc")
    N3State::N3DocExpectDot => logger.write("N3DocExpectDot")
    N3State::BaseExpectIri => logger.write("BaseExpectIri")
    N3State::PrefixExpectPrefix => logger.write("PrefixExpectPrefix")
    N3State::PrefixExpectIri(name~) => logger.write("PrefixExpectIri(\{name})")
    N3State::Triples => logger.write("Triples")
    N3State::TriplesMiddle => logger.write("TriplesMiddle")
    N3State::TriplesEnd => logger.write("TriplesEnd")
    N3State::PredicateObjectList => logger.write("PredicateObjectList")
    N3State::PredicateObjectListEnd => logger.write("PredicateObjectListEnd")
    N3State::PredicateObjectListPossibleContinuation =>
      logger.write("PredicateObjectListPossibleContinuation")
    N3State::ObjectsList => logger.write("ObjectsList")
    N3State::ObjectsListEnd => logger.write("ObjectsListEnd")
    N3State::Verb => logger.write("Verb")
    N3State::AfterRegularVerb => logger.write("AfterRegularVerb")
    N3State::AfterInvertedVerb => logger.write("AfterInvertedVerb")
    N3State::AfterVerbIs => logger.write("AfterVerbIs")
    N3State::Path => logger.write("Path")
    N3State::PathFollowUp => logger.write("PathFollowUp")
    N3State::PathAfterIndicator(is_inverse~) => {
      let desc = if is_inverse { "inverse" } else { "regular" }
      logger.write("Path After \{desc} Indicator")
    }
    N3State::PathItem => logger.write("PathItem")
    N3State::PropertyListMiddle => logger.write("PropertyListMiddle")
    N3State::PropertyListEnd => logger.write("PropertyListEnd")
    N3State::IriPropertyList => logger.write("IriPropertyList")
    N3State::CollectionBeginning => logger.write("CollectionBeginning")
    N3State::CollectionPossibleEnd => logger.write("CollectionPossibleEnd")
    N3State::LiteralPossibleSuffix(value~) =>
      logger.write("LiteralPossibleSuffix(\{value})")
    N3State::LiteralExpectDatatype(value~) =>
      logger.write("LiteralExpectDatatype(\{value})")
    N3State::FormulaContent => logger.write("FormulaContent")
    N3State::FormulaContentExpectDot => logger.write("FormulaContentExpectDot")
  }
}
