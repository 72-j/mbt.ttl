// langtag：展示面 + 扩展/私有使用访问器 + 解析失败面。
// 背景（覆盖率实测 2026-09-18）：langtag.mbt 有 94 行未覆盖——三条以上 Show impl、
// 扩展迭代器、以及扩展/私有使用两条错误分支都没被跑过。
// 调用口径：方法隐式提升已 deprecated ⇒ 一律显式 `Show::to_string`。

///|
test "langtag: Show 四件（Extension / PrivateUse / TagState / LanguageTag）" {
  let extension : Extension = { ident: (10, 1), subtags: [(12, 2), (15, 6)], }
  let extension_text = Show::to_string(extension)
  assert_true(extension_text.has_prefix("Extension:"))
  assert_true(extension_text.contains("subtags:"))
  let private_use : PrivateUse = { prefix: (5, 1), subtags: [(7, 4)], }
  assert_true(Show::to_string(private_use).has_prefix("PrivateUse:"))
  let tag = LanguageTag::parse("sl-afb-Latn-005-nedis"[:]).unwrap()
  let tag_text = Show::to_string(tag)
  assert_true(tag_text.has_prefix("LanguageTag:"))
  assert_true(tag_text.contains("tag: sl-afb-Latn-005-nedis"))
  assert_true(Show::to_string(tag.state).has_prefix("TagState:"))
}

///|
test "langtag: 扩展与私有使用访问器（has_* / extensions / private_use_subtags）" {
  let with_extension = LanguageTag::parse("en-u-nu-latn"[:]).unwrap()
  assert_true(with_extension.has_extensions())
  assert_false(with_extension.has_private_use())
  // 迭代器两条使用面：`extension_subtags()` 手动 next（to_array 内部亦走它）与 `extensions()`
  let extension_items = with_extension.extension_subtags().to_array()
  assert_eq(extension_items.length(), 1)
  let (ident, subtags) = extension_items[0]
  assert_eq(ident.to_owned(), "u")
  assert_eq(subtags.length(), 2)
  assert_eq(subtags[0].to_owned(), "nu")
  assert_eq(with_extension.extensions().to_array().length(), 1)
  let with_private_use = LanguageTag::parse("en-x-corp-private"[:]).unwrap()
  assert_true(with_private_use.has_private_use())
  assert_false(with_private_use.has_extensions())
  assert_eq(with_private_use.private_use_subtags().length(), 2)
  assert_eq(with_private_use.private_use_subtags()[0].to_owned(), "corp")
}

///|
test "langtag: 解析失败面（EmptySubtag / 扩展非法子标签 / 私有使用非法子标签）" {
  // scan_subtags 拿不到子标签（本用例走 parse_tag 的空表分支）
  assert_true(LanguageTag::parse("-"[:]) is Err(_))
  // 扩展子标签超 8 位（is_valid_private_use_subtag 拒）
  let long_subtag = "en-u-toolongsubtag"
  match LanguageTag::parse(long_subtag[:]) {
    Err(TagParseErr::InvalidSubtag(_, view)) =>
      assert_eq(view.to_owned(), "toolongsubtag")
    _ => fail("扩展非法子标签必须报 InvalidSubtag：\{long_subtag}")
  }
  // 私有使用子标签超 8 位（与扩展两条分支相对）
  match LanguageTag::parse("x-toolongsubtag"[:]) {
    Err(TagParseErr::InvalidSubtag(_, view)) =>
      assert_eq(view.to_owned(), "toolongsubtag")
    _ => fail("私有使用非法子标签必须报 InvalidSubtag")
  }
  // normalize 透传 Err（不吞错）
  assert_true(LanguageTag::parse_and_normalize(long_subtag[:]) is Err(_))
}
