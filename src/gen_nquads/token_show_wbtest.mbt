// ===== Token Show 冒烟（役 A 结构性裁决）：十变体逐臂点亮，2026-09-20 =====
// 冻结词法样本的 Show 实现此前无测试宿主（0 覆盖）；插值 `\{token}` 走 Show，
// 逐变体断言渲染文本 = 逐臂点亮 + 格式钉（改动即红）。

///|
test "wb·Token Show：十变体渲染逐臂 + 格式钉" {
  assert_eq("\{Token::Dot((0, 1))}", "Dot(0,1)")
  assert_eq("\{Token::Semicolon((0, 1))}", "Semicolon(0,1)")
  assert_eq("\{Token::Comma((0, 1))}", "Comma(0,1)")
  assert_eq("\{Token::Iri((2, 3))}", "Iri(2,3)")
  assert_eq("\{Token::Literal((4, 5))}", "Literal(4,5)")
  assert_eq("\{Token::BlankNode((6, 7))}", "BlankNode(6,7)")
  assert_eq("\{Token::PrefName((8, 9))}", "PrefName(8,9)")
  assert_eq("\{Token::TripleTerm((10, 11))}", "TripleTerm(10,11)")
  assert_eq("\{Token::Unknown((12, 13))}", "Unknown(12,13)")
  assert_eq("\{Token::EOF(14)}", "EOF(14)")
}
