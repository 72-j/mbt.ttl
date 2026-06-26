// ... (之前的函数)

// 8. 图内三元组解析
// 对应状态: TriGState::Triples
///|
fn handle_triples(
  self : TriGRecognizer,
  token : LocatedTokenOrLineJump,
  context : TriGRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
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
        NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
      )
      self.stack.push(TriGState::PredicateObjectList)
      self
    }
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      self.cur_subject.push(NamedNodeRef::new_unchecked(iri).as_enum())
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
        NamedOrBlankNodeRef::BlankNodeRef(BlankNodeRef::new_unchecked(label)),
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
      self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
      self.stack.push(TriGState::Verb)
      self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
      self
    }
    _ => self.error(errors, "TOKEN is not a valid RDF subject")
  }
}

// 9. 注解块处理
// 对应状态: TriGState::AnnotationBlock

///|
fn handle_annotation_block(
  self : TriGRecognizer,
  with_reifier : Bool,
  token : LocatedTokenOrLineJump,
  context : TriGRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
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

// 10. 字面量后缀处理
// 对应状态: TriGState::LiteralPossibleSuffix

///|
fn handle_literal_possible_suffix(
  self : TriGRecognizer,
  value : String,
  emit : Bool,
  token : LocatedTokenOrLineJump,
  context : TriGRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
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
      self.cur_object.push(LiteralRef::new_simple_literal(value).as_term())
      if emit {
        self.emit_quad(results)
        self.stack.push(TriGState::PredicateObjectListEnd)
      }
      self
    }
  }
}

// 11. 引用三元组对象结束
// 对应状态: TriGState::ObjectReifiedTripleEnd

///|
fn handle_object_reified_triple_end(
  self : TriGRecognizer,
  emit : Bool,
  token : LocatedTokenOrLineJump,
  context : TriGRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
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

// 12. 空节点属性列表结束 (对象)
// 对应状态: TriGState::ObjectBlankNodePropertyListEnd

///|
fn handle_object_blank_node_property_list_end(
  self : TriGRecognizer,
  token : LocatedTokenOrLineJump,
  context : TriGRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
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

// 13. 谓词列表可能继续
// 对应状态: TriGState::PredicateObjectListPossibleContinuation

///|
fn handle_predicate_object_list_possible_continuation(
  self : TriGRecognizer,
  token : LocatedTokenOrLineJump,
  context : TriGRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
  self.debug_logger.info(
    "Entering PredicateObjectListPossibleContinuation with token: \{token}",
  )
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match token {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(";"), _)
    ) => {
      self.stack.push(TriGState::PredicateObjectListPossibleContinuation)
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

// 14. 图结束处理
// 对应状态: TriGState::WrappedGraphPossibleEnd

///|
fn handle_wrapped_graph_possible_end(
  self : TriGRecognizer,
  token : LocatedTokenOrLineJump,
  context : TriGRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
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
