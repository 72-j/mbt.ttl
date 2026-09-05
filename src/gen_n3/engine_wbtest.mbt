// 白盒测试：engine.mbt 主循环 × actions.mbt 行为钉死（4E-1/4E-2 验收）
// 口径：span 级断言（materializer 未落地，quad = N3PendingQuad span 快照）；
//       事件流词法口径另见 n3_wbtest.mbt（Step 3，7/7）。

///|
fn bytes_of(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
fn view_str(data : ArrayView[Byte], span : (Int, Int)) -> String {
  let (off, len) = span
  let buf = StringBuilder()
  for i in 0..<len {
    buf.write_char(data[off + i].to_char())
  }
  buf.to_string()
}

///|
/// 全排水：next() 到 None，quads/errors 分箱
fn drain_n3(
  engine : N3Engine[N3LexerAdapter],
) -> (Array[N3PendingQuad], Array[ParseError]) {
  let quads = []
  let errors = []
  while true {
    match engine.next() {
      Some(Ok(q)) => quads.push(q)
      Some(Err(e)) => errors.push(e)
      None => break
    }
  }
  (quads, errors)
}

///|
test "骨架: 简单三元组，span 往返" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  let q = quads[0]
  assert_eq(view_str(data[:], q.subj.unwrap()), "<http://example.org/s>")
  assert_eq(view_str(data[:], q.pred.unwrap()), "<http://example.org/p>")
  assert_eq(view_str(data[:], q.obj.unwrap()), "<http://example.org/o>")
  assert_true(q.graph is None)
  assert_true(q.pk is PredKind::Normal)
}

///|
test "骨架: Comma 合成（langtag 零空格吞逗号）" {
  let input = "<http://s> <http://p> \"x\"@en, \"y\" .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  assert_eq(view_str(data[:], quads[0].obj.unwrap()), "\"x\"@en")
  assert_eq(view_str(data[:], quads[1].obj.unwrap()), "\"y\"")
}

///|
test "骨架: Semicolon 合成 + 数值零空格吞分号" {
  let input = "<http://s> <http://p> 1;<http://p2> 2 .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  assert_eq(view_str(data[:], quads[0].obj.unwrap()), "1")
  assert_eq(view_str(data[:], quads[1].obj.unwrap()), "2")
}

///|
test "骨架: 空集合 = nil 标记（ADR-003a 空特判）" {
  let input = "<http://s> <http://p> ( ) .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  let o = quads[0].obj.unwrap()
  // nil 标记：恰在 `(` 偏移、零长 span（物化层识别位）
  assert_eq(o.1, 0)
  assert_eq(o.0, 22)
}

///|
test "骨架: 非空集合 = 单一 BNode，零链 quad（ADR-003a）" {
  let input = "<http://s> <http://p> ( <http://a> <http://b> ) .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 无 rdf:first/rest 链发射：语句四元组即全部
  assert_eq(quads.length(), 1)
  let o = quads[0].obj.unwrap()
  // 单一 BNode = `(` 自身 span
  assert_eq(o.0, 22)
  assert_eq(o.1, 1)
}

///|
test "骨架: bnp 属性列表 = 内部 quad + 身份落 o 槽" {
  let input = "<http://s> <http://p> [ <http://p2> <http://o2> ] .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  let id = (22, 1)
  // 内部 quad：s = `[` 自身
  assert_eq(quads[0].subj.unwrap(), id)
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<http://p2>")
  assert_eq(view_str(data[:], quads[0].obj.unwrap()), "<http://o2>")
  // statement quad：o = `[` 身份
  assert_eq(quads[1].obj.unwrap(), id)
}

///|
test "骨架: EOF 判脏 + 自排水" {
  let input = "<http://s> <http://p>"
  let data = bytes_of(input)
  let engine = N3Engine::from_bytes(data)
  let mut err_count = 0
  while true {
    match engine.next() {
      Some(Err(_)) => err_count = err_count + 1
      Some(Ok(_)) => fail("dirty EOF must not emit quad")
      None => break
    }
  }
  assert_eq(err_count, 1)
}

///|
test "骨架: @prefix 账本 pver" {
  let input = "@prefix : <http://ex/> .\n:s :p :o .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].pver, 1)
}

///|
test "骨架: 恢复：垃圾跳到 Dot，后续语句存活" {
  let input = "<http://s> <http://p> % .\n<http://s2> <http://p2> <http://o2> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(view_str(data[:], quads[0].subj.unwrap()), "<http://s2>")
}


test "切片: 端到端 n3_parser（前缀 + 集合宾位）" {
  let input = "@prefix : <http://ex/> .\n:s :p ( 1 2 ) .\n"
  let data = bytes_of(input)
  let (quads, errors) = n3_parser(data)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(view_str(data[:], quads[0].s), ":s")
  assert_eq(view_str(data[:], quads[0].p), ":p")
  // 集合单一 BNode = `(` span（开括号即身份）
  let o = quads[0].o
  assert_eq(o.1, 1)
  assert_eq(quads[0].pver, 1)
  assert_true(quads[0].g is None)
}

test "切片: 未声明前缀拒绝" {
  let data = bytes_of(":x :y :z .\n")
  let (quads, errors) = n3_parser(data)
  assert_eq(quads.length(), 0)
  assert_eq(errors.length(), 1)
}

test "切片: `[] .` 谓语缺位 = 非法文法（trig wbtest:500 同口径）" {
  let input = "[] .\n<http://s> <http://p> <http://o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = n3_parser(data)
  // 谓语缺位拒绝。触发事件就是 Dot 本身（已消费），恢复吞到下一 Dot：
  // 后续语句同段被吃——恢复消费语义的固有形态（trig 同款，事件即恢复锚）
  assert_eq(errors.length(), 1)
  assert_eq(quads.length(), 0)
}
