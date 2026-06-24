///|
pub struct TriGRecognizer {
  mut stack : Array[TriGState]
  cur_subject : Array[NamedOrBlankNodeRef]
  cur_predicate : Array[NamedNodeRef]
  cur_object : Array[TermRef]
  mut cur_graph : GraphNameRef
  cur_reifier : Array[NamedOrBlankNodeRef]
  lenient : Bool
  mut debug_logger : &DebugLogger
  mut in_collection : Bool
}

///|
impl Show for TriGRecognizer with fn output(self, logger : &Logger) -> Unit {
  logger.write("TriGRecognizer:\n")

  // 1. 打印栈状态 (增加分隔符和更全的匹配)
  logger.write("  Stack: [")
  for i = 0; i < self.stack.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.stack[i] {
      TriGState::TriGDoc => logger.write("TriGDoc")
      TriGState::ExpectDot => logger.write("ExpectDot")
      TriGState::BaseExpectIri => logger.write("BaseExpectIri")
      TriGState::PrefixExpectPrefix => logger.write("PrefixExpectPrefix")
      TriGState::PrefixExpectIri(name~) =>
        logger.write("PrefixExpectIri(\{name})")
      TriGState::VersionExpectVersion => logger.write("VersionExpectVersion")
      TriGState::TriplesOrGraph => logger.write("TriplesOrGraph")
      TriGState::WrappedGraph => logger.write("WrappedGraph")
      TriGState::WrappedGraphPossibleEnd =>
        logger.write("WrappedGraphPossibleEnd")
      TriGState::GraphName => logger.write("GraphName")
      TriGState::ExpectAtKeyword => logger.write("ExpectAtKeyword")
      TriGState::PredicateObjectList => logger.write("PredicateObjectList")
      TriGState::PredicateObjectListEnd =>
        logger.write("PredicateObjectListEnd")
      TriGState::ObjectsList => logger.write("ObjectsList")
      TriGState::Object => logger.write("Object")
      TriGState::Verb => logger.write("Verb")
      TriGState::LiteralPossibleSuffix(value~, emit~) =>
        logger.write("LiteralPossibleSuffix(\{value} emit=\{emit})")
      TriGState::SubjectCollectionBeginning =>
        logger.write("SubjectCollectionBeginning")
      TriGState::ObjectCollectionBeginning =>
        logger.write("ObjectCollectionBeginning")
      TriGState::WrappedGraphOrPredicateObjectList(_) =>
        logger.write("WrappedGraphOrPredicateObjectList")
      TriGState::AnnotationBlock(_) => logger.write("AnnotationBlock")
      TriGState::Reifier(_) => logger.write("Reifier")
      TriGState::ReifiedTripleSubject(_) => logger.write("ReifiedTripleSubject")
      TriGState::ReifiedTripleObject(_) => logger.write("ReifiedTripleObject")
      TriGState::ObjectReifiedTripleEnd(_) =>
        logger.write("ObjectReifiedTripleEnd")
      TriGState::SubjectReifiedTripleEnd =>
        logger.write("SubjectReifiedTripleEnd")
      TriGState::EndOfReifiedTripleBeforeReifier =>
        logger.write("EndOfReifiedTripleBeforeReifier")
      TriGState::MaybePredicateObjectList =>
        logger.write("MaybePredicateObjectList")
      TriGState::PredicateObjectListPossibleContinuation =>
        logger.write("PredicateObjectListPossibleContinuation")
      TriGState::ObjectBlankNodePropertyListCurrent =>
        logger.write("ObjectBlankNodePropertyListCurrent")
      TriGState::ObjectBlankNodePropertyListEnd =>
        logger.write("ObjectBlankNodePropertyListEnd")
      TriGState::ObjectCollectionPossibleEnd =>
        logger.write("ObjectCollectionPossibleEnd")
      TriGState::SubjectBlankNodePropertyListEnd =>
        logger.write("SubjectBlankNodePropertyListEnd")
      TriGState::SubjectBlankNodePropertyListAfter =>
        logger.write("SubjectBlankNodePropertyListAfter")
      TriGState::WrappedGraphBlankNodePropertyListCurrent =>
        logger.write("WrappedGraphBlankNodePropertyListCurrent")
      TriGState::Triples => logger.write("Triples")
      TriGState::TriplesBlankNodePropertyListCurrent =>
        logger.write("TriplesBlankNodePropertyListCurrent")
      TriGState::GraphNameAnonEnd => logger.write("GraphNameAnonEnd")
      TriGState::QuotedAnonEnd => logger.write("QuotedAnonEnd")
      TriGState::AnnotationEnd(_) => logger.write("AnnotationEnd")
      TriGState::LiteralExpectDatatype(..) =>
        logger.write("LiteralExpectDatatype")
      TriGState::TripleTermEnd(_) => logger.write("TripleTermEnd")
      TriGState::SubjectCollectionPossibleEnd =>
        logger.write("SubjectCollectionPossibleEnd")
      // _ => logger.write("UnknownState")
    }
  }
  logger.write("]\n")

  // 2. 打印 Subject (增加分隔符，处理 BlankNode 显示)
  logger.write("  Subject: [")
  for i = 0; i < self.cur_subject.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.cur_subject[i] {
      NamedOrBlankNodeRef::NamedNodeRef(n) => logger.write(n.to_string())
      NamedOrBlankNodeRef::BlankNodeRef(b) => logger.write("_:b") // 或者 b.to_string() 如果有实现
    }
  }
  logger.write("]\n")

  // 3. 打印 Predicate
  logger.write("  Predicate: [")
  for i = 0; i < self.cur_predicate.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    // 假设 NamedNodeRef 实现了 Show 或者有 to_string
    logger.write(self.cur_predicate[i].to_string())
  }
  logger.write("]\n")

  // 4. 打印 Object
  logger.write("  Object: [")
  for i = 0; i < self.cur_object.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.cur_object[i] {
      TermRef::NamedNodeRef(n) => logger.write(n.to_string())
      TermRef::BlankNodeRef(b) => logger.write("_:b")
      TermRef::LiteralRef(l) => logger.write(l.to_string())
      TermRef::TripleRef(t) => logger.write("<<...>>") // 简化显示，避免递归过深
    }
  }
  logger.write("]\n")

  // 5. 打印 Reifier
  logger.write("  Reifier: [")
  for i = 0; i < self.cur_reifier.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.cur_reifier[i] {
      NamedOrBlankNodeRef::NamedNodeRef(n) => logger.write(n.to_string())
      NamedOrBlankNodeRef::BlankNodeRef(b) => logger.write("_:b")
    }
  }
  logger.write("]\n")

  // 6. 打印当前图
  logger.write("  Graph: ")
  match self.cur_graph {
    GraphNameRef::DefaultGraph => logger.write("DEFAULT")
    GraphNameRef::NamedNodeRef(n) => logger.write(n.to_string())
    GraphNameRef::BlankNodeRef(b) => logger.write("_:b")
  }
  logger.write("\n")
}

///|
pub struct TriGRecognizerContext {
  lexer_options : LexerOptions
  with_graph_name : Bool
  prefixes : Map[String, Iri]
}

///|
pub fn TriGRecognizerContext::prefixes(
  self : TriGRecognizerContext,
) -> Map[String, Iri] {
  self.prefixes
}

///|
impl RuleRecognizer for TriGRecognizer with fn error_recovery_state(
  self : TriGRecognizer,
) -> TriGRecognizer {
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_reifier.clear()
  self.cur_graph = GraphNameRef::DefaultGraph
  self
}

///|
impl RuleRecognizer for TriGRecognizer with fn[DL : DebugLogger] debug_logger(
  self : TriGRecognizer,
  debug_logger : DL,
) {
  self.debug_logger = debug_logger
}

///|
impl RuleRecognizer for TriGRecognizer with fn recognize_end(
  self : TriGRecognizer,
  _context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> Unit {
  self.debug_logger.info(
    "TriGRecognizer :: recognize_end \{self.stack.to_string()}",
  )
  match self.stack {
    [] | [TriGState::TriGDoc] => {
      debug_assert(() => self.cur_subject.is_empty())
      debug_assert(() => self.cur_predicate.is_empty())
      debug_assert(() => self.cur_object.is_empty())
    }
    [.., TriGState::LiteralPossibleSuffix(value~, emit=true)] => {
      self.cur_object.push(LiteralRef::new_simple_literal(value).as_term())
      self.emit_quad(results)
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Triples should be followed by a dot",
          SourcePosition::default(),
        ),
      )
    }
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          SourcePosition::default(),
        ),
      )
  }
}

///|
impl RuleRecognizer for TriGRecognizer with fn lexer_options(
  context : RdfContext,
) -> LexerOptions? {
  let lexer_opts : LexerOptions? = match context {
    RdfContext::TriGRecognizerContext(ctx) => Some(ctx.lexer_options)
    _ => None
  }
  lexer_opts
}

///|
pub fn TriGRecognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  with_graph_name : Bool,
  lenient : Bool,
  base_iri : Iri?,
  prefixes : Map[String, Iri],
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> Parser[RdfLexer, TriGRecognizer] {
  Parser::Parser(
    Lexer::Lexer(
      RdfLexer::RdfLexer(RdfLexerMode::Turtle, lenient),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    ),
    {
      stack: [TriGState::TriGDoc],
      cur_subject: [],
      cur_predicate: [],
      cur_object: [],
      cur_graph: GraphName::DefaultGraph.as_ref(),
      cur_reifier: [],
      lenient,
      debug_logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
      in_collection: false,
    },
    RdfContext::TriGRecognizerContext({
      with_graph_name,
      prefixes,
      lexer_options: { base_iri, },
    }),
  )
}

///|
fn TriGRecognizer::error(
  self : TriGRecognizer,
  errors : Array[RuleRecognizerError],
  msg : String,
) -> TriGRecognizer {
  errors.push(RuleRecognizerError::SyntaxError(msg, SourcePosition::default()))
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_graph = GraphName::DefaultGraph.as_ref()
  self
}

///|

///|
fn TriGRecognizer::emit_quad(
  self : TriGRecognizer,
  results : Array[RdfStatement],
) -> Unit {
  let subject = match self.cur_subject.last() {
    Some(s) => s
    None => return // 或者报错，例如: abort("Internal error: subject stack empty in emit_quad")
  }
  let predicate = match self.cur_predicate.last() {
    Some(p) => p
    None => return
  }
  let object = match self.cur_object.last() {
    Some(o) => o
    None => return
  }

  results.push(
    RdfStatement::Quad(
      Quad::Quad(
        subject.into_owned(),
        predicate.into_owned(),
        object.into_owned(),
        self.cur_graph.into_owned(),
      ),
    ),
  )
}

///|
enum TriGState {
  ExpectAtKeyword
  TriGDoc
  ExpectDot
  BaseExpectIri
  PrefixExpectPrefix
  PrefixExpectIri(name~ : String)
  VersionExpectVersion
  TriplesOrGraph
  WrappedGraphBlankNodePropertyListCurrent
  SubjectBlankNodePropertyListEnd
  SubjectBlankNodePropertyListAfter
  SubjectCollectionBeginning
  SubjectCollectionPossibleEnd
  WrappedGraphOrPredicateObjectList(term~ : NamedOrBlankNodeRef)
  WrappedGraph
  WrappedGraphPossibleEnd
  GraphName
  GraphNameAnonEnd
  Triples
  TriplesBlankNodePropertyListCurrent
  MaybePredicateObjectList
  PredicateObjectList
  PredicateObjectListEnd
  PredicateObjectListPossibleContinuation
  ObjectsList
  AnnotationBlock(with_reifier~ : Bool)
  AnnotationEnd(with_reifier~ : Bool)
  Verb
  Object
  ObjectBlankNodePropertyListCurrent
  ObjectBlankNodePropertyListEnd
  ObjectCollectionBeginning
  ObjectCollectionPossibleEnd
  LiteralPossibleSuffix(value~ : String, emit~ : Bool)
  LiteralExpectDatatype(value~ : String, emit~ : Bool)
  SubjectReifiedTripleEnd
  ObjectReifiedTripleEnd(emit~ : Bool)
  TripleTermEnd(emit~ : Bool)
  EndOfReifiedTripleBeforeReifier
  Reifier(triple~ : Triple)
  ReifiedTripleSubject(is_reified~ : Bool)
  ReifiedTripleObject(is_reified~ : Bool)
  QuotedAnonEnd
  // NegativeNumberSign
} derive(Debug, Eq)

///|
impl Show for TriGState with fn output(self, logger : &Logger) -> Unit {
  match self {
    TriGState::TripleTermEnd(emit~) => logger.write("TripleTermEnd(\{emit})")
    TriGState::LiteralExpectDatatype(value~, emit~) =>
      logger.write("LiteralExpectDatatype(\{value}, \{emit})")
    TriGState::TriplesBlankNodePropertyListCurrent =>
      logger.write("TriplesBlankNodePropertyListCurrent")
    TriGState::GraphNameAnonEnd => logger.write("GraphNameAnonEnd")
    TriGState::ExpectAtKeyword => logger.write("ExpectAtKeyword")
    TriGState::TriGDoc => logger.write("TriGDoc")
    TriGState::Object => logger.write("Object")
    TriGState::PredicateObjectList => logger.write("PredicateObjectList")
    TriGState::PredicateObjectListEnd => logger.write("PredicateObjectListEnd")
    TriGState::ObjectsList => logger.write("ObjectsList")
    TriGState::Verb => logger.write("Verb")
    TriGState::TriplesOrGraph => logger.write("TriplesOrGraph")
    TriGState::ExpectDot => logger.write("ExpectDot")
    TriGState::BaseExpectIri => logger.write("BaseExpectIri")
    TriGState::PrefixExpectPrefix => logger.write("PrefixExpectPrefix")
    TriGState::PrefixExpectIri(name~) =>
      logger.write("PrefixExpectIri(\{name})")
    TriGState::VersionExpectVersion => logger.write("VersionExpectVersion")
    TriGState::WrappedGraph => logger.write("WrappedGraph")
    TriGState::GraphName => logger.write("GraphName")
    TriGState::ExpectAtKeyword => logger.write("ExpectAtKeyword")
    TriGState::LiteralPossibleSuffix(..) =>
      logger.write("LiteralPossibleSuffix")
    TriGState::SubjectCollectionBeginning =>
      logger.write("SubjectCollectionBeginning")
    TriGState::ObjectCollectionBeginning =>
      logger.write("ObjectCollectionBeginning")
    TriGState::WrappedGraphOrPredicateObjectList(_) =>
      logger.write("WrappedGraphOrPredicateObjectList")
    TriGState::AnnotationBlock(_) => logger.write("AnnotationBlock")
    TriGState::Reifier(_) => logger.write("Reifier")
    TriGState::ReifiedTripleSubject(_) => logger.write("ReifiedTripleSubject")
    TriGState::ReifiedTripleObject(_) => logger.write("ReifiedTripleObject")
    TriGState::ObjectReifiedTripleEnd(_) =>
      logger.write("ObjectReifiedTripleEnd")
    TriGState::SubjectReifiedTripleEnd =>
      logger.write("SubjectReifiedTripleEnd")
    TriGState::EndOfReifiedTripleBeforeReifier =>
      logger.write("EndOfReifiedTripleBeforeReifier")
    TriGState::MaybePredicateObjectList =>
      logger.write("MaybePredicateObjectList")
    TriGState::PredicateObjectListPossibleContinuation =>
      logger.write("PredicateObjectListPossibleContinuation")
    TriGState::ObjectBlankNodePropertyListCurrent =>
      logger.write("ObjectBlankNodePropertyListCurrent")
    TriGState::ObjectBlankNodePropertyListEnd =>
      logger.write("ObjectBlankNodePropertyListEnd")
    TriGState::ObjectCollectionPossibleEnd =>
      logger.write("ObjectCollectionPossibleEnd")
    TriGState::SubjectBlankNodePropertyListEnd =>
      logger.write("SubjectBlankNodePropertyListEnd")
    TriGState::SubjectBlankNodePropertyListAfter =>
      logger.write("SubjectBlankNodePropertyListAfter")
    TriGState::WrappedGraphBlankNodePropertyListCurrent =>
      logger.write("WrappedGraphBlankNodePropertyListCurrent")
    TriGState::Triples => logger.write("Triples")
    TriGState::TriplesBlankNodePropertyListCurrent =>
      logger.write("TriplesBlankNodePropertyListCurrent")
    TriGState::GraphNameAnonEnd => logger.write("GraphNameAnonEnd")
    TriGState::QuotedAnonEnd => logger.write("QuotedAnonEnd")
    TriGState::AnnotationEnd(_) => logger.write("AnnotationEnd")
    TriGState::LiteralExpectDatatype(..) =>
      logger.write("LiteralExpectDatatype")
    TriGState::TripleTermEnd(_) => logger.write("TripleTermEnd")
    TriGState::SubjectCollectionPossibleEnd =>
      logger.write("SubjectCollectionPossibleEnd")
    TriGState::WrappedGraphPossibleEnd =>
      logger.write("WrappedGraphPossibleEnd")
    // TriGState::NegativeNumberSign => logger.write("NegativeNumberSign")
  }
}

///|
fn TriGRecognizer::replace_top(
  stack : Array[TriGState],
  new_state : TriGState,
) -> Array[TriGState] {
  let _ = stack.pop()
  stack.push(new_state)
  stack
}

///|
fn TriGRecognizer::set_state(
  self : TriGRecognizer,
  new_state : TriGState,
) -> TriGRecognizer {
  // let _ = self.stack.pop() // 弹出当前状态
  self.stack.push(new_state) // 压入新状态
  self
}

/// 重置状态到 TriGDoc
fn TriGRecognizer::reset_to_tri_gdoc(self : TriGRecognizer) -> TriGRecognizer {
  let new_stack = []
  new_stack.push(TriGState::TriGDoc)
  self.stack = new_stack
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_reifier.clear()
  self
}
// impl Show for TriGState with fn output(self, logger : &Logger) -> Unit {
//   logger.write("TriGState: ")
//   logger.write_object(self)

// }
