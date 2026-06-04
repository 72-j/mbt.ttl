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
