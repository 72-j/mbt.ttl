///|
pub trait StateMachine {
  fn initial_state(Self) -> RdfState
  fn transition(Self, state : RdfState, event : Event, context : RdfContext) -> TransitionResult[
    Self,
    RdfState,
    RdfOut,
  ]
  fn current_state(Self) -> RdfState
  fn step(Self, event : Event) -> Self
  fn reset(Self) -> Self
  fn is_accepting(Self) -> Bool
  fn context(Self) -> RdfContext
  fn set_context(Self, RdfContext) -> Self
  fn[ST : StateWrapper] set_current_state(Self, state : ST) -> Self
  fn error_recovery_statemachine(Self) -> Self
}

///|
/// 状态包装 Trait（用于类型擦除和统一处理）
pub trait StateWrapper {
  // fn to_str(Self) -> String
  fn as_state_enum(Self) -> RdfState
  // fn eq(Self, other : Self) -> Bool
  // fn clone(Self) -> Self
}

///|
pub trait IriComponents {
  fn query(self : Self) -> String?
  fn is_absolute(self : Self) -> Bool
  fn scheme(self : Self) -> String?
  fn authority(self : Self) -> String?
  fn path(self : Self) -> String?
  fn fragment(self : Self) -> String?
}

///|
pub trait StringRepr {
  fn as_stringview(self : Self) -> StringView
  fn into_string(self : Self) -> String
}

///|
pub impl StringRepr for Iri with fn as_stringview(self : Iri) -> StringView {
  self.base_iri
}

///|
pub impl StringRepr for Iri with fn into_string(self : Iri) -> String {
  self.base_iri
}

///|
pub impl StringRepr for IriRef with fn as_stringview(self : IriRef) -> StringView {
  self.val.base_iri
}

///|
pub impl StringRepr for IriRef with fn into_string(self : IriRef) -> String {
  self.val.base_iri
}

///|
pub trait TokenRecognizer {
  fn recognize_next_token(
    Self,
    data : ArrayView[Byte],
    is_ending : Bool,
    options : LexerOptions?,
    location_ctx : SourcePos,
  ) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])?
}

///|
pub trait RuleRecognizer {
  // asContextEnum(Self) -> RdfContext 
  fn error_recovery_state(Self) -> Self
  fn recognize_next(
    Self,
    token : LocatedTokenOrLineJump,
    context : RdfContext,
    results : Array[RdfOut],
  ) -> Self
  fn recognize_end(Self, context : RdfContext, results : Array[RdfOut]) -> Unit
  fn lexer_options(context : RdfContext) -> LexerOptions?
  fn[DL : DebugLogger] debug_logger(Self, debug_logger : DL) -> Unit
  // fn stack_signature(Self) -> Option[(Int, Option[String])]

}
