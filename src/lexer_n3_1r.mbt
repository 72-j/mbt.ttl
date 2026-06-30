// 1. 定义状态处理器的函数签名
// 注意：由于需要修改 self 并访问其他参数，我们传递可变引用或通过返回值更新状态
// 在 MoonBit 中，通常通过返回新的 Self 实例来体现状态变更

///|
type StateHandler = (
  N3Recognizer,
  LocatedTokenOrLineJump,
  RdfContext,
  Array[RdfOut],
  Array[RuleRecognizerError],
) -> N3Recognizer

///|
impl RuleRecognizer for N3Recognizer with fn recognize_next(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
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
        // 注意：如果 Handler 内部改变了 stack 并需要立即返回（如遇到 return self），
        // 这种函数式风格可能需要 Handler 返回一个包含“是否继续循环”标志的结构体，
        // 或者保持原有逻辑：如果 Handler 决定停止解析当前 Token，它应该通过某种方式信号告知。
        // 但在原有的命令式代码中，return self 会跳出 while 循环。
        // 为了完全兼容原有逻辑（即某些状态处理后直接返回，不再处理栈中下一个状态），
        // 我们需要 Handler 能够指示“提前终止”。

        // 简化方案：让 Handler 返回 Result<N3Recognizer, Bool> 或者类似结构？
        // 或者，我们保留 while 循环，但约定：如果 Handler 消费了 token 并准备结束本轮 recognize_next，
        // 它可以通过检查栈是否为空或特定标志来决定。

        // 鉴于 MoonBit 的简洁性，最直接的映射是将每个 case 变成函数调用。
        // 如果原代码中有 `return self`，这意味着退出 `recognize_next`。
        // 如果原代码只是修改状态并继续 while 循环，则继续。

        // 为了保持行为一致，我们可以让 handler 返回一个枚举：
        // enum HandleResult { Continue(N3Recognizer), Stop(N3Recognizer) }

        match self.handle_state(rule, token, context, results, errors) {
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
enum HandleResult {
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
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  match state {
    N3State::N3Doc => self.handle_n3_doc(token, context, results, errors)
    N3State::N3DocExpectDot =>
      self.handle_n3_doc_expect_dot(token, context, results, errors)
    N3State::BaseExpectIri =>
      self.handle_base_expect_iri(token, context, results, errors)
    N3State::PrefixExpectPrefix =>
      self.handle_prefix_expect_prefix(token, context, results, errors)
    N3State::PrefixExpectIri(name~) =>
      self.handle_prefix_expect_iri(name, token, context, results, errors)
    N3State::Triples => self.handle_triples(token, context, results, errors)
    N3State::TriplesMiddle =>
      self.handle_triples_middle(token, context, results, errors)
    N3State::TriplesEnd =>
      self.handle_triples_end(token, context, results, errors)
    N3State::PredicateObjectList =>
      self.handle_predicate_object_list(token, context, results, errors)
    N3State::PredicateObjectListEnd =>
      self.handle_predicate_object_list_end(token, context, results, errors)
    N3State::PredicateObjectListPossibleContinuation =>
      self.handle_predicate_object_list_possible_continuation(
        token, context, results, errors,
      )
    N3State::ObjectsList =>
      self.handle_objects_list(token, context, results, errors)
    N3State::ObjectsListEnd =>
      self.handle_objects_list_end(token, context, results, errors)
    N3State::Verb => self.handle_verb(token, context, results, errors)
    N3State::AfterRegularVerb =>
      self.handle_after_regular_verb(token, context, results, errors)
    N3State::AfterInvertedVerb =>
      self.handle_after_inverted_verb(token, context, results, errors)
    N3State::AfterVerbIs =>
      self.handle_after_verb_is(token, context, results, errors)
    N3State::Path => self.handle_path(token, context, results, errors)
    N3State::PathFollowUp =>
      self.handle_path_follow_up(token, context, results, errors)
    N3State::PathAfterIndicator(is_inverse~) =>
      self.handle_path_after_indicator(
        is_inverse, token, context, results, errors,
      )
    N3State::PathItem => self.handle_path_item(token, context, results, errors)
    N3State::PropertyListMiddle =>
      self.handle_property_list_middle(token, context, results, errors)
    N3State::PropertyListEnd =>
      self.handle_property_list_end(token, context, results, errors)
    N3State::IriPropertyList =>
      self.handle_iri_property_list(token, context, results, errors)
    N3State::CollectionBeginning =>
      self.handle_collection_beginning(token, context, results, errors)
    N3State::CollectionPossibleEnd =>
      self.handle_collection_possible_end(token, context, results, errors)
    N3State::LiteralPossibleSuffix(value~) =>
      self.handle_literal_possible_suffix(
        value, token, context, results, errors,
      )
    N3State::LiteralExpectDatatype(value~) =>
      self.handle_literal_expect_datatype(
        value, token, context, results, errors,
      )
    N3State::FormulaContent =>
      self.handle_formula_content(token, context, results, errors)
    N3State::FormulaContentExpectDot =>
      self.handle_formula_content_expect_dot(token, context, results, errors)
  }
}
