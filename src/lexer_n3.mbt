
///|
struct N3Recognizer {
  stack : Array[N3State]
  terms : Array[N3Term]
  predicates : Array[Predicate]
  contexts : Array[BlankNode]
 mut  debug_logger :&DebugLogger
}

///|
struct N3RecognizerContext {
  lexer_options : LexerOptions
  prefixes : Map[String, Iri]
}

///|
fn N3RecognizerContext::as_ctx(self : N3RecognizerContext) -> RdfContext {
  RdfContext::N3RecognizerContext(self)
}

///|
impl RuleRecognizer for N3Recognizer with fn error_recovery_state(
  self : N3Recognizer,
) -> N3Recognizer {
  self.stack.clear()
  self.terms.clear()
  self.predicates.clear()
  self.contexts.clear()
  self
}
impl RuleRecognizer for N3Recognizer with fn[DL: DebugLogger] debug_logger(
  self : N3Recognizer,
  logger : DL,
) {
  self.debug_logger = logger
}

///|
impl RuleRecognizer for N3Recognizer with fn recognize_next(
  self : N3Recognizer,
  token : TokenOrLineJump[N3Token],
  context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
  while true {
    // let TokenOrLineJump::Token(token) = token

    match self.stack.pop() {
      Some(rule) =>
        match rule {
          N3State::N3Doc => {
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
          N3State::BaseExpectIri =>
            if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
              match context {
                RdfContext::N3RecognizerContext(ctx) =>
                  ctx.lexer_options.base_iri = Some(Iri::Iri(iri))
                _ => ()
              }
              // context.lexer_options.base_iri = Some(Iri::Iri(iri))
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
          N3State::PrefixExpectPrefix =>
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
          N3State::PrefixExpectIri(name~) =>
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
          N3State::Triples => {
            self.stack.push(N3State::TriplesMiddle)
            self.stack.push(N3State::Path)
          }
          N3State::TriplesMiddle =>
            if token
              is TokenOrLineJump::Token(
                N3Token::Punctuation("." | "]" | "}" | ")")
              ) {

            } else {
              self.stack.push(N3State::TriplesEnd)
              self.stack.push(N3State::PredicateObjectList)
            }
          N3State::TriplesEnd => {
            let _ = self.terms.pop()
          }
          N3State::PredicateObjectList => {
            self.stack.push(N3State::PredicateObjectListEnd)
            self.stack.push(N3State::ObjectsList)
            self.stack.push(N3State::Verb)
          }
          N3State::PredicateObjectListEnd => {
            let _ = self.predicates.pop()
            if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
              self.stack.push(N3State::PredicateObjectListPossibleContinuation)
              return self
            }
          }
          N3State::PredicateObjectListPossibleContinuation =>
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
          N3State::ObjectsList => {
            self.stack.push(N3State::ObjectsListEnd)
            self.stack.push(N3State::Path)
          }
          N3State::ObjectsListEnd => {
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
          N3State::Verb =>
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
          N3State::AfterRegularVerb => {
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
          N3State::AfterVerbIs =>
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
          N3State::Path => {
            self.stack.push(N3State::PathFollowUp)
            self.stack.push(N3State::PathItem)
          }
          N3State::PathFollowUp =>
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
          N3State::PathAfterIndicator(is_inverse~) => {
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
          N3State::PathItem =>
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
          N3State::PropertyListMiddle =>
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
          N3State::PropertyListEnd =>
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
          N3State::IriPropertyList =>
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
          N3State::CollectionBeginning =>
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
          N3State::CollectionPossibleEnd => {
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
          N3State::LiteralPossibleSuffix(value~) =>
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
          N3State::LiteralExpectDatatype(value~) =>
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
          N3State::FormulaContent =>
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
          N3State::FormulaContentExpectDot =>
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

///|
impl RuleRecognizer for N3Recognizer with fn recognize_end(
  self : N3Recognizer,
  _state : RdfContext,
  _results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> Unit {
  match self.stack {
    [] | [N3State::N3Doc] => ()
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          SourcePosition::SourcePosition(0, 0, 0),
        ),
      )
  }
}

///|
impl RuleRecognizer for N3Recognizer with fn lexer_options(context : RdfContext) -> LexerOptions? {
  // context.lexer_options
  match context {
    N3RecognizerContext(context) => Some(context.lexer_options)
    _ => None
  }
}

///|
pub fn N3Recognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  unchecked : Bool,
  base_iri : Iri?,
  prefixes : Map[String, Iri],
      debug_logger? : &DebugLogger = make_mute_logger(),

) -> Parser[RdfLexer, N3Recognizer] {
  // 注意：参数 prefixes 类型已修正为 Map[String, IriRef] 以匹配 RdfContext 定义
  Parser::Parser(
    Lexer::Lexer(
      RdfLexer::RdfLexer(RdfLexerMode::N3, unchecked),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0
    ),
    { stack: [N3State::N3Doc], terms: [], predicates: [], contexts: [],debug_logger },
    // 修复点：使用 RdfContext ::N3RecognizerContext 包装记录
    RdfContext::N3RecognizerContext({ lexer_options: { base_iri, }, prefixes }),
  )
}

///|
fn N3Recognizer::error(
  self : N3Recognizer,
  errors : Array[RuleRecognizerError],
  msg : RuleRecognizerError,
) -> N3Recognizer {
  errors.push(msg)
  self.stack.clear()
  self
}

///|
fn N3Recognizer::quad(
  self : N3Recognizer,
  subject : N3Term,
  predicate : N3Term,
  object : N3Term,
) -> N3Quad {
  {
    subject,
    predicate,
    object,
    graph_name: self.contexts
    .last()
    .map_or(GraphName::DefaultGraph, fn(g) { GraphName::BlankNode(g) }),
  }
}

///|
enum N3State {
  N3Doc
  N3DocExpectDot
  BaseExpectIri
  PrefixExpectPrefix
  PrefixExpectIri(name~ : String)
  Triples
  TriplesMiddle
  TriplesEnd
  PredicateObjectList
  PredicateObjectListEnd
  PredicateObjectListPossibleContinuation
  ObjectsList
  ObjectsListEnd
  Verb
  AfterRegularVerb
  AfterInvertedVerb
  AfterVerbIs
  Path
  PathFollowUp
  PathAfterIndicator(is_inverse~ : Bool)
  PathItem
  PropertyListMiddle
  PropertyListEnd
  IriPropertyList
  CollectionBeginning
  CollectionPossibleEnd
  LiteralPossibleSuffix(value~ : String)
  LiteralExpectDatatype(value~ : String)
  FormulaContent
  FormulaContentExpectDot
} derive(Debug)
