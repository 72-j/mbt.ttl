///|
pub struct NQuadsRecognizer {
  stack : Array[NQuadsState]
  subjects : Array[NamedOrBlankNodeRef]
  predicates : Array[NamedNodeRef]
  objects : Array[TermRef]
  lenient : Bool
  mut debug_logger : &DebugLogger
}

///|
pub struct NQuadsRecognizerContext {
  with_graph_name : Bool
  lexer_options : LexerOptions?
}

///|
enum NQuadsState {
  ExpectSubject
  ExpectPredicate
  ExpectedObject
  ExpectPossibleGraphOrEndOfQuotedTriple
  ExpectDot
  ExpectLiteralAnnotationOrGraphNameOrDot(value~ : String)
  ExpectLiteralDatatype(value~ : String)
  ExpectLineJump
  RecoverToLineJump
  AfterQuotedTriple
}

///|
impl Show for NQuadsState with fn output(self, logger : &Logger) -> Unit {
  match self {
    NQuadsState::ExpectSubject => logger.write("Expecting subject")
    NQuadsState::ExpectPredicate => logger.write("Expecting predicate")
    NQuadsState::ExpectedObject => logger.write("Expecting object")
    NQuadsState::ExpectDot => logger.write("Expecting dot")
    NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~) =>
      logger.write("Expecting literal annotation \{value} ")
    NQuadsState::ExpectLiteralDatatype(value~) =>
      logger.write("Expecting literal datatype \{value}")
    NQuadsState::ExpectLineJump => logger.write("Expecting line jump")
    NQuadsState::RecoverToLineJump => logger.write("Recovering to line jump")
    NQuadsState::AfterQuotedTriple => logger.write("After quoted triple")
    NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple =>
      logger.write("Expecting possible graph or end of quoted triple")
  }
}

///|
impl RuleRecognizer for NQuadsRecognizer with fn error_recovery_state(
  self : NQuadsRecognizer,
) -> NQuadsRecognizer {
  self.stack.clear()
  self.stack.push(NQuadsState::RecoverToLineJump)
  self.subjects.clear()
  self.predicates.clear()
  self.objects.clear()
  self
}

///|
impl RuleRecognizer for NQuadsRecognizer with fn[DL : DebugLogger] debug_logger(
  self : NQuadsRecognizer,
  debug_logger : DL,
) {
  self.debug_logger = debug_logger
}

///|
impl RuleRecognizer for NQuadsRecognizer with fn recognize_next(
  self : NQuadsRecognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> NQuadsRecognizer {
  let ctx = match context {
    RdfContext::NQuadsRecognizerContext(c) => c
    _ => abort("Invalid context type")
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
            errors,
            token,
            RuleRecognizerError::BlankNodeOrIriError,
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
            errors,
            token,
            RuleRecognizerError::PredicateNotAnIRI,
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
            errors,
            token,
            RuleRecognizerError::BlankNodeOrIriError,
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
            errors,
            token,
            RuleRecognizerError::LiteralDatatypeError,
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
            ctx,
            results,
            errors,
            token,
            RuleRecognizerError::SyntaxError(
              "Expecting the end of a quoted triple ')>>'",
              Range::default(),
            ),
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

///|
impl RuleRecognizer for NQuadsRecognizer with fn recognize_end(
  self : NQuadsRecognizer,
  _context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> Unit {
  match self.stack {
    [NQuadsState::ExpectSubject | NQuadsState::ExpectLineJump] | [] => ()
    [NQuadsState::ExpectDot] =>
      errors.push(RuleRecognizerError::TripleMissingDot)
    [NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple] => {
      self.emit_quad(results, errors, GraphName::DefaultGraph.as_ref())
      errors.push(RuleRecognizerError::TripleMissingDot)
    }
    [NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~)] => {
      let literal = LiteralRef::new_simple_literal(value)
      self.objects.push(TermRef::LiteralRef(literal))
      self.emit_quad(results, errors, GraphName::DefaultGraph.as_ref())
      errors.push(RuleRecognizerError::TripleMissingDot)
    }
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          Range::default(),
        ),
      )
  }
}

///|
impl RuleRecognizer for NQuadsRecognizer with fn lexer_options(
  context : RdfContext,
) -> LexerOptions? {
  match context {
    RdfContext::NQuadsRecognizerContext(ctx) => ctx.lexer_options
    _ => None // 或者 panic!("Unexpected context type")
  }
}

///|
pub fn NQuadsRecognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  with_graph_name : Bool,
  lenient : Bool,
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> Parser[RdfLexer, NQuadsRecognizer] {
  let initial_context = NQuadsRecognizerContext::{
    with_graph_name,
    lexer_options: None,
  }

  Parser::Parser(
    Lexer::Lexer(
      RdfLexer::RdfLexer(RdfLexerMode::NTriples, lenient),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    ),
    {
      stack: [NQuadsState::ExpectSubject],
      subjects: [],
      predicates: [],
      objects: [],
      lenient,
      debug_logger, // 修复：包装为 Option 类型
    },
    RdfContext::NQuadsRecognizerContext(initial_context),
  )
}

///|
fn NQuadsRecognizer::error(
  self : NQuadsRecognizer,
  context : NQuadsRecognizerContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
  token : LocatedTokenOrLineJump,
  msg : RuleRecognizerError,
) -> NQuadsRecognizer {

  errors.push(msg)
  let this = self.error_recovery_state()
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(_) => this
    LocatedTokenOrLineJump::LineJump(_) =>
      this.recognize_next(
        token,
        RdfContext::NQuadsRecognizerContext(context),
        results,
        errors,
      )
    LocatedTokenOrLineJump::End => this
  }
}

///|
fn NQuadsRecognizer::emit_quad(
  self : NQuadsRecognizer,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
  graph_name : GraphNameRef,
) -> Unit {
  let subject_opt = self.subjects.pop()
  let predicate_opt = self.predicates.pop()
  let object_opt = self.objects.pop()

  match (subject_opt, predicate_opt, object_opt) {
    (Some(subject), Some(predicate), Some(object)) =>
      results.push(
        RdfStatement::Quad({
          subject: subject.into_owned(),
          predicate: predicate.into_owned(),
          object: object.into_owned(),
          graph_name: graph_name.into_owned(),
        }),
      )
    _ =>
      // 栈中元素不足，记录内部错误
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Internal error: incomplete quad on stack during emission",
          Range::default(),
        ),
      )
    // 可以选择在此处调用 self.error_recovery_state()，但这会改变 self
    // 通常 emit_quad 不应改变 self 的状态除了 pop，所以仅记录错误
  }
}
