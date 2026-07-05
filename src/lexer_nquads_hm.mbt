// 假设类型定义如下（需根据实际项目调整）
// pub type TransitionResult[T, S, Stmt] = Result[(T, S, Stmt?), RuleRecognizerError]
// pub type RdfOut = Quad | Triple // 假设存在这样的联合类型或枚举

// ===== State: ExpectSubject =====

///|
fn NQuadsRecognizer::handle_expect_subject_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering ExpectSubject with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(s), _)) => {
      let new_self = self
      new_self.subjects.push(NamedNodeRef::new_unchecked(s).as_enum())
      // 状态转换为 ExpectPredicate，无语句产生
      Ok((new_self, NQuadsState::ExpectPredicate, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(s), _)
    ) => {
      let new_self = self
      new_self.subjects.push(BlankNodeRef::new_unchecked(s).as_enum())
      Ok((new_self, NQuadsState::ExpectPredicate, None))
    }
    _ => Err(RuleRecognizerError::BlankNodeOrIriError)
  }
}

// ===== State: ExpectPredicate =====

///|
fn NQuadsRecognizer::handle_expect_predicate_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering ExpectPredicate with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(p), _)) => {
      let new_self = self
      new_self.predicates.push(NamedNodeRef::new_unchecked(p))
      Ok((new_self, NQuadsState::ExpectedObject, None))
    }
    _ => Err(RuleRecognizerError::PredicateNotAnIRI)
  }
}

// ===== State: ExpectedObject =====

///|
fn NQuadsRecognizer::handle_expected_object_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering ExpectedObject with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(o), _)) => {
      let new_self = self
      new_self.objects.push(
        TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(o)),
      )
      Ok((new_self, NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(o), _)
    ) => {
      let new_self = self
      new_self.objects.push(NamedNodeRef::new_unchecked(o).as_term())
      Ok((new_self, NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::String(value), _)
    ) => {
      let new_self = self
      // 需要携带 value 进入下一个状态，通常通过修改 self 或状态参数
      // 这里假设 NQuadsState::ExpectLiteralAnnotation... 可以携带数据，或者我们存储在 self 中
      // 为了简化，假设有一个临时字段或状态变体携带 value
      // new_self.temp_literal_value = Some(value) 
      Ok(
        (
          new_self,
          NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~),
          None,
        ),
      )
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<<("), _)
    ) => {
      let new_self = self
      new_self.stack.push(NQuadsState::AfterQuotedTriple)
      new_self.stack.push(NQuadsState::ExpectSubject)
      Ok((new_self, NQuadsState::ExpectSubject, None)) // 立即进入子解析
    }
    _ => Err(RuleRecognizerError::BlankNodeOrIriError)
  }
}

// ===== State: ExpectLiteralAnnotationOrGraphNameOrDot =====

///|
fn NQuadsRecognizer::handle_expect_literal_annotation_or_graph_name_or_dot_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
  value : String,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  // 获取之前存储的 literal value
  // let value = match self.temp_literal_value {
  //   Some(v) => v
  //   None => return Err(RuleRecognizerError::SyntaxError("Missing literal value", Range::default()))
  // }

  // self.debug_logger.info("Entering ExpectLiteralAnnotation... value: \{value}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language~, direction~), _)
    ) if direction is Some(_) => {
      let dir = match direction {
        Some(d) => d
        None => BaseDirection::Ltr
      }
      let lang_tag = LanguageTag::from_str(language.to_lower()) catch {
        _e => return Err(RuleRecognizerError::InvalidLanguageTag) // 简化错误处理
      }

      match lang_tag {
        lang_tag => {
          let new_self = self
          let literal = LiteralRef::new_directional_language_tagged_literal_unchecked(
            value, lang_tag, dir,
          ).as_term()
          new_self.objects.push(literal)
          // new_self.temp_literal_value = None // 清除临时值
          Ok(
            (
              new_self,
              NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple,
              None,
            ),
          )
        }
        // Err(_e) => Err(RuleRecognizerError::InvalidLanguageTag)
      }
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language~, direction~), _)
    ) if direction is None => {
      let lang_tag = LanguageTag::from_str(language.to_lower()) catch {
        _e => return Err(RuleRecognizerError::InvalidLanguageTag)
      }
      match lang_tag {
        lang_tag => {
          let new_self = self
          let literal = TermRef::LiteralRef(
            Literal::new_language_tagged_literal_unchecked(
              value,
              lang_tag.to_string(),
            ).as_ref(),
          )
          new_self.objects.push(literal)
          // new_self.temp_literal_value = None
          Ok(
            (
              new_self,
              NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple,
              None,
            ),
          )
        }
        // Err(_e) => Err(RuleRecognizerError::InvalidLanguageTag)
      }
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("^^"), _)
    ) => {
      let new_self = self
      // new_self.temp_literal_value = Some(value) // 传递给 datatype 状态
      Ok((new_self, NQuadsState::ExpectLiteralDatatype(value~), None))
    }
    _ => {
      let new_self = self
      let literal = TermRef::LiteralRef(LiteralRef::new_simple_literal(value))
      new_self.objects.push(literal)
      // new_self.temp_literal_value = None
      Ok((new_self, NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple, None))
    }
  }
}

// ===== State: ExpectLiteralDatatype =====

///|
pub fn NQuadsRecognizer::handle_expect_literal_datatype_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
  value : String,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  // let value = match self.temp_literal_value {
  //   Some(v) => v
  //   None => return Err(RuleRecognizerError::SyntaxError("Missing literal value for datatype", Range::default()))
  // }

  self.debug_logger.info("Entering ExpectLiteralDatatype with value: \{value}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(d), _)) => {
      if !self.lenient && d == lwLANG_STRING.to_string() {
        return Err(
          RuleRecognizerError::SyntaxError(
            "The datatype of a literal without a language tag must not be rdf:langString",
            Range::default(),
          ),
        )
      }
      if !self.lenient && d == lwDIR_LANG_STRING.to_string() {
        return Err(
          RuleRecognizerError::SyntaxError(
            "The datatype of a literal without a base direction must not be rdf:dirLangString",
            Range::default(),
          ),
        )
      }
      let d_ref = NamedNodeRef::new_unchecked(d)
      let data_value = d_ref.into_datatype(value)
      let new_self = self
      let literal = TermRef::LiteralRef(
        LiteralRef::new_typed_literal(data_value, d_ref),
      )
      new_self.objects.push(literal)
      // new_self.temp_literal_value = None
      Ok((new_self, NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple, None))
    }
    _ => Err(RuleRecognizerError::LiteralDatatypeError)
  }
}

// ===== State: ExpectPossibleGraphOrEndOfQuotedTriple =====

///|
pub fn NQuadsRecognizer::handle_expect_possible_graph_or_end_of_quoted_triple_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering ExpectPossibleGraphOrEndOfQuotedTriple")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  // 检查是否是引用的三元组结束
  if !self.stack.is_empty() {
    match token {
      LocatedTokenOrLineJump::LocatedN3Token(
        LocatedN3Token(N3Token::Punctuation(")>>"), _)
      ) =>
        // 结束引用三元组，返回当前解析器状态，不产生顶层语句
        return Ok((self, NQuadsState::AfterQuotedTriple, None)) // 或者保持当前栈顶状态？原逻辑是 return self
      _ => ()
    }
    // 如果在栈中且不是结束符，可能是错误，或者原逻辑中的 error 调用
    // 原逻辑: (false, _) => error(...)
    return Err(
      RuleRecognizerError::SyntaxError(
        "Expecting the end of a quoted triple ')>>'",
        Range::default(),
      ),
    )
  }

  // 栈为空，处理顶层 Quad/Triple
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(g), _)) if ctx.with_graph_name => {
      let stmt = self.make_current_quad(
        graph_name=GraphNameRef::new_unchecked(g).into_owned(),
      )
      let new_self = self
      let _ = new_self.error_recovery_state() // 假设有一个方法清空 subjects/predicates/objects
      Ok((new_self, NQuadsState::ExpectDot, Some(stmt)))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(_g), _)
    ) if ctx.with_graph_name => {
      // 原文逻辑似乎对 BlankNode Graph Name 有特定处理，这里简化为 DefaultGraph 或报错
      // 原文: self.emit_quad(results, errors, GraphNameRef::DefaultGraph)
      let stmt = self.make_current_quad()
      let new_self = self
      let _ = new_self.error_recovery_state()
      Ok((new_self, NQuadsState::ExpectDot, Some(stmt)))
    }
    _ => {
      // 默认图
      let stmt = self.make_current_quad()
      let new_self = self
      let _ = new_self.error_recovery_state()

      // 原文逻辑: 递归处理当前 token。在新架构中，我们返回当前状态，并由主循环决定如何处理剩余 token
      // 或者返回一个特殊状态指示需要重新消费 token。
      // 这里为了简化，我们返回 ExpectDot，但如果 token 不是 Dot，主循环会报错。
      // 更好的方式是返回一个状态，告诉主循环“我完成了一个语句，请重新用这个 token 开始新的解析”
      // 这通常需要主循环支持 "reconsume" 或返回一个特殊的 Transition。
      // 暂时返回 Ok，并在主循环中处理“如果产生了 Statement 且 Token 未消耗”的情况

      // 注意：原代码中 self.recognize_next 是递归调用。在新架构中，这通常由外部循环处理。
      // 我们返回当前完成的语句，并将状态重置为 ExpectSubject，以便主循环可以用同一个 token 再次调用 handle_expect_subject_m
      // 但这需要主循环支持“不前进 token”。

      // 妥协方案：返回语句，状态设为 ExpectSubject，并标记需要重新消费 token（如果框架支持）
      // 如果不支持，可能需要将 token 压回输入流。

      Ok((new_self, NQuadsState::ExpectSubject, Some(stmt)))
    }
  }
}

// ===== State: ExpectDot =====

///|
fn NQuadsRecognizer::handle_expect_dot_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering ExpectDot with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => Ok((self, NQuadsState::ExpectLineJump, None))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Quads must be followed by a dot",
          Range::default(),
        ),
      )
  }
}

// ===== State: ExpectLineJump =====

///|
pub fn NQuadsRecognizer::handle_expect_line_jump_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering ExpectLineJump with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  // 原文直接 push error 并返回 self。在新架构中，这应该是一个错误，或者如果允许宽松模式，则警告。
  // 假设这是严格错误
  Err(
    RuleRecognizerError::SyntaxError(
      "Only a single triple or quad can be written in a line, found \{token.to_string()}",
      Range::default(),
    ),
  )
}

// ===== State: AfterQuotedTriple =====

///|
pub fn NQuadsRecognizer::handle_after_quoted_triple_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering AfterQuotedTriple with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  let subject_opt = self.subjects.pop()
  let predicate_opt = self.predicates.pop()
  let object_opt = self.objects.pop()

  match (subject_opt, predicate_opt, object_opt) {
    (Some(subject), Some(predicate), Some(object)) => {
      let triple : TripleRef = { subject, predicate, object }
      let new_self = self
      // 将引用的三元组作为对象推入外层对象的栈
      new_self.objects.push(TermRef::TripleRef(triple))

      // 弹出 AfterQuotedTriple 状态，回到之前的状态
      // 原逻辑: self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
      // 这里我们需要知道上一个状态是什么。原代码使用 stack。
      // 在新架构中，如果我们要完全消除 stack，需要更复杂的状态传递。
      // 鉴于原代码严重依赖 stack，我们可能需要在 TransitionResult 中返回新的 Stack 或者保持 stack 在 self 中。
      // 假设 stack 仍在 self 中管理

      let prev_state = new_self.stack.pop()
      match prev_state {
        Some(state) => Ok((new_self, state, None))
        None =>
          Err(
            RuleRecognizerError::SyntaxError(
              "Stack underflow after quoted triple",
              Range::default(),
            ),
          )
      }
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: incomplete quoted triple on stack",
          Range::default(),
        ),
      )
  }
}

// ===== State: RecoverToLineJump =====

///|
pub fn NQuadsRecognizer::handle_recover_to_line_jump_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info("Entering RecoverToLineJump with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LineJump(_) =>
      // 恢复完成，通常意味着要重新开始或结束
      // 返回一个初始状态
      Ok((self, NQuadsState::ExpectSubject, None))
    _ =>
      // 继续等待 LineJump，保持状态
      Ok((self, NQuadsState::RecoverToLineJump, None))
  }
}
