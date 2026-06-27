///|
impl RuleRecognizer for N3Recognizer with fn recognize_next(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
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
        match rule {
          N3State::N3Doc => {
            self.debug_logger.info("Entering N3Doc with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(N3State::N3Doc)
            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "base") => {
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "prefix") => {
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::LangTag(language="prefix", direction=None),
                  _
                )
              ) => {
                self.stack.push(N3State::N3DocExpectDot)
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::LangTag(language="base", direction=None),
                  _
                )
              ) => {
                self.stack.push(N3State::N3DocExpectDot)
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              _ => {
                self.stack.push(N3State::N3DocExpectDot)
                self.stack.push(N3State::Triples)
              }
            }
          }
          N3State::N3DocExpectDot => {
            self.debug_logger.info(
              "Entering N3DocExpectDot with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("."), _)
              ) => return self
              _ => ()
            }
            errors.push(
              RuleRecognizerError::SyntaxError(
                "A dot is expected at the end of N3 statements",
                Range::default(),
              ),
            )
          }
          N3State::BaseExpectIri => {
            self.debug_logger.info(
              "Entering BaseExpectIri with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) {
              match context {
                RdfContext::N3RecognizerContext(ctx) =>
                  ctx.lexer_options.base_iri = Some(Iri::Iri(iri))
                _ => ()
              }
              return self
            } else {
              return self.error(
                errors, "The BASE keyword should be followed by an IRI",
              )
            }
          }
          N3State::PrefixExpectPrefix => {
            self.debug_logger.info(
              "Entering PrefixExpectPrefix with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PrefixedName(prefix~, localx~, ..), _)
              ) if localx.is_empty() => {
                self.stack.push(N3State::PrefixExpectIri(name=prefix))
                return self
              }
              _ =>
                return self.error(
                  errors, "The PREFIX keyword should be followed by a prefix like 'ex:'",
                )
            }
          }
          N3State::PrefixExpectIri(name~) => {
            self.debug_logger.info(
              "Entering PrefixExpectIri(\{name}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) {
              match context {
                RdfContext::N3RecognizerContext(ctx) =>
                  ctx.prefixes.set(name, Iri::Iri(iri))
                _ => ()
              }
              self
            } else {
              self.error(
                errors, "The PREFIX declaration should be followed by a prefix and its value as an IRI",
              )
            }
          }
          N3State::Triples => {
            self.debug_logger.info("Entering Triples with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(N3State::TriplesMiddle)
            self.stack.push(N3State::Path)
          }
          N3State::TriplesMiddle => {
            self.debug_logger.info(
              "Entering TriplesMiddle with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("." | "]" | "}" | ")"), _)
              ) {

            } else {
              self.stack.push(N3State::TriplesEnd)
              self.stack.push(N3State::PredicateObjectList)
            }
          }
          N3State::TriplesEnd => {
            self.debug_logger.info("Entering TriplesEnd with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let _ = self.terms.pop()
          }
          N3State::PredicateObjectList => {
            self.debug_logger.info(
              "Entering PredicateObjectList with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(N3State::PredicateObjectListEnd)
            self.stack.push(N3State::ObjectsList)
            self.stack.push(N3State::Verb)
          }
          N3State::PredicateObjectListEnd => {
            self.debug_logger.info(
              "Entering PredicateObjectListEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let _ = self.predicates.pop()
            // if token ==
            //   LocatedTokenOrLineJump::LocatedN3Token(
            //     LocatedN3Token(N3Token::Punctuation(";"), _),
            //   ) {
            //   self.stack.push(N3State::PredicateObjectListPossibleContinuation)
            //   return self
            // }
            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(";"), _)
              ) => {
                self.stack.push(
                  N3State::PredicateObjectListPossibleContinuation,
                )
                return self
              }
              _ => ()
            }
          }
          N3State::PredicateObjectListPossibleContinuation => {
            self.debug_logger.info(
              "Entering PredicateObjectListPossibleContinuation with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(";"), _)
              ) => {
                self.stack.push(
                  N3State::PredicateObjectListPossibleContinuation,
                )
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("."), _)
              ) =>
                // 处理句号
                return self
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("}"), _)
              ) =>
                // 处理右花括号
                return self
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) =>
                // 处理右方括号
                return self
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")"), _)
              ) =>
                // 处理右括号
                return self
              _ => {
                self.stack.push(N3State::PredicateObjectListEnd)
                self.stack.push(N3State::ObjectsList)
                self.stack.push(N3State::Verb)
              }
            }
          }
          N3State::ObjectsList => {
            self.debug_logger.info("Entering ObjectsList with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(N3State::ObjectsListEnd)
            self.stack.push(N3State::Path)
          }
          N3State::ObjectsListEnd => {
            self.debug_logger.info(
              "Entering ObjectsListEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let object = match self.terms.pop() {
              Some(o) => o
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty (object)",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let subject = match self.terms.last() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty (subject)",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let predicate_opt = match self.predicates.last() {
              Some(p) => p
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: predicates stack empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            results.push(
              match predicate_opt {
                Predicate::Regular(predicate) =>
                  RdfStatement::N3Quad(self.quad(subject, predicate, object))
                Predicate::Inverted(predicate) =>
                  RdfStatement::N3Quad(self.quad(object, predicate, subject))
              },
            )
            // if token ==
            //   LocatedTokenOrLineJump::LocatedN3Token(
            //     LocatedN3Token(N3Token::Punctuation(","), _),
            //   ) {
            //   self.stack.push(N3State::ObjectsListEnd)
            //   self.stack.push(N3State::Path)
            //   return self
            // }
            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(","), _)
              ) => {
                self.stack.push(N3State::ObjectsListEnd)
                self.stack.push(N3State::Path)
                return self
              }
              _ => ()
            }
          }
          N3State::Verb => {
            self.debug_logger.info("Entering Verb with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("a"), _)
              ) => {
                self.predicates.push(Predicate::Regular(lwTYPE.as_n3term()))
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("has"), _)
              ) => {
                self.stack.push(N3State::AfterRegularVerb)
                self.stack.push(N3State::Path)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("is"), _)
              ) => {
                self.stack.push(N3State::AfterVerbIs)
                self.stack.push(N3State::Path)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("="), _)
              ) => {
                self.predicates.push(
                  Predicate::Regular(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2002/07/owl#sameAs",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("=>"), _)
              ) => {
                self.predicates.push(
                  Predicate::Regular(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2000/10/swap/log#implies",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<="), _)
              ) => {
                self.predicates.push(
                  Predicate::Inverted(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2000/10/swap/log#implies",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<-"), _)
              ) => {
                self.stack.push(N3State::AfterInvertedVerb)
                self.stack.push(N3State::Path)
                return self
              }
              _ => {
                self.stack.push(N3State::AfterRegularVerb)
                self.stack.push(N3State::Path)
              }
            }
          }
          N3State::AfterRegularVerb => {
            self.debug_logger.info(
              "Entering AfterRegularVerb with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let term = match self.terms.pop() {
              Some(t) => t
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty in AfterRegularVerb",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            self.predicates.push(Predicate::Regular(term))
            return self
          }
          N3State::AfterInvertedVerb => {
            self.debug_logger.info(
              "Entering AfterInvertedVerb with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let term = match self.terms.pop() {
              Some(t) => t
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty in AfterInvertedVerb",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            self.predicates.push(Predicate::Inverted(term))
            return self
          }
          N3State::AfterVerbIs => {
            self.debug_logger.info("Entering AfterVerbIs with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("of"), _)
              ) => {
                let term = match self.terms.pop() {
                  Some(t) => t
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: terms stack empty in AfterVerbIs",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }
                self.predicates.push(Predicate::Inverted(term))
                return self
              }
              _ =>
                return self.error(
                  errors, "The keyword 'is' should be followed by a predicate then by the keyword 'of'",
                )
            }
          }
          N3State::Path => {
            self.debug_logger.info("Entering Path with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(N3State::PathFollowUp)
            self.stack.push(N3State::PathItem)
          }
          N3State::PathFollowUp => {
            self.debug_logger.info("Entering PathFollowUp with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("!"), _)
              ) => {
                self.stack.push(N3State::PathAfterIndicator(is_inverse=false))
                self.stack.push(N3State::PathItem)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("^"), _)
              ) => {
                self.stack.push(N3State::PathAfterIndicator(is_inverse=false))
                self.stack.push(N3State::PathItem)
                return self
              }
              _ => ()
            }
          }
          N3State::PathAfterIndicator(is_inverse~) => {
            self.debug_logger.info(
              "Entering PathAfterIndicator(is_inverse=\{is_inverse}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let predicate = match self.terms.pop() {
              Some(p) => p
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty (predicate) in PathAfterIndicator",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let previous = match self.terms.pop() {
              Some(prev) => prev
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty (previous) in PathAfterIndicator",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let current = BlankNode::default().as_n3term()
            results.push(
              if is_inverse {
                RdfStatement::N3Quad(self.quad(current, predicate, previous))
              } else {
                RdfStatement::N3Quad(self.quad(previous, predicate, current))
              },
            )
            self.terms.push(current)
            self.stack.push(N3State::PathFollowUp)
          }
          N3State::PathItem => {
            self.debug_logger.info("Entering PathItem with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.stack.push(N3State::PropertyListMiddle)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("("), _)
              ) => {
                self.stack.push(N3State::CollectionBeginning)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("{"), _)
              ) => {
                self.contexts.push(BlankNode::default())
                self.stack.push(N3State::FormulaContent)
                return self
              }
              // 修复：处理公式结束符 }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("}"), _)
              ) => {
                if self.contexts.is_empty() {
                  return self.error(errors, "Unexpected '}' outside of formula")
                }
                let ctx = self.contexts.pop().unwrap()
                self.terms.push(ctx.as_n3term())
                if self.stack.last() == Some(N3State::PathFollowUp) {
                  let _ = self.stack.pop()
                }

                return self
              }
              _ =>
                // 使用辅助函数处理其他 Term
                return self.handle_term_token(token, context, errors)
            }
          }
          N3State::PropertyListMiddle => {
            self.debug_logger.info(
              "Entering PropertyListMiddle with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => {
                self.terms.push(BlankNode::default().as_n3term())
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("id"), _)
              ) => {
                self.stack.push(N3State::IriPropertyList)
                return self
              }
              _ => {
                self.terms.push(BlankNode::default().as_n3term())
                self.stack.push(N3State::PropertyListEnd)
                self.stack.push(N3State::PredicateObjectList)
              }
            }
          }
          N3State::PropertyListEnd => {
            self.debug_logger.info(
              "Entering PropertyListEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => return self
              _ =>
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "blank node property lists should end with a ']'",
                    Range::default(),
                  ),
                )
            }
          }
          N3State::IriPropertyList => {
            self.debug_logger.info(
              "Entering IriPropertyList with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(id), _)
              ) => {
                self.terms.push(NamedNodeRef::new_unchecked(id).as_n3term())
                self.stack.push(N3State::PropertyListEnd)
                self.stack.push(N3State::PredicateObjectList)
                return self
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
                        self.terms.push(t.as_n3term())
                        return self
                      }
                      Err(e) => return self.error(errors, e.to_string())
                    }
                  _ =>
                    return self.error(
                      errors, "Invalid context for prefix resolution",
                    )
                }
              _ =>
                return self.error(
                  errors, "The '[ id' construction should be followed by an IRI",
                )
            }
          }
          N3State::CollectionBeginning => {
            self.debug_logger.info(
              "Entering CollectionBeginning with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")"), _)
              ) {
              self.terms.push(lwNIL.as_n3term())
              return self
            } else {
              let root = BlankNode::default()
              self.terms.push(root.as_n3term())
              self.terms.push(root.as_n3term())
              self.stack.push(N3State::CollectionPossibleEnd)
              self.stack.push(N3State::Path)
            }
          }
          N3State::CollectionPossibleEnd => {
            self.debug_logger.info(
              "Entering CollectionPossibleEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let value = match self.terms.pop() {
              Some(v) => v
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty (value) in CollectionPossibleEnd",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let old = match self.terms.pop() {
              Some(o) => o
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: terms stack empty (old) in CollectionPossibleEnd",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            results.push(
              RdfStatement::N3Quad(self.quad(old, lwFIRST.as_n3term(), value)),
            )
            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")"), _)
              ) {
              results.push(
                RdfStatement::N3Quad(
                  self.quad(old, lwREST.as_n3term(), lwNIL.as_n3term()),
                ),
              )
              return self
            }
            let new = BlankNode::default()
            results.push(
              RdfStatement::N3Quad(
                self.quad(old, lwREST.as_n3term(), new.as_n3term()),
              ),
            )
            self.terms.push(new.as_n3term())
            self.stack.push(N3State::CollectionPossibleEnd)
            self.stack.push(N3State::Path)
          }
          N3State::LiteralPossibleSuffix(value~) => {
            self.debug_logger.info(
              "Entering LiteralPossibleSuffix(\{value}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::LangTag(language~, direction~), _)
              ) => {
                if direction is Some(_) {
                  return self.error(
                    errors, "rdf:dirLangString is not supported in N3",
                  )
                }
                self.terms.push(
                  Literal::new_language_tagged_literal_unchecked(
                    value,
                    language.to_lower(),
                  ).as_n3term(),
                )
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("^^"), _)
              ) => {
                self.stack.push(N3State::LiteralExpectDatatype(value~))
                return self
              }
              _ =>
                self.terms.push(Literal::new_simple_literal(value).as_n3term())
            }
          }
          N3State::LiteralExpectDatatype(value~) => {
            self.debug_logger.info(
              "Entering LiteralExpectDatatype(\{value}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(datatype), _)
              ) => {
                let datatype = NamedNodeRef::new_unchecked(datatype)
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    datatype.into_datatype(value),
                    datatype,
                  ).as_n3term(),
                )
                return self
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
                      Ok(datatype) => {
                        self.terms.push(
                          LiteralRef::new_typed_literal(
                            datatype.into_datatype(value),
                            datatype,
                          ).as_n3term(),
                        )
                        return self
                      }
                      Err(e) => return self.error(errors, e)
                    }
                  _ =>
                    return self.error(
                      errors, "Invalid context for prefix resolution",
                    )
                }
              _ =>
                return self.error(errors, "Unexpected token in formula content")
            }
          }
          N3State::FormulaContent => {
            self.debug_logger.info(
              "Entering FormulaContent with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("}"), _)
              ) =>
                // 调用辅助函数处理结束逻辑
                return self.finish_formula(errors)
              // ... 其他 case 保持不变
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "base") => {
                self.stack.push(N3State::FormulaContent)
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              // ...
              _ => {
                self.stack.push(N3State::FormulaContentExpectDot)
                self.stack.push(N3State::Triples)
              }
            }
          }
          N3State::FormulaContentExpectDot => {
            self.debug_logger.info(
              "Entering FormulaContentExpectDot with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("}"), _)
              ) =>
                // 调用辅助函数处理结束逻辑
                // 注意：在 ExpectDot 状态下遇到 }，说明公式内最后一个三元组省略了 .
                // 或者 } 直接结束了公式。finish_formula 会处理上下文弹出。
                return self.finish_formula(errors)
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("."), _)
              ) => {
                self.stack.push(N3State::FormulaContent)
                return self
              }
              _ => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "A dot or '}' is expected at the end of N3 statements inside formula",
                    Range::default(),
                  ),
                )
                // 尝试恢复，推回 FormulaContent 继续解析
                self.stack.push(N3State::FormulaContent)
              }
            }
          }
        }
      _ => break
    }
  }
  // if token ==
  //   LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(Punctuation(".")), _) {
  //   self.stack.push(N3State::N3Doc)
  //   self
  // } else {
  //   self
  // }
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => return self
    _ => self
  }
}
