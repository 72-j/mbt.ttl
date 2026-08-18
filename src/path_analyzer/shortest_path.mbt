// ===== Shortest Path - 最短路径（Dijkstra 路由表）=====
// 规范第十一节 + 算子映射表：最短路径 → build_route_table() + route_to()
// 一次建表即可取任意目标的最短距离与前驱路径

///|
/// 最短路径结果
pub(all) struct ShortestPathResult {
  distances : Map[String, Int] // 初始 → 各可达状态的最短距离
  state_paths : Map[String, Array[String]] // 初始 → 各可达状态的状态序列
}

///|
/// 生成初始状态到所有可达状态的最短路径
pub fn generate_shortest_paths(
  ctx : GraphContext,
  reachability : ReachabilityResult,
) -> ShortestPathResult {
  let distances = Map([])
  let state_paths = Map([])

  match ctx.state_to_id.get(ctx.initial_state) {
    Some(start_id) => {
      // 一次建表：O(E log V)，之后 distance/route_to 均为 O(1)/O(V)
      let table = @moongraph.build_route_table(ctx.graph, start_id)

      for state in reachability.reachable {
        match ctx.state_to_id.get(state) {
          Some(goal_id) => {
            let dist = table.distance(goal_id)
            distances.set(state, dist)
            // route_to 返回源→目标的 NodeIndex 序列
            let node_path = table.route_to(goal_id)
            let state_path = node_path.map(fn(nid) {
              ctx.id_to_state.get(nid.value()).unwrap_or("?")
            })
            state_paths.set(state, state_path)
          }
          None => ()
        }
      }
    }
    None => ()
  }

  ShortestPathResult::{ distances, state_paths }
}

///|
/// 把状态路径还原为事件序列：对相邻状态对 (u, v)，
/// 在转移表中挑选 u→v 中事件权重最小的一条（确定性）
pub fn path_events(
  ctx : GraphContext,
  state_path : Array[String],
) -> Array[String] {
  let events = []
  for i = 0; i < state_path.length() - 1; i = i + 1 {
    let from = state_path[i]
    let to = state_path[i + 1]
    let mut best : String? = None
    let mut best_weight = UNREACHABLE_DISTANCE
    for t in ctx.transitions {
      if t.state == from && t.target == to {
        let weight = ctx.event_to_weight
          .get(t.event)
          .unwrap_or(UNREACHABLE_DISTANCE)
        if weight < best_weight {
          best_weight = weight
          best = Some(t.event)
        }
      }
    }
    match best {
      Some(event) => events.push(event)
      None => () // 相邻对无对应转移（理论不可能，防御）
    }
  }
  events
}

///|
test {
  // 菱形图：a→b→d 与 a→c→d 两条路，route_to 给出最短者
  let ctx = build_graph_context(
    ["a", "b", "c", "d"],
    ["e1", "e2", "e3", "e4"],
    make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "e2", "d", "Continue"),
      ("a", "e3", "c", "Continue"),
      ("c", "e4", "d", "Continue"),
    ]),
    "a",
    ["d"],
  ).unwrap()
  let reach = analyze_reachability(ctx)
  let sp = generate_shortest_paths(ctx, reach)

  assert_eq(sp.distances.get("a").unwrap(), 0)
  // 权重 = 事件下标：a-e1(0)→b-e2(1)→d = 1；a-e3(2)→c-e4(3)→d = 5
  assert_eq(sp.distances.get("d").unwrap(), 1)
  let d_path = sp.state_paths.get("d").unwrap()
  assert_eq(d_path, ["a", "b", "d"]) // 经 b 的路径权重更小

  // 事件序列与状态路径逐段对应
  let events = path_events(ctx, d_path)
  assert_eq(events.length(), 2)
}

///|
test {
  // 环 + 旁路：a↔b 循环上最短路不会绕环
  let ctx = build_graph_context(
    ["a", "b", "c"],
    ["e1", "e2", "e3"],
    make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "e2", "a", "Continue"),
      ("b", "e3", "c", "Continue"),
    ]),
    "a",
    ["c"],
  ).unwrap()
  let reach = analyze_reachability(ctx)
  let sp = generate_shortest_paths(ctx, reach)
  assert_eq(sp.distances.get("c").unwrap(), 2)
  assert_eq(sp.state_paths.get("c").unwrap(), ["a", "b", "c"])

  // path_events：自环路径 → 空事件序列
  assert_eq(path_events(ctx, ["a"]), [])
  assert_eq(path_events(ctx, ["a", "b", "c"]), ["e1", "e3"])
}
