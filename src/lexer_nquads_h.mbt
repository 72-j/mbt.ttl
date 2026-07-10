// ===== State: ExpectSubject =====

///|
fn NQuadsRecognizer::handle_expect_subject(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  ctx : NQuadsRecognizerContext,
  results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info("Entering ExpectSubject with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(s), _)) => {
      self.subjects.push(NamedNodeRef::new_unchecked(s).as_enum())
      self.stack.push(NQuadsState::ExpectPredicate)
      self
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(s), _)
    ) => {
      self.subjects.push(BlankNodeRef::new_unchecked(s).as_enum())
      self.stack.push(NQuadsState::ExpectPredicate)
      self
    }
    _ =>
      self.error(
        ctx,
        results,
        token,
        RuleRecognizerError::BlankNodeOrIriError.err_kind(),
      )
  }
}

// ===== State: ExpectPredicate =====

///|
fn NQuadsRecognizer::handle_expect_predicate(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  ctx : NQuadsRecognizerContext,
  results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info("Entering ExpectPredicate with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(p), _)) => {
      self.predicates.push(NamedNodeRef::new_unchecked(p))
      self.stack.push(NQuadsState::ExpectedObject)
      self
    }
    _ =>
      self.error(
        ctx,
        results,
        token,
        RuleRecognizerError::PredicateNotAnIRI.err_kind(),
      )
  }
}

// ===== State: ExpectedObject =====

///|
fn NQuadsRecognizer::handle_expected_object(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  ctx : NQuadsRecognizerContext,
  results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info(
    "Entering ExpectedObject with token: \{token} Token stack: \{@debug.to_string(self.stack)}",
  )

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(o), _)) => {
      self.objects.push(TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(o)))
      self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
      self
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(o), _)
    ) => {
      self.objects.push(NamedNodeRef::new_unchecked(o).as_term())
      self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
      self
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::String(value), _)
    ) => {
      self.stack.push(
        NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~),
      )
      self
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<<("), _)
    ) => {
      self.stack.push(NQuadsState::AfterQuotedTriple)
      self.stack.push(NQuadsState::ExpectSubject)
      self
    }
    _ =>
      self.error(
        ctx,
        results,
        token,
        RuleRecognizerError::BlankNodeOrIriError.err_kind(),
      )
  }
}

// ===== State: ExpectLiteralAnnotationOrGraphNameOrDot =====

///|
fn NQuadsRecognizer::handle_expect_literal_annotation_or_graph_name_or_dot(
  self : NQuadsRecognizer,
  value : String,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
  _results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info("Entering ExpectLiteralAnnotation... value: \{value}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language~, direction~), _)
    ) if direction is Some(_) => {
      let dir = match direction {
        Some(d) => d
        None => BaseDirection::Ltr
      }
      let lang_tag = try
        LanguageTag::from_str(language.to_lower()) |> Ok
      catch {
        e => Err(e)
      }
      match lang_tag {
        Ok(lang_tag) => {
          self.objects.push(
            LiteralRef::new_directional_language_tagged_literal_unchecked(
              value, lang_tag, dir,
            ).as_term(),
          )
          self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
          self
        }
        Err(_e) => {
          self.errors.push(RuleRecognizerError::InvalidLanguageTag)
          self.error_recovery_state()
        }
      }
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language~, direction~), _)
    ) if direction is None => {
      let lang_tag = try
        LanguageTag::from_str(language.to_lower()) |> Ok
      catch {
        e => Err(e)
      }
      match lang_tag {
        Ok(lang_tag) => {
          self.objects.push(
            TermRef::LiteralRef(
              Literal::new_language_tagged_literal_unchecked(
                value,
                lang_tag.to_string(),
              ).as_ref(),
            ),
          )
          self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
          self
        }
        Err(_e) => {
          self.errors.push(RuleRecognizerError::InvalidLanguageTag)
          self.error_recovery_state()
        }
      }
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("^^"), _)
    ) => {
      self.stack.push(NQuadsState::ExpectLiteralDatatype(value~))
      self
    }
    _ => {
      self.objects.push(
        TermRef::LiteralRef(LiteralRef::new_simple_literal(value)),
      )
      self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
      self
    }
  }
}

// ===== State: ExpectLiteralDatatype =====

///|
fn NQuadsRecognizer::handle_expect_literal_datatype(
  self : NQuadsRecognizer,
  value : String,
  token : LocatedTokenOrLineJump,
  ctx : NQuadsRecognizerContext,
  results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info("Entering ExpectLiteralDatatype with value: \{value}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(d), _)) => {
      if !self.lenient && d == lwLANG_STRING.to_string() {
        self.errors.push(
          RuleRecognizerError::SyntaxError(
            "The datatype of a literal without a language tag must not be rdf:langString",
            Range::default(),
          ),
        )
      }
      if !self.lenient && d == lwDIR_LANG_STRING.to_string() {
        self.errors.push(
          RuleRecognizerError::SyntaxError(
            "The datatype of a literal without a base direction must not be rdf:dirLangString",
            Range::default(),
          ),
        )
      }
      let d = NamedNodeRef::new_unchecked(d)
      let data_value = d.into_datatype(value)
      self.objects.push(
        TermRef::LiteralRef(LiteralRef::new_typed_literal(data_value, d)),
      )
      self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
      self
    }
    _ =>
      self.error(
        ctx,
        results,
        token,
        RuleRecognizerError::LiteralDatatypeError.err_kind(),
      )
  }
}

// ===== State: ExpectPossibleGraphOrEndOfQuotedTriple =====

///|
fn NQuadsRecognizer::handle_expect_possible_graph_or_end_of_quoted_triple(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  ctx : NQuadsRecognizerContext,
  results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info(
    "Entering ExpectPossibleGraphOrEndOfQuotedTriple Token stack: \{@debug.to_string(self.stack)}",
  )

  match (self.stack.is_empty(), token) {
    (
      true,
      LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(g), _)),
    ) if ctx.with_graph_name => {
      self.emit_quad(results, GraphNameRef::new_unchecked(g))
      self.stack.push(NQuadsState::ExpectDot)
      self
    }
    (
      true,
      LocatedTokenOrLineJump::LocatedN3Token(
        LocatedN3Token(N3Token::BlankNodeLabel(_g), _)
      ),
    ) if ctx.with_graph_name => {
      self.emit_quad(results, GraphNameRef::DefaultGraph)
      self.stack.push(NQuadsState::ExpectDot)
      self
    }
    (true, _) => {
      self.emit_quad(results, GraphName::DefaultGraph.as_ref())
      self.stack.push(NQuadsState::ExpectDot)
      // 递归处理当前 token，因为它可能是下一个 Triple 的开始
      self.recognize_next(
        token,
        RdfContext::NQuadsRecognizerContext(ctx),
        results,
      )
    }
    (
      false,
      LocatedTokenOrLineJump::LocatedN3Token(
        LocatedN3Token(N3Token::Punctuation(")>>"), _)
      ),
    ) => return self
    (false, _) =>
      self.error(
        ctx, results, token, "Expecting the end of a quoted triple ')>>'",
      )
  }
}

// ===== State: ExpectDot =====

///|
fn NQuadsRecognizer::handle_expect_dot(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
  _results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info("Entering ExpectDot with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      self.stack.push(NQuadsState::ExpectLineJump)
      self
    }
    _ => {
      self.errors.push(
        RuleRecognizerError::SyntaxError(
          "Quads must be followed by a dot",
          Range::default(),
        ),
      )
      self
    }
  }
}

// ===== State: ExpectLineJump =====

///|
fn NQuadsRecognizer::handle_expect_line_jump(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
  _results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info("Entering ExpectLineJump with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  self.errors.push(
    RuleRecognizerError::SyntaxError(
      "Only a single triple or quad can be written in a line, found \{token.to_string()}",
      Range::default(),
    ),
  )
  self
}

// ===== State: AfterQuotedTriple =====

///|
fn NQuadsRecognizer::handle_after_quoted_triple(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
  _results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info("Entering AfterQuotedTriple with token: \{token}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  let subject_opt = self.subjects.pop()
  let predicate_opt = self.predicates.pop()
  let object_opt = self.objects.pop()

  match (subject_opt, predicate_opt, object_opt) {
    (Some(subject), Some(predicate), Some(object)) => {
      let triple : TripleRef = { subject, predicate, object }
      self.objects.push(TermRef::TripleRef(triple))
      self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
      self
    }
    _ => {
      self.errors.push(
        RuleRecognizerError::SyntaxError(
          "Internal error: incomplete quoted triple on stack",
          Range::default(),
        ),
      )
      self.error_recovery_state()
    }
  }
}

// ===== State: RecoverToLineJump =====

///|
fn NQuadsRecognizer::handle_recover_to_line_jump(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  _ctx : NQuadsRecognizerContext,
  _results : Array[RdfOut],
) -> NQuadsRecognizer {
  self.debug_logger.info(
    "RecoverToLineJump with token: \{token}Token stack: \{@debug.to_string(self.stack)}",
  )

  match token {
    LocatedTokenOrLineJump::LineJump(_) =>
      // 是 LineJump，恢复完成
      return self
    _ => {
      // 继续等待 LineJump
      self.stack.push(NQuadsState::RecoverToLineJump)
      self
    }
  }
}
