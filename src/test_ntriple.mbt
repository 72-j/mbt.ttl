// test "lenient parsing" {
//   let triples = NTriplesParser::new().lenient().for_reader("<foo> <bar> \"baz\"@toolonglangtag .".to_bytes()).unwrap()
//   assert_eq(triples, [TripleRef::new(NamedNodeRef::new_unchecked("foo"), NamedNodeRef::new_unchecked("bar"), LiteralRef::new_language_tagged_literal_unchecked("baz", "toolonglangtag"))])
// }
