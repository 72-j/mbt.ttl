///|
pub trait StateMachine {
  fn initial_state(Self) -> RdfState
  fn transition(Self, state : RdfState, event : Event, context : RdfContext) -> TransitionResult[
    Self,
    RdfState,
    DataAction,
  ]
  fn current_state(Self) -> RdfState
  fn step(Self, event : Event) -> Self
  fn reset(Self) -> Self
  fn is_accepting(Self) -> Bool
  fn context(Self) -> RdfContext
  // fn set_context(Self, RdfContext) -> Self
  fn[ST : StateWrapper] set_current_state(Self, state : ST) -> Self
  fn error_recovery_statemachine(Self) -> Self
  fn accumulate(Self, dw : DataWorld, action : DataAction) -> (Self, DataWorld)
  fn get_and_clear_output(Self, dw : DataWorld) -> (Self, O?)
}

///|
pub trait StateWrapper {
  fn as_state_enum(Self) -> RdfState
}

///|
pub trait TokenRecognizer {
  fn recognize_next_token(
    Self,
    data : ArrayView[Byte],
    is_ending : Bool,
    options : LexerOptions?,
    location_pos : SourcePos,
  ) -> (Int, Result[LocatedToken, TokenRecognizerError])?
}

///|
pub trait RuleRecognizer {
  fn error_recovery_state(Self) -> Self
  // fn recognize_next(
  //   Self,
  //   token : LocatedTokenOrLineJump,
  //   context : RdfContext,
  //   results : Array[RdfOut],
  // ) -> Self
  fn recognize_end(Self, context : RdfContext, results : Array[RdfOut]) -> Unit
  fn lexer_options(context : RdfContext) -> LexerOptions?
  // fn[DL : DebugLogger] debug_logger(Self, debug_logger : DL) -> Unit
  // fn stack_signature(Self) -> Option[(Int, Option[String])]

}
