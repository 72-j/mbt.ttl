///|
pub(all) struct TriGRecognizer {
  mut stack : Array[TriGState]
  cur_subject : Array[NamedOrBlankNodeRef]
  cur_predicate : Array[NamedNodeRef]
  cur_object : Array[TermRef]
  mut cur_graph : GraphNameRef
  cur_reifier : Array[NamedOrBlankNodeRef]
  lenient : Bool
  mut debug_logger : &DebugLogger
  // mut in_collection : Bool
  mut last_range : Range
  errors : Array[RuleRecognizerError] // ← 新增：错误存储
}

///|
pub impl Show for TriGRecognizer with fn output(self, logger : &Logger) -> Unit {
  logger.write("TriGRecognizer:\n")

  // 1. 打印栈状态 (增加分隔符和更全的匹配)
  logger.write("  Stack: [")
  for i = 0; i < self.stack.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    logger.write(self.stack[i])
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
      NamedOrBlankNodeRef::BlankNodeRef(_b) =>
        logger.write(BlankNode::default()) // 或者 b.to_string() 如果有实现
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
      TermRef::BlankNodeRef(_b) => logger.write("_:b")
      TermRef::LiteralRef(l) => logger.write(l.to_string())
      TermRef::TripleRef(_t) => logger.write("<<...>>") // 简化显示，避免递归过深
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
      NamedOrBlankNodeRef::BlankNodeRef(_b) => logger.write("_:b")
    }
  }
  logger.write("]\n")

  // 6. 打印当前图
  logger.write("  Graph: ")
  match self.cur_graph {
    GraphNameRef::DefaultGraph => logger.write("DEFAULT")
    GraphNameRef::NamedNodeRef(n) => logger.write(n.to_string())
    GraphNameRef::BlankNodeRef(_b) => logger.write("_:b")
  }
  logger.write("\n")
}

///|
pub(all) struct TriGRecognizerContext {
  lexer_options : LexerOptions
  with_graph_name : Bool
  prefixes : Map[String, Iri]
}

///|
pub fn TriGRecognizerContext::TriGRecognizerContext(
  lexer_options : LexerOptions,
  with_graph_name : Bool,
  prefixes : Map[String, Iri],
) -> TriGRecognizerContext {
  TriGRecognizerContext::{ lexer_options, with_graph_name, prefixes }
}

///|
pub fn TriGRecognizerContext::prefixes(
  self : TriGRecognizerContext,
) -> Map[String, Iri] {
  self.prefixes
}

///|
pub impl RuleRecognizer for TriGRecognizer with fn error_recovery_state(
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
pub impl RuleRecognizer for TriGRecognizer with fn[DL : DebugLogger] debug_logger(
  self : TriGRecognizer,
  debug_logger : DL,
) {
  self.debug_logger = debug_logger
}

///|
pub impl RuleRecognizer for TriGRecognizer with fn recognize_end(
  self : TriGRecognizer,
  _context : RdfContext,
  results : Array[RdfOut],
) -> Unit {
  self.debug_logger.info(
    "TriGRecognizer :: recognize_end \{@debug.to_string(self.stack)}",
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
      self.errors.push(
        RuleRecognizerError::SyntaxError(
          "Triples should be followed by a dot",
          self.last_range,
        ),
      )
    }
    _ =>
      self.errors.push(
        RuleRecognizerError::SyntaxError("Unexpected end", self.last_range),
      )
  }
}

///|
pub impl RuleRecognizer for TriGRecognizer with fn lexer_options(
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
      stack: [TriGState::TriGDoc],
      cur_subject: [],
      cur_predicate: [],
      cur_object: [],
      cur_graph: GraphName::DefaultGraph.as_ref(),
      cur_reifier: [],
      lenient,
      debug_logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
      // in_collection: false,
      last_range: Range::default(),
      errors: [],
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
  // errors : Array[RuleRecognizerError],
  msg : String,
) -> TriGRecognizer {
  // guard self.last_range.start != self.last_range.end 

  self.errors.push(RuleRecognizerError::SyntaxError(msg, self.last_range))
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_graph = GraphName::DefaultGraph.as_ref()
  self
}

///|
fn TriGRecognizer::emit_quad_m(self : TriGRecognizer) -> RdfOut {
  let subject = self.cur_subject.last().unwrap()
  let predicate = self.cur_predicate.last().unwrap()
  let object = self.cur_object.last().unwrap()

  RdfOut::Quad(
    Quad::Quad(
      subject.into_owned(),
      predicate.into_owned(),
      object.into_owned(),
      self.cur_graph.into_owned(),
    ),
  )
}

///|
fn TriGRecognizer::emit_quad(
  self : TriGRecognizer,
  results : Array[RdfOut],
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
    RdfOut::Quad(
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
pub(all) enum TriGState {
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
  InCollection
  CollectionElement
  CollectionEnd
} derive(Debug, Eq, Hash)

///|
pub impl StateWrapper for TriGState with fn as_state_enum(self : TriGState) -> RdfState {
  RdfState::TriGState(self)
}

///|
pub impl Show for TriGState with fn output(self, logger : &Logger) -> Unit {
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
    TriGState::QuotedAnonEnd => logger.write("QuotedAnonEnd")
    TriGState::AnnotationEnd(_) => logger.write("AnnotationEnd")
    TriGState::SubjectCollectionPossibleEnd =>
      logger.write("SubjectCollectionPossibleEnd")
    TriGState::WrappedGraphPossibleEnd =>
      logger.write("WrappedGraphPossibleEnd")
    TriGState::CollectionElement => logger.write("CollectionElement")
    TriGState::CollectionEnd => logger.write("CollectionEnd")
    TriGState::InCollection => logger.write("InCollection")
  }
}

///|
pub fn TriGRecognizer::replace_top(
  stack : Array[TriGState],
  new_state : TriGState,
) -> Array[TriGState] {
  let _ = stack.pop()
  stack.push(new_state)
  stack
}

///|
pub fn TriGRecognizer::set_state(
  self : TriGRecognizer,
  new_state : TriGState,
) -> TriGRecognizer {
  // let _ = self.stack.pop() // 弹出当前状态
  self.stack.push(new_state) // 压入新状态
  self
}

///|
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

///|
fn TriGRecognizer::make_current_quad(self : TriGRecognizer) -> RdfOut {
  // 1. 获取主语、谓词、对象
  let subject = match self.cur_subject.pop() {
    Some(s) => s
    None => abort("Subject stack is empty when making quad")
  }

  let predicate = match self.cur_predicate.pop() {
    Some(p) => p
    None => abort("Predicate stack is empty when making quad")
  }

  let object = match self.cur_object.pop() {
    Some(o) => o
    None => abort("Object stack is empty when making quad")
  }

  let graph = self.cur_graph

  RdfOut::Quad(
    Quad::Quad(
      subject.into_owned(),
      predicate.into_owned(),
      object.into_owned(),
      graph.into_owned(),
    ),
  )
}
