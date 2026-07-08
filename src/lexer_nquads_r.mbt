///|
pub impl RuleRecognizer for NQuadsRecognizer with fn recognize_next(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
) -> NQuadsRecognizer {
  let ctx = match context {
    RdfContext::NQuadsRecognizerContext(c) => c
    _ => abort("Invalid context type")
  }

  // 更新 last_range
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(located) =>
      match located {
        LocatedN3Token(_, range) => self.last_range = range
      }
    _ => ()
  }

  // 弹出当前状态，默认为 ExpectSubject
  let current_state = self.stack.pop().unwrap_or(NQuadsState::ExpectSubject)

  // 分发到具体的 Handler 回调函数
  match current_state {
    NQuadsState::ExpectSubject =>
      self.handle_expect_subject(token, ctx, results)
    NQuadsState::ExpectPredicate =>
      self.handle_expect_predicate(token, ctx, results)
    NQuadsState::ExpectedObject =>
      self.handle_expected_object(token, ctx, results)
    NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~) =>
      self.handle_expect_literal_annotation_or_graph_name_or_dot(
        value, token, ctx, results,
      )
    NQuadsState::ExpectLiteralDatatype(value~) =>
      self.handle_expect_literal_datatype(value, token, ctx, results)
    NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple =>
      self.handle_expect_possible_graph_or_end_of_quoted_triple(
        token, ctx, results,
      )
    NQuadsState::ExpectDot => self.handle_expect_dot(token, ctx, results)
    NQuadsState::ExpectLineJump =>
      self.handle_expect_line_jump(token, ctx, results)
    NQuadsState::AfterQuotedTriple =>
      self.handle_after_quoted_triple(token, ctx, results)
    NQuadsState::RecoverToLineJump =>
      self.handle_recover_to_line_jump(token, ctx, results)
  }
}
