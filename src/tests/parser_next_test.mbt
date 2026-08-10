///|
/// 创建 N-Quads Parser

///|
test "nquads: basic triple with dot" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()
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
