///|
pub(all) struct NQuadsRecognizer {
  current_state : NQuadsState
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
/// 数据操作集合（可选字段模式）
pub(all) struct DataWorld {
  subjects : Array[NamedOrBlankNodeRef]
  predicates : Array[NamedNodeRef]
  objects : Array[TermRef]
  temp_literal : String?
  finalize_literal : LiteralKind?
  graph_name : NamedOrBlankNodeRef
  stack_push : Array[NQuadsState]
  emit_quad : Bool
  emit_quad_with_graph : Bool
  finalize_quoted_triple : Bool
  clear_accumulator : Bool
}

///|
pub fn DataWorld::DataWorld(
  subjects : Array[NamedOrBlankNodeRef],
  predicates : Array[NamedNodeRef],
  objects : Array[TermRef],
  temp_literal : String?,
  finalize_literal : LiteralKind?,
  graph_name : NamedOrBlankNodeRef,
  stack_push : Array[NQuadsState],
  emit_quad : Bool,
  emit_quad_with_graph : Bool,
  finalize_quoted_triple : Bool,
  clear_accumulator : Bool,
) -> DataWorld {
  DataWorld::{
    subjects,
    predicates,
    objects,
    temp_literal,
    finalize_literal,
    graph_name,
    stack_push,
    emit_quad,
    emit_quad_with_graph,
    finalize_quoted_triple,
    clear_accumulator,
  }
}

///|
pub fn DataWorld::default() -> DataWorld {
  DataWorld::DataWorld(
    Array::new(),
    Array::new(),
    Array::new(),
    None,
    None,
    NamedOrBlankNodeRef::NamedNodeRef(NamedNode::default().as_ref()),
    Array::new(),
    false,
    false,
    false,
    false,
  )
}

///|
pub(all) enum LiteralKind {
  Simple
  Lang(LanguageTag, BaseDirection)
  Typed(VarDataType, NamedNodeRef)
}

///|
pub(all) enum NQuadsState {
  // ==========================================
  // 1. 文档级 (Document Level)
  // ==========================================

  /// 初始状态。
  /// 期待遇到四元组/三元组的第一个 token（主语），或注释/空白。
  /// N-Quads 没有 @prefix/@base 等指令，直接开始解析三元组。
  Start

  // ==========================================
  // 2. 四元组核心级 (Quad Core)
  // ==========================================

  /// 期待读取主语（Subject）。
  /// 主语可以是 IRI 或 Blank Node。
  ExpectSubject
  /// 已读取主语，期待读取谓语（Predicate）。
  /// 谓语必须是 IRI。
  ExpectPredicate
  /// 已读取谓语，期待读取宾语（Object）。
  /// 宾语可以是 IRI、Blank Node 或 Literal。
  ExpectObject
  /// 已读取宾语，期待判断四元组是否包含图名。
  /// - 遇到 `.`：三元组结束，无图名（默认图）
  /// - 遇到 IRI 或 Blank Node：进入图名解析
  ExpectDotOrGraphName
  /// 已判定存在图名，期待读取图名（Graph IRI 或 Blank Node）。
  /// 图名用于标识该三元组所属的命名图。
  ExpectGraphName
  /// 已读取图名（或宾语后直接为 `.`），期待句点 `.` 结束当前四元组。
  ExpectDot

  // ==========================================
  // 3. 字面量后缀级 (Literal Suffix)
  // ==========================================

  /// 期待字面量（Literal）的后缀。
  /// 处理字符串后面的语言标签（如 @en）或数据类型标记（^^）。
  /// N-Quads 中字面量语法与 Turtle 相同。
  ExpectLiteralSuffix
  /// 遇到 `^^` 后，期待读取具体的数据类型 IRI。
  ExpectDatatype
  ExpectLineJump
} derive(Debug, Eq, Hash)

///|
// pub(all) enum NQuadsState {
//   ExpectSubject
//   ExpectPredicate
//   ExpectedObject
//   ExpectPossibleGraphOrEndOfQuotedTriple
//   ExpectDot
//   ExpectLiteralAnnotationOrGraphNameOrDot(value~ : String)
//   ExpectLiteralDatatype(value~ : String)
//   ExpectLineJump
//   RecoverToLineJump
//   AfterQuotedTriple
// } derive(Debug, Eq, Hash)

///|
impl StateWrapper for NQuadsState with fn as_state_enum(self : NQuadsState) -> RdfState {
  RdfState::NQuadsState(self)
}

///|
impl Show for NQuadsState with fn output(self, logger : &Logger) -> Unit {
  match self {
    NQuadsState::Start => logger.write("Start")
    NQuadsState::ExpectSubject => logger.write("ExpectSubject")
    NQuadsState::ExpectPredicate => logger.write("ExpectPredicate")
    NQuadsState::ExpectObject => logger.write("ExpectObject")
    NQuadsState::ExpectDotOrGraphName => logger.write("ExpectDotOrGraphName")
    NQuadsState::ExpectGraphName => logger.write("ExpectGraphName")
    NQuadsState::ExpectDot => logger.write("ExpectDot")
    NQuadsState::ExpectLiteralSuffix => logger.write("ExpectLiteralSuffix")
    NQuadsState::ExpectDatatype => logger.write("ExpectDatatype")
    NQuadsState::ExpectLineJump => logger.write("ExpectLineJump")
  }
}

///|
pub impl RuleRecognizer for NQuadsRecognizer with fn error_recovery_state(
  self : NQuadsRecognizer,
) -> NQuadsRecognizer {
  // self.stack.clear()
  // self.stack.push(NQuadsState::RecoverToLineJump)
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
  _self : NQuadsRecognizer,
  _context : RdfContext,
  _results : Array[RdfOut],
) -> Unit {
  ...
  // match self.stack {
  //   [NQuadsState::ExpectSubject | NQuadsState::ExpectLineJump] | [] => ()
  //   [NQuadsState::ExpectDot] =>
  //     self.errors.push(RuleRecognizerError::TripleMissingDot)
  //   [NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple] => {
  //     self.emit_curr_quad(results, GraphName::DefaultGraph.as_ref())
  //     self.errors.push(RuleRecognizerError::TripleMissingDot)
  //   }
  //   [NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~)] => {
  //     let literal = LiteralRef::new_simple_literal(value)
  //     self.objects.push(TermRef::LiteralRef(literal))
  //     self.emit_curr_quad(results, GraphName::DefaultGraph.as_ref())
  //     self.errors.push(RuleRecognizerError::TripleMissingDot)
  //   }
  //   _ =>
  //     self.errors.push(
  //       RuleRecognizerError::SyntaxError("Unexpected end", Range::default()),
  //     )
  // }
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
    current_state: NQuadsState::Start,
    stack: [NQuadsState::Start],
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
pub fn NQuadsRecognizer::emit_curr_quad(
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
pub fn NQuadsRecognizer::emit_current_quad(
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
