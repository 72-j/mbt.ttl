///|
pub(all) enum RdfState {
  TriGState(TriGState)
  NQuadsState(NQuadsState)
  N3State(N3State)
} derive(Eq, Hash)

///|
pub impl Show for RdfState with fn to_string(self) -> String {
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
pub impl StateWrapper for RdfState with fn as_state_enum(self) -> RdfState {
  self
}

///|
pub fn TriGState::to_str(self : TriGState) -> String {
  Show::to_string(self)
}

///|
pub impl StateMachine for TriGRecognizer with fn initial_state(
  _self : TriGRecognizer,
) -> RdfState {
  RdfState::TriGState(TriGState::TriGDoc)
}

///|
pub impl StateMachine for TriGRecognizer with fn error_recovery_statemachine(
  self,
) -> TriGRecognizer {
  self.error_recovery_state()
}

///|
pub impl StateMachine for TriGRecognizer with fn current_state(self) -> RdfState {
  // self.stack.last().unwrap_or(TriGState::TriGDoc).as_state_enum()
  self.current_state.as_state_enum()
}

///|
pub impl StateMachine for TriGRecognizer with fn step(self, event : Event) -> TriGRecognizer {
  let current_state = self.current_state()
  let result = self.transition(
    current_state.as_state_enum(),
    event,
    self.context(),
  )
  match result {
    Ok((new_machine, _new_state, _output)) => {
      let _new_context = new_machine.context()
      // let new_machine = new_machine.set_context(new_context)
      // let new_machine = new_machine.set_current_state(new_state)
      new_machine
    }
    Err(_e) => abort("Setp Error")
  }
}

///|
pub impl StateMachine for TriGRecognizer with fn reset(self) -> TriGRecognizer {
  self.error_recovery_state()
}

///|

///|
pub impl StateMachine for TriGRecognizer with fn transition(
  self : TriGRecognizer,
  state : RdfState,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, RdfState, RdfOut] {
  match event {
    LocatedToken(N3Token::LineJump, _) =>
      // 换行符不影响状态转换，直接保持当前状态
      return Ok((self, state, None))
    LocatedToken(N3Token::End, _) => {
      // 文件结束时的处理
      // 检查是否在可接受状态
      match state {
        RdfState::TriGState(_s) => ()
        _ =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Invalid state type for TriGRecognizer at end of input",
              self.last_range,
            ),
          )
      }

      // 如果栈为空，说明已正常结束
      if self.stack.length() == 0 {
        return Ok((self, state, None))
      }

      // 否则检查是否还有未处理的结束标记（如缺失的 .）
      return Err(
        RuleRecognizerError::SyntaxError(
          "Unexpected end of input (possibly missing '.')",
          self.last_range,
        ),
      )
    }
    _ => () // 继续正常处理
  }
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

  self.debug_logger.info("[impl transition] \{trig_state}, Token: \{event}")

  let result = match trig_state {
    TriGState::TriGDoc => self.handle_trig_doc(event, context)
    TriGState::TriplesOrGraph => self.handle_triples_or_graph(event, context)
    TriGState::WrappedGraphOrPredicateObjectList(term~) =>
      self.handle_wrapped_graph_or_predicate_object_list(term, event, context)
    TriGState::PredicateObjectList =>
      self.handle_predicate_object_list(event, context)
    TriGState::ObjectsList => self.handle_objects_list(event, context)
    TriGState::Object => self.handle_object(event, context)
    TriGState::PredicateObjectListEnd =>
      self.handle_predicate_object_list_end(event, context)
    TriGState::Verb => self.handle_verb(event, context)
    TriGState::ObjectCollectionBeginning =>
      self.handle_object_collection_beginning(event, context)
    TriGState::ObjectCollectionPossibleEnd =>
      self.handle_object_collection_possible_end(event, context)
    TriGState::WrappedGraph => self.handle_wrapped_graph(event, context)
    TriGState::WrappedGraphPossibleEnd =>
      self.handle_wrapped_graph_possible_end(event, context)
    TriGState::Triples => self.handle_triples(event, context)

    // ===== 指令与上下文处理 =====
    TriGState::ExpectAtKeyword => self.handle_expect_at_keyword(event, context)
    TriGState::BaseExpectIri => self.handle_base_expect_iri(event, context)
    TriGState::PrefixExpectPrefix =>
      self.handle_prefix_expect_prefix(event, context)
    TriGState::PrefixExpectIri(name~) =>
      self.handle_prefix_expect_iri(name, event, context)
    TriGState::VersionExpectVersion =>
      self.handle_version_expect_version(event, context)
    TriGState::ExpectDot => self.handle_expect_dot(event, context)

    // ===== 图名称处理 =====
    TriGState::GraphName => self.handle_graph_name(event, context)
    TriGState::GraphNameAnonEnd =>
      self.handle_graph_name_anon_end(event, context)

    // ===== 空白节点属性列表处理 =====
    TriGState::SubjectBlankNodePropertyListEnd =>
      self.handle_subject_blank_node_property_list_end(event, context)
    TriGState::SubjectBlankNodePropertyListAfter =>
      self.handle_subject_blank_node_property_list_after(event, context)
    TriGState::WrappedGraphBlankNodePropertyListCurrent =>
      self.handle_wrapped_graph_blank_node_property_list_current(event, context)
    TriGState::TriplesBlankNodePropertyListCurrent =>
      self.handle_triples_blank_node_property_list_current(event, context)
    TriGState::ObjectBlankNodePropertyListCurrent =>
      self.handle_object_blank_node_property_list_current(event, context)
    TriGState::ObjectBlankNodePropertyListEnd =>
      self.handle_object_blank_node_property_list_end(event, context) // 假设存在

    // ===== 集合处理 =====
    TriGState::SubjectCollectionBeginning =>
      self.handle_subject_collection_beginning(event, context)
    TriGState::SubjectCollectionPossibleEnd =>
      self.handle_subject_collection_possible_end(event, context)

    // ===== 字面量处理 =====
    TriGState::LiteralPossibleSuffix(value~, emit~) =>
      self.handle_literal_possible_suffix(value, emit, event, context) // 假设存在
    TriGState::LiteralExpectDatatype(value~, emit~) =>
      self.handle_literal_expect_datatype(value, emit, event, context)

    // ===== 引号三元组与重化处理 =====
    TriGState::ReifiedTripleSubject(is_reified~) =>
      self.handle_reified_triple_subject(is_reified, event, context)
    TriGState::ReifiedTripleObject(is_reified~) =>
      self.handle_reified_triple_object(is_reified, event, context)
    TriGState::SubjectReifiedTripleEnd =>
      self.handle_subject_reified_triple_end(event, context)
    TriGState::ObjectReifiedTripleEnd(emit~) =>
      self.handle_object_reified_triple_end(emit, event, context) // 假设存在
    TriGState::EndOfReifiedTripleBeforeReifier =>
      self.handle_end_of_reified_triple_before_reifier(event, context)
    TriGState::Reifier(triple~) => self.handle_reifier(triple, event, context)
    TriGState::TripleTermEnd(emit~) =>
      self.handle_triple_term_end(emit, event, context)
    TriGState::QuotedAnonEnd => self.handle_quoted_anon_end(event, context)

    // ===== 注解处理 =====
    TriGState::AnnotationEnd(with_reifier~) =>
      self.handle_annotation_end(with_reifier, event, context)

    // ===== 其他可能的状态 =====
    TriGState::MaybePredicateObjectList =>
      self.handle_maybe_predicate_object_list(event, context)
    TriGState::PredicateObjectListPossibleContinuation =>
      self.handle_predicate_object_list_possible_continuation(event, context)
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
  TriGRecognizer::process_transition_result(result)
}

///|
pub impl StateMachine for TriGRecognizer with fn is_accepting(
  self : TriGRecognizer,
) -> Bool {
  self.current_state() == RdfState::TriGState(TriGState::TriGDoc) &&
  self.stack.is_empty()
}

///|
pub impl StateMachine for TriGRecognizer with fn context(_self : TriGRecognizer) -> RdfContext {
  RdfContext::TriGRecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
    prefixes: Map([]),
  })
}



///|
pub impl StateMachine for TriGRecognizer with fn[ST : StateWrapper] set_current_state(
  self : TriGRecognizer,
  state : ST,
) -> TriGRecognizer {
  let state = ST::as_state_enum(state)
  match state {
    RdfState::TriGState(s) =>
      // 返回一个新的 TriGRecognizer 实例，其中 stack 被更新

      // let new_stack = self.stack
      // new_stack.push(s)
      { ..self, current_state: s }
    _ => self
  }
}

///|
fn TriGRecognizer::process_transition_result(
  result : TransitionResult[TriGRecognizer, TriGState, RdfOut],
) -> TransitionResult[TriGRecognizer, RdfState, RdfOut] {
  match result {
    Ok((new_self, new_state, output)) =>
      Ok((new_self, new_state.as_state_enum(), output))
    Err(e) => Err(e)
  }
}

///|
fn TriGRecognizer::add_error(
  self : TriGRecognizer,
  err : RuleRecognizerError,
) -> TriGRecognizer {
  let new_errors = self.errors
  new_errors.push(err)
  { ..self, errors: new_errors }
}
