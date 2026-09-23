// ===== R-19 续役·阶段 1（2026-09-23）：nquads 模型侧分道钉（入模笔同笔翻转：红面 → 绿面）=====
// 阶段 0（勘地形）：模型表级兜底 `(_, _) => Error(0)` 原地不动 ⇒ 带病推进 + Dot 发带病四元
// ——分道在册为红面证据。本笔（规格件先行裁定，§AP.16）：`[type_mapping.recovery_close]`
// 声明（Dot/EOF ⇒ All）落盘，恢复窗机件入模（engine `NQuadsLoopPolicy::recover` +
// `consume_to_dot` 同源）⇒ 钉翻绿面：错误在案 + 窗内吞咽 + 收窗不发带病四元。
// 表级随机门/普查门对恢复道仍无判别力（valid 只产表内命令、普查单步）——本钉是
// 判别力证明的常设面：机件退场（声明撤下）即回红面。

///|
test "R19/nquads 阶段1 分道钉（绿面）：`;` ⇒ Error(0)+开窗；`<j>` 吞咽 Skip；Dot 收窗不发带病四元" {
  let model0 = model_empty()
  let r1 : Command = Iri(Concrete({ id: 1, }))
  let r2 : Command = Iri(Concrete({ id: 2, }))
  let r3 : Command = Iri(Concrete({ id: 3, }))
  // <s> <p> ; <j> .
  let (m1, resp_s) = model_execute(model0, r1)
  assert_eq(resp_s, Continue)
  let (m2, resp_p) = model_execute(m1, r2)
  assert_eq(resp_p, Continue)
  // 分道点：`;` 在 Object 位——错误在案（Error(0)）+ 开窗清账（recovering 置旗，
  // 表级状态/槽位原样滞留，收窗时随 All 清账）
  let (m3, resp_bad) = model_execute(m2, Semicolon)
  assert_eq(resp_bad, Error(0))
  assert_eq(m3, recovery_enter(m2))
  assert_true(m3.recovering)
  assert_eq(m3.state, ExpectObject)
  // 窗内吞咽：<j> 不进表（Skip），槽位滞留、旗位保持
  let (m4, resp_j) = model_execute(m3, r3)
  assert_eq(resp_j, Skip)
  assert_eq(m4.state, ExpectObject)
  assert_true(m4.subject is Some(_))
  // 终局收窗：Dot ⇒ 清四槽 + 归位 + 关旗 + Skip——不发带病四元（真驱动同口径：
  // 吞 <j> 归位后发恢复后的 (a,b,c)）
  let (m5, resp_dot) = model_execute(m4, Dot)
  assert_eq(m5, model_empty())
  assert_eq(resp_dot, Skip)
  // EOF 亦为收窗事件（同形第二臂）：开窗后 EOF 直接收窗
  let (m6, resp_bad2) = model_execute(m5, Semicolon)
  assert_eq(resp_bad2, Error(0))
  let (m7, resp_eof) = model_execute(m6, EOF)
  assert_eq(resp_eof, Skip)
  assert_eq(m7, model_empty())
  ignore(resp_s)
  ignore(resp_p)
}
