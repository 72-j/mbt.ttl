// ===== 状态: TriGState::TriplesOrGraph =====
// 功能: 处理三元组或图的起始，识别主语或图名

///|
fn TriGRecognizer::handle_triples_or_graph_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("TriplesOrGraph: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::WrappedGraphOrPredicateObjectList =====
// 功能: 根据term判断是进入图块还是谓词对象列表

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

  self.debug_logger.info(
    "WrappedGraphOrPredicateObjectList: event=\{event} Token stack: \{@debug.to_string(self.stack)}",
  )
  self.debug_logger.info(
    "Current subject: \{@debug.to_string(self.cur_subject)},Current predicate: \{@debug.to_string(self.cur_predicate)},Current object: \{@debug.to_string(self.cur_object)}",
  )

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
      // 不再压入 ObjectsList，直接准备进入 Object 状态
      // 但我们需要告诉引擎用同一个 token 调用 Object 状态
      // 由于当前架构每次 transition 都消费 token，我们需要直接返回 Object
      let new_self_with_stack = { ..new_self, stack: new_stack }
      // 直接转移到 Object 状态，让引擎用同一个 token 处理
      Ok((new_self_with_stack, TriGState::Object, None))
    }
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      self.debug_logger.info(
        "[Step 2] WrappedGraphOrPredicateObjectList: event=\{event}",
      )

      let new_self = self
      new_self.cur_subject.push(term)
      new_self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))

      let new_stack = new_self.stack
      new_stack.push(TriGState::ExpectDot)

      // 直接转移到 Object 状态
      let new_self_with_stack = { ..new_self, stack: new_stack }
      Ok((new_self_with_stack, TriGState::Object, None))
    }
    // ✅ 处理 PrefixedName 作为 predicate
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          let new_self = self
          new_self.cur_subject.push(term)
          // match t {
          // NamedOrBlankNodeRef::NamedNodeRef(n) => {
          new_self.cur_predicate.push(t)
          // }
          // _ =>
          //   return Err(
          //     RuleRecognizerError::SyntaxError(
          //       "PrefixedName in predicate position must resolve to IRI",
          //       self.last_range,
          //     ),
          //   )
          // }

          let new_stack = new_self.stack
          new_stack.push(TriGState::ExpectDot)

          let new_self_with_stack = { ..new_self, stack: new_stack }
          Ok((new_self_with_stack, TriGState::Object, None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected a predicate or graph block",
          self.last_range,
        ),
      )
  }
}

// ===== 状态: TriGState::ObjectsList =====
// 功能: 路由到Object状态处理对象列表

///|
fn TriGRecognizer::handle_objects_list_m(
  self : TriGRecognizer,
  _event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {

  // ObjectsList 只是路由到 Object
  // 原代码: push Object, then recognize_next (which processes same token)
  self.debug_logger.info("ObjectsList: routing to Object state")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  let new_stack = self.stack
  new_stack.push(TriGState::Object) // 如果内部栈需要记录返回点? 原代码似乎没 push 返回点到内部栈，而是直接切换逻辑

  // 注意：原代码中 ObjectsList 是一个"瞬态"状态，它立即把控制权交给 Object。
  // 如果我们的状态机引擎在一次 transition 中只走一步，那么返回 Object 状态是正确的。

  let new_self = { ..self, stack: new_stack }
  Ok((new_self, TriGState::Object, None))
}

// ===== 状态: TriGState::Object =====
// 功能: 处理RDF对象（IRI、字面量、集合等）

///|
fn TriGRecognizer::handle_object_m(
  self : TriGRecognizer,
  event : Event,
  __context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "Object: handling event: \{event},Token stack: \{@debug.to_string(self.stack)}",
  )

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let obj_term = TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))
      // let new_self = self
      self.cur_object.push(obj_term)
      // emit_quad 逻辑：生成一个 RdfOut
      // 假设 make_current_quad 或类似方法可用
      let quad = self.make_current_quad() // 假设此方法存在并正确构建 Quad
      self.debug_logger.info("[Step 4]Object: emitted quad: \{quad}")

      // 转移状态：根据原代码，push PredicateObjectListEnd
      let new_stack = self.stack
      new_stack.push(TriGState::PredicateObjectListEnd)

      let final_self = { ..self, stack: new_stack }
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
    // ✅ 添加 String 处理
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::String(value), _)
    ) => {
      let new_self = self
      new_self.cur_object.push(
        TermRef::LiteralRef(LiteralRef::new_simple_literal(value)),
      )

      // 生成 quad
      let quad = new_self.make_current_quad()

      // 进入 PredicateObjectListEnd
      new_self.stack.push(TriGState::PredicateObjectListEnd)
      let final_self = { ..new_self, stack: new_self.stack }
      Ok((final_self, TriGState::PredicateObjectListEnd, Some(quad)))
    }

    // ✅ 添加 LongString 处理
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::LongString(value), _)
    ) => {
      let new_self = self
      new_self.cur_object.push(
        TermRef::LiteralRef(LiteralRef::new_simple_literal(value)),
      )

      let quad = new_self.make_current_quad()
      new_self.stack.push(TriGState::PredicateObjectListEnd)
      let final_self = { ..new_self, stack: new_self.stack }
      Ok((final_self, TriGState::PredicateObjectListEnd, Some(quad)))
    }
    // ✅ 添加带数据类型注解的 String
    // LocatedTokenOrLineJump::LocatedN3Token(
    //   LocatedN3Token(N3Token::StringWithDatatype(value, dt~), _)
    // ) => {
    //   let new_self = self
    //   new_self.cur_object.push(
    //     TermRef::LiteralRef(LiteralRef::new_typed_literal(value, dt).as_ref()),
    //   )

    //   let quad = new_self.make_current_quad()
    //   new_self.stack.push(TriGState::PredicateObjectListEnd)
    //   let final_self = { ..new_self, stack: new_self.stack }
    //   Ok((final_self, TriGState::PredicateObjectListEnd, Some(quad)))
    // }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "TOKEN is not a valid RDF object",
          self.last_range,
        ),
      )
  }
}

// ===== 状态: TriGState::ObjectCollectionBeginning =====
// 功能: 处理 '(' 后的第一个元素或空集合情况

///|
fn TriGRecognizer::handle_object_collection_beginning_m(
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

  self.debug_logger.info("ObjectCollectionBeginning: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::ObjectCollectionPossibleEnd =====
// 功能: 检查集合是否结束或继续处理下一个元素

///|
fn TriGRecognizer::handle_object_collection_possible_end_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "ObjectCollectionPossibleEnd: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::PredicateObjectListEnd =====
// 功能: 处理谓词对象列表结束符（逗号、分号、句号）

///|
fn TriGRecognizer::handle_predicate_object_list_end_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("PredicateObjectListEnd: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::TriGDoc =====
// 功能: TriG文档的顶层状态，处理指令和三文组

///|
fn TriGRecognizer::handle_trig_doc_m(
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

  self.debug_logger.info("[Step 1] Entering TriGDoc with event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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
      let new_self_with_subject = new_self
      new_self_with_subject.cur_subject.push(
        NamedNodeRef::new_unchecked(iri).as_enum(),
      )
      // 进入 WrappedGraphOrPredicateObjectList，等待谓词
      let new_stack = new_self_with_subject.stack
      new_stack.push(
        TriGState::WrappedGraphOrPredicateObjectList(
          term=NamedNodeRef::new_unchecked(iri).as_enum(),
        ),
      )
      let final_self = { ..new_self_with_subject, stack: new_stack }
      Ok(
        (
          final_self,
          TriGState::WrappedGraphOrPredicateObjectList(
            term=NamedNodeRef::new_unchecked(iri).as_enum(),
          ),
          None,
        ),
      )
    }

    // 处理 BlankNode 作为主语
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(label), _)
    ) => {
      self.debug_logger.info("TriGDoc: BlankNode as subject = \{label}")
      let new_self_with_subject = new_self
      new_self_with_subject.cur_subject.push(
        BlankNodeRef::new_unchecked(label).as_enum(),
      )
      let new_stack = new_self_with_subject.stack
      new_stack.push(
        TriGState::WrappedGraphOrPredicateObjectList(
          term=BlankNodeRef::new_unchecked(label).as_enum(),
        ),
      )
      let final_self = { ..new_self_with_subject, stack: new_stack }
      Ok(
        (
          final_self,
          TriGState::WrappedGraphOrPredicateObjectList(
            term=BlankNodeRef::new_unchecked(label).as_enum(),
          ),
          None,
        ),
      )
    }

    // 处理 PrefixedName 作为主语
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          self.debug_logger.info("TriGDoc: PrefixedName as subject = \{t}")
          let new_self_with_subject = new_self
          new_self_with_subject.cur_subject.push(t.as_enum())
          let new_stack = new_self_with_subject.stack
          new_stack.push(
            TriGState::WrappedGraphOrPredicateObjectList(term=t.as_enum()),
          )
          let final_self = { ..new_self_with_subject, stack: new_stack }
          Ok(
            (
              final_self,
              TriGState::WrappedGraphOrPredicateObjectList(term=t.as_enum()),
              None,
            ),
          )
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
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
      Ok(
        (final_self, TriGState::WrappedGraphBlankNodePropertyListCurrent, None),
      )
    }

    // 默认情况
    _ => {
      self.debug_logger.info(
        "TriGDoc: unexpected token, pushing TriplesOrGraph",
      )
      let new_stack = new_self.stack
      new_stack.push(TriGState::TriplesOrGraph)
      let final_self = { ..new_self, stack: new_stack }
      Ok((final_self, TriGState::TriplesOrGraph, None))
    }
  }
}

// ===== 状态: TriGState::Triples =====
// 功能: 处理图内的三元组，识别主语

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
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::Verb =====
// 功能: 处理谓词（包括 'a' 关键字和IRI）

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
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::ExpectDot =====
// 功能: 期望遇到句号，用于指令结束

///|
fn TriGRecognizer::handle_expect_dot_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("ExpectDot: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::BaseExpectIri =====
// 功能: BASE指令后期望IRI

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

  self.debug_logger.info("BaseExpectIri: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match event {
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(iri_str), _)
    ) => {
      let iri_ref = Iri::new(iri_str)
      let new_ctx_options = if self.lenient {
        { base_iri: Some(IriRef::parse_unchecked(iri_ref)) }
      } else {
        match IriRef::parse(iri_ref) {
          Ok(parsed_iri) => { base_iri: Some(parsed_iri) }
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

// ===== 状态: TriGState::PrefixExpectPrefix =====
// 功能: PREFIX指令后期望前缀名

///|
fn TriGRecognizer::handle_prefix_expect_prefix_m(
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

  self.debug_logger.info("PrefixExpectPrefix: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::PrefixExpectIri =====
// 功能: 前缀名后期望IRI值

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

  self.debug_logger.info("PrefixExpectIri: name=\{name}, event=\{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::VersionExpectVersion =====
// 功能: VERSION指令后期望版本号字符串

///|
fn TriGRecognizer::handle_version_expect_version_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("VersionExpectVersion: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::WrappedGraphBlankNodePropertyListCurrent =====
// 功能: 处理图中空白节点属性列表的当前状态

///|
fn TriGRecognizer::handle_wrapped_graph_blank_node_property_list_current_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "WrappedGraphBlankNodePropertyListCurrent: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::SubjectBlankNodePropertyListEnd =====
// 功能: 主语空白节点属性列表结束，期望']'

///|
fn TriGRecognizer::handle_subject_blank_node_property_list_end_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "SubjectBlankNodePropertyListEnd: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::SubjectBlankNodePropertyListAfter =====
// 功能: 主语空白节点属性列表结束后处理

///|
fn TriGRecognizer::handle_subject_blank_node_property_list_after_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "SubjectBlankNodePropertyListAfter: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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
  _context : RdfContext,
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

// ===== 状态: TriGState::SubjectCollectionPossibleEnd =====
// 功能: 检查主语集合是否结束或继续处理下一个元素

///|
fn TriGRecognizer::handle_subject_collection_possible_end_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "SubjectCollectionPossibleEnd: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::TriplesBlankNodePropertyListCurrent =====
// 功能: 处理三元组中空白节点属性列表的当前状态

///|
fn TriGRecognizer::handle_triples_blank_node_property_list_current_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "TriplesBlankNodePropertyListCurrent: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::GraphName =====
// 功能: 处理图名的解析（IRI、前缀名、空白节点等）

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

  self.debug_logger.info("GraphName: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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
// ===== 状态: TriGState::GraphNameAnonEnd =====
// 功能: 匿名图名结束，期望']'

///|
fn TriGRecognizer::handle_graph_name_anon_end_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("GraphNameAnonEnd: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::MaybePredicateObjectList =====
// 功能: 可选的谓词对象列表，处理特殊情况

///|
fn TriGRecognizer::handle_maybe_predicate_object_list_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("MaybePredicateObjectList: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::AnnotationEnd =====
// 功能: 注释结束，期望'|}'

///|
fn TriGRecognizer::handle_annotation_end_m(
  self : TriGRecognizer,
  with_reifier : Bool,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "AnnotationEnd: with_reifier=\{with_reifier}, event=\{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::ObjectBlankNodePropertyListCurrent =====
// 功能: 对象空白节点属性列表的当前状态

///|
fn TriGRecognizer::handle_object_blank_node_property_list_current_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "ObjectBlankNodePropertyListCurrent: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::LiteralExpectDatatype =====
// 功能: 字面量后期望数据类型IRI

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

  self.debug_logger.info(
    "LiteralExpectDatatype: value='\{value}', emit=\{emit}, event=\{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::SubjectReifiedTripleEnd =====
// 功能: 引用三元组主语结束，期望'>>'

///|
fn TriGRecognizer::handle_subject_reified_triple_end_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("SubjectReifiedTripleEnd: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::TripleTermEnd =====
// 功能: 三元组项结束，期望')>>'

///|
fn TriGRecognizer::handle_triple_term_end_m(
  self : TriGRecognizer,
  emit : Bool,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info("TripleTermEnd: emit=\{emit}, event=\{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::EndOfReifiedTripleBeforeReifier =====
// 功能: 引用三元组结束后处理reifier

///|
fn TriGRecognizer::handle_end_of_reified_triple_before_reifier_m(
  self : TriGRecognizer,
  event : Event,
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  self.debug_logger.info(
    "EndOfReifiedTripleBeforeReifier: handling event: \{event}",
  )
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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

// ===== 状态: TriGState::Reifier =====
// 功能: 处理reifier（引用节点）

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

  self.debug_logger.info("Reifier: triple=\{triple}, event=\{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

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
  _context : RdfContext,
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
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  // WrappedGraph 由 { 进入，现在进入图内容
  // 期望收到三元组主语（IRI、blank node 等）或 {
  match event {
    // 收到 '{'，开始图内容
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("{"), _)
    ) => {
      self.stack.push(TriGState::WrappedGraphPossibleEnd)
      self.stack.push(TriGState::Triples)
      Ok((self, TriGState::Triples, None))
    }
    // 收到 IRI 作为图内容的主语
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      self.cur_subject.push(NamedNodeRef::new_unchecked(iri).as_enum())
      self.stack.push(TriGState::WrappedGraphPossibleEnd)
      self.stack.push(TriGState::PredicateObjectList)
      Ok((self, TriGState::PredicateObjectList, None))
    }
    // 收到 BlankNode 作为图内容的主语
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::BlankNodeLabel(label), _)
    ) => {
      self.cur_subject.push(BlankNodeRef::new_unchecked(label).as_enum())
      self.stack.push(TriGState::WrappedGraphPossibleEnd)
      self.stack.push(TriGState::PredicateObjectList)
      Ok((self, TriGState::PredicateObjectList, None))
    }
    // 收到匿名图 [
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("["), _)
    ) => {
      self.stack.push(TriGState::WrappedGraphPossibleEnd)
      self.stack.push(TriGState::WrappedGraphBlankNodePropertyListCurrent)
      Ok((self, TriGState::WrappedGraphBlankNodePropertyListCurrent, None))
    }
    // 收到集合开始 (
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("("), _)
    ) => {
      self.stack.push(TriGState::WrappedGraphPossibleEnd)
      self.stack.push(TriGState::SubjectCollectionBeginning)
      Ok((self, TriGState::SubjectCollectionBeginning, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected '{' or subject to start graph content",
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
  _context : RdfContext,
) -> TransitionResult[TriGRecognizer, TriGState, RdfOut] {
  match event {
    // ✅ 情况1：收到 `}` → 图结束
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      self.debug_logger.info("WrappedGraphPossibleEnd: graph ended with '}'")

      // ✅ 弹出 WrappedGraphPossibleEnd

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
  _context : RdfContext,
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
  _context : RdfContext,
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
  _context : RdfContext,
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

///|
/// 状态: PredicateObjectList - 处理谓词对象列表
fn TriGRecognizer::handle_predicate_object_list_m(
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

  self.debug_logger.info("PredicateObjectList: handling event: \{event}")
  self.debug_logger.info("Token stack: \{@debug.to_string(self.stack)}")

  match event {
    // ✅ 处理 'a' 作为 rdf:type
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("a"), _)
    ) => {
      let new_self = self
      new_self.cur_predicate.push(lwTYPE)
      // 保持在 PredicateObjectList，准备处理 Object
      Ok((new_self, TriGState::Object, None))
    }

    // ✅ 处理 IRI 作为 predicate
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let new_self = self
      new_self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))
      Ok((new_self, TriGState::Object, None))
    }

    // ✅ 处理 PrefixedName 作为 predicate
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          let new_self = self
          new_self.cur_predicate.push(t)
          Ok((new_self, TriGState::Object, None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }

    // ✅ 处理 '}' 图结束
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      // 图结束，返回 TriGDoc
      let new_self = { ..self, stack: [TriGState::TriGDoc] }
      Ok((new_self, TriGState::TriGDoc, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected predicate or '}' in predicate-object list",
          self.last_range,
        ),
      )
  }
}

///|
/// 状态: PredicateObjectListPossibleContinuation - 谓词列表分号后等待新谓词
fn TriGRecognizer::handle_predicate_object_list_possible_continuation_m(
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
    // ✅ 处理 'a' 作为 rdf:type
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::PlainKeyword("a"), _)
    ) => {
      let new_self = self
      new_self.cur_predicate.push(lwTYPE)
      Ok((new_self, TriGState::Object, None))
    }

    // ✅ 处理 IRI 作为 predicate
    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Iri(iri), _)) => {
      let new_self = self
      new_self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))
      Ok((new_self, TriGState::Object, None))
    }

    // ✅ 处理 PrefixedName 作为 predicate
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(
        N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
        _
      )
    ) =>
      match
        resolve_local_name(prefix, localx, might_be_invalid_iri, ctx.prefixes) {
        Ok(t) => {
          let new_self = self
          new_self.cur_predicate.push(t)
          Ok((new_self, TriGState::Object, None))
        }
        Err(e) => Err(RuleRecognizerError::SyntaxError(e, self.last_range))
      }

    // ✅ 处理 } 图结束
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("}"), _)
    ) => {
      let new_self = { ..self, stack: [TriGState::TriGDoc] }
      Ok((new_self, TriGState::TriGDoc, None))
    }

    // ✅ 处理 . 结束语句
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Punctuation("."), _)
    ) => {
      let new_self = {
        ..self,
        stack: [TriGState::TriGDoc],
        cur_subject: [],
        cur_predicate: [],
        cur_object: [],
      }
      Ok((new_self, TriGState::TriGDoc, None))
    }
    _ =>
      Err(
        RuleRecognizerError::SyntaxError(
          "Expected predicate, '.', or '}' after ';'",
          self.last_range,
        ),
      )
  }
}
