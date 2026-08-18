// ===== Graph Builder - 转移表 → moongraph 有向图 =====
// 规范第七节：图构建器。
// 节点按 states 顺序 add_node（权重 = 状态名），边权重 = 事件权重（事件下标）。

///|
/// 构建错误类型
pub(all) enum BuildError {
  UndefinedState(String) // 转移引用了未声明的状态
  UndefinedEvent(String) // 转移引用了未声明的事件
  DuplicateEdge(String, String) // 同一 (from, on) 重复定义
  UnknownInitialState(String) // 初始状态未在 states 中声明
} derive(Debug, Eq)

///|
/// 从转移表构建 GraphContext
///
/// # 校验
/// 1. initial 必须在 states 中声明
/// 2. 转移的 from / target 必须是已声明状态
/// 3. 转移的 on 必须是已声明事件
/// 4. (from, on) 必须唯一（与 Validator V6 一致）
pub fn build_graph_context(
  states : Array[String],
  events : Array[String],
  transitions : Array[TransitionTarget],
  initial : String,
  terminals : Array[String],
) -> Result[GraphContext, BuildError] {
  // 0. 初始/终止状态必须已声明
  if !states.contains(initial) {
    return Err(UnknownInitialState(initial))
  }
  for t in terminals {
    if !states.contains(t) {
      return Err(UndefinedState(t))
    }
  }

  // 1. 创建空有向图
  let graph : @moongraph.Graph[String, Int] = @moongraph.Graph::new(
    directed=true,
  )

  // 2. 建立双向映射
  let (state_to_id, id_to_state) = map_state_to_id(states)
  let (event_to_weight, weight_to_event) = map_event_to_weight(events)

  // 3. 添加节点（插入序即 NodeIndex，与映射层约定一致）
  for state in states {
    ignore(graph.add_node(state))
  }

  // 4. 添加边（带校验 + 去重检查）
  let seen_pairs : Array[(String, String)] = []
  for t in transitions {
    if !state_to_id.contains(t.state) {
      return Err(UndefinedState(t.state))
    }
    if !state_to_id.contains(t.target) {
      return Err(UndefinedState(t.target))
    }
    if !event_to_weight.contains(t.event) {
      return Err(UndefinedEvent(t.event))
    }
    if seen_pairs.contains((t.state, t.event)) {
      return Err(DuplicateEdge(t.state, t.event))
    }
    seen_pairs.push((t.state, t.event))

    let from_id = state_to_id.get(t.state).unwrap()
    let to_id = state_to_id.get(t.target).unwrap()
    let weight = event_to_weight.get(t.event).unwrap()
    let edge = graph.add_edge(from_id, to_id, weight)
    // add_edge 对非法端点返回 val < 0 的 EdgeIndex
    if edge.value() < 0 {
      return Err(UndefinedState(t.target))
    }
  }

  Ok(GraphContext::{
    graph,
    state_to_id,
    id_to_state,
    event_to_weight,
    weight_to_event,
    transitions,
    initial_state: initial,
    terminal_states: terminals,
  })
}

///|
/// 便捷构造：从 (from, on, to, effect_name) 四元组构建转移表
pub fn make_transitions(
  rows : Array[(String, String, String, String)],
) -> Array[TransitionTarget] {
  rows.map(fn(row) {
    let (from, on, to, effect_name) = row
    TransitionTarget::{
      state: from,
      event: on,
      target: to,
      effect: Effect::classify(effect_name),
    }
  })
}

///|
test {
  // 线性链：a -e1-> b -e2-> c
  let states = ["a", "b", "c"]
  let events = ["e1", "e2"]
  let transitions = make_transitions([
    ("a", "e1", "b", "Continue"),
    ("b", "e2", "c", "Continue"),
  ])
  let ctx = build_graph_context(states, events, transitions, "a", ["c"]).unwrap()
  assert_eq(ctx.graph.node_count(), 3)
  assert_eq(ctx.graph.edge_count(), 2)
  assert_true(ctx.is_terminal("c"))
  assert_false(ctx.is_terminal("a"))
}

///|
test {
  // 未声明状态 / 事件 / 重复边 / 未知初始状态
  let states = ["a", "b"]
  let events = ["e1"]
  let bad_target = make_transitions([("a", "e1", "ghost", "Continue")])
  assert_true(
    build_graph_context(states, events, bad_target, "a", [])
    is Err(UndefinedState(_)),
  )

  let bad_event = make_transitions([("a", "nope", "b", "Continue")])
  assert_true(
    build_graph_context(states, events, bad_event, "a", [])
    is Err(UndefinedEvent(_)),
  )

  let dup = make_transitions([
    ("a", "e1", "b", "Continue"),
    ("a", "e1", "b", "Continue"),
  ])
  assert_true(
    build_graph_context(states, events, dup, "a", [])
    is Err(DuplicateEdge(_, _)),
  )

  assert_true(
    build_graph_context(states, events, [], "start", [])
    is Err(UnknownInitialState(_)),
  )
}
