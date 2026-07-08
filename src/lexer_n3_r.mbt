// 1. 定义状态处理器的函数签名

///|
// type StateHandler = (
//   N3Recognizer,
//   LocatedTokenOrLineJump,
//   RdfContext,
//   Array[RdfOut],
//   Array[RuleRecognizerError],
// ) -> N3Recognizer

///|
pub impl RuleRecognizer for N3Recognizer with fn recognize_next(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
) -> N3Recognizer {
  // 记录最后范围逻辑保持不变
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(located) =>
      match located {
        LocatedN3Token(_, range) => self.last_range = range
      }
    _ => ()
  }

  while true {
    match self.stack.pop() {
      Some(rule) =>
        // 2. 获取对应状态的 Handler
        // let handler = self.get_state_handler(rule)

        // 3. 执行 Handler

        // 为了保持行为一致，我们可以让 handler 返回一个枚举：
        // enum HandleResult { Continue(N3Recognizer), Stop(N3Recognizer) }

        match self.handle_state(rule, token, context, results) {
          HandleResult::Continue(new_self) => return new_self
          // 继续 while 循环处理栈中下一个状态
          HandleResult::Stop(new_self) => return new_self
        }
      _ => break
    }
  }

  // 末尾的标点处理逻辑
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => return self
    _ => self
  }
}

// 辅助枚举，用于控制 while 循环的流程

///|
pub enum HandleResult {
  Continue(N3Recognizer)
  Stop(N3Recognizer)
}

// 主分派函数

///|
fn N3Recognizer::handle_state(
  self : N3Recognizer,
  state : N3State,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
) -> HandleResult {
  match state {
    N3State::N3Doc => self.handle_n3_doc(token, context)
    N3State::N3DocExpectDot => self.handle_n3_doc_expect_dot(token, context)
    N3State::BaseExpectIri => self.handle_base_expect_iri(token, context)
    N3State::PrefixExpectPrefix =>
      self.handle_prefix_expect_prefix(token, context)
    N3State::PrefixExpectIri(name~) =>
      self.handle_prefix_expect_iri(name, token, context)
    N3State::Triples => self.handle_triples(token, context)
    N3State::TriplesMiddle => self.handle_triples_middle(token, context)
    N3State::TriplesEnd => self.handle_triples_end(token, context)
    N3State::PredicateObjectList =>
      self.handle_predicate_object_list(token, context)
    N3State::PredicateObjectListEnd =>
      self.handle_predicate_object_list_end(token, context)
    N3State::PredicateObjectListPossibleContinuation =>
      self.handle_predicate_object_list_possible_continuation(token, context)
    N3State::ObjectsList => self.handle_objects_list(token, context)
    N3State::ObjectsListEnd =>
      self.handle_objects_list_end(token, context, results)
    N3State::Verb => self.handle_verb(token, context)
    N3State::AfterRegularVerb => self.handle_after_regular_verb(token, context)
    N3State::AfterInvertedVerb =>
      self.handle_after_inverted_verb(token, context)
    N3State::AfterVerbIs => self.handle_after_verb_is(token, context)
    N3State::Path => self.handle_path(token, context)
    N3State::PathFollowUp => self.handle_path_follow_up(token, context)
    N3State::PathAfterIndicator(is_inverse~) =>
      self.handle_path_after_indicator(is_inverse, token, context, results)
    N3State::PathItem => self.handle_path_item(token, context)
    N3State::PropertyListMiddle =>
      self.handle_property_list_middle(token, context)
    N3State::PropertyListEnd => self.handle_property_list_end(token, context)
    N3State::IriPropertyList => self.handle_iri_property_list(token, context)
    N3State::CollectionBeginning =>
      self.handle_collection_beginning(token, context)
    N3State::CollectionPossibleEnd =>
      self.handle_collection_possible_end(token, context, results)
    N3State::LiteralPossibleSuffix(value~) =>
      self.handle_literal_possible_suffix(value, token, context)
    N3State::LiteralExpectDatatype(value~) =>
      self.handle_literal_expect_datatype(value, token, context)
    N3State::FormulaContent => self.handle_formula_content(token, context)
    N3State::FormulaContentExpectDot =>
      self.handle_formula_content_expect_dot(token, context)
  }
}
