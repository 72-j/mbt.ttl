// 白盒测试：serialize_n3.mbt 序列化层（役27a 自生产文件迁入，R-11 测试归位）

///|
test "序列化: 基本语句回写" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let quad : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  match N3Serializer::new().serialize([quad]) {
    Ok(out) =>
      assert_eq(out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n")
    Err(_) => assert_false(true)
  }
}

///|
test "序列化: PrefName 残留报错钉住" {
  let s = @utf8.encode("ex:name").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let bad : @nquads.QuadEmit = {
    subject: PrefName(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  assert_true(N3Serializer::new().serialize([bad]) is Err(_))
}

///|
test "序列化: 图名残留报错钉住（N3 无图语法）" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let g = @utf8.encode("<http://e.org/g>").to_array()
  let bad : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: Iri(g[:]),
  }
  assert_true(N3Serializer::new().serialize([bad]) is Err(_))
}

///|
test "序列化: 全链路 解析→物化→N3Serializer（前缀展开 + 集合 genid）" {
  let (emits, errors) = parse_materialize(
    "@prefix ex: <http://example/> .\nex:s ex:p ( 1 2 ) .\n",
  )
  assert_eq(errors.length(), 0)
  match N3Serializer::new().serialize(emits) {
    Ok(out) =>
      assert_eq(out, "<http://example/s> <http://example/p> _:genid42 .\n")
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}
