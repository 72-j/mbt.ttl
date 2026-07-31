///|
pub(all) struct NQuadsRecognizer {
  current_state : NQuadsState
  stack : Array[NQuadsState]
  mut emit_quad : Bool
  temp_literal : String?
  lenient : Bool
  debug_logger : &DebugLogger
  mut last_range : Range
  errors : Array[RuleRecognizerError]
}

///|
pub(all) struct NQuadsRecognizerContext {
  with_graph_name : Bool
  lexer_options : LexerOptions
}

///|
pub(all) struct DataWorld {
  mut subjects : Array[NamedOrBlankNodeRef]
  mut predicates : Array[NamedNodeRef]
  mut objects : Array[TermRef]
  mut temp_literal : String?
  mut finalize_literal : LiteralKind?
  mut graph_name : GraphNameRef?
} derive(Debug, Eq, Hash)

// impl DataWorld for DataWorld with fn default(self) -> Unit {
// ...
// }

///|
pub(all) enum DataAction {
  NoOp // ✅ 新增
  AddSubject(NamedOrBlankNodeRef)
  AddPredicate(NamedNodeRef)
  AddObject(TermRef)
  SetTempLiteral(String)
  SetGraphName(GraphNameRef)
  EmitQuad
  EmitQuadWithLiteral(LiteralKind)
  EmitQuadWithTempLiteral(NamedNodeRef)
  PushStack(NQuadsState)
  ClearAccumulator
  FinalizeLiteral(LiteralKind)
  FinalizeQuotedTriple
}

///|
impl Show for DataAction with fn output(self, logger : &Logger) -> Unit {
  match self {
    DataAction::NoOp => logger.write("NoOp")
    DataAction::AddSubject(subject) => {
      logger.write("AddSubject(")
      logger.write(subject)
      logger.write(")")
    }
    DataAction::AddPredicate(predicate) => {
      logger.write("AddPredicate(")
      logger.write(predicate)
      logger.write(")")
    }
    DataAction::AddObject(object) => {
      logger.write("AddObject(")
      logger.write(object)
      logger.write(")")
    }
    DataAction::SetTempLiteral(temp_literal) => {
      logger.write("SetTempLiteral(")
      logger.write(temp_literal)
      logger.write(")")
    }
    DataAction::SetGraphName(graph_name) => {
      logger.write("SetGraphName(")
      logger.write(graph_name)
      logger.write(")")
    }
    DataAction::EmitQuad => logger.write("EmitQuad")
    DataAction::EmitQuadWithLiteral(finalize_literal) => {
      logger.write("EmitQuadWithLiteral(")
      logger.write(finalize_literal)
      logger.write(")")
    }
    DataAction::EmitQuadWithTempLiteral(finalize_literal) => {
      logger.write("EmitQuadWithTempLiteral(")
      logger.write(finalize_literal)
      logger.write(")")
    }
    DataAction::PushStack(state) => {
      logger.write("PushStack(")
      logger.write(state)
      logger.write(")")
    }
    DataAction::ClearAccumulator => logger.write("ClearAccumulator")
    DataAction::FinalizeLiteral(finalize_literal) => {
      logger.write("FinalizeLiteral(")
      logger.write(finalize_literal)
      logger.write(")")
    }
    DataAction::FinalizeQuotedTriple => logger.write("FinalizeQuotedTriple")
  }
}

///|
pub fn DataWorld::DataWorld(
  subjects : Array[NamedOrBlankNodeRef],
  predicates : Array[NamedNodeRef],
  objects : Array[TermRef],
  temp_literal : String?,
  finalize_literal : LiteralKind?,
  graph_name : GraphNameRef?,
) -> DataWorld {
  DataWorld::{
    subjects,
    predicates,
    objects,
    temp_literal,
    finalize_literal,
    graph_name,
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
    None,
  )
}

///|
pub(all) enum LiteralKind {
  Simple
  Lang(LanguageTag, BaseDirection)
  Typed(String, NamedNodeRef)
} derive(Debug, Eq, Hash)

///|
pub impl Show for LiteralKind with fn output(self, logger : &Logger) -> Unit {
  match self {
    LiteralKind::Simple => logger.write("Simple")
    LiteralKind::Lang(lang, dir) => {
      logger.write("Lang(")
      logger.write(lang)
      logger.write(", ")
      logger.write(dir)
      logger.write(")")
    }
    LiteralKind::Typed(data_type, iri) => {
      logger.write("Typed(")
      logger.write(data_type)
      logger.write(", ")
      logger.write(iri)
      logger.write(")")
    }
  }
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
pub(all) enum NQuadsAction {
  // 主体积木操作
  PushSubject(NamedOrBlankNodeRef)
  PushPredicate(NamedNodeRef)
  PushObject(TermRef)

  // 字面量处理
  SetTempLiteral(String)
  FinalizeSimpleLiteral
  FinalizeLangLiteral(String, BaseDirection)

  // 图名处理
  SetGraphName(NamedOrBlankNodeRef)
  EmitQuad
  EmitQuadWithGraphName

  // 引号三元组 (<< >>)
  PushStack(NQuadsState)
  PopStack
  FinalizeQuotedTriple

  // 错误恢复
  SetError(RuleRecognizerError)
  ClearAccumulator
}

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
  // self.subjects.clear()
  // self.predicates.clear()
  // self.objects.clear()
  self
}

///|
// pub impl RuleRecognizer for NQuadsRecognizer with fn[DL : DebugLogger] debug_logger(
//   self : NQuadsRecognizer,
//   debug_logger : DL,
// ) {
//   self.debug_logger = debug_logger
// }

///|
pub impl RuleRecognizer for NQuadsRecognizer with fn recognize_end(
  _self : NQuadsRecognizer,
  _context : RdfContext,
  _results : Array[RdfOut],
) -> Unit {
  ()
}

///|
pub impl RuleRecognizer for NQuadsRecognizer with fn lexer_options(
  context : RdfContext,
) -> LexerOptions? {
  match context {
    RdfContext::NQuadsRecognizerContext(ctx) => Some(ctx.lexer_options)
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
    RdfLexer::RdfLexer(RdfLexerMode::NTriples, lenient, []),
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
    emit_quad: false,
    // finalize_literal: None,
    // last_output: None,
    temp_literal: None,
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
    data_world: DataWorld::default(),
    debug_logger,
    lexer_errors: [],
  }
  Parser::{ lexer, engine: generic_machine, context, errors: [] }
  // Parser::Parser(lexer, machine, context)
}
