// ===== State: ExpectSubject =====

///|
fn NQuadsRecognizer::handle_expect_subject_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info(
    "ExpectSubject with token: \{token} Token stack: \{@debug.to_string(self.stack)}",
  )

  match token {
    LocatedTokenOrLineJump::End => Ok((self, NQuadsState::ExpectSubject, None))
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
  ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info(
    " ExpectedObject: \{token} Token stack: \{@debug.to_string(self.stack)}",
  )

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(o), _)) => {
      let new_self = self
      new_self.objects.push(
        TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(o)),
      )
      if ctx.with_graph_name {
        Ok(
          (new_self, NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple, None),
        )
      } else {
        // N-Triples 直接进入 ExpectDot
        Ok((new_self, NQuadsState::ExpectDot, None))
      }
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
    _ =>
      // 检查是否是句点
      match token {
        LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Punctuation("."), _)
        ) => {
          let new_self = self
          let literal = TermRef::LiteralRef(
            LiteralRef::new_simple_literal(value),
          )
          new_self.objects.push(literal)
          let stmt = new_self.make_current_quad()
          let _ = new_self.error_recovery_state()
          Ok((new_self, NQuadsState::ExpectLineJump, stmt))
        }
        _ => {
          let new_self = self
          let literal = TermRef::LiteralRef(
            LiteralRef::new_simple_literal(value),
          )
          new_self.objects.push(literal)
          Ok(
            (
              new_self,
              NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple,
              None,
            ),
          )
        }
      }
  }
  // _ => {
  //   let new_self = self
  //   let literal = TermRef::LiteralRef(LiteralRef::new_simple_literal(value))
  //   new_self.objects.push(literal)
  //   // new_self.temp_literal_value = None
  //   Ok((new_self, NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple, None))
  // }
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
  self.debug_logger.info(
    "ExpectPossibleGraphOrEndOfQuotedTriple Token stack: \{@debug.to_string(self.stack)}",
  )

  // 首先检查是否是图名 IRI（无论是顶层还是嵌套在引用的三元组中）
  if ctx.with_graph_name {
    match token {
      LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(g), _)) => {
        let stmt = self.make_current_quad(
          graph_name=GraphNameRef::new_unchecked(g).into_owned(),
        )
        let new_self = self
        let _ = new_self.error_recovery_state()
        return Ok((new_self, NQuadsState::ExpectDot, stmt))
      }
      LocatedTokenOrLineJump::LocatedN3Token(
        LocatedN3Token(N3Token::BlankNodeLabel(_g), _)
      ) => {
        let stmt = self.make_current_quad()
        let new_self = self
        let _ = new_self.error_recovery_state()
        return Ok((new_self, NQuadsState::ExpectDot, stmt))
      }
      _ => ()
    }
  }

  // 检查是否是句点（默认图结束）
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      let stmt = self.make_current_quad()
      let new_self = self
      let _ = new_self.error_recovery_state()
      return Ok((new_self, NQuadsState::ExpectLineJump, stmt))
    }
    _ => ()
  }

  // 检查是否是引用的三元组结束
  if !self.stack.is_empty() {
    match token {
      LocatedTokenOrLineJump::LocatedN3Token(
        LocatedN3Token(N3Token::Punctuation(")>>"), _)
      ) =>
        // 结束引用三元组，返回当前解析器状态，不产生顶层语句
        return Ok((self, NQuadsState::AfterQuotedTriple, None))
      _ => ()
    }
    // 如果在栈中且不是结束符，可能是错误
    return Err(
      RuleRecognizerError::SyntaxError(
        "Expecting the end of a quoted triple ')>>'",
        Range::default(),
      ),
    )
  }

  // 栈为空且没有特殊 token，返回 ExpectSubject 并输出 quad
  let stmt = self.make_current_quad()
  let new_self = self
  let _ = new_self.error_recovery_state()
  Ok((new_self, NQuadsState::ExpectSubject, stmt))
}

// ===== State: ExpectDot =====

///|
fn NQuadsRecognizer::handle_expect_dot_m(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
) -> TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut] {
  self.debug_logger.info(
    "ExpectDot with token: \{token} Token stack: \{@debug.to_string(self.stack)}",
  )

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      let stmt = self.make_current_quad()
      Ok((self, NQuadsState::ExpectLineJump, stmt))
    }
    LocatedTokenOrLineJump::LocatedN3Token(t) =>
      Err(
        RuleRecognizerError::SyntaxError("Quads must be followed by a dot", t.1),
      )
    _ =>
      Err(RuleRecognizerError::SyntaxError("Expecting a dot", Range::default()))
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
  let tok = match token {
    LocatedTokenOrLineJump::LineJump(n) => "LineJump(\{n})"
    LocatedTokenOrLineJump::End => "End"
    LocatedTokenOrLineJump::LocatedN3Token(t) => "N3Token: \{t.0}"
  }
  self.debug_logger.info("Token type: \{tok}")

  match token {
    LocatedTokenOrLineJump::LineJump(_) =>
      // 成功：换行后回到 ExpectSubject 开始下一个语句
      Ok((self, NQuadsState::ExpectSubject, None))
    LocatedTokenOrLineJump::End =>
      // 文件结束，安静地接受
      Ok((self, NQuadsState::ExpectSubject, None))
    _ =>
      // 换行符之后不应该有其他内容
      // 跳过并继续等待换行（lenient 模式）
      if self.lenient {
        Ok((self, NQuadsState::ExpectLineJump, None))
      } else {
        Err(
          RuleRecognizerError::SyntaxError(
            "Only a single triple or quad can be written in a line",
            Range::default(),
          ),
        )
      }
  }
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

