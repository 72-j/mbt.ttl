// ===== Path Analyzer 核心类型 =====
// 规范 4.1/4.2：GraphContext / PathReport / TransitionTarget
// 适配说明：
// - 规范写 @mbtgraph，实现绑定本模块依赖 wedarp/moongraph（moon.pkg 别名 @moongraph）；
//   NodeId → @moongraph.NodeIndex，shortest_path() → build_route_table + route_to
// - Set[State] → Array[String]（保持插入序，测试可断言；contains 语义等价）
// - i32::MAX 不可达阈值与 moongraph dijkstra 的 2147483647 约定一致

///|
/// 不可达判定阈值：dijkstra 距离 == 该值即不可达（moongraph 约定）
const UNREACHABLE_DISTANCE : Int = 2147483647

///|
/// 转移副作用意图分类（用于错误路径识别等语义分析）
pub(all) enum Effect {
  Continue // 正常流转
  Error(String) // 错误恢复路径（SkipError / SkipLine 等）
  Emit(String) // 输出副作用（EmitQuad 等）
  Other(String) // 其他副作用
} derive(Debug, Eq)

///|
/// 按 FSM effect 名称做启发式分类：
/// "Continue" → Continue；含 Error/Skip → Error；含 Emit → Emit；其余 Other
pub fn Effect::classify(name : String) -> Effect {
  if name == "Continue" {
    Continue
  } else if name.contains("Error") || name.contains("Skip") {
    Error(name)
  } else if name.contains("Emit") {
    Emit(name)
  } else {
    Other(name)
  }
}

///|
/// 转移目标（规范 TransitionTarget，扩展 target 字段以支持覆盖率回放）
pub(all) struct TransitionTarget {
  state : String // 源状态
  event : String // 触发事件
  target : String // 目标状态
  effect : Effect // 副作用意图分类
} derive(Debug)

///|
/// 图分析上下文：moongraph 有向图 + 双向 ID 映射 + 原始转移表
pub(all) struct GraphContext {
  graph : @moongraph.Graph[String, Int] // 节点权重 = 状态名，边权重 = 事件权重
  state_to_id : Map[String, @moongraph.NodeIndex] // State → NodeIndex
  id_to_state : Map[Int, String] // NodeIndex.val → State
  event_to_weight : Map[String, Int] // Event → 边权重
  weight_to_event : Map[Int, String] // 边权重 → Event
  transitions : Array[TransitionTarget] // 原始转移表（(from, event) 唯一）
  initial_state : String
  terminal_states : Array[String] // 终止状态（有序集合语义）
}

///|
/// 状态是否为终止状态
pub fn GraphContext::is_terminal(self : GraphContext, state : String) -> Bool {
  self.terminal_states.contains(state)
}

///|
/// 路径分析报告（规范 4.2 PathReport）
pub(all) struct PathReport {
  reachable_states : Array[String] // 可达状态集合
  unreachable_states : Array[String] // 不可达状态集合
  dead_states : Array[String] // 死状态集合（非终止 + 无出边）
  cycles : Array[Array[String]] // 循环列表（每个 SCC 一个状态列表）
  uncovered_transitions : Array[(String, String)] // 未覆盖 (state, event) 集合
  generated_paths : Array[Array[String]] // 生成的测试路径（事件序列）
  coverage_ratio : Double // 覆盖率（0.0 ~ 1.0）
  partial : Bool // 是否为部分报告（某算法不可用时）
  degradation_reason : String? // 降级原因（部分报告时）
} derive(Debug)

///|
test {
  // Effect::classify 启发式分类
  assert_eq(Effect::classify("Continue"), Continue)
  assert_true(Effect::classify("SkipError") is Error(_))
  assert_true(Effect::classify("SkipLine") is Error(_))
  assert_true(Effect::classify("EmitQuad") is Emit(_))
  assert_true(Effect::classify("Goto") is Other(_))
}
