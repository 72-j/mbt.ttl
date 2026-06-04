// test "lenient parsing" {
//   let triples = NTriplesParser::new().lenient().for_reader("<foo> <bar> "baz"@toolonglangtag .".to_bytes()).unwrap()
//   assert_eq(triples, [Triple::new(NamedNode::new_unchecked("foo"), NamedNode::new_unchecked("bar"), Literal::new_language_tagged_literal_unchecked("baz", "toolonglangtag"))])
// }
