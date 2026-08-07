///|
pub fn NQuadsState::to_str(self : NQuadsState) -> String {
  Show::to_string(self)
}

///|
pub impl GenMachine for NQuadsRecognizer with fn initial_state(
  _self : NQuadsRecognizer,
) -> RdfState {
  RdfState::NQuadsState(NQuadsState::ExpectSubject)
}

///|
pub impl GenMachine for NQuadsRecognizer with fn error_recovery_statemachine(
  self,
) -> NQuadsRecognizer {
  self.error_recovery_state()
}

///|
pub impl GenMachine for NQuadsRecognizer with fn current_state(self) -> RdfState {
  StateWrapper::as_state_enum(self.current_state)
}

///|
pub impl GenMachine for NQuadsRecognizer with fn reset(self) -> NQuadsRecognizer {
  self.error_recovery_state()
}

///|
pub impl GenMachine for NQuadsRecognizer with fn transition(
  self : NQuadsRecognizer,
  state : RdfState,
  event : Event,
  _context : Ctx,
) -> TransitionResult[NQuadsRecognizer, RdfState, DataAction] {
  let nquads_state = match state {
    RdfState::NQuadsState(s) => s
  }

  let token = event
  self.debug_logger.info("NQuads State: \{nquads_state}, Event: \{token}")
  let token_name = match token.0 {
    N3Token::Punctuation(p) => "Punctuation('\{p}')"
    N3Token::PlainKeyword(k) => "PlainKeyword('\{k}')"
    N3Token::Iri(i) => "Iri('\{i}')"
    N3Token::LongString(s) => "LongString('\{s}')"
    _ => "Other"
  }
  self.debug_logger.info("[DEBUG] ExpectDotOrGraphName token: \{token_name}")

  let (next_state, action) = match (nquads_state, token) {
    // ── Start / ExpectSubject ─────────────────────────────────
    (Start, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[Start] IRI: \{iri}")
      let node = NamedNodeRef::new_unchecked(iri).as_enum()
      (NQuadsState::ExpectPredicate, DataAction::AddSubject(node))
    }
    (Start, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[Start] Blank: _:\{l}")
      let node = BlankNodeRef::new_unchecked(l).as_enum()
      (NQuadsState::ExpectPredicate, DataAction::AddSubject(node))
    }
    (Start, LocatedToken(N3Token::LineJump | N3Token::End, _)) => {
      self.debug_logger.info("[Start] LineJump/End")
      (Start, DataAction::NoOp)
    }

    // ── ExpectSubject ─────────────────────────────────────────
    (ExpectSubject, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectSubject] IRI: \{iri}")
      let node = NamedNodeRef::new_unchecked(iri).as_enum()
      (NQuadsState::ExpectPredicate, DataAction::AddSubject(node))
    }
    (ExpectSubject, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[ExpectSubject] Blank: \{l}")
      let node = BlankNodeRef::new_unchecked(l).as_enum()
      (NQuadsState::ExpectPredicate, DataAction::AddSubject(node))
    }
    (ExpectSubject, LocatedToken(N3Token::LineJump | N3Token::End, _)) =>
      (ExpectSubject, DataAction::NoOp)

    // ── ExpectPredicate ────────────────────────────────────────
    (ExpectPredicate, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectPredicate] IRI: \{iri}")
      let pred = NamedNodeRef::new_unchecked(iri)
      (ExpectObject, DataAction::AddPredicate(pred))
    }

    // ── ExpectObject ───────────────────────────────────────────
    (ExpectObject, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectObject] IRI: \{iri}")
      let obj = TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))
      (ExpectDotOrGraphName, DataAction::AddObject(obj))
    }
    (ExpectObject, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[ExpectObject] Blank: \{l}")
      let obj = BlankNodeRef::new_unchecked(l).as_term()
      (ExpectDotOrGraphName, DataAction::AddObject(obj))
    }
    (ExpectObject, LocatedToken(N3Token::String(v), _)) => {
      self.debug_logger.info("[ExpectObject] STRING: '\{v}'")
      (ExpectLiteralSuffix, DataAction::SetTempLiteral(v))
    }
    // ★ 添加 LongString 处理
    (ExpectObject, LocatedToken(N3Token::LongString(v), _)) => {
      self.debug_logger.info("[ExpectObject] LONGSTRING: '\{v}'")
      (ExpectLiteralSuffix, DataAction::SetTempLiteral(v))
    }
    (ExpectObject, LocatedToken(N3Token::PlainKeyword(k), range)) if k.length() >
      0 &&
      k[0] == '"' => {
      self.debug_logger.error("Invalid token: \{k}")
      return Err(RuleRecognizerError::SyntaxError("Expected string", range))
    }
    (ExpectObject, LocatedToken(N3Token::PlainKeyword(k), range)) => {
      let quote_count = {
        let mut count = 0
        for c in k {
          if c == '"' {
            count += 1
          }
        }
        count
      }
      if quote_count % 2 != 0 {
        self.debug_logger.error("Unmatched quote: \{k}")
        return Err(RuleRecognizerError::SyntaxError("Unmatched quote", range))
      }
      return Err(RuleRecognizerError::SyntaxError("Unexpected string", range))
    }

    // ── ExpectLiteralSuffix ────────────────────────────────────
    (
      ExpectLiteralSuffix,
      // | LocatedToken(N3Token::PlainKeyword("."), _),
      LocatedToken(N3Token::Punctuation("."), _),
    ) => {
      self.debug_logger.info("[ExpectLiteralSuffix] DOT, finalize=Simple")
      (ExpectLineJump, DataAction::EmitQuadWithLiteral(LiteralKind::Simple))
    }
    (
      ExpectLiteralSuffix,
      LocatedToken(N3Token::LangTag(language~, direction~), _),
    ) => {
      let dir = direction.unwrap_or(BaseDirection::Ltr)
      let tag = match LanguageTag::parse(language) {
        Ok(tag) => tag
        Err(_) =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Invalid language tag",
              self.last_range,
            ),
          )
      }
      (
        ExpectDotOrGraphName,
        DataAction::EmitQuadWithLiteral(LiteralKind::Lang(tag, dir)),
      )
    }
    (ExpectLiteralSuffix, LocatedToken(N3Token::Punctuation("^^"), _)) =>
      (ExpectDatatype, DataAction::NoOp)
    (ExpectDatatype, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectDatatype] IRI: \{iri}")
      let datatype_node = NamedNodeRef::new_unchecked(iri)
      (ExpectDotOrGraphName, DataAction::EmitQuadWithTempLiteral(datatype_node))
    }

    // ── ExpectDotOrGraphName ───────────────────────────────────

    (
      ExpectDotOrGraphName,
      LocatedToken(N3Token::Punctuation("."), _)
      | LocatedToken(N3Token::PlainKeyword("."), _),
    ) =>
      match self.temp_literal {
        Some(_) => (ExpectLiteralSuffix, DataAction::NoOp)
        None => (ExpectLineJump, DataAction::EmitQuad)
      }
    (ExpectDotOrGraphName, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectDotOrGraphName] GraphName IRI: \{iri}")
      let gn = GraphNameRef::new_unchecked(iri)
      (ExpectDot, DataAction::SetGraphName(gn))
    }
    (ExpectDotOrGraphName, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[ExpectDotOrGraphName] GraphName Blank: _:\{l}")
      let gn = GraphNameRef::new_unchecked(l)
      (ExpectDot, DataAction::SetGraphName(gn))
    }
    // 添加转换
    (ExpectDotOrGraphName, LocatedToken(N3Token::LineJump, _)) => {
      self.debug_logger.info("[ExpectDotOrGraphName] LineJump")
      (ExpectDotOrGraphName, DataAction::NoOp) // 跳过换行
    }

    // ── ExpectDot ──────────────────────────────────────────────
    (
      ExpectDot,
      LocatedToken(N3Token::Punctuation(".") | N3Token::PlainKeyword("."), _),
    ) => {
      self.debug_logger.info("[ExpectDot] DOT")
      (ExpectLineJump, DataAction::EmitQuad)
    }

    // ── ExpectLineJump ─────────────────────────────────────────
    (ExpectLineJump, LocatedToken(N3Token::LineJump, _)) => {
      self.debug_logger.info("[ExpectLineJump] LineJump")
      (ExpectSubject, DataAction::ClearAccumulator)
    }
    (ExpectLineJump, LocatedToken(N3Token::End, _)) => {
      self.debug_logger.info("[ExpectLineJump] End")
      (ExpectSubject, DataAction::ClearAccumulator)
    }

    // ── Error fallback ─────────────────────────────────────────
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "Unexpected token in state '\{nquads_state}': \{token.0}",
        token.1,
      )
      self.debug_logger.error("\{err}")
      return Ok(
        (
          self.add_error(err),
          StateWrapper::as_state_enum(nquads_state),
          DataAction::NoOp,
        ),
      )
    }
  }

  self.debug_logger.info(
    "[TRANSITION] \{nquads_state} + \{token.0} -> \{next_state}",
  )

  Ok(
    (
      self.set_current_state(next_state),
      StateWrapper::as_state_enum(next_state),
      action,
    ),
  )
}

///|
pub impl GenMachine for NQuadsRecognizer with fn is_accepting(
  self : NQuadsRecognizer,
) -> Bool {
  match self.current_state() {
    RdfState::NQuadsState(NQuadsState::ExpectSubject) => true
    RdfState::NQuadsState(NQuadsState::ExpectLineJump) => true
    _ => false // self.stack.is_empty()
  }
}

///|
pub impl GenMachine for NQuadsRecognizer with fn context(
  _self : NQuadsRecognizer,
) -> RdfContext {
  RdfContext::NQuadsRecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
  })
}

///|
pub impl GenMachine for NQuadsRecognizer with fn[ST : StateWrapper] set_current_state(
  self : NQuadsRecognizer,
  state : ST,
) -> NQuadsRecognizer {
  let state = ST::as_state_enum(state)
  match state {
    RdfState::NQuadsState(s) => { ..self, current_state: s }
  }
}

///|
pub impl GenMachine for NQuadsRecognizer with fn accumulate(
  self : NQuadsRecognizer,
  data_world : DataWorld,
  action : DataAction,
) -> (NQuadsRecognizer, DataWorld) {
  let dw = data_world
  let m = self
  self.debug_logger.info("[ACCUMULATE] \{action}")
  match action {
    DataAction::NoOp => return (m, dw)
    DataAction::AddSubject(s) => dw.subjects.push(s)
    DataAction::AddPredicate(p) => dw.predicates.push(p)
    DataAction::AddObject(o) => dw.objects.push(o)
    DataAction::SetTempLiteral(s) => {
      self.debug_logger.info("[ACCUMULATE] SetTempLiteral: \{s}")
      dw.temp_literal = Some(s)
    }
    DataAction::SetGraphName(gn) => dw.graph_name = Some(gn)
    DataAction::EmitQuad => m.emit_quad = true
    DataAction::EmitQuadWithLiteral(kind) => {
      let lit = match kind {
        LiteralKind::Simple =>
          LiteralRef::new_simple_literal(dw.temp_literal.unwrap_or(""))
        LiteralKind::Lang(lang, dir) =>
          LiteralRef::new_directional_language_tagged_literal_unchecked(
            dw.temp_literal.unwrap_or(""),
            lang,
            dir,
          )
        LiteralKind::Typed(value, iri) =>
          LiteralRef::new_typed_literal(value, iri)
      }
      dw.objects.push(lit.as_term())
      m.emit_quad = true
    }
    // accumulate 中
    DataAction::EmitQuadWithTempLiteral(datatype_node) => {
      let temp = dw.temp_literal.unwrap_or("")
      let lit = LiteralRef::new_typed_literal(temp, datatype_node)
      dw.objects.push(lit.as_term())
      m.emit_quad = true
    }
    DataAction::PushStack(state) => m.stack.push(state)
    DataAction::ClearAccumulator => {
      dw.subjects.clear()
      dw.predicates.clear()
      dw.objects.clear()
      dw.temp_literal = None
      dw.graph_name = None
    }
    DataAction::FinalizeLiteral(kind) => {
      let lit = match kind {
        LiteralKind::Simple =>
          LiteralRef::new_simple_literal(dw.temp_literal.unwrap_or(""))
        LiteralKind::Lang(lang, dir) =>
          LiteralRef::new_directional_language_tagged_literal_unchecked(
            dw.temp_literal.unwrap_or(""),
            lang,
            dir,
          )
        LiteralKind::Typed(value, iri) =>
          LiteralRef::new_typed_literal(value, iri)
      }
      dw.objects.push(lit.as_term())
      // m.finalize_literal = Some(kind)
    }
    DataAction::FinalizeQuotedTriple =>
      match (dw.subjects.pop(), dw.predicates.pop(), dw.objects.pop()) {
        (Some(s), Some(p), Some(o)) =>
          dw.objects.push(
            TermRef::TripleRef(TripleRef::{
              subject: s,
              predicate: p,
              object: o,
            }),
          )
        _ => m.errors.push(RuleRecognizerError::TripleMissingDot)
      }
  }
  (m, dw)
}

///|
pub impl GenMachine for NQuadsRecognizer with fn get_and_clear_output(
  self : NQuadsRecognizer,
  data_world : DataWorld,
) -> (NQuadsRecognizer, RdfOut?) {
  let m = self
  let dw = data_world
  let output = if m.emit_quad {
    self.pop_quad_from_data_world(dw)
  } else {
    None
  }

  // emit_quad 成功后，从数组末尾删除
  if output is Some(_) {
    let _ = dw.subjects.pop()
    let _ = dw.predicates.pop()
    let _ = dw.objects.pop()
  }

  // 清除标志
  m.emit_quad = false
  // m.finalize_literal = None

  (m, output)
}

///|
fn NQuadsRecognizer::pop_quad_from_data_world(
  _self : NQuadsRecognizer,
  dw : DataWorld,
) -> RdfOut? {
  let subject = dw.subjects.pop()
  let predicate = dw.predicates.pop()
  let object = dw.objects.pop()
  match (subject, predicate, object) {
    (Some(s), Some(p), Some(o)) => {
      let graph_name = dw.graph_name.unwrap_or(GraphNameRef::DefaultGraph)
      Some(
        RdfOut::Quad(
          Quad::Quad(
            s.into_owned(),
            p.into_owned(),
            o.into_owned(),
            graph_name.into_owned(),
          ),
        ),
      )
    }
    _ => None
  }
}

///|
fn NQuadsRecognizer::add_error(
  self : NQuadsRecognizer,
  err : RuleRecognizerError,
) -> NQuadsRecognizer {
  let new_errors = self.errors
  new_errors.push(err)
  { ..self, errors: new_errors }
}
