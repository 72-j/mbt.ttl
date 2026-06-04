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
