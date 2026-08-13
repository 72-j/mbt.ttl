///|
/// 创建 N-Quads Parser

///|
test "nquads: basic triple with dot" {
  let data =
    #| <http://a.example/s> <http://a.example/p> "true"^^<http://www.w3.org/2001/XMLSchema#boolean> .

  let data = @utf8.encode(data).to_fixedarray()
  let parser = @lib.nquads_parser(data)

  match parser.next() {
    Some(Ok(pending)) =>
      // 验证各部分
      debug(pending)
    Some(Err(err)) => debug(err)
    None => debug("EOF")
  }

  // EOF
  match parser.next() {
    None => debug("EOF ok")
    Some(Err(err)) => debug(err)
    Some(Ok(pending)) => debug(pending)
  }
}

// async test "collect tokens" {
//       let path = "./test_1000.nq"
//   let path = if @fs.exists(path) {
//     path
//   } else {
//     "./src/benchmark/test_1000.nq"
//   }
//   let content = @fs.read_file(path).binary()
//   let bytes = content.to_fixedarray()
//   let data = bytes
//   let start1 = @bench.monotonic_clock_start()
//   let lexer = @lib.Lexerc::new(data)
//   let tokens = lexer.collect()
//   let elapsed1 = @bench.monotonic_clock_end(start1)

//   debug("Tokens: \{tokens.length()}")
//   debug("Lexer elapsed: \{elapsed1}")
//   lexer.destroy()
// }
