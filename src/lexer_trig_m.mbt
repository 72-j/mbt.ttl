///|
pub enum RdfState {
  TriGState(TriGState)
  NQuadsState(NQuadsState)
  N3State(N3State)
} derive(Eq, Hash)

///|
impl Show for RdfState with fn to_string(self) -> String {
  match self {
    RdfState::TriGState(s) => s.to_string()
    RdfState::NQuadsState(s) => s.to_string()
    RdfState::N3State(s) => s.to_string()
  }
}

// ===== 定义 Result 类型 =====

///|
pub type TransitionResult[TR, S, O] = Result[(TR, S, O?), RuleRecognizerError]

///|
impl StateWrapper for RdfState with fn as_state_enum(self) -> RdfState {
  self
}

///|
pub fn TriGState::to_str(self : TriGState) -> String {
  Show::to_string(self)
}

///|
impl StateMachine for TriGRecognizer with fn initial_state(
  _self : TriGRecognizer,
) -> RdfState {
  RdfState::TriGState(TriGState::TriGDoc)
}

///|
impl StateMachine for TriGRecognizer with fn error_recovery_statemachine(self) -> TriGRecognizer {
  self.error_recovery_state()
}

///|
impl StateMachine for TriGRecognizer with fn current_state(self) -> RdfState {
  self.stack.last().unwrap_or(TriGState::TriGDoc).as_state_enum()
}

///|
impl StateMachine for TriGRecognizer with fn step(self, event : Event) -> TriGRecognizer {
  let current_state = self.current_state()
  let result = self.transition(
    current_state.as_state_enum(),
    event,
    self.context(),
  )
  match result {
    Ok((new_machine, new_state, _output)) => {
      let new_context = new_machine.context()
      let new_machine = new_machine.set_context(new_context)
      let new_machine = new_machine.set_current_state(new_state)
      new_machine
    }
    Err(_e) => abort("Error")
  }
}

///|
impl StateMachine for TriGRecognizer with fn reset(self) -> TriGRecognizer {
  self.error_recovery_state()
}

///|

///|
impl StateMachine for TriGRecognizer with fn transition(
  self : TriGRecognizer,
  state : RdfState,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, RdfState, RdfOut] { // 1. 修正返回类型为 Result
  // 解包 RdfState
  let trig_state = match state {
    RdfState::TriGState(s) => s
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Invalid state type for TriGRecognizer",
          self.last_range,
        ),
      ) // 2. 错误返回 Err
  }

  // let context = match context {
  //   RdfContext::TriGRecognizerContext(c) => c
  //   _ => return Err(RuleRecognizerError::SyntaxError("Invalid context for TriG", self.last_range)) // 2. 错误返回 Err
  // }

  self.debug_logger.info("TriG State: \{trig_state}, Event: \{event}")

  let result = match trig_state {
    TriGState::TriGDoc => self.handle_trig_doc_m(event, context)
    TriGState::TriplesOrGraph => self.handle_triples_or_graph_m(event, context)
    TriGState::WrappedGraphOrPredicateObjectList(term~) =>
      self.handle_wrapped_graph_or_predicate_object_list_m(term, event, context)
    TriGState::ObjectsList => self.handle_objects_list_m(event, context)
    TriGState::Object => self.handle_object_m(event, context)
    TriGState::PredicateObjectListEnd =>
      self.handle_predicate_object_list_end_m(event, context)
    TriGState::Verb => self.handle_verb_m(event, context)
    TriGState::ObjectCollectionBeginning =>
      self.handle_object_collection_beginning_m(event, context)
    TriGState::ObjectCollectionPossibleEnd =>
      self.handle_object_collection_possible_end_m(event, context)
    TriGState::WrappedGraph => self.handle_wrapped_graph_m(event, context)
    TriGState::WrappedGraphPossibleEnd =>
      self.handle_wrapped_graph_possible_end_m(event, context)
    TriGState::Triples => self.handle_triples_m(event, context)

    // ===== 指令与上下文处理 =====
    TriGState::ExpectAtKeyword =>
      self.handle_expect_at_keyword_m(event, context)
    TriGState::BaseExpectIri => self.handle_base_expect_iri_m(event, context)
    TriGState::PrefixExpectPrefix =>
      self.handle_prefix_expect_prefix_m(event, context)
    TriGState::PrefixExpectIri(name~) =>
      self.handle_prefix_expect_iri_m(name, event, context)
    TriGState::VersionExpectVersion =>
      self.handle_version_expect_version_m(event, context)
    TriGState::ExpectDot => self.handle_expect_dot_m(event, context)

    // ===== 图名称处理 =====
    TriGState::GraphName => self.handle_graph_name_m(event, context)
    TriGState::GraphNameAnonEnd =>
      self.handle_graph_name_anon_end_m(event, context)

    // ===== 空白节点属性列表处理 =====
    TriGState::SubjectBlankNodePropertyListEnd =>
      self.handle_subject_blank_node_property_list_end_m(event, context)
    TriGState::SubjectBlankNodePropertyListAfter =>
      self.handle_subject_blank_node_property_list_after_m(event, context)
    TriGState::WrappedGraphBlankNodePropertyListCurrent =>
      self.handle_wrapped_graph_blank_node_property_list_current_m(
        event, context,
      )
    TriGState::TriplesBlankNodePropertyListCurrent =>
      self.handle_triples_blank_node_property_list_current_m(event, context)
    TriGState::ObjectBlankNodePropertyListCurrent =>
      self.handle_object_blank_node_property_list_current_m(event, context)
    TriGState::ObjectBlankNodePropertyListEnd =>
      self.handle_object_blank_node_property_list_end_m(event, context) // 假设存在

    // ===== 集合处理 =====
    TriGState::SubjectCollectionBeginning =>
      self.handle_subject_collection_beginning_m(event, context)
    TriGState::SubjectCollectionPossibleEnd =>
      self.handle_subject_collection_possible_end_m(event, context)

    // ===== 字面量处理 =====
    TriGState::LiteralPossibleSuffix(value~, emit~) =>
      self.handle_literal_possible_suffix_m(value, emit, event, context) // 假设存在
    TriGState::LiteralExpectDatatype(value~, emit~) =>
      self.handle_literal_expect_datatype_m(value, emit, event, context)

    // ===== 引号三元组与重化处理 =====
    TriGState::ReifiedTripleSubject(is_reified~) =>
      self.handle_reified_triple_subject_m(is_reified, event, context)
    TriGState::ReifiedTripleObject(is_reified~) =>
      self.handle_reified_triple_object_m(is_reified, event, context)
    TriGState::SubjectReifiedTripleEnd =>
      self.handle_subject_reified_triple_end_m(event, context)
    TriGState::ObjectReifiedTripleEnd(emit~) =>
      self.handle_object_reified_triple_end_m(emit, event, context) // 假设存在
    TriGState::EndOfReifiedTripleBeforeReifier =>
      self.handle_end_of_reified_triple_before_reifier_m(event, context)
    TriGState::Reifier(triple~) => self.handle_reifier_m(triple, event, context)
    TriGState::TripleTermEnd(emit~) =>
      self.handle_triple_term_end_m(emit, event, context)
    TriGState::QuotedAnonEnd => self.handle_quoted_anon_end_m(event, context)

    // ===== 注解处理 =====
    TriGState::AnnotationEnd(with_reifier~) =>
      self.handle_annotation_end_m(with_reifier, event, context)

    // ===== 其他可能的状态 =====
    TriGState::MaybePredicateObjectList =>
      self.handle_maybe_predicate_object_list_m(event, context)
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "Unhandled state: \{trig_state.to_string()}",
        self.last_range,
      )
      let new_self = self.add_error(err)
      Ok((new_self, trig_state, None))
    }
  }
  // 将元组包装为 Ok
  match result {
    Ok((new_self, new_state, output)) =>
      Ok((new_self, new_state.as_state_enum(), output))
    Err(e) => Err(e)
  }
}

///|
impl StateMachine for TriGRecognizer with fn is_accepting(self : TriGRecognizer) -> Bool {
  self.current_state() == RdfState::TriGState(TriGState::TriGDoc) &&
  self.stack.is_empty()
}

///|
impl StateMachine for TriGRecognizer with fn context(_self : TriGRecognizer) -> RdfContext {
  RdfContext::TriGRecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
    prefixes: Map([]),
  })
}

///|
impl StateMachine for TriGRecognizer with fn set_context(
  self : TriGRecognizer,
  _context : RdfContext,
) -> TriGRecognizer {
  // 假设 TriGRecognizer 有一个 context 字段或者通过其他方式管理
  // 这里简单返回 self，实际可能需要更新内部状态
  self
}

///|
impl StateMachine for TriGRecognizer with fn[ST : StateWrapper] set_current_state(
  self : TriGRecognizer,
  state : ST,
) -> TriGRecognizer {
  let state = ST::as_state_enum(state)
  match state {
    RdfState::TriGState(s) => {
      // 返回一个新的 TriGRecognizer 实例，其中 stack 被更新

      let new_stack = self.stack
      new_stack.push(s)
      { ..self, stack: new_stack }
    }
    _ => self
  }
}

///|
pub fn TriGRecognizer::process_transition_result(
  self : TriGRecognizer,
  current_state : TriGState,
  result : TransitionResult[TriGRecognizer, TriGState, RdfOut],
) -> (TriGRecognizer, RdfState, RdfOut?) {
  match result {
    Ok((self, new_state, output)) => (self, new_state.as_state_enum(), output)
    Err(e) => {
      let new_self = self.add_error(e)
      (new_self, current_state.as_state_enum(), None)
    }
  }
}
// 辅助方法：添加错误并返回新的实例

///|
fn TriGRecognizer::add_error(
  self : TriGRecognizer,
  err : RuleRecognizerError,
) -> TriGRecognizer {
  let new_errors = self.errors
  new_errors.push(err)
  { ..self, errors: new_errors }
}
