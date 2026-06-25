///|
/// 
///|
async test "debug_simple_turtle_workaround" {
  // 变通：使用简单字面量代替集合，验证解析器基本通路
  let input = "<http://a.example/s> <http://a.example/p> 1 ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/"))

  let parser = TriGRecognizer::new_parser(
    data,
    true, // is_ending
    false, // with_graph_name
    true, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}
async test "debug_simple_turtle_fixed_input" {
  // 修复：使用标准的三元组，避免集合语法，以验证解析器核心功能
  let input = "<http://a.example/s> <http://a.example/p> <http://a.example/o> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/"))

  let parser = TriGRecognizer::new_parser(
    data,
    true, // is_ending
    false, // with_graph_name
    true, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}
async test "debug_simple_turtle" {
  let input =
    #| <http://a.example/s> <http://a.example/p> (1) .

  // #|<http://a.example/s> <http://a.example/p> 1 .
  // #|<http://example.org/s> <http://example.org/p> <http://example.org/o> .
  let data = @utf8.encode(input).to_array()

  // 关键：Turtle 解析通常需要 BASE 或 Prefixes 即使为空，或者特定的标志
  // 如果 TriGRecognizer 有 is_turtle 标志，请设置为 true
  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/")) // 尝试提供一个基础 IRI，避免相对 IRI 问题

  // 注意：with_graph_name 为 false，lenient 为 true
  let parser = TriGRecognizer::new_parser(
    data,
    true, // is_ending
    false, // with_graph_name
    true, // lenient - 开启宽松模式可能有助于处理非标准起始
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  // 如果仍然失败，可能需要检查 TriGRecognizer 是否需要在 parse_next 之前调用某个 init() 或 set_mode_turtle()

  match parser.parse_next() {
    Some(Ok(t)) => debug("Success: \{t.to_string()}")
    Some(Err(e)) => debug("Error: \{e.to_string()}")
    None => debug("None")
  }
}

///|
async test "debug_simple_triple" {
  // 1. 准备最简单的 Turtle 输入: <s> <p> <o> .
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  let data = @utf8.encode(input)

  // 2. 创建解析器 (使用 TriGRecognizer 的底层接口，假设存在或直接调用 new_parser)
  // 注意：根据你之前的代码，TriGRecognizer::new_parser 返回一个 Parser[RdfLexer, TriGRecognizer]
  let parser = TurtleParser::new().lenient()

  let low_level = parser.low_level()

  // 3. 喂入数据
  low_level.extend_from_slice(data)
  low_level.end()

  // 4. 尝试解析
  let result = low_level.parse_next()

  // 5. 输出调试信息
  match result {
    Some(Ok(triple)) => debug("Success! Parsed Quad: \{triple.to_string()}")
    // 预期输出: Success! Parsed Quad: <http://example.org/s> <http://example.org/p> <http://example.org/o> .
    Some(Err(e)) => debug("Parse Error: \{e.to_string()}")
    // 如果这里报错 "TOKEN is not allowed here"，说明状态栈复位失败
    None => debug("Parse returned None (No output)")
  }
}

///|
async test "debug_simple_triple 2" {
  // 1. 准备最简单的 Turtle 输入
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  let data = @utf8.encode(input).to_array()

  // 2. 创建解析器
  let prefixes = Map([])
  let base_iri = None

  let parser = TriGRecognizer::new_parser(
    data, true, // is_ending
     false, // with_graph_name
     false, // lenient
     base_iri, prefixes,
  )

  // 3. 解析并打印每一步
  let mut step = 0
  for ;; {
    step += 1
    debug("\n=== Step \{step} ===")

    // 修复：移除对 lexer.last_token() 等不存在方法的调用
    // 如果 RdfLexer 有公开的 current_token 或 peek 方法，可在此处添加
    // 例如: if let Some(tok) = parser.lexer.peek() { debug("Current token: \{tok}") }

    // 获取当前状态 (这是更可靠的调试信息来源)
    match parser.state {
      Some(state) => {
        debug("State stack depth: \{state.stack.length()}")
        debug("Current object: \{state.to_string()}")
      }
      None => debug("No active state")
    }

    // 解析下一个
    match parser.parse_next() {
      Some(Ok(t)) => debug("✓ Parsed quad: \{t.to_string()}")
      Some(Err(e)) => {
        debug("Error: \{e.to_string()}")
        break
      }
      None => {
        debug("Need more input or end of file")
        break
      }
    }
  }
}


///|
async test "verify_with_turtle" {
  // N-Triples 格式相同
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  let data = @utf8.encode(input)

  let parser = TurtleParser::new().lenient()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)
  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("Turtle Success:\{t.to_string()} ")
    Some(Err(e)) => debug("Turtle Error: \{e.to_string()}")
    None => debug("Turtle None")
  }
}
// test "write" {
//   let mut serializer = TurtleSerializer::new().for_writer([])
//   serializer.serialize_triple(TripleRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p"), NamedNodeRef::new_unchecked("http://example.com/o")))
//   serializer.serialize_triple(TripleRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p"), LiteralRef::new_simple_literal("foo")))
//   serializer.serialize_triple(TripleRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p2"), LiteralRef::new_language_tagged_literal_unchecked("foo", "en")))
//   serializer.serialize_triple(TripleRef::new(BlankNodeRef::new_unchecked("b"), NamedNodeRef::new_unchecked("http://example.com/p2"), BlankNodeRef::new_unchecked("b2")))
//   assert_eq(String::from_utf8(serializer.finish()).map_err(io::Error::other), "<http://example.com/s> <http://example.com/p> <http://example.com/o> , "foo" ;
// 	<http://example.com/p2> "foo"@en .
// _:b <http://example.com/p2> _:b2 .
// ")
//   Ok(())
// }
