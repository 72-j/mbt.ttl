// ===== 泛型状态机引擎 =====

///|
pub(all) struct GenericStateMachine[M] {
  machine : M
  context : Ctx
  outputs : Array[O]
  data_world : DataWorld
  debug_logger : &DebugLogger
  lexer_errors : Array[(String, ArrayView[Byte], Range)]
}

///|
pub fn[M] GenericStateMachine::GenericStateMachine(
  machine : M,
  context : Ctx,
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> GenericStateMachine[M] {
  GenericStateMachine::{
    machine,
    context,
    outputs: [],
    data_world: DataWorld::default(),
    debug_logger,
    lexer_errors: [],
  }
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn initial_state(
  self : GenericStateMachine[M],
) -> RdfState {
  self.machine.initial_state()
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn error_recovery_statemachine(
  self : GenericStateMachine[M],
) -> GenericStateMachine[M] {
  self.error_recovery_statemachine()
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn current_state(
  self,
) -> RdfState {
  // 从栈中获取当前状态
  self.machine.current_state() // ← 委托给 machine
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn step(
  self,
  event : Event,
) -> GenericStateMachine[M] {
  let state = self.machine.current_state()

  // 1. 调用 transition
  let (m1, next_state, action) = match
    self.machine.transition(state, event, self.context) {
    Ok(r) => r
    Err(e) => {
      self.debug_logger.warn("[GSM step] transition failed: \{e}")
      return self
    }
  }

  self.debug_logger.info("[GSM step] action: \{action}")

  // 2. 调用 accumulate
  let (m2, dw2) = m1.accumulate(self.data_world, action)
  self.debug_logger.info(
    "[GSM step] after accumulate: subs=\{dw2.subjects.length()}, preds=\{dw2.predicates.length()},objs=\{dw2.objects.length()}, temp_literal=\{@debug.to_string(dw2.temp_literal)}",
  )

  // 3. 调用 get_and_clear_output
  let (m3, output) = m2.get_and_clear_output(dw2)
  self.debug_logger.info("[GSM step] output: \{@debug.to_string(output)}")

  // 4. 收集 output
  let outputs = self.outputs
  if output is Some(o) {
    self.debug_logger.info("[GSM step] pushing output")
    outputs.push(o)
  }

  // 5. 更新 machine 状态
  let m4 = m3.set_current_state(next_state)

  // 6. 返回新的 GenericStateMachine
  GenericStateMachine::{
    machine: m4,
    context: self.context,
    outputs,
    data_world: dw2,
    debug_logger: self.debug_logger,
    lexer_errors: self.lexer_errors,
  }
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn reset(
  self,
) -> GenericStateMachine[M] {
  let new_machine = self.machine.error_recovery_statemachine()
  // let new_state = new_machine.initial_state()
  if self.lexer_errors.length() > 0 {
    let (msg, bytes, range) = self.lexer_errors.pop().unwrap()
    self.debug_logger.error(
      "[GSM step] lexer error: \{msg} at \{range.start} to \{range.end} \{@debug.debug(bytes)}",
    )
  }

  GenericStateMachine::{
    machine: new_machine,
    context: self.context,
    outputs: [],
    data_world: DataWorld::default(),
    debug_logger: self.debug_logger,
    lexer_errors: self.lexer_errors,
  }
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn is_accepting(
  self : GenericStateMachine[M],
) -> Bool {
  self.machine.is_accepting()
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn[
  ST : StateWrapper,
] set_current_state(self : GenericStateMachine[M], state : ST) -> GenericStateMachine[
  M,
] {
  let new_machine = self.machine.set_current_state(state)
  {
    machine: new_machine,
    context: self.context,
    outputs: self.outputs,
    data_world: self.data_world,
    debug_logger: self.debug_logger,
    lexer_errors: self.lexer_errors,
  }
}

///|
pub fn[M : GenMachine] GenericStateMachine::run(
  self : GenericStateMachine[M],
  events : Array[Event],
) -> Result[Array[DataAction], RuleRecognizerError]? {
  let mut current_machine = self.machine
  let mut current_state = current_machine.initial_state()
  let actions : Array[DataAction] = []
  let current_context = self.context

  for event in events {
    // ✅ 1. 匹配 Result
    match current_machine.transition(current_state, event, current_context) {
      // ✅ 2. 成功：解构元组
      Ok((next_machine, next_state, action)) => {
        current_machine = next_machine
        current_state = next_state

        // if output is Some(o) {
        actions.push(action)
        // }

        if current_machine.is_accepting() {
          break
        }
      }
      // ✅ 3. 失败：返回错误
      Err(e) => return Some(Err(e))
    }
  }

  Some(Ok(actions))
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn context(
  self : GenericStateMachine[M],
) -> Ctx {
  self.context
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn accumulate(
  self : GenericStateMachine[M],
  dw : DataWorld,
  da : DataAction,
) -> (GenericStateMachine[M], DataWorld) {
  let (m, dw) = self.machine.accumulate(dw, da)
  ({ ..self, machine: m }, dw)
}

///|
pub impl[M : GenMachine] GenMachine for GenericStateMachine[M] with fn get_and_clear_output(
  self : GenericStateMachine[M],
  data_world : DataWorld,
) -> (GenericStateMachine[M], RdfOut?) {
  let (m, output) = self.machine.get_and_clear_output(data_world)
  ({ ..self, machine: m }, output)
}

///|
pub fn[M] GenericStateMachine::set_context(
  self : GenericStateMachine[M],
  new_context : Ctx,
) -> GenericStateMachine[M] {
  {
    machine: self.machine,
    context: new_context,
    outputs: self.outputs,
    data_world: self.data_world,
    debug_logger: self.debug_logger,
    lexer_errors: self.lexer_errors,
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
    data_world: self.data_world,
    debug_logger: self.debug_logger,
    lexer_errors: self.lexer_errors,
  }
}
