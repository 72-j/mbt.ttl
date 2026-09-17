// 基础类型卷（types.mbt）的**错误外观 / 展示面 / 切分工具**测试。
// 背景（覆盖率实测 2026-09-18）：gen_trig/types.mbt 此前只有 2/86 行覆盖——
// `ErrOut` 两个 impl、`Show for TrigEvent` 的三十余条臂、`slice_span` 都没被跑过。
// 调用口径：方法隐式提升已 deprecated ⇒ 一律显式 `Show::to_string` / `ErrOut::…`。

///|
fn trig_view(text : String) -> ArrayView[Byte] {
  @utf8.encode(text).to_array()[:]
}

///|
fn trig_view_str(view : ArrayView[Byte]) -> String {
  let buf = StringBuilder()
  for i = 0; i < view.length(); i = i + 1 {
    buf.write_char(view[i].to_char())
  }
  buf.to_string()
}

///|
test "trig types: ErrOut for ParseError 四变体（message / err_kind）" {
  let cases : Array[(ParseError, String)] = [
    (ParseError::ValidationErr("bad"), "ValidationErr"),
    (ParseError::StructSyntaxErr("bad", 2, (10, 4)), "StructSyntaxErr"),
    (ParseError::SyntaxErr("bad", (1, 2)), "SyntaxErr"),
    (ParseError::IriErr("bad"), "IriErr"),
  ]
  for case in cases {
    let (err, kind) = case
    assert_eq(ErrOut::err_kind(err), kind)
    assert_eq(ErrOut::message(err), "bad")
  }
}

///|
test "trig types: slice_span 正常 / 越界三档（越界退化为空视图）" {
  let data = trig_view("abcdef")
  assert_eq(trig_view_str(slice_span(data, (1, 2))), "bc")
  assert_eq(trig_view_str(slice_span(data, (0, 6))), "abcdef")
  assert_eq(trig_view_str(slice_span(data, (10, 5))), "")
  assert_eq(trig_view_str(slice_span(data, (-1, 1))), "")
  assert_eq(trig_view_str(slice_span(data, (0, 99))), "")
}

///|
test "trig types: TrigEvent 展示面——无载荷 24 变体逐条等值" {
  assert_eq(Show::to_string(TrigEvent::TrigAt), "@")
  assert_eq(Show::to_string(TrigEvent::TrigPrefixKw), "PrefixKw")
  assert_eq(Show::to_string(TrigEvent::TrigBaseKw), "BaseKw")
  assert_eq(Show::to_string(TrigEvent::TrigGraphKw), "GraphKw")
  assert_eq(Show::to_string(TrigEvent::TrigVersionKw), "VersionKw")
  assert_eq(Show::to_string(TrigEvent::TrigComma), "Comma")
  assert_eq(Show::to_string(TrigEvent::TrigSemicolon), "Semicolon")
  assert_eq(Show::to_string(TrigEvent::TrigDot), "Dot")
  assert_eq(Show::to_string(TrigEvent::TrigLbrace), "Lbrace")
  assert_eq(Show::to_string(TrigEvent::TrigRbrace), "Rbrace")
  assert_eq(Show::to_string(TrigEvent::TrigRbracket), "Rbracket")
  assert_eq(Show::to_string(TrigEvent::TrigRparen), "Rparen")
  assert_eq(Show::to_string(TrigEvent::TrigUnknown), "Unknown")
  assert_eq(Show::to_string(TrigEvent::TrigEOF), "EOF")
  assert_eq(Show::to_string(TrigEvent::TrigAnnotStart), "AnnotStart")
  assert_eq(Show::to_string(TrigEvent::TrigAnnotEnd), "AnnotEnd")
  assert_eq(Show::to_string(TrigEvent::TrigTilde), "Tilde")
  assert_eq(Show::to_string(TrigEvent::TrigBang), "Bang")
  assert_eq(Show::to_string(TrigEvent::TrigCaret), "Caret")
  assert_eq(Show::to_string(TrigEvent::TrigImplies), "Implies")
  assert_eq(Show::to_string(TrigEvent::TrigImpliedBy), "ImpliedBy")
  assert_eq(Show::to_string(TrigEvent::TrigForAllKw), "ForAllKw")
  assert_eq(Show::to_string(TrigEvent::TrigForSomeKw), "ForSomeKw")
  assert_eq(Show::to_string(TrigEvent::TrigKeywordsKw), "KeywordsKw")
}

///|
test "trig types: TrigEvent 展示面——带载荷 10 变体（前缀 + 载荷 span）" {
  let span : Span = (3, 4)
  let cases : Array[(TrigEvent, String)] = [
    (TrigEvent::TrigIri(span), "IRI "),
    (TrigEvent::TrigBlankNode(span), "BlankNode "),
    (TrigEvent::TrigLiteral(span), "Literal "),
    (TrigEvent::TrigPrefName(span), "PrefName "),
    (TrigEvent::TrigTripleTerm(span), "TripleTerm "),
    (TrigEvent::TrigBracketTripleTerm(span), "BracketTripleTerm "),
    (TrigEvent::TrigKeywordA(span), "KeywordA "),
    (TrigEvent::TrigLbracket(span), "Lbracket "),
    (TrigEvent::TrigLparen(span), "Lparen "),
    (TrigEvent::TrigAnon(span), "Anon "),
  ]
  for case in cases {
    let (event, prefix) = case
    let text = Show::to_string(event)
    assert_true(text.has_prefix(prefix))
    assert_true(text.contains("(3, 4)"))
  }
}
