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
impl RuleRecognizer for NQuadsRecognizer with fn[DL: DebugLogger] debug_logger(
  self : NQuadsRecognizer,
  debug_logger : DL,
) {
  self.debug_logger = debug_logger
}

///|
impl RuleRecognizer for NQuadsRecognizer with fn recognize_next(
  self : NQuadsRecognizer,
  token : TokenOrLineJump[N3Token],
  context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> NQuadsRecognizer {
  // let RdfContext ::NQuadsRecognizerContext(context) = context
  //  let TokenOrLineJump::Token(token) = token
  let ctx = match context {
    RdfContext::NQuadsRecognizerContext(c) => c
    // _ => panic()
    _ => abort("Invalid context type")
  }
  match self.stack.pop().unwrap_or(NQuadsState::ExpectSubject) {
    NQuadsState::ExpectSubject =>
      // let TokenOrLineJump::Token(token) = token
      match token {
        TokenOrLineJump::Token(N3Token::Iri(s)) => {
          self.subjects.push(NamedNodeRef::new_unchecked(s).as_enum())
          self.stack.push(NQuadsState::ExpectPredicate)
          self
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(s)) => {
          self.subjects.push(BlankNodeRef::new_unchecked(s).as_enum())
          self.stack.push(NQuadsState::ExpectPredicate)
          self
        }
        // _ => self.error(context, results, errors, TokenOrLineJump::Token(token), "The subject of a triple must be an IRI or a blank node")
        _ =>
          self.error(
            ctx,
            results,
            errors,
            token,
            RuleRecognizerError::BlankNodeOrIriError,
          )
      }
    NQuadsState::ExpectPredicate =>
      // let TokenOrLineJump::Token(token) = token
      match token {
        TokenOrLineJump::Token(N3Token::Iri(p)) => {
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
    NQuadsState::ExpectedObject =>
      // let TokenOrLineJump::Token(token) = token
      match token {
        TokenOrLineJump::Token(N3Token::Iri(o)) => {
          self.objects.push(
            TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(o)),
          )
          self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
          self
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(o)) => {
          self.objects.push(NamedNodeRef::new_unchecked(o).as_term())
          self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
          self
        }
        TokenOrLineJump::Token(N3Token::String(value)) => {
          self.stack.push(
            NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~),
          )
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("<<(")) => {
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
    NQuadsState::ExpectLiteralAnnotationOrGraphNameOrDot(value~) =>
      match token {
        TokenOrLineJump::Token(N3Token::LangTag(language~, direction~)) if direction
          is Some(_) => {
          let dir = match direction {
            Some(d) => d // 假设有此类方法
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
              // 处理错误，例如推入错误信息并进入恢复状态
              errors.push(RuleRecognizerError::InvalidLanguageTag) // 需确保此错误类型存在
              self.error_recovery_state()
            }
          }
        }
        TokenOrLineJump::Token(N3Token::LangTag(language~, direction~)) if direction
          is None => {
          // self.objects.push(Literal::new_language_tagged_literal_unchecked(value, try? LanguageTag::from_str(language.to_lower())))
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
              // 处理错误，例如推入错误信息并进入恢复状态
              errors.push(RuleRecognizerError::InvalidLanguageTag) // 需确保此错误类型存在
              self.error_recovery_state()
            }
          }
        }
        TokenOrLineJump::Token(N3Token::Punctuation("^^")) => {
          self.stack.push(NQuadsState::ExpectLiteralDatatype(value~))
          self
        }
        _ => {
          self.objects.push(
            TermRef::LiteralRef(LiteralRef::new_simple_literal(value)),
          )
          self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
          self
          // self.recognize_next(
          //   token,
          //   NQuadsRecognizerContext(ctx),
          //   results,
          //   errors,
          // )
        }
      }
    NQuadsState::ExpectLiteralDatatype(value~) =>
      // let TokenOrLineJump::Token(token) = token
      match token {
        TokenOrLineJump::Token(N3Token::Iri(d)) => {
          if !self.lenient && d == lwLANG_STRING.to_string() {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "The datatype of a literal without a language tag must not be rdf:langString",
                SourcePosition::default(),
              ),
            )
          }
          if !self.lenient && d == lwDIR_LANG_STRING.to_string() {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "The datatype of a literal without a base direction must not be rdf:dirLangString",
                SourcePosition::default(),
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
    NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple =>
      if self.stack.is_empty() {
        match token {
          TokenOrLineJump::Token(N3Token::Iri(g)) if ctx.with_graph_name => {
            self.emit_quad(results, errors, GraphNameRef::new_unchecked(g))
            self.stack.push(NQuadsState::ExpectDot)
            self
          }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(_g)) if ctx.with_graph_name => {
            self.emit_quad(results, errors, GraphNameRef::DefaultGraph)
            self.stack.push(NQuadsState::ExpectDot)
            self
          }
          _ => {
            self.emit_quad(results, errors, GraphName::DefaultGraph.as_ref())
            self.stack.push(NQuadsState::ExpectDot)
            self.recognize_next(
              token,
              RdfContext::NQuadsRecognizerContext(ctx),
              results,
              errors,
            )
          }
        }
      } else if token == TokenOrLineJump::Token(N3Token::Punctuation(")>>")) {
        self
      } else {
        self.error(
          ctx,
          results,
          errors,
          token,
          RuleRecognizerError::SyntaxError(
            "Expecting the end of a quoted triple ')>>'",
            SourcePosition::default(),
          ),
        )
      }
    NQuadsState::ExpectDot =>
      // let TokenOrLineJump::Token(token) = token
      if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) {
        self.stack.push(NQuadsState::ExpectLineJump)
        self
      } else {
        errors.push(
          RuleRecognizerError::SyntaxError(
            "Quads must be followed by a dot",
            SourcePosition::default(),
          ),
        )
        self
        // self.recognize_next(
        //   token,
        //   RdfContext ::NQuadsRecognizerContext(ctx),
        //   results,
        //   errors,
        // )
      }
    NQuadsState::ExpectLineJump => {
      // let TokenOrLineJump::Token(token) = token
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Only a single triple or quad can be written in a line, found \{token.to_string()}",
          SourcePosition::default(),
        ),
      )
      self
      // self.recognize_next(
      //   token,
      //   RdfContext ::NQuadsRecognizerContext(ctx),
      //   results,
      //   errors,
      // )
    }
    NQuadsState::AfterQuotedTriple => {
      // 安全地弹出三元组的组成部分
      let subject_opt = self.subjects.pop()
      let predicate_opt = self.predicates.pop()
      let object_opt = self.objects.pop()

      match (subject_opt, predicate_opt, object_opt) {
        (Some(subject), Some(predicate), Some(object)) => {
          let triple : TripleRef = { subject, predicate, object }
          self.objects.push(TermRef::TripleRef(triple))
          self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::NQuadsRecognizerContext(ctx),
          //   results,
          //   errors,
          // )
        }
        _ => {
          // 如果栈中元素不足，说明内部状态不一致，报告错误并恢复
          errors.push(
            RuleRecognizerError::SyntaxError(
              "Internal error: incomplete quoted triple on stack",
              SourcePosition::default(),
            ),
          )
          self.error_recovery_state()
        }
      }
    }
    // NQuadsState::AfterQuotedTriple => {
    //   let triple : TripleRef = {
    //     subject: self.subjects.pop().unwrap(),
    //     predicate: self.predicates.pop().unwrap(),
    //     object: self.objects.pop().unwrap(),
    //   }
    //   self.objects.push(TermRef::TripleRef(triple))
    //   self.stack.push(NQuadsState::ExpectPossibleGraphOrEndOfQuotedTriple)
    //   self.recognize_next(
    //     token,
    //     RdfContext ::NQuadsRecognizerContext(ctx),
    //     results,
    //     errors,
    //   )
    // }
    NQuadsState::RecoverToLineJump => {
      if token != TokenOrLineJump::LineJump {
        self.stack.push(NQuadsState::RecoverToLineJump)
      }
      self
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
          SourcePosition::default(),
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
      0

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
  token : TokenOrLineJump[N3Token],
  msg : RuleRecognizerError,
) -> NQuadsRecognizer {
  errors.push(msg)
  let this = self.error_recovery_state()
  match token {
    TokenOrLineJump::Token(_) => this
    TokenOrLineJump::LineJump =>
      this.recognize_next(
        token,
        RdfContext::NQuadsRecognizerContext(context),
        results,
        errors,
      )
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
          SourcePosition::default(),
        ),
      )
    // 可以选择在此处调用 self.error_recovery_state()，但这会改变 self
    // 通常 emit_quad 不应改变 self 的状态除了 pop，所以仅记录错误
  }
}
