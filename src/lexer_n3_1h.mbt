// --- 以下为各个状态的具体实现示例 ---

///|
fn N3Recognizer::handle_term_token(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(located) =>
      match located {
        LocatedN3Token(N3Token::Iri(iri), _) => {
          self.terms.push(NamedNodeRef::new_unchecked(iri).as_n3term())
          self
        }
        LocatedN3Token(
          N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
          _
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
                Err(e) => self.error(e)
              }
            _ => self.error("Invalid context for N3Term")
          }
        LocatedN3Token(N3Token::BlankNodeLabel(bnode), _) => {
          self.terms.push(BlankNodeRef::new_unchecked(bnode).as_n3term())
          self
        }
        LocatedN3Token(N3Token::Variable(name), _) => {
          self.terms.push(N3Term::Variable(name))
          self
        }
        LocatedN3Token(N3Token::String(value), _)
        | LocatedN3Token(N3Token::LongString(value), _) => {
          self.stack.push(N3State::LiteralPossibleSuffix(value~))
          self
        }
        LocatedN3Token(N3Token::Integer(v), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(VarDataType::IntegerVar(v), lwINTEGER).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::Decimal(v), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(VarDataType::IntegerVar(v), lwDECIMAL).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::Double(v), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(VarDataType::IntegerVar(v), lwDOUBLE).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::PlainKeyword("true"), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(
              VarDataType::IntegerVar("true"),
              lwBOOLEAN,
            ).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::PlainKeyword("false"), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(
              VarDataType::IntegerVar("false"),
              lwBOOLEAN,
            ).as_n3term(),
          )
          self
        }
        _ => self.error("TOKEN is not a valid RDF value")
      }
    _ => self.error("TOKEN is not a valid RDF value")
  }
}

// 辅助函数：统一处理公式结束逻辑

///|
fn N3Recognizer::finish_formula(
  self : N3Recognizer,
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
  let ctx = match self.contexts.pop() {
    Some(c) => c
    None => {
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Internal error: contexts stack empty in finish_formula",
          Range::default(),
        ),
      )
      return self
    }
  }

  // 将公式对应的 BlankNode 作为 Term 压入
  self.terms.push(ctx.as_n3term())

  // 关键修复：清理状态栈
  // 1. 弹出 PathFollowUp (如果存在)
  if self.stack.last() == Some(N3State::PathFollowUp) {
    let _ = self.stack.pop()
  }

  // 2. 弹出 FormulaContentExpectDot (如果存在，防止残留)
  if self.stack.last() == Some(N3State::FormulaContentExpectDot) {
    let _ = self.stack.pop()
  }

  // 3. 重要：公式结束后，我们实际上完成了一个 PathItem。
  // 如果栈顶现在是 TriplesMiddle 或 ObjectsListEnd 等，它们应该能处理后续 token。
  // 但如果栈顶是 PathFollowUp 的上一层（例如 Path），我们需要确保不会再次进入 PathFollowUp 的错误逻辑。

  // 调试建议：打印此时的栈状态
  // self.debug_logger.info("Stack after finish_formula: \{self.stack.to_string()}")

  self
}

///|
fn N3Recognizer::handle_n3_doc(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering N3Doc with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  self.stack.push(N3State::N3Doc)
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "base") => {
      self.stack.push(N3State::BaseExpectIri)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "prefix") => {
      self.stack.push(N3State::PrefixExpectPrefix)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language="prefix", direction=None), _)
    ) => {
      self.stack.push(N3State::N3DocExpectDot)
      self.stack.push(N3State::PrefixExpectPrefix)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language="base", direction=None), _)
    ) => {
      self.stack.push(N3State::N3DocExpectDot)
      self.stack.push(N3State::BaseExpectIri)
      HandleResult::Stop(self)
    }
    _ => {
      self.stack.push(N3State::N3DocExpectDot)
      self.stack.push(N3State::Triples)
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_n3_doc_expect_dot(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering N3DocExpectDot with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => HandleResult::Stop(self)
    _ => {
      errors.push(
        RuleRecognizerError::SyntaxError(
          "A dot is expected at the end of N3 statements",
          Range::default(),
        ),
      )
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_base_expect_iri(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering BaseExpectIri with token: \{token}")
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
    HandleResult::Stop(self)
  } else {
    HandleResult::Stop(
      self.error("The BASE keyword should be followed by an IRI"),
    )
  }
}

///|
fn N3Recognizer::handle_prefix_expect_prefix(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering PrefixExpectPrefix with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PrefixedName(prefix~, localx~, ..), _)
    ) if localx.is_empty() => {
      self.stack.push(N3State::PrefixExpectIri(name=prefix))
      HandleResult::Stop(self)
    }
    _ =>
      HandleResult::Stop(
        self.error(
          "The PREFIX keyword should be followed by a prefix like 'ex:'",
        ),
      )
  }
}

///|
fn N3Recognizer::handle_prefix_expect_iri(
  self : N3Recognizer,
  name : String,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info(
    "Entering PrefixExpectIri(\{name}) with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(iri), _)
    ) {
    match context {
      RdfContext::N3RecognizerContext(ctx) =>
        ctx.prefixes.set(name, Iri::Iri(iri))
      _ => ()
    }
    HandleResult::Stop(self)
  } else {
    HandleResult::Stop(
      self.error(
        "The PREFIX declaration should be followed by a prefix and its value as an IRI",
      ),
    )
  }
}

///|
fn N3Recognizer::handle_triples(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering Triples with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  self.stack.push(N3State::TriplesMiddle)
  self.stack.push(N3State::Path)
  HandleResult::Continue(self)
}

///|
fn N3Recognizer::handle_triples_middle(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering TriplesMiddle with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("." | "]" | "}" | ")"), _)
    ) {
    HandleResult::Continue(self)
  } else {
    self.stack.push(N3State::TriplesEnd)
    self.stack.push(N3State::PredicateObjectList)
    HandleResult::Continue(self)
  }
}

///|
fn N3Recognizer::handle_triples_end(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering TriplesEnd with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  let _ = self.terms.pop()
  HandleResult::Continue(self)
}

///|
fn N3Recognizer::handle_predicate_object_list(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering PredicateObjectList with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  self.stack.push(N3State::PredicateObjectListEnd)
  self.stack.push(N3State::ObjectsList)
  self.stack.push(N3State::Verb)
  HandleResult::Continue(self)
}

///|
fn N3Recognizer::handle_predicate_object_list_end(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering PredicateObjectListEnd with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  let _ = self.predicates.pop()

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(";"), _)
    ) => {
      self.stack.push(N3State::PredicateObjectListPossibleContinuation)
      HandleResult::Stop(self)
    }
    _ => HandleResult::Continue(self)
  }
}

///|
fn N3Recognizer::handle_predicate_object_list_possible_continuation(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info(
    "Entering PredicateObjectListPossibleContinuation with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(";"), _)
    ) => {
      self.stack.push(N3State::PredicateObjectListPossibleContinuation)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => HandleResult::Stop(self)
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => HandleResult::Stop(self)
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => HandleResult::Stop(self)
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) => HandleResult::Stop(self)
    _ => {
      self.stack.push(N3State::PredicateObjectListEnd)
      self.stack.push(N3State::ObjectsList)
      self.stack.push(N3State::Verb)
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_objects_list(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering ObjectsList with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  self.stack.push(N3State::ObjectsListEnd)
  self.stack.push(N3State::Path)
  HandleResult::Continue(self)
}

///|
fn N3Recognizer::handle_objects_list_end(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering ObjectsListEnd with token: \{token}")
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
      return HandleResult::Stop(self)
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
      return HandleResult::Stop(self)
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
      return HandleResult::Stop(self)
    }
  }
  results.push(
    match predicate_opt {
      Predicate::Regular(predicate) =>
        RdfOut::N3Quad(self.quad(subject, predicate, object))
      Predicate::Inverted(predicate) =>
        RdfOut::N3Quad(self.quad(object, predicate, subject))
    },
  )

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(","), _)
    ) => {
      self.stack.push(N3State::ObjectsListEnd)
      self.stack.push(N3State::Path)
      HandleResult::Stop(self)
    }
    _ => HandleResult::Continue(self)
  }
}

///|
fn N3Recognizer::handle_verb(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering Verb with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("a"), _)
    ) => {
      self.predicates.push(Predicate::Regular(lwTYPE.as_n3term()))
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("has"), _)
    ) => {
      self.stack.push(N3State::AfterRegularVerb)
      self.stack.push(N3State::Path)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("is"), _)
    ) => {
      self.stack.push(N3State::AfterVerbIs)
      self.stack.push(N3State::Path)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("="), _)
    ) => {
      self.predicates.push(
        Predicate::Regular(
          NamedNodeRef::new_unchecked("http://www.w3.org/2002/07/owl#sameAs").as_n3term(),
        ),
      )
      HandleResult::Stop(self)
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
      HandleResult::Stop(self)
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
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<-"), _)
    ) => {
      self.stack.push(N3State::AfterInvertedVerb)
      self.stack.push(N3State::Path)
      HandleResult::Stop(self)
    }
    _ => {
      self.stack.push(N3State::AfterRegularVerb)
      self.stack.push(N3State::Path)
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_after_regular_verb(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering AfterRegularVerb with token: \{token}")
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
      return HandleResult::Stop(self)
    }
  }
  self.predicates.push(Predicate::Regular(term))
  HandleResult::Stop(self)
}

///|
fn N3Recognizer::handle_after_inverted_verb(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering AfterInvertedVerb with token: \{token}")
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
      return HandleResult::Stop(self)
    }
  }
  self.predicates.push(Predicate::Inverted(term))
  HandleResult::Stop(self)
}

///|
fn N3Recognizer::handle_after_verb_is(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
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
          return HandleResult::Stop(self)
        }
      }
      self.predicates.push(Predicate::Inverted(term))
      HandleResult::Stop(self)
    }
    _ =>
      HandleResult::Stop(
        self.error(
          "The keyword 'is' should be followed by a predicate then by the keyword 'of'",
        ),
      )
  }
}

///|
fn N3Recognizer::handle_path(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering Path with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  self.stack.push(N3State::PathFollowUp)
  self.stack.push(N3State::PathItem)
  HandleResult::Continue(self)
}

///|
fn N3Recognizer::handle_path_follow_up(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering PathFollowUp with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("!"), _)
    ) => {
      self.stack.push(N3State::PathAfterIndicator(is_inverse=false))
      self.stack.push(N3State::PathItem)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("^"), _)
    ) => {
      self.stack.push(N3State::PathAfterIndicator(is_inverse=false))
      self.stack.push(N3State::PathItem)
      HandleResult::Stop(self)
    }
    _ => HandleResult::Continue(self)
  }
}

///|
fn N3Recognizer::handle_path_after_indicator(
  self : N3Recognizer,
  is_inverse : Bool,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
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
      return HandleResult::Stop(self)
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
      return HandleResult::Stop(self)
    }
  }
  let current = BlankNode::default().as_n3term()
  results.push(
    if is_inverse {
      RdfOut::N3Quad(self.quad(current, predicate, previous))
    } else {
      RdfOut::N3Quad(self.quad(previous, predicate, current))
    },
  )
  self.terms.push(current)
  self.stack.push(N3State::PathFollowUp)
  HandleResult::Continue(self)
}

///|
fn N3Recognizer::handle_path_item(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering PathItem with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => {
      self.stack.push(N3State::PropertyListMiddle)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("("), _)
    ) => {
      self.stack.push(N3State::CollectionBeginning)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("{"), _)
    ) => {
      self.contexts.push(BlankNode::default())
      self.stack.push(N3State::FormulaContent)
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      if self.contexts.is_empty() {
        return HandleResult::Stop(
          self.error("Unexpected '}' outside of formula"),
        )
      }
      let ctx = self.contexts.pop().unwrap()
      self.terms.push(ctx.as_n3term())
      if self.stack.last() == Some(N3State::PathFollowUp) {
        let _ = self.stack.pop()
      }
      HandleResult::Stop(self)
    }
    _ =>
      // 使用之前重构的 handle_term_token
      HandleResult::Stop(self.handle_term_token(token, context, errors))
  }
}

///|
fn N3Recognizer::handle_property_list_middle(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering PropertyListMiddle with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => {
      self.terms.push(BlankNode::default().as_n3term())
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("id"), _)
    ) => {
      self.stack.push(N3State::IriPropertyList)
      HandleResult::Stop(self)
    }
    _ => {
      self.terms.push(BlankNode::default().as_n3term())
      self.stack.push(N3State::PropertyListEnd)
      self.stack.push(N3State::PredicateObjectList)
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_property_list_end(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering PropertyListEnd with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => HandleResult::Stop(self)
    _ => {
      errors.push(
        RuleRecognizerError::SyntaxError(
          "blank node property lists should end with a ']'",
          Range::default(),
        ),
      )
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_iri_property_list(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering IriPropertyList with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(id), _)) => {
      self.terms.push(NamedNodeRef::new_unchecked(id).as_n3term())
      self.stack.push(N3State::PropertyListEnd)
      self.stack.push(N3State::PredicateObjectList)
      HandleResult::Stop(self)
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
              HandleResult::Stop(self)
            }
            Err(e) => HandleResult::Stop(self.error(e.to_string()))
          }
        _ =>
          HandleResult::Stop(
            self.error("Invalid context for prefix resolution"),
          )
      }
    _ =>
      HandleResult::Stop(
        self.error("The '[ id' construction should be followed by an IRI"),
      )
  }
}

///|
fn N3Recognizer::handle_collection_beginning(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering CollectionBeginning with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) {
    self.terms.push(lwNIL.as_n3term())
    HandleResult::Stop(self)
  } else {
    let root = BlankNode::default()
    self.terms.push(root.as_n3term())
    self.terms.push(root.as_n3term())
    self.stack.push(N3State::CollectionPossibleEnd)
    self.stack.push(N3State::Path)
    HandleResult::Continue(self)
  }
}

///|
fn N3Recognizer::handle_collection_possible_end(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering CollectionPossibleEnd with token: \{token}")
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
      return HandleResult::Stop(self)
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
      return HandleResult::Stop(self)
    }
  }
  results.push(RdfOut::N3Quad(self.quad(old, lwFIRST.as_n3term(), value)))
  if token
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) {
    results.push(
      RdfOut::N3Quad(self.quad(old, lwREST.as_n3term(), lwNIL.as_n3term())),
    )
    HandleResult::Stop(self)
  } else {
    let new = BlankNode::default()
    results.push(
      RdfOut::N3Quad(self.quad(old, lwREST.as_n3term(), new.as_n3term())),
    )
    self.terms.push(new.as_n3term())
    self.stack.push(N3State::CollectionPossibleEnd)
    self.stack.push(N3State::Path)
    HandleResult::Continue(self)
  }
}

///|
fn N3Recognizer::handle_literal_possible_suffix(
  self : N3Recognizer,
  value : String,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info(
    "Entering LiteralPossibleSuffix(\{value}) with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language~, direction~), _)
    ) => {
      if direction is Some(_) {
        return HandleResult::Stop(
          self.error("rdf:dirLangString is not supported in N3"),
        )
      }
      self.terms.push(
        Literal::new_language_tagged_literal_unchecked(
          value,
          language.to_lower(),
        ).as_n3term(),
      )
      HandleResult::Stop(self)
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("^^"), _)
    ) => {
      self.stack.push(N3State::LiteralExpectDatatype(value~))
      HandleResult::Stop(self)
    }
    _ => {
      self.terms.push(Literal::new_simple_literal(value).as_n3term())
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_literal_expect_datatype(
  self : N3Recognizer,
  value : String,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
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
        LiteralRef::new_typed_literal(datatype.into_datatype(value), datatype).as_n3term(),
      )
      HandleResult::Stop(self)
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
              HandleResult::Stop(self)
            }
            Err(e) => HandleResult::Stop(self.error(e))
          }
        _ =>
          HandleResult::Stop(
            self.error("Invalid context for prefix resolution"),
          )
      }
    _ => HandleResult::Stop(self.error("Unexpected token in formula content"))
  }
}

///|
fn N3Recognizer::handle_formula_content(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info("Entering FormulaContent with token: \{token}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => HandleResult::Stop(self.finish_formula(errors))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "base") => {
      self.stack.push(N3State::FormulaContent)
      self.stack.push(N3State::BaseExpectIri)
      HandleResult::Stop(self)
    }
    _ => {
      self.stack.push(N3State::FormulaContentExpectDot)
      self.stack.push(N3State::Triples)
      HandleResult::Continue(self)
    }
  }
}

///|
fn N3Recognizer::handle_formula_content_expect_dot(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfOut],
  errors : Array[RuleRecognizerError],
) -> HandleResult {
  self.debug_logger.info(
    "Entering FormulaContentExpectDot with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => HandleResult::Stop(self.finish_formula(errors))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      self.stack.push(N3State::FormulaContent)
      HandleResult::Stop(self)
    }
    _ => {
      errors.push(
        RuleRecognizerError::SyntaxError(
          "A dot or '}' is expected at the end of N3 statements inside formula",
          Range::default(),
        ),
      )
      self.stack.push(N3State::FormulaContent)
      HandleResult::Continue(self)
    }
  }
}
