// ===== 役9 注解精化钉：体主语 = TT 壳（与 gen_n3 役8 同构，双区口径）=====
// 引擎 span 级（trig_parser lenient=true，跨前缀无关）；物化级（mat_chain，
// @prefix 必带——物化层要展开）。壳 span = 锚主语起点→锚宾语终点的原文连续
// 区间（含原空白）；物化层合成 <<原文>> TT 壳。

///|
test "役9 顶层正典：主 quad 锚槽 + 体 quad 壳主语 span" {
  let data = @utf8.encode(":s :p :o {| :q :z |} .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  // 主 quad：锚槽位原样，无壳
  assert_eq(quads[0].s, (0, 2))
  assert_eq(quads[0].p, (3, 2))
  assert_eq(quads[0].o, (6, 2))
  assert_false(quads[0].subj_shell)
  // 体 quad：主语 = 锚三元组原文区间 ":s :p :o"
  assert_eq(quads[1].s, (0, 8))
  assert_eq(quads[1].p, (12, 2))
  assert_eq(quads[1].o, (15, 2))
  assert_true(quads[1].subj_shell)
}

///|
test "役9 图块区：体 quad 壳主语 + 图名保持" {
  let data = @utf8.encode(":g { :s :p :o {| :q :z |} . }\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  assert_eq(quads[0].g, Some((0, 2)))
  assert_false(quads[0].subj_shell)
  // 体 quad：壳 span ":s :p :o"（(5, 11+2-5)），图名随行保持
  assert_eq(quads[1].s, (5, 8))
  assert_eq(view_str(data[:], quads[1].s), ":s :p :o")
  assert_eq(quads[1].p, (17, 2))
  assert_eq(quads[1].o, (20, 2))
  assert_eq(quads[1].g, Some((0, 2)))
  assert_true(quads[1].subj_shell)
}

///|
test "役9 收尾续锚：|} ; 尾句照常发射（shell 落假）" {
  let data = @utf8.encode(":s :p :o {| :q :z |} ; :r :w .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_true(quads[1].subj_shell)
  // 尾句：PredObj reset 保锚主语在槽，shell false
  assert_eq(quads[2].s, (0, 2))
  assert_eq(quads[2].p, (23, 2))
  assert_eq(quads[2].o, (26, 2))
  assert_false(quads[2].subj_shell)
}

///|
test "役9 嵌套 bnp：内层 fresh 主语错键不换 + 旗落假" {
  let data = @utf8.encode(":s :p :o {| :q [ :x :y ] |} .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_false(quads[0].subj_shell)
  // 内层 quad：fresh 主语（`[` span），错键不换且旗被强制落假
  assert_eq(quads[1].s, (15, 1))
  assert_false(quads[1].subj_shell)
  // 外层体 quad：壳主语 + 宾 = bnode span
  assert_eq(quads[2].s, (0, 8))
  assert_eq(quads[2].p, (12, 2))
  assert_eq(quads[2].o, (15, 1))
  assert_true(quads[2].subj_shell)
}

///|
test "役9 静默收口：体内 `;` 直落 |} 直清壳账，后续语句无壳" {
  let data = @utf8.encode(":s :p :o {| :q :z ; |} . :a :b :c .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_true(quads[1].subj_shell)
  assert_eq(quads[2].s, (25, 2))
  assert_false(quads[2].subj_shell)
}

///|
test "役9 TT 独立主语回归：组装拆壳，subj_shell 恒假" {
  let data = @utf8.encode("<<:s :p :o>> .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].s, (2, 2))
  assert_eq(quads[0].p, (5, 2))
  assert_eq(quads[0].o, (8, 2))
  assert_false(quads[0].subj_shell)
}

///|
test "役9 ~ 驻留位 + 注解：reifier 标签不扰壳账" {
  let data = @utf8.encode(":s :p :o ~ :l {| :q :z |} .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  assert_false(quads[0].subj_shell)
  assert_eq(quads[1].s, (0, 8))
  assert_eq(quads[1].p, (17, 2))
  assert_eq(quads[1].o, (20, 2))
  assert_true(quads[1].subj_shell)
}

///|
test "役9 物化：TT 壳逐字节保真直出（三右尖括号 = 壳自有的 + 合成的 >>）" {
  let (emits, errors) = mat_chain(
    "@prefix : <http://e/> .\n:s :p :o {| :q :z |} .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  // 主 quad：锚 IRI 原样
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://e/s>")
  // 体 quad：主语 = <<锚三元组原文>>——壳 span 原文逐字节保真（prefname
  // 不展开，与宾位的词项展开成对照）；全 IRI 输入时壳内即全 IRI
  assert_eq(mat_vs(mat_subj(emits[1])), "<<:s :p :o>>")
  assert_eq(mat_vs(mat_obj(emits[1])), "<http://e/z>")
}

///|
test "役9 物化图块区：壳主语 + 图名随行" {
  let (emits, errors) = mat_chain(
    "@prefix : <http://e/> .\n:G { :s :p :o {| :q :z |} . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  assert_eq(mat_vs(mat_subj(emits[1])), "<<:s :p :o>>")
  assert_eq(mat_vs(mat_graph(emits[1])), "<http://e/G>")
}
