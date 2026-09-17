// 错误对象的**展示面与访问器**逐变体测试。
// 背景（覆盖率实测 2026-09-18）：error.mbt 此前 79/101 行未覆盖——错误对象只在失败路径
// 被构造，而 `to_span` / `position` / `ErrOut` / `Show` 这些面没人跑过。
// 调用口径：方法隐式提升已 deprecated ⇒ 显式 `Show::to_string` / `ErrOut::…`。

///|
test "error: ParseError 的 to_span 四变体" {
  assert_eq(
    ParseError::to_span(ParseError::StructSyntaxErr("m", 2, (10, 4))),
    (10, 4),
  )
  assert_eq(ParseError::to_span(ParseError::SyntaxErr("m", (1, 2))), (1, 2))
  assert_eq(ParseError::to_span(ParseError::ValidationErr("m")), (0, 0))
  assert_eq(ParseError::to_span(ParseError::IriErr("m")), (0, 0))
}

///|
test "error: ParseError 的 ErrOut（message / err_kind）四变体" {
  let cases : Array[(ParseError, String)] = [
    (ParseError::StructSyntaxErr("bad", 2, (10, 4)), "StructSyntaxErr"),
    (ParseError::SyntaxErr("bad", (1, 2)), "SyntaxErr"),
    (ParseError::ValidationErr("bad"), "ValidationErr"),
    (ParseError::IriErr("bad"), "IriErr"),
  ]
  for case in cases {
    let (err, kind) = case
    assert_eq(ErrOut::err_kind(err), kind)
    assert_eq(ErrOut::message(err), "bad")
  }
}

///|
test "error: ParseError 的展示面四变体" {
  assert_eq(Show::to_string(ParseError::ValidationErr("boom")), "boom")
  assert_eq(
    Show::to_string(ParseError::StructSyntaxErr("bad", 2, (10, 4))),
    "bad at line :2 at position (10, 4)",
  )
  assert_eq(
    Show::to_string(ParseError::SyntaxErr("bad", (1, 2))),
    "bad at position (1, 2)",
  )
  assert_eq(Show::to_string(ParseError::IriErr("bad")), "bad")
}

///|
test "error: IriError 的 position 七变体（InvalidAuthority 恒 -1）" {
  assert_eq(IriError::NoScheme(3).position(), 3)
  assert_eq(IriError::InvalidScheme('x', 4).position(), 4)
  assert_eq(IriError::InvalidCharacter('x', 5).position(), 5)
  assert_eq(IriError::InvalidPath(6).position(), 6)
  assert_eq(IriError::InvalidAuthority("host").position(), -1)
  assert_eq(IriError::InvalidPercentEncoding(7).position(), 7)
  assert_eq(IriError::UnexpectedEnd(8).position(), 8)
}

///|
test "error: IriError 的 ErrOut（message / err_kind）七变体" {
  let cases : Array[(IriError, String, String)] = [
    (IriError::NoScheme(0), "NoScheme", "No scheme found"),
    (
      IriError::InvalidScheme('x', 0),
      "InvalidScheme",
      "Invalid scheme character",
    ),
    (
      IriError::InvalidCharacter('x', 0),
      "InvalidCharacter",
      "Invalid character",
    ),
    (IriError::InvalidPath(0), "InvalidPath", "Invalid path"),
    (
      IriError::InvalidAuthority("h"),
      "InvalidAuthority",
      "Invalid authority: h",
    ),
    (
      IriError::InvalidPercentEncoding(0),
      "InvalidPercentEncoding",
      "Invalid percent encoding",
    ),
    (IriError::UnexpectedEnd(0), "UnexpectedEnd", "Unexpected end of input"),
  ]
  for case in cases {
    let (err, kind, msg) = case
    assert_eq(ErrOut::err_kind(err), kind)
    assert_eq(ErrOut::message(err), msg)
  }
}

///|
test "error: IriError 展示面（有位置 / 无位置两档）" {
  assert_eq(
    Show::to_string(IriError::NoScheme(3)),
    "NoScheme - No scheme found at position 3",
  )
  assert_eq(
    Show::to_string(IriError::InvalidAuthority("h")),
    "InvalidAuthority - Invalid authority: h",
  )
}

///|
test "error: TagParseErr 展示面十变体" {
  assert_eq(Show::to_string(TagParseErr::EmptyTag), "EmptyTag")
  assert_eq(Show::to_string(TagParseErr::EmptySubtag), "EmptySubtag")
  assert_eq(
    Show::to_string(TagParseErr::InvalidLanguageLength),
    "InvalidLanguageLength",
  )
  assert_eq(Show::to_string(TagParseErr::ForbiddenChar), "ForbiddenChar")
  assert_eq(Show::to_string(TagParseErr::TooManyExtlangs), "TooManyExtlangs")
  assert_eq(
    Show::to_string(TagParseErr::InvalidSubtag((1, 2), "xy"[:])),
    "InvalidSubtag: xy",
  )
  assert_eq(Show::to_string(TagParseErr::EmptyExtension), "EmptyExtension")
  assert_eq(Show::to_string(TagParseErr::EmptyPrivateUse), "EmptyPrivateUse")
  assert_eq(Show::to_string(TagParseErr::InvalidVariant), "InvalidVariant")
  assert_eq(
    Show::to_string(TagParseErr::InvalidPrivateUsePrefix),
    "InvalidPrivateUsePrefix",
  )
}
