///|
async test "debug_trig_subj_only" {
  // 只有 Subject
  let input = "<http://a/b>"
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = None

  let parser = TriGRecognizer::new_parser(
    data,
    true, // is_ending
    false, // with_graph_name
    false, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  // inspect("Initial State: \{parser.state}")

  match parser.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }

  // inspect("Final State: \{parser.state}")
}

///|
async test "debug_trig_complete_triple" {
  // 完整的三元组：Subject Predicate Object .
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()
  debug("Input length: \{input.length()}")
  let prefixes = Map([])
  let base_iri = None

  let parser = TriGRecognizer::new_parser(
    data,
    true, // is_ending
    false, // with_graph_name
    false, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  // debug("Initial State: \{parser.state}")

  match parser.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }

  // debug("Final State: \{parser.state}")
}

///|
async test "debug_trig_complete_triple_newline" {
  // 完整的三元组 + 换行符
  let input = "<http://a/b> <http://a/c> <http://a/d> .\n"
  let data = @utf8.encode(input).to_array()

  let prefixes = Map([])
  let base_iri = None

  let parser = TriGRecognizer::new_parser(
    data,
    true, // is_ending
    false, // with_graph_name
    false, // lenient
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  match parser.parse_next() {
    Some(Ok(t)) => debug("✓ Success: \{t.to_string()}")
    Some(Err(e)) => debug("✗ Error: \{e.to_string()}")
    None => debug("⚠ None")
  }
}

///|
async test "debug_lexer_tokens" {
  let input = "<http://a/b> <http://a/c> <http://a/d> ."
  let data = @utf8.encode(input).to_array()

  // 假设你有一个可以直接访问 Lexer 的方法，或者通过解析器的 debug 日志
  // 如果没有，请在 TriGRecognizer 的主循环中打印每个消耗的 token
  debug("Input: \{input}")

  // 运行解析器，但依靠已有的 [INFO] 日志来观察 Token
  let prefixes = Map([])
  let base_iri = None
  let parser = TriGRecognizer::new_parser(
    data,
    true,
    false,
    false,
    base_iri,
    prefixes,
    debug_logger=make_console_logger(),
  )

  // 尝试解析，观察日志中出现的 Token 顺序
  for ;; {
    match parser.parse_next() {
      Some(Ok(t)) => {
        debug("Parsed: \{t}")
        break
      }
      Some(Err(e)) => {
        debug("Error: \{e}")
        break
      }
      None => {
        debug("None")
        break
      }
    }
  }
}
// test "write" {
//   let mut serializer = TriGSerializer::new().with_prefix("ex", "http://example.com/").map_err(io::Error::other)!.with_prefix("exl", "http://example.com/p/").map_err(io::Error::other)!.for_writer([])
//   serializer.serialize_quad(QuadRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p"), NamedNodeRef::new_unchecked("http://example.com/p/o."), NamedNodeRef::new_unchecked("http://example.com/g")))!
//   serializer.serialize_quad(QuadRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p"), NamedNodeRef::new_unchecked("http://example.com/o{o}"), NamedNodeRef::new_unchecked("http://example.com/g")))!
//   serializer.serialize_quad(QuadRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p"), NamedNodeRef::new_unchecked("http://example.com/"), NamedNodeRef::new_unchecked("http://example.com/g")))!
//   serializer.serialize_quad(QuadRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p"), LiteralRef::new_simple_literal("foo"), NamedNodeRef::new_unchecked("http://example.com/g")))!
//   serializer.serialize_quad(QuadRef::new(NamedNodeRef::new_unchecked("http://example.com/s"), NamedNodeRef::new_unchecked("http://example.com/p2"), LiteralRef::new_language_tagged_literal_unchecked("foo", "en"), NamedNodeRef::new_unchecked("http://example.com/g")))!
//   serializer.serialize_quad(QuadRef::new(BlankNodeRef::new_unchecked("b"), NamedNodeRef::new_unchecked("http://example.com/p2"), BlankNodeRef::new_unchecked("b2"), NamedNodeRef::new_unchecked("http://example.com/g")))!
//   serializer.serialize_quad(QuadRef::new(BlankNodeRef::new_unchecked("b"), NamedNodeRef::new_unchecked("http://example.com/p2"), LiteralRef::new_typed_literal("true", xsd::BOOLEAN), GraphNameRef::DefaultGraph))!
//   serializer.serialize_quad(QuadRef::new(BlankNodeRef::new_unchecked("b"), NamedNodeRef::new_unchecked("http://example.org/p2"), LiteralRef::new_typed_literal("false", xsd::BOOLEAN), NamedNodeRef::new_unchecked("http://example.com/g2")))!
//   assert_eq(String::from_utf8(serializer.finish()!).map_err(io::Error::other)!, "@prefix exl: <http://example.com/p/> .
// @prefix ex: <http://example.com/> .
// ex:g {
// 	ex:s ex:p exl:o\. , <http://example.com/o{o}> , ex: , "foo" ;
// 		ex:p2 "foo"@en .
// 	_:b ex:p2 _:b2 .
// }
// _:b ex:p2 true .
// ex:g2 {
// 	_:b <http://example.org/p2> false .
// }
// ")
//   Ok(())
// }
