// ===== Reachability Analysis - 可达性分析 =====
// 规范第八节 + 算子映射表：可达性分析 → dijkstra()（O((V+E) log V)）
// 距离 < UNREACHABLE_DISTANCE (2147483647) 即为可达

///|
/// 可达性分析结果
pub(all) struct ReachabilityResult {
  reachable : Array[String] // 可达状态（按节点插入序）
  unreachable_states : Array[String] // 不可达状态（按节点插入序）
  distances : Map[String, Int] // 初始状态到各状态的距离（不可达 = UNREACHABLE_DISTANCE）
}

///|
/// 执行可达性分析：单源 dijkstra，一次遍历判定所有状态
pub fn analyze_reachability(ctx : GraphContext) -> ReachabilityResult {
  match ctx.state_to_id.get(ctx.initial_state) {
    Some(start_id) => {
      let distances = ctx.graph.dijkstra(start_id) // Array[Int]，按 NodeIndex.val 索引
      let reachable = []
      let unreachable_states = []
      let state_distances = Map([])

      // 按节点插入序遍历，保证结果确定性
      for i = 0; i < ctx.graph.node_count(); i = i + 1 {
        match ctx.id_to_state.get(i) {
          Some(state) => {
            let dist = distances[i]
            state_distances.set(state, dist)
            if dist < UNREACHABLE_DISTANCE {
              reachable.push(state)
            } else {
              unreachable_states.push(state)
            }
          }
          None => ()
        }
      }

      ReachabilityResult::{
        reachable,
        unreachable_states,
        distances: state_distances,
      }
    }
    None =>
      // 初始状态不在图中：所有状态都不可达（降级情形）
      ReachabilityResult::{
        reachable: [],
        unreachable_states: all_states(ctx),
        distances: Map([]),
      }
  }
}

///|
/// 辅助函数：按节点插入序获取所有状态
fn all_states(ctx : GraphContext) -> Array[String] {
  let states = []
  for i = 0; i < ctx.graph.node_count(); i = i + 1 {
    match ctx.id_to_state.get(i) {
      Some(state) => states.push(state)
      None => ()
    }
  }
  states
}

///|
test {
  // a -e1-> b -e2-> c，island 孤立：island 不可达
  let ctx = build_graph_context(
    ["a", "b", "c", "island"],
    ["e1", "e2"],
    make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "e2", "c", "Continue"),
    ]),
    "a",
    ["c"],
  ).unwrap()
  let result = analyze_reachability(ctx)
  assert_eq(result.reachable, ["a", "b", "c"])
  assert_eq(result.unreachable_states, ["island"])
  assert_eq(result.distances.get("a").unwrap(), 0)
  assert_eq(result.distances.get("c").unwrap(), 1) // 事件权重 0 + 1
  assert_eq(result.distances.get("island").unwrap(), UNREACHABLE_DISTANCE)
}
