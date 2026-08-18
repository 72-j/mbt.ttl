// ===== ID Mapping - State↔NodeIndex, Event↔Weight 双向映射 =====
// 规范第六节：映射层。
// moongraph 的 NodeIndex 按 add_node 插入序分配（0-based），
// 因此按 states 数组下标构造即可与图节点一一对齐。

///|
/// State → NodeIndex 双向映射
/// 节点索引按数组下标分配：states[i] ↔ NodeIndex::new(i)
pub fn map_state_to_id(
  states : Array[String],
) -> (Map[String, @moongraph.NodeIndex], Map[Int, String]) {
  let state_to_id = Map([])
  let id_to_state = Map([])
  for i = 0; i < states.length(); i = i + 1 {
    let node_id = @moongraph.NodeIndex::new(i)
    state_to_id.set(states[i], node_id)
    id_to_state.set(i, states[i])
  }
  (state_to_id, id_to_state)
}

///|
/// Event → 边权重 双向映射（权重 = 事件在数组中的下标，保证唯一）
pub fn map_event_to_weight(
  events : Array[String],
) -> (Map[String, Int], Map[Int, String]) {
  let event_to_weight = Map([])
  let weight_to_event = Map([])
  for i = 0; i < events.length(); i = i + 1 {
    event_to_weight.set(events[i], i)
    weight_to_event.set(i, events[i])
  }
  (event_to_weight, weight_to_event)
}

///|
test {
  // 状态映射：双向一致
  let states = ["idle", "running", "paused"]
  let (state_to_id, id_to_state) = map_state_to_id(states)
  assert_eq(state_to_id.get("idle").unwrap().value(), 0)
  assert_eq(state_to_id.get("paused").unwrap().value(), 2)
  assert_eq(id_to_state.get(1).unwrap(), "running")

  // 事件映射：双向一致
  let events = ["start", "stop"]
  let (event_to_weight, weight_to_event) = map_event_to_weight(events)
  assert_eq(event_to_weight.get("start").unwrap(), 0)
  assert_eq(weight_to_event.get(1).unwrap(), "stop")
}
