///|
/// 创建 N-Quads Parser
pub fn nquads_parser(
  data : FixedArray[Byte],
) -> @lib.ParserE[@lib.NQuadsEngine] {
  let engine = @lib.NQuadsEngine::new()
  @lib.ParserE::from_bytes(data, engine)
}

///|
test "nquads: basic triple with dot" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()
  let parser = nquads_parser(data)

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

///|
test "nquads: multiple triples" {
  let data =
    #|<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .
    #|<http://ex.org/s2> <http://ex.org/p2> <http://ex.org/o2> .
    #|<http://ex.org/s3> <http://ex.org/p3> <http://ex.org/o3> <http://ex.org/g3> .
    #|
  let data = @utf8.encode(data).to_fixedarray()
  let parser = nquads_parser(data)

  match parser.next() {
    Some(Ok(pending)) => {
      assert_true(pending.subj is Some(_))
      assert_true(pending.pred is Some(_))
      assert_true(pending.obj is Some(_))
      debug("first quad ok")
    }
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }

  match parser.next() {
    Some(Ok(pending)) => {
      assert_true(pending.subj is Some(_))
      debug("second quad ok")
    }
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
  match parser.next() {
    Some(Ok(pending)) => {
      assert_true(pending.subj is Some(_))
      debug("second quad ok")
    }
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }

  // EOF
  match parser.next() {
    None => debug("EOF ok")
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}

///|
test "nquads: triple without dot" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o>",
  ).to_fixedarray()
  let parser = nquads_parser(data)

  match parser.next() {
    Some(Ok(pending)) => {
      assert_true(pending.is_complete())
      debug("implicit dot ok")
    }
    Some(Err(err)) => debug("Error: \{err}")
    None => debug("EOF")
  }
}

///|
test "nquads: empty input" {
  let data = @utf8.encode("").to_fixedarray()
  let parser = nquads_parser(data)

  match parser.next() {
    Some(Ok(pending)) => debug("Unexpected: \{pending}")
    Some(Err(err)) => debug("Error: \{err}")
    None => debug("EOF ok")
  }
}

// ///|
// test "nquads: parse_all with errors" {
//   let data =
//     #|<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .
//     #|<http://ex.org/s2> <http://ex.org/p2> <http://ex.org/o2> <http://ex.org/g> .
//     #|<http://ex.org/s3> <http://ex.org/p3> <http://ex.org/o3> .
//   let data = @utf8.encode(data).to_fixedarray()
//   // let engine = @lib.NQuadsEngine::new()
//   let parser = @lib.NQuadsEngine::from_bytes(data)

//   let (results, errors) = parser.parse_all()

//   // 第二个 quad 有额外 token，应该被跳过，保留第一个和第三个
//   assert_eq(results.length(), 2)
//   debug("errors: \{errors.length()}")
//   debug("parse_all with errors ok")
// }
