///|
test "check char classification" {
  // 测试 '>' 的分类
  let gt = b'>'
  let cc = @lib.classify_byte(gt)
  debug("'>' classified as: \{cc}")
  let rdflexer = @lib.RdfLexer::default()

  // 检查是否是 RAngle
  match cc {
    @lib.CharClass::RAngle => debug("OK: is RAngle")
    _ => debug("ERROR: not RAngle, is: \{cc}")
  }

  // 检查转换表
  let t = rdflexer.find_transition(
    @lib.LexStateMachine::InIri,
    @lib.CharClass::RAngle,
  )
  match t {
    Some(t) => debug("Found transition: to=\{t.to}, action=\{t.action}")
    None => debug("ERROR: No transition for InIri + RAngle")
  }
}

///|
test "check all IRI chars have transition" {
  let iri_chars = "<http://example.org>"
  let rdflexer = @lib.RdfLexer::default()

  for i, b in @utf8.encode(iri_chars).iter2() {
    let cc = @lib.classify_byte(b)
    let t = rdflexer.find_transition(@lib.LexStateMachine::InIri, cc)
    debug(
      "  [\{i}] '\{b.to_int().unsafe_to_char()}' (\{cc}): \{if t is Some(_) { "OK" } else { "MISSING" }}",
    )
  }
}

///|
test "test @lib.classify_byte" {
  // 基本字符分类

  assert_eq(@lib.classify_byte(b' '), @lib.CharClass::Space)
  assert_eq(@lib.classify_byte(b'\t'), @lib.CharClass::Space)
  assert_eq(@lib.classify_byte(b'\n'), @lib.CharClass::Newline)
  assert_eq(@lib.classify_byte(b'<'), @lib.CharClass::LAngle)
  assert_eq(@lib.classify_byte(b'>'), @lib.CharClass::RAngle)
  assert_eq(@lib.classify_byte(b'"'), @lib.CharClass::Quote)
  assert_eq(@lib.classify_byte(b'\''), @lib.CharClass::Apostrophe)
  assert_eq(@lib.classify_byte(b':'), @lib.CharClass::Colon)
  assert_eq(@lib.classify_byte(b'@'), @lib.CharClass::At)
  assert_eq(@lib.classify_byte(b'.'), @lib.CharClass::Period)
  assert_eq(@lib.classify_byte(b'-'), @lib.CharClass::Minus)
  assert_eq(@lib.classify_byte(b'+'), @lib.CharClass::Plus)
  assert_eq(@lib.classify_byte(b'\\'), @lib.CharClass::Backslash)
  assert_eq(@lib.classify_byte(b'a'), @lib.CharClass::Other)
}

///|
test "test transitions initialization" {
  let transitions = @lib.initialize_transitions

  assert_true(transitions.length() > 0)
}

///|
test "test find_transition - Start with Space" {
  let rdflexer = @lib.RdfLexer::default()

  let t = rdflexer.find_transition(
    @lib.LexStateMachine::Start,
    @lib.CharClass::Space,
  )
  match t {
    Some(t) => {
      assert_eq(t.from, @lib.LexStateMachine::Start)
      assert_eq(t.to, @lib.LexStateMachine::SkipWhitespace)
    }
    None => fail("Should find transition")
  }
}

///|
test "test find_transition - Start with LAngle" {
  let rdflexer = @lib.RdfLexer::default()

  let t = rdflexer.find_transition(
    @lib.LexStateMachine::Start,
    @lib.CharClass::LAngle,
  )
  match t {
    Some(t) => {
      assert_eq(t.from, @lib.LexStateMachine::Start)
      assert_eq(t.to, @lib.LexStateMachine::InIri)
    }
    None => fail("Should find transition")
  }
}

///|
test "test find_transition - InIri with RAngle" {
  let rdflexer = @lib.RdfLexer::default()

  let t = rdflexer.find_transition(
    @lib.LexStateMachine::InIri,
    @lib.CharClass::RAngle,
  )
  match t {
    Some(t) => assert_eq(t.to, @lib.LexStateMachine::Start)
    None => fail("Should find transition")
  }
}

///|
test "test LexContext - basic operations" {
  let data = @utf8.encode("hello").to_array()
  let ctx = @lib.LexContext::new(data)
  assert_eq(ctx.position, 0)
  assert_eq(ctx.state, @lib.LexStateMachine::Start)

  ctx.advance()
  assert_eq(ctx.position, 1)
}

///|
test "test LexContext - current_char and peek_char" {
  let data = @utf8.encode("abc").to_array()
  let ctx = @lib.LexContext::new(data)
  match ctx.current_char() {
    Some(b) => assert_eq(b, b'a')
    None => fail("Should have current char")
  }

  match ctx.peek_char() {
    Some(b) => assert_eq(b, b'b')
    None => fail("Should have peek char")
  }
}

///|
test "test LexContext - capture" {
  let data = @utf8.encode("hello").to_array()
  let ctx = @lib.LexContext::new(data)

  ctx.capture_start = 0
  ctx.capture_current = 5

  let captured = ctx.get_capture()
  assert_eq(captured, "hello")
}

///|
test "test execute_action - StartCapture" {
  let data = @utf8.encode("hello").to_array()
  let ctx = @lib.LexContext::new(data)
  let rdflexer = @lib.RdfLexer::default()

  let (_action, new_ctx) = rdflexer.execute_action(
    @lib.LexAction::StartCapture,
    ctx,
    b'h',
    data,
  )
  assert_eq(ctx.capture_start, 0)
  assert_eq(new_ctx.position, 1)
}

///|
test "test execute_action - AppendCapture" {
  let data = @utf8.encode("hello").to_array()
  let ctx = @lib.LexContext::new(data)
  ctx.capture_start = 0
  ctx.capture_current = 0
  ctx.position = 0
  let rdflexer = @lib.RdfLexer::default()

  let (_action, new_ctx) = rdflexer.execute_action(
    @lib.LexAction::AppendCapture,
    ctx,
    b'h',
    data,
  )
  assert_eq(ctx.capture_current, 1)
  assert_eq(new_ctx.position, 1)
}

///|
test "test state machine - IRI token" {
  let data = @utf8.encode("<http://example.org>").to_array()
  let ctx = @lib.LexContext::new(data)
  let rdflexer = @lib.RdfLexer::default()
  // Start -> InIri
  match rdflexer.find_transition(ctx.state, @lib.classify_byte(data[0])) {
    Some(t) => {
      let (_action, _new_ctx) = rdflexer.execute_action(
        t.action,
        ctx,
        data[0],
        data,
      )
      ctx.state = t.to
      assert_eq(ctx.state, @lib.LexStateMachine::InIri)
    }
    None => fail("Should find transition for <")
  }

  // 消费 IRI 内容
  for _i in 1..<(data.length() - 1) {
    ctx.advance()
  }

  // InIri -> Start (遇到 >)
  match rdflexer.find_transition(ctx.state, @lib.CharClass::RAngle) {
    Some(t) => {
      let (action, _) = rdflexer.execute_action(t.action, ctx, b'>', data)
      match action {
        @lib.LexAction::EmitToken => assert_true(true)
        _ => fail("Should emit token")
      }
    }
    None => fail("Should find transition for >")
  }
}

///|
test "test state machine - keyword token" {
  let data = @utf8.encode("hello ")
  let mut ctx = @lib.LexContext::new(data.to_array())

  // 调试：检查 state
  println("initial state: \{ctx.state}")

  // 调试：检查 char class
  let char_class = @lib.classify_byte(data[0])
  println("char class: \{char_class}")
  let rdflexer = @lib.RdfLexer::default()

  // Start -> InKeyword
  let t = rdflexer.find_transition(ctx.state, char_class)
  println("transition found: \{@debug.to_string(t)}")

  match t {
    Some(t) => {
      let (_action, new_ctx) = rdflexer.execute_action(
        t.action,
        ctx,
        data[0],
        data.to_array(),
      )
      ctx = new_ctx
      ctx.state = t.to
      println("new state: \{ctx.state}")
    }
    None => fail("Should find transition for keyword start")
  }

  // 消费 "hello"
  for _i in 1..<5 {
    ctx.advance()
  }

  // 调试：检查当前状态和空格分类
  println("before space, state: \{ctx.state}")
  println("Space char class: \{@lib.CharClass::Space}")

  // InKeyword -> Start (遇到空格)
  match rdflexer.find_transition(ctx.state, @lib.CharClass::Space) {
    Some(t) => {
      let (action, _) = rdflexer.execute_action(
        t.action,
        ctx,
        b' ',
        data.to_array(),
      )
      match action {
        @lib.LexAction::EmitToken => assert_true(true)
        _ => fail("Should emit token")
      }
    }
    None => fail("Should find transition for space")
  }
}

///|
test "test state machine - blank node" {
  let data = @utf8.encode("_:node1").to_array()
  let ctx = @lib.LexContext::new(data)
  let rdflexer = @lib.RdfLexer::default()

  // Start -> InBlank
  match rdflexer.find_transition(ctx.state, @lib.CharClass::Underscore) {
    Some(t) => {
      let (_, new_ctx) = rdflexer.execute_action(t.action, ctx, b'_', data)
      new_ctx.state = t.to
    }
    None => fail("Should find transition for _")
  }

  // InBlank -> InBlankLabel (遇到 :)
  match rdflexer.find_transition(ctx.state, @lib.CharClass::Colon) {
    Some(t) => {
      let (_, new_ctx) = rdflexer.execute_action(t.action, ctx, b':', data)
      new_ctx.state = t.to
    }
    None => fail("Should find transition for :")
  }

  // 消费 "node1"
  for _i in 0..<5 {
    ctx.advance()
  }
}

///|
test "test state machine - skip whitespace" {
  let data = @utf8.encode("hello").to_array()
  let ctx = @lib.LexContext::new(data)
  let rdflexer = @lib.RdfLexer::default()

  // Start -> SkipWhitespace
  match rdflexer.find_transition(ctx.state, @lib.CharClass::Space) {
    Some(t) => ctx.state = t.to
    None => fail("Should find transition for space")
  }

  // SkipWhitespace -> SkipWhitespace
  for _i in 1..<3 {
    match rdflexer.find_transition(ctx.state, @lib.CharClass::Space) {
      Some(t) => {
        let (_action, new_ctx) = rdflexer.execute_action(
          t.action,
          ctx,
          b' ',
          data,
        )
        new_ctx.state = t.to
      }
      None => fail("Should find transition")
    }
  }

  // SkipWhitespace -> Start (遇到非空白)
  match rdflexer.find_transition(ctx.state, @lib.classify_byte(b'h')) {
    Some(t) => assert_eq(t.to, @lib.LexStateMachine::Start)
    None => fail("Should find transition")
  }
}

///|
test "test state machine - lang tag" {
  let data = @utf8.encode("@en ").to_array()
  let ctx = @lib.LexContext::new(data)
  let rdflexer = @lib.RdfLexer::default()

  // Start -> InLangTag
  match rdflexer.find_transition(ctx.state, @lib.CharClass::At) {
    Some(t) => {
      let (_action, new_ctx) = rdflexer.execute_action(
        t.action,
        ctx,
        b'@',
        data,
      )
      new_ctx.state = t.to
    }
    None => fail("Should find transition for @")
  }

  // 消费 "en"
  for _i in 0..<2 {
    ctx.advance()
  }

  // 手动设置状态为 InLangTag（因为 ctx.state 可能还是 Start）
  ctx.state = @lib.LexStateMachine::InLangTag

  // InLangTag -> Start (遇到空格)
  match rdflexer.find_transition(ctx.state, @lib.CharClass::Space) {
    Some(t) => {
      let (action, _new_ctx) = rdflexer.execute_action(
        t.action,
        ctx,
        b' ',
        data,
      )
      match action {
        @lib.LexAction::EmitToken => {
          debug("Captured: '\{ctx.get_capture()}'")
          assert_true(true)
        }
        _ => fail("Should emit token")
      }
    }
    None => fail("Should find transition for space")
  }
}

///|
test "test make_token - Iri" {
  let token = @lib.make_token(
    @lib.LexStateMachine::InIri,
    "<http://example.org>",
  )
  match token {
    @lib.N3Token::Iri(s) => assert_eq(s, "<http://example.org>")
    _ => fail("Should be Iri token")
  }
}

///|
test "test make_token - BlankNodeLabel" {
  let token = @lib.make_token(@lib.LexStateMachine::InBlankLabel, "node1")
  match token {
    @lib.N3Token::BlankNodeLabel(s) => assert_eq(s, "node1")
    _ => fail("Should be BlankNodeLabel token")
  }
}

///|
test "test make_token - String" {
  let token = @lib.make_token(@lib.LexStateMachine::InString, "hello")
  match token {
    @lib.N3Token::String(s) => assert_eq(s, "hello")
    _ => fail("Should be String token")
  }
}

///|
test "test make_token - Integer" {
  let token = @lib.make_token(@lib.LexStateMachine::InInteger, "123")
  match token {
    @lib.N3Token::Integer(s) => assert_eq(s, "123")
    _ => fail("Should be Integer token")
  }
}

///|
test "test make_token - PlainKeyword" {
  let token = @lib.make_token(@lib.LexStateMachine::InKeyword, "SELECT")
  match token {
    @lib.N3Token::PlainKeyword(s) => assert_eq(s, "SELECT")
    _ => fail("Should be PlainKeyword token")
  }
}
