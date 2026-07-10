// ===== 泛型状态机引擎 =====

///|
pub(all) struct GenericStateMachine[M] {
  machine : M
  context : Ctx
  outputs : Array[O]
  mut debug_logger : &DebugLogger
}
// fn[M: RuleRecognizer] GenericStateMachine::error_recovery_state(self: M) ->M  {
//   M::error_recovery_state(self)
// }

///|
pub fn[M] GenericStateMachine::GenericStateMachine(
  machine : M,
  context : Ctx,
  debug_logger : &DebugLogger,
) -> GenericStateMachine[M] {
  GenericStateMachine::{ machine, context, outputs: [], debug_logger }
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn initial_state(
  self : GenericStateMachine[M],
) -> RdfState {
  self.machine.initial_state()
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn error_recovery_statemachine(
  self : GenericStateMachine[M],
) -> GenericStateMachine[M] {
  self.error_recovery_statemachine()
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn current_state(
  self,
) -> RdfState {
  // 从栈中获取当前状态
  self.machine.current_state() // ← 委托给 machine
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn step(
  self,
  event : Event,
) -> GenericStateMachine[M] {
  self.debug_logger.info(
    "event = \{event}, step: state_before = [\{self.current_state()}]",
  )

  let current_state = self.machine.current_state() // ← 从 machine 获取

  let result = self.machine.transition(current_state, event, self.context)

  match result {
    Ok((new_machine, new_state, output)) => {
      self.debug_logger.info(
        "step: new_state = \{new_state.to_string()}, output received = \{@debug.to_string(output)}",
      )

      let outputs = self.outputs
      if output is Some(o) {
        self.debug_logger.info("step: pushing output to engine: \{o}")
        outputs.push(o)
      }

      let updated_machine = new_machine.set_current_state(new_state)
      let new_engine = GenericStateMachine::{
        machine: updated_machine,
        context: self.context,
        outputs,
        debug_logger: self.debug_logger,
      }
      new_engine
    }
    Err(e) => {
      self.debug_logger.warn("step: transition failed with: \{e}")
      self.reset()
    }
  }
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn reset(
  self,
) -> GenericStateMachine[M] {
  let new_machine = self.machine.error_recovery_statemachine()
  // let new_state = new_machine.initial_state()
  GenericStateMachine::{
    machine: new_machine,
    context: self.context,
    outputs: [],
    debug_logger: self.debug_logger,
  }
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn transition(
  self : GenericStateMachine[M],
  state : RdfState,
  event : Event,
  context : Ctx,
) -> TransitionResult[GenericStateMachine[M], RdfState, O] {
  // ✅ 1. 调用 machine.transition，返回 Result
  match self.machine.transition(state, event, context) {
    // ✅ 2. 成功：解构元组
    Ok((new_machine, new_state, output)) => {
      // 3. 构造新的 GenericStateMachine
      let new_gsm = GenericStateMachine::{
        machine: new_machine,
        context: self.context,
        outputs: self.outputs,
        debug_logger: self.debug_logger,
      }
      // 4. 返回 Ok
      Ok((new_gsm, new_state, output))
    }
    // ✅ 5. 错误：向上传播
    Err(e) => Err(e)
  }
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn is_accepting(
  self : GenericStateMachine[M],
) -> Bool {
  self.machine.is_accepting()
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn[
  ST : StateWrapper,
] set_current_state(self : GenericStateMachine[M], state : ST) -> GenericStateMachine[
  M,
] {
  let new_machine = self.machine.set_current_state(state)
  {
    machine: new_machine,
    context: self.context,
    outputs: self.outputs,
    debug_logger: self.debug_logger,
  }
}

///|
pub fn[M : StateMachine] GenericStateMachine::run(
  self : GenericStateMachine[M],
  events : Array[Event],
) -> Result[Array[O], RuleRecognizerError]? {
  let mut current_machine = self.machine
  let mut current_state = current_machine.initial_state()
  let outputs : Array[O] = []
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
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn context(
  self : GenericStateMachine[M],
) -> Ctx {
  self.context
}

///|
pub impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn set_context(
  self : GenericStateMachine[M],
  new_context : Ctx,
) -> GenericStateMachine[M] {
  {
    machine: self.machine,
    context: new_context,
    outputs: self.outputs,
    debug_logger: self.debug_logger,
  }
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
    debug_logger: self.debug_logger,
  }
}
