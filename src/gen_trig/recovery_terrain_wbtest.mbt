// ===== R-19 续役·阶段 0（2026-09-23）：trig 恢复道地形钉（勘地形产出）=====
// 背景：n3 侧 R-19（役 2/2b）已入模；trig 引擎恢复机械 = 图块感知（engine.mbt
// `TrigSupervisor::recover` + `consume_to_recover_point`）：
//   顶层 Dot ⇒ TrigExpectSubject + reset(All)；图内 Dot ⇒ GraphExpectSubject + reset(SPO)
//   （graph 槽保留）；图内 Rbrace ⇒ **停在不消费的前界**（pending 推回，下一轮走表闭合图块）；
//   EOF ⇒ 按出错位归位 + reset(SPO)。
// 与 n3 声明门 `[type_mapping.recovery_close]`（收窗恒回初始态、收窗事件必消费）对比：
//   trig 需要的是「**按出错位分派收窗态/清槽域** + **Rbrace 不消费停**」——现声明门
//   不可表达，落地前需机件扩展裁定（见 todo.md §AP.16）。
// 无判别力证明（与 nquads 钉同证）：随机门 valid 只产表内命令、普查单步、适配层 step 直驱
// ⇒ 三面对环级恢复道全盲。判据 = 本钉（分道在册为红面证据；入模笔同笔翻转）。

///|
fn trig_bytes(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
test "R19/trig 阶段0 真值钉：顶层 Object 位裸 `;` ⇒ Dot 收窗（错1 + 恰 (a,b,c)）" {
  let data = trig_bytes(":s :p ; <j> . :a :b :c .")
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 1)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].s, (14, 2))
  assert_eq(quads[0].p, (17, 2))
  assert_eq(quads[0].o, (20, 2))
  assert_true(quads[0].g is None)
}

///|
test "R19/trig 阶段0 真值钉：图内恢复 Dot 收窗 ⇒ reset(SPO) 且 graph 槽保留" {
  let data = trig_bytes(":g { :s :p ; <j> . :a :b :c . }")
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 1)
  assert_eq(quads.length(), 1)
  assert_eq(quads[0].s, (19, 2))
  assert_eq(quads[0].p, (22, 2))
  assert_eq(quads[0].o, (25, 2))
  assert_eq(quads[0].g, Some((0, 2)))
}

///|
test "R19/trig 阶段0 真值钉：图内恢复 Rbrace 不消费停 ⇒ 表闭图块（错1 + 零四元）" {
  let data = trig_bytes(":g { :s :p ; }")
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 1)
  assert_eq(quads.length(), 0)
}

///|
test "R19/trig 阶段0 真值钉：顶层恢复 EOF 收窗 ⇒ reset(SPO)（错1 + 零四元）" {
  let data = trig_bytes(":s :p ;")
  let (quads, errors) = trig_parser(data, lenient=true)
  assert_eq(errors.length(), 1)
  assert_eq(quads.length(), 0)
}
