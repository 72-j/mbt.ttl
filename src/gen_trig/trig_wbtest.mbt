// ===== 骨架验收测试 =====
// 口径：图块进出 / 图名继承 / 指令（@风格+SPARQL 风格）/ 三档发射粒度 /
//       恢复（图块内保 graph）/ EOF 判脏 / 未声明前缀拒绝 / 三元组词项宾语位

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
test "骨架: 简单三元组，span 往返" {
  let data = bytes_of(
    "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
  let q = quads[0]
  assert_eq(view_str(data[:], q.s), "<http://example.org/s>")
  assert_eq(view_str(data[:], q.p), "<http://example.org/p>")
  assert_eq(view_str(data[:], q.o), "<http://example.org/o>")
  assert_true(q.g is None)
}

///|
test "骨架: 连续三条 + bnode 主语 + literal 宾语（@en 后缀在词内）" {
  let data = bytes_of(
    "_:b1 <http://example.org/p> \"hello\"@en .\n<http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .\n<http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 3)
  assert_eq(errors.length(), 0)
  assert_eq(view_str(data[:], quads[0].s), "_:b1")
  assert_eq(view_str(data[:], quads[0].o), "\"hello\"@en")
}

///|
test "骨架: 分号/逗号两档发射（同主语 / 同主谓）" {
  let data = bytes_of(
    "<http://example.org/s> <http://example.org/p1> <http://example.org/o1> ; <http://example.org/p2> <http://example.org/o2> , <http://example.org/o3> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 3)
  assert_eq(errors.length(), 0)
  assert_eq(view_str(data[:], quads[0].p), "<http://example.org/p1>")
  assert_eq(view_str(data[:], quads[1].p), "<http://example.org/p2>")
  assert_eq(view_str(data[:], quads[2].o), "<http://example.org/o3>")
  assert_eq(view_str(data[:], quads[1].s), view_str(data[:], quads[2].s))
}

///|
test "骨架: 'a' 缩写走谓词位" {
  let data = bytes_of("<http://example.org/s> a <http://example.org/o> .\n")
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
  assert_eq(view_str(data[:], quads[0].p), "a")
}

///|
test "图块: 默认图块进出，g=None，块后顶层语句恢复" {
  let data = bytes_of(
    "{ <http://example.org/s> <http://example.org/p> <http://example.org/o> . } <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 2)
  assert_eq(errors.length(), 0)
  assert_true(quads[0].g is None)
  assert_true(quads[1].g is None)
}

///|
test "图块: 命名图块 <g> {}，图名继承到块内每条，退块后清空" {
  let data = bytes_of(
    "<http://example.org/g> { <http://example.org/s> <http://example.org/p> <http://example.org/o> . <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> . } <http://example.org/s3> <http://example.org/p3> <http://example.org/o3> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 3)
  assert_eq(errors.length(), 0)
  match quads[0].g {
    Some(g) => assert_eq(view_str(data[:], g), "<http://example.org/g>")
    None => fail("expected graph label on quad 0")
  }
  match quads[1].g {
    Some(g) => assert_eq(view_str(data[:], g), "<http://example.org/g>")
    None => fail("expected graph label on quad 1")
  }
  assert_true(quads[2].g is None)
}

///|
test "图块: 空块 {} 与 <g> {} 合法" {
  let data = bytes_of(
    "{} <http://example.org/g> {} <http://example.org/s> <http://example.org/p> <http://example.org/o> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
}

///|
test "图块: `}` 前省点（Sequence 复合意图：发射+退图）" {
  let data = bytes_of(
    "<http://example.org/g> { <http://example.org/s> <http://example.org/p> <http://example.org/o> } <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 2)
  assert_eq(errors.length(), 0)
  match quads[0].g {
    Some(g) => assert_eq(view_str(data[:], g), "<http://example.org/g>")
    None => fail("expected graph label")
  }
  assert_true(quads[1].g is None)
}

///|
test "指令: @prefix 声明 + PrefName 展开（span 口径：词项保持 ex:s）" {
  let data = bytes_of("@prefix ex: <http://example.org/> .\nex:s ex:p ex:o .\n")
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
  assert_eq(view_str(data[:], quads[0].s), "ex:s")
}

///|
test "指令: SPARQL 风格 PREFIX/BASE 无点直通" {
  let data = bytes_of("PREFIX ex: <http://example.org/>\nex:s ex:p ex:o .\n")
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
}

///|
test "指令: DefaultPrefixIRI 冒号声明 + :s 词项" {
  let data = bytes_of("@prefix : <http://d/> .\n:s :p :o .\n")
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
}

///|
test "指令: PrefName 图标签 `ex:g { }`" {
  let data = bytes_of(
    "@prefix ex: <http://example.org/> .\nex:g { ex:s ex:p ex:o . }\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
  match quads[0].g {
    Some(g) => assert_eq(view_str(data[:], g), "ex:g")
    None => fail("expected graph label")
  }
}

///|
test "负例: 未声明前缀拒绝" {
  let data = bytes_of("ex:s ex:p ex:o .\n")
  let (quads, errors) = trig_parser(data)
  assert_true(quads.is_empty())
  assert_true(errors.length() > 0)
}

///|
test "负例: 先用后声明拒绝（逐 quad 发射时检查账本时序）" {
  let data = bytes_of("ex:s ex:p ex:o .\n@prefix ex: <http://example.org/> .\n")
  let (quads, errors) = trig_parser(data)
  assert_true(quads.is_empty())
  assert_true(errors.length() > 0)
}

///|
test "负例: 裸词主语拒绝" {
  let data = bytes_of("hello <http://example.org/p> <http://example.org/o> .\n")
  let (quads, errors) = trig_parser(data)
  assert_true(quads.is_empty())
  assert_true(errors.length() > 0)
}

///|
test "负例: EOF 槽位脏 → Incomplete，且不无限重报" {
  let data = bytes_of("<http://example.org/s> <http://example.org/p>\n")
  let (quads, errors) = trig_parser(data)
  assert_true(quads.is_empty())
  assert_eq(errors.length(), 1)
}

///|
test "恢复: 图块内坏 token，停 Rbrace 闭合，块内前序 quad 保图名" {
  // '@' 在图块内 GraphExpectDotOrGraph 无边 → 恢复停在 Rbrace 前界 → 表闭合图块
  let data = bytes_of(
    "<http://example.org/g> { <http://example.org/s> <http://example.org/p> <http://example.org/o> . @ } <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .\n",
  )
  let (quads, errors) = trig_parser(data)
  // 坏的部分报错、好的部分照常通过——分别锁定：
  // 恰 1 错（'@' 一次登记：恢复无双报，EOF 收尾无连带脏）
  assert_eq(errors.length(), 1)
  // 坏 token 之前的块内 quad：内容往返 + 图名保留
  assert_eq(quads.length(), 2)
  assert_eq(view_str(data[:], quads[0].s), "<http://example.org/s>")
  match quads[0].g {
    Some(g) => assert_eq(view_str(data[:], g), "<http://example.org/g>")
    None => fail("expected graph label")
  }
  // 恢复停在未消费的 `}` → 表闭合图块 → 顶层 s2/p2/o2 正常发射：无图名
  assert_true(quads[1].g is None)
  assert_eq(view_str(data[:], quads[1].s), "<http://example.org/s2>")
}

///|
test "负例: 图块内嵌套 `{` 结构性拒绝（TriG 语义，非 N3）" {
  let data = bytes_of(
    "{ <http://example.org/s> <http://example.org/p> <http://example.org/o> . { } } .\n",
  )
  let (quads, errors) = trig_parser(data)
  // 内层 `{` 在 GraphExpectDotOrGraph 无边 → 恢复；不产生合法发射
  assert_true(errors.length() >= 1)
  let _ = quads
}

///|
test "白捡: <<( )>> 三元组词项落宾语位" {
  let data = bytes_of(
    "<http://example.org/s> <http://example.org/p> <<( <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> )>> .\n",
  )
  let (quads, errors) = trig_parser(data)
  assert_eq(quads.length(), 1)
  assert_eq(errors.length(), 0)
  assert_eq(
    view_str(data[:], quads[0].o),
    "<<( <http://example.org/s2> <http://example.org/p2> <http://example.org/o2> )>>",
  )
}

///|
test "适配器: 结构字符逐 token 分类（含 @ → TrigAt）" {
  let data = bytes_of("{ } [ ] ( ) @")
  let lexer = TrigLexerAdapter::new(data[:])
  let events : Array[TrigEvent] = []
  for ;; {
    match LexerSource::next(lexer) {
      Some(TrigEvent::TrigEOF) => {
        // EOF 合法送达：计入事件后终止（其后 None=枯竭）
        events.push(TrigEvent::TrigEOF)
        break
      }
      Some(ev) => events.push(ev)
      None => break
    }
  }
  // `[ ]` 词法合并为单 TrigAnon（kw-graph-07 口径：`[]` 是 ANON 产生式，
  // 不是开括号；`( )` 不合并——空集合由表 list_nil 收口）
  assert_eq(events.length(), 7)
  assert_true(events[0] is TrigEvent::TrigLbrace)
  assert_true(events[1] is TrigEvent::TrigRbrace)
  assert_true(events[2] is TrigEvent::TrigAnon)
  assert_true(events[3] is TrigEvent::TrigLparen)
  assert_true(events[4] is TrigEvent::TrigRparen)
  assert_true(events[5] is TrigEvent::TrigAt)
  assert_true(events[6] is TrigEvent::TrigEOF)
}

///|
test "适配器: 指令收紧——@ 风格小写精确 / 无冒号 PrefName 降级 Unknown" {
  let evs = fn(data : Array[Byte]) -> Array[TrigEvent] {
    let lexer = TrigLexerAdapter::new(data[:])
    let acc : Array[TrigEvent] = []
    for ;; {
      match LexerSource::next(lexer) {
        Some(TrigEvent::TrigEOF) => break
        Some(ev) => acc.push(ev)
        None => break
      }
    }
    acc
  }
  // @BASE：@ 风格大写拒（bad-base-02）；@base 小写精确放行
  let e1 = evs(bytes_of("@BASE"))
  assert_true(e1[0] is TrigEvent::TrigAt)
  assert_true(e1[1] is TrigEvent::TrigUnknown)
  let e2 = evs(bytes_of("@base"))
  assert_true(e2[0] is TrigEvent::TrigAt)
  assert_true(e2[1] is TrigEvent::TrigBaseKw)
  // SPARQL 风格裸词大小写不敏感照旧放行
  let e3 = evs(bytes_of("BASE"))
  assert_true(e3[0] is TrigEvent::TrigBaseKw)
  // 无冒号 PrefName 全域降级 Unknown（bad-prefix-05）；带冒号照旧
  let e4 = evs(bytes_of("x"))
  assert_true(e4[0] is TrigEvent::TrigUnknown)
  let e5 = evs(bytes_of("ex:p"))
  assert_true(e5[0] is TrigEvent::TrigPrefName)
}

///|
test "引擎: 指令负例四族——@ 大写 / 前缀名缺冒号 / SPARQL 收点 / version 长串" {
  // @BASE：表外 Unknown → 报错
  let (_, e1) = trig_parser(
    @utf8.encode("@BASE <http://example/> .\n").to_array(),
  )
  assert_true(e1.length() > 0)
  // @prefix x（名缺冒号）→ 报错
  let (_, e2) = trig_parser(
    @utf8.encode("@prefix x <http://example/> .\n").to_array(),
  )
  assert_true(e2.length() > 0)
  // SPARQL BASE 收句点（bad-base-03）→ 报错（后续语句照常解析）
  let (q3, e3) = trig_parser(
    @utf8.encode("BASE <http://example/> .\n<s> <p> <o> .\n").to_array(),
  )
  assert_true(e3.length() > 0)
  assert_eq(q3.length(), 0) // 恢复语义：顶层消费到 Dot，错误后续句一并吞掉
  // version 长串拒（驱动守卫）；后续语句照常
  let (q4, e4) = trig_parser(
    @utf8.encode("VERSION \"\"\"1.2\"\"\"\n<s> <p> <o> .\n").to_array(),
  )
  assert_true(e4.length() > 0)
  assert_eq(q4.length(), 0) // 同上：恢复吞到下一个 Dot
  // 对应正例：@ 风格收点 + SPARQL 无点直通 + 短串版本，全链零错
  let (q5, e5) = trig_parser(
    @utf8.encode(
      "@base <http://example/> .\n@prefix ex: <http://example/> .\nVERSION \"1.2\"\nex:s ex:p ex:o .\n",
    ).to_array(),
  )
  assert_true(e5.length() == 0)
  assert_eq(q5.length(), 1)
  let (_, e6) = trig_parser(
    @utf8.encode("@version \"1.2\" .\n<s> <p> <o> .\n").to_array(),
  )
  assert_true(e6.length() == 0)
}

///|
test "适配器: TT 括号壳分流——<<( )>> → BracketTripleTerm，<< >> → TripleTerm" {
  let evs = fn(data : Array[Byte]) -> Array[TrigEvent] {
    let lexer = TrigLexerAdapter::new(data[:])
    let acc : Array[TrigEvent] = []
    for ;; {
      match LexerSource::next(lexer) {
        Some(TrigEvent::TrigEOF) => break
        Some(ev) => acc.push(ev)
        None => break
      }
    }
    acc
  }
  // 括号壳（含无空格形态 basic-03 `<<(:s` 口径）
  let e1 = evs(bytes_of("<<( <s> <p> <o> )>>"))
  assert_true(e1[0] is TrigEvent::TrigBracketTripleTerm)
  let e2 = evs(bytes_of("<<(:s :p :o )>>"))
  assert_true(e2[0] is TrigEvent::TrigBracketTripleTerm)
  // 裸壳
  let e3 = evs(bytes_of("<< <s> <p> <o> >>"))
  assert_true(e3[0] is TrigEvent::TrigTripleTerm)
  let e4 = evs(bytes_of("<<:s :p :o>>"))
  assert_true(e4[0] is TrigEvent::TrigTripleTerm)
}

///|
test "引擎: TT 括号壳兼容口径——宾语位放行（含图块内），主语位拒" {
  // 宾语位（nt-ttl12-syntax-1 reifies 形态）→ 零错 1 quad
  let (q1, e1) = trig_parser(
    @utf8.encode(
      "<http://e/a> <http://e/reifies> <<(<http://e/s> <http://e/p> <http://e/o>)>> .\n",
    ).to_array(),
  )
  assert_true(e1.length() == 0)
  assert_eq(q1.length(), 1)
  // 图块内宾语（trig12-syntax-basic-03 形态）
  let (q2, e2) = trig_parser(
    @utf8.encode(
      "@prefix ex: <http://e/> .\nex:G { ex:s ex:p <<(ex:s ex:p ex:o )>> . }\n",
    ).to_array(),
  )
  assert_true(e2.length() == 0)
  assert_eq(q2.length(), 1)
  // 主语位（nt-ttl12-bad-10/05 同款）→ 表外拒绝
  let (_, e3) = trig_parser(
    @utf8.encode(
      "<<( <http://e/s> <http://e/p> <http://e/o> )>> <http://e/a> <http://e/z> .\n",
    ).to_array(),
  )
  assert_true(e3.length() > 0)
  // 图块区主语位同拒
  let (_, e4) = trig_parser(
    @utf8.encode(
      "<<( <http://e/s> <http://e/p> <http://e/o> )>> { <http://e/a> <http://e/b> <http://e/c> . }\n",
    ).to_array(),
  )
  assert_true(e4.length() > 0)
}

///|
test "方言守卫: Turtle 禁图块区（裸 { } / <g> { }），TriG 默认放行" {
  // Turtle：裸图块拒（bad-struct-01 同款）
  let (_, e1) = trig_parser(
    @utf8.encode("@prefix ex: <http://e/> .\n{ ex:a ex:b ex:c . }\n").to_array(),
    dialect=Turtle,
  )
  assert_true(e1.length() > 0)
  // Turtle：图名图块区拒（<g> { 歧义消解行同样属 TriG 特性）
  let (_, e2) = trig_parser(
    @utf8.encode("@prefix ex: <http://e/> .\nex:g { ex:a ex:b ex:c . }\n").to_array(),
    dialect=Turtle,
  )
  assert_true(e2.length() > 0)
  // Turtle：纯三元组文档零错（字面量内 { 不产事件，不受守卫影响）
  let (q3, e3) = trig_parser(
    @utf8.encode("<http://e/s> <http://e/p> \"punct {}{|}\" .\n").to_array(),
    dialect=Turtle,
  )
  assert_true(e3.length() == 0)
  assert_eq(q3.length(), 1)
  // 默认 TriG：同款裸图块放行（超集口径不变）
  let (q4, e4) = trig_parser(
    @utf8.encode("@prefix ex: <http://e/> .\n{ ex:a ex:b ex:c . }\n").to_array(),
  )
  assert_true(e4.length() == 0)
  assert_eq(q4.length(), 1)
}

///|
/// N3 预埋分类 pin：适配层发出新事件（表未接走兜底，不进任何 quad）。
/// 量化指令要求 @ 邻接精确拼写；适配层无跨 token 状态，
/// @keywords 模式下 'a' 仍出 KeywordA（语义豁免归表/物化层，将来接表再定）。
test "N3 预埋: ! ^ => <= 与 @forAll/@forSome/@keywords 分类" {
  let input = "! ^ => <=\n@forAll :x .\n@forSome :y .\n@keywords a.\n"
  let data = bytes_of(input)
  let adapter = TrigLexerAdapter::new(data[:])
  let events : Array[String] = []
  for ;; {
    match adapter.next() {
      None => break
      Some(TrigEvent::TrigEOF) => break
      Some(e) => {
        let name = match e {
          TrigEvent::TrigBang => "Bang"
          TrigEvent::TrigCaret => "Caret"
          TrigEvent::TrigImplies => "Implies"
          TrigEvent::TrigImpliedBy => "ImpliedBy"
          TrigEvent::TrigForAllKw => "ForAllKw"
          TrigEvent::TrigForSomeKw => "ForSomeKw"
          TrigEvent::TrigKeywordsKw => "KeywordsKw"
          TrigEvent::TrigAt => "At"
          TrigEvent::TrigDot => "Dot"
          TrigEvent::TrigKeywordA(_) => "KeywordA"
          TrigEvent::TrigPrefName(_) => "PrefName"
          TrigEvent::TrigUnknown => "Unknown"
          _ => "other"
        }
        events.push(name)
      }
    }
  }
  assert_eq(events, [
    "Bang", "Caret", "Implies", "ImpliedBy", "At", "ForAllKw", "PrefName", "Dot",
    "At", "ForSomeKw", "PrefName", "Dot", "At", "KeywordsKw", "KeywordA", "Dot",
  ])
}

///|
/// ★3 `[]`/`()` 全链路（引擎表 → 组装 → 物化）。fresh 节点标签 = `_:genid{offset}`，
/// offset 为 `[` token 自身位置（全文档唯一）——标签断言同时 pin 了 fresh 身份语义
test "★3 主位 [] ：内层三元组发射 + 点收口空 fresh 独立句" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\n[ ex:q ex:r ] .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_subj(emits[0])), "_:genid32")
  assert_eq(mat_vs(mat_obj(emits[0])), "<http://example/r>")
}

///|
test "★3 宾位 [] ：内层先发 + 外层宾槽落 fresh" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p [ ex:q ex:r ] .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  // 内层三元组在 `]` 收口时先发
  assert_eq(mat_vs(mat_subj(emits[0])), "_:genid42")
  assert_eq(mat_vs(mat_obj(emits[1])), "_:genid42")
  assert_eq(mat_vs(mat_subj(emits[1])), "<http://example/s>")
}

///|
test "★3 空形式：[] 独立成句谓语缺位必拒（ANON 终结符口径）；宾位空 [] 落 fresh" {
  // ANON 是 bnode 终结符，`[] .` 谓语缺位 = 非法文法（旧空帧口径曾静默吞，
  // 词法立词后表自然拒绝——收紧而非放宽）
  let (_, errors1) = mat_chain(
    "@prefix ex: <http://example/> .\n[] .\n",
  )
  assert_true(errors1.length() > 0)
  // 宾位空 []：fresh 落 o 槽（`[` 在 42 号偏移）
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p [] .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://example/s>")
  assert_eq(mat_vs(mat_obj(emits[0])), "_:genid42")
}

///|
test "★3 分号链与嵌套：`;` 链各自发射；内层 [] 作宾语" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\n[ ex:p1 ex:o1 ; ex:p2 ex:o2 ] .\n[ ex:q [ ex:a ex:b ] ] .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 4)
  assert_eq(mat_vs(mat_subj(emits[0])), "_:genid32")
  assert_eq(mat_vs(mat_subj(emits[1])), "_:genid32")
  // 嵌套：外层 [ 在 64、内层 [ 在 71；内层收口先发 (f71 a b)，外层收口发 (f64 q f71)
  assert_eq(mat_vs(mat_subj(emits[2])), "_:genid71")
  assert_eq(mat_vs(mat_obj(emits[2])), "<http://example/b>")
  assert_eq(mat_vs(mat_subj(emits[3])), "_:genid64")
  assert_eq(mat_vs(mat_obj(emits[3])), "_:genid71")
}

///|
test "★3 图块内 [] ：fresh 主语带图名；EOF 未闭合判脏" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\n<http://g> { [ ex:q ex:r ] . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_graph(emits[0])), "<http://g>")
  // 未闭合 `[]` 到 EOF：finish_at_end 判脏报错（栈脏判定）
  let (_, errors2) = mat_chain("@prefix ex: <http://example/> .\n[ ex:q ")
  assert_true(errors2.length() > 0)
}

///|
test "★3 集合 宾位双元素：first/rest 链合成 + 头节点落外层宾槽" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p ( ex:a ex:b ) .\n",
  )
  assert_eq(errors.length(), 0)
  // (n0 first a)(n0 rest n1)(n1 first b)(n1 rest nil)(s p n0)
  assert_eq(emits.length(), 5)
  let first = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#first>"
  let rest = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest>"
  let nil_iri = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>"
  assert_eq(mat_vs(emits[0].predicate), first)
  assert_eq(mat_vs(mat_subj(emits[0])), "_:genid42n0")
  assert_eq(mat_vs(mat_obj(emits[0])), "<http://example/a>")
  assert_eq(mat_vs(emits[1].predicate), rest)
  assert_eq(mat_vs(mat_subj(emits[1])), "_:genid42n0")
  assert_eq(mat_vs(mat_obj(emits[1])), "_:genid42n1")
  assert_eq(mat_vs(mat_subj(emits[2])), "_:genid42n1")
  assert_eq(mat_vs(mat_obj(emits[2])), "<http://example/b>")
  assert_eq(mat_vs(mat_obj(emits[3])), nil_iri)
  assert_eq(mat_vs(mat_obj(emits[4])), "_:genid42n0")
  assert_eq(mat_vs(mat_subj(emits[4])), "<http://example/s>")
}

///|
test "★3 空集合 = rdf:nil：宾位落 nil IRI；主位 nil 作主语" {
  // 宾位 ()：单 quad，o = 合成 nil
  let (emits, errors) = mat_chain("<http://s> <http://p> () .\n")
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(
    mat_vs(mat_obj(emits[0])),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>",
  )
  // 主位 ()：nil 作主语（materializer 主语位 nil 臂）
  let (emits2, errors2) = mat_chain("() <http://p> <http://o> .\n")
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 1)
  assert_eq(
    mat_vs(mat_subj(emits2[0])),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>",
  )
}

///|
test "★3 嵌套集合：内层集合作元素（头身份 = 内层 `(` token span）" {
  let (emits, errors) = mat_chain(
    "<http://s> <http://p> ( <http://a> ( <http://b> ) ) .\n",
  )
  assert_eq(errors.length(), 0)
  // (n0 first a)(n0 rest n1)(n1 first m0)(n1 rest nil)(m0 first b)(m0 rest nil)(s p n0)
  assert_eq(emits.length(), 7)
  let rest = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#rest>"
  let nil_iri = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>"
  assert_eq(mat_vs(mat_subj(emits[0])), "_:genid22n0")
  assert_eq(mat_vs(mat_obj(emits[1])), "_:genid22n1")
  // 内层集合头 = 内层 `(` token span (35,1) → genid35n0
  assert_eq(mat_vs(mat_obj(emits[2])), "_:genid35n0")
  // 内层区域 quad 在外层 rest→nil 之前交错发射（外层收口在内层完成后）
  assert_eq(mat_vs(mat_subj(emits[3])), "_:genid35n0")
  assert_eq(mat_vs(mat_obj(emits[3])), "<http://b>")
  assert_eq(mat_vs(mat_subj(emits[4])), "_:genid35n0")
  assert_eq(mat_vs(emits[4].predicate), rest)
  assert_eq(mat_vs(mat_obj(emits[5])), nil_iri)
  assert_eq(mat_vs(mat_obj(emits[6])), "_:genid22n0")
}

///|
test "★3 集合内 [] 作元素：first 链指 fresh bnode + 内层三元组先发" {
  let (emits, errors) = mat_chain(
    "<http://s> <http://p> ( [ <http://q> <http://r> ] <http://a> ) .\n",
  )
  assert_eq(errors.length(), 0)
  // (n0 first br)(br q r)(n0 rest n1)(n1 first a)(n1 rest nil)(s p n0)
  assert_eq(emits.length(), 6)
  assert_eq(mat_vs(mat_obj(emits[0])), "_:genid24")
  assert_eq(mat_vs(mat_subj(emits[1])), "_:genid24")
  assert_eq(mat_vs(mat_obj(emits[1])), "<http://r>")
  assert_eq(mat_vs(mat_obj(emits[2])), "_:genid22n1")
  assert_eq(mat_vs(mat_obj(emits[5])), "_:genid22n0")
}

///|
test "★3 集合字面量元素：数值 typed 展开 + 简单字面量保真" {
  let (emits, errors) = mat_chain(
    "<http://s> <http://p> ( 1 \"two\" ) .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 5)
  assert_eq(
    mat_vs(mat_obj(emits[0])),
    "\"1\"^^<http://www.w3.org/2001/XMLSchema#integer>",
  )
  assert_eq(mat_vs(mat_obj(emits[2])), "\"two\"")
}

///|
test "★3 集合未闭合：区域无 Dot 出边（表即裁决）+ EOF 栈判脏" {
  // 集合内语句点：ExpectElemOrEnd/AfterElem 无 Dot 行 → UnexpectedEvent 恢复
  let (_, errors1) = mat_chain("<http://s> <http://p> ( <http://a> .\n")
  assert_true(errors1.length() > 0)
  // EOF 未闭合：slot_stack 判脏 + finish 自排水（不无限重报）
  let (_, errors2) = mat_chain("<http://s> <http://p> ( <http://a>")
  assert_true(errors2.length() > 0)
}

///|
test "★3 回收: 词法后缀门——字面量紧邻 ) 出独立结构符（lists-05 口径）" {
  // 旧"只认空白收束"把 "a") 的闭括号吞进词项；门收紧后 `"a"` 出 Literal、
  // `)` 出 Rparen，集合元素位正常闭合
  let (emits, errors) = mat_chain(
    "<http://s> <http://p> ( \"a\" \"b\") .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 5)
  assert_eq(mat_vs(mat_obj(emits[0])), "\"a\"")
  assert_eq(mat_vs(mat_obj(emits[2])), "\"b\"")
}

///|
test "★3 回收: PrefName 相对展开按 base 解析（subm-01 口径）" {
  // 相对前缀声明 @prefix : <#> → :x 展开仍是相对 IRI → 与词项位相对 IRI
  // 同径按 base 改写；无 base 则报错（与 <rel> 词项口径一致）
  let (emits, errors) = mat_chain(
    "@base <http://ex.org/a/> .\n@prefix : <#> .\n:x :p :o .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://ex.org/a/#x>")
  assert_eq(mat_vs(mat_obj(emits[0])), "<http://ex.org/a/#o>")
  // 无 base：相对展开报错
  let (_, errors2) = mat_chain("@prefix : <#> .\n:x :p :o .\n")
  assert_true(errors2.length() > 0)
}

///|
test "★3 回收: `] }` 图块无点收口 vs 集合主位 `}` 必拒（sole/bad-list 对偶）" {
  // sole 口径：[] 主位图块无点收块，合法（VerbOrDot 的 Rbrace 臂）
  let (emits1, errors1) = mat_chain(
    "<http://g> { [ <http://a/p> <http://a/o> ] }\n",
  )
  assert_eq(errors1.length(), 0)
  assert_eq(emits1.length(), 1)
  // bad-list-03 口径：集合头裸节点谓语必接（ret=GraphExpectPredicate 无 Rbrace 出边）
  let (_, errors2) = mat_chain("{ ( 1 2 3 ) }\n")
  assert_true(errors2.length() > 0)
  // bad-list-04 口径：空集合同拒
  let (_, errors3) = mat_chain("{ ( ) }\n")
  assert_true(errors3.length() > 0)
  // collection-graph-bad 口径：顶层集合后 Lbrace（集合头做图名）必拒
  //（ret=ExpectVerbRequired 无 Lbrace 出边；<g> { 主形态走 ExpectPredicate 行不受扰）
  let (_, errors4) = mat_chain("( 1 2 ) <http://s> <http://p> .\n<http://g> { <http://s> <http://p> <http://o> . }\n")
  assert_eq(errors4.length(), 0)
  let (_, errors5) = mat_chain("( 1 2 ) { <http://s> <http://p> <http://o> . }\n")
  assert_true(errors5.length() > 0)
}

///|
test "★3 回收: 指令后 TT 壳主位（turtle12-bnode-03 口径）" {
  // PREFIX 指令后的 DirectiveEnd 状态补 TripleTerm 主位行；括号壳 <<( 不接
  //（NT reifier 形态只许宾位，bad-10 口径 = 表即裁决）
  let (emits, errors) = mat_chain(
    "PREFIX : <http://example/>\n\n<<:s :p :o >> :q :z .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  // 壳主语：TripleTerm 变体整段保真（mat_subj 不覆盖该变体，直接 match）
  match emits[0].subject {
    @nquads.Subject::TripleTerm(v) => assert_eq(mat_vs(v), "<<:s :p :o >>")
    _ => assert_true(false)
  }
  // 括号壳主位：无行 → 恢复报错
  let (_, errors2) = mat_chain(
    "<<(:s :p :o) >> :q :z .\n",
  )
  assert_true(errors2.length() > 0)
}

///|
test "★3 回收: @ 风格指令名零空格直连冒号拆分（minimal-whitespace 口径）" {
  // `@prefix:<iri>` 词法整词扫出 `prefix:`（冒号是名字字符），适配层拆成
  // PrefixKw + 冒号声明名 PrefName（单槽 pending 先入后兑）；空声明名照常
  let (emits, errors) = mat_chain(
    "@prefix ex:<http://x/> .\nex:s ex:p ex:o .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://x/s>")
  // `@base:<iri>` 非法（base 只收 IRIREF）：BaseKw + 冒号 PrefName 落表外报错
  let (_, errors2) = mat_chain("@base:<http://x/> .\n<s> <p> <o> .\n")
  assert_true(errors2.length() > 0)
  // `@prefix:foo <iri>` 带本地部非法（prefixID 只收 PNAME_NS），不拆、表外报错
  let (_, errors3) = mat_chain("@prefix:foo <http://x/> .\n")
  assert_true(errors3.length() > 0)
  // term 位 `prefix:x` 合法 pname 无 @ 邻接，不受拆分扰动
  let (emits4, errors4) = mat_chain(
    "@prefix prefix: <http://x/> .\nprefix:s prefix:p prefix:o .\n",
  )
  assert_eq(errors4.length(), 0)
  assert_eq(emits4.length(), 1)
  assert_eq(mat_vs(mat_subj(emits4[0])), "<http://x/s>")
}

///|
test "★1 per-quad 快照: 中途换 base / 前缀重声明不污染历史 quad" {
  // quad1 发射时点 bver=0（无 @base）→ 走 fallback（mat_chain 无 fallback →
  // 相对词项报错）；quad2 发射时点 bver=1 → 按 chain[0..1] 折叠出 ns base。
  // 绝对词项不受任何 base 影响，两 quad 均保真——差异在相对词项的改写：
  // 把 quad1 放 @base 声明前且词项全相对 = 报错路径，放声明后 = 改写路径
  let (emits, errors) = mat_chain(
    "<a1> <b1> <c1> .\n@base <http://example.org/ns/> .\n<a2> <b2> <c2> .\n",
  )
  assert_true(errors.length() == 1) // quad1：发射时无生效 base，物化层拒
  // 同文档倒序：@base 先行则两 quad 均按同一 base 改写（基线口径）
  let (emits2, errors2) = mat_chain(
    "@base <http://example.org/ns/> .\n<a1> <b1> <c1> .\n",
  )
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 1)
  assert_eq(mat_vs(mat_subj(emits2[0])), "<http://example.org/ns/a1>")
  // 前缀重声明：quad1 发射时 pver=1（老 ns），quad2 pver=2（新 ns）——
  // 物化回扫上界 pver 保证 ex: 在 quad1 展开为老 ns
  let (emits3, errors3) = mat_chain(
    "@prefix ex: <http://old/> .\nex:a ex:b ex:c .\n@prefix ex: <http://new/> .\nex:a ex:b ex:c .\n",
  )
  assert_eq(errors3.length(), 0)
  assert_eq(emits3.length(), 2)
  assert_eq(mat_vs(mat_subj(emits3[0])), "<http://old/a>")
  assert_eq(mat_vs(emits3[0].predicate), "<http://old/b>")
  assert_eq(mat_vs(mat_obj(emits3[0])), "<http://old/c>")
  assert_eq(mat_vs(mat_subj(emits3[1])), "<http://new/a>")
  assert_eq(mat_vs(emits3[1].predicate), "<http://new/b>")
  assert_eq(mat_vs(mat_obj(emits3[1])), "<http://new/c>")
}

///|
test "★1 base 链: 相对 @base 折叠 + 相对前缀声明随 base 改写（subm-27 口径）" {
  // 链：绝对 ns → 相对 foo/ 合并 = ns/foo/；quad3 全相对词项按折叠 base 改写
  let (emits, errors) = mat_chain(
    "@base <http://example.org/ns/> .\n<a2> <b2> <c2> .\n@base <foo/> .\n<a3> <b3> <c3> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://example.org/ns/a2>")
  assert_eq(mat_vs(mat_subj(emits[1])), "<http://example.org/ns/foo/a3>")
  assert_eq(mat_vs(emits[1].predicate), "<http://example.org/ns/foo/b3>")
  assert_eq(mat_vs(mat_obj(emits[1])), "<http://example.org/ns/foo/c3>")
  // 相对前缀声明（@prefix : <bar#>）：声明 IRI 本身相对，按发射时点 base 改写；
  // 中途重声明（绝对 ns2#）后新 quad 走新 ns（pver 上界口径）
  let (emits2, errors2) = mat_chain(
    "@base <http://example.org/ns/foo/> .\n@prefix : <bar#> .\n:a4 :b4 :c4 .\n@prefix : <http://example.org/ns2#> .\n:a5 :b5 :c5 .\n",
  )
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 2)
  assert_eq(mat_vs(mat_subj(emits2[0])), "<http://example.org/ns/foo/bar#a4>")
  assert_eq(mat_vs(mat_subj(emits2[1])), "<http://example.org/ns2#a5>")
}


///|
test "壳内 ~ reifier：分写 / 连写 / 全连写 / 裸 ~ / IRI 形（syntax-inside 口径）" {
  // 分写 PrefName：尾巴吞掉不计项，壳整段保真
  let (emits1, errors1) = mat_chain(
    "@prefix : <http://example/> .\n:s :p << :s :p :o1 ~ :id >> .\n",
  )
  assert_eq(errors1.length(), 0)
  assert_eq(emits1.length(), 1)
  assert_eq(mat_vs(mat_obj(emits1[0])), "<< :s :p :o1 ~ :id >>")
  // 连写 BlankNode（~ 后无空白）
  let (emits2, errors2) = mat_chain(
    "@prefix : <http://example/> .\n:s :p <<:s :p :o1 ~_:id>> .\n",
  )
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 1)
  // 全连写：~ 粘着第 3 项尾（词法同分写）
  let (emits3, errors3) = mat_chain(
    "@prefix : <http://example/> .\n:s :p <<:s :p :o1~_:id>> .\n",
  )
  assert_eq(errors3.length(), 0)
  assert_eq(emits3.length(), 1)
  // 裸 ~（fresh reifier）
  let (emits4, errors4) = mat_chain(
    "@prefix : <http://example/> .\n:s :p << :s :p :o ~ >> .\n",
  )
  assert_eq(errors4.length(), 0)
  assert_eq(emits4.length(), 1)
  // IRI reifier
  let (emits5, errors5) = mat_chain(
    "@prefix : <http://example/> .\n:s :p << :s :p :o ~ <http://x/> >> .\n",
  )
  assert_eq(errors5.length(), 0)
  assert_eq(emits5.length(), 1)
  // 主位壳带尾巴（turtle12-bnode-03 形 + reifier）：壳是项不是断言，单发射
  let (emits6, errors6) = mat_chain(
    "@prefix : <http://example/> .\n<< :s :p :o ~ :id >> :q :z .\n",
  )
  assert_eq(errors6.length(), 0)
  assert_eq(emits6.length(), 1)
  match emits6[0].subject {
    @nquads.Subject::TripleTerm(v) => assert_eq(mat_vs(v), "<< :s :p :o ~ :id >>")
    _ => assert_true(false)
  }
}

///|
test "壳内 ~ reifier 负例：4 真项 / 项后垃圾 / 双 ~ 仍拒" {
  // 4 真项：没有 ~ 门面，项数判拒
  let (_, errors1) = mat_chain(
    "@prefix : <http://example/> .\n:s :p << :s :p :o :extra >> .\n",
  )
  assert_true(errors1.length() > 0)
  // 项后垃圾再 ~：4 项在途，~ 不相救
  let (_, errors2) = mat_chain(
    "@prefix : <http://example/> .\n:s :p << :s :p :o :x ~ :id >> .\n",
  )
  assert_true(errors2.length() > 0)
  // 双 ~：尾巴只吃一次
  let (_, errors3) = mat_chain(
    "@prefix : <http://example/> .\n:s :p << :s :p :o ~ :id ~ :id2 >> .\n",
  )
  assert_true(errors3.length() > 0)
}


///|
test "[] 图标签/主位/宾位/集合元素（kw-graph-07 + anonymous_blank_node_graph 口径）" {
  // `[] { … }`：ANON 直作图标签，fresh 身份 = `[` offset（此处 0 → genid0）
  let (emits1, errors1) = mat_chain(
    "[] { <http://s> <http://p> <http://o> . }\n",
  )
  assert_eq(errors1.length(), 0)
  assert_eq(emits1.length(), 1)
  match emits1[0].graph {
    @nquads.GraphName::BNode(v) => assert_eq(mat_vs(v), "_:genid0")
    _ => assert_true(false)
  }
  // `GRAPH [] { … }`：关键字路径同达（`[` 在 7 号偏移）
  let (emits2, errors2) = mat_chain(
    "GRAPH [] { <http://s> <http://p> <http://o> . }\n",
  )
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 1)
  match emits2[0].graph {
    @nquads.GraphName::BNode(v) => assert_eq(mat_vs(v), "_:genid6")
    _ => assert_true(false)
  }
  // `[]` 主位：fresh 占 s 槽（graph-kw-06 家族回归口径）
  let (emits3, errors3) = mat_chain(
    "[] <http://p> <http://o> .\n",
  )
  assert_eq(errors3.length(), 0)
  assert_eq(emits3.length(), 1)
  assert_eq(mat_vs(mat_subj(emits3[0])), "_:genid0")
  // `[]` 宾位 + `[ ]` 内含空白变体：fresh 落 o 槽
  let (emits4, errors4) = mat_chain(
    "<http://s> <http://p> [] .\n<http://s> <http://p> [ ] .\n",
  )
  assert_eq(errors4.length(), 0)
  assert_eq(emits4.length(), 2)
  assert_eq(mat_vs(mat_obj(emits4[0])), "_:genid22")
  assert_eq(mat_vs(mat_obj(emits4[1])), "_:genid49")
  // `[]` 集合元素位：fresh 作链元素（first 指向，不开嵌套帧）；
  // 单元素链 = first + rest:nil 两链 + 主三元组
  let (emits5, errors5) = mat_chain(
    "( [] ) <http://p> <http://o> .\n",
  )
  assert_eq(errors5.length(), 0)
  assert_eq(emits5.length(), 3)
  // 指令后 `[]` 主位
  let (emits6, errors6) = mat_chain(
    "PREFIX : <http://example/>\n\n[] :p :o .\n",
  )
  assert_eq(errors6.length(), 0)
  assert_eq(emits6.length(), 1)
}

///|
test "[] 图标签负例：非空属性列表落图位必拒（bnodeplist-graph-bad-01 口径）" {
  let (_, errors1) = mat_chain(
    "[ <http://a> <http://b> ] { <http://s> <http://p> <http://o> . }\n",
  )
  assert_true(errors1.length() > 0)
  // `[] .`：谓语位缺（表无边自然拒）
  let (_, errors2) = mat_chain("[] .\n")
  assert_true(errors2.length() > 0)
}


///|
test "注解体内 fresh 结构：[] 嵌套帧 + [] 终结符（annotation-2 口径）" {
  // 注解体宾位 `[ … ]`：嵌套帧快照注解体 s/p/g，弹帧回 AnnotExpectEnd，
  // `;` 链与 `|}` 收口不受扰
  let (emits1, errors1) = mat_chain(
    "@prefix : <http://example/> .\n@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n:G {\n  :s :p :o {| :source [ :graph <http://host1/> ;\n                        :date \"2020-01-20\"^^xsd:date\n                      ] ;\n              :source [ :graph <http://host2/> ;\n                        :date \"2020-12-31\"^^xsd:date\n                      ]\n            |} .\n}\n",
  )
  assert_eq(errors1.length(), 0)
  assert_true(emits1.length() >= 3)
  // 注解体宾位 `[]` 终结符：fresh 直落
  let (emits2, errors2) = mat_chain(
    "@prefix : <http://example/> .\n:s :p :o {| :q [] |} .\n",
  )
  assert_eq(errors2.length(), 0)
  assert_true(emits2.length() >= 2)
  // 图块注解体孪生
  let (emits3, errors3) = mat_chain(
    "@prefix : <http://example/> .\n:G { :s :p :o {| :q [ :a :b ] |} . }\n",
  )
  assert_eq(errors3.length(), 0)
  assert_true(emits3.length() >= 2)
}
