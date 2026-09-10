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

///|
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

///|
test "切片: 未声明前缀拒绝" {
  let data = bytes_of(":x :y :z .\n")
  let (quads, errors) = n3_parser(data)
  assert_eq(quads.length(), 0)
  assert_eq(errors.length(), 1)
}

///|
test "切片: `[] .` 零谓词 bnp 合法（役10 零谓词收口，trig 不受影响）" {
  let input = "[] .\n<http://s> <http://p> <http://o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = n3_parser(data)
  // 役10 零谓词收口：`[] .` 与 `[:c :d] .` 同径——空属性列表 = 零谓词裸
  // 节点语句，bnp 帧空形式弹栈后 Dot 走零发射收口；后句照常发射 q=1
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
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

///|
test "役3: 公式罩内路径——内容零发射，statement 身份 = { span" {
  // 官方形（罩内完整语句含路径跳）：罩内 desugar 全被压制（ADR-002 同口径）
  let input = "<s> <p> { <a> !<b> <c> <d> } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 罩内路径零发射；statement 一条，宾位 = 公式身份（{ span）
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].obj.unwrap(), (8, 1))
  // 罩内直连形（a !b c 无宾）官方非法 → 表无行静默兜底：外层 statement 一并零出
  let input2 = "<s> <p> { <a> !<b> <c> } .\n"
  let (quads2, errors2) = drain_n3(N3Engine::from_bytes(bytes_of(input2)))
  assert_eq(errors2.length(), 0)
  assert_eq(quads2.length(), 0)
}

///|
test "役3: 公式罩内基动词 !——急兑现 EmitQuad 同被罩内压制" {
  let input = "{ <a> <b> !<c> <d> } <p> <o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 罩内基跳急兑现走同一 suppression 单点（役1 决策在表）；statement 一条
  assert_eq(quads.length(), 1)
  // statement 主语 = 公式身份（{ 在 offset 0）
  assert_eq(quads[0].subj.unwrap(), (0, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<p>")
  assert_eq(view_str(data[:], quads[0].obj.unwrap()), "<o>")
}

///|
test "役3: 公式主位路径——! 链从公式身份起步" {
  // 官方形：跳后随真谓词 + 宾语（{ <a> } 裸主语公式非法——Rbrace 在
  // FormulaExpectPredicate 无行，`[] .` 同口径——用完整内层语句）
  let input = "{ <a> <b> <c> } !<p> <q> <o> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 公式主语跳：(F,<p>,g) + (g,<q>,<o>)；F = { span（罩内零发射后身份落主位槽）
  assert_eq(quads.length(), 2)
  assert_eq(quads[0].subj.unwrap(), (0, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<p>")
  // fresh = 操作符 span（引擎层快照；genid 化在物化层）
  assert_eq(view_str(data[:], quads[1].subj.unwrap()), "!")
  assert_eq(view_str(data[:], quads[1].pred.unwrap()), "<q>")
  assert_eq(view_str(data[:], quads[1].obj.unwrap()), "<o>")
}

///|
test "役3: 反向路径复合末跳拒绝——基跳急兑现先落，连接边不出" {
  let input = "<http://ex/s> ^<http://ex/p> [ <http://ex/q> <http://ex/r> ] .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  // 直连形（路径主语后无真谓词）官方非法 → 表无行静默兜底：零错误零出账
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 0)
  // 基动词变体：基跳急兑现先于末跳拒绝已落（同 bnp 内部 quad 先落口径）
  let input2 = "<http://ex/s> <http://ex/p>^<http://ex/q> [ <http://ex/r> <http://ex/t> ] .\n"
  let data2 = bytes_of(input2)
  let (quads2, errors2) = drain_n3(N3Engine::from_bytes(data2))
  assert_eq(errors2.length(), 1)
  assert_eq(quads2.length(), 1)
  assert_eq(view_str(data2[:], quads2[0].subj.unwrap()), "<http://ex/s>")
  assert_eq(view_str(data2[:], quads2[0].pred.unwrap()), "<http://ex/p>")
  // 引擎层 = span 快照：基跳宾位 = ^ token span 本身（genid 化在物化层）
  assert_eq(view_str(data2[:], quads2[0].obj.unwrap()), "^")
}

///|
test "役4: 正向规则——({A}, =>span, {B}) 单 quad，操作符即谓词身份" {
  let input = "{ <a> <b> <c> } => { <d> <e> <f> } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 罩内两侧内容零发射（ADR-002），规则语句一条
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (0, 1))
  // 谓词 = => token span（规则方向自描述，rule_side 无需占用）
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "=>")
  assert_eq(quads[0].obj.unwrap(), (19, 1))
}

///|
test "役4: 反向规则——<= 同构，谓词 span 即方向" {
  let input = "{ <a> <b> <c> } <= { <d> <e> <f> } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (0, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "<=")
  assert_eq(quads[0].obj.unwrap(), (19, 1))
}

///|
test "役4: 公式罩内嵌套规则——内层语句同被罩内压制" {
  let input = "<s> <p> { { <a> <b> <c> } => { <d> <e> <f> } } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 内层规则零 quad；statement 一条，o = 外层 { 身份（offset 8）
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].obj.unwrap(), (8, 1))
  assert_eq(view_str(data[:], quads[0].subj.unwrap()), "<s>")
}

///|
test "役4: 变量体规则——役2 只记身份 × 役4 规则谓词同帧" {
  let input = "{ ?x <a> ?y } => { ?y <b> ?x } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (0, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "=>")
  // RHS { 身份（offset 17）
  assert_eq(quads[0].obj.unwrap(), (17, 1))
}

///|
test "役10: 裸规则形式合法化——`<a> => <b> .` 即普通三元组" {
  let input = "<a> => <b> .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  // 役10：官方 manifest 翻案——操作符即普通谓词（verb ::= expression），
  // ExpectPredicate+Implies 行落槽；规则罩形态役4 行继续并行
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
}

///|
test "役5: listed 词谓词位——台账命中 Unknown→KeywordX，词性 = 词" {
  let input = "@keywords foo, a . :s foo :o .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (19, 2))
  // 谓词 = listed 裸词自身 span（物化按 DefaultPrefixIRI 展开）
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "foo")
  assert_eq(quads[0].obj.unwrap(), (26, 2))
}

///|
test "役5: `a` 复活——台账含 a，KeywordA 嗅探放行照常 rdf:type" {
  let input = "@keywords a . :s a :o .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // a 保 KeywordA（谓词 span 即 a 本词；物化层展开 rdf:type 由物化钉盖）
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "a")
  assert_eq(quads[0].pred.unwrap(), (17, 1))
}

///|
test "役5: listed 词主位 + 未列入词拒——无行静默兜底口径不变" {
  let input = "@keywords sub . sub :p :o . junk :q :r .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // sub 台账命中走 KeywordX 主位；junk 未列入 = Unknown 无行 → 静默跳到 Dot
  assert_eq(quads.length(), 1)
  assert_eq(view_str(data[:], quads[0].subj.unwrap()), "sub")
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
}

///|
test "役5: 公式罩内 listed 词——node 位镜像 Variable，罩内零发射不变" {
  let input = "@keywords foo . :s :p { foo foo foo } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 罩内语句消费不发射（ADR-002）；外层 statement 一条，o = { 身份
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].obj.unwrap(), (22, 1))
}

///|
test "役5: 全量重置——新 @keywords 清账，旧 listed 词即刻失格" {
  let input = "@keywords foo . foo :p :o . @keywords bar . foo :q :r .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 首声明期 foo 可用；再声明 @keywords bar 后 foo 失格 = Unknown 静默拒
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (16, 3))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
}

///|
test "役5: 空列表——@keywords . 全关键词失格，a 走 PrefName 谓词位照常" {
  let input = "@keywords . :s a :o .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // a 失格 → PrefName（冒号无前缀裸名，物化层 DefaultPrefixIRI 展开径）
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "a")
}

// —— 役6：is/of 集合等价倒装（`X is P of Y ≡ Y P X`；grammar 序槽位、语义序出账）——

///|
test "役6: 正典倒装——主宾互换出账" {
  let input = ":a is :p of :b .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  // :a is :p of :b ≡ :b :p :a
  assert_eq(quads[0].subj.unwrap(), (12, 2))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
  assert_eq(quads[0].obj.unwrap(), (0, 2))
}

///|
test "役6: 变量倒装——?x is :p of ?y ≡ ?y :p ?x（W3C 正典形）" {
  let input = "?x is :p of ?y .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (12, 2))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
  assert_eq(quads[0].obj.unwrap(), (0, 2))
}

///|
test "役6: 逗号连换——Object 粒度保交换键，多宾各自互换" {
  let input = ":a is :p of :b, :c .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // :b :p :a . :c :p :a .
  assert_eq(quads.length(), 2)
  assert_eq(quads[0].subj.unwrap(), (12, 2))
  assert_eq(quads[0].obj.unwrap(), (0, 2))
  assert_eq(quads[1].subj.unwrap(), (16, 2))
  assert_eq(quads[1].obj.unwrap(), (0, 2))
}

///|
test "役6: 分号续谓词——PredObj 粒度清键，后续谓词不互换" {
  let input = ":a is :p of :b ; :q :c .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // :b :p :a . :a :q :c .——第二句语法主语 :a 不换
  assert_eq(quads.length(), 2)
  assert_eq(quads[0].subj.unwrap(), (12, 2))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
  assert_eq(quads[1].subj.unwrap(), (0, 2))
  assert_eq(view_str(data[:], quads[1].pred.unwrap()), ":q")
  assert_eq(quads[1].obj.unwrap(), (20, 2))
}

///|
test "役6: 分号二次倒装——新 is/of 重新登记交换键" {
  let input = ":a is :p of :b ; is :q of :c .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // :b :p :a . :c :q :a .
  assert_eq(quads.length(), 2)
  assert_eq(quads[0].subj.unwrap(), (12, 2))
  assert_eq(quads[0].obj.unwrap(), (0, 2))
  assert_eq(quads[1].subj.unwrap(), (26, 2))
  assert_eq(view_str(data[:], quads[1].pred.unwrap()), ":q")
  assert_eq(quads[1].obj.unwrap(), (0, 2))
}

///|
test "役6: 嵌套 bnp 宾位——内层发射 fresh 主语错键不换，外层照常互换" {
  let input = ":a is :p of [ :q :r ] .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  // 内层：(fresh, :q, :r)——fresh = [ span，错键不换
  assert_eq(quads[0].subj.unwrap(), (12, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":q")
  assert_eq(quads[0].obj.unwrap(), (17, 2))
  // 外层：fresh :p :a——交换键 :a 仍在（槽深 1 ≠ 登记 0，内层未清账）
  assert_eq(quads[1].subj.unwrap(), (12, 1))
  assert_eq(view_str(data[:], quads[1].pred.unwrap()), ":p")
  assert_eq(quads[1].obj.unwrap(), (0, 2))
}

///|
test "役6: 公式宾位——罩内零发射不动外层账，GraphTerm 作倒装主语出账" {
  let input = ":a is :p of { :x :q :z } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // { :p :a——罩内语句消费不发射；外层互换照常
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (12, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
  assert_eq(quads[0].obj.unwrap(), (0, 2))
}

///|
test "役12: 公式罩内 is——Is 入口接表（役6 拒钉翻转），内容零发射外层照常" {
  let input = "{ :a is :p of :b } :s :z .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  // 公式内容 ADR-002 零发射（倒装含内），外层语句 ({span}, :s, :z) 出账
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (0, 1))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":s")
}

///|
test "役6: 残缺倒装拒——is 谓词后无 of = Dot 无行，不出 (:a,:b) 垃圾 quad" {
  let input = ":a is :b .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  // 静默兜底：残缺倒装整句吞（误收编退役——此前 :b 成宾位出 (:a,is,:b)）
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 0)
}

///|
test "役6: of 无行拒——裸 of 出现在非倒装位 = 静默兜底" {
  let input = ":a :b of :c .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 0)
}

///|
test "役12: bnp 位 is——`[ is P of X ]` ≡ (X, P, bnode)（役6 拒钉翻转）" {
  let input = "[ is :p of :x ] :q :z .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  // `]` 收口 EmitQuad 交换键 = `[` 身份 span（is_src 恰匹配）→ 语义序出账；
  // pop 后外层语句 ([span], :q, :z)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  // quad0 = 语义序 (:x, :p, [span)
  assert_eq(view_str(data[:], quads[0].subj.unwrap()), ":x")
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
  assert_eq(quads[0].obj.unwrap(), (0, 1))
  // quad1 = 外层 ([span], :q, :z)
  assert_eq(quads[1].subj.unwrap(), (0, 1))
  assert_eq(view_str(data[:], quads[1].pred.unwrap()), ":q")
}

///|
test "役6: 'a' 倒装——set_predicate 复用，pk 出账 KwA（物化层 rdf:type 同径）" {
  let input = ":x is a of :y .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (11, 2))
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), "a")
  assert_true(quads[0].pk is PredKind::KwA)
  assert_eq(quads[0].obj.unwrap(), (0, 2))
}

// —— 役7：`=` 等同谓词（ADR-005：owl:sameAs 语法糖；= token span 占槽、
// 语义身份 pk=SameAs，物化层展开）——

///|
test "役7: 正典等同——:a = :b 出账谓词身份 pk=SameAs" {
  let input = ":a = :b .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].subj.unwrap(), (0, 2))
  // = token span 占谓词槽（展开语义在物化层 pk 账）
  assert_eq(quads[0].pred.unwrap(), (3, 1))
  assert_true(quads[0].pk is PredKind::SameAs)
  assert_eq(quads[0].obj.unwrap(), (5, 2))
}

///|
test "役7: 逗号连发——pk 快照直引保真，双宾同 SameAs" {
  let input = ":a = :b, :c .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // (:a,sameAs,:b) (:a,sameAs,:c)——Comma 不过 action，pk 直引不写回
  assert_eq(quads.length(), 2)
  assert_eq(quads[0].pred.unwrap(), (3, 1))
  assert_true(quads[0].pk is PredKind::SameAs)
  assert_eq(quads[1].pred.unwrap(), (3, 1))
  assert_true(quads[1].pk is PredKind::SameAs)
  assert_eq(quads[0].obj.unwrap(), (5, 2))
  assert_eq(quads[1].obj.unwrap(), (9, 2))
}

///|
test "役7: 分号续谓词——set_predicate 归账 Normal，SameAs 不外溢" {
  let input = ":a = :b ; :q :c .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  assert_true(quads[0].pk is PredKind::SameAs)
  assert_true(quads[1].pk is PredKind::Normal)
  assert_eq(view_str(data[:], quads[1].pred.unwrap()), ":q")
}

///|
test "役7: bnp 谓词位——八位全开口径，fresh 主语等同出账" {
  let input = "[ :q :r ] = :z .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // (fresh,:q,:r) + (fresh,sameAs,:z)——fresh = [ span
  assert_eq(quads.length(), 2)
  assert_eq(quads[1].subj.unwrap(), (0, 1))
  assert_eq(quads[1].pred.unwrap(), (10, 1))
  assert_true(quads[1].pk is PredKind::SameAs)
  assert_eq(quads[1].obj.unwrap(), (12, 2))
}

///|
test "役7: 公式罩内 =——罩内零发射口径不变，外层不受扰" {
  let input = ":s :p { :x = :y } .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  // 罩内语句消费不发射；外层一条，o = { 身份
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].obj.unwrap(), (6, 1))
}

///|
test "役8: 正典注解——主 quad 锚主语 + 体 quad 壳主语（span 账）" {
  let input = ":s :p :o {| :q :z |} .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  // 主 quad：锚主语预发射，壳旗假
  assert_eq(quads[0].subj.unwrap(), (0, 2))
  assert_eq(quads[0].pred.unwrap(), (3, 2))
  assert_eq(quads[0].obj.unwrap(), (6, 2))
  assert_false(quads[0].subj_shell)
  // 体 quad：subj = 壳 span（锚 s 起点 (0) 至锚 o 终点 (8) 的连续原文
  // ":s :p :o"），壳旗真
  assert_true(quads[1].subj_shell)
  assert_eq(quads[1].subj.unwrap(), (0, 8))
  assert_eq(view_str(data[:], quads[1].subj.unwrap()), ":s :p :o")
  assert_eq(quads[1].pred.unwrap(), (12, 2))
  assert_eq(quads[1].obj.unwrap(), (15, 2))
}

///|
test "役8: 收尾续锚——{|…|} 后 `;` 谓词回锚主语（收口还原口径）" {
  let input = ":s :p :o {| :q :z |} ; :r :w .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_true(quads[1].subj_shell)
  // 末体 quad 收口发射（annot_end），其后 `; :r :w` 续锚主语、壳旗假
  assert_false(quads[2].subj_shell)
  assert_eq(quads[2].subj.unwrap(), (0, 2))
  assert_eq(view_str(data[:], quads[2].pred.unwrap()), ":r")
  assert_eq(view_str(data[:], quads[2].obj.unwrap()), ":w")
}

///|
test "役8: 体区逗号连换——多体 quad 同壳（旗直引保真）" {
  let input = ":s :p :o {| :q :z1, :z2 |} .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_true(quads[1].subj_shell)
  assert_true(quads[2].subj_shell)
  assert_eq(quads[1].subj.unwrap(), (0, 8))
  assert_eq(quads[2].subj.unwrap(), (0, 8))
  assert_eq(view_str(data[:], quads[2].obj.unwrap()), ":z2")
}

///|
test "役8: 体区分号多谓词——逐体出账同壳" {
  let input = ":s :p :o {| :q :z ; :r :w |} .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_true(quads[1].subj_shell)
  assert_true(quads[2].subj_shell)
  assert_eq(view_str(data[:], quads[2].pred.unwrap()), ":r")
  assert_eq(view_str(data[:], quads[2].obj.unwrap()), ":w")
}

///|
test "役8: 嵌套 bnp——内层 fresh 主语错键不带壳旗，外层体 quad 同壳" {
  let input = ":s :p :o {| :q [ :x :y ] |} .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  // 内层 (genid, :x, :y)：fresh 主语 ≠ 锚主语 = 错键不换 + 壳旗落假
  assert_false(quads[1].subj_shell)
  assert_true(quads[1].subj.unwrap() != (0, 8))
  // 外层体 quad（壳, :q, genid）：收口发射，壳旗真
  assert_true(quads[2].subj_shell)
  assert_eq(quads[2].subj.unwrap(), (0, 8))
}

///|
test "役8: 静默收口——体尾分号后 |} 直清壳账，后语句不染" {
  let input = ":s :p :o {| :q :z ; |} . :a :b :c .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_true(quads[1].subj_shell)
  // 后续正常语句：无壳旗（旗漏 = 全局污染，此处钉死）
  assert_false(quads[2].subj_shell)
  assert_eq(quads[2].subj.unwrap(), (25, 2))
  assert_eq(view_str(data[:], quads[2].pred.unwrap()), ":b")
}

///|
test "役8: 公式罩内注解——压位点消费收口旗，零发射零报错" {
  let input = "{ :s :p :o {| :q :z |} }\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 0)
}

///|
test "役8: 残缺体 EOF——主 quad 已出账，收尾判脏报错" {
  let input = ":s :p :o {| :q"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(quads.length(), 1)
  assert_false(quads[0].subj_shell)
  assert_eq(errors.length(), 1)
}

///|
test "役8: ~ 驻留位注解——标签驻留不占槽，壳账照抄锚槽" {
  let input = ":s :p :o ~ :l {| :q :z |} .\n"
  let data = bytes_of(input)
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  assert_eq(quads[0].subj.unwrap(), (0, 2))
  assert_true(quads[1].subj_shell)
  assert_eq(quads[1].subj.unwrap(), (0, 8))
  assert_eq(view_str(data[:], quads[1].pred.unwrap()), ":q")
}

///|
test "役11: has 引导词——六动词位 self-loop 收动词，主语位拒" {
  // `X has P … ≡ X P …`：has 零簿记，下个事件在本态收动词
  let data = bytes_of("@prefix : <http://e/> .\n:s has :p :o .\n")
  let (quads, errors) = drain_n3(N3Engine::from_bytes(data))
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(view_str(data[:], quads[0].pred.unwrap()), ":p")
  // 公式罩内：行存在（FormulaExpectPredicate self-loop）但 ADR-002 内容零发射
  // ——黑盒面 = 零 quad 零错静默收拾；行存在性由再生 assert 钉（表源白盒）
  let data2 = bytes_of("@prefix : <http://e/> .\n{ :s has :p :o . } .\n")
  let (quads2, errors2) = drain_n3(N3Engine::from_bytes(data2))
  assert_eq(errors2.length(), 0)
  assert_eq(quads2.length(), 0)
  // bnp 内（BnpExpectPredicate self-loop，罩内发射不压制）：`[` 直入
  // BnpExpectPredicate（两入口同款），`has` 作动词前缀收内层谓词——
  // `[ has :r :t ]` ≡ (bnode, :r, :t)，内层/外层 quad 照常出账
  let data3 = bytes_of("@prefix : <http://e/> .\n[ has :r :t ] :z :w .\n")
  let (quads3, errors3) = drain_n3(N3Engine::from_bytes(data3))
  assert_eq(errors3.length(), 0)
  assert_eq(quads3.length(), 2)
  // 分号续谓词位（ExpectVerbOrEnd self-loop）
  let data4 = bytes_of("@prefix : <http://e/> .\n:s :p :o ; has :q :r .\n")
  let (quads4, errors4) = drain_n3(N3Engine::from_bytes(data4))
  assert_eq(errors4.length(), 0)
  assert_eq(quads4.length(), 2)
  // 主语位 `has` 无行 = 干净拒（拒绝钉口径）：引擎 recover 登记 last_error，
  // SliceParser EOF 兑现为 ParseError——组装层可见错误
  let data5 = bytes_of("@prefix : <http://e/> .\nhas :p :o .\n")
  let engine5 = N3Engine::from_bytes(data5)
  let slice5 = N3SliceParser::new(engine5, data5[:], lenient=true)
  let (quads5, perrs5) = slice5.parse_all()
  assert_eq(quads5.length(), 0)
  assert_true(perrs5.length() > 0)
}

///|
test "役11: `[]` 谓词位——as_pred 帧弹栈身份落 p 槽，mat raw 臂接住" {
  let data = bytes_of("@prefix : <http://e/> .\n:s [ :p :o ] :obj .\n")
  let engine = N3Engine::from_bytes(data)
  let slice = N3SliceParser::new(engine, data[:], lenient=true)
  let (quads, perrs) = slice.parse_all()
  assert_eq(perrs.length(), 0)
  assert_eq(quads.length(), 2)
  let mat = N3Materializer::new(
    data[:],
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
    base_fallback=Some("https://e/"),
  )
  let (emits, merrs) = mat.materialize_all(quads)
  assert_eq(merrs.length(), 0)
  assert_eq(emits.length(), 2)
  // 外层 quad 谓词 = `[` 开括号原文 span（raw 直出）；SliceParser 面 = QuadSpan，p 恒有值
  let (po, _pl) = quads[1].p
  assert_eq(data[po], b'[')
  // 分号续谓词位（ExpectVerbOrEnd 行）：罩内属性 quad + 外层谓词身份 quad，
  // 共 3 条——谓词身份 = `[` 开括号原文 span
  let data2 = bytes_of("@prefix : <http://e/> .\n:s :p :o ; [ :b :c ] :z .\n")
  let (quads2, errors2) = drain_n3(N3Engine::from_bytes(data2))
  assert_eq(errors2.length(), 0)
  assert_eq(quads2.length(), 3)
  let (so2, _sl2) = quads2[1].subj.unwrap()
  assert_eq(data2[so2], b'[')
  let (po2, _pl2) = quads2[2].pred.unwrap()
  assert_eq(data2[po2], b'[')
  assert_eq(view_str(data2[:], quads2[2].subj.unwrap()), ":s")
}

///|
test "役11: 空语句拒钉——zero-objects/djb1 官方负例面（两轮拔行定案）" {
  // `s p .` 无宾语句：官方负例 zero-objects 钉死非法。引擎层无行 = 静默吞
  // （分层面：拒钉在 SliceParser 组装后校验，引擎只管 span 快照）
  let data = bytes_of("@prefix : <http://e/> .\n:s :p .\n")
  let engine = N3Engine::from_bytes(data)
  let slice = N3SliceParser::new(engine, data[:], lenient=true)
  let (quads, perrs) = slice.parse_all()
  assert_eq(quads.length(), 0)
  assert_true(perrs.length() > 0)
  // 句后游离点：W3C bad-struct-09 面拒绝（组装层同口）
  let data2 = bytes_of("@prefix : <http://e/> .\n:s :p :o . .\n")
  let engine2 = N3Engine::from_bytes(data2)
  let slice2 = N3SliceParser::new(engine2, data2[:], lenient=true)
  let (quads2, perrs2) = slice2.parse_all()
  assert_eq(quads2.length(), 1) // 首语句正常出账
  assert_true(perrs2.length() > 0) // 游离点拒
}

///|
test "役13: 量化指令——@forAll/@forSome 指令头接表，顶层/公式两语境" {
  // 顶层指令：变量表逗号续、句点收口归位（零发射零簿记）
  let data = bytes_of(
    "@prefix : <#> .\n@forAll :x, :y, :z.\n@forSome :a .\n:s :p :o .\n",
  )
  let engine = N3Engine::from_bytes(data)
  let slice = N3SliceParser::new(engine, data[:], lenient=true)
  let (quads, perrs) = slice.parse_all()
  assert_eq(perrs.length(), 0)
  assert_eq(quads.length(), 1)
  // 公式内指令（嵌套规则面，quantifiers 正典）：指令零发射，规则 quad 照常出账
  let data2 = bytes_of(
    "@prefix : <#> .\n{{ :foo :bar :baz } log:includes { @forSome :foo. :foo :bar :baz }}\n log:implies { :t a :s }.\n",
  )
  let (quads2, errors2) = drain_n3(N3Engine::from_bytes(data2))
  assert_eq(errors2.length(), 0)
  assert_eq(quads2.length(), 1)
  // 公式宾位内指令（unify2 面）：`:Juno :says {@forAll :y. :Mars :fights :y}.`
  let data3 = bytes_of(
    "@prefix : <#> .\n:Juno :says {@forAll :y.  :Mars :fights :y}.\n",
  )
  let (quads3, errors3) = drain_n3(N3Engine::from_bytes(data3))
  assert_eq(errors3.length(), 0)
  assert_eq(quads3.length(), 1)
  // 空变量表 `@forAll .` 无行 = 干净拒（组装层可见）
  let data4 = bytes_of("@prefix : <#> .\n@forAll .\n")
  let engine4 = N3Engine::from_bytes(data4)
  let slice4 = N3SliceParser::new(engine4, data4[:], lenient=true)
  let (quads4, perrs4) = slice4.parse_all()
  assert_eq(quads4.length(), 0)
  assert_true(perrs4.length() > 0)
}

///|
/// 役18 语义钉：宾位贴路径 `S P O!Q`/`S P O^Q` 全展开（词法 `^` 门解胶 +
/// path_obj_close 双发纠偏）。desugar：`S P (O!Q) ≡ S P _:1 . _:1 Q O`（ADR-006）。
/// 路径值 = 多跳链终尾 fresh（open_span 改指终尾）；`,`/`;` 续位语义免费继承
/// （第二条 EmitQuad 粒度随收口事件）。
test "役18 宾位贴路径全展开（词法解胶 + path_obj_close 双发）" {
  // 基本形：跳边 ( _:1, q, "v" ) + 外层语句 ( s, p, _:1 )，双 quad 同一 fresh
  let (emits, errors) = mat_chain("@prefix : <http://d/> .\n:s :p \"v\"^:q .\n")
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  assert_eq(mat_vs(emits[0].predicate), "<http://d/q>")
  assert_eq(mat_vs(mat_obj(emits[0])), "\"v\"")
  // 同一 fresh 身份：语句宾位 = 跳边主语
  assert_true(mat_vs(mat_subj(emits[0])) == mat_vs(mat_obj(emits[1])))
  assert_eq(mat_vs(mat_subj(emits[1])), "<http://d/s>")
  assert_eq(mat_vs(emits[1].predicate), "<http://d/p>")
  // 多跳链：fresh 链独立（A→B），外层语句归属终尾 B
  let (emits2, errors2) = mat_chain(
    "@prefix : <http://d/> .\n@prefix p: <http://p/> .\n:s :p \"v\"^p:one^p:two .\n",
  )
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 3)
  assert_true(mat_vs(mat_obj(emits2[1])) == mat_vs(mat_subj(emits2[0])))
  assert_true(mat_vs(mat_subj(emits2[1])) != mat_vs(mat_subj(emits2[0])))
  // 外层语句归属终尾
  assert_true(mat_vs(mat_obj(emits2[2])) == mat_vs(mat_subj(emits2[1])))
  // `,` 续位：各路径各得一语句（第二条 EmitQuad Object 粒度，s/p 存活续位）
  let (emits3, errors3) = mat_chain(
    "@prefix : <http://d/> .\n@prefix s: <http://s/> .\n@prefix lang: <http://lang/> .\n:x s:label \"Help!\"^lang:eng, \"foo\"^lang:fr .\n",
  )
  assert_eq(errors3.length(), 0)
  assert_eq(emits3.length(), 4)
  assert_true(mat_vs(mat_obj(emits3[1])) != mat_vs(mat_obj(emits3[3])))
  // `;` 续位：真语句 (:s,:r,:w) 续组完好（PredObj 粒度保 s 存活）
  let (emits4, errors4) = mat_chain(
    "@prefix : <http://d/> .\n:s :p \"v\"^:q ; :r :w .\n",
  )
  assert_eq(errors4.length(), 0)
  assert_eq(emits4.length(), 3)
  assert_eq(mat_vs(emits4[2].predicate), "<http://d/r>")
  assert_eq(mat_vs(mat_subj(emits4[2])), "<http://d/s>")
}

///|
/// 役20 语义钉：负例缺口 3 收口（三裁断四形）。
/// ① this 晋升门：@keywords 台账命中也不晋升（deprecated，永保 Unknown）；
/// ② 声明名验形门：账本名末字节须 `:`，零 quad 也报（merrs 通道）；
/// ③ 重定义宽容钉：同/异 IRI 重声明均全净（cwm/Turtle 官方语义——
///   prefix_reassigned_and_used/qvars/path2 正例实证），值语义 = 首匹配胜。
test "役20 负例缺口收口（this 晋升门 + 声明名验形 + 重定义宽容）" {
  // ① thisadoc 最小形：@keywords 声明后文档级 this → Unknown 无表行 → perr
  let (e1, err1) = mat_chain("@keywords this . @prefix : <#> . this :a :Doc .\n")
  assert_eq(e1.length(), 0)
  assert_true(err1.length() > 0)
  // ② qname-as-prefix 最小形：声明名带本地部，零 quad 也报（账本门）
  let (e2, err2) = mat_chain("@prefix foo:bar <> .\n")
  assert_eq(e2.length(), 0)
  assert_true(err2.length() > 0)
  // ③ 同-IRI 重声明宽容：全净
  let (e3, err3) = mat_chain(
    "@prefix p: <http://a/> . @prefix p: <http://a/> . p:x p:y p:z .\n",
  )
  assert_eq(err3.length(), 0)
  assert_eq(e3.length(), 1)
  // ④ 异-IRI 重定义宽容 + 值语义首匹配胜（qvars/path2/turtle-subm-25 同形）
  let (e4, err4) = mat_chain(
    "@prefix lang: <http://d/> . @prefix lang: <http://e/> . lang:x lang:y lang:z .\n",
  )
  assert_eq(err4.length(), 0)
  // ④ 异-IRI 重定义宽容 + 值语义后声明胜（qvars/path2/turtle-subm-25 同形）
  assert_eq(mat_vs(mat_subj(e4[0])), "<http://e/x>") // 值语义 = 后声明胜（cwm/Turtle 官方口径）
}
