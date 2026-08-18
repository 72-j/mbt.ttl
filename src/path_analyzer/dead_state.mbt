// ===== Dead State Detection - 死状态检测 =====
// 规范第九节 + 算子映射表：死状态检测 → out_degree()/neighbors()（outgoing_edges）
// 死状态定义：可达 + 非终止 + 无出边

///|
/// 死状态检测结果
pub(all) struct DeadStateResult {
  dead_states : Array[String] // 可达但非终止且无出边
  live_states : Array[String] // 其余可达状态
}

///|
/// 检测死状态：遍历可达状态，out_degree == 0 且非终止即为死状态
pub fn detect_dead_states(
  ctx : GraphContext,
  reachability : ReachabilityResult,
) -> DeadStateResult {
  let dead_states = []
  let live_states = []

  for state in reachability.reachable {
    match ctx.state_to_id.get(state) {
      Some(nid) => {
        // 死状态判定：可达 + 非终止 + 无出边
        let is_terminal = ctx.is_terminal(state)
        let has_outgoing = ctx.graph.out_degree(nid) > 0
        if !is_terminal && !has_outgoing {
          dead_states.push(state)
        } else {
          live_states.push(state)
        }
      }
      None => ()
    }
  }

  DeadStateResult::{ dead_states, live_states }
}

///|
test {
  // s1 -e3-> sink（sink 无出边且非终止）→ 死状态；s2 为终止状态 → 非死
  let ctx = build_graph_context(
    ["s0", "s1", "s2", "sink"],
    ["e1", "e2", "e3"],
    make_transitions([
      ("s0", "e1", "s1", "Continue"),
      ("s1", "e2", "s2", "Continue"),
      ("s1", "e3", "sink", "Continue"),
    ]),
    "s0",
    ["s2"],
  ).unwrap()
  let reach = analyze_reachability(ctx)
  let dead = detect_dead_states(ctx, reach)
  assert_eq(dead.dead_states, ["sink"])
  assert_true(dead.live_states.contains("s2")) // 终止状态无出边也不算死
  assert_true(dead.live_states.contains("s0"))
}
