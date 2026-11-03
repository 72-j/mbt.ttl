///|
/// U2 电池：同构比较器律面（值等/双射/数据集/复合项/引形）
/// 案号即断言——true 组 = 等价对，false 组 = 反例

///|
fn iso_row(
  g : String,
  s : String,
  p : String,
  o : String,
) -> (String, String, String, String) {
  (g, s, p, o)
}

///|
test "iso: 地面行恒等与序无关" {
  let a = [iso_row("", "<s>", "<p>", "<o>"), iso_row("", "<s>", "<p>", "<o2>")]
  let b = [iso_row("", "<s>", "<p>", "<o2>"), iso_row("", "<s>", "<p>", "<o>")]
  assert_eq(rows_isomorphic(a, b), true)
  let c = [iso_row("", "<s>", "<p>", "<o>")]
  assert_eq(rows_isomorphic(a, c), false)
}

///|
test "iso: bnode 换标等价" {
  let a = [iso_row("", "_:a", "<p>", "<o>")]
  let b = [iso_row("", "_:x", "<p>", "<o>")]
  assert_eq(rows_isomorphic(a, b), true)
}

///|
test "iso: 三链 vs 三链（双射）与链 vs 星（反例）" {
  let chain_l = [
    iso_row("", "_:a", "<p>", "_:b"),
    iso_row("", "_:b", "<p>", "_:c"),
    iso_row("", "_:c", "<p>", "<o>"),
  ]
  let chain_r = [
    iso_row("", "_:q", "<p>", "_:r"),
    iso_row("", "_:r", "<p>", "_:s"),
    iso_row("", "_:s", "<p>", "<o>"),
  ]
  assert_eq(rows_isomorphic(chain_l, chain_r), true)
  let star_r = [
    iso_row("", "_:c", "<p>", "_:a"),
    iso_row("", "_:c", "<p>", "_:b"),
    iso_row("", "_:c", "<p>", "<o>"),
  ]
  assert_eq(rows_isomorphic(chain_l, star_r), false)
}

///|
test "iso: IRI 转义值等" {
  let a = [iso_row("", "<http://e/\\u0053>", "<p>", "<o>")]
  let b = [iso_row("", "<http://e/S>", "<p>", "<o>")]
  assert_eq(rows_isomorphic(a, b), true)
}

///|
test "iso: 字面量转义体值等（\\n 转义形 vs 原生 LF）" {
  let a = [iso_row("", "<s>", "<p>", "\"a\\nb\"")]
  let b = [iso_row("", "<s>", "<p>", "\"a\nb\"")]
  assert_eq(rows_isomorphic(a, b), true)
}

///|
test "iso: langtag 大小写值等；方向异为反例" {
  let a = [iso_row("", "<s>", "<p>", "\"chat\"@EN")]
  let b = [iso_row("", "<s>", "<p>", "\"chat\"@en")]
  assert_eq(rows_isomorphic(a, b), true)
  let rtl = [iso_row("", "<s>", "<p>", "\"x\"@en--rtl")]
  let ltr = [iso_row("", "<s>", "<p>", "\"x\"@en--ltr")]
  assert_eq(rows_isomorphic(rtl, ltr), false)
}

///|
test "iso: 简形 = 显式 xsd:string；异数据型反例" {
  let plain = [iso_row("", "<s>", "<p>", "\"x\"")]
  let typed = [
    iso_row(
      "", "<s>", "<p>", "\"x\"^^<http://www.w3.org/2001/XMLSchema#string>",
    ),
  ]
  assert_eq(rows_isomorphic(plain, typed), true)
  let int_dt = [
    iso_row(
      "", "<s>", "<p>", "\"2\"^^<http://www.w3.org/2001/XMLSchema#integer>",
    ),
  ]
  let plain2 = [iso_row("", "<s>", "<p>", "\"2\"")]
  assert_eq(rows_isomorphic(plain2, int_dt), false)
}

///|
test "iso: 数据型 IRI 转义值等" {
  let a = [iso_row("", "<s>", "<p>", "\"v\"^^<http://e/\\u0053>")]
  let b = [iso_row("", "<s>", "<p>", "\"v\"^^<http://e/S>")]
  assert_eq(rows_isomorphic(a, b), true)
}

///|
test "iso: 复合项壳内外空白无关 + 内嵌 bnode 双射" {
  let spaced = [iso_row("", "<s>", "<p>", "<<( _:a <q> <o> )>>")]
  let tight = [iso_row("", "<s>", "<p>", "<<(_:z <q> <o>)>>")]
  assert_eq(rows_isomorphic(spaced, tight), true)
  let diff_pred = [iso_row("", "<s>", "<p>", "<<(_:z <r> <o>)>>")]
  assert_eq(rows_isomorphic(spaced, diff_pred), false)
}

///|
test "iso: 嵌套复合项（壳中壳）值等" {
  let a = [
    iso_row("", "<s>", "<p>", "<<( <s1> <p1> <<( <s2> <p2> <o2> )>> )>>"),
  ]
  let b = [iso_row("", "<s>", "<p>", "<<(<s1><p1><<( <s2> <p2> <o2> )>>)>>")]
  assert_eq(rows_isomorphic(a, b), true)
}

///|
test "iso: 具名图槽异 = 反例；bnode 图标签双射 = 等价" {
  let g1 = [iso_row("<g1>", "<s>", "<p>", "<o>")]
  let g2 = [iso_row("<g2>", "<s>", "<p>", "<o>")]
  assert_eq(rows_isomorphic(g1, g2), false)
  let bg1 = [iso_row("_:g", "<s>", "<p>", "<o>")]
  let bg2 = [iso_row("_:h", "<s>", "<p>", "<o>")]
  assert_eq(rows_isomorphic(bg1, bg2), true)
}

///|
test "iso: 引形归一（三引/单引/双引同词面）" {
  let long3 = [iso_row("", "<s>", "<p>", "\"\"\"x\"\"\"")]
  let short = [iso_row("", "<s>", "<p>", "\"x\"")]
  assert_eq(rows_isomorphic(long3, short), true)
  let single = [iso_row("", "<s>", "<p>", "'x'")]
  assert_eq(rows_isomorphic(single, short), true)
  let single3 = [iso_row("", "<s>", "<p>", "'''y'''")]
  let short_y = [iso_row("", "<s>", "<p>", "\"y\"")]
  assert_eq(rows_isomorphic(single3, short_y), true)
}

///|
test "iso: bnode 计数失配快拒" {
  let one = [iso_row("", "_:a", "<p>", "<o>")]
  let two = [iso_row("", "_:a", "<p>", "_:b")]
  assert_eq(rows_isomorphic(one, two), false)
}
