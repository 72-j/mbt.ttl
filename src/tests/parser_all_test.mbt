///|
/// 带图名的三元组
test "nquads: valid triple with graph" {
  let data = "<http://example/s> <http://example/p> <http://example/o> <http://example/g> ."
  let bytes = @utf8.encode(data).to_fixedarray()
  let engine = @lib.NQuadsEngine::from_bytes(bytes)
  let parser = @lib.SliceParser::new(engine, bytes)

  let (quads, errs) = parser.parse_all()

  @debug.assert_eq(quads.length(), 1)
  @debug.assert_eq(errs.length(), 0)
}
