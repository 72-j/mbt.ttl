impl RuleRecognizer for N3Recognizer with fn recognize_next(
  self : N3Recognizer,
  token : TokenOrLineJump[N3Token],
  context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
  while true {
    match self.stack.pop() {
      Some(rule) =>
        match rule {
          N3State::N3Doc => {
            self.debug_logger.info(
              "Entering N3Doc with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(N3State::N3Doc)
            match token {
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "base",
                ) => {
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "prefix",
                ) => {
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="prefix", direction=None)
              ) => {
                self.stack.push(N3State::N3DocExpectDot)
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="base", direction=None)
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

            if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) {
              return self
            }
            errors.push(
              RuleRecognizerError::SyntaxError(
                "A dot is expected at the end of N3 statements",
                SourcePosition::default(),
              ),
            )
          }
          N3State::BaseExpectIri => {
            self.debug_logger.info(
              "Entering BaseExpectIri with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
              match context {
                RdfContext::N3RecognizerContext(ctx) =>
                  ctx.lexer_options.base_iri = Some(Iri::Iri(iri))
                _ => ()
              }
              return self
            } else {
              return self.error(
                errors,
                RuleRecognizerError::SyntaxError(
                  "The BASE keyword should be followed by an IRI",
                  SourcePosition::default(),
                ),
              )
            }
          }
          N3State::PrefixExpectPrefix => {
            self.debug_logger.info(
              "Entering PrefixExpectPrefix with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, ..)
              ) if localx.is_empty() => {
                self.stack.push(N3State::PrefixExpectIri(name=prefix))
                self
              }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "The PREFIX keyword should be followed by a prefix like 'ex:'",
                    SourcePosition::default(),
                  ),
                )
            }
          }
          N3State::PrefixExpectIri(name~) => {
            self.debug_logger.info(
              "Entering PrefixExpectIri(\{name}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
              match context {
                RdfContext::N3RecognizerContext(ctx) =>
                  ctx.prefixes.set(name, Iri::Iri(iri))
                _ => ()
              }
              self
            } else {
              self.error(
                errors,
                RuleRecognizerError::SyntaxError(
                  "The PREFIX declaration should be followed by a prefix and its value as an IRI",
                  SourcePosition::default(),
                ),
              )
            }
          }
          N3State::Triples => {
            self.debug_logger.info(
              "Entering Triples with token: \{token}",
            )
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
              is TokenOrLineJump::Token(
                N3Token::Punctuation("." | "]" | "}" | ")")
              ) {

            } else {
              self.stack.push(N3State::TriplesEnd)
              self.stack.push(N3State::PredicateObjectList)
            }
          }
          N3State::TriplesEnd => {
            self.debug_logger.info(
              "Entering TriplesEnd with token: \{token}",
            )
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
            if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
              self.stack.push(N3State::PredicateObjectListPossibleContinuation)
              return self
            }
          }
          N3State::PredicateObjectListPossibleContinuation => {
            self.debug_logger.info(
              "Entering PredicateObjectListPossibleContinuation with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
              self.stack.push(N3State::PredicateObjectListPossibleContinuation)
              return self
            } else if token
              is TokenOrLineJump::Token(
                N3Token::Punctuation(";" | "." | "}" | "]" | ")")
              ) {

            } else {
              self.stack.push(N3State::PredicateObjectListEnd)
              self.stack.push(N3State::ObjectsList)
              self.stack.push(N3State::Verb)
            }
          }
          N3State::ObjectsList => {
            self.debug_logger.info(
              "Entering ObjectsList with token: \{token}",
            )
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
                    SourcePosition::default(),
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
                    SourcePosition::default(),
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
                    SourcePosition::default(),
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
            if token == TokenOrLineJump::Token(N3Token::Punctuation(",")) {
              self.stack.push(N3State::ObjectsListEnd)
              self.stack.push(N3State::Path)
              return self
            }
          }
          N3State::Verb => {
            self.debug_logger.info(
              "Entering Verb with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              TokenOrLineJump::Token(N3Token::PlainKeyword("a")) => {
                self.predicates.push(Predicate::Regular(lwTYPE.as_n3term()))
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("has")) => {
                self.stack.push(N3State::AfterRegularVerb)
                self.stack.push(N3State::Path)
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("is")) => {
                self.stack.push(N3State::AfterVerbIs)
                self.stack.push(N3State::Path)
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("=")) => {
                self.predicates.push(
                  Predicate::Regular(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2002/07/owl#sameAs",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("=>")) => {
                self.predicates.push(
                  Predicate::Regular(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2000/10/swap/log#implies",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("<=")) => {
                self.predicates.push(
                  Predicate::Inverted(
                    NamedNodeRef::new_unchecked(
                      "http://www.w3.org/2000/10/swap/log#implies",
                    ).as_n3term(),
                  ),
                )
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("<-")) => {
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
                    SourcePosition::default(),
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
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }
            self.predicates.push(Predicate::Inverted(term))
            return self
          }
          N3State::AfterVerbIs => {
            self.debug_logger.info(
              "Entering AfterVerbIs with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              TokenOrLineJump::Token(N3Token::PlainKeyword("of")) => {
                let term = match self.terms.pop() {
                  Some(t) => t
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: terms stack empty in AfterVerbIs",
                        SourcePosition::default(),
                      ),
                    )
                    return self
                  }
                }
                self.predicates.push(Predicate::Inverted(term))
                self
              }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "The keyword 'is' should be followed by a predicate then by the keyword 'of'",
                    SourcePosition::default(),
                  ),
                )
            }
          }
          N3State::Path => {
            self.debug_logger.info(
              "Entering Path with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(N3State::PathFollowUp)
            self.stack.push(N3State::PathItem)
          }
          N3State::PathFollowUp => {
            self.debug_logger.info(
              "Entering PathFollowUp with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              TokenOrLineJump::Token(N3Token::Punctuation("!")) => {
                self.stack.push(N3State::PathAfterIndicator(is_inverse=false))
                self.stack.push(N3State::PathItem)
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("^")) => {
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
                    SourcePosition::default(),
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
                    SourcePosition::default(),
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
            self.debug_logger.info(
              "Entering PathItem with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              TokenOrLineJump::Token(N3Token::Iri(iri)) => {
                self.terms.push(NamedNodeRef::new_unchecked(iri).as_n3term())
                self
              }
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
                        self
                      }
                      Err(e) =>
                        return self.error(
                          errors,
                          RuleRecognizerError::SyntaxError(
                            e,
                            SourcePosition::default(),
                          ),
                        )
                    }
                  _ =>
                    self.error(
                      errors,
                      RuleRecognizerError::SyntaxError(
                        "Invalid context for prefix resolution",
                        SourcePosition::default(),
                      ),
                    )
                }
              TokenOrLineJump::Token(N3Token::BlankNodeLabel(bnode)) => {
                self.terms.push(BlankNodeRef::new_unchecked(bnode).as_n3term())
                self
              }
              TokenOrLineJump::Token(N3Token::Variable(name)) => {
                self.terms.push(N3Term::Variable(name))
                self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
                self.stack.push(N3State::PropertyListMiddle)
                self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
                self.stack.push(N3State::CollectionBeginning)
                self
              }
              TokenOrLineJump::Token(N3Token::String(value))
              | TokenOrLineJump::Token(N3Token::LongString(value)) => {
                self.stack.push(N3State::LiteralPossibleSuffix(value~))
                self
              }
              TokenOrLineJump::Token(N3Token::Integer(v)) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar(v),
                    lwINTEGER,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::Decimal(v)) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar(v),
                    lwDECIMAL,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::Double(v)) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar(v),
                    lwDOUBLE,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar("true"),
                    lwBOOLEAN,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntegerVar("false"),
                    lwBOOLEAN,
                  ).as_n3term(),
                )
                self
              }
              TokenOrLineJump::Token(N3Token::Punctuation("{")) => {
                self.contexts.push(BlankNode::default())
                self.stack.push(N3State::FormulaContent)
                self
              }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "TOKEN is not a valid RDF value",
                    SourcePosition::default(),
                  ),
                )
            }
          }
          N3State::PropertyListMiddle => {
            self.debug_logger.info(
              "Entering PropertyListMiddle with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              TokenOrLineJump::Token(N3Token::Punctuation("]")) => {
                self.terms.push(BlankNode::default().as_n3term())
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword("id")) => {
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

            if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
              return self
            } else {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "blank node property lists should end with a ']'",
                  SourcePosition::default(),
                ),
              )
            }
          }
          N3State::IriPropertyList => {
            self.debug_logger.info(
              "Entering IriPropertyList with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              TokenOrLineJump::Token(N3Token::Iri(id)) => {
                self.terms.push(NamedNodeRef::new_unchecked(id).as_n3term())
                self.stack.push(N3State::PropertyListEnd)
                self.stack.push(N3State::PredicateObjectList)
                self
              }
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
                        self
                      }
                      Err(e) =>
                        self.error(
                          errors,
                          RuleRecognizerError::SyntaxError(
                            e,
                            SourcePosition::default(),
                          ),
                        )
                    }
                  _ =>
                    return self.error(
                      errors,
                      RuleRecognizerError::SyntaxError(
                        "Invalid context for prefix resolution",
                        SourcePosition::default(),
                      ),
                    )
                }
              _ =>
                self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "The '[ id' construction should be followed by an IRI",
                    SourcePosition::default(),
                  ),
                )
            }
          }
          N3State::CollectionBeginning => {
            self.debug_logger.info(
              "Entering CollectionBeginning with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
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
                    SourcePosition::default(),
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
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }
            results.push(
              RdfStatement::N3Quad(self.quad(old, lwFIRST.as_n3term(), value)),
            )
            if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
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
              TokenOrLineJump::Token(N3Token::LangTag(language~, direction~)) => {
                if direction is Some(_) {
                  return self.error(
                    errors,
                    RuleRecognizerError::SyntaxError(
                      "rdf:dirLangString is not supported in N3",
                      SourcePosition::default(),
                    ),
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
              TokenOrLineJump::Token(N3Token::Punctuation("^^")) => {
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
              TokenOrLineJump::Token(N3Token::Iri(datatype)) => {
                let datatype = NamedNodeRef::new_unchecked(datatype)
                self.terms.push(
                  LiteralRef::new_typed_literal(
                    datatype.into_datatype(value),
                    datatype,
                  ).as_n3term(),
                )
                return self
              }
              TokenOrLineJump::Token(
                N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
                      Err(e) =>
                        return self.error(
                          errors,
                          RuleRecognizerError::SyntaxError(
                            e,
                            SourcePosition::default(),
                          ),
                        )
                    }
                  _ =>
                    return self.error(
                      errors,
                      RuleRecognizerError::SyntaxError(
                        "Invalid context for prefix resolution",
                        SourcePosition::default(),
                      ),
                    )
                }
              _ =>
                return self.error(
                  errors,
                  RuleRecognizerError::SyntaxError(
                    "Unexpected token in formula content",
                    SourcePosition::default(),
                  ),
                )
            }
          }
          N3State::FormulaContent => {
            self.debug_logger.info(
              "Entering FormulaContent with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              TokenOrLineJump::Token(N3Token::Punctuation("}")) => {
                let ctx = match self.contexts.pop() {
                  Some(c) => c
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: contexts stack empty in FormulaContent",
                        SourcePosition::default(),
                      ),
                    )
                    return self
                  }
                }
                self.terms.push(ctx.as_n3term())
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "base",
                ) => {
                self.stack.push(N3State::FormulaContent)
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
              TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
                  k, "prefix",
                ) => {
                self.stack.push(N3State::FormulaContent)
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="prefix", direction=None)
              ) => {
                self.stack.push(N3State::FormulaContentExpectDot)
                self.stack.push(N3State::PrefixExpectPrefix)
                return self
              }
              TokenOrLineJump::Token(
                N3Token::LangTag(language="base", direction=None)
              ) => {
                self.stack.push(N3State::FormulaContentExpectDot)
                self.stack.push(N3State::BaseExpectIri)
                return self
              }
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
              TokenOrLineJump::Token(N3Token::Punctuation("}")) => {
                let ctx = match self.contexts.pop() {
                  Some(c) => c
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: contexts stack empty in FormulaContentExpectDot",
                        SourcePosition::default(),
                      ),
                    )
                    return self
                  }
                }
                self.terms.push(ctx.as_n3term())
                return self
              }
              TokenOrLineJump::Token(N3Token::Punctuation(".")) => {
                self.stack.push(N3State::FormulaContent)
                return self
              }
              _ => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "A dot is expected at the end of N3 statements",
                    SourcePosition::default(),
                  ),
                )
                self.stack.push(N3State::FormulaContent)
              }
            }
          }
        }
      _ => break
    }
  }
  if token == TokenOrLineJump::Token(Punctuation(".")) {
    self.stack.push(N3State::N3Doc)
    self
  } else {
    self
  }
}