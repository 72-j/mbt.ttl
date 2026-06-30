///|
impl RuleRecognizer for TriGRecognizer with fn recognize_next(
  self : TriGRecognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
  self.debug_logger.info(
    "Stack Depth: \{self.stack.length()} Token stack: \{self.stack.to_string()}",
  )

  let context = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ => abort("Invalid context for TriGRecognizer")
  }
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
          TriGState::TriGDoc =>
            return self.handle_trig_doc(token, context, errors)
          TriGState::TriplesOrGraph =>
            return self.handle_triples_or_graph(token, context, errors)
          TriGState::WrappedGraph =>
            return self.handle_wrapped_graph(token, context, results, errors)
          TriGState::WrappedGraphPossibleEnd =>
            return self.handle_wrapped_graph_possible_end(token, errors)
          TriGState::Triples =>
            return self.handle_triples(token, context, errors)
          TriGState::PredicateObjectList =>
            return self.handle_predicate_object_list(
              token, context, results, errors,
            )
          TriGState::PredicateObjectListEnd =>
            return self.handle_predicate_object_list_end(token, errors)
          TriGState::PredicateObjectListPossibleContinuation =>
            return self.handle_predicate_object_list_possible_continuation(
              token,
            )
          TriGState::ObjectsList =>
            return self.handle_objects_list(token, context, results, errors)
          TriGState::AnnotationBlock(with_reifier~) =>
            return self.handle_annotation_block(
              with_reifier, token, results, errors,
            )
          TriGState::Verb =>
            return self.handle_verb(token, context, results, errors)
          TriGState::Object =>
            return self.handle_object(token, context, results, errors)
          TriGState::ObjectBlankNodePropertyListEnd =>
            return self.handle_object_blank_node_property_list_end(
              token, results, errors,
            )
          TriGState::ObjectCollectionBeginning =>
            return self.handle_object_collection_beginning(
              token, context, results, errors,
            )
          TriGState::ObjectCollectionPossibleEnd =>
            return self.handle_object_collection_possible_end(
              token, context, results, errors,
            )
          TriGState::LiteralPossibleSuffix(value~, emit~) =>
            return self.handle_literal_possible_suffix(
              value, emit, token, results, errors,
            )
          TriGState::ObjectReifiedTripleEnd(emit~) =>
            return self.handle_object_reified_triple_end(
              emit, token, results, errors,
            )
          TriGState::WrappedGraphOrPredicateObjectList(term~) =>
            return self.handle_wrapped_graph_or_predicate_object_list(
              term, token, context, results, errors,
            )
          TriGState::InCollection => return self.handle_in_collection()
          TriGState::CollectionElement =>
            return self.handle_collection_element(token)
          TriGState::CollectionEnd =>
            return self.handle_collection_end(token, results, errors)
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
                        self.last_range,
                      ),
                    )
                }
              }
              self.stack.push(TriGState::ExpectDot)
              return self
            } else {
              return self.error("The BASE keyword should be followed by an IRI")
            }
          }
          TriGState::PrefixExpectPrefix => {
            self.debug_logger.info(
              "Entering PrefixExpectPrefix with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PrefixedName(prefix~, localx~, ..), _)
              ) if localx.is_empty() => {
                self.stack.push(TriGState::PrefixExpectIri(name=prefix))
                return self
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
                return self
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
                return self
              }
              _ =>
                return self.error(
                  "The PREFIX keyword should be followed by a prefix like 'ex:'",
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
                "The PREFIX declaration should be followed by a prefix and its value as an IRI",
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
                "The VERSION keyword should be followed by a single quoted string like \"1.2\"",
              )
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
                    self.last_range,
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
                RdfOut::Quad(
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
                RdfOut::Quad(
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

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_graph = GraphNameRef::NamedNodeRef(
                  NamedNodeRef::new_unchecked(iri),
                )
                return self
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
                    return self
                  }
                  Err(e) => return self.error(e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_graph = GraphNameRef::BlankNodeRef(
                  BlankNodeRef::new_unchecked(label),
                )
                return self
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
                return self
              }
              _ => return self.error("TOKEN is not a valid graph name")
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
                  "Anonymous blank node with a property list are not allowed as graph name",
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
                  .error("Annotations should end with '|}'")
                  .recognize_next(
                    token,
                    RdfContext::TriGRecognizerContext(context),
                    results,
                    errors,
                  )
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
          TriGState::LiteralExpectDatatype(value~, emit~) => {
            self.debug_logger.info(
              "Entering LiteralExpectDatatype(\{value}, emit=\{emit}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(datatype), _)
              ) => {
                if !self.lenient && datatype == lwLANG_STRING.to_string() {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "The datatype of a literal without a language tag must not be rdf:langString",
                      self.last_range,
                    ),
                  )
                }
                if !self.lenient && datatype == lwDIR_LANG_STRING.to_string() {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "The datatype of a literal without a base direction must not be rdf:dirLangString",
                      self.last_range,
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
                return self
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
                          self.last_range,
                        ),
                      )
                    }
                    if !self.lenient && t == lwDIR_LANG_STRING {
                      errors.push(
                        RuleRecognizerError::SyntaxError(
                          "The datatype of a literal without a base direction must not be rdf:dirLangString",
                          self.last_range,
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
                    return self
                  }
                  Err(e) => return self.error(e)
                }
              _ =>
                return self.error(
                  "Expecting a datatype IRI after ^^, found TOKEN",
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
                    self.last_range,
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
                  "Expecting '>>' to close a reified triple, found TOKEN",
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
                    self.last_range,
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
                    self.last_range,
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
                    self.last_range,
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
                  .error("Expecting ')>>' to close a triple term, found TOKEN")
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
                    self.last_range,
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
                    self.last_range,
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
                    self.last_range,
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
                  RdfOut::Quad(
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

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                let reifier = NamedNodeRef::new_unchecked(iri)
                results.push(
                  RdfOut::Quad(
                    Quad::Quad(
                      reifier.as_enum().into_owned(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum())
                return self
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
                      RdfOut::Quad(
                        Quad::Quad(
                          reifier.as_enum().into_owned(),
                          lwREIFIES.into_owned(),
                          triple.as_enum(),
                          self.cur_graph.into_owned(),
                        ),
                      ),
                    )
                    self.cur_reifier.push(reifier.as_enum())
                    return self
                  }
                  Err(e) => {
                    let reifier = BlankNode::default()
                    results.push(
                      RdfOut::Quad(
                        Quad::Quad(
                          reifier.as_enum(),
                          lwREIFIES.into_owned(),
                          triple.as_enum(),
                          self.cur_graph.into_owned(),
                        ),
                      ),
                    )
                    self.cur_reifier.push(reifier.as_enum().as_ref())
                    return self.error(e)
                  }
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(bnode), _)
              ) => {
                let reifier = BlankNodeRef::new_unchecked(bnode)
                results.push(
                  RdfOut::Quad(
                    Quad::Quad(
                      reifier.as_enum().into_owned(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum())
                return self
              }
              _ => {
                let reifier = BlankNode::default()
                results.push(
                  RdfOut::Quad(
                    Quad::Quad(
                      reifier.as_enum(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum().as_ref())

                return self
              }
            }
          }
          TriGState::ReifiedTripleSubject(is_reified~) => {
            self.debug_logger.info(
              "Entering ReifiedTripleSubject(is_reified=\{is_reified}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::BlankNodeRef(
                    BlankNode::default().as_ref(),
                  ),
                )
                self.stack.push(TriGState::QuotedAnonEnd)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_subject.push(
                  NamedOrBlankNodeRef::NamedNodeRef(
                    NamedNodeRef::new_unchecked(iri),
                  ),
                )
                return self
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
                    return self
                  }
                  Err(e) => return self.error(e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_subject.push(
                  NamedNodeRef::new_unchecked(label).as_enum(),
                )
                return self
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
                return self
              }
              _ =>
                return self.error(
                  "TOKEN is not a valid RDF quoted triple subject: TOKEN",
                )
            }
          }
          TriGState::ReifiedTripleObject(is_reified~) => {
            self.debug_logger.info(
              "Entering ReifiedTripleObject(is_reified=\{is_reified}) with token: \{token}",
            )
            self.debug_logger.info("Token stack: \{self.stack.to_string()}")

            match token {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Punctuation("["), _)
              ) => {
                self.cur_object.push(
                  TermRef::BlankNodeRef(BlankNode::default().as_ref()),
                )
                self.stack.push(TriGState::QuotedAnonEnd)
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::Iri(iri), _)
              ) => {
                self.cur_object.push(
                  TermRef::BlankNodeRef(BlankNodeRef::new_unchecked(iri)),
                )
                return self
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
                    return self
                  }
                  Err(e) => return self.error(e)
                }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::BlankNodeLabel(label), _)
              ) => {
                self.cur_object.push(
                  BlankNodeRef::new_unchecked(label).as_term(),
                )
                return self
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::String(value), _)
              ) => {
                self.stack.push(
                  TriGState::LiteralPossibleSuffix(value~, emit=false),
                )
                return self
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
                    return self
                  }
                  Err(e) => return self.error(e.to_string())
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
                    return self
                  }
                  Err(e) => return self.error(e.to_string())
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
                    return self
                  }
                  Err(e) => return self.error(e.to_string())
                }
              }
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token(N3Token::PlainKeyword("true"), _)
              ) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(VarDataType::TrueVar, lwBOOLEAN).as_term(),
                )
                self.emit_quad(results)
                return self
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
                return self
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
                return self
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
                return self
              }
              _ =>
                return self.error(
                  "TOKEN is not a valid RDF quoted triple object",
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
                  "Anonymous blank node with a property list are not allowed in quoted triples",
                )
            }
          }
          TriGState::ExpectAtKeyword =>
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
                LocatedN3Token(N3Token::Punctuation("{"), _)
              ) if context.with_graph_name => {
                self.stack.push(TriGState::WrappedGraph)
                return self

                // self.recognize_next(token, RdfContext ::TriGRecognizerContext(context), results, errors)
              }
              _ =>
                return self.error(
                  "Expected 'base', 'prefix', or 'version' after '@'",
                )
            }
        }
      None => break
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
