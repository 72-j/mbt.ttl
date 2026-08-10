///|
test "basic token parsing" {
  let input = "<subject> <predicate> <object>"
  let data = @utf8.encode(input).to_fixedarray()

  debug("input: '\{input}'")
  debug("data length: \{data.length()}")

  let lexer = @lib.Lexerc::new(data)

  let tok1 = lexer.next()
  debug("tok1: \{@debug.to_string(tok1)}")

  let tok2 = lexer.next()
  debug("tok2: \{@debug.to_string(tok2)}")

  let tok3 = lexer.next()
  debug("tok3: \{@debug.to_string(tok3)}")

  lexer.destroy()
}
