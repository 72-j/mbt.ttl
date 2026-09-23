// ===== R-19 续役·阶段 0（2026-09-23）：nquads 恢复道地形钉（勘地形产出）=====
// 背景：n3 侧 R-19（役 2/2b，2026-09-21）已把恢复道入模（`[type_mapping.recovery_close]`
// 声明门 + 恢复窗 + 探针同扩）；nquads/trig 两实例引擎的环级恢复仍在模型外（本钉 + trig 侧
// 同名钉 = 勘地形产出，裁定与落地见 todo.md §AP.16）。
//
// 地形（engine.mbt `NQuadsLoopPolicy::recover` + `consume_to_dot`）：表级
// `Err(UnexpectedEvent)` ⇒ 环级 record_error → 吞事件到 Dot（或 EOF 枯竭）→
// reset(All) → ExpectSubject。错误在**环级**才可观测；表级 `step` 两侧同响应。
//
// 无判别力证明：随机门的命令生成经 `valid()` 只产**表内**命令（UnexpectedEvent
// 永不被采样）；普查门单步、锚点走 `step` 直驱——三面对环级恢复道全盲。
// ⇒ 判据 = 本钉（判别力证明：分道在册为红面证据，入模笔同笔翻转绿面）。
//
// 反例形 1（Dot 收窗）：`<s> <p> ; <j> . <a> <b> <c> .`
//   `;` 在 ExpectObject 位无表行 ⇒ 环级恢复：错 1 条在案、`;` 后的 `<j>` 被吞、
//   带病槽位（s/p）随 reset 作废；终局 = 恰 (a,b,c) 一枚四元。
// 反例形 2（EOF 收窗）：`<s> <p> ;`（无句点）
//   吞到 EOF → reset(All) → finish_at_end 判净；终局 = 错 1 条 + 零四元。

///|
fn r19_bytes(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
fn r19_view_str(view : ArrayView[Byte]) -> String {
  let buf = StringBuilder()
  for i = 0; i < view.length(); i = i + 1 {
    buf.write_char(view[i].to_char())
  }
  buf.to_string()
}

///|
test "R19/nquads 阶段0 真值钉：Object 位裸 `;` ⇒ 环级恢复（错1 + 恰 (a,b,c)）" {
  let input = "<http://e/s> <http://e/p> ; <http://e/j> . <http://e/a> <http://e/b> <http://e/c> .\n"
  let (quads, errors) = nquads_parser(r19_bytes(input))
  assert_eq(errors.length(), 1)
  assert_eq(quads.length(), 1)
  let q = quads[0]
  assert_eq(r19_view_str(q.subj), "<http://e/a>")
  assert_eq(r19_view_str(q.pred), "<http://e/b>")
  assert_eq(r19_view_str(q.obj), "<http://e/c>")
  assert_true(q.graph is None)
}

///|
test "R19/nquads 阶段0 真值钉：Object 位裸 `;` 无句点 ⇒ EOF 收窗（错1 + 零四元）" {
  let input = "<http://e/s> <http://e/p> ;\n"
  let (quads, errors) = nquads_parser(r19_bytes(input))
  assert_eq(errors.length(), 1)
  assert_eq(quads.length(), 0)
}
