///|
impl RuleRecognizer for TriGRecognizer with fn recognize_next(
  self : TriGRecognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
  self.debug_logger.info("Stack Depth: \{self.stack.length()}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  let context = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ => abort("Invalid context for TriGRecognizer")
  }

  while true {
    match self.stack.pop() {
      Some(rule) =>
        match rule {
          TriGState::TriGDoc => {
            self.debug_logger.info("Entering TriGDoc with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.cur_graph = GraphNameRef::DefaultGraph
            self.stack.push(TriGState::TriGDoc)
            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "base") => {
                self.stack.push(TriGState::BaseExpectIri)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "prefix") => {
                self.stack.push(TriGState::PrefixExpectPrefix)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "version") => {
                self.stack.push(TriGState::VersionExpectVersion)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::LangTag(language="prefix", direction=None),
                  _
                )
              ) => {
                self.stack.push(TriGState::ExpectDot)
                self.stack.push(TriGState::PrefixExpectPrefix)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::LangTag(language="base", direction=None),
                  _
                )
              ) => {
                self.stack.push(TriGState::ExpectDot)
                self.stack.push(TriGState::BaseExpectIri)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::LangTag(language="version", direction=None),
                  _
                )
              ) => {
                self.stack.push(TriGState::ExpectDot)
                self.stack.push(TriGState::VersionExpectVersion)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "graph") && context.with_graph_name => {
                self.stack.push(TriGState::WrappedGraph)
                self.stack.push(TriGState::GraphName)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("{"), _)
              ) if context.with_graph_name => {
                self.stack.push(TriGState::WrappedGraph)
                return self
              }
              _ => {
                self.stack.push(TriGState::TriplesOrGraph)
                return self
              }
            }
          }
          TriGState::ExpectDot => {
            self.debug_logger.info("Entering ExpectDot with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("."), _)
              ) => {
                let _ = self.reset_to_tri_gdoc()
              }
              _ => {
                errors.push(RuleRecognizerError::TripleMissingDot)
                let _ = self.reset_to_tri_gdoc()
              }
            }
          }
          TriGState::BaseExpectIri => {
            self.debug_logger.info(
              "Entering BaseExpectIri with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) {
              let iri_ref = Iri::new(iri)
              if self.lenient {
                context.lexer_options.base_iri = Some(
                  IriRef::parse_unchecked(iri_ref),
                )
              } else {
                match IriRef::parse(iri_ref) {
                  Ok(parsed_iri) =>
                    context.lexer_options.base_iri = Some(parsed_iri)
                  Err(e) =>
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Invalid BASE IRI: \{e.to_string()}",
                        Range::default(),
                      ),
                    )
                }
              }
              self.stack.push(TriGState::ExpectDot)
              return self
            } else {
              return self.error(
                errors, "The BASE keyword should be followed by an IRI",
              )
            }
          }
          TriGState::PrefixExpectPrefix => {
            self.debug_logger.info(
              "Entering PrefixExpectPrefix with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PrefixedName(prefix~, localx~, ..), _)
              ) if localx.is_empty() => {
                self.stack.push(TriGState::PrefixExpectIri(name=prefix))
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri_str), _)
              ) if iri_str.has_suffix(":") => {
                let prefix = iri_str[0:iri_str.length() - 1]
                self.debug_logger.info(
                  "PrefixExpectPrefix: Matched Iri as prefix '\{prefix}:'",
                )
                self.stack.push(
                  TriGState::PrefixExpectIri(name=prefix.to_owned()),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if k.has_suffix(":") => {
                let prefix = k[0:k.length() - 1]
                self.debug_logger.info(
                  "PrefixExpectPrefix: Matched Keyword as prefix '\{prefix}:'",
                )
                self.stack.push(
                  TriGState::PrefixExpectIri(name=prefix.to_owned()),
                )
                self
              }
              _ =>
                self.error(
                  errors, "The PREFIX keyword should be followed by a prefix like 'ex:'",
                )
            }
          }
          TriGState::PrefixExpectIri(name~) => {
            self.debug_logger.info(
              "Entering PrefixExpectIri(\{name}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) {
              let iri = Iri::Iri(iri)
              context.prefixes.set(name, iri)
              self.stack.push(TriGState::ExpectDot)
              return self
            } else {
              return self.error(
                errors, "The PREFIX declaration should be followed by a prefix and its value as an IRI",
              )
            }
          }
          TriGState::VersionExpectVersion => {
            self.debug_logger.info(
              "Entering VersionExpectVersion with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::String(_), _)
              ) {
              self.stack.push(TriGState::ExpectDot)
              return self
            } else {
              return self.error(
                errors, "The VERSION keyword should be followed by a single quoted string like \"1.2\"",
              )
            }
          }
          TriGState::TriplesOrGraph => {
            self.debug_logger.info(
              "Entering TriplesOrGraph with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_subject.push(
                  NamedNodeRef::new_unchecked(iri).as_enum(),
                )
                self.stack.push(
                  TriGState::WrappedGraphOrPredicateObjectList(
                    term=NamedNodeRef::new_unchecked(iri).as_enum(),
                  ),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.cur_subject.push(t.as_enum())
                    self.stack.push(
                      TriGState::WrappedGraphOrPredicateObjectList(
                        term=t.as_enum(),
                      ),
                    )
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.stack.push(
                  TriGState::WrappedGraphOrPredicateObjectList(
                    term=NamedNodeRef::new_unchecked(label).as_enum(),
                  ),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.stack.push(
                  TriGState::WrappedGraphBlankNodePropertyListCurrent,
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("("), _)
              ) => {
                self.stack.push(TriGState::ExpectDot)
                self.stack.push(TriGState::PredicateObjectList)
                self.stack.push(TriGState::SubjectCollectionBeginning)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<<"), _)
              ) => {
                self.stack.push(TriGState::MaybePredicateObjectList)
                self.stack.push(TriGState::SubjectReifiedTripleEnd)
                self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
                self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
                self.stack.push(TriGState::Verb)
                self.stack.push(
                  TriGState::ReifiedTripleSubject(is_reified=true),
                )
                self
              }
              _ =>
                self.error(errors, "TOKEN is not a valid subject or graph name")
            }
          }
          TriGState::WrappedGraphBlankNodePropertyListCurrent => {
            self.debug_logger.info(
              "Entering WrappedGraphBlankNodePropertyListCurrent with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => {
                self.stack.push(
                  TriGState::WrappedGraphOrPredicateObjectList(
                    term=BlankNode::default().as_ref().as_enum(),
                  ),
                )
                return self
              }
              _ => {
                self.cur_subject.push(BlankNode::default().as_ref().as_enum())
                self.stack.push(TriGState::ExpectDot)
                self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
                self.stack.push(TriGState::PredicateObjectList)
                return self
              }
            }
          }
          // TriGState::WrappedGraphBlankNodePropertyListCurrent => {
          //   self.debug_logger.info(
          //     "Entering WrappedGraphBlankNodePropertyListCurrent with token: \{token}",
          //   )
          //   self.debug_logger.info("Token stack: \{self.stack.to_string()}")

          //   match token {
          //     LocatedTokenOrLineJump::LocatedN3Token(
          //       LocatedN3Token(N3Token::Punctuation("]"), _)
          //     ) => {
          //       self.stack.push(
          //         TriGState::WrappedGraphOrPredicateObjectList(
          //           term=BlankNode::default().as_ref().as_enum(),
          //         ),
          //       )

          //     }
          //     _ => {
          //       self.cur_subject.push(BlankNode::default().as_ref().as_enum())
          //       self.stack.push(TriGState::ExpectDot)
          //       self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
          //       self.stack.push(TriGState::PredicateObjectList)
          //       return self
          //     }
          //   }
          // }
          TriGState::SubjectBlankNodePropertyListEnd => {
            self.debug_logger.info(
              "Entering SubjectBlankNodePropertyListEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => {
                self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
                return self
              }
              _ => {
                errors.push(
                  RuleRecognizerError::BlankNodePropertyListMissingEndBracket,
                )
                self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
                return self
              }
            }
          }
          TriGState::SubjectBlankNodePropertyListAfter => {
            self.debug_logger.info(
              "Entering SubjectBlankNodePropertyListAfter with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("." | "}"), _)
              ) {
              return self
            } else {
              self.stack.push(TriGState::PredicateObjectList)
              return self
            }
          }
          TriGState::SubjectCollectionBeginning => {
            self.debug_logger.info(
              "Entering SubjectCollectionBeginning with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")"), _)
              ) {
              self.cur_subject.push(lwNIL.as_enum())
              return self
            } else {
              let root = NamedOrBlankNodeRef::BlankNodeRef(
                BlankNode::default().as_ref(),
              )
              self.cur_subject.push(root)
              self.cur_subject.push(root)
              self.cur_predicate.push(lwFIRST)
              self.stack.push(TriGState::SubjectCollectionPossibleEnd)
              self.stack.push(TriGState::Object)
              return self
            }
          }
          TriGState::SubjectCollectionPossibleEnd => {
            self.debug_logger.info(
              "Entering SubjectCollectionPossibleEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let old = match self.cur_subject.pop() {
              Some(node) => node
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack is empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let _ = self.cur_object.pop()
            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")"), _)
              ) {
              let _ = self.cur_predicate.pop()
              results.push(
                RdfStatement::Quad(
                  Quad::Quad(
                    old.into_owned(),
                    lwREST.into_owned(),
                    lwNIL.into_owned().as_term(),
                    self.cur_graph.into_owned(),
                  ),
                ),
              )
              return self
            } else {
              let new = BlankNode::default()
              results.push(
                RdfStatement::Quad(
                  Quad::Quad(
                    old.into_owned(),
                    lwREST.into_owned(),
                    lwNIL.as_term().into_owned(),
                    self.cur_graph.into_owned(),
                  ),
                ),
              )
              self.cur_subject.push(
                NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()),
              )
              self.stack.push(TriGState::ObjectCollectionPossibleEnd)
              self.stack.push(TriGState::Object)
              return self
            }
          }
          TriGState::WrappedGraph => {
            self.debug_logger.info("Entering WrappedGraph with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("{"), _)
              ) => {
                self.stack.push(TriGState::WrappedGraphPossibleEnd)
                self.stack.push(TriGState::Triples)
                return self
              }
              _ =>
                return self.error(
                  errors, "The GRAPH keyword should be followed by a graph name and a value in '{'",
                )
            }
          }
          TriGState::WrappedGraphPossibleEnd => {
            self.debug_logger.info(
              "Entering WrappedGraphPossibleEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("}"), _)
              ) => self
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("."), _)
              ) => {
                self.stack.push(TriGState::WrappedGraphPossibleEnd)
                self.stack.push(TriGState::Triples)
                self
              }
              _ => {
                errors.push(RuleRecognizerError::TripleMissingDot)
                self
              }
            }
          }
          TriGState::Triples => {
            self.debug_logger.info("Entering Triples with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("}"), _)
              ) => self
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::BlankNodeRef(
                    BlankNode::default().as_ref(),
                  ),
                )
                self.stack.push(TriGState::PredicateObjectList)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_subject.push(
                  NamedNodeRef::new_unchecked(iri).as_enum(),
                )
                self.stack.push(TriGState::PredicateObjectList)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.cur_subject.push(t.as_enum())
                    self.stack.push(TriGState::PredicateObjectList)
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::BlankNodeRef(
                    BlankNodeRef::new_unchecked(label),
                  ),
                )
                self.stack.push(TriGState::PredicateObjectList)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("("), _)
              ) => {
                self.stack.push(TriGState::PredicateObjectList)
                self.stack.push(TriGState::SubjectCollectionBeginning)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<<"), _)
              ) => {
                self.stack.push(TriGState::MaybePredicateObjectList)
                self.stack.push(TriGState::SubjectReifiedTripleEnd)
                self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
                self.stack.push(
                  TriGState::ReifiedTripleSubject(is_reified=true),
                )
                self.stack.push(TriGState::Verb)
                self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
                self
              }
              _ => self.error(errors, "TOKEN is not a valid RDF subject")
            }
          }
          TriGState::TriplesBlankNodePropertyListCurrent => {
            self.debug_logger.info(
              "Entering TriplesBlankNodePropertyListCurrent with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => {
                self.stack.push(TriGState::PredicateObjectList)
                return self
              }
              _ => {
                self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
                self.stack.push(TriGState::PredicateObjectList)
                return self
              }
            }
          }
          TriGState::GraphName => {
            self.debug_logger.info("Entering GraphName with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_graph = GraphNameRef::NamedNodeRef(
                  NamedNodeRef::new_unchecked(iri),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.cur_graph = GraphNameRef::NamedNodeRef(t)
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_graph = GraphNameRef::BlankNodeRef(
                  BlankNodeRef::new_unchecked(label),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::BlankNodeRef(
                    BlankNode::default().as_ref(),
                  ),
                )
                self.stack.push(TriGState::PredicateObjectList)
                self
              }
              _ => self.error(errors, "TOKEN is not a valid graph name")
            }
          }
          TriGState::GraphNameAnonEnd => {
            self.debug_logger.info(
              "Entering GraphNameAnonEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => {
                self.cur_graph = GraphNameRef::BlankNodeRef(
                  BlankNode::default().as_ref(),
                )
                return self
              }
              _ =>
                return self.error(
                  errors, "Anonymous blank node with a property list are not allowed as graph name",
                )
            }
          }
          TriGState::MaybePredicateObjectList => {
            self.debug_logger.info(
              "Entering MaybePredicateObjectList with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("."), _)
              ) =>
                // Do nothing, just return self
                return self
              _ => self.stack.push(TriGState::PredicateObjectList)
            }
            return self
          }
          TriGState::PredicateObjectList => {
            self.debug_logger.info(
              "Entering PredicateObjectList with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(TriGState::PredicateObjectListEnd)
            self.stack.push(TriGState::Object)
            return self
          }
          TriGState::PredicateObjectListEnd => {
            self.debug_logger.info(
              "Entering PredicateObjectListEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.debug_logger.info(
              "PredicateObjectListEnd: token=\{token}, expected_dot=\{LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("."), Range::default()))}",
            )

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(","), _)
              ) => {
                self.stack.push(TriGState::Object)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(";"), _)
              ) => {
                self.stack.push(
                  TriGState::PredicateObjectListPossibleContinuation,
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("."), _)
              ) => {
                self.stack.clear()
                self.stack.push(TriGState::TriGDoc)
                self.cur_subject.clear()
                self.cur_predicate.clear()
                self.cur_object.clear()
                self
              }
              _ =>
                self.error(
                  errors, "Expected ';' or '.' after predicate-object list",
                )
            }
          }
          TriGState::PredicateObjectListPossibleContinuation => {
            self.debug_logger.info(
              "Entering PredicateObjectListPossibleContinuation with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(";"), _)
              ) => {
                self.stack.push(
                  TriGState::PredicateObjectListPossibleContinuation,
                )
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("." | "}" | "]" | "|}"), _)
              ) => return self
              _ => {
                self.stack.push(TriGState::PredicateObjectListEnd)
                self.stack.push(TriGState::Object)
                self.stack.push(TriGState::Verb)
                return self
              }
            }
          }
          TriGState::ObjectsList => {
            self.debug_logger.info("Entering ObjectsList with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            self.stack.push(TriGState::Object)
            self.debug_logger.info(
              "ObjectsList: after replace, stack: \{self.stack.to_string()}",
            )
            return self.recognize_next(
              token,
              RdfContext::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
          TriGState::AnnotationBlock(with_reifier~) => {
            self.debug_logger.info(
              "Entering AnnotationBlock(with_reifier=\{with_reifier}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(","), _)
              ) => {
                let _ = self.cur_object.pop()
                if with_reifier {
                  let _ = self.cur_reifier.pop()
                }
                self.stack.push(TriGState::AnnotationBlock(with_reifier=false))
                self.stack.push(TriGState::Object)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("~"), _)
              ) => {
                let cur_sub = match self.cur_subject.last() {
                  Some(s) => s
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: subject stack empty",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }
                let cur_pred = match self.cur_predicate.last() {
                  Some(p) => p
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: predicate stack empty",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }
                let cur_obj = match self.cur_object.last() {
                  Some(o) => o
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: object stack empty",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }

                self.stack.push(TriGState::AnnotationBlock(with_reifier=true))
                self.stack.push(
                  TriGState::Reifier(
                    triple=TripleRef::TripleRef(cur_sub, cur_pred, cur_obj).into_owned(),
                  ),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("{|"), _)
              ) => {
                let cur_sub = match self.cur_subject.last() {
                  Some(s) => s
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: subject stack empty",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }
                let cur_pred = match self.cur_predicate.last() {
                  Some(p) => p
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: predicate stack empty",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }
                let cur_obj = match self.cur_object.last() {
                  Some(o) => o
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: object stack empty",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }
                let reifier = if with_reifier {
                  match self.cur_reifier.last() {
                    Some(r) => r
                    None => {
                      errors.push(
                        RuleRecognizerError::SyntaxError(
                          "Internal error: reifier stack empty",
                          Range::default(),
                        ),
                      )
                      return self
                    }
                  }
                } else {
                  let reifier = BlankNode::default()
                  results.push(
                    RdfStatement::Quad(
                      Quad::Quad(
                        reifier.as_enum(),
                        lwREIFIES.into_owned(),
                        TermRef::TripleRef(
                          TripleRef::TripleRef(cur_sub, cur_pred, cur_obj),
                        ).into_owned(),
                        self.cur_graph.into_owned(),
                      ),
                    ),
                  )
                  reifier.as_enum().as_ref()
                }
                self.cur_subject.push(reifier)
                self.stack.push(TriGState::AnnotationBlock(with_reifier~))
                self.stack.push(TriGState::PredicateObjectList)
                self
              }
              _ => {
                let _ = self.cur_object.pop()
                if with_reifier {
                  let _ = self.cur_reifier.pop()
                }
                self
              }
            }
          }
          TriGState::AnnotationEnd(with_reifier~) => {
            self.debug_logger.info(
              "Entering AnnotationEnd(with_reifier=\{with_reifier}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let _ = self.cur_subject.pop()
            // 无论匹配成功与否，都需要保持状态以便处理后续 token 或报错后继续
            self.stack.push(TriGState::AnnotationEnd(with_reifier~))

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("|}"), _)
              ) => return self
              _ =>
                return self
                  .error(errors, "Annotations should end with '|}'")
                  .recognize_next(
                    token,
                    RdfContext::TriGRecognizerContext(context),
                    results,
                    errors,
                  )
            }
          }
          TriGState::Verb => {
            self.debug_logger.info("Entering Verb with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("a"), _)
              ) => {
                self.cur_predicate.push(lwTYPE)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))
                self.emit_quad(results)
                self.stack.push(TriGState::PredicateObjectListEnd)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.cur_predicate.push(t)
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              _ => self.error(errors, "TOKEN is not a valid predicate")
            }
          }
          TriGState::Object => {
            self.debug_logger.info("Entering Object state with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.debug_logger.info("Object: IRI branch, pushing object")
                self.cur_object.push(
                  TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri)),
                )
                self.emit_quad(results)
                self.stack.push(TriGState::PredicateObjectListEnd)
                self.debug_logger.info(
                  "Object: after pop, stack: \{self.stack.to_string()}",
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.debug_logger.info(
                      "Object: PrefixedName branch, pushing object",
                    )
                    self.cur_object.push(TermRef::NamedNodeRef(t))
                    self.emit_quad(results)
                    self.stack.push(TriGState::PredicateObjectListEnd)
                    self.debug_logger.info(
                      "Object: after pop, stack: \{self.stack.to_string()}",
                    )
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_object.push(
                  TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(label)),
                )
                self.emit_quad(results)
                self.stack.push(TriGState::PredicateObjectListEnd)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.stack.push(TriGState::ObjectBlankNodePropertyListCurrent)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("("), _)
              ) => {
                self.stack.push(TriGState::ObjectCollectionBeginning)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::String(value), _)
              )
              | LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::LongString(value), _)
              ) => {
                self.stack.push(
                  TriGState::LiteralPossibleSuffix(value~, emit=true),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Integer(v), _)
              ) => {
                let v = try @string.parse_int(v) |> Ok catch {
                  e => Err(e)
                }
                self.debug_logger.info(
                  "Object: Integer branch, in_collection = \{self.in_collection}",
                )

                match v {
                  Ok(value) => {
                    self.cur_object.push(
                      LiteralRef::new_typed_literal(
                        VarDataType::IntVar(value.to_string()),
                        lwINTEGER,
                      ).as_term(),
                    )
                    self.emit_quad(results)
                    if self.in_collection {
                      self.stack.push(TriGState::ObjectCollectionPossibleEnd)
                    } else {
                      self.stack.push(TriGState::PredicateObjectListEnd)
                    }
                    self
                  }
                  Err(e) => self.error(errors, e.to_string())
                }
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Decimal(v), _)
              ) => {
                let v = try @string.parse_double(v) |> Ok catch {
                  e => Err(e)
                }
                match v {
                  Ok(value) => {
                    self.cur_object.push(
                      LiteralRef::new_typed_literal(
                        VarDataType::DecimalVar(value.to_string()),
                        lwDECIMAL,
                      ).as_term(),
                    )
                    self.emit_quad(results)
                    self.stack.push(TriGState::PredicateObjectListEnd)
                    self
                  }
                  Err(e) => self.error(errors, e.to_string())
                }
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Double(v), _)
              ) => {
                let v = try @string.parse_double(v) |> Ok catch {
                  e => Err(e)
                }
                match v {
                  Ok(value) => {
                    self.cur_object.push(
                      LiteralRef::new_typed_literal(
                        VarDataType::DoubleVar(value.to_string()),
                        lwDOUBLE,
                      ).as_term(),
                    )
                    self.emit_quad(results)
                    self.stack.push(TriGState::PredicateObjectListEnd)
                    self
                  }
                  Err(e) => self.error(errors, e.to_string())
                }
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("true"), _)
              ) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(VarDataType::TrueVar, lwBOOLEAN).as_term(),
                )
                self.emit_quad(results)
                self.stack.push(TriGState::PredicateObjectListEnd)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("false"), _)
              ) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::FalseVar,
                    lwBOOLEAN,
                  ).as_term(),
                )
                self.emit_quad(results)
                self.stack.push(TriGState::PredicateObjectListEnd)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<<"), _)
              ) => {
                self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=true))
                self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
                self.stack.push(
                  TriGState::ReifiedTripleSubject(is_reified=true),
                )
                self.stack.push(TriGState::Verb)
                self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<<("), _)
              ) => {
                self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=true))
                self.stack.push(
                  TriGState::ReifiedTripleSubject(is_reified=false),
                )
                self.stack.push(TriGState::Verb)
                self.stack.push(
                  TriGState::ReifiedTripleObject(is_reified=false),
                )
                self
              }
              // 修复：移除对 ")" 的递归调用，恢复为报错或忽略。
              // 如果 Object 收到 )，说明状态机流转错误，应该由 ObjectCollectionPossibleEnd 处理。
              // 为了调试，我们让它报错，或者如果是在集合中，尝试回退。
              // 但为了避免死循环，我们不再递归调用 recognize_next。
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::Punctuation("." | ";" | "," | "]" | "}" | "|}"),
                  _
                )
              ) => {
                self.debug_logger.info(
                  "Object: Termination token detected: \{token}. Treating as missing object.",
                )
                self.stack.push(TriGState::PredicateObjectListEnd)
                self.debug_logger.info(
                  "Object: after push PredicateObjectListEnd, stack: \{self.stack.to_string()}",
                )
                return self.recognize_next(
                  token,
                  RdfContext::TriGRecognizerContext(context),
                  results,
                  errors,
                )
              }
              // 对于 ")"，如果它出现在这里，说明前面的 ObjectCollectionPossibleEnd 没有正确处理。
              // 我们直接报错，以便发现根本问题，而不是陷入死循环。
              _ => self.error(errors, "TOKEN is not a valid RDF object")
            }
          }
          TriGState::ObjectBlankNodePropertyListCurrent => {
            self.debug_logger.info(
              "Entering ObjectBlankNodePropertyListCurrent with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => {
                self.cur_object.push(
                  TermRef::BlankNodeRef(BlankNode::default().as_ref()),
                )
                self.emit_quad(results)
                return self
              }
              _ => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::BlankNodeRef(
                    BlankNode::default().as_ref(),
                  ),
                )
                self.stack.push(TriGState::ObjectBlankNodePropertyListEnd)
                self.stack.push(TriGState::PredicateObjectList)
                return self
              }
            }
          }
          TriGState::ObjectBlankNodePropertyListEnd => {
            self.debug_logger.info(
              "Entering ObjectBlankNodePropertyListEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => {
                let subject = match self.cur_subject.pop() {
                  Some(s) => s
                  None => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        "Internal error: subject stack is empty",
                        Range::default(),
                      ),
                    )
                    return self
                  }
                }

                let blank_ref = match subject {
                  NamedOrBlankNodeRef::BlankNodeRef(b) => b
                  _ => abort("subject should be a blank node")
                }
                self.cur_object.push(TermRef::BlankNodeRef(blank_ref))
                self.emit_quad(results)
                return self
              }
              _ =>
                return self.error(
                  errors, "blank node property lists should end with a ']'",
                )
            }
          }
          TriGState::ObjectCollectionBeginning => {
            self.debug_logger.info(
              "Entering ObjectCollectionBeginning with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")"), _)
              ) => {
                self.debug_logger.info("!!! SETTING in_collection TO TRUE !!!")
                self.in_collection = false
                self.debug_logger.info(
                  "!!! in_collection IS NOW: \{self.in_collection} !!!",
                )
                self.cur_object.push(TermRef::NamedNodeRef(lwNIL))
                self.emit_quad(results)
                self.stack.push(TriGState::PredicateObjectListEnd)
              }
              _ => {
                self.debug_logger.info(
                  "ObjectCollectionBeginning: non-empty collection, first element: \{token}",
                )
                self.in_collection = true
                let root = BlankNode::default()
                self.cur_object.push(TermRef::BlankNodeRef(root.as_ref()))
                self.emit_quad(results)
                self.cur_subject.push(
                  NamedOrBlankNodeRef::BlankNodeRef(root.as_ref()),
                )
                self.cur_predicate.push(
                  NamedNodeRef::NamedNodeRef(lwFIRST.to_string()),
                )
                self.stack.push(TriGState::ObjectCollectionPossibleEnd)
                self.stack.push(TriGState::Object)
              }
            }
          }
          TriGState::ObjectCollectionPossibleEnd => {
            self.debug_logger.info(
              "Entering ObjectCollectionPossibleEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let old = match self.cur_subject.pop() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack is empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let _ = self.cur_object.pop()
            if token
              is LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")"), _)
              ) {
              self.debug_logger.info(
                "ObjectCollectionPossibleEnd: end of collection",
              )
              self.in_collection = false
              let _ = self.cur_predicate.pop()
              results.push(
                RdfStatement::Quad(
                  Quad::Quad(
                    old.into_owned(),
                    lwREST.into_owned(),
                    lwNIL.as_term().into_owned(),
                    self.cur_graph.into_owned(),
                  ),
                ),
              )
              // 确保只压入下一个状态，不要 pop
              self.stack.push(TriGState::PredicateObjectListEnd)
              return self
            } else {
              self.debug_logger.info(
                "ObjectCollectionPossibleEnd: more elements",
              )
              let new = BlankNode::default()
              results.push(
                RdfStatement::Quad(
                  Quad::Quad(
                    old.into_owned(),
                    lwREST.into_owned(),
                    lwNIL.as_term().into_owned(),
                    self.cur_graph.into_owned(),
                  ),
                ),
              )
              self.cur_subject.push(
                NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()),
              )
              self.stack.push(TriGState::ObjectCollectionPossibleEnd)
              self.stack.push(TriGState::Object)
              return self
            }
          }
          TriGState::LiteralPossibleSuffix(value~, emit~) => {
            self.debug_logger.info(
              "Entering LiteralPossibleSuffix(\{value}, emit=\{emit}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::LangTag(language~, direction~), _)
              ) => {
                self.cur_object.push(
                  if direction is Some(direction) {
                    let lang_tag = try
                      LanguageTag::from_str(language.to_lower()) |> Ok
                    catch {
                      e => Err(e)
                    }
                    let resolved_lang_tag = match lang_tag {
                      Ok(tag) => tag
                      Err(e) => {
                        errors.push(
                          RuleRecognizerError::SyntaxError(
                            e.to_string(),
                            Range::default(),
                          ),
                        )
                        return self
                      }
                    }
                    TermRef::LiteralRef(
                      LiteralRef::new_directional_language_tagged_literal_unchecked(
                        value, resolved_lang_tag, direction,
                      ),
                    )
                  } else {
                    TermRef::LiteralRef(
                      Literal::new_language_tagged_literal_unchecked(
                        value,
                        language.to_lower(),
                      ).as_ref(),
                    )
                  },
                )
                if emit {
                  self.emit_quad(results)
                  self.stack.push(TriGState::PredicateObjectListEnd)
                }
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("^^"), _)
              ) => {
                self.stack.push(TriGState::LiteralPossibleSuffix(value~, emit~))
                self
              }
              _ => {
                self.cur_object.push(
                  LiteralRef::new_simple_literal(value).as_term(),
                )
                if emit {
                  self.emit_quad(results)
                  self.stack.push(TriGState::PredicateObjectListEnd)
                }
                self
              }
            }
          }
          TriGState::LiteralExpectDatatype(value~, emit~) => {
            self.debug_logger.info(
              "Entering LiteralExpectDatatype(\{value}, emit=\{emit}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(datatype), _)
              ) => {
                if !self.lenient && datatype == lwLANG_STRING.to_string() {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "The datatype of a literal without a language tag must not be rdf:langString",
                      Range::default(),
                    ),
                  )
                }
                if !self.lenient && datatype == lwDIR_LANG_STRING.to_string() {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "The datatype of a literal without a base direction must not be rdf:dirLangString",
                      Range::default(),
                    ),
                  )
                }
                let datatype = NamedNodeRef::new_unchecked(datatype)
                let data_value = datatype.into_datatype(value)
                self.cur_object.push(
                  TermRef::LiteralRef(
                    LiteralRef::new_typed_literal(data_value, datatype),
                  ),
                )
                if emit {
                  self.emit_quad(results)
                }
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    if !self.lenient && t == lwLANG_STRING {
                      errors.push(
                        RuleRecognizerError::SyntaxError(
                          "The datatype of a literal without a language tag must not be rdf:langString",
                          Range::default(),
                        ),
                      )
                    }
                    if !self.lenient && t == lwDIR_LANG_STRING {
                      errors.push(
                        RuleRecognizerError::SyntaxError(
                          "The datatype of a literal without a base direction must not be rdf:dirLangString",
                          Range::default(),
                        ),
                      )
                    }
                    let data_value = t.into_datatype(value)
                    self.cur_object.push(
                      TermRef::LiteralRef(
                        LiteralRef::new_typed_literal(data_value, t),
                      ),
                    )
                    if emit {
                      self.emit_quad(results)
                    }
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              _ =>
                self.error(
                  errors, "Expecting a datatype IRI after ^^, found TOKEN",
                )
            }
          }
          TriGState::SubjectReifiedTripleEnd => {
            self.debug_logger.info(
              "Entering SubjectReifiedTripleEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let reifier = match self.cur_reifier.pop() {
              Some(r) => r
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: reifier stack empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            self.cur_subject.push(reifier)

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(">>"), _)
              ) => return self
              _ =>
                return self.error(
                  errors, "Expecting '>>' to close a reified triple, found TOKEN",
                )
            }
          }
          TriGState::ObjectReifiedTripleEnd(emit~) => {
            self.debug_logger.info(
              "Entering ObjectReifiedTripleEnd(emit=\{emit}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let subject = match self.cur_subject.pop() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack is empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }

            let blank_ref = match subject {
              NamedOrBlankNodeRef::BlankNodeRef(b) => TermRef::BlankNodeRef(b)
              _ => abort("Subject must be a blank node")
            }
            self.cur_object.push(blank_ref)
            if emit {
              self.emit_quad(results)
            }
            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(">>"), _)
              ) => return self
              _ =>
                return self.error(
                  errors, "Expecting '>>' to close a reified triple, found TOKEN",
                )
            }
          }
          TriGState::TripleTermEnd(emit~) => {
            self.debug_logger.info(
              "Entering TripleTermEnd(emit=\{emit}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let subject = match self.cur_subject.pop() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack empty in TripleTermEnd",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let predicate = match self.cur_predicate.pop() {
              Some(p) => p
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: predicate stack empty in TripleTermEnd",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let object = match self.cur_object.pop() {
              Some(o) => o
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: object stack empty in TripleTermEnd",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let triple = TripleRef::TripleRef(subject, predicate, object)

            self.cur_object.push(TermRef::TripleRef(triple))
            if emit {
              self.emit_quad(results)
            }

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation(")>>"), _)
              ) => return self
              _ =>
                return self
                  .error(
                    errors, "Expecting ')>>' to close a triple term, found TOKEN",
                  )
                  .recognize_next(
                    token,
                    RdfContext::TriGRecognizerContext(context),
                    results,
                    errors,
                  )
            }
          }
          TriGState::EndOfReifiedTripleBeforeReifier => {
            self.debug_logger.info(
              "Entering EndOfReifiedTripleBeforeReifier with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            let subject = match self.cur_subject.pop() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let predicate = match self.cur_predicate.pop() {
              Some(p) => p
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: predicate stack empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let object = match self.cur_object.pop() {
              Some(o) => o
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: object stack empty",
                    Range::default(),
                  ),
                )
                return self
              }
            }
            let triple = TripleRef::TripleRef(subject, predicate, object)

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("~"), _)
              ) => {
                self.stack.push(TriGState::Reifier(triple=triple.into_owned()))
                return self
              }
              _ => {
                let reifier = BlankNode::default()
                results.push(
                  RdfStatement::Quad(
                    Quad::Quad(
                      reifier.as_enum(),
                      lwREIFIES.into_owned(),
                      TermRef::TripleRef(triple).into_owned(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum().as_ref())
                return self
              }
            }
          }
          TriGState::Reifier(triple~) => {
            self.debug_logger.info("Entering Reifier with token: \{token}")
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                let reifier = NamedNodeRef::new_unchecked(iri)
                results.push(
                  RdfStatement::Quad(
                    Quad::Quad(
                      reifier.as_enum().into_owned(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum())
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(reifier) => {
                    results.push(
                      RdfStatement::Quad(
                        Quad::Quad(
                          reifier.as_enum().into_owned(),
                          lwREIFIES.into_owned(),
                          triple.as_enum(),
                          self.cur_graph.into_owned(),
                        ),
                      ),
                    )
                    self.cur_reifier.push(reifier.as_enum())
                    self
                  }
                  Err(e) => {
                    let reifier = BlankNode::default()
                    results.push(
                      RdfStatement::Quad(
                        Quad::Quad(
                          reifier.as_enum(),
                          lwREIFIES.into_owned(),
                          triple.as_enum(),
                          self.cur_graph.into_owned(),
                        ),
                      ),
                    )
                    self.cur_reifier.push(reifier.as_enum().as_ref())
                    self.error(errors, e)
                  }
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(bnode), _)
              ) => {
                let reifier = BlankNodeRef::new_unchecked(bnode)
                results.push(
                  RdfStatement::Quad(
                    Quad::Quad(
                      reifier.as_enum().into_owned(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum())
                self
              }
              _ => {
                let reifier = BlankNode::default()
                results.push(
                  RdfStatement::Quad(
                    Quad::Quad(
                      reifier.as_enum(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum().as_ref())
                self
              }
            }
          }
          TriGState::ReifiedTripleSubject(is_reified~) => {
            self.debug_logger.info(
              "Entering ReifiedTripleSubject(is_reified=\{is_reified}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::BlankNodeRef(
                    BlankNode::default().as_ref(),
                  ),
                )
                self.stack.push(TriGState::QuotedAnonEnd)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::NamedNodeRef(
                    NamedNodeRef::new_unchecked(iri),
                  ),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.cur_subject.push(t.as_enum())
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_subject.push(
                  NamedNodeRef::new_unchecked(label).as_enum(),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<<"), _)
              ) if is_reified => {
                self.stack.push(TriGState::SubjectReifiedTripleEnd)
                self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
                self.stack.push(
                  TriGState::ReifiedTripleSubject(is_reified=true),
                )
                self.stack.push(TriGState::Verb)
                self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
                self
              }
              _ =>
                self.error(
                  errors, "TOKEN is not a valid RDF quoted triple subject: TOKEN",
                )
            }
          }
          TriGState::ReifiedTripleObject(is_reified~) => {
            self.debug_logger.info(
              "Entering ReifiedTripleObject(is_reified=\{is_reified}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.cur_object.push(
                  TermRef::BlankNodeRef(BlankNode::default().as_ref()),
                )
                self.stack.push(TriGState::QuotedAnonEnd)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_object.push(
                  TermRef::BlankNodeRef(BlankNodeRef::new_unchecked(iri)),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.cur_object.push(t.as_term())
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_object.push(
                  BlankNodeRef::new_unchecked(label).as_term(),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::String(value), _)
              ) => {
                self.stack.push(
                  TriGState::LiteralPossibleSuffix(value~, emit=false),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Integer(v), _)
              ) => {
                let v = try @string.parse_int(v) |> Ok catch {
                  e => Err(e)
                }

                match v {
                  Ok(value) => {
                    self.cur_object.push(
                      LiteralRef::new_typed_literal(
                        VarDataType::IntVar(value.to_string()),
                        lwINTEGER,
                      ).as_term(),
                    )
                    //                     self.emit_quad(results)

                    // // 关键：根据 in_collection 决定下一个状态
                    // if self.in_collection {
                    //   self.stack.push(TriGState::ObjectCollectionPossibleEnd)
                    // } else {
                    //   self.stack.push(TriGState::PredicateObjectListEnd)
                    // }
                    self
                  }
                  Err(e) => self.error(errors, e.to_string())
                }
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Decimal(v), _)
              ) => {
                let v = try @string.parse_double(v) |> Ok catch {
                  e => Err(e)
                }
                match v {
                  Ok(value) => {
                    self.cur_object.push(
                      LiteralRef::new_typed_literal(
                        VarDataType::DecimalVar(value.to_string()),
                        lwDECIMAL,
                      ).as_term(),
                    )
                    self.emit_quad(results)
                    self
                  }
                  Err(e) => self.error(errors, e.to_string())
                }
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Double(v), _)
              ) => {
                let v = try @string.parse_double(v) |> Ok catch {
                  e => Err(e)
                }
                match v {
                  Ok(value) => {
                    self.cur_object.push(
                      LiteralRef::new_typed_literal(
                        VarDataType::DoubleVar(value.to_string()),
                        lwDOUBLE,
                      ).as_term(),
                    )
                    self.emit_quad(results)
                    self
                  }
                  Err(e) => self.error(errors, e.to_string())
                }
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("true"), _)
              ) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(VarDataType::TrueVar, lwBOOLEAN).as_term(),
                )
                self.emit_quad(results)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("false"), _)
              ) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::FalseVar,
                    lwBOOLEAN,
                  ).as_term(),
                )
                self.emit_quad(results)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<<("), _)
              ) => {
                self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
                self.stack.push(
                  TriGState::ReifiedTripleObject(is_reified=false),
                )
                self.stack.push(TriGState::Verb)
                self.stack.push(
                  TriGState::ReifiedTripleSubject(is_reified=false),
                )
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("<<"), _)
              ) if is_reified => {
                self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
                self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
                self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
                self.stack.push(TriGState::Verb)
                self.stack.push(
                  TriGState::ReifiedTripleSubject(is_reified=true),
                )
                self
              }
              _ =>
                self.error(
                  errors, "TOKEN is not a valid RDF quoted triple object",
                )
            }
          }
          TriGState::QuotedAnonEnd => {
            self.debug_logger.info(
              "Entering QuotedAnonEnd with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("]"), _)
              ) => return self
              _ =>
                return self.error(
                  errors, "Anonymous blank node with a property list are not allowed in quoted triples",
                )
            }
          }
          TriGState::ExpectAtKeyword =>
            return match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "base") => {
                self.stack.push(TriGState::BaseExpectIri)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "prefix") => {
                self.stack.push(TriGState::PrefixExpectPrefix)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword(k), _)
              ) if eq_ignore_ascii_case(k, "version") => {
                self.stack.push(TriGState::VersionExpectVersion)
                self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("{"), _)
              ) if context.with_graph_name => {
                self.stack.push(TriGState::WrappedGraph)
                self

                // self.recognize_next(token, RdfContext ::TriGRecognizerContext(context), results, errors)
              }
              _ =>
                self.error(
                  errors, "Expected 'base', 'prefix', or 'version' after '@'",
                )
            }
          TriGState::WrappedGraphOrPredicateObjectList(term~) => {
            self.debug_logger.info(
              "Entering WrappedGraphOrPredicateObjectList with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            return match token {
              // 1. 检查是否是图名块开始 '{'
              // 只有在 context.with_graph_name 为 true 时，'{ ' 才可能表示图名块
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("{"), _)
              ) if context.with_graph_name => {
                self.debug_logger.info(
                  "WrappedGraphOrPredicateObjectList: Graph branch",
                )
                // 将之前的 term 作为图名
                self.cur_graph = term.into_graph()
                self.stack.push(TriGState::WrappedGraph)
                // 注意：WrappedGraph 状态会消耗 '{' 并推入 Triples
                self
              }

              // 2.1 谓语是 'a' (rdf:type)
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("a"), _)
              ) => {
                self.debug_logger.info(
                  "WrappedGraphOrPredicateObjectList: 'a' predicate",
                )
                self.cur_predicate.push(lwTYPE)
                self.stack.push(TriGState::ObjectsList)
                self
              }

              // 2.2 谓语是 IRI
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.debug_logger.info(
                  "WrappedGraphOrPredicateObjectList: IRI predicate: \{iri}",
                )
                self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))
                self.stack.push(TriGState::ObjectsList)
                self
              }

              // 2.3 谓语是前缀名
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(
                  N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
                  _
                )
              ) =>
                match
                  resolve_local_name(
                    prefix,
                    localx,
                    might_be_invalid_iri,
                    context.prefixes,
                  ) {
                  Ok(t) => {
                    self.debug_logger.info(
                      "WrappedGraphOrPredicateObjectList: PrefixedName predicate: \{t}",
                    )
                    self.cur_predicate.push(t)
                    self.stack.push(TriGState::ObjectsList)
                    self
                  }
                  Err(e) => self.error(errors, e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("("), _)
              ) => {
                // 谓词是当前 token 之前已经设置好的
                // 直接进入 ObjectsList 处理宾语
                //  self.in_collection = true 
                self.debug_logger.info(
                  "WrappedGraphOrPredicateObjectList: Collection start",
                )
                // 必须推入 ObjectCollectionBeginning 来初始化集合的空白节点和 rdf:first/rdf:rest 结构
                // self.stack.push(TriGState::ObjectCollectionBeginning)
                self.stack.push(TriGState::ObjectsList)
                self
              }
              // 3. 其他所有情况均为语法错误（主语后必须跟谓语或图名块）
              _ => {
                self.debug_logger.info(
                  "WrappedGraphOrPredicateObjectList: Invalid token: \{token}",
                )
                self.error(
                  errors,
                  "Expected a predicate (IRI or 'a') or graph block '{' after subject, found: \{token.to_string()}",
                )
              }
            }
          }
        }
      _ => break
    }
  }
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    )
    | LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      self.stack.push(TriGState::TriGDoc)
      self
    }
    _ => self
  }
}
