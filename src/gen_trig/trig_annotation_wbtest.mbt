// ===== U3b 注解钉（役9 钉子的三 span 直传律改写）=====
// 引擎 span 级（trig_parser lenient=true，跨前缀无关）；物化级（mat_chain，
// @prefix 必带——物化层要展开）。
// U3b 律：①体行主语 = 锚行主语 span（真词项，非合并锚文）；TT 三成分走
// 锚行三 span 直传 extras；②块透明不变量——收口回填锚行谓宾槽，句界/收口
// `.` 重发主行（重复 quad，物化集合语义塌缩）。

///|
test "U3b 顶层正典：主 quad 锚槽 + 体 quad 壳主语 span + 收口重发主行" {
  let data = @utf8.encode(":s :p :o {| :q :z |} .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  // 主行 + 体行 + 收口重发主行（块透明不变量）
  assert_eq(quads.length(), 3)
  // 主 quad：锚槽位原样，无壳
  assert_eq(quads[0].s, (0, 2))
  assert_eq(quads[0].p, (3, 2))
  assert_eq(quads[0].o, (6, 2))
  assert_false(quads[0].subj_shell)
  // 体 quad：主语 = 锚行主语 span ":s"（U3b 三 span 直传）
  assert_eq(quads[1].s, (0, 2))
  assert_eq(quads[1].p, (12, 2))
  assert_eq(quads[1].o, (15, 2))
  assert_true(quads[1].subj_shell)
  // 收口重发主行：槽位回填后 `.` 的重复行（物化层集合塌缩）
  assert_eq(quads[2].s, (0, 2))
  assert_eq(quads[2].p, (3, 2))
  assert_eq(quads[2].o, (6, 2))
  assert_false(quads[2].subj_shell)
}

///|
test "U3b 图块区：体 quad 壳主语 + 图名保持 + 收口重发" {
  let data = @utf8.encode(":g { :s :p :o {| :q :z |} . }\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 3)
  assert_eq(quads[0].g, Some((0, 2)))
  assert_false(quads[0].subj_shell)
  // 体 quad：主语 = 锚行主语 ":s"（(5,2)），图名随行保持
  assert_eq(quads[1].s, (5, 2))
  assert_eq(view_str(data[:], quads[1].s), ":s")
  assert_eq(quads[1].p, (17, 2))
  assert_eq(quads[1].o, (20, 2))
  assert_eq(quads[1].g, Some((0, 2)))
  assert_true(quads[1].subj_shell)
  // 收口重发主行
  assert_eq(quads[2].s, (5, 2))
  assert_false(quads[2].subj_shell)
}

///|
test "U3b 收尾续锚：|} ; 尾句照常发射（shell 落假）" {
  let data = @utf8.encode(":s :p :o {| :q :z |} ; :r :w .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  // 主行 + 体行 + 收口 `;` 重发主行 + 尾句
  assert_eq(quads.length(), 4)
  assert_true(quads[1].subj_shell)
  // 收口重发主行（槽位回填 → `;` 的 PredObj 发射）
  assert_eq(quads[2].s, (0, 2))
  assert_false(quads[2].subj_shell)
  // 尾句：shell false
  assert_eq(quads[3].s, (0, 2))
  assert_eq(quads[3].p, (23, 2))
  assert_eq(quads[3].o, (26, 2))
  assert_false(quads[3].subj_shell)
}

///|
test "U3b 嵌套 bnp：内层 fresh 主语错键不换 + 旗落假" {
  let data = @utf8.encode(":s :p :o {| :q [ :x :y ] |} .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 4)
  assert_false(quads[0].subj_shell)
  // 内层 quad：fresh 主语（`[` span），错键不换且旗被强制落假
  assert_eq(quads[1].s, (15, 1))
  assert_false(quads[1].subj_shell)
  // 外层体 quad：主语 = 锚行主语 + 宾 = bnode span
  assert_eq(quads[2].s, (0, 2))
  assert_eq(quads[2].p, (12, 2))
  assert_eq(quads[2].o, (15, 1))
  assert_true(quads[2].subj_shell)
  // 收口重发主行
  assert_eq(quads[3].s, (0, 2))
  assert_false(quads[3].subj_shell)
}

///|
test "U3b 静默收口：体内 `;` 直落 |} 直清壳账，后续语句无壳" {
  let data = @utf8.encode(":s :p :o {| :q :z ; |} . :a :b :c .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  // 主行 + 体行 + 收口 `.` 重发主行 + 后续语句
  assert_eq(quads.length(), 4)
  assert_true(quads[1].subj_shell)
  assert_eq(quads[2].s, (0, 2))
  assert_false(quads[2].subj_shell)
  assert_eq(quads[3].s, (25, 2))
  assert_false(quads[3].subj_shell)
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
test "U3b ~ 驻留位 + 注解：reifier 绑块 + 链随主行" {
  let data = @utf8.encode(":s :p :o ~ :l {| :q :z |} .\n").to_array()
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 0)
  // 主行（携 ~ 链）+ 体行 + 收口重发主行
  assert_eq(quads.length(), 3)
  assert_false(quads[0].subj_shell)
  // 体行：主语 = 锚行主语 span；显式 reifier 绑块
  assert_eq(quads[1].s, (0, 2))
  assert_eq(quads[1].p, (17, 2))
  assert_eq(quads[1].o, (20, 2))
  assert_true(quads[1].subj_shell)
  assert_eq(quads[1].bound_reifier, Some((11, 2)))
  // 收口重发主行
  assert_eq(quads[2].s, (0, 2))
  assert_false(quads[2].subj_shell)
}

///|
test "U3b 物化：TT 壳逐字节保真直出（三右尖括号 = 壳自有的 + 合成的 >>）" {
  let (emits, errors) = mat_chain(
    "@prefix : <http://e/> .\n:s :p :o {| :q :z |} .\n",
  )
  assert_eq(errors.length(), 0)
  // U3a/U3b 官方律：锚行 + 注解行(R 主语) + reifies 行 + 收口重发主行
  //（重复锚行，集合语义塌缩——emits 层保留，比对层折叠）
  assert_eq(emits.length(), 4)
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://e/s>")
  assert_true(mat_vs(mat_subj(emits[1])).has_prefix("_:"))
  assert_eq(mat_vs(mat_obj(emits[1])), "<http://e/z>")
  assert_eq(
    mat_vs(mat_obj(emits[2])),
    "<<( <http://e/s> <http://e/p> <http://e/o> )>>",
  )
  // 收口重发主行 = 锚行重复
  assert_eq(mat_vs(mat_subj(emits[3])), "<http://e/s>")
  assert_eq(mat_vs(emits[3].predicate), "<http://e/p>")
  assert_eq(mat_vs(mat_obj(emits[3])), "<http://e/o>")
}

///|
test "U3b 物化图块区：壳主语 + 图名随行" {
  let (emits, errors) = mat_chain(
    "@prefix : <http://e/> .\n:G { :s :p :o {| :q :z |} . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 4)
  assert_true(mat_vs(mat_subj(emits[1])).has_prefix("_:"))
  assert_eq(mat_vs(mat_graph(emits[1])), "<http://e/G>")
  assert_eq(mat_vs(mat_graph(emits[2])), "<http://e/G>")
  // 收口重发主行：图名随行
  assert_eq(mat_vs(mat_graph(emits[3])), "<http://e/G>")
}
