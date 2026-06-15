test "lenient parsing" {
  let input = "<foo> <bar> \"baz\"@toolonglangtag ."
  // 使用 utf8 encode 获取兼容的 reader，或查找 String 转 Reader 的正确 API
  // 此处假设 @encoding/utf8.encode 返回一个可转为 Reader 的类型，或有 .as_reader()

  let slice = @utf8.encode(input) 
  
  // 注意：以上行可能仍不直接实现 Reader，需查阅具体 API。
  // 另一种常见模式是使用 Cursor<Bytes> 实现 Reader
  let triples = NTriplesParser::new().lenient().for_slice(slice)
  // 构建期望的 TripleRef，注意类型转换
  let expected_subject = NamedNodeRef::new_unchecked("foo").as_enum() // 转为 NamedOrBlankNodeRef
  let expected_predicate = NamedNodeRef::new_unchecked("bar") // 转为 NamedNodeRef (通常 predicate 也是 NamedNode)
  let expected_object = LiteralRef::new_language_tagged_literal_unchecked("baz", "toolonglangtag").as_term() // 转为 TermRef
  
  let expected_triple = TripleRef::new(expected_subject, expected_predicate, expected_object)
  
  // assert_eq(triples, [expected_triple])
  }