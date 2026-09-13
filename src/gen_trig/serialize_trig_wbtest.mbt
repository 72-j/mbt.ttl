// ===== 序列化用例（T14 归位：自 serialize_trig.mbt 迁出）=====

///|
test "序列化: TriG 默认图先输出 + 命名图按内容归并（首次出现序）" {
  let s1 = @utf8.encode("<http://e.org/s>").to_array()
  let p1 = @utf8.encode("<http://e.org/p>").to_array()
  let o1 = @utf8.encode("<http://e.org/o>").to_array()
  let s2 = @utf8.encode("<http://e.org/s2>").to_array()
  let p2 = @utf8.encode("<http://e.org/p2>").to_array()
  let o2 = @utf8.encode("<http://e.org/o2>").to_array()
  let s3 = @utf8.encode("<http://e.org/s3>").to_array()
  let g1a = @utf8.encode("<http://e.org/g>").to_array()
  // 同一图名的两份不同切片（模拟 arena 展开 vs 原 data）——按内容归并
  let g1b = @utf8.encode("<http://e.org/").to_array() +
    @utf8.encode("g>").to_array()
  let g2 = @utf8.encode("<http://e.org/h>").to_array()
  let quads : Array[@nquads.QuadEmit] = [
    { subject: Iri(s1[:]), predicate: p1[:], object: Iri(o1[:]), graph: None, },
    {
      subject: Iri(s2[:]),
      predicate: p2[:],
      object: Iri(o2[:]),
      graph: Iri(g1a[:]),
    },
    {
      subject: Iri(s3[:]),
      predicate: p2[:],
      object: Iri(o2[:]),
      graph: Iri(g1b[:]),
    },
    {
      subject: Iri(s1[:]),
      predicate: p1[:],
      object: Iri(o1[:]),
      graph: Iri(g2[:]),
    },
  ]
  let ser = TrigSerializer::new() // 默认 TriG + Strict
  match ser.serialize(quads) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n<http://e.org/g> {\n  <http://e.org/s2> <http://e.org/p2> <http://e.org/o2> .\n  <http://e.org/s3> <http://e.org/p2> <http://e.org/o2> .\n}\n<http://e.org/h> {\n  <http://e.org/s> <http://e.org/p> <http://e.org/o> .\n}\n",
      )
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}

///|
test "序列化: Turtle 开关——Strict 阻断图名 / Drop 有损丢弃（默认图不受影响）" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let g = @utf8.encode("<http://e.org/g>").to_array()
  let named : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: Iri(g[:]),
  }
  let plain : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  // Turtle + Strict（默认）：图名阻断
  let strict = TrigSerializer::new(format=Turtle)
  assert_true(strict.serialize([named, plain]) is Err(_))
  // Turtle + Drop：图名丢弃，其余照写
  let drop = TrigSerializer::new(format=Turtle, graph_policy=Drop)
  match drop.serialize([named, plain]) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n",
      )
    Err(_) => assert_false(true)
  }
}

///|
test "序列化: PrefName 残留报错钉住（主语/宾语位）" {
  let s = @utf8.encode("ex:name").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let bad_subj : @nquads.QuadEmit = {
    subject: PrefName(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  let bad_obj : @nquads.QuadEmit = {
    subject: Iri(o[:]),
    predicate: p[:],
    object: PrefName(s[:]),
    graph: None,
  }
  let ser = TrigSerializer::new()
  assert_true(ser.serialize([bad_subj]) is Err(_))
  assert_true(ser.serialize([bad_obj]) is Err(_))
}

///|
test "序列化: 引用三元组壳整段回写" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let tt = @utf8.encode("<< <http://a> <http://b> <http://c> >>").to_array()
  let quad : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: TripleTerm(tt[:]),
    graph: None,
  }
  let ser = TrigSerializer::new()
  match ser.serialize([quad]) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> << <http://a> <http://b> <http://c> >> .\n",
      )
    Err(_) => assert_false(true)
  }
}

///|
test "序列化: 全链路 解析→物化→TrigSerializer（前缀展开 + 数值 + 图块区）" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p ex:o .\nex:g { ex:s2 ex:p2 42 . }\n",
  )
  assert_eq(errors.length(), 0)
  let ser = TrigSerializer::new()
  match ser.serialize(emits) {
    Ok(out) =>
      assert_eq(
        out, "<http://example/s> <http://example/p> <http://example/o> .\n<http://example/g> {\n  <http://example/s2> <http://example/p2> \"42\"^^<http://www.w3.org/2001/XMLSchema#integer> .\n}\n",
      )
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}
