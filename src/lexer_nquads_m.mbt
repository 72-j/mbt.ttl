///|
pub fn NQuadsState::to_str(self : NQuadsState) -> String {
  Show::to_string(self)
}

// ===== NQuadsRecognizer 实现 =====

///|
pub impl StateMachine for NQuadsRecognizer with fn initial_state(
  _self : NQuadsRecognizer,
) -> RdfState {
  RdfState::NQuadsState(NQuadsState::ExpectSubject)
}

///|
pub impl StateMachine for NQuadsRecognizer with fn error_recovery_statemachine(
  self,
) -> NQuadsRecognizer {
  self.error_recovery_state()
}

///|
pub impl StateMachine for NQuadsRecognizer with fn current_state(self) -> RdfState {
  self.stack.last().unwrap_or(NQuadsState::ExpectSubject).as_state_enum()
}

///|
pub impl StateMachine for NQuadsRecognizer with fn step(self, event : Event) -> NQuadsRecognizer {
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
pub impl StateMachine for NQuadsRecognizer with fn reset(self) -> NQuadsRecognizer {
  self.error_recovery_state()
}

///|
pub impl StateMachine for NQuadsRecognizer with fn transition(
  self : NQuadsRecognizer,
  state : RdfState,
  event : Event,
  context : RdfContext,
) -> TransitionResult[NQuadsRecognizer, RdfState, RdfOut] { // 1. 修正返回类型为 Result
  // 解包 RdfState
  let nquads_state = match state {
    RdfState::NQuadsState(s) => s
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Invalid state type for NQuadsRecognizer",
          self.last_range,
        ),
      )
  }

  let context = match context {
    RdfContext::NQuadsRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Invalid context for NQuads",
          self.last_range,
        ),
      )
  }

  self.debug_logger.info("NQuads State: \{nquads_state}, Event: \{event}")

  let result = match nquads_state {
    NQuadsState::ExpectSubject => self.handle_expect_subject_m(event, context)
    NQuadsState::ExpectPredicate =>
      self.handle_expect_predicate_m(event, context)
    NQuadsState::ExpectedObject => self.handle_expected_object_m(event, context)
    NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~) =>
      self.handle_expect_literal_annotation_or_graph_name_or_dot_m(
        event, context, value,
      )
    NQuadsState::ExpectLiteralDatatype(value~) =>
      self.handle_expect_literal_datatype_m(event, context, value)
    NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple =>
      self.handle_expect_possible_graph_or_end_of_quoted_triple_m(
        event, context,
      )
    NQuadsState::ExpectDot => self.handle_expect_dot_m(event, context)
        NQuadsState::ExpectLineJump => 
      self.handle_expect_line_jump_m(event, context)
    NQuadsState::RecoverToLineJump =>
      self.handle_recover_to_line_jump_m(event, context)
    _ => {
      self.debug_logger.info(
        ">>> FALLBACK to _ case: \{nquads_state.to_string()}",
      )
      let err = RuleRecognizerError::SyntaxError(
        "Unhandled state: \{nquads_state.to_string()}",
        self.last_range,
      )
      let new_self = self.add_error(err)
      Ok((new_self, nquads_state, None))
    }
  }
  match result {
    Ok((new_self, new_state, output)) =>
      Ok((new_self, new_state.as_state_enum(), output))
    Err(e) => Err(e)
  }
}

///|
pub impl StateMachine for NQuadsRecognizer with fn is_accepting(
  self : NQuadsRecognizer,
) -> Bool {
  self.current_state() == RdfState::NQuadsState(NQuadsState::ExpectSubject) &&
  self.stack.is_empty()
}

///|
pub impl StateMachine for NQuadsRecognizer with fn context(
  _self : NQuadsRecognizer,
) -> RdfContext {
  RdfContext::NQuadsRecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
  })
}

///|
pub impl StateMachine for NQuadsRecognizer with fn set_context(
  self : NQuadsRecognizer,
  _context : RdfContext,
) -> NQuadsRecognizer {
  // 假设 NQuadsRecognizer 有一个 context 字段或者通过其他方式管理
  // 这里简单返回 self，实际可能需要更新内部状态
  self
}

///|
pub impl StateMachine for NQuadsRecognizer with fn[ST : StateWrapper] set_current_state(
  self : NQuadsRecognizer,
  state : ST,
) -> NQuadsRecognizer {
  let state = ST::as_state_enum(state)
  match state {
    RdfState::NQuadsState(s) => {
      // 返回一个新的 NQuadsRecognizer 实例，其中 stack 被更新
      // 假设有一个 with_stack 或类似的方法，或者直接构造新实例
      // 这里简化处理，实际需要根据 NQuadsRecognizer 的结构体定义来更新
      // debug("[Step 3] Set current state: \{s}")
              let new_stack = self.stack
        if new_stack.is_empty() {
          new_stack.push(s)
        } else {
          let _ = new_stack.pop() // 移除旧状态
          new_stack.push(s) // 添加新状态
        }
      { ..self, stack: new_stack }
    }
    _ => self
  }
}

// 辅助方法：统一处理 TransitionResult 并返回更新后的 Self

///|
pub fn NQuadsRecognizer::process_transition_result(
  self : NQuadsRecognizer,
  current_state : NQuadsState,
  result : TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut],
) -> (NQuadsRecognizer, RdfState, RdfOut?) {
  match result {
    Ok((self, new_state, output)) => (self, new_state.as_state_enum(), output)
    Err(e) => {
      let new_self = self.add_error(e)
      (new_self, current_state.as_state_enum(), None)
    }
  }
}

///|
fn NQuadsRecognizer::add_error(
  self : NQuadsRecognizer,
  err : RuleRecognizerError,
) -> NQuadsRecognizer {
  let new_errors = self.errors
  new_errors.push(err)
  { ..self, errors: new_errors }
}
