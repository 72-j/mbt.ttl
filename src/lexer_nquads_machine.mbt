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
pub impl StateMachine for NQuadsRecognizer with fn step(self, event : Event) -> NQuadsRecognizer {
  let current_state = self.current_state()
  let result = self.transition(
    current_state.as_state_enum(),
    event,
    self.context(),
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
  _context : RdfContext,
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

  let token = event
  self.debug_logger.info("NQuads State: \{nquads_state}, Event: \{token}")

  let data_world = DataWorld::default()
  let (next_state, data_world) = match (nquads_state, token) {

    // ── Start / ExpectSubject ─────────────────────────────────
    (Start, LocatedToken(N3Token::Iri(iri), _)) => {
      let node = NamedNodeRef::new_unchecked(iri).as_enum()
      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (Start, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      let node = BlankNodeRef::new_unchecked(l).as_enum()
      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (Start, LocatedToken(N3Token::LineJump | N3Token::End, _)) =>
      (Start, data_world)
    (ExpectSubject, LocatedToken(N3Token::Iri(iri), _)) => {
      let node = NamedNodeRef::new_unchecked(iri).as_enum()

      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (ExpectSubject, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      let node = BlankNodeRef::new_unchecked(l).as_enum()
      (ExpectPredicate, DataWorld::{ ..data_world, subjects: [node] })
    }
    (ExpectSubject, LocatedToken(N3Token::LineJump | N3Token::End, _)) =>
      // (ExpectSubject, LocatedToken(N3Token::Comment(_), _)) =>
      (ExpectSubject, data_world)

    // ── ExpectPredicate ────────────────────────────────────────
    (ExpectPredicate, LocatedToken(N3Token::Iri(iri), _)) => {
      let pred = NamedNodeRef::new_unchecked(iri)
      (ExpectObject, DataWorld::{ ..data_world, predicates: [pred] })
    }

    // ── ExpectObject ───────────────────────────────────────────
    (ExpectObject, LocatedToken(N3Token::Iri(iri), _)) => {
      let obj = TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))
      (ExpectDotOrGraphName, DataWorld::{ ..data_world, objects: [obj] })
    }
    (ExpectObject, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      let obj = BlankNodeRef::new_unchecked(l).as_term()
      (ExpectDotOrGraphName, DataWorld::{ ..data_world, objects: [obj] })
    }
    (ExpectObject, LocatedToken(N3Token::String(v), _)) =>
      (ExpectLiteralSuffix, DataWorld::{ ..data_world, temp_literal: Some(v) })
    (ExpectObject, LocatedToken(N3Token::Punctuation("<<("), _)) =>
      (
        ExpectSubject,
        DataWorld::{
          ..data_world,
          stack_push: [NQuadsState::ExpectDotOrGraphName],
        },
      )

    // ── ExpectDotOrGraphName ───────────────────────────────────
    (ExpectDotOrGraphName, LocatedToken(N3Token::Punctuation("."), _)) =>
      (ExpectLineJump, DataWorld::{ ..data_world, emit_quad: true })
    (ExpectDotOrGraphName, LocatedToken(N3Token::Iri(iri), _)) => {
      let gn = NamedNodeRef::new_unchecked(iri).as_enum()
      (ExpectDot, DataWorld::{ ..data_world, graph_name: gn })
    }
    (ExpectDotOrGraphName, LocatedToken(N3Token::BlankNodeLabel(l), _)) => {
      let gn = BlankNodeRef::new_unchecked(l).as_enum()
      (ExpectDot, DataWorld::{ ..data_world, graph_name: gn })
    }

    // ── ExpectDot ──────────────────────────────────────────────
    (ExpectDot, LocatedToken(N3Token::Punctuation("."), _)) =>
      (ExpectLineJump, DataWorld::{ ..data_world, emit_quad_with_graph: true })

    // ── ExpectLiteralSuffix ────────────────────────────────────
    (ExpectLiteralSuffix, LocatedToken(N3Token::Punctuation("."), _)) =>
      (
        ExpectLineJump,
        DataWorld::{
          ..data_world,
          finalize_literal: Some(LiteralKind::Simple),
          emit_quad: true,
        },
      )
    (ExpectLiteralSuffix, LocatedToken(N3Token::Punctuation("^^"), _)) =>
      (ExpectDatatype, data_world)
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
        DataWorld::{
          ..data_world,
          finalize_literal: Some(LiteralKind::Lang(tag, dir)),
        },
      )
    }

    // ── ExpectDatatype ─────────────────────────────────────────
    (ExpectDatatype, LocatedToken(N3Token::Iri(iri), _)) => {
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
        },
      )
    }

    // ── ExpectLineJump ─────────────────────────────────────────
    // ★★★ 关键！缺少这个分支导致死循环 ★★★
    (ExpectLineJump, LocatedToken(N3Token::LineJump, _)) =>
      (ExpectSubject, data_world)
    (ExpectLineJump, LocatedToken(N3Token::End, _)) =>
      (ExpectSubject, data_world)

    // ── 错误兜底 ───────────────────────────────────────────────
    _ => {
      let err = RuleRecognizerError::SyntaxError(
        "Unexpected token in state '\{nquads_state}': \{token.0}",
        token.1,
      )
      return Ok((self.add_error(err), nquads_state.as_state_enum(), None))
    }
  }

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
  let s = self

  for subject in ops.subjects {
    s.subjects.push(subject)
  }
  for pred in ops.predicates {
    s.predicates.push(pred)
  }
  for obj in ops.objects {
    s.objects.push(obj)
  }

  // if  ops.temp_literal is  Some(v) { s.temp_literal = Some(v) }

  if ops.finalize_literal is Some(kind) {
    let lit = match kind {
      LiteralKind::Simple =>
        LiteralRef::new_simple_literal(ops.temp_literal.unwrap())
      LiteralKind::Lang(lang, dir) =>
        LiteralRef::new_directional_language_tagged_literal_unchecked(
          ops.temp_literal.unwrap(),
          lang,
          dir,
        )
      LiteralKind::Typed(value, iri) => {
        let literal = LiteralRef::new_typed_literal(value, iri)
        literal
        // LiteralRef::new_typed_literal(ops.temp_literal, iri)
      }
    }
    s.objects.push(lit.as_term())
    // s.temp_literal = None
  }

  // if let gn = ops.graph_name { s.graph_name = gn }

  for state in ops.stack_push {
    s.stack.push(state)
  }

  if ops.clear_accumulator {
    s.subjects.clear()
    s.predicates.clear()
    s.objects.clear()
    // s.graph_name = None
  }

  if ops.finalize_quoted_triple {
    // 处理引号三元组
    match (s.subjects.pop(), s.predicates.pop(), s.objects.pop()) {
      (Some(su), Some(pr), Some(ob)) =>
        s.objects.push(
          TermRef::TripleRef(TripleRef::{
            subject: su,
            predicate: pr,
            object: ob,
          }),
        )
      _ => s.errors.push(RuleRecognizerError::TripleMissingDot)
    }
  }

  // s.last_range = token.1
  s
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
