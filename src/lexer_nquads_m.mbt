///|
fn NQuadsState::to_str(self : NQuadsState) -> String {
  Show::to_string(self)
}

// ===== NQuadsRecognizer 实现 =====

///|
impl StateMachine for NQuadsRecognizer with fn initial_state(
  self : NQuadsRecognizer,
) -> RdfState {
  RdfState::NQuadsState(NQuadsState::ExpectSubject)
}

///|
impl StateMachine for NQuadsRecognizer with fn error_recovery_statemachine(self) -> NQuadsRecognizer {
  // self.stack.clear()
  // self.stack.push(NQuadsState::ExpectSubject)
  // self.cur_subject.clear()
  // self.cur_predicate.clear()
  // self.cur_object.clear()
  // self.cur_reifier.clear()
  // self.cur_graph = GraphName::DefaultGraph.as_ref()
  self.error_recovery_state()
}

///|
impl StateMachine for NQuadsRecognizer with fn current_state(self) -> RdfState {
  self.stack.last().unwrap_or(NQuadsState::ExpectSubject).as_state_enum()
}

///|
impl StateMachine for NQuadsRecognizer with fn step(self, event : Event) -> NQuadsRecognizer {
  let current_state = self.current_state()
  let result = self.transition(
    current_state.as_state_enum(),
    event,
    self.context(),
  )
  match result {
    Ok((new_machine, new_state, output)) => {
      let new_context = new_machine.context()
      let new_machine = new_machine.set_context(new_context)
      let new_machine = new_machine.set_current_state(new_state)
      new_machine
    }
    Err(_e) => abort("Error")
  }
}

///|
impl StateMachine for NQuadsRecognizer with fn reset(self) -> NQuadsRecognizer {
  // 重置栈
  // self.stack.clear()
  // self.stack.push(NQuadsState::ExpectSubject)

  // // 清空数据
  // self.cur_subject.clear()
  // self.cur_predicate.clear()
  // self.cur_object.clear()
  // self.cur_reifier.clear()

  // // 重置图
  // self.cur_graph = GraphName::DefaultGraph.as_ref()

  self.error_recovery_state()
}

///|

///|
impl StateMachine for NQuadsRecognizer with fn transition(
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
      ) // 2. 错误返回 Err
  }

  let context = match context {
    RdfContext::NQuadsRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Invalid context for NQuads",
          self.last_range,
        ),
      ) // 2. 错误返回 Err
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
    NQuadsState::ExpectDot => self.handle_expect_dot_m(event, context)
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "Unhandled state: \{nquads_state.to_string()}",
        self.last_range,
      )
      let new_self = self.add_error(err)
      Ok((new_self, nquads_state, None))
    }
  }
  // 将元组包装为 Ok
  match result {
    Ok((new_self, new_state, output)) =>
      Ok((new_self, new_state.as_state_enum(), output))
    Err(e) => Err(e)
  }
}

// 新增或修改辅助方法，只返回元组，不处理 Result 包装

///|
fn NQuadsRecognizer::process_transition_result_to_tuple(
  self : NQuadsRecognizer,
  current_state : NQuadsState,
  result : TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut], // 这里的 TransitionResult 可能是指 handle_xxx 的返回类型？
  // 假设 handle_xxx 返回的是 Result<(NQuadsRecognizer, NQuadsState, RdfOut?), RuleRecognizerError>
  // 或者它们直接返回元组？看原代码 process_transition_result 接收的是 TransitionResult
) -> (NQuadsRecognizer, RdfState, RdfOut?) {
  match result {
    Ok((new_self, new_state, output)) =>
      (new_self, new_state.as_state_enum(), output)
    Err(e) => {
      let new_self = self.add_error(e)
      (new_self, current_state.as_state_enum(), None)
    }
  }
}

///|
impl StateMachine for NQuadsRecognizer with fn is_accepting(
  self : NQuadsRecognizer,
) -> Bool {
  self.current_state() == RdfState::NQuadsState(NQuadsState::ExpectSubject) &&
  self.stack.is_empty()
}

///|
impl StateMachine for NQuadsRecognizer with fn context(self : NQuadsRecognizer) -> RdfContext {
  RdfContext::NQuadsRecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
  })
}

///|
impl StateMachine for NQuadsRecognizer with fn set_context(
  self : NQuadsRecognizer,
  context : RdfContext,
) -> NQuadsRecognizer {
  // 假设 NQuadsRecognizer 有一个 context 字段或者通过其他方式管理
  // 这里简单返回 self，实际可能需要更新内部状态
  self
}

///|
impl StateMachine for NQuadsRecognizer with fn[ST : StateWrapper] set_current_state(
  self : NQuadsRecognizer,
  state : ST,
) -> NQuadsRecognizer {
  let state = ST::as_state_enum(state)
  match state {
    RdfState::NQuadsState(s) => {
      // 返回一个新的 NQuadsRecognizer 实例，其中 stack 被更新
      // 假设有一个 with_stack 或类似的方法，或者直接构造新实例
      // 这里简化处理，实际需要根据 NQuadsRecognizer 的结构体定义来更新
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

// 辅助方法：统一处理 TransitionResult 并返回更新后的 Self

///|
fn NQuadsRecognizer::process_transition_result(
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
// 辅助方法：添加错误并返回新的实例

///|
fn NQuadsRecognizer::add_error(
  self : NQuadsRecognizer,
  err : RuleRecognizerError,
) -> NQuadsRecognizer {
  let new_errors = self.errors.clone()
  new_errors.push(err)
  { ..self, errors: new_errors }
}
