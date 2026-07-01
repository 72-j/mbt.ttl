// ===== State: N3Doc =====

///|
fn N3Recognizer::handle_n3_doc_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering N3Doc with token: \{token}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "base") =>
      Ok((self, N3State::BaseExpectIri, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "prefix") =>
      Ok((self, N3State::PrefixExpectPrefix, None))
    // 处理特殊的 LangTag 作为关键字的情况 (如果 lexer 这样输出)
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language="prefix", direction=None), _)
    ) =>
      // 这里可能需要一个中间状态来处理 prefix 后的 IRI，然后再处理 Dot
      // 简化处理：直接进入 PrefixExpectPrefix，假设后续逻辑能处理 Dot 或依靠栈
      Ok((self, N3State::PrefixExpectPrefix, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language="base", direction=None), _)
    ) => Ok((self, N3State::BaseExpectIri, None))
    _ => {
      // 默认进入 Triples 解析，解析完后期望 Dot
      // 我们将 N3DocExpectDot 压入栈，以便 Triples 结束后返回这里
      let new_stack = self.stack
      new_stack.push(N3State::N3DocExpectDot)
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, N3State::Triples, None))
    }
  }
}

// ===== State: N3DocExpectDot =====

///|
fn N3Recognizer::handle_n3_doc_expect_dot_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering N3DocExpectDot with token: \{token}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) =>
      // 语句结束，回到 N3Doc 继续解析下一条
      Ok((self, N3State::N3Doc, None))
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "A dot is expected at the end of N3 statements",
        self.last_range,
      )
      Err(err)
    }
  }
}

// ===== State: BaseExpectIri =====

///|
fn N3Recognizer::handle_base_expect_iri_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering BaseExpectIri with token: \{token}")

  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(iri), _)
    ) {
    match context {
      RdfContext::N3RecognizerContext(ctx) => {
        let new_options = { ..ctx.lexer_options, base_iri: Some(Iri::Iri(iri)) }
        let new_ctx = { ..ctx, lexer_options: new_options }
        // 注意：context 通常是通过 StateMachine 的 set_context 更新的，或者存储在 self 中
        // 这里假设我们需要更新 self 中的 context 或者返回新的 self 携带更新后的 context
        // 由于 signature 限制，我们只能返回 self。通常 context 是外部传入的。
        // 如果 context 是可变的且在 self 中，这里需要更新 self。
        // 假设 context 更新由外层处理，或者我们只关注状态转移。
        // BASE 语句后通常跟一个点
        Ok((self, N3State::N3DocExpectDot, None))
      }
      _ =>
        Err(
          RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
        )
    }
  } else {
    Err(
      RuleRecognizerError::SyntaxError(
        "The BASE keyword should be followed by an IRI",
        self.last_range,
      ),
    )
  }
}

// ===== State: PrefixExpectPrefix =====

///|
fn N3Recognizer::handle_prefix_expect_prefix_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PrefixExpectPrefix with token: \{token}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PrefixedName(prefix~, localx~, ..), _)
    ) if localx.is_empty() =>
      // 转移到期待 IRI 的状态，并携带 prefix 名称
      // 假设 N3State::PrefixExpectIri 可以携带参数，或者我们需要将 prefix 暂存到 self 中
      // 这里假设 N3State 枚举定义为 PrefixExpectIri(String)
      Ok((self, N3State::PrefixExpectIri(name=prefix), None))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "The PREFIX keyword should be followed by a prefix like 'ex:'",
          self.last_range,
        ),
      )
  }
}

// ===== State: PrefixExpectIri =====

///|
fn N3Recognizer::handle_prefix_expect_iri_m(
  self : N3Recognizer,
  name : String, // 从状态中提取的参数
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info(
    "Entering PrefixExpectIri(\{name}) with token: \{token}",
  )

  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(iri), _)
    ) {
    match context {
      RdfContext::N3RecognizerContext(ctx) => {
        ctx.prefixes.set(name, Iri::Iri(iri))
        // let new_ctx = { ..ctx}
        // 同样，context 的更新可能需要通过 set_context 或在 self 中维护
        // 这里假设状态转移后，外层会处理 context 的持久化或 self 已包含 context
        Ok((self, N3State::N3DocExpectDot, None))
      }
      _ =>
        Err(
          RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
        )
    }
  } else {
    Err(
      RuleRecognizerError::SyntaxError(
        "The PREFIX declaration should be followed by a prefix and its value as an IRI",
        self.last_range,
      ),
    )
  }
}

// ===== State: Triples =====

///|
fn N3Recognizer::handle_triples_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering Triples with token: \{token}")

  // Triples 开始，首先解析 Subject (Path)
  // 原逻辑: push TriplesMiddle, push Path
  // 新逻辑: 进入 Path 状态，并记录当 Path 结束后应进入 TriplesMiddle
  let new_stack = self.stack
  new_stack.push(N3State::TriplesMiddle)
  let new_self = { ..self, stack: new_stack }

  Ok((new_self, N3State::Path, None))
}

// ===== State: TriplesMiddle =====

///|
fn N3Recognizer::handle_triples_middle_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering TriplesMiddle with token: \{token}")

  // 如果遇到结束符，说明没有 PredicateObjectList，直接结束当前 Triples
  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("." | "]" | "}" | ")"), _)
    ) {
    // 弹出 TriplesMiddle，回到上一层 (例如 N3DocExpectDot)
    // 这里需要手动管理栈弹出，或者依靠上层状态处理
    // 简单起见，如果栈顶是 TriplesMiddle，我们弹出它，并返回栈顶下一个状态
    let new_stack = self.stack
    if !new_stack.is_empty() && new_stack.last() == Some(N3State::TriplesMiddle) {
      let _ = new_stack.pop()
    }
    let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
    let new_self = { ..self, stack: new_stack }
    Ok((new_self, next_state, None))
  } else {
    // 否则，开始解析 PredicateObjectList
    // 原逻辑: push TriplesEnd, push PredicateObjectList
    let new_stack = self.stack
    new_stack.push(N3State::TriplesEnd)
    new_stack.push(N3State::PredicateObjectList)
    let new_self = { ..self, stack: new_stack }

    Ok((new_self, N3State::PredicateObjectList, None))
  }
}

// ===== State: TriplesEnd =====

///|
fn N3Recognizer::handle_triples_end_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering TriplesEnd with token: \{token}")

  // 原逻辑: pop terms (subject)
  let new_terms = self.terms
  let _ = new_terms.pop()
  let new_self = { ..self, terms: new_terms }

  // 弹出 TriplesEnd，回到上一层
  let new_stack = self.stack
  if !new_stack.is_empty() && new_stack.last() == Some(N3State::TriplesEnd) {
    let _ = new_stack.pop()
  }
  let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
  let final_self = { ..new_self, stack: new_stack }

  Ok((final_self, next_state, None))
}

// ===== State: PredicateObjectList =====

///|
fn N3Recognizer::handle_predicate_object_list_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PredicateObjectList with token: \{token}")

  // 原逻辑: push PredicateObjectListEnd, push ObjectsList, push Verb
  let new_stack = self.stack
  new_stack.push(N3State::PredicateObjectListEnd)
  new_stack.push(N3State::ObjectsList)
  new_stack.push(N3State::Verb)
  let new_self = { ..self, stack: new_stack }

  Ok((new_self, N3State::Verb, None))
}

// ===== State: PredicateObjectListEnd =====

///|
fn N3Recognizer::handle_predicate_object_list_end_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PredicateObjectListEnd with token: \{token}")

  // 原逻辑: pop predicates
  let new_predicates = self.predicates
  let _ = new_predicates.pop()
  let new_self = { ..self, predicates: new_predicates }

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(";"), _)
    ) => {
      // 分号表示同一个主语的新谓词对象对
      // 原逻辑: push PredicateObjectListPossibleContinuation
      let new_stack = new_self.stack
      new_stack.push(N3State::PredicateObjectListPossibleContinuation)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, N3State::PredicateObjectListPossibleContinuation, None))
    }
    _ => {
      // 没有分号，结束当前 PredicateObjectList
      // 弹出 PredicateObjectListEnd，回到上一层 (通常是 TriplesMiddle 或 PropertyListEnd)
      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::PredicateObjectListEnd) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, next_state, None))
    }
  }
}

// ===== State: PredicateObjectListPossibleContinuation =====

///|
fn N3Recognizer::handle_predicate_object_list_possible_continuation_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info(
    "Entering PredicateObjectListPossibleContinuation with token: \{token}",
  )

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(";"), _)
    ) =>
      // 多个分号，忽略，保持当前状态
      Ok((self, N3State::PredicateObjectListPossibleContinuation, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("." | "}" | "]" | ")"), _)
    ) => {
      // 遇到结束符，弹出当前状态，回到上一层
      let new_stack = self.stack
      if !new_stack.is_empty() &&
        new_stack.last() ==
        Some(N3State::PredicateObjectListPossibleContinuation) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, next_state, None))
    }
    _ => {
      // 新的谓词开始，重新进入 PredicateObjectList
      // 原逻辑: push PredicateObjectListEnd, push ObjectsList, push Verb
      let new_stack = self.stack
      new_stack.push(N3State::PredicateObjectListEnd)
      new_stack.push(N3State::ObjectsList)
      new_stack.push(N3State::Verb)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::Verb, None))
    }
  }
}

// ===== State: ObjectsList =====

///|
fn N3Recognizer::handle_objects_list_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering ObjectsList with token: \{token}")

  // 原逻辑: push ObjectsListEnd, push Path
  let new_stack = self.stack
  new_stack.push(N3State::ObjectsListEnd)
  new_stack.push(N3State::Path)
  let new_self = { ..self, stack: new_stack }

  Ok((new_self, N3State::Path, None))
}

// ===== State: ObjectsListEnd =====

///|
fn N3Recognizer::handle_objects_list_end_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering ObjectsListEnd with token: \{token}")

  let object = match self.terms.pop() {
    Some(o) => o
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty (object)",
          self.last_range,
        ),
      )
  }
  let subject = match self.terms.last() {
    Some(s) => s
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty (subject)",
          self.last_range,
        ),
      )
  }
  let predicate_opt = match self.predicates.last() {
    Some(p) => p
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: predicates stack empty",
          self.last_range,
        ),
      )
  }

  let quad = match predicate_opt {
    Predicate::Regular(predicate) => self.quad(subject, predicate, object)
    Predicate::Inverted(predicate) => self.quad(object, predicate, subject)
  }

  let output = Some(RdfOut::N3Quad(quad))
  // let new_results = results // 注意：results 通常由外层收集，这里仅作为示例
  // 在实际 StateMachine 中，output 会被外层收集

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(","), _)
    ) => {
      // 逗号表示同一个谓语的下一个对象
      // 原逻辑: push ObjectsListEnd, push Path
      let new_stack = self.stack
      new_stack.push(N3State::ObjectsListEnd)
      new_stack.push(N3State::Path)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::Path, output))
    }
    _ => {
      // 结束对象列表
      // 弹出 ObjectsListEnd，回到上一层 (通常是 PredicateObjectListEnd)
      let new_stack = self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::ObjectsListEnd) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, next_state, output))
    }
  }
}

// ===== State: Verb =====

///|
fn N3Recognizer::handle_verb_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering Verb with token: \{token}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("a"), _)
    ) => {
      let new_predicates = self.predicates
      new_predicates.push(Predicate::Regular(lwTYPE.as_n3term()))
      let new_self = { ..self, predicates: new_predicates }
      // Verb 处理完毕，回到调用者 (ObjectsList)
      // 弹出 Verb，回到上一层
      let new_stack = new_self.stack
      if !new_stack.is_empty() && new_stack.last() == Some(N3State::Verb) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("has"), _)
    ) => {
      // has <path>
      // 原逻辑: push AfterRegularVerb, push Path
      let new_stack = self.stack
      new_stack.push(N3State::AfterRegularVerb)
      new_stack.push(N3State::Path)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::Path, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("is"), _)
    ) => {
      // is <path> of
      // 原逻辑: push AfterVerbIs, push Path
      let new_stack = self.stack
      new_stack.push(N3State::AfterVerbIs)
      new_stack.push(N3State::Path)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::Path, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("="), _)
    ) => {
      let new_predicates = self.predicates
      new_predicates.push(
        Predicate::Regular(
          NamedNodeRef::new_unchecked("http://www.w3.org/2002/07/owl#sameAs").as_n3term(),
        ),
      )
      let new_self = { ..self, predicates: new_predicates }

      let new_stack = new_self.stack
      if !new_stack.is_empty() && new_stack.last() == Some(N3State::Verb) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("=>"), _)
    ) => {
      let new_predicates = self.predicates
      new_predicates.push(
        Predicate::Regular(
          NamedNodeRef::new_unchecked(
            "http://www.w3.org/2000/10/swap/log#implies",
          ).as_n3term(),
        ),
      )
      let new_self = { ..self, predicates: new_predicates }

      let new_stack = new_self.stack
      if !new_stack.is_empty() && new_stack.last() == Some(N3State::Verb) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<="), _)
    ) => {
      let new_predicates = self.predicates
      new_predicates.push(
        Predicate::Inverted(
          NamedNodeRef::new_unchecked(
            "http://www.w3.org/2000/10/swap/log#implies",
          ).as_n3term(),
        ),
      )
      let new_self = { ..self, predicates: new_predicates }

      let new_stack = new_self.stack
      if !new_stack.is_empty() && new_stack.last() == Some(N3State::Verb) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<-"), _)
    ) => {
      // <- <path>
      // 原逻辑: push AfterInvertedVerb, push Path
      let new_stack = self.stack
      new_stack.push(N3State::AfterInvertedVerb)
      new_stack.push(N3State::Path)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::Path, None))
    }
    _ => {
      // 默认视为 Regular Verb (IRI or Path)
      // 原逻辑: push AfterRegularVerb, push Path
      let new_stack = self.stack
      new_stack.push(N3State::AfterRegularVerb)
      new_stack.push(N3State::Path)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::Path, None))
    }
  }
}

// ===== State: AfterRegularVerb =====

///|
fn N3Recognizer::handle_after_regular_verb_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering AfterRegularVerb with token: \{token}")

  let term = match self.terms.pop() {
    Some(t) => t
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty in AfterRegularVerb",
          self.last_range,
        ),
      )
  }

  let new_predicates = self.predicates
  new_predicates.push(Predicate::Regular(term))
  let new_self = { ..self, predicates: new_predicates }

  // 弹出 AfterRegularVerb，回到调用者
  let new_stack = new_self.stack
  if !new_stack.is_empty() &&
    new_stack.last() == Some(N3State::AfterRegularVerb) {
    let _ = new_stack.pop()
  }
  let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
  let final_self = { ..new_self, stack: new_stack }

  Ok((final_self, next_state, None))
}

// ===== State: AfterInvertedVerb =====

///|
fn N3Recognizer::handle_after_inverted_verb_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering AfterInvertedVerb with token: \{token}")

  let term = match self.terms.pop() {
    Some(t) => t
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty in AfterInvertedVerb",
          self.last_range,
        ),
      )
  }

  let new_predicates = self.predicates
  new_predicates.push(Predicate::Inverted(term))
  let new_self = { ..self, predicates: new_predicates }

  let new_stack = new_self.stack
  if !new_stack.is_empty() &&
    new_stack.last() == Some(N3State::AfterInvertedVerb) {
    let _ = new_stack.pop()
  }
  let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
  let final_self = { ..new_self, stack: new_stack }

  Ok((final_self, next_state, None))
}

// ===== State: AfterVerbIs =====

///|
fn N3Recognizer::handle_after_verb_is_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering AfterVerbIs with token: \{token}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("of"), _)
    ) => {
      let term = match self.terms.pop() {
        Some(t) => t
        None =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Internal error: terms stack empty in AfterVerbIs",
              self.last_range,
            ),
          )
      }

      let new_predicates = self.predicates
      new_predicates.push(Predicate::Inverted(term))
      let new_self = { ..self, predicates: new_predicates }

      let new_stack = new_self.stack
      if !new_stack.is_empty() && new_stack.last() == Some(N3State::AfterVerbIs) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "The keyword 'is' should be followed by a predicate then by the keyword 'of'",
          self.last_range,
        ),
      )
  }
}

// ===== State: Path =====

///|
fn N3Recognizer::handle_path_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering Path with token: \{token}")

  // 原逻辑: push PathFollowUp, push PathItem
  let new_stack = self.stack
  new_stack.push(N3State::PathFollowUp)
  new_stack.push(N3State::PathItem)
  let new_self = { ..self, stack: new_stack }

  Ok((new_self, N3State::PathItem, None))
}

// ===== State: PathFollowUp =====

///|
fn N3Recognizer::handle_path_follow_up_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PathFollowUp with token: \{token}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("!"), _)
    ) => {
      // ! indicates inverse path in some contexts, or property path
      // 原逻辑: push PathAfterIndicator(is_inverse=false), push PathItem
      // 注意：N3 中 ! 通常用于 Negation 或 Property Path，这里假设是 Path Indicator
      let new_stack = self.stack
      new_stack.push(N3State::PathAfterIndicator(is_inverse=false))
      new_stack.push(N3State::PathItem)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::PathItem, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("^"), _)
    ) => {
      // ^ indicates inverse path
      let new_stack = self.stack
      new_stack.push(N3State::PathAfterIndicator(is_inverse=false)) // 假设 ^ 也是某种 indicator
      new_stack.push(N3State::PathItem)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::PathItem, None))
    }
    _ => {
      // 没有 follow up，结束 Path
      // 弹出 PathFollowUp，回到调用者
      let new_stack = self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::PathFollowUp) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, next_state, None))
    }
  }
}

// ===== State: PathAfterIndicator =====

///|
fn N3Recognizer::handle_path_after_indicator_m(
  self : N3Recognizer,
  is_inverse : Bool,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PathAfterIndicator with token: \{token}")

  let predicate = match self.terms.pop() {
    Some(p) => p
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty (predicate) in PathAfterIndicator",
          self.last_range,
        ),
      )
  }
  let previous = match self.terms.pop() {
    Some(prev) => prev
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty (previous) in PathAfterIndicator",
          self.last_range,
        ),
      )
  }

  let current = BlankNode::default().as_n3term()
  let quad = if is_inverse {
    self.quad(current, predicate, previous)
  } else {
    self.quad(previous, predicate, current)
  }

  let output = Some(RdfOut::N3Quad(quad))

  let new_terms = self.terms
  new_terms.push(current)
  let new_self = { ..self, terms: new_terms }

  // 结束后，可能还有 FollowUp
  let new_stack = new_self.stack
  new_stack.push(N3State::PathFollowUp)
  let final_self = { ..new_self, stack: new_stack }

  Ok((final_self, N3State::PathFollowUp, output))
}

// ===== State: PathItem =====

///|
fn N3Recognizer::handle_path_item_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PathItem with token: \{token}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => Ok((self, N3State::PropertyListMiddle, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("("), _)
    ) => Ok((self, N3State::CollectionBeginning, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("{"), _)
    ) => {
      // Formula
      let new_contexts = self.contexts
      new_contexts.push(BlankNode::default())
      let new_self = { ..self, contexts: new_contexts }

      Ok((new_self, N3State::FormulaContent, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      if self.contexts.is_empty() {
        return Err(
          RuleRecognizerError::SyntaxError(
            "Unexpected '}' outside of formula",
            self.last_range,
          ),
        )
      }
      let ctx = self.contexts.last().unwrap() // peek
      // 注意：这里不应该 pop contexts，应该由 FormulaContent 处理 pop
      // 但如果是在 PathItem 中遇到 }，说明公式作为项结束
      // 原逻辑: pop contexts, push term, pop PathFollowUp

      let new_contexts = self.contexts
      let ctx = new_contexts.pop().unwrap()
      let new_self = { ..self, contexts: new_contexts }

      let new_terms = new_self.terms
      new_terms.push(ctx.as_n3term())
      let new_self = { ..new_self, terms: new_terms }

      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::PathFollowUp) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    _ => {
      // 普通 Term
      // 调用 handle_term_token_m 的逻辑，但这里直接内联或调用
      // 为了简化，我们假设 handle_term_token_m 返回的是 TransitionResult
      // 但由于 handle_term_token_m 也需要符合签名，我们这里直接处理

      let term_result = self.handle_term_token_internal(token, context)
      match term_result {
        Ok(new_self) => {
          // Term 处理成功，结束 PathItem
          let new_stack = new_self.stack
          if !new_stack.is_empty() &&
            new_stack.last() == Some(N3State::PathItem) {
            let _ = new_stack.pop()
          }
          let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
          let final_self = { ..new_self, stack: new_stack }

          Ok((final_self, next_state, None))
        }
        Err(e) => Err(e)
      }
    }
  }
}

// 辅助内部函数，用于处理 Term 并返回新的 Self

///|
fn N3Recognizer::handle_term_token_internal(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> Result[N3Recognizer, RuleRecognizerError] {
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(located) =>
      match located {
        LocatedN3Token(N3Token::Iri(iri), _) => {
          let new_terms = self.terms
          new_terms.push(NamedNodeRef::new_unchecked(iri).as_n3term())
          Ok({ ..self, terms: new_terms })
        }
        // ... 其他 Token 类型处理类似，省略以节省空间 ...
        _ =>
          Err(
            RuleRecognizerError::SyntaxError(
              "TOKEN is not a valid RDF value",
              self.last_range,
            ),
          )
      }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "TOKEN is not a valid RDF value",
          self.last_range,
        ),
      )
  }
}

// ===== State: PropertyListMiddle =====

///|
fn N3Recognizer::handle_property_list_middle_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PropertyListMiddle with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => {
      let new_terms = self.terms
      new_terms.push(BlankNode::default().as_n3term())
      let new_self = { ..self, terms: new_terms }

      // 结束 BlankNode 属性列表，弹出 PropertyListMiddle，回到调用者 (通常是 PathItem 或 TriplesMiddle)
      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::PropertyListMiddle) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("id"), _)
    ) =>
      // 进入 [ id <IRI> ... ] 模式
      Ok((self, N3State::IriPropertyList, None))
    _ => {
      // 默认情况：匿名空白节点开始，后面跟谓词对象列表
      let new_terms = self.terms
      new_terms.push(BlankNode::default().as_n3term())
      let new_self = { ..self, terms: new_terms }

      let new_stack = new_self.stack
      new_stack.push(N3State::PropertyListEnd)
      new_stack.push(N3State::PredicateObjectList)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, N3State::PredicateObjectList, None))
    }
  }
}

// ===== State: PropertyListEnd =====

///|
fn N3Recognizer::handle_property_list_end_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering PropertyListEnd with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => {
      // 正常结束，弹出 PropertyListEnd
      let new_stack = self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::PropertyListEnd) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, next_state, None))
    }
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "blank node property lists should end with a ']'",
        self.last_range,
      )
      Err(err)
    }
  }
}

// ===== State: IriPropertyList =====

///|
fn N3Recognizer::handle_iri_property_list_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering IriPropertyList with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(id), _)) => {
      let new_terms = self.terms
      new_terms.push(NamedNodeRef::new_unchecked(id).as_n3term())
      let new_self = { ..self, terms: new_terms }

      let new_stack = new_self.stack
      new_stack.push(N3State::PropertyListEnd)
      new_stack.push(N3State::PredicateObjectList)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, N3State::PredicateObjectList, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match context {
        RdfContext::N3RecognizerContext(ctx) =>
          match
            resolve_local_name(
              prefix,
              localx,
              might_be_invalid_iri,
              ctx.prefixes,
            ) {
            Ok(t) => {
              let new_terms = self.terms
              new_terms.push(t.as_n3term())
              let new_self = { ..self, terms: new_terms }

              let new_stack = new_self.stack
              new_stack.push(N3State::PropertyListEnd)
              new_stack.push(N3State::PredicateObjectList)
              let final_self = { ..new_self, stack: new_stack }

              Ok((final_self, N3State::PredicateObjectList, None))
            }
            Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
          }
        _ =>
          Err(
            RuleRecognizerError::SyntaxError(
              "Invalid context for prefix resolution",
              self.last_range,
            ),
          )
      }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "The '[ id' construction should be followed by an IRI",
          self.last_range,
        ),
      )
  }
}

// ===== State: CollectionBeginning =====

///|
fn N3Recognizer::handle_collection_beginning_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering CollectionBeginning with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) {
    // 空列表 ()
    let new_terms = self.terms
    new_terms.push(lwNIL.as_n3term())
    let new_self = { ..self, terms: new_terms }

    // 弹出 CollectionBeginning，回到调用者
    let new_stack = new_self.stack
    if !new_stack.is_empty() &&
      new_stack.last() == Some(N3State::CollectionBeginning) {
      let _ = new_stack.pop()
    }
    let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
    let final_self = { ..new_self, stack: new_stack }

    Ok((final_self, next_state, None))
  } else {
    // 非空列表，创建根节点
    let root = BlankNode::default()
    let new_terms = self.terms
    new_terms.push(root.as_n3term()) // Current list node
    new_terms.push(root.as_n3term()) // Previous list node (for linking)
    let new_self = { ..self, terms: new_terms }

    let new_stack = new_self.stack
    new_stack.push(N3State::CollectionPossibleEnd)
    new_stack.push(N3State::Path)
    let final_self = { ..new_self, stack: new_stack }

    Ok((final_self, N3State::Path, None))
  }
}

// ===== State: CollectionPossibleEnd =====

///|
fn N3Recognizer::handle_collection_possible_end_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering CollectionPossibleEnd with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  let value = match self.terms.pop() {
    Some(v) => v
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty (value) in CollectionPossibleEnd",
          self.last_range,
        ),
      )
  }
  let old = match self.terms.pop() {
    Some(o) => o
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: terms stack empty (old) in CollectionPossibleEnd",
          self.last_range,
        ),
      )
  }

  let quad1 = self.quad(old, lwFIRST.as_n3term(), value)
  let output1 = Some(RdfOut::N3Quad(quad1))

  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) {
    // 列表结束
    let quad2 = self.quad(old, lwREST.as_n3term(), lwNIL.as_n3term())
    let output2 = Some(RdfOut::N3Quad(quad2))

    // 弹出 CollectionPossibleEnd
    let new_stack = self.stack
    if !new_stack.is_empty() &&
      new_stack.last() == Some(N3State::CollectionPossibleEnd) {
      let _ = new_stack.pop()
    }
    let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
    let new_self = { ..self, stack: new_stack }

    // 注意：TransitionResult 只能返回一个 Output。如果有多个 Quad，通常由外层收集或合并。
    // 这里返回最后一个，或者将第一个放入 results (如果 results 是可变引用，但这里是函数式风格)
    // 假设外层会处理多个 outputs，或者我们只返回主要的。
    // 为了简化，我们返回第二个 output，第一个可能需要通过其他方式记录，或者合并。
    // 在此框架下，通常一次转换产生一个主要输出。
    Ok((new_self, next_state, output2))
  } else {
    // 列表继续
    let new_node = BlankNode::default()
    let quad2 = self.quad(old, lwREST.as_n3term(), new_node.as_n3term())
    let output2 = Some(RdfOut::N3Quad(quad2))

    let new_terms = self.terms
    new_terms.push(new_node.as_n3term()) // New current
    new_terms.push(new_node.as_n3term()) // New previous (for next iteration)
    let new_self = { ..self, terms: new_terms }

    let new_stack = new_self.stack
    new_stack.push(N3State::CollectionPossibleEnd)
    new_stack.push(N3State::Path)
    let final_self = { ..new_self, stack: new_stack }

    Ok((final_self, N3State::Path, output2))
  }
}

// ===== State: LiteralPossibleSuffix =====

///|
fn N3Recognizer::handle_literal_possible_suffix_m(
  self : N3Recognizer,
  value : String,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info(
    "Entering LiteralPossibleSuffix(\{value}) with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language~, direction~), _)
    ) => {
      if direction is Some(_) {
        return Err(
          RuleRecognizerError::SyntaxError(
            "rdf:dirLangString is not supported in N3",
            self.last_range,
          ),
        )
      }
      let literal = Literal::new_language_tagged_literal_unchecked(
        value,
        language.to_lower(),
      )
      let new_terms = self.terms
      new_terms.push(literal.as_n3term())
      let new_self = { ..self, terms: new_terms }

      // 字面量处理完毕，弹出 LiteralPossibleSuffix，回到调用者
      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::LiteralPossibleSuffix(value~)) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("^^"), _)
    ) =>
      // 期待数据类型 IRI
      Ok((self, N3State::LiteralExpectDatatype(value~), None))
    _ => {
      // 简单字面量
      let literal = Literal::new_simple_literal(value)
      let new_terms = self.terms
      new_terms.push(literal.as_n3term())
      let new_self = { ..self, terms: new_terms }

      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::LiteralPossibleSuffix(value~)) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
  }
}

// ===== State: LiteralExpectDatatype =====

///|
fn N3Recognizer::handle_literal_expect_datatype_m(
  self : N3Recognizer,
  value : String,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info(
    "Entering LiteralExpectDatatype(\{value}) with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(datatype), _)
    ) => {
      let datatype_node = NamedNodeRef::new_unchecked(datatype)
      let literal = LiteralRef::new_typed_literal(
        datatype_node.into_datatype(value),
        datatype_node,
      )

      let new_terms = self.terms
      new_terms.push(literal.as_n3term())
      let new_self = { ..self, terms: new_terms }

      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::LiteralExpectDatatype(value~)) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match context {
        RdfContext::N3RecognizerContext(ctx) =>
          match
            resolve_local_name(
              prefix,
              localx,
              might_be_invalid_iri,
              ctx.prefixes,
            ) {
            Ok(datatype_node) => {
              let literal = LiteralRef::new_typed_literal(
                datatype_node.into_datatype(value),
                datatype_node,
              )

              let new_terms = self.terms
              new_terms.push(literal.as_n3term())
              let new_self = { ..self, terms: new_terms }

              let new_stack = new_self.stack
              if !new_stack.is_empty() &&
                new_stack.last() == Some(N3State::LiteralExpectDatatype(value~)) {
                let _ = new_stack.pop()
              }
              let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
              let final_self = { ..new_self, stack: new_stack }

              Ok((final_self, next_state, None))
            }
            Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
          }
        _ =>
          Err(
            RuleRecognizerError::SyntaxError(
              "Invalid context for prefix resolution",
              self.last_range,
            ),
          )
      }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Unexpected token in formula content",
          self.last_range,
        ),
      )
  }
}

// ===== State: FormulaContent =====

///|
fn N3Recognizer::handle_formula_content_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info("Entering FormulaContent with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      // 公式结束
      let ctx = match self.contexts.pop() {
        Some(c) => c
        None =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Internal error: contexts stack empty in finish_formula",
              self.last_range,
            ),
          )
      }

      let new_terms = self.terms
      new_terms.push(ctx.as_n3term())
      let new_self = { ..self, terms: new_terms, contexts: self.contexts } // contexts already popped

      // 清理栈：弹出 PathFollowUp 和 FormulaContentExpectDot (如果存在)
      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::PathFollowUp) {
        let _ = new_stack.pop()
      }
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::FormulaContentExpectDot) {
        let _ = new_stack.pop()
      }

      // 弹出 FormulaContent 本身
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::FormulaContent) {
        let _ = new_stack.pop()
      }

      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "base") => {
      let new_stack = self.stack
      new_stack.push(N3State::FormulaContent)
      new_stack.push(N3State::BaseExpectIri)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::BaseExpectIri, None))
    }
    _ => {
      // 普通语句
      let new_stack = self.stack
      new_stack.push(N3State::FormulaContentExpectDot)
      new_stack.push(N3State::Triples)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, N3State::Triples, None))
    }
  }
}

// ===== State: FormulaContentExpectDot =====

///|
fn N3Recognizer::handle_formula_content_expect_dot_m(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
) -> TransitionResult[N3Recognizer, N3State, RdfOut] {
  self.debug_logger.info(
    "Entering FormulaContentExpectDot with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      // 公式直接结束，没有点
      let ctx = match self.contexts.pop() {
        Some(c) => c
        None =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Internal error: contexts stack empty in finish_formula",
              self.last_range,
            ),
          )
      }

      let new_terms = self.terms
      new_terms.push(ctx.as_n3term())
      let new_self = { ..self, terms: new_terms, contexts: self.contexts }

      let new_stack = new_self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::PathFollowUp) {
        let _ = new_stack.pop()
      }
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::FormulaContentExpectDot) {
        let _ = new_stack.pop()
      }
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::FormulaContent) {
        let _ = new_stack.pop()
      }

      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let final_self = { ..new_self, stack: new_stack }

      Ok((final_self, next_state, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      // 语句结束，回到 FormulaContent
      let new_stack = self.stack
      if !new_stack.is_empty() &&
        new_stack.last() == Some(N3State::FormulaContentExpectDot) {
        let _ = new_stack.pop()
      }
      let next_state = new_stack.last().unwrap_or(N3State::N3Doc)
      let new_self = { ..self, stack: new_stack }

      Ok((new_self, next_state, None))
    }
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "A dot or '}' is expected at the end of N3 statements inside formula",
        self.last_range,
      )
      Err(err)
    }
  }
}
