// ===== R-19 续役·阶段 0（2026-09-23）：trig 模型侧分道钉（勘地形产出）=====
// 引擎环级在 Object 位遇 `;` 开**图块感知恢复窗**（顶层 Dot → All / 图内 Dot → SPO 且
// graph 槽保留 / 图内 Rbrace → 不消费停交表闭合 / EOF → 按出错位归位），模型表级兜底
// `(_, _) => Error(0)` 原地不动 ⇒ 后续事件按带病状态照常进表：
//   分道点 = `;` 本身；终局分道 = Dot（真驱动吞 <j> 归位后发 (a,b,c)；模型发**带病四元**
//   (s,p,j) 且无错）。图内形态的分道同构（graph 槽分道另含 graph 槽去留）。
// 表级随机门/普查门对此无判别力（valid 只产表内命令过滤 + 普查单步）——判据 = 本钉
// （判别力证明：未入模 = 分道在册；入模笔同笔翻转，与 n3 r19_probe 同法）。

///|
test "R19/trig 阶段0 分道钉：模型表级无恢复窗 ⇒ Error(0) 原地 + 带病推进 + Dot 发 (s,p,j)" {
  let model0 = model_empty()
  let r1 : Command = Iri(Concrete({ id: 1, }))
  let r2 : Command = Iri(Concrete({ id: 2, }))
  let r3 : Command = Iri(Concrete({ id: 3, }))
  // :s :p ; <j> .
  let (m1, resp_s) = model_execute(model0, r1)
  let (m2, resp_p) = model_execute(m1, r2)
  // 分道点：`;` 在 Object 位——模型兜底 Error(0)，状态/槽位原样
  let (m3, resp_bad) = model_execute(m2, Semicolon)
  assert_eq(resp_bad, Error(0))
  assert_eq(m3.state, ExpectObject)
  assert_true(m3.subject is Some(_))
  assert_true(m3.predicate is Some(_))
  let (m4, resp_j) = model_execute(m3, r3)
  assert_eq(resp_j, Continue)
  // 终局分道：模型发带病四元 (s,p,j)——真驱动吞 <j> 归位后发 (a,b,c)
  let (m5, resp_dot) = model_execute(m4, Dot)
  assert_eq(m5.state, ExpectSubject)
  match resp_dot {
    EmitQuad(q) => {
      assert_eq(q.subject, Some({ id: 1, }))
      assert_eq(q.predicate, Some({ id: 2, }))
      assert_eq(q.object, Some({ id: 3, }))
      assert_true(q.graph is None)
    }
    _ => fail("expected EmitQuad")
  }
  ignore(resp_s)
  ignore(resp_p)
}
