// ===== 泛型状态机引擎 =====

///|
pub struct GenericStateMachine[M] {
  machine : M
  context : Ctx
  outputs : Array[O]
}
// fn[M: RuleRecognizer] GenericStateMachine::error_recovery_state(self: M) ->M  {
//   M::error_recovery_state(self)
// }

///|
fn[M] GenericStateMachine::GenericStateMachine(
  machine : M,
  context : Ctx,
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
  debug("step: state_before = [\{state_before}]")
  debug("step: event = \{event}")

  let current_state = self.machine.current_state() // ← 从 machine 获取

  let result = self.machine.transition(current_state, event, self.context)

  match result {
    Ok((new_machine, new_state, output)) => {
      // ✅ 新增调试：打印转换结果
      debug("step: transition successful")
      debug("step: new_state = \{new_state}")
      debug("step: output received = \{@debug.to_string(output)}")

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
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn context(
  self : GenericStateMachine[M],
) -> Ctx {
  self.context
}

///|
impl[M : StateMachine] StateMachine for GenericStateMachine[M] with fn set_context(
  self : GenericStateMachine[M],
  new_context : Ctx,
) -> GenericStateMachine[M] {
  { machine: self.machine, context: new_context, outputs: self.outputs }
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
