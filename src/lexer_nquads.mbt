///|
pub struct NQuadsRecognizer {
  stack : Array[NQuadsState]
  subjects : Array[NamedOrBlankNodeRef]
  predicates : Array[NamedNodeRef]
  objects : Array[TermRef]
  lenient : Bool
  mut debug_logger : &DebugLogger
}

///|
pub struct NQuadsRecognizerContext {
  with_graph_name : Bool
  lexer_options : LexerOptions?
}

///|
enum NQuadsState {
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
}

///|
impl Show for NQuadsState with fn output(self, logger : &Logger) -> Unit {
  match self {
    NQuadsState::ExpectSubject => logger.write("Expecting subject")
    NQuadsState::ExpectPredicate => logger.write("Expecting predicate")
    NQuadsState::ExpectedObject => logger.write("Expecting object")
    NQuadsState::ExpectDot => logger.write("Expecting dot")
    NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~) =>
      logger.write("Expecting literal annotation \{value} ")
    NQuadsState::ExpectLiteralDatatype(value~) =>
      logger.write("Expecting literal datatype \{value}")
    NQuadsState::ExpectLineJump => logger.write("Expecting line jump")
    NQuadsState::RecoverToLineJump => logger.write("Recovering to line jump")
    NQuadsState::AfterQuotedTriple => logger.write("After quoted triple")
    NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple =>
      logger.write("Expecting possible graph or end of quoted triple")
  }
}

///|
impl RuleRecognizer for NQuadsRecognizer with fn error_recovery_state(
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
impl RuleRecognizer for NQuadsRecognizer with fn[DL : DebugLogger] debug_logger(
  self : NQuadsRecognizer,
  debug_logger : DL,
) {
  self.debug_logger = debug_logger
}



///|
impl RuleRecognizer for NQuadsRecognizer with fn recognize_end(
  self : NQuadsRecognizer,
  _context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> Unit {
  match self.stack {
    [NQuadsState::ExpectSubject | NQuadsState::ExpectLineJump] | [] => ()
    [NQuadsState::ExpectDot] =>
      errors.push(RuleRecognizerError::TripleMissingDot)
    [NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple] => {
      self.emit_quad(results, errors, GraphName::DefaultGraph.as_ref())
      errors.push(RuleRecognizerError::TripleMissingDot)
    }
    [NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~)] => {
      let literal = LiteralRef::new_simple_literal(value)
      self.objects.push(TermRef::LiteralRef(literal))
      self.emit_quad(results, errors, GraphName::DefaultGraph.as_ref())
      errors.push(RuleRecognizerError::TripleMissingDot)
    }
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          Range::default(),
        ),
      )
  }
}

///|
impl RuleRecognizer for NQuadsRecognizer with fn lexer_options(
  context : RdfContext,
) -> LexerOptions? {
  match context {
    RdfContext::NQuadsRecognizerContext(ctx) => ctx.lexer_options
    _ => None // 或者 panic!("Unexpected context type")
  }
}

///|
pub fn NQuadsRecognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  with_graph_name : Bool,
  lenient : Bool,
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> Parser[RdfLexer, NQuadsRecognizer] {
  let initial_context = NQuadsRecognizerContext::{
    with_graph_name,
    lexer_options: None,
  }

  Parser::Parser(
    Lexer::Lexer(
      RdfLexer::RdfLexer(RdfLexerMode::NTriples, lenient),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    ),
    {
      stack: [NQuadsState::ExpectSubject],
      subjects: [],
      predicates: [],
      objects: [],
      lenient,
      debug_logger, // 修复：包装为 Option 类型
    },
    RdfContext::NQuadsRecognizerContext(initial_context),
  )
}

///|
fn NQuadsRecognizer::error(
  self : NQuadsRecognizer,
  context : NQuadsRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
  token : LocatedTokenOrLineJump,
  msg : RuleRecognizerError,
) -> NQuadsRecognizer {

  errors.push(msg)
  let this = self.error_recovery_state()
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(_) => this
    LocatedTokenOrLineJump::LineJump(_) =>
      this.recognize_next(
        token,
        RdfContext::NQuadsRecognizerContext(context),
        results,
        errors,
      )
    LocatedTokenOrLineJump::End => this
  }
}

///|
fn NQuadsRecognizer::emit_quad(
  self : NQuadsRecognizer,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
  graph_name : GraphNameRef,
) -> Unit {
  let subject_opt = self.subjects.pop()
  let predicate_opt = self.predicates.pop()
  let object_opt = self.objects.pop()

  match (subject_opt, predicate_opt, object_opt) {
    (Some(subject), Some(predicate), Some(object)) =>
      results.push(
        RdfStatement::Quad({
          subject: subject.into_owned(),
          predicate: predicate.into_owned(),
          object: object.into_owned(),
          graph_name: graph_name.into_owned(),
        }),
      )
    _ =>
      // 栈中元素不足，记录内部错误
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Internal error: incomplete quad on stack during emission",
          Range::default(),
        ),
      )
    // 可以选择在此处调用 self.error_recovery_state()，但这会改变 self
    // 通常 emit_quad 不应改变 self 的状态除了 pop，所以仅记录错误
  }
}
