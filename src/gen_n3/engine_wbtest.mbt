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

///|
test "役1: 公式主位——内容零发射，身份 = { span" {
  let input = "{ <a> <b> <c> } <p> <o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // ADR-002：花括号内三元组不断言——内容零 quad；statement 一条
  assert_eq(quads.length(), 1)
  // 公式身份 = { 自身 span（无 nil 特判，() 集合口径除外）
  assert_eq(quads[0].subj.unwrap(), (0, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<p>")
  assert_eq(view_str(data[:], quads[0].obj.unwrap()), "<o>")
}

///|
test "役1: 公式宾位——内容零发射，身份 = { span" {
  let input = "<s> <p> { <a> <b> <c> } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // 身份 = { span（offset 8）
  assert_eq(quads[0].obj.unwrap(), (8, 1))
}

///|
test "役1: 空公式 { } 主位——同占位身份，无 nil 特判" {
  let input = "{ } <p> <o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // 空公式身份 = { span（与 () 的 rdf:nil 零长标记分野）
  assert_eq(quads[0].subj.unwrap(), (0, 1))
}

///|
test "役1: 公式内 Comma/Semicolon 只收拾不发射" {
  let input = "{ <a> <b> <c>, <d> ; <q> <r> } <p> <o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 公式状态自身零 EmitQuad 行（决策在表）：内容多语句也零发射
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (0, 1))
}

///|
test "役1: Bnp 罩内收口压制——公式帧在罩，EmitQuad 降级纯收拾" {
  let input = "<s> <p> { [ <q> <r> ] <P> <O> } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // ] 共享行的 EmitQuad(PredObj) 在公式罩内被压制：bnp 内部 quad 不泄漏
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].obj.unwrap(), (8, 1))
  // 公式帧快照恢复外层槽位：statement = <s> <p> { }（<P>/<O> 是罩内被压制的内层语句）
  assert_eq(view_str(data[:], quads[0].subj.unwrap()), "<s>")
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<p>")
}

///|
test "役1: 集合元素公式——list_first_nested 开公式帧" {
  let input = "<s> <p> ( { <a> <b> <c> } ) .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // 集合单一 BNode = ( 自身 span
  assert_eq(quads[0].obj.unwrap(), (8, 1))
}

///|
test "役1: 嵌套公式（内层带动词）——内层语句同被罩内压制" {
  let input = "<s> <p> { { <a> <b> <c> } <q> <r> } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // 身份 = 外层 { span
  assert_eq(quads[0].obj.unwrap(), (8, 1))
}

///|
test "役1: Bnp 内公式宾位正常发射（非压制对照）" {
  let input = "<s> <p> [ <q> { <a> <b> <c> } ] .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 公式已 ] 前收口：] 共享行 EmitQuad 不在罩内 → bnp 内部 quad 照常发射
  assert_eq(quads.length(), 2)
  // [0] = bnp 内部 quad：s = [ span(8,1)，o = 公式身份(14,1)
  assert_eq(quads[0].subj.unwrap(), (8, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<q>")
  assert_eq(quads[0].obj.unwrap(), (14, 1))
  // [1] = statement：o = [ 身份
  assert_eq(quads[1].obj.unwrap(), (8, 1))
}

///|
test "役2: 变量主/宾位——只记身份 span" {
  let input = "?s <p> ?o .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // ADR-004：变量名与位置即全部语义——span 原样持有（?s = (0,2)）
  assert_eq(quads[0].subj.unwrap(), (0, 2))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<p>")
  assert_eq(quads[0].obj.unwrap(), (7, 2))
}

///|
test "役2: 公式内变量——罩内零发射" {
  let input = "<s> <p> { ?x <q> ?y } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 公式内容零 quad（ADR-002），statement 一条
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].obj.unwrap(), (8, 1))
}

///|
test "役2: 集合元素变量 + bnp 宾位变量" {
  let input = "<s> <p> ( ?x <y> ) .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 集合单一 BNode = ( 自身 span（ADR-003a，元素只记账）
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].obj.unwrap(), (8, 1))
  let input2 = "<s> <p> [ <q> ?o ] .\n"
  let data2 = bytes_of(input2)
  let (quads2, errors2) = drain_n3(N3Engine::from_bytes(data2))
  assert_eq(errors2.length(), 0)
  // bnp 内部 quad + statement
  assert_eq(quads2.length(), 2)
  assert_eq(quads2[0].obj.unwrap(), (14, 2))
  assert_eq(quads2[1].obj.unwrap(), (8, 1))
}

///|
test "役2: 全链路 round-trip——变量字节保真回写" {
  // 绝对 IRI：mat_chain 无 base_fallback（相对 IRI 落 base-bad 桶）
  let (emits, errors) = mat_chain("?s <http://p> ?o .\n")
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  match N3Serializer::new().serialize(emits) {
    Ok(out) => assert_eq(out, "?s <http://p> ?o .\n")
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}

///|
test "役2: 谓词位变量显式拒绝" {
  let (quads, errors) = n3_parser(bytes_of("<s> ?p <o> .\n"))
  assert_eq(quads.length(), 0)
  assert_eq(errors.length(), 1)
}
