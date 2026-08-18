// ===== Cycle Detection - 循环检测（Tarjan SCC）=====
// 规范第十节 + 算子映射表：循环检测 → tarjan_scc()（O(V+E)）
// 循环判定：SCC 节点数 > 1，或单节点 SCC 含自环

///|
/// 循环检测结果
pub(all) struct CycleResult {
  cycles : Array[Array[String]] // 每个循环为一个状态列表（SCC 内序）
  has_cycles : Bool
}

///|
/// 检测循环：Tarjan SCC，SCC.size > 1 或自环即为循环
pub fn detect_cycles(ctx : GraphContext) -> CycleResult {
  let sccs = ctx.graph.tarjan_scc()

  let cycles = []
  let mut has_cycles = false

  for scc in sccs {
    // 自环判定：SCC 内某节点的邻居包含自身
    let contains_self_loop = scc.any(fn(nid) {
      ctx.graph.neighbors(nid).any(fn(next) { next == nid })
    })

    if scc.length() > 1 || contains_self_loop {
      has_cycles = true
      // NodeIndex → 状态名
      let cycle_states = scc.map(fn(nid) {
        ctx.id_to_state.get(nid.value()).unwrap_or("?")
      })
      cycles.push(cycle_states)
    }
  }

  CycleResult::{ cycles, has_cycles }
}

///|
test {
  // a <==> b 构成循环；c 为链尾
  let ctx = build_graph_context(
    ["a", "b", "c"],
    ["e1", "e2", "e3"],
    make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "e2", "a", "Continue"),
      ("a", "e3", "c", "Continue"),
    ]),
    "a",
    ["c"],
  ).unwrap()
  let result = detect_cycles(ctx)
  assert_true(result.has_cycles)
  assert_eq(result.cycles.length(), 1)
  let cycle = result.cycles[0]
  assert_true(cycle.contains("a") && cycle.contains("b"))
  assert_false(cycle.contains("c"))
}

///|
test {
  // 线性链无循环；自环构成单节点循环
  let linear = build_graph_context(
    ["a", "b"],
    ["e1"],
    make_transitions([("a", "e1", "b", "Continue")]),
    "a",
    ["b"],
  ).unwrap()
  assert_false(detect_cycles(linear).has_cycles)

  let self_loop = build_graph_context(
    ["a"],
    ["loop"],
    make_transitions([("a", "loop", "a", "Continue")]),
    "a",
    [],
  ).unwrap()
  let result = detect_cycles(self_loop)
  assert_true(result.has_cycles)
  assert_eq(result.cycles[0], ["a"])
}
