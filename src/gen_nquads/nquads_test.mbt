// ===== gen_nquads 解析测试 =====
// 验证：fsm 生成器产出的状态机（nquads.mbt）+ 用户补充部分（Actions/引擎/SliceParser）
// 能正确解析真实 N-Quads 输入 —— 检验 fsm 生成器的生成效果

///|
fn bytes_of(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
fn view_str(view : ArrayView[Byte]) -> String {
  let buf = StringBuilder()
  for i = 0; i < view.length(); i = i + 1 {
    buf.write_char(view[i].to_char())
  }
  buf.to_string()
}

///|
test "simple triple" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  let (quads, errors) = nquads_parser(bytes_of(input))
  assert_eq(quads.length(), 1)
  let q = quads[0]
  assert_eq(view_str(q.subj), "<http://example.org/s>")
  assert_eq(view_str(q.pred), "<http://example.org/p>")
  assert_eq(view_str(q.obj), "<http://example.org/o>")
  assert_true(q.graph is None)
  assert_eq(q.subj_type, TermType::Iri)
  assert_eq(q.obj_type, TermType::Iri)
  assert_eq(errors.length(), 0)
}

///|
test "quad with graph name" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> <http://example.org/g> .\n"
  let (quads, _errors) = nquads_parser(bytes_of(input))
  assert_eq(quads.length(), 1)
  match quads[0].graph {
    Some(g) => assert_eq(view_str(g), "<http://example.org/g>")
    None => fail("expected graph")
  }
}

///|
test "bnode subject and literal object" {
  let input = "_:b1 <http://example.org/p> \"hello\" .\n"
  let (quads, _errors) = nquads_parser(bytes_of(input))
  assert_eq(quads.length(), 1)
  let q = quads[0]
  assert_eq(view_str(q.subj), "_:b1")
  assert_eq(q.subj_type, TermType::BNode)
  assert_eq(view_str(q.obj), "\"hello\"")
  assert_eq(q.obj_type, TermType::Literal)
  assert_eq(view_str(q.pred), "<http://example.org/p>")
}

///|
test "multiple lines with comments and blank line" {
  let input =
    #|# comment line
    #|<http://example.org/s1> <http://example.org/p1> <http://example.org/o1> .
    #|
    #|<http://example.org/s2> <http://example.org/p2> _:b2 .
  let (quads, errors) = nquads_parser(bytes_of(input))
  assert_eq(quads.length(), 2)
  assert_eq(view_str(quads[1].obj), "_:b2")
  assert_eq(quads[1].obj_type, TermType::BNode)
  assert_eq(errors.length(), 0)
}

///|
test "error token skips line and valid line still parsed" {
  // `,` 出现在谓语位：无转移 → 兜底按 SkipError 处理，消费到 `.` 后继续
  let input =
    #|<http://example.org/s> , <http://example.org/o> .
    #|<http://example.org/s2> <http://example.org/p2> <http://example.org/o2> .
  let (quads, errors) = nquads_parser(bytes_of(input))
  assert_eq(quads.length(), 1)
  assert_eq(view_str(quads[0].subj), "<http://example.org/s2>")
  assert_true(errors.length() >= 1)
}

///|
test "incomplete triple at end of input" {
  let input = "<http://example.org/s> <http://example.org/p>"
  let engine = NQuadsEngine::from_bytes(bytes_of(input))
  assert_true(engine.next() is Some(Err(_)))
}

///|
test "strict mode rejects bad IRI, lenient mode accepts" {
  let input = "<bad-scheme> <http://example.org/p> <http://example.org/o> .\n"
  // 严格模式：validate_iri 拒绝非 http/https/ftp/mailto 前缀
  let (quads, errors) = nquads_parser(bytes_of(input))
  assert_eq(quads.length(), 0)
  assert_eq(errors.length(), 1)
  // 宽松模式：跳过验证
  let (quads2, errors2) = nquads_parser(bytes_of(input), lenient=true)
  assert_eq(quads2.length(), 1)
  assert_eq(errors2.length(), 0)
  assert_eq(view_str(quads2[0].subj), "<bad-scheme>")
}

///|
test "双引擎一致性: Lexermoon 与 C Lexerc 解析结果相同" {
  let input = "<http://example.org/s1> <http://example.org/p1> \"hello\" .\n" +
    "# 注释行\n" +
    "_:b1 <http://example.org/p2> _:b2 <http://example.org/g1> .\n" +
    "<http://example.org/s3>, <http://example.org/p3> <http://example.org/o3> .\n" +
    "<http://example.org/s4> <http://example.org/p4> <http://example.org/o4> .\n"
  // Tokenizer（纯 MoonBit 词法）
  let (quads, errors) = nquads_parser(bytes_of(input), lenient=true)
  // C Lexerc（FFI 词法，同一状态机）
  let (quads_c, errors_c) = nquads_parser_c(
    @utf8.encode(input).to_fixedarray(),
    lenient=true,
  )
  assert_eq(quads.length(), 3)
  assert_eq(quads_c.length(), quads.length())
  assert_eq(errors_c.length(), errors.length())
  // 逐条比较四元组切片
  for i in 0..<quads.length() {
    assert_eq(view_str(quads[i].subj), view_str(quads_c[i].subj))
    assert_eq(view_str(quads[i].pred), view_str(quads_c[i].pred))
    assert_eq(view_str(quads[i].obj), view_str(quads_c[i].obj))
    let graph_eq = match (quads[i].graph, quads_c[i].graph) {
      (None, None) => true
      (Some(a), Some(b)) => view_str(a) == view_str(b)
      (_, _) => false
    }
    assert_true(graph_eq)
    assert_eq(quads[i].subj_type, quads_c[i].subj_type)
    assert_eq(quads[i].obj_type, quads_c[i].obj_type)
  }
  // 具体内容抽查（字面量 / bnode / 图名）
  assert_eq(view_str(quads_c[0].obj), "\"hello\"")
  assert_eq(view_str(quads_c[1].subj), "_:b1")
  assert_true(quads_c[1].graph is Some(_))
}

///|
test "回归: 未终结输入 parse_all 必须终止且报错" {
  // 曾经的死循环：EOF 脏记录 → begin_record 只清槽位不复位 state →
  // finish_at_end 无限重报。现 begin_record 归位 state，EOF 报错收集即止
  let input = "<http://e.org/s> <http://e.org/p> \"x\""
  let (quads, errors) = nquads_parser(bytes_of(input), lenient=false)
  assert_eq(quads.length(), 0)
  assert_true(errors.length() >= 1)
}

///|
/// Token → (类型号, offset, len) 归一键（类型号沿用 C 侧 ctype 编号）
fn tok_kind_key(t : Token) -> (Int, Int, Int) {
  match t {
    Token::Dot(s) => (0, s.0, s.1)
    Token::Semicolon(s) => (1, s.0, s.1)
    Token::Comma(s) => (2, s.0, s.1)
    Token::Iri(s) => (3, s.0, s.1)
    Token::Literal(s) => (4, s.0, s.1)
    Token::BlankNode(s) => (5, s.0, s.1)
    Token::PrefName(s) => (6, s.0, s.1)
    Token::Unknown(s) => (7, s.0, s.1)
    Token::EOF(_) => (8, 0, 0)
    Token::TripleTerm(s) => (9, s.0, s.1)
  }
}

///|
/// 加字词（N3 预埋）pin：=> 与 <= 整词 Unknown(2)（{|/|} 同机械）；
/// 裸 = / > 单字 Unknown(1) 不变，>> 拆两单字，<g> 普通 IRI 不受 <= 判别干扰；
/// 双词法器逐 token 同口径（口径一致是硬约定，分歧即失败）
test "lexer 加字词: => / <= 整词出，双词法器同口径" {
  let input = "ex:a => ex:b .\nex:c <= ex:d .\nex:e = ex:f .\n<g> >> <h> .\n"
  let data = bytes_of(input)
  let moon = Lexermoon::new(data[:]).tokenize()
  // MoonBit 侧形态断言（末位 EOF 不计）
  let mut arrow = 0
  let mut implied = 0
  let mut bare_eq = 0
  let mut bare_gt = 0
  for i in 0..<(moon.length() - 1) {
    match moon[i] {
      Token::Unknown((off, len)) => {
        let c0 = data[off]
        if len == 2 && c0 == b'=' {
          arrow = arrow + 1
        } else if len == 2 && c0 == b'<' {
          implied = implied + 1
        } else if len == 1 && c0 == b'=' {
          bare_eq = bare_eq + 1
        } else if len == 1 && c0 == b'>' {
          bare_gt = bare_gt + 1
        } else {
          ()
        }
      }
      _ => ()
    }
  }
  assert_eq(arrow, 1)
  assert_eq(implied, 1)
  assert_eq(bare_eq, 1)
  assert_eq(bare_gt, 2)
  // C 侧同口径比对
  let fa = @utf8.encode(input).to_fixedarray()
  let lex = Lexerc::new(fa)
  let n = moon.length() - 1
  let mut i = 0
  for ;; {
    match lex.next() {
      None => {
        assert_eq(i, n)
        break
      }
      Some(t) => {
        assert_eq(tok_kind_key(t), tok_kind_key(moon[i]))
        i = i + 1
      }
    }
  }
  lex.destroy()
}
