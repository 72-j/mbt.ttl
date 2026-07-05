///|
pub fn N3State::to_str(self : N3State) -> String {
  Show::to_string(self)
}

///|
impl StateMachine for N3Recognizer with fn initial_state(_self : N3Recognizer) -> RdfState {
  RdfState::N3State(N3State::N3Doc)
}

///|
impl StateMachine for N3Recognizer with fn error_recovery_statemachine(self) -> N3Recognizer {
  self.error_recovery_state()
}

///|
impl StateMachine for N3Recognizer with fn current_state(self) -> RdfState {
  self.stack.last().unwrap_or(N3State::N3Doc).as_state_enum()
}

///|
impl StateMachine for N3Recognizer with fn step(self, event : Event) -> N3Recognizer {
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
impl StateMachine for N3Recognizer with fn reset(self) -> N3Recognizer {
  // 重置栈

  self.error_recovery_state()
}

///|

///|
impl StateMachine for N3Recognizer with fn transition(
  self : N3Recognizer,
  state : RdfState,
  event : Event,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, RdfState, RdfOut] { // 1. 修正返回类型为 Result
  // 解包 RdfState
  let n3_state = match state {
    RdfState::N3State(s) => s
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Invalid state type for N3Recognizer",
          self.last_range,
        ),
      )
  }

  self.debug_logger.info("N3 State: \{n3_state}, Event: \{event}")

  let result = match n3_state {
    N3State::N3Doc => self.handle_n3_doc_m(event, context)
    N3State::N3DocExpectDot => self.handle_n3_doc_expect_dot_m(event, context)
    N3State::BaseExpectIri => self.handle_base_expect_iri_m(event, context)
    N3State::PrefixExpectPrefix =>
      self.handle_prefix_expect_prefix_m(event, context)
    N3State::PrefixExpectIri(name~) =>
      self.handle_prefix_expect_iri_m(name, event, context)
    N3State::Triples => self.handle_triples_m(event, context)
    N3State::TriplesMiddle => self.handle_triples_middle_m(event, context)
    N3State::TriplesEnd => self.handle_triples_end_m(event, context)
    N3State::PredicateObjectList =>
      self.handle_predicate_object_list_m(event, context)
    N3State::PredicateObjectListEnd =>
      self.handle_predicate_object_list_end_m(event, context)
    N3State::PredicateObjectListPossibleContinuation =>
      self.handle_predicate_object_list_possible_continuation_m(event, context)
    N3State::ObjectsList => self.handle_objects_list_m(event, context)
    N3State::ObjectsListEnd => self.handle_objects_list_end_m(event, context)
    N3State::Verb => self.handle_verb_m(event, context)
    N3State::AfterRegularVerb =>
      self.handle_after_regular_verb_m(event, context)
    N3State::AfterInvertedVerb =>
      self.handle_after_inverted_verb_m(event, context)
    N3State::AfterVerbIs => self.handle_after_verb_is_m(event, context)
    N3State::Path => self.handle_path_m(event, context)
    N3State::PathFollowUp => self.handle_path_follow_up_m(event, context)
    N3State::PathAfterIndicator(is_inverse~) =>
      self.handle_path_after_indicator_m(is_inverse, event, context)
    N3State::PathItem => self.handle_path_item_m(event, context)
    N3State::PropertyListMiddle =>
      self.handle_property_list_middle_m(event, context)
    N3State::PropertyListEnd => self.handle_property_list_end_m(event, context)
    N3State::IriPropertyList => self.handle_iri_property_list_m(event, context)
    N3State::CollectionBeginning =>
      self.handle_collection_beginning_m(event, context)
    N3State::CollectionPossibleEnd =>
      self.handle_collection_possible_end_m(event, context)
    N3State::LiteralPossibleSuffix(value~) =>
      self.handle_literal_possible_suffix_m(value, event, context)
    N3State::LiteralExpectDatatype(value~) =>
      self.handle_literal_expect_datatype_m(value, event, context)
    N3State::FormulaContent => self.handle_formula_content_m(event, context)
    N3State::FormulaContentExpectDot =>
      self.handle_formula_content_expect_dot_m(event, context)

    // _ => {
    //   let err = RuleRecognizerError::SyntaxError(
    //     "Unhandled state: \{n3_state.to_string()}",
    //     self.last_range,
    //   )
    //   let new_self = self.add_error(err)
    //   Ok((new_self, n3_state, None))
    // }
  }
  // 将元组包装为 Ok
  match result {
    Ok((new_self, new_state, output)) =>
      Ok((new_self, new_state.as_state_enum(), output))
    Err(e) => Err(e)
  }
}

///|
impl StateMachine for N3Recognizer with fn is_accepting(self : N3Recognizer) -> Bool {
  self.current_state() == RdfState::N3State(N3State::N3Doc) &&
  self.stack.is_empty()
}

///|
impl StateMachine for N3Recognizer with fn context(_self : N3Recognizer) -> RdfContext {
  RdfContext::N3RecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    prefixes: Map([]),
  })
}

///|
impl StateMachine for N3Recognizer with fn set_context(
  self : N3Recognizer,
  _context : RdfContext,
) -> N3Recognizer {
  // 假设 N3Recognizer 有一个 context 字段或者通过其他方式管理
  // 这里简单返回 self，实际可能需要更新内部状态
  self
}

///|
impl StateMachine for N3Recognizer with fn[ST : StateWrapper] set_current_state(
  self : N3Recognizer,
  state : ST,
) -> N3Recognizer {
  let state = ST::as_state_enum(state)
  match state {
    RdfState::N3State(s) => {
      debug("[Step 3] Set current state: \{s}")
      let new_stack = self.stack
      if !new_stack.is_empty() {
        let _ = new_stack.pop() // 移除旧状态
      }
      new_stack.push(s)
      { ..self, stack: new_stack }
    }
    _ => self
  }
}

///|
pub fn N3Recognizer::add_error(
  self : N3Recognizer,
  err : RuleRecognizerError,
) -> N3Recognizer {
  let new_errors = self.errors
  new_errors.push(err)
  { ..self, errors: new_errors }
}
