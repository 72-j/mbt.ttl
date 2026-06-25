///|
async test "debug_n3_implies" {
  // N3 蕴含语法: { Subject Predicate Object } => { Subject Predicate Object } .
  let input = "{ <http://example.org/s> <http://example.org/p> <http://example.org/o> } => { <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> } ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/"))

  // N3 通常需要更宽松的模式或特定的 N3 标志，这里假设 N3Recognizer 能处理基础 N3 结构
  let parser = N3Recognizer::new_parser(
    data,
    true, // is_ending
    true, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Implies Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Implies Error: \{e.to_string()}")
    None => debug("N3 Implies None")
  }
}

///|
async test "debug_n3_forall" {
  // N3 全称量词: @forAll <x> .
  let input = "@forAll <http://example.org/x> . <http://example.org/s> <http://example.org/p> <http://example.org/x> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/"))

  let parser = N3Recognizer::new_parser(
    data,
    true, // is_ending
    true, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 ForAll Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 ForAll Error: \{e.to_string()}")
    None => debug("N3 ForAll None")
  }
}

///|
async test "debug_n3_path_alternative" {
  // N3 路径交替: <s> (<p1>|<p2>) <o> .
  // 注意：这取决于 lexer_trig_1r.mbt 是否实现了 N3 路径语法解析
  let input = "<http://example.org/s> (<http://example.org/p1>|<http://example.org/p2>) <http://example.org/o> ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/"))

  let parser = N3Recognizer::new_parser(
    data,
    true, // is_ending
    true, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Path Alt Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Path Alt Error: \{e.to_string()}")
    None => debug("N3 Path Alt None")
  }
}

///|
async test "debug_n3_literal_complex" {
  // N3 支持更复杂的字面量，如 XML Literal 或 Formula literals (如果实现的话)
  // 这里测试一个标准的带语言标签和类型的复杂情况，确保 N3 模式下兼容
  let input =
  #|<http://example.org/s> <http://example.org/p> "Simple String"@en-us .
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/"))

  let parser = N3Recognizer::new_parser(
    data,
    true, // is_ending
    true, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Literal Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Literal Error: \{e.to_string()}")
    None => debug("N3 Literal None")
  }
}

///|
async test "debug_n3_nested_formula" {
  // N3 嵌套公式作为宾语: <s> <p> { <s2> <p2> <o2> } .
  let input = "<http://example.org/s> <http://example.org/p> { <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> } ."
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = Some(Iri::Iri("http://example.org/"))

  let parser = N3Recognizer::new_parser(
    data,
    true, // is_ending
    true, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("N3 Nested Formula Success: \{t.to_string()}")
    Some(Err(e)) => debug("N3 Nested Formula Error: \{e.to_string()}")
    None => debug("N3 Nested Formula None")
  }
}