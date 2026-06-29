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

///|
/// 状态包装 Trait（用于类型擦除和统一处理）
pub trait StateWrapper {
  // fn to_str(Self) -> String
  fn as_state_enum(Self) -> RdfState
  // fn eq(Self, other : Self) -> Bool
  // fn clone(Self) -> Self
}

// ===== 定义 Result 类型 =====

///|
pub type TransitionResult[TR, S, O] = Result[(TR, S, O?), RuleRecognizerError]

///|
pub type Event = LocatedTokenOrLineJump

// 为 RdfState 实现 StateWrapper，使其成为统一的状态载体

///|
// impl StateWrapper for RdfState with fn to_str(self) -> String {
//   match self {
//     RdfState::TriGState(s) => s.to_string()
//     RdfState::NQuadsState(s) => s.to_string()
//     RdfState::N3State(s) => s.to_string()
//   }
// }

///|
impl StateWrapper for RdfState with fn as_state_enum(self) -> RdfState {
  self
}

///|
// impl StateWrapper for RdfState with fn eq(self, other : RdfState) -> Bool {
//   self == other
// }

// ///|
// impl StateWrapper for RdfState with fn clone(self) -> RdfState {
//   self
// }

// 为 TriGState 实现辅助方法以便转换

///|
// fn TriGState::as_state_enum(self : TriGState) -> RdfState {
//   RdfState::TriGState(self)
// }

///|
fn TriGState::to_str(self : TriGState) -> String {
  Show::to_string(self)
}

///|
pub trait StateMachine {
  // 修改：返回 (Self, RdfState, RdfOut?) 以支持不可变状态更新
  fn initial_state(Self) -> RdfState
  fn transition(Self, state : RdfState, event : Event, context : RdfContext) -> TransitionResult[
    Self,
    RdfState,
    RdfOut,
  ]
  fn current_state(Self) -> RdfState // ← 必须提供
  fn step(Self, event : Event) -> Self
  fn reset(Self) -> Self
  fn is_accepting(Self) -> Bool
  fn context(Self) -> RdfContext
  fn set_context(Self, RdfContext) -> Self
  fn[ST : StateWrapper] set_current_state(Self, state : ST) -> Self
  fn error_recovery_statemachine(Self) -> Self
}

// ===== 泛型状态机引擎 =====

///|
pub struct GenericStateMachine[M] {
  machine : M
  context : RdfContext
  outputs : Array[RdfOut]
}
// fn[M: RuleRecognizer] GenericStateMachine::error_recovery_state(self: M) ->M  {
//   M::error_recovery_state(self)
// }

///|
fn[M] GenericStateMachine::GenericStateMachine(
  machine : M,
  context : RdfContext,
) -> GenericStateMachine[M] {
  GenericStateMachine::{ machine, context, outputs: [] }
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn initial_state(
  self : GenericStateMachine[M],
) -> RdfState {
  self.machine.initial_state()
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn error_recovery_statemachine(
  self : GenericStateMachine[M],
) -> GenericStateMachine[M] {
  self.error_recovery_statemachine()
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn current_state(
  self,
) -> RdfState {
  // 从栈中获取当前状态
  self.machine.current_state() // ← 委托给 machine
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn step(
  self,
  event : Event,
) -> GenericStateMachine[M] {
  let state_before = self.current_state()
  debug("step: state_before = \{state_before}")
  debug("step: event = \{event}")

  let current_state = self.machine.current_state() // ← 从 machine 获取

  let result = self.machine.transition(current_state, event, self.context)

  match result {
    Ok((new_machine, new_state, output)) => {
      // ✅ 新增调试：打印转换结果
      debug("step: transition successful")
      debug("step: new_state = \{new_state}")
      debug("step: output received = \{output}")
      
      let outputs = self.outputs
      if output is Some(o) {
        debug("step: pushing output to engine: \{o}") // ✅ 确认是否执行了 push
        outputs.push(o)
      } else {
        debug("step: no output generated in this step")
      }

      // ✅ 新增调试：打印新引擎的状态
      debug("step: new_engine outputs length = \{outputs.length()}")
      debug("step: new_machine is_accepting = \{new_machine.is_accepting()}")

      let new_engine = GenericStateMachine::{
        machine: new_machine,
        context: self.context,
        outputs,
      }
      new_engine
    }
    Err(e) => {
      debug("step: transition failed with error: \{e}") // ✅ 记录错误
      self.reset()
    }
  }
}
///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn reset(
  self,
) -> GenericStateMachine[M] {
  let new_machine = self.machine.error_recovery_statemachine()
  // let new_state = new_machine.initial_state()
  GenericStateMachine::{
    machine: new_machine,
    context: self.context,
    outputs: [],
  }
}

///|

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn transition(
  self : GenericStateMachine[M],
  state : RdfState,
  event : Event,
  context : RdfContext,
) -> TransitionResult[GenericStateMachine[M], RdfState, RdfOut] {
  // ✅ 1. 调用 machine.transition，返回 Result
  match self.machine.transition(state, event, context) {
    // ✅ 2. 成功：解构元组
    Ok((new_machine, new_state, output)) => {
      // 3. 构造新的 GenericStateMachine
      let new_gsm = GenericStateMachine::{
        machine: new_machine,
        context: self.context,
        outputs: self.outputs,
      }
      // 4. 返回 Ok
      Ok((new_gsm, new_state, output))
    }
    // ✅ 5. 错误：向上传播
    Err(e) => Err(e)
  }
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn is_accepting(
  self : GenericStateMachine[M],
) -> Bool {
  self.machine.is_accepting()
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn[
  ST : StateWrapper,
] set_current_state(self : GenericStateMachine[M], state : ST) -> GenericStateMachine[
  M,
] {
  let new_machine = self.machine.set_current_state(state)
  { machine: new_machine, context: self.context, outputs: self.outputs }
}

///|
fn[M : StateMachine] GenericStateMachine::run(
  self : GenericStateMachine[M],
  events : Array[Event],
) -> Result[Array[RdfOut], RuleRecognizerError]? {
  let mut current_machine = self.machine
  let mut current_state = current_machine.initial_state()
  let outputs : Array[RdfOut] = []
  let current_context = self.context

  for event in events {
    // ✅ 1. 匹配 Result
    match current_machine.transition(current_state, event, current_context) {
      // ✅ 2. 成功：解构元组
      Ok((next_machine, next_state, output)) => {
        current_machine = next_machine
        current_state = next_state

        if output is Some(o) {
          outputs.push(o)
        }

        if current_machine.is_accepting() {
          break
        }
      }
      // ✅ 3. 失败：返回错误
      Err(e) => return Some(Err(e))
    }
  }

  Some(Ok(outputs))
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn context(
  self : GenericStateMachine[M],
) -> RdfContext {
  self.context
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn set_context(
  self : GenericStateMachine[M],
  new_context : RdfContext,
) -> GenericStateMachine[M] {
  { machine: self.machine, context: new_context, outputs: self.outputs }
}

// ===== TriGRecognizer 实现 =====

///|
impl StateMachine for TriGRecognizer with fn initial_state(
  self : TriGRecognizer,
) -> RdfState {
  RdfState::TriGState(TriGState::TriGDoc)
}

///|
impl StateMachine for TriGRecognizer with fn error_recovery_statemachine(self) -> TriGRecognizer {
  // self.stack.clear()
  // self.stack.push(TriGState::TriGDoc)
  // self.cur_subject.clear()
  // self.cur_predicate.clear()
  // self.cur_object.clear()
  // self.cur_reifier.clear()
  // self.cur_graph = GraphName::DefaultGraph.as_ref()
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
impl StateMachine for TriGRecognizer with fn reset(self) -> TriGRecognizer {
  // 重置栈
  // self.stack.clear()
  // self.stack.push(TriGState::TriGDoc)

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

// 新增或修改辅助方法，只返回元组，不处理 Result 包装

///|
fn TriGRecognizer::process_transition_result_to_tuple(
  self : TriGRecognizer,
  current_state : TriGState,
  result : TransitionResult[TriGRecognizer, TriGState, RdfOut], // 这里的 TransitionResult 可能是指 handle_xxx 的返回类型？
  // 假设 handle_xxx 返回的是 Result<(TriGRecognizer, TriGState, RdfOut?), RuleRecognizerError>
  // 或者它们直接返回元组？看原代码 process_transition_result 接收的是 TransitionResult
) -> (TriGRecognizer, RdfState, RdfOut?) {
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
impl StateMachine for TriGRecognizer with fn is_accepting(self : TriGRecognizer) -> Bool {
  self.current_state() == RdfState::TriGState(TriGState::TriGDoc) &&
  self.stack.is_empty()
}

///|
impl StateMachine for TriGRecognizer with fn context(self : TriGRecognizer) -> RdfContext {
  RdfContext::TriGRecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
    prefixes: Map([]),
  })
}

///|
impl StateMachine for TriGRecognizer with fn set_context(
  self : TriGRecognizer,
  context : RdfContext,
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
      // 假设有一个 with_stack 或类似的方法，或者直接构造新实例
      // 这里简化处理，实际需要根据 TriGRecognizer 的结构体定义来更新
      let new_stack = self.stack.clone()
      new_stack.push(s)
      { ..self, stack: new_stack }
    }
    _ => self
  }
}

// 辅助方法：统一处理 TransitionResult 并返回更新后的 Self

///|
fn TriGRecognizer::process_transition_result(
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
  let new_errors = self.errors.clone()
  new_errors.push(err)
  { ..self, errors: new_errors }
}

///|
pub fn[M] GenericStateMachine::remove_first_output(
  self : GenericStateMachine[M],
) -> GenericStateMachine[M] {
  let new_outputs = if self.outputs.length() > 1 {
    // 从索引 1 到末尾
    self.outputs[1:].to_owned()
  } else {
    []
  }

  GenericStateMachine::{
    machine: self.machine,
    context: self.context,
    outputs: new_outputs,
  }
}
