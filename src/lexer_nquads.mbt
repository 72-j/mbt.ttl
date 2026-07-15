///|
pub(all) struct NQuadsRecognizer {
  stack : Array[NQuadsState]
  subjects : Array[NamedOrBlankNodeRef]
  predicates : Array[NamedNodeRef]
  objects : Array[TermRef]
  lenient : Bool
  mut debug_logger : &DebugLogger
  mut last_range : Range
  errors : Array[RuleRecognizerError]
}

///|
pub(all) struct NQuadsRecognizerContext {
  with_graph_name : Bool
  lexer_options : LexerOptions
}

///|
pub(all) enum NQuadsState {
  ExpectSubject
  ExpectPredicate
  ExpectedObject
  ExpectPossibleGraphOrEndOfQuotedTriple
  ExpectDot
  ExpectLiteralAnnotationOrGraphNameOrDot(value~ : String)
  ExpectLiteralDatatype(value~ : String)
  ExpectLineJump
  RecoverToLineJump
  AfterQuotedTriple
} derive(Debug, Eq, Hash)

///|
impl StateWrapper for NQuadsState with fn as_state_enum(self : NQuadsState) -> RdfState {
  RdfState::NQuadsState(self)
}

///|
impl Show for NQuadsState with fn output(self, logger : &Logger) -> Unit {
  match self {
    NQuadsState::ExpectSubject => logger.write("ExpectSubject")
    NQuadsState::ExpectPredicate => logger.write("ExpectPredicate")
    NQuadsState::ExpectedObject => logger.write("ExpectedObject")
    NQuadsState::ExpectDot => logger.write("ExpectDot")
    NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~) =>
      logger.write("ExpectLiteralAnnotationOrGraphNameOrDot(\{value})")
    NQuadsState::ExpectLiteralDatatype(value~) =>
      logger.write("ExpectLiteralDatatype(\{value})")
    NQuadsState::ExpectLineJump => logger.write("ExpectLineJump")
    NQuadsState::RecoverToLineJump => logger.write("RecoverToLineJump")
    NQuadsState::AfterQuotedTriple => logger.write("AfterQuotedTriple")
    NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple =>
      logger.write("ExpectPossibleGraphOrEndOfQuotedTriple")
  }
}

///|
pub impl RuleRecognizer for NQuadsRecognizer with fn error_recovery_state(
  self : NQuadsRecognizer,
) -> NQuadsRecognizer {
  self.stack.clear()
  self.stack.push(NQuadsState::RecoverToLineJump)
  self.subjects.clear()
  self.predicates.clear()
  self.objects.clear()
  self
}

///|
pub impl RuleRecognizer for NQuadsRecognizer with fn[DL : DebugLogger] debug_logger(
  self : NQuadsRecognizer,
  debug_logger : DL,
) {
  self.debug_logger = debug_logger
}

///|
pub impl RuleRecognizer for NQuadsRecognizer with fn recognize_end(
  self : NQuadsRecognizer,
  _context : RdfContext,
  results : Array[RdfOut],
) -> Unit {
  match self.stack {
    [NQuadsState::ExpectSubject | NQuadsState::ExpectLineJump] | [] => ()
    [NQuadsState::ExpectDot] =>
      self.errors.push(RuleRecognizerError::TripleMissingDot)
    [NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple] => {
      self.emit_curr_quad(results, GraphName::DefaultGraph.as_ref())
      self.errors.push(RuleRecognizerError::TripleMissingDot)
    }
    [NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~)] => {
      let literal = LiteralRef::new_simple_literal(value)
      self.objects.push(TermRef::LiteralRef(literal))
      self.emit_curr_quad(results, GraphName::DefaultGraph.as_ref())
      self.errors.push(RuleRecognizerError::TripleMissingDot)
    }
    _ =>
      self.errors.push(
        RuleRecognizerError::SyntaxError("Unexpected end", Range::default()),
      )
  }
}

///|
pub impl RuleRecognizer for NQuadsRecognizer with fn lexer_options(
  context : RdfContext,
) -> LexerOptions? {
  match context {
    RdfContext::NQuadsRecognizerContext(ctx) => Some(ctx.lexer_options)
    _ => None
  }
}

///|
pub fn NQuadsRecognizer::new_parser(
  data : Array[Byte],
  with_graph_name : Bool,
  lenient : Bool,
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> Parser[RdfLexer, NQuadsRecognizer] {
  let initial_context = NQuadsRecognizerContext::{
    with_graph_name,
    lexer_options: { base_iri: None },
  }
  let lexer = Lexer::Lexer(
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, lenient),
    data,
    true,
    MIN_BUFFER_SIZE,
    MAX_BUFFER_SIZE,
    Some(b"#"),
    0,
    0,
  )

  let machine = NQuadsRecognizer::{
    stack: [NQuadsState::ExpectSubject],
    subjects: [],
    predicates: [],
    objects: [],
    lenient,
    debug_logger, // 修复：包装为 Option 类型
    last_range: Range::default(),
    errors: [],
  }
  let context = RdfContext::NQuadsRecognizerContext(initial_context)
  let generic_machine = GenericStateMachine::{
    machine,
    context,
    outputs: [],
    debug_logger,
  }
  Parser::{ lexer, engine: generic_machine, context, errors: [] }
  // Parser::Parser(lexer, machine, context)
}

///|
fn NQuadsRecognizer::emit_curr_quad(
  self : NQuadsRecognizer,
  results : Array[RdfOut],
  graph_name : GraphNameRef,
) -> Unit {
  let subject_opt = self.subjects.pop()
  let predicate_opt = self.predicates.pop()
  let object_opt = self.objects.pop()

  match (subject_opt, predicate_opt, object_opt) {
    (Some(subject), Some(predicate), Some(object)) =>
      results.push(
        RdfOut::Quad({
          subject: subject.into_owned(),
          predicate: predicate.into_owned(),
          object: object.into_owned(),
          graph_name: graph_name.into_owned(),
        }),
      )
    _ =>
      // 栈中元素不足，记录内部错误
      self.errors.push(
        RuleRecognizerError::SyntaxError(
          "Internal error: incomplete quad on stack during emission",
          Range::default(),
        ),
      )
    // 可以选择在此处调用 self.error_recovery_state()，但这会改变 self
  }
}

///|
fn NQuadsRecognizer::emit_current_quad(
  self : NQuadsRecognizer,
  graph_name? : GraphName,
) -> RdfOut? {
  self.debug_logger.info("emit_current_quad called")
  self.debug_logger.info("  subjects length: \{self.subjects.length()}")
  self.debug_logger.info("  predicates length: \{self.predicates.length()}")
  self.debug_logger.info("  objects length: \{self.objects.length()}")

  let subject = self.subjects.pop()
  let predicate = self.predicates.pop()
  let object = self.objects.pop()

  match (subject, predicate, object) {
    (Some(s), Some(p), Some(o)) => {
      let graph_name = graph_name.unwrap_or(GraphName::DefaultGraph)
      Some(
        RdfOut::Quad(
          Quad::Quad(s.into_owned(), p.into_owned(), o.into_owned(), graph_name),
        ),
      )
    }
    _ => {
      self.debug_logger.info("ERROR: missing data!")
      None
    }
  }
}
