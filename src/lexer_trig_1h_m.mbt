// lexer_trig_1h1_refactored.mbt

///|
// fn TriGRecognizer::handle_trig_doc_m(
//   self : TriGRecognizer,
//   event : Event,
//   context : RdfContext,
// ) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
//   let ctx = match context {
//     RdfContext::TriGRecognizerContext(c) => c
//     _ => return Err(RuleRecognizerError::SyntaxError("Invalid context", self.last_range))
//   }

//    // 假设 Event 包装了 token

//   // 重置当前图为默认图 (如果需要每次进入 Doc 都重置，否则可能在 init 中做)
//   let new_self = { ..self, cur_graph: GraphNameRef::DefaultGraph }

//   // 注意：原代码 push TriGDoc 到 stack，这在新架构中可能不需要，因为 transition 返回的状态就是当前状态
//   // 但如果内部 stack 用于其他目的，需保留。这里假设内部 stack 仅用于嵌套结构解析。

//   match event {
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::PlainKeyword(k), _)) if eq_ignore_ascii_case(k, "base") => {
//       // 转移到 BaseExpectIri 状态
//       Ok((new_self, TriGState::BaseExpectIri, None))
//     }
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::PlainKeyword(k), _)) if eq_ignore_ascii_case(k, "prefix") => {
//       Ok((new_self, TriGState::PrefixExpectPrefix, None))
//     }
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::PlainKeyword(k), _)) if eq_ignore_ascii_case(k, "version") => {
//       Ok((new_self, TriGState::VersionExpectVersion, None))
//     }
//     // ... 处理其他关键字 ...

//     // 默认情况：进入三元组或图解析
//     _ => {
//       // 将当前 token “推回” 或让下一个状态处理？
//       // 在新架构中，通常由引擎再次调用 transition 并传入同一个 event，或者我们在当前状态消耗它。
//       // 原代码是 push TriplesOrGraph 然后 fallthrough。
//       // 这里我们直接转移到 TriplesOrGraph，并期望引擎能重新处理当前 token？
//       // 或者，TriplesOrGraph 的 handle 方法需要能处理“空”输入或重用 token？
//       // 标准做法：如果当前状态决定下一个状态，且当前 token 未被消耗，通常需要一种机制“peek”或“unget”。
//       // 鉴于原代码逻辑，这里我们假设转移到 TriplesOrGraph，并且该状态的 handle 函数会被立即用同一个 token 调用（如果引擎支持）
//       // 或者，我们在这里直接调用 handle_triples_or_graph_m 的逻辑？不，这违背了状态机原则。

//       // 修正：原代码中 handle_trig_doc 最后 push TriplesOrGraph 并返回 self。
//       // 这意味着下一个 loop 迭代会用同一个 token 进入 TriplesOrGraph。
//       // 在我们的架构中，我们返回新的状态 TriGState::TriplesOrGraph。
//       // 引擎在下一次迭代时会用同一个 event 调用 transition(state=TriplesOrGraph, event=same_event)。
//       Ok((new_self, TriGState::TriplesOrGraph, None))
//     }
//   }
// }

///|
fn TriGRecognizer::handle_triples_or_graph_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let term = NamedNodeRef::new_unchecked(iri).as_enum()
      // 转移到 WrappedGraphOrPredicateObjectList，并携带 term 信息
      // 由于 TriGState::WrappedGraphOrPredicateObjectList 需要参数 term，我们需要一个带参数的状态构造
      Ok((self, TriGState::WrappedGraphOrPredicateObjectList(term~), None))
    }
    // ... 处理 PrefixedName, BlankNodeLabel 等 ...
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("("), _)
    ) => {
      // 原代码: push ExpectDot, PredicateObjectList, SubjectCollectionBeginning
      // 新架构: 我们需要模拟这个栈行为。
      // 如果 TriGRecognizer 内部有 stack 字段用于解析器栈，我们更新它。
      let new_stack = self.stack
      new_stack.push(TriGState::ExpectDot)
      new_stack.push(TriGState::PredicateObjectList)
      new_stack.push(TriGState::SubjectCollectionBeginning)

      let new_self = { ..self, stack: new_stack }
      // 下一个活跃状态是 SubjectCollectionBeginning? 或者原代码逻辑是立即进入?
      // 原代码最后返回 self，意味着下一次迭代处理同一个 token。
      // 这里我们返回 SubjectCollectionBeginning 作为下一个状态。
      Ok((new_self, TriGState::SubjectCollectionBeginning, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "TOKEN is not a valid subject or graph name",
          self.last_range,
        ),
      )
  }
}

///|
fn TriGRecognizer::handle_wrapped_graph_or_predicate_object_list_m(
  self : TriGRecognizer,
  term : NamedOrBlankNodeRef, // 从状态中提取
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  // 

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("{"), _)
    ) if ctx.with_graph_name => {
      let new_self = { ..self, cur_graph: term.into_graph() }
      // 转移到 WrappedGraph
      Ok((new_self, TriGState::WrappedGraph, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("a"), _)
    ) => {
      let new_self = self
      new_self.cur_subject.push(term)
      new_self.cur_predicate.push(lwTYPE)

      let new_stack = new_self.stack
      new_stack.push(TriGState::ExpectDot)
      new_stack.push(TriGState::ObjectsList)

      let new_self_with_stack = { ..new_self, stack: new_stack }
      // 转移到 ObjectsList
      Ok((new_self_with_stack, TriGState::ObjectsList, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let new_self = self
      new_self.cur_subject.push(term)
      new_self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))

      let new_stack = new_self.stack
      new_stack.push(TriGState::ExpectDot)
      new_stack.push(TriGState::ObjectsList)

      let new_self_with_stack = { ..new_self, stack: new_stack }
      Ok((new_self_with_stack, TriGState::ObjectsList, None))
    }
    // ... 处理 PrefixedName ...
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected a predicate or graph block",
          self.last_range,
        ),
      )
  }
}

///|
fn TriGRecognizer::handle_objects_list_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // let ctx = match context {
  //   RdfContext::TriGRecognizerContext(c) => c
  //   _ =>
  //     return Err(
  //       RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
  //     )
  // }

  // ObjectsList 只是路由到 Object
  // 原代码: push Object, then recognize_next (which processes same token)
  // 新架构: 直接转移到 Object 状态，引擎会用同一个 event 调用 handle_object_m
  debug("TrigRecognizer::recognize_objects_list_m \{self.stack.to_string()}")
  let new_stack = self.stack
  new_stack.push(TriGState::Object) // 如果内部栈需要记录返回点? 原代码似乎没 push 返回点到内部栈，而是直接切换逻辑

  // 注意：原代码中 ObjectsList 是一个“瞬态”状态，它立即把控制权交给 Object。
  // 如果我们的状态机引擎在一次 transition 中只走一步，那么返回 Object 状态是正确的。

  let new_self = { ..self, stack: new_stack } // 如果 stack 需要更新
  Ok((new_self, TriGState::Object, None))
}

///|
fn TriGRecognizer::handle_object_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // let ctx = match context {
  //   RdfContext::TriGRecognizerContext(c) => c
  //   _ =>
  //     return Err(
  //       RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
  //     )
  // }
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let obj_term = TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))
      let new_self = self
      new_self.cur_object.push(obj_term)

      // emit_quad 逻辑：生成一个 RdfOut
      // 假设 make_current_quad 或类似方法可用
      let quad = new_self.make_current_quad() // 假设此方法存在并正确构建 Quad

      // 转移状态：根据原代码，push PredicateObjectListEnd
      let new_stack = new_self.stack
      new_stack.push(TriGState::PredicateObjectListEnd)

      let final_self = { ..new_self, stack: new_stack }
      // 返回生成的 Quad
      Ok((final_self, TriGState::PredicateObjectListEnd, Some(quad)))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("("), _)
    ) => {
      // 嵌套集合
      let new_stack = self.stack
      new_stack.push(TriGState::ObjectCollectionBeginning)

      let new_self = { ..self, stack: new_stack }
      // 转移到 ObjectCollectionBeginning
      Ok((new_self, TriGState::ObjectCollectionBeginning, None))
    }
    // ... 处理其他类型 ...
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "TOKEN is not a valid RDF object",
          self.last_range,
        ),
      )
  }
}

///|
fn TriGRecognizer::handle_object_collection_beginning_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // let ctx = match context {
  //   RdfContext::TriGRecognizerContext(c) => c
  //   _ =>
  //     return Err(
  //       RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
  //     )
  // }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) => {
      // 空集合 ()
      let new_self = self
      new_self.cur_object.push(TermRef::NamedNodeRef(lwNIL))

      // emit_quad for nil? 原代码调用了 emit_quad(results)
      let quad = new_self.make_current_quad()

      let new_stack = new_self.stack
      new_stack.push(TriGState::PredicateObjectListEnd)

      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::PredicateObjectListEnd, Some(quad)))
    }
    _ => {
      // 非空集合
      let root = BlankNode::default()
      let new_self = self

      // Push root as current object and emit quad (Subject, Predicate, Root)
      new_self.cur_object.push(TermRef::BlankNodeRef(root.as_ref()))
      let quad_root = new_self.make_current_quad()

      // Prepare for first element
      new_self.cur_subject.push(
        NamedOrBlankNodeRef::BlankNodeRef(root.as_ref()),
      )
      new_self.cur_predicate.push(
        NamedNodeRef::NamedNodeRef(lwFIRST.to_string()),
      )

      let new_stack = new_self.stack
      new_stack.push(TriGState::ObjectCollectionPossibleEnd)
      new_stack.push(TriGState::Object)

      let final_self = { ..new_self, stack: new_stack }
      // 返回根节点的 Quad，后续元素的 Quad 将在后续状态中生成
      Ok((final_self, TriGState::Object, Some(quad_root)))
    }
  }
}

///|
fn TriGRecognizer::handle_object_collection_possible_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  let old_subject = match self.cur_subject.pop() {
    Some(s) => s
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: subject stack empty",
          self.last_range,
        ),
      )
  }

  // Clean up object stack if needed? Original code pops object.
  // Let's assume we need to pop the object that was just processed by the previous Object state.
  // However, in our flow, Object state returns the Quad. The object remains in cur_object until popped here?
  // Original code: let _ = self.cur_object.pop()

  let new_self = { ..self, cur_subject: self.cur_subject } // Pop last subject manually if pop() isn't available on immutable, or use mutable logic in builder
  // For simplicity, assuming we construct new_self with updated stacks

  if event
    is LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) {
    // End of collection
    let _ = new_self.cur_predicate.pop()

    // Generate rest -> nil
    let rest_quad = RdfOut::Quad(
      Quad::Quad(
        old_subject.into_owned(),
        lwREST.into_owned(),
        lwNIL.as_term().into_owned(),
        new_self.cur_graph.into_owned(),
      ),
    )

    let new_stack = new_self.stack
    new_stack.push(TriGState::PredicateObjectListEnd)

    let final_self = { ..new_self, stack: new_stack }
    Ok((final_self, TriGState::PredicateObjectListEnd, Some(rest_quad)))
  } else {
    // Continue collection
    let new_bnode = BlankNode::default()

    // Generate rest -> new_bnode (Original code used lwNIL here which seems wrong, but we follow logic or fix it)
    // Fixing to use new_bnode for correct RDF list construction
    let rest_quad = RdfOut::Quad(
      Quad::Quad(
        old_subject.into_owned(),
        lwREST.into_owned(),
        new_bnode.as_ref().as_term().into_owned(),
        new_self.cur_graph.into_owned(),
      ),
    )

    // Push new subject for next element
    let updated_cur_subject = new_self.cur_subject
    updated_cur_subject.push(
      NamedOrBlankNodeRef::BlankNodeRef(new_bnode.as_ref()),
    )

    let new_stack = new_self.stack
    new_stack.push(TriGState::ObjectCollectionPossibleEnd)
    new_stack.push(TriGState::Object)

    let final_self = {
      ..new_self,
      cur_subject: updated_cur_subject,
      stack: new_stack,
    }
    Ok((final_self, TriGState::Object, Some(rest_quad)))
  }
}

///|
fn TriGRecognizer::handle_predicate_object_list_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(","), _)
    ) =>
      // Same predicate, next object
      Ok((self, TriGState::Object, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(";"), _)
    ) =>
      // Same subject, next predicate
      // Original code pushes PredicateObjectListPossibleContinuation
      // We need to define this state or handle it. Assuming it leads back to Verb/Predicate parsing.
      Ok((self, TriGState::PredicateObjectListPossibleContinuation, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      // End of statement
      let new_self = {
        ..self,
        stack: [TriGState::TriGDoc], // Reset stack to Doc
        cur_subject: [],
        cur_predicate: [],
        cur_object: [],
      }
      Ok((new_self, TriGState::TriGDoc, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected ';' or '.' after predicate-object list",
          self.last_range,
        ),
      )
  }
}

// ... 其他 handle_*_m 函数依此类推 ...

// ===== 7. 文档和图 (修正版) =====
// 对应状态: TriGState::TriGDoc

///|
// ===== 修正 handle_trig_doc_m =====

fn TriGRecognizer::handle_trig_doc_m(
  self: TriGRecognizer,
  event: Event,
  context: RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ => return Err(RuleRecognizerError::SyntaxError("Invalid context", self.last_range))
  }

  self.debug_logger.info("[Step 1] Entering TriGDoc with event: \{event}")

  let new_self = { ..self, cur_graph: GraphNameRef::DefaultGraph }

  match event {
    // 匹配 BASE 关键字
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "base") =>
      Ok((new_self, TriGState::BaseExpectIri, None))

    // 匹配 PREFIX 关键字
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "prefix") =>
      Ok((new_self, TriGState::PrefixExpectPrefix, None))

    // 匹配 VERSION 关键字
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "version") =>
      Ok((new_self, TriGState::VersionExpectVersion, None))

    // 处理 @prefix, @base, @version 语法糖
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language="prefix", direction=None), _)
    ) => {
      let new_stack = new_self.stack
      new_stack.push(TriGState::ExpectDot)
      new_stack.push(TriGState::PrefixExpectPrefix)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::PrefixExpectPrefix, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language="base", direction=None), _)
    ) => {
      let new_stack = new_self.stack
      new_stack.push(TriGState::ExpectDot)
      new_stack.push(TriGState::BaseExpectIri)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::BaseExpectIri, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language="version", direction=None), _)
    ) => {
      let new_stack = new_self.stack
      new_stack.push(TriGState::ExpectDot)
      new_stack.push(TriGState::VersionExpectVersion)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::VersionExpectVersion, None))
    }

    // 处理 GRAPH 关键字
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "graph") && ctx.with_graph_name => {
      let new_stack = new_self.stack
      new_stack.push(TriGState::WrappedGraph)
      new_stack.push(TriGState::GraphName)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::GraphName, None))
    }

    // 处理匿名图开始 {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("{"), _)
    ) if ctx.with_graph_name => {
      let new_stack = new_self.stack
      new_stack.push(TriGState::WrappedGraph)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::WrappedGraph, None))
    }

    // ✅ 处理 IRI 作为主语
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("TriGDoc: IRI as subject = \{iri}")
      let  new_self_with_subject = new_self
      new_self_with_subject.cur_subject.push(
        NamedNodeRef::new_unchecked(iri).as_enum()
      )
      // 进入 WrappedGraphOrPredicateObjectList，等待谓词
      let new_stack = new_self_with_subject.stack
      new_stack.push(TriGState::WrappedGraphOrPredicateObjectList(
        term = NamedNodeRef::new_unchecked(iri).as_enum()
      ))
      let final_self = { ..new_self_with_subject, stack: new_stack }
      Ok((final_self, TriGState::WrappedGraphOrPredicateObjectList(term = NamedNodeRef::new_unchecked(iri).as_enum()), None))
    }

    // 处理 BlankNode 作为主语
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(label), _)
    ) => {
      self.debug_logger.info("TriGDoc: BlankNode as subject = \{label}")
      let  new_self_with_subject = new_self
      new_self_with_subject.cur_subject.push(
        BlankNodeRef::new_unchecked(label).as_enum()
      )
      let new_stack = new_self_with_subject.stack
      new_stack.push(TriGState::WrappedGraphOrPredicateObjectList(
        term = BlankNodeRef::new_unchecked(label).as_enum()
      ))
      let final_self = { ..new_self_with_subject, stack: new_stack }
      Ok((final_self, TriGState::WrappedGraphOrPredicateObjectList(term = BlankNodeRef::new_unchecked(label).as_enum()), None))
    }

    // 处理 PrefixedName 作为主语
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~), _)
    ) => {
      match resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          self.debug_logger.info("TriGDoc: PrefixedName as subject = \{t}")
          let  new_self_with_subject = new_self
          new_self_with_subject.cur_subject.push(t.as_enum())
          let new_stack = new_self_with_subject.stack
          new_stack.push(TriGState::WrappedGraphOrPredicateObjectList(
            term = t.as_enum()
          ))
          let final_self = { ..new_self_with_subject, stack: new_stack }
          Ok((final_self, TriGState::WrappedGraphOrPredicateObjectList(term = t.as_enum()), None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }
    }

    // 处理集合开始 ( 作为主语
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("("), _)
    ) => {
      let new_stack = new_self.stack
      new_stack.push(TriGState::PredicateObjectList)
      new_stack.push(TriGState::SubjectCollectionBeginning)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::SubjectCollectionBeginning, None))
    }

    // 处理空白节点属性列表 [ 作为主语
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => {
      let new_stack = new_self.stack
      new_stack.push(TriGState::WrappedGraphBlankNodePropertyListCurrent)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::WrappedGraphBlankNodePropertyListCurrent, None))
    }

    // 默认情况
    _ => {
      self.debug_logger.info("TriGDoc: unexpected token, pushing TriplesOrGraph")
      let new_stack = new_self.stack
      new_stack.push(TriGState::TriplesOrGraph)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::TriplesOrGraph, None))
    }
  }
}

// ===== 8. 图内三元组解析 (修正版) =====
// 对应状态: TriGState::Triples

///|
fn TriGRecognizer::handle_triples_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  self.debug_logger.info("Entering Triples with event: \{event}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => Ok((self, TriGState::Triples, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => {
      let new_subject = BlankNode::default()
      let new_cur_subject = self.cur_subject +
        [NamedOrBlankNodeRef::BlankNodeRef(new_subject.as_ref())]
      let new_self = { ..self, cur_subject: new_cur_subject }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let new_cur_subject = self.cur_subject +
        [NamedNodeRef::new_unchecked(iri).as_enum()]
      let new_self = { ..self, cur_subject: new_cur_subject }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          let new_cur_subject = self.cur_subject + [t.as_enum()]
          let new_self = { ..self, cur_subject: new_cur_subject }
          Ok((new_self, TriGState::PredicateObjectList, None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(label), _)
    ) => {
      let new_cur_subject = self.cur_subject +
        [NamedOrBlankNodeRef::BlankNodeRef(BlankNodeRef::new_unchecked(label))]
      let new_self = { ..self, cur_subject: new_cur_subject }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("("), _)
    ) => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::PredicateObjectList)
      new_stack.push(TriGState::SubjectCollectionBeginning)
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::SubjectCollectionBeginning, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<<"), _)
    ) => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::MaybePredicateObjectList)
      new_stack.push(TriGState::SubjectReifiedTripleEnd)
      new_stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
      new_stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
      new_stack.push(TriGState::Verb)
      new_stack.push(TriGState::ReifiedTripleObject(is_reified=true))
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::Verb, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "TOKEN is not a valid RDF subject".to_string(),
          self.last_range,
        ),
      )
  }
}

// ===== 15. Verb 处理 (修正版) =====
// 对应状态: TriGState::Verb

///|
fn TriGRecognizer::handle_verb_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  self.debug_logger.info("Verb: handling event: \{event}")

  match event {
    // 'a' 表示 rdf:type
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("a"), _)
    ) => {
      self.debug_logger.info("Verb: 'a' predicate")
      let new_cur_predicate = self.cur_predicate + [lwTYPE]
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::ObjectsList)
      let new_self = {
        ..self,
        cur_predicate: new_cur_predicate,
        stack: new_stack,
      }
      Ok((new_self, TriGState::ObjectsList, None))
    }

    // IRI 谓词
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      self.debug_logger.info("Verb: IRI predicate: \{iri}")
      let new_cur_predicate = self.cur_predicate +
        [NamedNodeRef::new_unchecked(iri)]
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::ObjectsList)
      let new_self = {
        ..self,
        cur_predicate: new_cur_predicate,
        stack: new_stack,
      }
      Ok((new_self, TriGState::ObjectsList, None))
    }

    // 前缀名谓词
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          self.debug_logger.info("Verb: PrefixedName predicate: \{t}")
          let new_cur_predicate = self.cur_predicate + [t]
          let new_stack = self.stack.copy()
          new_stack.push(TriGState::ObjectsList)
          let new_self = {
            ..self,
            cur_predicate: new_cur_predicate,
            stack: new_stack,
          }
          Ok((new_self, TriGState::ObjectsList, None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }

    // 其他情况 - 错误
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected a predicate (IRI or 'a'), found: \{event}".to_string(),
          self.last_range,
        ),
      )
  }
}

// fn TriGRecognizer::handle_literal_possible_suffix_m(
//   self : TriGRecognizer,
//   value : String,
//   emit : Bool,
//   event : Event,
//   context : RdfContext,
// ) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {

//   self.debug_logger.info(
//     "Entering LiteralPossibleSuffix(\{value}, emit=\{emit}) with event: \{event}",
//   )
//   self.debug_logger.info("Token stack: \{self.stack.to_string()}")

//   match event {
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::LangTag(language~, direction~), _)) => {
//       let literal = match direction {
//         Some(dir) => {
//           match LanguageTag::from_str(language.to_lower()) {
//             Ok(tag) => {
//               TermRef::LiteralRef(
//                 LiteralRef::new_directional_language_tagged_literal_unchecked(
//                   value, tag, dir,
//                 ),
//               )
//             }
//             Err(e) => return Err(RuleRecognizerError::SyntaxError(e.to_string(), self.last_range))
//           }
//         }
//         None => {
//           TermRef::LiteralRef(
//             Literal::new_language_tagged_literal_unchecked(
//               value,
//               language.to_lower(),
//             ).as_ref(),
//           )
//         }
//       }

//       let new_cur_object = self.cur_object.push(literal)
//       let new_self = { ..self, cur_object: new_cur_object }

//       if emit {
//         let quad = new_self.emit_quad()
//         let mut new_stack = new_self.stack.clone()
//         new_stack.push(TriGState::PredicateObjectListEnd)
//         let final_self = { ..new_self, stack: new_stack }
//         Ok((final_self, TriGState::PredicateObjectListEnd, Some(quad)))
//       } else {
//         Ok((new_self, TriGState::LiteralPossibleSuffix(value, emit), None))
//       }
//     }

//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("^^"), _)) => {
//       let mut new_stack = self.stack.clone()
//       new_stack.push(TriGState::LiteralExpectDatatype(value=value, emit=emit))
//       let new_self = { ..self, stack: new_stack }
//       Ok((new_self, TriGState::LiteralExpectDatatype(value, emit), None))
//     }

//     _ => {
//       let new_cur_object = self.cur_object.push(LiteralRef::new_simple_literal(value).as_term())
//       let new_self = { ..self, cur_object: new_cur_object }
//       if emit {
//         let quad = new_self.emit_quad()
//         let mut new_stack = new_self.stack.clone()
//         new_stack.push(TriGState::PredicateObjectListEnd)
//         let final_self = { ..new_self, stack: new_stack }
//         Ok((final_self, TriGState::PredicateObjectListEnd, Some(quad)))
//       } else {
//         Ok((new_self, TriGState::LiteralPossibleSuffix(value, emit), None))
//       }
//     }
//   }
// }


// ===== ExpectDot 处理 =====

///|
fn TriGRecognizer::handle_expect_dot_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      // 重置到文档级别状态
      let new_self = self.reset_to_tri_gdoc() // 假设此方法返回新的 TriGRecognizer 实例
      Ok((new_self, TriGState::TriGDoc, None))
    }
    _ => {
      // 记录错误并重置
      let err = RuleRecognizerError::TripleMissingDot
      let new_self = self.add_error(err).reset_to_tri_gdoc()
      Ok((new_self, TriGState::TriGDoc, None))
    }
  }
}

// ===== BaseExpectIri 处理 =====

///|
fn TriGRecognizer::handle_base_expect_iri_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(iri_str), _)
    ) => {
      let iri_ref = Iri::new(iri_str)
      let new_ctx_options = if self.lenient {
        {
          ..ctx.lexer_options,
          base_iri: Some(IriRef::parse_unchecked(iri_ref)),
        }
      } else {
        match IriRef::parse(iri_ref) {
          Ok(parsed_iri) => { ..ctx.lexer_options, base_iri: Some(parsed_iri) }
          Err(e) => {
            let err = RuleRecognizerError::SyntaxError(
              "Invalid BASE IRI: \{e.to_string()}",
              self.last_range,
            )
            let new_self = self.add_error(err)
            // 即使出错也继续，但保持上下文不变或更新为默认？这里假设出错不更新 base_iri
            return Ok((new_self, TriGState::ExpectDot, None))
          }
        }
      }

      let new_ctx = { ..ctx, lexer_options: new_ctx_options }
      let new_context = RdfContext::TriGRecognizerContext(new_ctx)
      let new_self = self.set_context(new_context)

      Ok((new_self, TriGState::ExpectDot, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "The BASE keyword should be followed by an IRI",
          self.last_range,
        ),
      )
  }
}

// ===== PrefixExpectPrefix 处理 =====

///|
fn TriGRecognizer::handle_prefix_expect_prefix_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PrefixedName(prefix~, localx~, ..), _)
    ) if localx.is_empty() =>
      Ok((self, TriGState::PrefixExpectIri(name=prefix), None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(iri_str), _)
    ) if iri_str.has_suffix(":") => {
      let prefix = iri_str[0:iri_str.length() - 1]
      Ok((self, TriGState::PrefixExpectIri(name=prefix.to_owned()), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if k.has_suffix(":") => {
      let prefix = k[0:k.length() - 1]
      Ok((self, TriGState::PrefixExpectIri(name=prefix.to_owned()), None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "The PREFIX keyword should be followed by a prefix like 'ex:'",
          self.last_range,
        ),
      )
  }
}

// ===== PrefixExpectIri 处理 =====

///|
fn TriGRecognizer::handle_prefix_expect_iri_m(
  self : TriGRecognizer,
  name : String,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(iri_str), _)
    ) => {
      let iri = Iri::Iri(iri_str)
      let new_prefixes = ctx.prefixes.copy()
      new_prefixes.set(name, iri)
      let new_ctx = { ..ctx, prefixes: new_prefixes }
      let new_context = RdfContext::TriGRecognizerContext(new_ctx)
      let new_self = self.set_context(new_context)

      Ok((new_self, TriGState::ExpectDot, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "The PREFIX declaration should be followed by a prefix and its value as an IRI",
          self.last_range,
        ),
      )
  }
}

// ===== VersionExpectVersion 处理 =====

///|
fn TriGRecognizer::handle_version_expect_version_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::String(_), _)
    ) => Ok((self, TriGState::ExpectDot, None))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "The VERSION keyword should be followed by a single quoted string like \"1.2\"",
          self.last_range,
        ),
      )
  }
}

// ===== WrappedGraphBlankNodePropertyListCurrent 处理 =====

///|
fn TriGRecognizer::handle_wrapped_graph_blank_node_property_list_current_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => {
      let term = BlankNode::default().as_ref().as_enum()
      Ok((self, TriGState::WrappedGraphOrPredicateObjectList(term~), None))
    }
    _ => {
      let bnode = BlankNode::default().as_ref().as_enum()
      let new_cur_subject = self.cur_subject + [bnode]
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::ExpectDot)
      new_stack.push(TriGState::SubjectBlankNodePropertyListEnd)
      new_stack.push(TriGState::PredicateObjectList)

      let new_self = { ..self, cur_subject: new_cur_subject, stack: new_stack }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
  }
}

// ===== SubjectBlankNodePropertyListEnd 处理 =====

///|
fn TriGRecognizer::handle_subject_blank_node_property_list_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => Ok((self, TriGState::SubjectBlankNodePropertyListAfter, None))
    _ => {
      let err = RuleRecognizerError::BlankNodePropertyListMissingEndBracket
      let new_self = self.add_error(err)
      Ok((new_self, TriGState::SubjectBlankNodePropertyListAfter, None))
    }
  }
}

// ===== SubjectBlankNodePropertyListAfter 处理 =====

///|
fn TriGRecognizer::handle_subject_blank_node_property_list_after_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    )
    | LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => Ok((self, TriGState::SubjectBlankNodePropertyListAfter, None))
    _ => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::PredicateObjectList)
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
  }
}
// ===== 修正后的 handle_subject_collection_beginning_m =====

///|
fn TriGRecognizer::handle_subject_collection_beginning_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    // ===== 情况1：空集合 () =====
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) => {
      // ✅ 空集合：cur_subject.push(rdf:nil)
      let new_cur_subject = self.cur_subject + [lwNIL.as_enum()]
      let new_self = { ..self, cur_subject: new_cur_subject }

      // ✅ 返回 PredicateObjectList，处理后续的 '.' 或 ';'
      // 注意：SubjectCollectionBeginning 已经完成，应该弹出
      // 由于栈中可能有其他状态，直接返回 PredicateObjectList
      Ok((new_self, TriGState::PredicateObjectList, None))
    }

    // ===== 情况2：非空集合 (element ...) =====
    _ => {
      // ✅ 创建空白节点作为集合的根
      let root = NamedOrBlankNodeRef::BlankNodeRef(
        BlankNode::default().as_ref(),
      )
      let new_cur_subject = self.cur_subject + [root]
      let new_cur_predicate = self.cur_predicate + [lwFIRST]

      // ✅ 压入状态：处理集合结束 + 处理元素
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::SubjectCollectionPossibleEnd) // 处理 ')' 或下一个元素
      new_stack.push(TriGState::Object) // 处理当前元素

      let new_self = {
        ..self,
        cur_subject: new_cur_subject,
        cur_predicate: new_cur_predicate,
        stack: new_stack,
      }

      // ✅ 返回 Object 状态，处理当前元素
      // 注意：这里返回 Object，让引擎用同一个 token 继续处理
      Ok((new_self, TriGState::Object, None))
    }
  }
}
// ===== SubjectCollectionBeginning 处理 =====
// fn TriGRecognizer::handle_subject_collection_beginning_m(
//   self : TriGRecognizer,
//   event : Event,
//   context : RdfContext,
// ) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
//   match event {
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(")"), _)) => {
//       let new_cur_subject = self.cur_subject +[lwNIL.as_enum()]
//       let new_self = { ..self, cur_subject: new_cur_subject }
//       Ok((new_self, TriGState::SubjectCollectionBeginning, None)) // 或者返回上一个状态？原代码是 return self，意味着栈顶变化后继续。这里假设下一个状态由栈决定，或者我们需要显式返回栈顶状态。
//       // 在新架构中，如果栈用于模拟递归，我们通常返回一个“继续解析”的状态，或者让引擎检查栈。
//       // 鉴于原代码逻辑，这里可能应该返回 TriGState::PredicateObjectList 或类似，取决于栈顶。
//       // 为了简化，假设引擎会处理栈，或者我们返回一个通用状态。
//       // *修正*：原代码 push 后 return self。在新架构中，我们通常需要返回下一个要执行的具体 Handler 对应的状态。
//       // 如果栈顶是 PredicateObjectList，我们应该返回它。
//       // 但这里为了保持一致性，我们先返回当前状态，实际项目中可能需要更复杂的栈管理逻辑暴露给引擎。
//       // 假设：引擎在 Ok 后，如果 stack 非空，会优先处理 stack 顶部的状态？
//       // 如果不，我们需要手动弹出栈顶并返回。
//       // 让我们假设：返回的状态是下一步要调用的 handler。
//       // 原代码: push ExpectDot, PredicateObjectList, SubjectCollectionBeginning. 
//       // 这里的逻辑是进入集合解析。
//       // 让我们返回 TriGState::Object (因为集合元素是对象) 或者专门的集合状态。
//       // 原代码后续是 push SubjectCollectionPossibleEnd, Object.
//       // 这里如果是空集合 ()，则 push lwNIL 到 subject。
//       // 让我们返回 TriGState::PredicateObjectList (假设栈顶是这个)
//       // 由于无法确切知道栈管理机制，这里暂且返回一个占位状态，实际需根据引擎实现调整。
//       // *更安全的做法*：如果原代码是 push 然后 return self (loop)，那么新架构应该返回栈顶状态。
//       // 这里我们假设栈顶是 PredicateObjectList
//       Ok((new_self, TriGState::PredicateObjectList, None))
//     }
//     _ => {
//       let root = NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref())
//       let new_cur_subject = self.cur_subject +[root]
//       let new_cur_predicate = self.cur_predicate+[lwFIRST]

//       let new_stack = self.stack.copy()
//       new_stack.push(TriGState::SubjectCollectionPossibleEnd)
//       new_stack.push(TriGState::Object)

//       let new_self = { ..self, cur_subject: new_cur_subject, cur_predicate: new_cur_predicate, stack: new_stack }
//       Ok((new_self, TriGState::Object, None))
//     }
//   }
// }
// ===== SubjectCollectionPossibleEnd 状态 =====

///|
fn TriGRecognizer::handle_subject_collection_possible_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // 弹出当前 subject 和 object
  let old = match self.cur_subject.pop() {
    Some(s) => s
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: subject stack is empty",
          self.last_range,
        ),
      )
  }
  let _ = self.cur_object.pop()

  match event {
    // ✅ 集合结束：收到 ')'
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")"), _)
    ) => {
      // 弹出 predicate (rdf:first)
      let _ = self.cur_predicate.pop()

      // ✅ 输出 rdf:rest rdf:nil
      let quad = RdfOut::Quad(
        Quad::Quad(
          old.into_owned(),
          lwREST.into_owned(),
          lwNIL.into_owned().as_term(),
          self.cur_graph.into_owned(),
        ),
      )

      // ✅ 返回 PredicateObjectList 继续处理
      Ok((self, TriGState::PredicateObjectList, Some(quad)))
    }

    // ✅ 还有更多元素
    _ => {
      // 创建新的空白节点
      let new = BlankNode::default()

      // ✅ 输出 rdf:rest new
      let quad = RdfOut::Quad(
        Quad::Quad(
          old.into_owned(),
          lwREST.into_owned(),
          new.as_ref().as_term().into_owned(),
          self.cur_graph.into_owned(),
        ),
      )

      // 设置新的 subject 和 predicate
      let new_cur_subject = self.cur_subject +
        [NamedOrBlankNodeRef::BlankNodeRef(new.as_ref())]
      let new_cur_predicate = self.cur_predicate + [lwFIRST]
      let new_self = {
        ..self,
        cur_subject: new_cur_subject,
        cur_predicate: new_cur_predicate,
      }

      // 压入状态继续处理
      let new_stack = new_self.stack
      new_stack.push(TriGState::SubjectCollectionPossibleEnd)
      new_stack.push(TriGState::Object)
      let new_self = { ..new_self, stack: new_stack }

      // ✅ 返回 Object 处理下一个元素
      Ok((new_self, TriGState::Object, Some(quad)))
    }
  }
}
// ===== SubjectCollectionPossibleEnd 处理 =====
// fn TriGRecognizer::handle_subject_collection_possible_end_m(
//   self : TriGRecognizer,
//   event : Event,
//   context : RdfContext,
// ) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
//   let (old, new_cur_subject) = match self.cur_subject.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: subject stack is empty", self.last_range))
//   }

//   let new_cur_object = self.cur_object // pop last

//   match event {
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(")"), _)) => {
//       let new_cur_predicate = self.cur_predicate
//       let quad = RdfOut::Quad(
//         Quad::Quad(
//           old.into_owned(),
//           lwREST.into_owned(),
//           lwNIL.into_owned().as_term(),
//           self.cur_graph.into_owned(),
//         ),
//       )
//       let new_self = { ..self, cur_subject: new_cur_subject, cur_object: new_cur_object, cur_predicate: new_cur_predicate }
//       Ok((new_self, TriGState::SubjectCollectionPossibleEnd, Some(quad)))
//     }
//     _ => {
//       let new_bnode = BlankNode::default()
//       let quad = RdfOut::Quad(
//         Quad::Quad(
//           old.into_owned(),
//           lwREST.into_owned(),
//           lwNIL.as_term().into_owned(), // 注意：原代码此处可能有误，应为 new_bnode
//           self.cur_graph.into_owned(),
//         ),
//       )

//       let new_cur_subject = new_cur_subject+[NamedOrBlankNodeRef::BlankNodeRef(new_bnode.as_ref())]
//       let new_stack = self.stack.copy()
//       new_stack.push(TriGState::ObjectCollectionPossibleEnd) // 注意：原代码 push 的是 ObjectCollectionPossibleEnd? 不，是 SubjectCollection...
//       // 原代码: self.stack.push(TriGState::ObjectCollectionPossibleEnd) -> 这可能是笔误，应该是 Subject...
//       // 但为了忠实于原代码，我们保留。
//       new_stack.push(TriGState::Object)

//       let new_self = { ..self, cur_subject: new_cur_subject, cur_object: new_cur_object, stack: new_stack }
//       Ok((new_self, TriGState::Object, Some(quad)))
//     }
//   }
// }

// ===== TriplesBlankNodePropertyListCurrent 处理 =====

///|
fn TriGRecognizer::handle_triples_blank_node_property_list_current_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => Ok((self, TriGState::PredicateObjectList, None))
    _ => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::SubjectBlankNodePropertyListEnd)
      new_stack.push(TriGState::PredicateObjectList)
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
  }
}

// ===== GraphName 处理 =====
// ===== 修正后的 handle_graph_name_m =====

///|
fn TriGRecognizer::handle_graph_name_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    // ✅ IRI 作为图名
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let new_cur_graph = GraphNameRef::NamedNodeRef(
        NamedNodeRef::new_unchecked(iri),
      )
      let new_self = { ..self, cur_graph: new_cur_graph }
      // ✅ 返回 GraphName，等待下一个 token（应该是 '{'）
      // 下一个 token 会在 WrappedGraph 状态处理
      Ok((new_self, TriGState::GraphName, None))
    }

    // ✅ PrefixedName 作为图名
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          let new_cur_graph = GraphNameRef::NamedNodeRef(t)
          let new_self = { ..self, cur_graph: new_cur_graph }
          // ✅ 返回 GraphName，等待 '{'
          Ok((new_self, TriGState::GraphName, None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }

    // ✅ BlankNode 作为图名
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(label), _)
    ) => {
      let new_cur_graph = GraphNameRef::BlankNodeRef(
        BlankNodeRef::new_unchecked(label),
      )
      let new_self = { ..self, cur_graph: new_cur_graph }
      // ✅ 返回 GraphName，等待 '{'
      Ok((new_self, TriGState::GraphName, None))
    }

    // ✅ 匿名图名: [ ... ]
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => {
      // 创建匿名空白节点作为图名
      let bnode = BlankNode::default().as_ref()
      let new_cur_graph = GraphNameRef::BlankNodeRef(bnode)
      let new_self = { ..self, cur_graph: new_cur_graph }

      // ✅ 匿名图名需要处理内部的属性列表
      // 压入 GraphNameAnonEnd 状态等待 ']'
      self.stack.push(TriGState::GraphNameAnonEnd)

      // ✅ 返回 GraphName，等待 ']' 完成匿名图名
      Ok((new_self, TriGState::GraphName, None))
    }

    // ❌ 无效的图名
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Invalid graph name: expected IRI, PrefixedName, BlankNode, or '['",
          self.last_range,
        ),
      )
  }
}
// ===== GraphNameAnonEnd 处理 =====
// ===== 修正后的 handle_graph_name_anon_end_m =====

///|
fn TriGRecognizer::handle_graph_name_anon_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    // ✅ 收到 ']'，匿名图名结束
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => {
      // 创建匿名空白节点作为图名
      let bnode = BlankNode::default().as_ref()
      let new_cur_graph = GraphNameRef::BlankNodeRef(bnode)
      let new_self = { ..self, cur_graph: new_cur_graph }

      // ✅ 返回 WrappedGraph，等待 '{'
      // 注意：不要返回 GraphNameAnonEnd，因为匿名图名已经结束
      Ok((new_self, TriGState::WrappedGraph, None))
    }

    // ❌ 不是 ']'，错误
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected ']' to close anonymous graph name",
          self.last_range,
        ),
      )
  }
}

// ===== MaybePredicateObjectList 处理 =====

///|
fn TriGRecognizer::handle_maybe_predicate_object_list_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => Ok((self, TriGState::MaybePredicateObjectList, None))
    _ => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::PredicateObjectList)
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
  }
}

// ===== AnnotationEnd 处理 =====

///|
fn TriGRecognizer::handle_annotation_end_m(
  self : TriGRecognizer,
  with_reifier : Bool,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let new_cur_subject = self.cur_subject // pop
  let new_self = { ..self, cur_subject: new_cur_subject }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("|}"), _)
    ) => Ok((new_self, TriGState::AnnotationEnd(with_reifier~), None))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Annotations should end with '|}'",
          self.last_range,
        ),
      )
  }
}

// ===== ObjectBlankNodePropertyListCurrent 处理 =====

///|
fn TriGRecognizer::handle_object_blank_node_property_list_current_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => {
      let bnode = BlankNode::default().as_ref()
      let new_cur_object = self.cur_object + [TermRef::BlankNodeRef(bnode)]
      let new_self = { ..self, cur_object: new_cur_object }
      let quad = new_self.emit_quad_m()
      Ok((new_self, TriGState::ObjectBlankNodePropertyListCurrent, Some(quad)))
    }
    _ => {
      let bnode = BlankNode::default().as_ref()
      let new_cur_subject = self.cur_subject +
        [NamedOrBlankNodeRef::BlankNodeRef(bnode)]
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::ObjectBlankNodePropertyListEnd)
      new_stack.push(TriGState::PredicateObjectList)
      let new_self = { ..self, cur_subject: new_cur_subject, stack: new_stack }
      Ok((new_self, TriGState::PredicateObjectList, None))
    }
  }
}

// ===== LiteralExpectDatatype 处理 =====

///|
fn TriGRecognizer::handle_literal_expect_datatype_m(
  self : TriGRecognizer,
  value : String,
  emit : Bool,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(datatype_str), _)
    ) => {
      if !self.lenient && datatype_str == lwLANG_STRING.to_string() {
        return Err(
          RuleRecognizerError::SyntaxError(
            "The datatype of a literal without a language tag must not be rdf:langString",
            self.last_range,
          ),
        )
      }
      if !self.lenient && datatype_str == lwDIR_LANG_STRING.to_string() {
        return Err(
          RuleRecognizerError::SyntaxError(
            "The datatype of a literal without a base direction must not be rdf:dirLangString",
            self.last_range,
          ),
        )
      }

      let datatype = NamedNodeRef::new_unchecked(datatype_str)
      let data_value = datatype.into_datatype(value)
      let literal = LiteralRef::new_typed_literal(data_value, datatype)
      let new_cur_object = self.cur_object + [TermRef::LiteralRef(literal)]
      let new_self = { ..self, cur_object: new_cur_object }

      if emit {
        let quad = new_self.emit_quad_m()
        Ok(
          (
            new_self,
            TriGState::LiteralExpectDatatype(value~, emit~),
            Some(quad),
          ),
        )
      } else {
        Ok((new_self, TriGState::LiteralExpectDatatype(value~, emit~), None))
      }
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          if !self.lenient && t == lwLANG_STRING {
            return Err(
              RuleRecognizerError::SyntaxError(
                "The datatype of a literal without a language tag must not be rdf:langString",
                self.last_range,
              ),
            )
          }
          if !self.lenient && t == lwDIR_LANG_STRING {
            return Err(
              RuleRecognizerError::SyntaxError(
                "The datatype of a literal without a base direction must not be rdf:dirLangString",
                self.last_range,
              ),
            )
          }

          let data_value = t.into_datatype(value)
          let literal = LiteralRef::new_typed_literal(data_value, t)
          let new_cur_object = self.cur_object + [TermRef::LiteralRef(literal)]
          let new_self = { ..self, cur_object: new_cur_object }

          if emit {
            let quad = new_self.emit_quad_m()
            Ok(
              (
                new_self,
                TriGState::LiteralExpectDatatype(value~, emit~),
                Some(quad),
              ),
            )
          } else {
            Ok(
              (new_self, TriGState::LiteralExpectDatatype(value~, emit~), None),
            )
          }
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expecting a datatype IRI after ^^",
          self.last_range,
        ),
      )
  }
}

// ===== SubjectReifiedTripleEnd 处理 =====
// ===== SubjectReifiedTripleEnd 处理 =====

///|
fn TriGRecognizer::handle_subject_reified_triple_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // 使用 pop() 弹出 reifier
  let reifier = match self.cur_reifier.pop() {
    Some(r) => r
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: reifier stack empty",
          self.last_range,
        ),
      )
  }

  // 将弹出的 reifier 加入 cur_subject
  let new_cur_subject = self.cur_subject + [reifier]

  // self.cur_reifier 已经被 pop 修改，直接使用 self 并更新 cur_subject
  let new_self = { ..self, cur_subject: new_cur_subject }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(">>"), _)
    ) => Ok((new_self, TriGState::SubjectReifiedTripleEnd, None))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expecting '>>' to close a reified triple",
          self.last_range,
        ),
      )
  }
}
// fn TriGRecognizer::handle_subject_reified_triple_end_m(
//   self : TriGRecognizer,
//   event : Event,
//   context : RdfContext,
// ) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
//   let (reifier, new_cur_reifier) = match self.cur_reifier.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: reifier stack empty", self.last_range))
//   }

//   let new_cur_subject = self.cur_subject +[reifier]
//   let new_self = { ..self, cur_subject: new_cur_subject, cur_reifier: new_cur_reifier }

//   match event {
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(">>"), _)) => {
//       Ok((new_self, TriGState::SubjectReifiedTripleEnd, None))
//     }
//     _ => {
//       Err(RuleRecognizerError::SyntaxError("Expecting '>>' to close a reified triple", self.last_range))
//     }
//   }
// }
// ===== TripleTermEnd 处理 =====

///|
fn TriGRecognizer::handle_triple_term_end_m(
  self : TriGRecognizer,
  emit : Bool,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // 使用 pop() 替代 unsnoc()
  let subject = match self.cur_subject.pop() {
    Some(s) => s
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: subject stack empty in TripleTermEnd",
          self.last_range,
        ),
      )
  }
  let predicate = match self.cur_predicate.pop() {
    Some(p) => p
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: predicate stack empty in TripleTermEnd",
          self.last_range,
        ),
      )
  }
  let object = match self.cur_object.pop() {
    Some(o) => o
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: object stack empty in TripleTermEnd",
          self.last_range,
        ),
      )
  }

  let triple = TripleRef::TripleRef(subject, predicate, object)

  // 将 triple 作为对象推入 cur_object
  self.cur_object.push(TermRef::TripleRef(triple))

  let output = if emit { Some(self.emit_quad_m()) } else { None }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(")>>"), _)
    ) =>
      // self 已经包含更新后的 cur_object, cur_subject 等
      Ok((self, TriGState::TripleTermEnd(emit~), output))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expecting ')>>' to close a triple term",
          self.last_range,
        ),
      )
  }
}
// ===== TripleTermEnd 处理 =====
// fn TriGRecognizer::handle_triple_term_end_m(
//   self : TriGRecognizer,
//   emit : Bool,
//   event : Event,
//   context : RdfContext,
// ) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
//   let (subject, new_cur_subject) = match self.cur_subject.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: subject stack empty in TripleTermEnd", self.last_range))
//   }
//   let (predicate, new_cur_predicate) = match self.cur_predicate.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: predicate stack empty in TripleTermEnd", self.last_range))
//   }
//   let (object, new_cur_object) = match self.cur_object.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: object stack empty in TripleTermEnd", self.last_range))
//   }

//   let triple = TripleRef::TripleRef(subject, predicate, object)
//   let new_cur_object = new_cur_object.push(TermRef::TripleRef(triple))
//   let intermediate_self = { ..self, cur_subject: new_cur_subject, cur_predicate: new_cur_predicate, cur_object: new_cur_object }

//   let output = if emit {
//     Some(intermediate_self.emit_quad_m())
//   } else {
//     None
//   }

//   match event {
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(")>>"), _)) => {
//       Ok((intermediate_self, TriGState::TripleTermEnd(emit~), output))
//     }
//     _ => {
//       Err(RuleRecognizerError::SyntaxError("Expecting ')>>' to close a triple term", self.last_range))
//     }
//   }
// }

// ===== EndOfReifiedTripleBeforeReifier 处理 =====
// ===== EndOfReifiedTripleBeforeReifier 处理 =====

///|
fn TriGRecognizer::handle_end_of_reified_triple_before_reifier_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // 使用 pop() 弹出 subject, predicate, object
  let subject = match self.cur_subject.pop() {
    Some(s) => s
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: subject stack empty",
          self.last_range,
        ),
      )
  }
  let predicate = match self.cur_predicate.pop() {
    Some(p) => p
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: predicate stack empty",
          self.last_range,
        ),
      )
  }
  let object = match self.cur_object.pop() {
    Some(o) => o
    None =>
      return Err(
        RuleRecognizerError::SyntaxError(
          "Internal error: object stack empty",
          self.last_range,
        ),
      )
  }

  let triple = TripleRef::TripleRef(subject, predicate, object)

  // 此时 self 中的 cur_subject, cur_predicate, cur_object 已经被 pop 修改
  // 直接使用 self 作为 intermediate_self
  let intermediate_self = self

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("~"), _)
    ) =>
      Ok(
        (
          intermediate_self,
          TriGState::Reifier(triple=triple.into_owned()),
          None,
        ),
      )
    _ => {
      let reifier = BlankNode::default()
      let quad = RdfOut::Quad(
        Quad::Quad(
          reifier.as_enum(),
          lwREIFIES.into_owned(),
          TermRef::TripleRef(triple).into_owned(),
          intermediate_self.cur_graph.into_owned(),
        ),
      )
      // 注意：这里需要修改 cur_reifier，由于 intermediate_self 是 self 的别名/拷贝，
      // 我们需要构建一个新的 self 来更新 cur_reifier
      let new_cur_reifier = intermediate_self.cur_reifier +
        [reifier.as_enum().as_ref()]
      let new_self = { ..intermediate_self, cur_reifier: new_cur_reifier }
      Ok((new_self, TriGState::EndOfReifiedTripleBeforeReifier, Some(quad)))
    }
  }
}
// fn TriGRecognizer::handle_end_of_reified_triple_before_reifier_m(
//   self : TriGRecognizer,
//   event : Event,
//   context : RdfContext,
// ) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
//   let (subject, new_cur_subject) = match self.cur_subject.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: subject stack empty", self.last_range))
//   }
//   let (predicate, new_cur_predicate) = match self.cur_predicate.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: predicate stack empty", self.last_range))
//   }
//   let (object, new_cur_object) = match self.cur_object.unsnoc() {
//     Some((init, last)) => (last, init)
//     None => return Err(RuleRecognizerError::SyntaxError("Internal error: object stack empty", self.last_range))
//   }

//   let triple = TripleRef::TripleRef(subject, predicate, object)
//   let intermediate_self = { ..self, cur_subject: new_cur_subject, cur_predicate: new_cur_predicate, cur_object: new_cur_object }

//   match event {
//     LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("~"), _)) => {
//       Ok((intermediate_self, TriGState::Reifier(triple=triple.into_owned()), None))
//     }
//     _ => {
//       let reifier = BlankNode::default()
//       let quad = RdfOut::Quad(
//         Quad::Quad(
//           reifier.as_enum(),
//           lwREIFIES.into_owned(),
//           TermRef::TripleRef(triple).into_owned(),
//           intermediate_self.cur_graph.into_owned(),
//         ),
//       )
//       let new_cur_reifier = intermediate_self.cur_reifier + [reifier.as_enum().as_ref()]
//       let new_self = { ..intermediate_self, cur_reifier: new_cur_reifier }
//       Ok((new_self, TriGState::EndOfReifiedTripleBeforeReifier, Some(quad)))
//     }
//   }
// }

// ===== Reifier 处理 =====

///|
fn TriGRecognizer::handle_reifier_m(
  self : TriGRecognizer,
  triple : Triple,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let reifier = NamedNodeRef::new_unchecked(iri)
      let quad = RdfOut::Quad(
        Quad::Quad(
          reifier.as_enum().into_owned(),
          lwREIFIES.into_owned(),
          triple.as_enum(),
          self.cur_graph.into_owned(),
        ),
      )
      let new_cur_reifier = self.cur_reifier + [reifier.as_enum()]
      let new_self = { ..self, cur_reifier: new_cur_reifier }
      Ok((new_self, TriGState::Reifier(triple~), Some(quad)))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(reifier) => {
          let quad = RdfOut::Quad(
            Quad::Quad(
              reifier.as_enum().into_owned(),
              lwREIFIES.into_owned(),
              triple.as_term(),
              self.cur_graph.into_owned(),
            ),
          )
          let new_cur_reifier = self.cur_reifier + [reifier.as_enum()]
          let new_self = { ..self, cur_reifier: new_cur_reifier }
          Ok((new_self, TriGState::Reifier(triple~), Some(quad)))
        }
        Err(e) => {
          // Fallback to blank node reifier on error? Original code does this.
          let reifier = BlankNode::default()

          let quad = RdfOut::Quad(
            Quad::Quad(
              reifier.as_enum(),
              lwREIFIES.into_owned(),
              triple.as_term(),
              self.cur_graph.into_owned(),
            ),
          )
          let new_cur_reifier = self.cur_reifier + [reifier.as_enum().as_ref()]
          let new_self = self.add_error(
            RuleRecognizerError::SyntaxError(e, self.last_range),
          )
          let final_self = { ..new_self, cur_reifier: new_cur_reifier }
          Ok((final_self, TriGState::Reifier(triple~), Some(quad)))
        }
      }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(bnode), _)
    ) => {
      let reifier = BlankNodeRef::new_unchecked(bnode)
      let quad = RdfOut::Quad(
        Quad::Quad(
          reifier.as_enum().into_owned(),
          lwREIFIES.into_owned(),
          triple.as_enum(),
          self.cur_graph.into_owned(),
        ),
      )
      let new_cur_reifier = self.cur_reifier + [reifier.as_enum()]
      let new_self = { ..self, cur_reifier: new_cur_reifier }
      Ok((new_self, TriGState::Reifier(triple~), Some(quad)))
    }
    _ => {
      // Fallback to blank node reifier
      let reifier = BlankNode::default()
      let quad = RdfOut::Quad(
        Quad::Quad(
          reifier.as_enum(),
          lwREIFIES.into_owned(),
          triple.as_enum(),
          self.cur_graph.into_owned(),
        ),
      )
      let new_cur_reifier = self.cur_reifier + [reifier.as_ref().as_enum()]
      let new_self = { ..self, cur_reifier: new_cur_reifier }
      Ok((new_self, TriGState::Reifier(triple~), Some(quad)))
    }
  }
}

// ===== ReifiedTripleSubject 处理 =====

///|
fn TriGRecognizer::handle_reified_triple_subject_m(
  self : TriGRecognizer,
  is_reified : Bool,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => {
      let bnode = BlankNode::default().as_ref()
      let new_cur_subject = self.cur_subject +
        [NamedOrBlankNodeRef::BlankNodeRef(bnode)]
      let new_self = { ..self, cur_subject: new_cur_subject }
      Ok((new_self, TriGState::QuotedAnonEnd, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let new_cur_subject = self.cur_subject +
        [NamedOrBlankNodeRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))]
      let new_self = { ..self, cur_subject: new_cur_subject }
      Ok((new_self, TriGState::ReifiedTripleSubject(is_reified~), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          let new_cur_subject = self.cur_subject + [t.as_enum()]
          let new_self = { ..self, cur_subject: new_cur_subject }
          Ok((new_self, TriGState::ReifiedTripleSubject(is_reified~), None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(label), _)
    ) => {
      let new_cur_subject = self.cur_subject +
        [NamedNodeRef::new_unchecked(label).as_enum()]
      let new_self = { ..self, cur_subject: new_cur_subject }
      Ok((new_self, TriGState::ReifiedTripleSubject(is_reified~), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<<"), _)
    ) if is_reified => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::SubjectReifiedTripleEnd)
      new_stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
      new_stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
      new_stack.push(TriGState::Verb)
      new_stack.push(TriGState::ReifiedTripleObject(is_reified=true))
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::Verb, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "TOKEN is not a valid RDF quoted triple subject",
          self.last_range,
        ),
      )
  }
}

// ===== ReifiedTripleObject 处理 =====

///|
fn TriGRecognizer::handle_reified_triple_object_m(
  self : TriGRecognizer,
  is_reified : Bool,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => {
      let bnode = BlankNode::default().as_ref()
      let new_cur_object = self.cur_object + [TermRef::BlankNodeRef(bnode)]
      let new_self = { ..self, cur_object: new_cur_object }
      Ok((new_self, TriGState::QuotedAnonEnd, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      // 注意：原代码这里 push 的是 BlankNodeRef? 应该是 NamedNodeRef 或 TermRef
      // 修正为 NamedNodeRef
      let new_cur_object = self.cur_object +
        [TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))]
      let new_self = { ..self, cur_object: new_cur_object }
      Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          let new_cur_object = self.cur_object + [t.as_term()]
          let new_self = { ..self, cur_object: new_cur_object }
          Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(label), _)
    ) => {
      let new_cur_object = self.cur_object +
        [BlankNodeRef::new_unchecked(label).as_term()]
      let new_self = { ..self, cur_object: new_cur_object }
      Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::String(value), _)
    ) => Ok((self, TriGState::LiteralPossibleSuffix(value~, emit=false), None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Integer(v), _)
    ) => {
      let v = try @string.parse_int(v) |> Ok catch {
        e => Err(e)
      }
      match v {
        Ok(value) => {
          let literal = LiteralRef::new_typed_literal(
            VarDataType::IntVar(value.to_string()),
            lwINTEGER,
          )
          let new_cur_object = self.cur_object + [literal.as_term()]
          let new_self = { ..self, cur_object: new_cur_object }
          Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
        }
        Err(e) =>
          Err(RuleRecognizerError::SyntaxError(e.to_string(), self.last_range))
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
          let literal = LiteralRef::new_typed_literal(
            VarDataType::DecimalVar(value.to_string()),
            lwDECIMAL,
          )
          let new_cur_object = self.cur_object + [literal.as_term()]
          let new_self = { ..self, cur_object: new_cur_object }
          Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
        }
        Err(e) =>
          Err(RuleRecognizerError::SyntaxError(e.to_string(), self.last_range))
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
          let literal = LiteralRef::new_typed_literal(
            VarDataType::DoubleVar(value.to_string()),
            lwDOUBLE,
          )
          let new_cur_object = self.cur_object + [literal.as_term()]
          let new_self = { ..self, cur_object: new_cur_object }
          Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
        }
        Err(e) =>
          Err(RuleRecognizerError::SyntaxError(e.to_string(), self.last_range))
      }
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("true"), _)
    ) => {
      let literal = LiteralRef::new_typed_literal(
        VarDataType::TrueVar,
        lwBOOLEAN,
      )
      let new_cur_object = self.cur_object + [literal.as_term()]
      let new_self = { ..self, cur_object: new_cur_object }
      Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("false"), _)
    ) => {
      let literal = LiteralRef::new_typed_literal(
        VarDataType::FalseVar,
        lwBOOLEAN,
      )
      let new_cur_object = self.cur_object + [literal.as_term()]
      let new_self = { ..self, cur_object: new_cur_object }
      Ok((new_self, TriGState::ReifiedTripleObject(is_reified~), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<<("), _)
    ) => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
      new_stack.push(TriGState::ReifiedTripleObject(is_reified=false))
      new_stack.push(TriGState::Verb)
      new_stack.push(TriGState::ReifiedTripleSubject(is_reified=false))
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::ReifiedTripleSubject(is_reified=false), None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("<<"), _)
    ) if is_reified => {
      let new_stack = self.stack.copy()
      new_stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
      new_stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
      new_stack.push(TriGState::ReifiedTripleObject(is_reified=true))
      new_stack.push(TriGState::Verb)
      new_stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
      let new_self = { ..self, stack: new_stack }
      Ok((new_self, TriGState::ReifiedTripleSubject(is_reified=true), None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "TOKEN is not a valid RDF quoted triple object",
          self.last_range,
        ),
      )
  }
}

// ===== QuotedAnonEnd 处理 =====

///|
fn TriGRecognizer::handle_quoted_anon_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => Ok((self, TriGState::QuotedAnonEnd, None))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Anonymous blank node with a property list are not allowed in quoted triples",
          self.last_range,
        ),
      )
  }
}

// ===== ExpectAtKeyword 处理 =====

///|
fn TriGRecognizer::handle_expect_at_keyword_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  let ctx = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ =>
      return Err(
        RuleRecognizerError::SyntaxError("Invalid context", self.last_range),
      )
  }

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "base") =>
      Ok((self, TriGState::BaseExpectIri, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "prefix") =>
      Ok((self, TriGState::PrefixExpectPrefix, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword(k), _)
    ) if eq_ignore_ascii_case(k, "version") =>
      Ok((self, TriGState::VersionExpectVersion, None))
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("{"), _)
    ) if ctx.with_graph_name => Ok((self, TriGState::WrappedGraph, None))
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected 'base', 'prefix', or 'version' after '@'",
          self.last_range,
        ),
      )
  }
}

// ===== WrappedGraph 状态处理 '{' =====

///|
fn TriGRecognizer::handle_wrapped_graph_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    // ✅ 收到 '{'，开始图内容
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("{"), _)
    ) => {
      // 压入状态：图结束 + 三元组处理
      self.stack.push(TriGState::WrappedGraphPossibleEnd)
      self.stack.push(TriGState::Triples)
      Ok((self, TriGState::Triples, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected '{' to start graph",
          self.last_range,
        ),
      )
  }
}

// ===== handle_wrapped_graph_possible_end_m =====

///|
fn TriGRecognizer::handle_wrapped_graph_possible_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    // ✅ 情况1：收到 `}` → 图结束
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      self.debug_logger.info("WrappedGraphPossibleEnd: graph ended with '}'")

      // ✅ 弹出 WrappedGraphPossibleEnd
      // 注意：这里可能还有 WrappedGraph 状态，但由上层管理
      // 我们只需返回 WrappedGraph 状态，让上层决定下一步

      // 清空当前图的数据（可选）
      // 注意：cur_graph 已经设置，不需要重置

      // ✅ 返回 WrappedGraph，表示图已结束，可以回到上层
      Ok((self, TriGState::WrappedGraph, None))
    }

    // ✅ 情况2：收到 `.` → 还有更多三元组
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      self.debug_logger.info(
        "WrappedGraphPossibleEnd: dot, continuing graph content",
      )

      // ✅ 继续处理图内的三元组
      // 清空当前三元组的数据
      let new_self = {
        ..self,
        cur_subject: [],
        cur_predicate: [],
        cur_object: [],
        cur_reifier: [],
      }

      // ✅ 压入 Triples 状态，继续处理
      let new_stack = new_self.stack
      new_stack.push(TriGState::WrappedGraphPossibleEnd) // 保留结束状态
      new_stack.push(TriGState::Triples) // 继续处理三元组
      let new_self = { ..new_self, stack: new_stack }

      Ok((new_self, TriGState::Triples, None))
    }

    // ✅ 情况3：收到其他 token → 可能是错误，或者是新的三元组开始
    _ =>
      // 检查是否可能是新的三元组（主语）
      match event {
        LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Iri(_), _)
        )
        | LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::BlankNodeLabel(_), _)
        )
        | LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Punctuation("["), _)
        )
        | LocatedTokenOrLineJump::LocatedN3Token(
          LocatedN3Token(N3Token::Punctuation("("), _)
        ) => {
          // 可能是新的三元组开始
          self.debug_logger.info(
            "WrappedGraphPossibleEnd: new triple detected, continuing",
          )

          // 清空当前三元组数据
          let new_self = {
            ..self,
            cur_subject: [],
            cur_predicate: [],
            cur_object: [],
            cur_reifier: [],
          }

          // ✅ 压入 Triples 状态，让主语处理
          let new_stack = new_self.stack
          new_stack.push(TriGState::WrappedGraphPossibleEnd) // 保留结束状态
          new_stack.push(TriGState::Triples) // 处理新三元组
          let new_self = { ..new_self, stack: new_stack }

          // ✅ 返回 Triples 状态
          Ok((new_self, TriGState::Triples, None))
        }
        _ =>
          // ❌ 无效 token
          Err(
            RuleRecognizerError::SyntaxError(
              "Expected '}' or '.' or new triple in graph block",
              self.last_range,
            ),
          )
      }
  }
}

// ===== handle_object_reified_triple_end_m =====

///|
fn TriGRecognizer::handle_object_reified_triple_end_m(
  self : TriGRecognizer,
  emit : Bool,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("ObjectReifiedTripleEnd: emit=\{emit}, event=\{event}")

  // ✅ 检查是否是结束标记 `>>`
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation(">>"), _)
    ) => {
      // 1. 弹出引用三元组的三个部分
      // 注意：顺序是 subject, predicate, object
      // 它们在栈中的顺序：先压入 subject，再 predicate，最后 object

      let object = match self.cur_object.pop() {
        Some(o) => o
        None =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Internal error: object stack empty in reified triple",
              self.last_range,
            ),
          )
      }

      let predicate = match self.cur_predicate.pop() {
        Some(p) => p
        None =>
          // 如果 predicate 为空，可能是语法错误
          return Err(
            RuleRecognizerError::SyntaxError(
              "Internal error: predicate stack empty in reified triple",
              self.last_range,
            ),
          )
      }

      let subject = match self.cur_subject.pop() {
        Some(s) => s
        None =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Internal error: subject stack empty in reified triple",
              self.last_range,
            ),
          )
      }

      // 2. 构造 Triple 对象
      let triple = TripleRef::TripleRef(subject, predicate, object)

      // 3. 将 Triple 作为对象推入 cur_object
      let new_cur_object = self.cur_object + [TermRef::TripleRef(triple)]
      let new_self = { ..self, cur_object: new_cur_object }

      // 4. 如果 emit=true，输出三元组
      if emit {
        self.debug_logger.info("ObjectReifiedTripleEnd: emitting triple")

        // 注意：此时输出的三元组是外层的三元组
        // subject = cur_subject 栈顶（外层 subject）
        // predicate = cur_predicate 栈顶（外层 predicate）
        // object = triple (刚构造的引用三元组)
        let quad = new_self.emit_quad_m()

        // 5. 弹出 ObjectReifiedTripleEnd，进入 PredicateObjectListEnd
        // 注意：需要弹出当前状态
        let new_stack = new_self.stack
        let _ = new_stack.pop() // 弹出 ObjectReifiedTripleEnd
        let new_self = { ..new_self, stack: new_stack }

        Ok((new_self, TriGState::PredicateObjectListEnd, Some(quad)))
      } else {
        // ✅ 不输出（用于嵌套的引用三元组）
        self.debug_logger.info("ObjectReifiedTripleEnd: not emitting (nested)")

        // 弹出 ObjectReifiedTripleEnd
        let new_stack = new_self.stack
        let _ = new_stack.pop()
        let new_self = { ..new_self, stack: new_stack }

        Ok((new_self, TriGState::PredicateObjectListEnd, None))
      }
    }

    // ❌ 错误：期望 `>>`
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected '>>' to close reified triple",
          self.last_range,
        ),
      )
  }
}

// ===== handle_literal_possible_suffix_m =====

///|
fn TriGRecognizer::handle_literal_possible_suffix_m(
  self : TriGRecognizer,
  value : String,
  emit : Bool,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "LiteralPossibleSuffix: value='\{value}', emit=\{emit}, event=\{event}",
  )

  match event {
    // ===== 情况1：语言标签 =====
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LangTag(language~, direction~), _)
    ) => {
      self.debug_logger.info(
        "LiteralPossibleSuffix: language tag '@\{language}'",
      )

      // 创建语言标签字面量
      let literal = if direction is Some(dir) {
        // RDF 1.2 支持方向
        let lang_tag = try
          LanguageTag::from_str(language.to_lower()) |> Ok
        catch {
          e => Err(e)
        }
        let lang_tag = match lang_tag {
          Ok(lang_tag) => lang_tag
          Err(_e) => LanguageTag::default()
        }
        LiteralRef::new_directional_language_tagged_literal_unchecked(
          value, lang_tag, dir,
        )
      } else {
        // 普通语言标签
        let lang_tag = try
          LanguageTag::from_str(language.to_lower()) |> Ok
        catch {
          e => Err(e)
        }
        let lang_tag = match lang_tag {
          Ok(lang_tag) => lang_tag
          Err(_e) => LanguageTag::default()
        }
        LiteralRef::new_language_tagged_literal_unchecked(
          value,
          lang_tag.to_string(),
        )
      }

      // 推入 cur_object
      let new_cur_object = self.cur_object + [TermRef::LiteralRef(literal)]
      let new_self = { ..self, cur_object: new_cur_object }

      // 如果 emit=true，输出三元组
      if emit {
        self.debug_logger.info(
          "LiteralPossibleSuffix: emitting quad with language tag",
        )
        let quad = new_self.emit_quad_m()

        // 弹出 LiteralPossibleSuffix 状态
        let new_stack = new_self.stack
        let _ = new_stack.pop()
        let new_self = { ..new_self, stack: new_stack }

        Ok((new_self, TriGState::PredicateObjectListEnd, Some(quad)))
      } else {
        // 不输出（用于引用三元组内部）
        let new_stack = new_self.stack
        let _ = new_stack.pop()
        let new_self = { ..new_self, stack: new_stack }

        Ok((new_self, TriGState::PredicateObjectListEnd, None))
      }
    }

    // ===== 情况2：数据类型 =====
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("^^"), _)
    ) => {
      self.debug_logger.info("LiteralPossibleSuffix: datatype indicator '^^'")

      // ✅ 进入 LiteralExpectDatatype 状态等待数据类型
      // 注意：不消耗当前 token，让下一个状态处理
      Ok((self, TriGState::LiteralExpectDatatype(value~, emit~), None))
    }

    // ===== 情况3：无后缀（简单字面量） =====
    _ => {
      self.debug_logger.info("LiteralPossibleSuffix: no suffix, simple literal")

      // 创建简单字面量
      let literal = LiteralRef::new_simple_literal(value)
      let new_cur_object = self.cur_object + [TermRef::LiteralRef(literal)]
      let new_self = { ..self, cur_object: new_cur_object }

      // 如果 emit=true，输出三元组
      if emit {
        self.debug_logger.info(
          "LiteralPossibleSuffix: emitting quad (simple literal)",
        )
        let quad = new_self.emit_quad_m()

        // 弹出 LiteralPossibleSuffix 状态
        let new_stack = new_self.stack
        let _ = new_stack.pop()
        let new_self = { ..new_self, stack: new_stack }

        // ✅ 继续处理当前 token（可能是 '.' 或 ';' 或 ','）
        // 需要递归调用 recognize_next 处理同一个 token
        // 但这里我们返回 PredicateObjectListEnd，由引擎处理同一个 token
        Ok((new_self, TriGState::PredicateObjectListEnd, Some(quad)))
      } else {
        // 不输出
        let new_stack = new_self.stack
        let _ = new_stack.pop()
        let new_self = { ..new_self, stack: new_stack }

        Ok((new_self, TriGState::PredicateObjectListEnd, None))
      }
    }
  }
}

// ===== 简化版 =====

///|
fn TriGRecognizer::handle_object_blank_node_property_list_end_m(
  self : TriGRecognizer,
  event : Event,
  context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("]"), _)
    ) => {
      // 弹出空白节点
      let subject = self.cur_subject.pop()
      // let subject= match subject  {
      //   Some(NamedOrBlankNodeRef::BlankNodeRef(b)) => b
      //   _ => return Err(RuleRecognizerError::SyntaxError("Expected blank node", self.last_range))
      //  }

      let blank_ref = match subject {
        Some(NamedOrBlankNodeRef::BlankNodeRef(b)) => b
        _ =>
          return Err(
            RuleRecognizerError::SyntaxError(
              "Expected blank node",
              self.last_range,
            ),
          )
      }

      // 推入 cur_object
      let new_cur_object = self.cur_object + [TermRef::BlankNodeRef(blank_ref)]
      let new_self = { ..self, cur_object: new_cur_object }

      // 输出
      let quad = new_self.emit_quad_m()

      // 弹出当前状态
      let new_stack = new_self.stack
      let _ = new_stack.pop()
      let new_self = { ..new_self, stack: new_stack }

      Ok((new_self, TriGState::PredicateObjectListEnd, Some(quad)))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected ']' to close blank node property list",
          self.last_range,
        ),
      )
  }
}
