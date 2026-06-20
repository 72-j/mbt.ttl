///|
pub struct TriGRecognizer {
  stack : Array[TriGState]
  cur_subject : Array[NamedOrBlankNodeRef]
  cur_predicate : Array[NamedNodeRef]
  cur_object : Array[TermRef]
  mut cur_graph : GraphNameRef
  cur_reifier : Array[NamedOrBlankNodeRef]
  lenient : Bool
}

///|
pub struct TriGRecognizerContext {
  lexer_options : LexerOptions
  with_graph_name : Bool
  prefixes : Map[String, Iri]
}

///|
fn TriGRecognizerContext::as_ctx(self : TriGRecognizerContext) -> Context {
  Context::TriGRecognizerContext(self)
}

///|
// pub struct TriGLexerOptions {
//   mut base_iri : Iri?
// } derive(Debug)

///|
// fn TriGLexerOptions::TriGLexerOptions() -> TriGLexerOptions {
//   { base_iri: None }
// }

///|
pub fn TriGRecognizerContext::prefixes(
  self : TriGRecognizerContext,
) -> Map[String, Iri] {
  self.prefixes
}

///|
impl RuleRecognizer for TriGRecognizer with fn error_recovery_state(
  self : TriGRecognizer,
) -> TriGRecognizer {
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_reifier.clear()
  self.cur_graph = GraphNameRef::DefaultGraph
  self
}

///|
impl RuleRecognizer for TriGRecognizer with fn recognize_next(
  self : TriGRecognizer,
  token : TokenOrLineJump[N3Token],
  context : Context,
  results : Array[LexOutput],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
  // let token = token
  let context = match context {
    Context::TriGRecognizerContext(c) => c
    _ => abort("Invalid context for TriGRecognizer")
  }
  if self.stack.pop() is Some(rule) {
    match rule {
      TriGState::TriGDoc => {
        self.cur_graph = GraphNameRef::DefaultGraph
        self.stack.push(TriGState::TriGDoc)
        match token {
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "base",
            ) => {
            self.stack.push(TriGState::BaseExpectIri)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "prefix",
            ) => {
            self.stack.push(TriGState::PrefixExpectPrefix)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "version",
            ) => {
            self.stack.push(TriGState::VersionExpectVersion)
            self
          }
          TokenOrLineJump::Token(
            N3Token::LangTag(language="prefix", direction=None)
          ) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::PrefixExpectPrefix)
            self
          }
          TokenOrLineJump::Token(
            N3Token::LangTag(language="base", direction=None)
          ) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::BaseExpectIri)
            self
          }
          TokenOrLineJump::Token(
            N3Token::LangTag(language="version", direction=None)
          ) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::VersionExpectVersion)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "graph",
            ) &&
            context.with_graph_name => {
            self.stack.push(TriGState::WrappedGraph)
            self.stack.push(TriGState::GraphName)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("{")) if context.with_graph_name => {
            self.stack.push(TriGState::WrappedGraph)
            self.recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
          _ => {
            self.stack.push(TriGState::TriplesOrGraph)
            self.recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
        }
      }
      TriGState::ExpectDot => {
        let _ = self.cur_subject.pop()
        if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) {
          self
        } else {
          errors.push(RuleRecognizerError::TripleMissingDot)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::BaseExpectIri =>
        if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
          let iri_ref = Iri::Iri(iri).as_ref()
          if self.lenient {
            // 宽松模式：直接解析，不检查有效性
            context.lexer_options.base_iri = Some(
              IriRef::parse_unchecked(iri_ref),
            )
          } else {
            // 严格模式：检查解析结果
            match IriRef::parse(iri_ref) {
              Ok(parsed_iri) =>
                context.lexer_options.base_iri = Some(parsed_iri)
              Err(e) =>
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Invalid BASE IRI: \{e.message()}",
                    TextPosition::default(), // 如果有位置信息，应传入实际位置
                  ),
                )
              // 可以选择保持原状或设为 None，这里选择不更新 base_iri
            }
          }
          self
        } else {
          self.error(errors, "The BASE keyword should be followed by an IRI")
        }
      TriGState::PrefixExpectPrefix =>
        match token {
          TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, ..)) if localx.is_empty() => {
            self.stack.push(TriGState::PrefixExpectIri(name=prefix))
            self
          }
          _ =>
            self.error(
              errors, "The PREFIX keyword should be followed by a prefix like 'ex:'",
            )
        }
      TriGState::PrefixExpectIri(name~) =>
        if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
          let iri = Iri::Iri(iri)
          context.prefixes.set(name, iri)
          self
        } else {
          self.error(
            errors, "The PREFIX declaration should be followed by a prefix and its value as an IRI",
          )
        }
      TriGState::VersionExpectVersion =>
        if token is TokenOrLineJump::Token(N3Token::String(_)) {
          self
        } else {
          self.error(
            errors, "The VERSION keyword should be followed by a single quoted string like \"1.2\"",
          )
        }
      TriGState::TriplesOrGraph =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.stack.push(
              TriGState::WrappedGraphOrPredicateObjectList(
                term=NamedNodeRef::new_unchecked(iri).as_enum(),
              ),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.stack.push(
                  TriGState::WrappedGraphOrPredicateObjectList(term=t.as_enum()),
                )
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.stack.push(
              TriGState::WrappedGraphOrPredicateObjectList(
                term=NamedNodeRef::new_unchecked(label).as_enum(),
              ),
            )
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.stack.push(TriGState::WrappedGraphBlankNodePropertyListCurrent)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::PredicateObjectList)
            self.stack.push(TriGState::SubjectCollectionBeginning)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::MaybePredicateObjectList)
            self.stack.push(TriGState::SubjectReifiedTripleEnd)
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self
          }
          _ => self.error(errors, "TOKEN is not a valid subject or graph name")
        }
      TriGState::WrappedGraphOrPredicateObjectList(term~) => {
        if token == TokenOrLineJump::Token(N3Token::Punctuation("{")) &&
          context.with_graph_name {
          self.cur_graph = term.into_graph()

          self.stack.push(TriGState::WrappedGraph)
        } else {
          self.cur_graph = term.into_graph()
          self.stack.push(TriGState::ExpectDot)
          self.stack.push(TriGState::PredicateObjectList)
        }
        self.recognize_next(
          token,
          Context::TriGRecognizerContext(context),
          results,
          errors,
        )
      }
      TriGState::WrappedGraphBlankNodePropertyListCurrent =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.stack.push(
            TriGState::WrappedGraphOrPredicateObjectList(
              term=BlankNode::default().as_ref().as_enum(),
            ),
          )
          self
        } else {
          self.cur_subject.push(BlankNode::default().as_ref().as_enum())
          self.stack.push(TriGState::ExpectDot)
          self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
          self.stack.push(TriGState::PredicateObjectList)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::SubjectBlankNodePropertyListEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
          self
        } else {
          errors.push(
            RuleRecognizerError::BlankNodePropertyListMissingEndBracket,
          )
          self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::SubjectBlankNodePropertyListAfter =>
        if token is TokenOrLineJump::Token(N3Token::Punctuation("." | "}")) {
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        } else {
          self.stack.push(TriGState::PredicateObjectList)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::SubjectCollectionBeginning =>
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          self.cur_subject.push(lwNIL.as_enum())
          self
        } else {
          let root = NamedOrBlankNodeRef::BlankNodeRef(
            BlankNode::default().as_ref(),
          )
          self.cur_subject.push(root)
          self.cur_subject.push(root)
          self.cur_predicate.push(lwFIRST)
          self.stack.push(TriGState::SubjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::SubjectCollectionPossibleEnd => {
        let old = match self.cur_subject.pop() {
          Some(node) => node
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack is empty",
                TextPosition::default(),
              ),
            )
            return self
          }
        }
        let _ = self.cur_object.pop()
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          let _ = self.cur_predicate.pop()
          results.push(
            LexOutput::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.into_owned().as_term(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self
        } else {
          let new = BlankNode::default()
          results.push(
            LexOutput::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.as_term().into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()))
          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::WrappedGraph =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("{")) {
          self.stack.push(TriGState::WrappedGraphPossibleEnd)
          self.stack.push(TriGState::Triples)
          self
        } else {
          self.error(
            errors, "The GRAPH keyword should be followed by a graph name and a value in '{'",
          )
        }
      TriGState::WrappedGraphPossibleEnd => {
        let _ = self.cur_subject.pop()
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("}")) => self
          TokenOrLineJump::Token(N3Token::Punctuation(".")) => {
            self.stack.push(TriGState::WrappedGraphPossibleEnd)
            self.stack.push(TriGState::Triples)
            self
          }
          _ => {
            errors.push(RuleRecognizerError::TripleMissingDot)
            self.recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
        }
      }
      TriGState::Triples =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("}")) =>
            self.recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
            )
            self.stack.push(TriGState::TriplesBlankNodePropertyListCurrent)
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_subject.push(NamedNodeRef::new_unchecked(iri).as_enum())
            self.stack.push(TriGState::PredicateObjectList)
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::BlankNodeRef(
                BlankNodeRef::new_unchecked(label),
              ),
            )
            self.stack.push(TriGState::PredicateObjectList)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
            self.stack.push(TriGState::PredicateObjectList)
            self.stack.push(TriGState::SubjectCollectionBeginning)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) => {
            self.stack.push(TriGState::MaybePredicateObjectList)
            self.stack.push(TriGState::SubjectReifiedTripleEnd)
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self
          }
          _ => self.error(errors, "TOKEN is not a valid RDF subject")
        }
      TriGState::TriplesBlankNodePropertyListCurrent =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.stack.push(TriGState::PredicateObjectList)
          self
        } else {
          self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
          self.stack.push(TriGState::PredicateObjectList)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::GraphName =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_graph = GraphNameRef::NamedNodeRef(
              NamedNodeRef::new_unchecked(iri),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_graph = GraphNameRef::BlankNodeRef(
              BlankNodeRef::new_unchecked(label),
            )
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.stack.push(TriGState::GraphNameAnonEnd)
            self
          }
          _ => self.error(errors, "TOKEN is not a valid graph name")
        }
      TriGState::GraphNameAnonEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.cur_graph = GraphNameRef::BlankNodeRef(
            BlankNode::default().as_ref(),
          )
          self
        } else {
          self.error(
            errors, "Anonymous blank node with a property list are not allowed as graph name",
          )
        }
      TriGState::MaybePredicateObjectList => {
        if token != TokenOrLineJump::Token(N3Token::Punctuation(".")) {
          self.stack.push(TriGState::PredicateObjectList)
        }
        self.recognize_next(
          token,
          Context::TriGRecognizerContext(context),
          results,
          errors,
        )
      }
      TriGState::PredicateObjectList => {
        self.stack.push(TriGState::PredicateObjectListEnd)
        self.stack.push(TriGState::ObjectsList)
        self.stack.push(TriGState::Verb)
        self.recognize_next(
          token,
          Context::TriGRecognizerContext(context),
          results,
          errors,
        )
      }
      TriGState::PredicateObjectListEnd => {
        let _ = self.cur_predicate.pop()
        if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
          self.stack.push(TriGState::PredicateObjectListPossibleContinuation)
          self
        } else {
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::PredicateObjectListPossibleContinuation =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
          self.stack.push(TriGState::PredicateObjectListPossibleContinuation)
          self
        } else if token
          is TokenOrLineJump::Token(
            N3Token::Punctuation("." | "}" | "]" | "|}")
          ) {
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        } else {
          self.stack.push(TriGState::PredicateObjectListEnd)
          self.stack.push(TriGState::ObjectsList)
          self.stack.push(TriGState::Verb)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::ObjectsList => {
        self.stack.push(TriGState::AnnotationEnd(with_reifier=false))
        self.stack.push(TriGState::Object)
        self.recognize_next(
          token,
          Context::TriGRecognizerContext(context),
          results,
          errors,
        )
      }
      TriGState::AnnotationBlock(with_reifier~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation(",")) => {
            let _ = self.cur_object.pop()
            if with_reifier {
              let _ = self.cur_reifier.pop()
            }
            self.stack.push(TriGState::AnnotationBlock(with_reifier=false))
            self.stack.push(TriGState::Object)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("~")) => {
            let cur_sub = match self.cur_subject.last() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack empty",
                    TextPosition::default(),
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
                    TextPosition::default(),
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
                    TextPosition::default(),
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
          TokenOrLineJump::Token(N3Token::Punctuation("{|")) => {
            let cur_sub = match self.cur_subject.last() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack empty",
                    TextPosition::default(),
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
                    TextPosition::default(),
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
                    TextPosition::default(),
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
                      TextPosition::default(),
                    ),
                  )
                  return self
                }
              }
            } else {
              let reifier = BlankNode::default()
              results.push(
                LexOutput::Quad(
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
            self.recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
        }
      TriGState::AnnotationEnd(with_reifier~) => {
        let _ = self.cur_subject.pop()
        self.stack.push(TriGState::AnnotationEnd(with_reifier~))
        if token == TokenOrLineJump::Token(N3Token::Punctuation("|}")) {
          self
        } else {
          self
          .error(errors, "Annotations should end with '|}'")
          .recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::Verb =>
        match token {
          TokenOrLineJump::Token(N3Token::PlainKeyword("a")) => {
            self.cur_predicate.push(lwTYPE)
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
      TriGState::Object =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_object.push(
              TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri)),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.cur_object.push(TermRef::NamedNodeRef(t))
                self.emit_quad(results)
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_object.push(
              TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(label)),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.stack.push(TriGState::ObjectBlankNodePropertyListCurrent)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
            self.stack.push(TriGState::ObjectCollectionBeginning)
            self
          }
          TokenOrLineJump::Token(N3Token::String(value))
          | TokenOrLineJump::Token(N3Token::LongString(value)) => {
            self.stack.push(TriGState::LiteralPossibleSuffix(value~, emit=true))
            self
          }
          TokenOrLineJump::Token(N3Token::Integer(v)) => {
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
                self.emit_quad(results)
                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::Decimal(v)) => {
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
          TokenOrLineJump::Token(N3Token::Double(v)) => {
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
          TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::TrueVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::FalseVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=true))
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<(")) => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=true))
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=false))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=false))
            self
          }
          _ => self.error(errors, "TOKEN is not a valid RDF object")
        }
      TriGState::ObjectBlankNodePropertyListCurrent =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.cur_object.push(
            TermRef::BlankNodeRef(BlankNode::default().as_ref()),
          )
          self.emit_quad(results)
          self
        } else {
          self.cur_subject.push(
            NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
          )
          self.stack.push(TriGState::ObjectBlankNodePropertyListEnd)
          self.stack.push(TriGState::PredicateObjectList)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::ObjectBlankNodePropertyListEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          let subject = match self.cur_subject.pop() {
            Some(s) => s
            None => {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "Internal error: subject stack is empty",
                  TextPosition::default(),
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
          self
        } else {
          self.error(errors, "blank node property lists should end with a ']'")
        }
      TriGState::ObjectCollectionBeginning =>
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          self.cur_object.push(TermRef::NamedNodeRef(lwNIL))
          self.emit_quad(results)
          self
        } else {
          let root = BlankNode::default()
          self.cur_object.push(TermRef::BlankNodeRef(root.as_ref()))
          self.emit_quad(results)
          self.cur_subject.push(
            NamedOrBlankNodeRef::BlankNodeRef(root.as_ref()),
          )
          self.cur_predicate.push(
            NamedNode::NamedNode(lwFIRST.to_string()).as_ref(),
          )
          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      TriGState::ObjectCollectionPossibleEnd => {
        // if token.is_eof() || token.is_dot() || token.is_rbracket() || token.is_rbrace() || token.is_comma() || token.is_semicolon() || token.is_newline() || token.is_eol() || token.is_eof() {
        let old = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack is empty",
                TextPosition::default(),
              ),
            )
            return self
          }
        }
        let _ = self.cur_object.pop()
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          let _ = self.cur_predicate.pop()
          results.push(
            LexOutput::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.as_term().into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self
        } else {
          let new = BlankNode::default()
          results.push(
            LexOutput::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.as_term().into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()))
          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
        // }
      }
      TriGState::LiteralPossibleSuffix(value~, emit~) =>
        match token {
          TokenOrLineJump::Token(N3Token::LangTag(language~, direction~)) => {
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
                        TextPosition::default(),
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
            }
            self
          }
          // TokenOrLineJump::Token(N3Token::LangTag(language~,..)) => {
          //   self.cur_object.push(
          //     TermRef::LiteralRef(
          //       LiteralRef::new_language_tagged_literal_unchecked(
          //         value,
          //         language.to_lower(),
          //       ),
          //     ),
          //   )
          //   if emit {
          //     self.emit_quad(results)
          //   }
          //   self
          // }
          TokenOrLineJump::Token(N3Token::Punctuation("^^")) => {
            self.stack.push(TriGState::LiteralPossibleSuffix(value~, emit~))
            self
          }
          _ => {
            self.cur_object.push(
              LiteralRef::new_simple_literal(value).as_term(),
            )
            if emit {
              self.emit_quad(results)
            }
            self.recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
        }
      TriGState::LiteralExpectDatatype(value~, emit~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(datatype)) => {
            if !self.lenient && datatype == lwLANG_STRING.to_string() {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "The datatype of a literal without a language tag must not be rdf:langString",
                  TextPosition::default(),
                ),
              )
            }
            if !self.lenient && datatype == lwDIR_LANG_STRING.to_string() {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "The datatype of a literal without a base direction must not be rdf:dirLangString",
                  TextPosition::default(),
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
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
                      TextPosition::default(),
                    ),
                  )
                }
                if !self.lenient && t == lwDIR_LANG_STRING {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "The datatype of a literal without a base direction must not be rdf:dirLangString",
                      TextPosition::default(),
                    ),
                  )
                }
                // let datatype = t
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
            self
            .error(errors, "Expecting a datatype IRI after ^^, found TOKEN")
            .recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
        }
      TriGState::SubjectReifiedTripleEnd => {
        let reifier = match self.cur_reifier.pop() {
          Some(r) => r
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: reifier stack empty",
                TextPosition::default(),
              ),
            )
            return self
          }
        }
        self.cur_subject.push(reifier)
        if token == TokenOrLineJump::Token(N3Token::Punctuation(">>")) {
          self
        } else {
          self
          .error(
            errors, "Expecting '>>' to close a reified triple, found TOKEN",
          )
          .recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::ObjectReifiedTripleEnd(emit~) => {
        let subject = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack is empty",
                TextPosition::default(),
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
        if token == TokenOrLineJump::Token(N3Token::Punctuation(">>")) {
          self
        } else {
          self
          .error(
            errors, "Expecting '>>' to close a reified triple, found TOKEN",
          )
          .recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::TripleTermEnd(emit~) => {
        let subject = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack empty in TripleTermEnd",
                TextPosition::default(),
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
                TextPosition::default(),
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
                TextPosition::default(),
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
        if token == TokenOrLineJump::Token(N3Token::Punctuation(")>>")) {
          self
        } else {
          self
          .error(errors, "Expecting ')>>' to close a triple term, found TOKEN")
          .recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::EndOfReifiedTripleBeforeReifier => {
        let subject = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack empty",
                TextPosition::default(),
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
                TextPosition::default(),
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
                TextPosition::default(),
              ),
            )
            return self
          }
        }
        let triple = TripleRef::TripleRef(subject, predicate, object)

        if token == TokenOrLineJump::Token(N3Token::Punctuation("~")) {
          self.stack.push(TriGState::Reifier(triple=triple.into_owned()))
          self
        } else {
          let reifier = BlankNode::default()
          results.push(
            LexOutput::Quad(
              Quad::Quad(
                reifier.as_enum(),
                lwREIFIES.into_owned(),
                TermRef::TripleRef(triple).into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self.cur_reifier.push(reifier.as_enum().as_ref())
          self.recognize_next(
            token,
            Context::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::Reifier(triple~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            let reifier = NamedNodeRef::new_unchecked(iri)
            results.push(
              LexOutput::Quad(
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
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
                  LexOutput::Quad(
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
                  LexOutput::Quad(
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
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(bnode)) => {
            let reifier = BlankNodeRef::new_unchecked(bnode)
            results.push(
              LexOutput::Quad(
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
              LexOutput::Quad(
                Quad::Quad(
                  reifier.as_enum(),
                  lwREIFIES.into_owned(),
                  triple.as_enum(),
                  self.cur_graph.into_owned(),
                ),
              ),
            )
            self.cur_reifier.push(reifier.as_enum().as_ref())
            self.recognize_next(
              token,
              Context::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
        }
      TriGState::ReifiedTripleSubject(is_reified~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
            )
            self.stack.push(TriGState::QuotedAnonEnd)
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::NamedNodeRef(
                NamedNodeRef::new_unchecked(iri),
              ),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_subject.push(NamedNodeRef::new_unchecked(label).as_enum())
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) if is_reified => {
            self.stack.push(TriGState::SubjectReifiedTripleEnd)
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self
          }
          _ =>
            self.error(
              errors, "TOKEN is not a valid RDF quoted triple subject: TOKEN",
            )
        }
      TriGState::ReifiedTripleObject(is_reified~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.cur_object.push(
              TermRef::BlankNodeRef(BlankNode::default().as_ref()),
            )
            self.stack.push(TriGState::QuotedAnonEnd)
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_object.push(
              TermRef::BlankNodeRef(BlankNodeRef::new_unchecked(iri)),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
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
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_object.push(BlankNodeRef::new_unchecked(label).as_term())
            self
          }
          TokenOrLineJump::Token(N3Token::String(value)) => {
            self.stack.push(
              TriGState::LiteralPossibleSuffix(value~, emit=false),
            )
            self
          }
          TokenOrLineJump::Token(N3Token::Integer(v)) => {
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
                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::Decimal(v)) => {
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
          TokenOrLineJump::Token(N3Token::Double(v)) => {
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
          TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::TrueVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::FalseVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<(")) => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=false))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=false))
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) if is_reified => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self
          }
          _ =>
            self.error(errors, "TOKEN is not a valid RDF quoted triple object")
        }
      TriGState::QuotedAnonEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self
        } else {
          self.error(
            errors, "Anonymous blank node with a property list are not allowed in quoted triples",
          )
        }
    }
  } else if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) ||
    token == TokenOrLineJump::Token(N3Token::Punctuation("}")) {
    self.stack.push(TriGState::TriGDoc)
    self
  } else {
    self
  }
}

///|
impl RuleRecognizer for TriGRecognizer with fn recognize_end(
  self : TriGRecognizer,
  _context : Context,
  results : Array[LexOutput],
  errors : Array[RuleRecognizerError],
) -> Unit {
  match self.stack {
    [] | [TriGState::TriGDoc] => {
      debug_assert(() => self.cur_subject.is_empty())
      debug_assert(() => self.cur_predicate.is_empty())
      debug_assert(() => self.cur_object.is_empty())
    }
    [.., TriGState::LiteralPossibleSuffix(value~, emit=true)] => {
      self.cur_object.push(LiteralRef::new_simple_literal(value).as_term())
      self.emit_quad(results)
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Triples should be followed by a dot",
          TextPosition::default(),
        ),
      )
    }
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          TextPosition::default(),
        ),
      )
  }
}

///|
impl RuleRecognizer for TriGRecognizer with fn lexer_options(context : Context) -> LexerOptions? {
  let lexer_opts : LexerOptions? = match context {
    Context::TriGRecognizerContext(ctx) => Some(ctx.lexer_options)
    _ => None
  }
  lexer_opts
}

///|
pub fn TriGRecognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  with_graph_name : Bool,
  lenient : Bool,
  base_iri : Iri?,
  prefixes : Map[String, Iri],
) -> Parser[NxLexer, TriGRecognizer] {
  Parser::Parser(
    Lexer::Lexer(
      NxLexer::NxLexer(NxLexerMode::Turtle, lenient),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
    ),
    {
      stack: [TriGState::TriGDoc],
      cur_subject: [],
      cur_predicate: [],
      cur_object: [],
      cur_graph: GraphName::DefaultGraph.as_ref(),
      cur_reifier: [],
      lenient,
    },
    Context::TriGRecognizerContext({
      with_graph_name,
      prefixes,
      lexer_options: { base_iri, },
    }),
  )
}

///|
fn TriGRecognizer::error(
  self : TriGRecognizer,
  errors : Array[RuleRecognizerError],
  msg : String,
) -> TriGRecognizer {
  errors.push(RuleRecognizerError::SyntaxError(msg, TextPosition::default()))
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_graph = GraphName::DefaultGraph.as_ref()
  self
}

///|

///|
fn TriGRecognizer::emit_quad(
  self : TriGRecognizer,
  results : Array[LexOutput],
) -> Unit {
  let subject = match self.cur_subject.last() {
    Some(s) => s
    None => return // 或者报错，例如: abort("Internal error: subject stack empty in emit_quad")
  }
  let predicate = match self.cur_predicate.last() {
    Some(p) => p
    None => return
  }
  let object = match self.cur_object.last() {
    Some(o) => o
    None => return
  }

  results.push(
    LexOutput::Quad(
      Quad::Quad(
        subject.into_owned(),
        predicate.into_owned(),
        object.into_owned(),
        self.cur_graph.into_owned(),
      ),
    ),
  )
}

///|
enum TriGState {
  TriGDoc
  ExpectDot
  BaseExpectIri
  PrefixExpectPrefix
  PrefixExpectIri(name~ : String)
  VersionExpectVersion
  TriplesOrGraph
  WrappedGraphBlankNodePropertyListCurrent
  SubjectBlankNodePropertyListEnd
  SubjectBlankNodePropertyListAfter
  SubjectCollectionBeginning
  SubjectCollectionPossibleEnd
  WrappedGraphOrPredicateObjectList(term~ : NamedOrBlankNodeRef)
  WrappedGraph
  WrappedGraphPossibleEnd
  GraphName
  GraphNameAnonEnd
  Triples
  TriplesBlankNodePropertyListCurrent
  MaybePredicateObjectList
  PredicateObjectList
  PredicateObjectListEnd
  PredicateObjectListPossibleContinuation
  ObjectsList
  AnnotationBlock(with_reifier~ : Bool)
  AnnotationEnd(with_reifier~ : Bool)
  Verb
  Object
  ObjectBlankNodePropertyListCurrent
  ObjectBlankNodePropertyListEnd
  ObjectCollectionBeginning
  ObjectCollectionPossibleEnd
  LiteralPossibleSuffix(value~ : String, emit~ : Bool)
  LiteralExpectDatatype(value~ : String, emit~ : Bool)
  SubjectReifiedTripleEnd
  ObjectReifiedTripleEnd(emit~ : Bool)
  TripleTermEnd(emit~ : Bool)
  EndOfReifiedTripleBeforeReifier
  Reifier(triple~ : Triple)
  ReifiedTripleSubject(is_reified~ : Bool)
  ReifiedTripleObject(is_reified~ : Bool)
  QuotedAnonEnd
} derive(Debug)
