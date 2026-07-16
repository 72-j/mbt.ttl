///|
pub fn NQuadsState::to_str(self : NQuadsState) -> String {
  Show::to_string(self)
}

// ===== NQuadsRecognizer 实现 =====

///|
pub impl StateMachine for NQuadsRecognizer with fn initial_state(
  _self : NQuadsRecognizer,
) -> RdfState {
  RdfState::NQuadsState(NQuadsState::ExpectSubject)
}

///|
pub impl StateMachine for NQuadsRecognizer with fn error_recovery_statemachine(
  self,
) -> NQuadsRecognizer {
  self.error_recovery_state()
}

///|
pub impl StateMachine for NQuadsRecognizer with fn current_state(self) -> RdfState {
  // self.stack.last().unwrap_or(NQuadsState::ExpectSubject).as_state_enum()
  self.current_state.as_state_enum()
}

///|
pub impl StateMachine for NQuadsRecognizer with fn step(
  self,
  event : Event,
  data_world : DataWorld,
) -> NQuadsRecognizer {
  let current_state = self.current_state()

  let result = self.transition(
    current_state.as_state_enum(),
    event,
    self.context(),
    data_world,
  )
  match result {
    Ok((new_machine, new_state, _output)) => {
      // let new_context = new_machine.context()
      // let new_machine = new_machine.set_context(new_context)
      let new_machine = new_machine.set_current_state(new_state)
      new_machine
    }
    Err(_e) => abort("Error")
  }
}

///|
pub impl StateMachine for NQuadsRecognizer with fn reset(self) -> NQuadsRecognizer {
  self.error_recovery_state()
}

///|
pub impl StateMachine for NQuadsRecognizer with fn transition(
  self : NQuadsRecognizer,
  state : RdfState,
  event : Event,
  _context : Ctx,
  data_world : DataWorld,
) -> TransitionResult[NQuadsRecognizer, RdfState, RdfOut] {

  // 1. 解包
  let nquads_state = match state {
    RdfState::NQuadsState(s) => s
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid state", self.last_range),
      )
  }

  // let ctx = match context {
  //   RdfContext::NQuadsRecognizerContext(c) => c
  //   _ =>
  //     return Err(
  //       RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
  //     )
  // }
  // let data_world = data_world
  let token = event
  self.debug_logger.info("NQuads State: \{nquads_state}, Event: \{token}")

  // let data_world = DataWorld::default()
  let (next_state, data_world) = match (nquads_state, token) {

    // ── Start / ExpectSubject ─────────────────────────────────
    (Start, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[Start] IRI: \{iri}")
      let node = NamedNodeRef::new_unchecked(iri).as_enum()
      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (Start, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[Start] Blank: _:\{l}")
      let node = BlankNodeRef::new_unchecked(l).as_enum()
      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (Start, LocatedToken(N3Token::LineJump | N3Token::End, _)) => {
      self.debug_logger.info("[Start] LineJump/End")
      (Start, data_world)
    }
    (ExpectSubject, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectSubject] IRI: \{iri}")
      let node = NamedNodeRef::new_unchecked(iri).as_enum()
      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (ExpectSubject, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[ExpectSubject] Blank: _:\{l}")
      let node = BlankNodeRef::new_unchecked(l).as_enum()
      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (ExpectSubject, LocatedToken(N3Token::LineJump | N3Token::End, _)) => {
      self.debug_logger.info("[ExpectSubject] LineJump/End (skip)")
      (ExpectSubject, data_world)
    }

    // ── ExpectPredicate ────────────────────────────────────────
    (ExpectPredicate, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectPredicate] IRI: \{iri}")
      let pred = NamedNodeRef::new_unchecked(iri)
      (ExpectObject, DataWorld::{ ..data_world, predicates: [pred] })
    }

    // ── ExpectObject ───────────────────────────────────────────
    (ExpectObject, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectObject] IRI: \{iri}")
      let obj = TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))
      (ExpectDotOrGraphName, DataWorld::{ ..data_world, objects: [obj] })
    }
    (ExpectObject, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[ExpectObject] Blank: _:\{l}")
      let obj = BlankNodeRef::new_unchecked(l).as_term()
      (ExpectDotOrGraphName, DataWorld::{ ..data_world, objects: [obj] })
    }
    (ExpectObject, LocatedToken(N3Token::String(v), _)) => {
      self.debug_logger.info("[ExpectObject] STRING: '\{v}'")
      (ExpectLiteralSuffix, DataWorld::{ ..data_world, temp_literal: Some(v) })
    }
    (ExpectObject, LocatedToken(N3Token::Punctuation("<<("), _)) => {
      self.debug_logger.info("[ExpectObject] QuotedTriple")
      (
        ExpectSubject,
        DataWorld::{
          ..data_world,
          stack_push: [NQuadsState::ExpectDotOrGraphName],
        },
      )
    }

    // ── ExpectDotOrGraphName ───────────────────────────────────
    (ExpectDotOrGraphName, LocatedToken(N3Token::Punctuation("."), _)) => {
      self.debug_logger.info(
        "[ExpectDotOrGraphName] DOT, emit_quad=true data_world.temp_literal \{@debug.to_string(data_world.temp_literal)}",
      )
      (ExpectLineJump, DataWorld::{ ..data_world, emit_quad: true })
    }
    (ExpectDotOrGraphName, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("[ExpectDotOrGraphName] GraphName IRI: \{iri}")
      let gn = NamedNodeRef::new_unchecked(iri).as_enum()
      (ExpectDot, DataWorld::{ ..data_world, graph_name: gn })
    }
    (ExpectDotOrGraphName, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      self.debug_logger.info("[ExpectDotOrGraphName] GraphName Blank: _:\{l}")
      let gn = BlankNodeRef::new_unchecked(l).as_enum()
      (ExpectDot, DataWorld::{ ..data_world, graph_name: gn })
    }

    // ── ExpectDot ──────────────────────────────────────────────
    (ExpectDot, LocatedToken(N3Token::Punctuation("."), _)) => {
      self.debug_logger.info(
        "[ExpectDot] DOT, emit_quad_with_graph=true,temp_literal=\{@debug.to_string(data_world.temp_literal)},",
      )
      (ExpectLineJump, DataWorld::{ ..data_world, emit_quad_with_graph: true })
    }

    // ── ExpectLiteralSuffix ────────────────────────────────────
    (ExpectLiteralSuffix, LocatedToken(N3Token::Punctuation("."), _)) => {
      self.debug_logger.info(
        "[ExpectLiteralSuffix] DOT, temp_literal=\{@debug.to_string(data_world.temp_literal)}, finalize=Simple",
      )
      (
        ExpectLineJump,
        DataWorld::{
          ..data_world,
          finalize_literal: Some(LiteralKind::Simple),
          temp_literal: data_world.temp_literal,
          emit_quad: true,
        },
      )
    }
    (ExpectLiteralSuffix, LocatedToken(N3Token::Punctuation("^^"), _)) => {
      self.debug_logger.info(
        "[ExpectLiteralSuffix] ^^, temp_literal=\{@debug.to_string(data_world.temp_literal)}",
      )
      (ExpectDatatype, data_world)
    }
    (
      ExpectLiteralSuffix,
      LocatedToken(N3Token::LangTag(language~, direction~), _),
    ) => {
      self.debug_logger.info("[ExpectLiteralSuffix] LangTag: @\{language}")
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
        DataWorld::{
          ..data_world,
          finalize_literal: Some(LiteralKind::Lang(tag, dir)),
        },
      )
    }

    // ── ExpectDatatype ─────────────────────────────────────────
    (ExpectDatatype, LocatedToken(N3Token::Iri(iri), _)) => {
      self.debug_logger.info(
        "[ExpectDatatype] IRI: \{iri}, temp_literal=\{@debug.to_string(data_world.temp_literal)}",
      )
      let datatype_node = NamedNodeRef::new_unchecked(iri)
      let datatype = match data_world.temp_literal {
        Some(v) => datatype_node.into_datatype(v)
        None =>
          return Err(
            RuleRecognizerError::SyntaxError("Invalid literal", self.last_range),
          )
      }
      (
        ExpectDotOrGraphName,
        DataWorld::{
          ..data_world,
          finalize_literal: Some(LiteralKind::Typed(datatype, datatype_node)),
          temp_literal: data_world.temp_literal,
        },
      )
    }

    // ── ExpectLineJump ─────────────────────────────────────────
    (ExpectLineJump, LocatedToken(N3Token::LineJump, _)) => {
      self.debug_logger.info("[ExpectLineJump] LineJump -> ExpectSubject")
      (ExpectSubject, data_world)
    }
    (ExpectLineJump, LocatedToken(N3Token::End, _)) => {
      self.debug_logger.info("[ExpectLineJump] End -> ExpectSubject")
      (ExpectSubject, data_world)
    }

    // ── 错误兜底 ───────────────────────────────────────────────
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "Unexpected token in state '\{nquads_state}': \{token.0}",
        token.1,
      )
      self.debug_logger.info("[ERROR] \{err}")
      return Ok((self.add_error(err), nquads_state.as_state_enum(), None))
    }
  }
  // self.debug_logger.info("[TRANSITION] \{nquads_state} + \{token.0} -> \{next_state}, data_world=\{@debug.to_string(data_world.temp_literal)}")

  // self.debug_logger.info("[TRANSITION] \{nquads_state} + \{token.0} -> \{next_state}, data_world=\{data_world}")

  // 3. 应用数据操作到 self
  let new_self = self.apply_data_ops(data_world)

  // 4. 处理 emit_quad 的输出
  let output = match
    (
      data_world.emit_quad,
      data_world.emit_quad_with_graph,
      data_world.graph_name,
    ) {
    (true, false, _) => new_self.pop_quad()
    (false, true, gn) => new_self.pop_quad(graph_name=gn.into_graph())
    _ => None
  }

  Ok(
    (new_self.set_current_state(next_state), next_state.as_state_enum(), output),
  )
}

///|
pub impl StateMachine for NQuadsRecognizer with fn is_accepting(
  self : NQuadsRecognizer,
) -> Bool {
  match self.current_state() {
    RdfState::NQuadsState(NQuadsState::ExpectSubject) => true
    RdfState::NQuadsState(NQuadsState::ExpectLineJump) => true
    _ => false // self.stack.is_empty()
  }
}

///|
pub impl StateMachine for NQuadsRecognizer with fn context(
  _self : NQuadsRecognizer,
) -> RdfContext {
  RdfContext::NQuadsRecognizerContext({
    lexer_options: LexerOptions::{ base_iri: None },
    with_graph_name: false,
  })
}

///|
pub impl StateMachine for NQuadsRecognizer with fn[ST : StateWrapper] set_current_state(
  self : NQuadsRecognizer,
  state : ST,
) -> NQuadsRecognizer {
  let state = ST::as_state_enum(state)
  match state {
    RdfState::NQuadsState(s) =>
      // 返回一个新的 NQuadsRecognizer 实例，其中 stack 被更新
      // 假设有一个 with_stack 或类似的方法，或者直接构造新实例
      // 这里简化处理，实际需要根据 NQuadsRecognizer 的结构体定义来更新
      // debug("[Step 3] Set current state: \{s}")
      // let new_stack = self.stack
      // if new_stack.is_empty() {
      //   new_stack.push(s)
      // } else {
      //   let _ = new_stack.pop() // 移除旧状态
      //   new_stack.push(s) // 添加新状态
      // }
      { ..self, current_state: s }
    _ => self
  }
}

// 辅助方法：统一处理 TransitionResult 并返回更新后的 Self

///|
pub fn NQuadsRecognizer::process_transition_result(
  result : TransitionResult[NQuadsRecognizer, NQuadsState, RdfOut],
) -> TransitionResult[NQuadsRecognizer, RdfState, RdfOut] {
  match result {
    Ok((new_self, new_state, output)) =>
      Ok((new_self, new_state.as_state_enum(), output))
    Err(e) => Err(e)
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

///|
/// 应用数据操作到 self
fn NQuadsRecognizer::apply_data_ops(
  self : NQuadsRecognizer,
  ops : DataWorld,
) -> NQuadsRecognizer {
  // let s = self

  self.debug_logger.info("[apply_data_ops] ENTER")
  self.debug_logger.info("  ops.subjects: \{ops.subjects.length()}")
  self.debug_logger.info("  ops.predicates: \{ops.predicates.length()}")
  self.debug_logger.info("  ops.objects: \{ops.objects.length()}")
  self.debug_logger.info(
    "  ops.temp_literal: \{@debug.to_string(ops.temp_literal)}",
  )
  self.debug_logger.info(
    "  ops.finalize_literal: \{@debug.to_string(ops.finalize_literal)}",
  )
  self.debug_logger.info("  ops.emit_quad: \{ops.emit_quad}")

  for subject in ops.subjects {
    self.subjects.push(subject)
  }
  for pred in ops.predicates {
    self.predicates.push(pred)
  }
  for obj in ops.objects {
    self.objects.push(obj)
  }

  if ops.finalize_literal is Some(kind) {
    self.debug_logger.info("[apply_data_ops] finalize_literal = Some(\{kind})")
    let lit = match kind {
      LiteralKind::Simple => {
        let v = ops.temp_literal.unwrap_or("")
        self.debug_logger.info("  LiteralKind::Simple, temp_literal='\{v}'")
        LiteralRef::new_simple_literal(v)
      }
      LiteralKind::Lang(lang, dir) => {
        let v = ops.temp_literal.unwrap_or("")
        self.debug_logger.info(
          "  LiteralKind::Lang, temp_literal='\{v}', lang=\{lang}",
        )
        LiteralRef::new_directional_language_tagged_literal_unchecked(
          v, lang, dir,
        )
      }
      LiteralKind::Typed(value, iri) => {
        self.debug_logger.info(
          "  LiteralKind::Typed, value='\{value}', iri=\{iri}",
        )
        LiteralRef::new_typed_literal(value, iri)
      }
    }
    self.objects.push(lit.as_term())
    //  ops.temp_literal = None
  }

  for state in ops.stack_push {
    self.stack.push(state)
  }

  if ops.clear_accumulator {
    self.subjects.clear()
    self.predicates.clear()
    self.objects.clear()
  }

  if ops.finalize_quoted_triple {
    match (self.subjects.pop(), self.predicates.pop(), self.objects.pop()) {
      (Some(su), Some(pr), Some(ob)) =>
        self.objects.push(
          TermRef::TripleRef(TripleRef::{
            subject: su,
            predicate: pr,
            object: ob,
          }),
        )
      _ => self.errors.push(RuleRecognizerError::TripleMissingDot)
    }
  }

  self.debug_logger.info(
    "[apply_data_ops] EXIT, self.objects.length()=\{self.objects.length()},ops.temp_literal: \{@debug.to_string(ops.temp_literal)}",
  )
  self
}

///|
/// 弹出并发射 Quad
fn NQuadsRecognizer::pop_quad(
  self : NQuadsRecognizer,
  graph_name? : GraphNameRef,
) -> RdfOut? {
  let subject = self.subjects.pop()
  let predicate = self.predicates.pop()
  let object = self.objects.pop()

  match (subject, predicate, object) {
    (Some(s), Some(p), Some(o)) => {
      let graph_name = graph_name.unwrap_or(GraphNameRef::DefaultGraph)
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
    _ => {
      self.debug_logger.info("ERROR: missing data!")
      None
    }
  }
}
