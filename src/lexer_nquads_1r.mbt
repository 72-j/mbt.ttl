///|
impl RuleRecognizer for NQuadsRecognizer with fn recognize_next(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> NQuadsRecognizer {
  let ctx = match context {
    RdfContext::NQuadsRecognizerContext(c) => c
    _ => abort("Invalid context type")
  }
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(located) =>
      match located {
        LocatedN3Token(_, range) => self.last_range = range
      }
    _ => ()
  }
  // 获取当前状态的字符串表示用于日志（假设 NQuadsState 实现了 ToString 或者手动匹配）
  // 这里为了通用性，我们直接在每个分支记录状态名称

  match self.stack.pop().unwrap_or(NQuadsState::ExpectSubject) {
    NQuadsState::ExpectSubject => {
      self.debug_logger.info("Entering ExpectSubject with token: \{token}")
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

      match token {
        LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Iri(s), _)
        ) => {
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
    NQuadsState::ExpectPredicate => {
      self.debug_logger.info("Entering ExpectPredicate with token: \{token}")
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

      match token {
        LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Iri(p), _)
        ) => {
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
    NQuadsState::ExpectedObject => {
      self.debug_logger.info("Entering ExpectedObject with token: \{token}")
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

      match token {
        LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Iri(o), _)
        ) => {
          self.objects.push(
            TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(o)),
          )
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
    NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~) => {
      self.debug_logger.info(
        "Entering ExpectLiteralAnnotationOrGraphNameOrDot with token: \{token}, value: \{value}",
      )
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

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
              self.stack.push(
                NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple,
              )
              self
            }
            Err(_e) => {
              errors.push(RuleRecognizerError::InvalidLanguageTag)
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
              self.stack.push(
                NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple,
              )
              self
            }
            Err(_e) => {
              errors.push(RuleRecognizerError::InvalidLanguageTag)
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
    NQuadsState::ExpectLiteralDatatype(value~) => {
      self.debug_logger.info(
        "Entering ExpectLiteralDatatype with token: \{token}, value: \{value}",
      )
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

      match token {
        LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Iri(d), _)
        ) => {
          if !self.lenient && d == lwLANG_STRING.to_string() {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "The datatype of a literal without a language tag must not be rdf:langString",
                Range::default(),
              ),
            )
          }
          if !self.lenient && d == lwDIR_LANG_STRING.to_string() {
            errors.push(
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
    NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple => {
      self.debug_logger.info(
        "Entering ExpectPossibleGraphOrEndOfQuotedTriple with token: \{token}",
      )
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")
      match (self.stack.is_empty(), token) {
        (
          true,
          LocatedTokenOrLineJump::LocatedN3Token(
            LocatedN3Token(N3Token::Iri(g), _)
          ),
        ) if ctx.with_graph_name => {
          self.emit_quad(results, errors, GraphNameRef::new_unchecked(g))
          self.stack.push(NQuadsState::ExpectDot)
          self
        }
        (
          true,
          LocatedTokenOrLineJump::LocatedN3Token(
            LocatedN3Token(N3Token::BlankNodeLabel(_g), _)
          ),
        ) if ctx.with_graph_name => {
          self.emit_quad(results, errors, GraphNameRef::DefaultGraph)
          self.stack.push(NQuadsState::ExpectDot)
          self
        }
        (true, _) => {
          self.emit_quad(results, errors, GraphName::DefaultGraph.as_ref())
          self.stack.push(NQuadsState::ExpectDot)
          self.recognize_next(
            token,
            RdfContext::NQuadsRecognizerContext(ctx),
            results,
            errors,
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
    // if self.stack.is_empty() {
    //   match token {
    //     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(g), _)) if ctx.with_graph_name => {
    //       self.emit_quad(results, errors, GraphNameRef::new_unchecked(g))
    //       self.stack.push(NQuadsState::ExpectDot)
    //       self
    //     }
    //     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::BlankNodeLabel(_g), _)) if ctx.with_graph_name => {
    //       self.emit_quad(results, errors, GraphNameRef::DefaultGraph)
    //       self.stack.push(NQuadsState::ExpectDot)
    //       self
    //     }
    //     _ => {
    //       self.emit_quad(results, errors, GraphName::DefaultGraph.as_ref())
    //       self.stack.push(NQuadsState::ExpectDot)
    //       self.recognize_next(
    //         token,
    //         RdfContext::NQuadsRecognizerContext(ctx),
    //         results,
    //         errors,
    //       )
    //     }
    //   }
    // } else if token == LocatedTokenOrLineJump::LocatedN3Token(N3Token::Punctuation(")>>")) {
    //   self
    // } else {
    //   self.error(
    //     ctx,
    //     results,
    //     errors,
    //     token,
    //     RuleRecognizerError::SyntaxError(
    //       "Expecting the end of a quoted triple ')>>'",
    //       Range::default(),
    //     ),
    //   )
    // }
    NQuadsState::ExpectDot => {
      self.debug_logger.info("Entering ExpectDot with token: \{token}")
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

      match token {
        LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Punctuation("."), _)
        ) => {
          self.stack.push(NQuadsState::ExpectLineJump)
          self
        }
        _ => {
          errors.push(
            RuleRecognizerError::SyntaxError(
              "Quads must be followed by a dot",
              Range::default(),
            ),
          )
          self
        }
      }
    }
    NQuadsState::ExpectLineJump => {
      self.debug_logger.info("Entering ExpectLineJump with token: \{token}")
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

      errors.push(
        RuleRecognizerError::SyntaxError(
          "Only a single triple or quad can be written in a line, found \{token.to_string()}",
          Range::default(),
        ),
      )
      self
    }
    NQuadsState::AfterQuotedTriple => {
      self.debug_logger.info("Entering AfterQuotedTriple with token: \{token}")
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

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
          errors.push(
            RuleRecognizerError::SyntaxError(
              "Internal error: incomplete quoted triple on stack",
              Range::default(),
            ),
          )
          self.error_recovery_state()
        }
      }
    }
    NQuadsState::RecoverToLineJump => {
      self.debug_logger.info("Entering RecoverToLineJump with token: \{token}")
      self.debug_logger.info("Token stack: \{self.stack.to_string()}")

      // if token != LocatedTokenOrLineJump::LineJump {
      //   self.stack.push(NQuadsState::RecoverToLineJump)
      // }
      // self
      match token {
        LocatedTokenOrLineJump::LineJump(_) =>
          // 是 LineJump，不做任何事
          return self
        _ => {
          self.stack.push(NQuadsState::RecoverToLineJump)
          self
        }
      }
    }
  }
}
