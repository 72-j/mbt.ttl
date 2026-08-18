
  # FSM 路径分析器集成规范 (v1.0)

  ## 一、概述与目标

  本规范定义了将路径分析器（Path Analyzer）集成至 FSM 代码生成器阶段的标准流程。分析器旨在通过静态图分析，将状态机
  从"运行时黑盒"转化为"可审查、可覆盖、可回归"的结构化对象。

  ### 核心目标

   目标          说明
  ━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   结构洞察      识别不可达状态、死状态、循环结构
  ────────────  ────────────────────────────────────────────────
   覆盖率度量    计算转移表级别的覆盖率，输出未覆盖转移集合
  ────────────  ────────────────────────────────────────────────
   测试指导      生成五类测试路径，驱动 quickcheck_statemachine
  ────────────  ────────────────────────────────────────────────
   可视化反馈    输出带标注的 SVG 状态图，用于设计审查

  ———

  ## 二、架构边界与执行时机

  ┌─────────────────────────────────────┐
  │         代码生成阶段（编译期）          │
  ├─────────────────────────────────────┤
  │                                      │
  │  ┌─────────────────────────────────┐ │
  │  │       Path Analyzer             │ │
  │  │                                 │ │
  │  │  types.mbt    (核心类型)        │ │
  │  │  id_mapping.mbt (映射层)        │ │
  │  │  graph_builder.mbt (图构建)    │ │
  │  │  reachability.mbt (可达性)     │ │
  │  │  dead_state.mbt (死状态)       │ │
  │  │  cycle_detect.mbt (循环检测)   │ │
  │  │  shortest_path.mbt (最短路径)  │ │
  │  │  path_generator.mbt (路径生成) │ │
  │  │  coverage.mbt (覆盖率)         │ │
  │  │  report.mbt (报告组装)        │ │
  │  │  visualizer.mbt (可视化)       │ │
  │  │  analyzer.mbt (顶层入口)       │ │
  │  └─────────────────────────────────┘ │
  │                  │                    │
  │                  ▼                    │
  │  ┌─────────────────────────────────┐ │
  │  │    PathReport + SVG 可视化      │ │
  │  └─────────────────────────────────┘ │
  └─────────────────────────────────────┘


  ### 执行时机

  - **严格在代码生成阶段**（编译期/构建期）运行
  - **严禁引入运行时 I/O 依赖**

  ### 依赖边界

  | 层级 | 依赖库 | 说明 |
  |------|--------|------|
  | 图算法层 | `mbtgraph` | 纯函数语义，零副作用 |
  | 可视化层 | `graphviz.mbt` | 纯 MoonBit 布局渲染 |
  | 测试层 | `quickcheck_statemachine` | 仅消费分析结果 |

  ---

  ## 三、文件结构规范


  path_analyzer/
  ├── types.mbt              # 核心类型：GraphContext, PathReport, TransitionTarget
  ├── id_mapping.mbt         # State↔NodeId, Event↔Weight 双向映射
  ├── graph_builder.mbt      # 转移表 → mbtgraph DirectedGraph 适配
  ├── reachability.mbt       # 可达性分析（封装 shortest_path）
  ├── dead_state.mbt         # 死状态检测（封装 outgoing_edges）
  ├── cycle_detect.mbt       # 循环检测（封装 Tarjan_SCC）
  ├── shortest_path.mbt      # 最短路径生成（封装 shortest_path + path_to）
  ├── path_generator.mbt     # 五类路径生成策略
  ├── coverage.mbt           # 转移覆盖率计算
  ├── report.mbt             # PathReport 组装
  ├── visualizer.mbt         # graphviz.mbt 集成与标注规范实现
  └── analyzer.mbt           # 顶层入口：串联所有分析步骤


  ---

  ## 四、核心数据类型规范

  ### 4.1 GraphContext

  ```moonbit
  // ========================================
  // GraphContext - 图分析核心上下文
  // ========================================

  ///| 转移目标
  pub struct TransitionTarget {
    state: State
    event: Event
    effect: Effect
  }

  ///| 图分析上下文
  pub struct GraphContext {
    graph: @mbtgraph.DirectedGraph
    state_to_id: Map[State, @mbtgraph.NodeId]     // State → NodeId
    id_to_state: Map[@mbtgraph.NodeId, State]     // NodeId → State
    event_to_weight: Map[Event, Int]            // Event → 边权重
    weight_to_event: Map[Int, Event]            // 边权重 → Event
    transitions: Array[TransitionTarget]        // 原始转移表
    initial_state: State
    terminal_states: Set[State]
  }

  ### 4.2 PathReport

  // ========================================
  // PathReport - 标准分析报告
  // ========================================

  ///| 路径分析报告
  pub struct PathReport {
    /// 可达状态集合
    reachable_states: Set[State]
    /// 不可达状态集合
    unreachable_states: Set[State]
    /// 死状态集合（非终止 + 无出边）
    dead_states: Set[State]
    /// 循环列表（每个 SCC 为一个状态列表）
    cycles: List[List[State]]
    /// 未覆盖转移集合
    uncovered_transitions: Set[(State, Event)]
    /// 生成的测试路径集合
    generated_paths: List[List[Event]]
    /// 覆盖率（0.0 ~ 1.0）
    coverage_ratio: Double
    /// 是否为部分报告（某算法不可用时）
    partial: Bool
    /// 降级原因（部分报告时）
    degradation_reason: Option[String]
  }

  ### 4.3 不可达距离常量

  ///| 不可达判定阈值
  const UNREACHABLE_DISTANCE: Int = 2147483647  // i32::MAX

  ———

  ## 五、算法算子映射规范

  所有图算法必须通过 mbtgraph 调用，禁止自行实现底层遍历逻辑。

  ### 5.1 算子映射表

   分析维度        mbtgraph API                   复杂度            说明
  ━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━
   可达性分析      shortest_path()                O((V+E) log V)    距离 < i32::MAX 即为可达
  ──────────────  ─────────────────────────────  ────────────────  ──────────────────────────
   死状态检测      outgoing_edges()               O(V+E)            非终止 + 无出边 = 死状态
  ──────────────  ─────────────────────────────  ────────────────  ──────────────────────────
   循环检测        Tarjan_SCC()                   O(V+E)            SCC.size > 1 或自环
  ──────────────  ─────────────────────────────  ────────────────  ──────────────────────────
   最短路径        shortest_path() + path_to()    O((V+E) log V)    单源一次，多目标查询
  ──────────────  ─────────────────────────────  ────────────────  ──────────────────────────
   连通性检查      is_weakly_connected()          O(V+E)            快速检查
  ──────────────  ─────────────────────────────  ────────────────  ──────────────────────────
   DAG 有序路径    topological_sort()             O(V+E)            仅对无环子图
  ──────────────  ─────────────────────────────  ────────────────  ──────────────────────────
   最长执行路径    dag_longest_paths()            O(V+E)            性能边界测试
  ──────────────  ─────────────────────────────  ────────────────  ──────────────────────────
   图导出          to_dot()                       O(V+E)            快速调试

  ———

  ## 六、ID 映射层 (id_mapping.mbt)

  ### 6.1 双向映射函数

  // ========================================
  // ID Mapping - State↔NodeId, Event↔Weight 双向映射
  // ========================================

  ///| State → NodeId 映射
  pub fn map_state_to_id(states: Array[State]) -> (Map[State, @mbtgraph.NodeId], Map[@mbtgraph.NodeId, State]) {
    let state_to_id = Map::new()
    let id_to_state = Map::new()

    for i = 0; i < states.length(); i = i + 1 {
      let node_id = @mbtgraph.NodeId::new(i)
      state_to_id.set(states[i], node_id)
      id_to_state.set(node_id, states[i])
    }

    (state_to_id, id_to_state)
  }

  ///| Event → Weight 映射
  pub fn map_event_to_weight(events: Array[Event]) -> (Map[Event, Int], Map[Int, Event]) {
    let event_to_weight = Map::new()
    let weight_to_event = Map::new()

    for i = 0; i < events.length(); i = i + 1 {
      event_to_weight.set(events[i], i)
      weight_to_event.set(i, events[i])
    }

    (event_to_weight, weight_to_event)
  }

  ———

  ## 七、图构建器 (graph_builder.mbt)

  ### 7.1 构建函数

  // ========================================
  // Graph Builder - 转移表 → mbtgraph 有向图
  // ========================================

  ///| 构建错误类型
  pub enum BuildError {
    DuplicateEdge(State, Event)
    InvalidTarget(State, Event, State)
    UndefinedState(State)
  }

  ///| 从转移表构建 GraphContext
  pub fn build_graph_context(
    states: Array[State],
    events: Array[Event],
    transitions: Array[TransitionDef],
    initial: State,
    terminals: Set[State],
  ) -> Result[GraphContext, BuildError] {
    // 1. 创建空图
    let graph = @mbtgraph.DirectedGraph::new()

    // 2. 建立映射
    let (state_to_id, id_to_state) = map_state_to_id(states)
    let (event_to_weight, weight_to_event) = map_event_to_weight(events)

    // 3. 添加节点
    for state in states {
      let node_id = state_to_id.get(state)
      graph.add_node(node_id)?
    }

    // 4. 添加边
    let transition_targets = []
    for t in transitions {
      let from_id = state_to_id.get(t.from_state)
      let weight = event_to_weight.get(t.on_event)
      let to_id = state_to_id.get(t.to_state)

      match (from_id, weight, to_id) {
        (Some(fid), Some(w), Some(tid)) => {
          graph.add_edge(fid, tid, w)?
          transition_targets.push(TransitionTarget::{
            state: t.from_state,
            event: t.on_event,
            effect: t.effect,
          })
        }
        _ => return Err(BuildError::InvalidTarget(
          t.from_state, t.on_event, t.to_state
        ))
      }
    }

    Ok(GraphContext::{
      graph,
      state_to_id,
      id_to_state,
      event_to_weight,
      weight_to_event,
      transitions: transition_targets,
      initial_state: initial,
      terminal_states: terminals,
    })
  }

  ———

  ## 八、可达性分析 (reachability.mbt)

  ### 8.1 算法实现

  // ========================================
  // Reachability Analysis - 可达性分析
  // ========================================

  ///| 可达性分析结果
  pub struct ReachabilityResult {
    reachable: Set[State]
    unreachable: Set[State]
    distances: Map[State, Int]
  }

  ///| 执行可达性分析
  pub fn analyze_reachability(ctx: GraphContext) -> ReachabilityResult {
    let initial_id = ctx.state_to_id.get(ctx.initial_state)

    match initial_id {
      Some(start_id) => {
        // 使用 shortest_path 获取距离
        let distances = ctx.graph.shortest_path(start_id)

        let mut reachable = Set::new()
        let mut unreachable = Set::new()
        let mut state_distances = Map::new()

        // 遍历所有状态
        for (node_id, state) in ctx.id_to_state {
          let dist = distances.get(node_id)
          state_distances.set(state, dist)

          if dist < UNREACHABLE_DISTANCE {
            reachable.add(state)
          } else {
            unreachable.add(state)
          }
        }

        ReachabilityResult::{
          reachable,
          unreachable,
          distances: state_distances,
        }
      }
      None => {
        // 初始状态不存在，所有状态都不可达
        let unreachable = states_from_context(ctx)
        ReachabilityResult::{
          reachable: Set::new(),
          unreachable,
          distances: Map::new(),
        }
      }
    }
  }

  ///| 辅助函数：获取所有状态
  fn states_from_context(ctx: GraphContext) -> Set[State] {
    let states = []
    for state in ctx.id_to_state.values() {
      states.push(state)
    }
    states.to_set()
  }

  ———

  ## 九、死状态检测 (dead_state.mbt)

  ### 9.1 算法实现

  // ========================================
  // Dead State Detection - 死状态检测
  // ========================================

  ///| 死状态检测结果
  pub struct DeadStateResult {
    dead_states: Set[State]
    live_states: Set[State]
  }

  ///| 检测死状态
  /// 死状态定义：可达状态 + 非终止状态 + 无出边
  pub fn detect_dead_states(
    ctx: GraphContext,
    reachability: ReachabilityResult,
  ) -> DeadStateResult {
    let mut dead_states = Set::new()
    let mut live_states = Set::new()

    for state in reachability.reachable {
      let node_id = ctx.state_to_id.get(state)

      match node_id {
        Some(nid) => {
          let outgoing = ctx.graph.outgoing_edges(nid)

          // 死状态判定：可达 + 非终止 + 无出边
          let is_terminal = ctx.terminal_states.contains(state)
          let has_outgoing = not(outgoing.is_empty())

          if not(is_terminal) && not(has_outgoing) {
            dead_states.add(state)
          } else {
            live_states.add(state)
          }
        }
        None => ()
      }
    }

    DeadStateResult::{ dead_states, live_states }
  }

  ———

  ## 十、循环检测 (cycle_detect.mbt)

  ### 10.1 算法实现

  // ========================================
  // Cycle Detection - 循环检测（Tarjan SCC）
  // ========================================

  ///| 循环检测结果
  pub struct CycleResult {
    cycles: List[List[State]]
    has_cycles: Bool
  }

  ///| 检测循环
  /// 循环判定：SCC 节点数 > 1 或存在自环
  pub fn detect_cycles(ctx: GraphContext) -> CycleResult {
    let sccs = ctx.graph.Tarjan_SCC()

    let mut cycles = []
    let mut has_cycles = false

    for scc in sccs {
      // SCC 节点数 > 1 或包含自环
      let contains_self_loop = scc.some(fn(node_id) {
        let outgoing = ctx.graph.outgoing_edges(node_id)
        outgoing.any(fn(edge) { edge.target == node_id })
      })

      if scc.length() > 1 || contains_self_loop {
        has_cycles = true

        // 转换为状态列表
        let cycle_states = scc.map(fn(node_id) {
          ctx.id_to_state.get(node_id).unwrap()
        })
        cycles.push(cycle_states)
      }
    }

    CycleResult::{ cycles, has_cycles }
  }

  ———

  ## 十一、最短路径生成 (shortest_path.mbt)

  ### 11.1 算法实现

  // ========================================
  // Shortest Path - 最短路径生成
  // ========================================

  ///| 最短路径结果
  pub struct ShortestPathResult {
    paths: Map[State, List[Event]]
    distances: Map[State, Int]
  }

  ///| 生成到每个状态的最短路径
  pub fn generate_shortest_paths(
    ctx: GraphContext,
    reachability: ReachabilityResult,
  ) -> ShortestPathResult {
    let initial_id = ctx.state_to_id.get(ctx.initial_state)

    match initial_id {
      Some(start_id) => {
        let all_distances = ctx.graph.shortest_path(start_id)
        let mut paths = Map::new()
        let mut distances = Map::new()

        for (state, initial_id) in ctx.state_to_id {
          let dist = all_distances.get(state)
          distances.set(state, dist)

          if dist < UNREACHABLE_DISTANCE {
            let path = path_to(state, start_id, all_distances, ctx)
            paths.set(state, path)
          }
        }

        ShortestPathResult::{ paths, distances }
      }
      None => ShortestPathResult::{ paths: Map::new(), distances: Map::new() }
    }
  }

  ///| 回溯路径
  fn path_to(
    target: @mbtgraph.NodeId,
    start: @mbtgraph.NodeId,
    distances: Map[@mbtgraph.NodeId, Int],
    ctx: GraphContext,
  ) -> List[Event] {
    // 使用 path_to() 回溯路径
    let node_path = ctx.graph.path_to(target)
    let mut events = []

    for i = 0; i < node_path.length() - 1; i = i + 1 {
      let from = node_path[i]
      let to = node_path[i + 1]

      // 获取边权重作为事件
      let weight = ctx.graph.edge_weight(from, to)
      match weight {
        Some(w) => {
          let event = ctx.weight_to_event.get(w)
          match event {
            Some(e) => events.push(e)
            None => ()
          }
        }
        None => ()
      }
    }

    events
  }

  ———

  ## 十二、路径生成策略 (path_generator.mbt)

  ### 12.1 五类路径生成

  // ========================================
  // Path Generator - 五类路径生成策略
  // ========================================

  ///| 路径生成器
  pub struct PathGenerator {
    ctx: GraphContext
    reachability: ReachabilityResult
    dead_states: DeadStateResult
    cycles: CycleResult
    shortest_paths: ShortestPathResult
  }

  ///| 生成所有测试路径
  pub fn PathGenerator::generate_all(self: PathGenerator) -> List[List[Event]] {
    let mut all_paths = []

    // 1. 最短可达路径
    all_paths.append(self.shortest_reachable_paths())

    // 2. 完整成功路径
    all_paths.append(self.complete_paths())

    // 3. 错误路径
    all_paths.append(self.error_paths())

    // 4. 循环压力路径
    if self.cycles.has_cycles {
      all_paths.append(self.cycle_pressure_paths())
    }

    // 5. 未覆盖转移路径
    all_paths.append(self.uncovered_paths())

    all_paths
  }

  ///| 1. 最短可达路径
  pub fn PathGenerator::shortest_reachable_paths(self: PathGenerator) -> List[List[Event]] {
    let mut paths = []
    for (state, path) in self.shortest_paths.paths {
      if not(self.dead_states.dead_states.contains(state)) {
        paths.push(path)
      }
    }
    paths
  }

  ///| 2. 完整成功路径（到终止状态）
  pub fn PathGenerator::complete_paths(self: PathGenerator) -> List[List[Event]] {
    let mut paths = []

    for terminal in self.ctx.terminal_states {
      match self.shortest_paths.paths.get(terminal) {
        Some(path) => paths.push(path)
        None => ()
    paths
  }

  ///| 3. 错误路径
  pub fn PathGenerator::error_paths(self: PathGenerator) -> List[List[Event]] {
    // 查找所有 Error 转移
    let mut paths = []

    for target in self.ctx.transitions {
      if target.effect is Effect::Error(_) {
        match self.shortest_paths.paths.get(target.state) {
          Some(prefix) => paths.push(prefix)
          None => ()
        }
      }
    }

    paths
  }

  ///| 4. 循环压力路径
  pub fn PathGenerator::cycle_pressure_paths(self: PathGenerator) -> List[List[Event]] {
    let mut paths = []

    // 对每个循环，生成经过 2-3 次的路径
    for cycle in self.cycles.cycles {
      if cycle.length() > 1 {
        // 生成 2 倍循环
        let double_cycle = cycle + cycle
        paths.push(double_cycle)

        // 生成 3 倍循环
        let triple_cycle = cycle + cycle + cycle
        paths.push(triple_cycle)
      }
    }

    paths
  }

  ///| 5. 未覆盖转移路径
  pub fn PathGenerator::uncovered_paths(
    self: PathGenerator,
    uncovered: Set[(State, Event)],
  ) -> List[List[Event]] {
    let mut paths = []

    for (state, event) in uncovered {
      // 生成经过该转移的最短前缀
      match self.shortest_paths.paths.get(state) {
        Some(prefix) => {
          let mut full_path = prefix
          full_path.push(event)
          paths.push(full_path)
        }
        None => ()
      }
    }

    paths
  }

 ## 十三、覆盖率计算 (coverage.mbt)

  ### 13.1 算法实现

  // ========================================
  // Coverage - 转移覆盖率计算
  // ========================================

  ///| 覆盖率结果
  pub(all) struct CoverageResult {
    total_transitions : Int // 转移表总转移数
    covered_transitions : Int // 已覆盖转移数
    uncovered_transitions : Array[(String, String)] // 未覆盖 (state, event) 数组
    coverage_ratio : Double // 覆盖率 0.0 ~ 1.0
  } derive(Debug)

  ///| 计算转移覆盖率
  ///
  /// 输入：
  ///   - ctx: 图分析上下文（含完整转移表）
  ///   - generated_paths: 生成的测试路径（状态序列数组）
  ///
  /// 输出：
  ///   - CoverageResult：覆盖率统计与未覆盖转移列表
  pub fn calculate_coverage(
    ctx : GraphContext,
    generated_paths : Array[Array[String]],
  ) -> CoverageResult {
    // 1. 追踪路径覆盖率
    let covered = trace_path_coverage(ctx, generated_paths)

    // 2. 计算未覆盖转移
    let (uncovered_transitions, covered_count) = diff_transitions(
      ctx.transitions,
      covered,
    )

    // 3. 计算覆盖率
    let total = ctx.transitions.length()
    let ratio = if total > 0 {
      covered_count.to_double() / total.to_double()
    } else {
      0.0
    }

    CoverageResult::{
      total_transitions : total,
      covered_transitions : covered_count,
      uncovered_transitions,
      coverage_ratio : ratio,
    }
  }

  ### 13.2 路径覆盖率追踪

  ///| 追踪路径覆盖率：收集所有路径覆盖的转移
  ///
  /// 对于每条路径 [s0, s1, ..., sn]，覆盖的转移为：
  ///   (s0, e01), (s1, e12), ..., (s{n-1}, e{n-1}n)
  /// 其中 e{ij} 是 si → sj 的转移事件
  fn trace_path_coverage(
    ctx : GraphContext,
    paths : Array[Array[String]],
  ) -> Set[(String, String)] {
    let mut covered = Set::new()

    for path in paths {
      if path.length() < 2 {
        continue // 单状态路径无转移
      }

      // 遍历相邻状态对
      for i = 0; i < path.length() - 1; i = i + 1 {
        let from = path[i]
        let to = path[i + 1]

        // 查找 from → to 的转移事件
        match find_transition(ctx, from, to) {
          Some(event) => covered.insert((from, event))
          None => () // 未找到对应转移（理论上不可能）
        }
      }
    }

    covered
  }

  ///| 查找源状态到目标状态的转移事件
  /// 若有多条转移，优先选择权重最小的事件（确定性）
  fn find_transition(
    ctx : GraphContext,
    from : String,
    to : String,
  ) -> String? {
    let mut best : String? = None
    let mut best_weight = UNREACHABLE_DISTANCE

    for t in ctx.transitions {
      if t.state == from && t.target == to {
        let weight = ctx.event_to_weight.get(t.event).unwrap_or(
          UNREACHABLE_DISTANCE,
        )
        if weight < best_weight {
          best_weight = weight
          best = Some(t.event)
        }
      }
    }

    best
  }

  ///| 计算未覆盖转移（总转移 - 已覆盖）
  fn diff_transitions(
    all : Array[TransitionTarget],
    covered : Set[(String, String)],
  ) -> (Array[(String, String)], Int) {
    let mut uncovered = []
    let mut count = 0

    for t in all {
      let pair = (t.state, t.event)
      if covered.contains(pair) {
        count = count + 1
      } else {
        uncovered.push(pair)
      }
    }

    (uncovered, count)
  }

  ### 13.3 覆盖率结果方法

  ///| 检查是否达到目标覆盖率
  pub fn CoverageResult::is_satisfied(
    self : CoverageResult,
    target : Double,
  ) -> Bool {
    self.coverage_ratio >= target
  }

  ///| 获取覆盖率百分比字符串（保留 2 位小数）
  pub fn CoverageResult::percentage_string(self : CoverageResult) -> String {
    let percent = self.coverage_ratio * 100.0
    let formatted = @strconv.format_float(percent, precision=2)
    "\{formatted}%"
  }

  ///| 获取覆盖统计摘要
  pub fn CoverageResult::summary(self : CoverageResult) -> String {
    let covered = self.covered_transitions
    let total = self.total_transitions
    let ratio = self.percentage_string()
    "\{covered}/\{total} (\{ratio})"
  }

  ### 13.4 单元测试

  ///|
  test {
    // 简单线性链：a→b→c，完整覆盖
    let ctx = build_graph_context(
      ["a", "b", "c"],
      ["e1", "e2"],
      make_transitions([
        ("a", "e1", "b", "Continue"),
        ("b", "e2", "c", "Continue"),
      ]),
      "a",
      ["c"],
    ).unwrap()

    let paths = [["a", "b", "c"]]
    let result = calculate_coverage(ctx, paths)

    assert_eq(result.total_transitions, 2)
    assert_eq(result.covered_transitions, 2)
    assert_eq(result.uncovered_transitions.length(), 0)
    assert_eq(result.coverage_ratio, 1.0)
    assert_true(result.is_satisfied(1.0))
  }

  ///|
  test {
    // 部分覆盖：只有 a→b，未覆盖 b→c
    let ctx = build_graph_context(
      ["a", "b", "c"],
      ["e1", "e2"],
      make_transitions([
        ("a", "e1", "b", "Continue"),
        ("b", "e2", "c", "Continue"),
      ]),
      "a",
      ["c"],
    ).unwrap()

    let paths = [["a", "b"]]
    let result = calculate_coverage(ctx, paths)

    assert_eq(result.total_transitions, 2)
    assert_eq(result.covered_transitions, 1)
    assert_eq(result.uncovered_transitions.length(), 1)
    assert_eq(result.uncovered_transitions[0], ("b", "e2"))
    assert_true(result.coverage_ratio > 0.49)
    assert_true(result.coverage_ratio < 0.51)
  }

  ///|
  test {
    // 多路径覆盖：分支图 a→b→d 与 a→c→d
    let ctx = build_graph_context(
      ["a", "b", "c", "d"],
      ["e1", "e2", "e3", "e4"],
      make_transitions([
        ("a", "e1", "b", "Continue"),
        ("a", "e2", "c", "Continue"),
        ("b", "e3", "d", "Continue"),
        ("c", "e4", "d", "Continue"),
      ]),
      "a",
      ["d"],
    ).unwrap()

    let paths = [
      ["a", "b", "d"],
      ["a", "c", "d"],
    ]
    let result = calculate_coverage(ctx, paths)

    assert_eq(result.total_transitions, 4)
    assert_eq(result.covered_transitions, 4)
    assert_eq(result.coverage_ratio, 1.0)
    assert_eq(result.summary(), "4/4 (100.00%)")
  }

  ### 13.5 算法复杂度

   操作                   时间复杂度      说明
  ━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   calculate_coverage     O(P × L + T)    P=路径数，L=平均路径长度，T=转移数
  ─────────────────────  ──────────────  ────────────────────────────────────
   trace_path_coverage    O(P × L)        遍历所有路径的相邻状态对
  ─────────────────────  ──────────────  ────────────────────────────────────
   find_transition        O(T)            线性扫描转移表寻找匹配
  ─────────────────────  ──────────────  ────────────────────────────────────
   diff_transitions       O(T)            遍历转移表计算差集

  ### 13.6 与 PathReport 集成

  calculate_coverage 的输出将填充 PathReport 的以下字段：

  PathReport {
    // ... 其他字段
    uncovered_transitions : Array[(String, String)] // 未覆盖 (state, event)
    generated_paths : Array[Array[String]] // 测试路径
    coverage_ratio : Double // 覆盖率
  }
