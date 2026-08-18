// ===== Analyzer - 顶层入口 =====
// 规范第十六节：串联所有分析步骤，供 FSM 生成器在代码生成阶段调用。
// 流水线位置（生成器侧）：
//   [1 解析] TOML → 转移表
//   [2 分析] analyze() → 本模块          ←—— 这里
//   [3 生成] PathReport + 转移表 → 引擎代码 & 测试代码
//   [4 渲染] dot 输出 → 状态图可视化
//
// 调用形态（对齐生成器侧约定）：
//   let result = @path_analyzer.analyze(
//     states=..., events=..., transitions=...,
//     initial_state=..., terminal_states=...,
//   )

///|
/// 分析器配置
pub(all) struct AnalyzerConfig {
  cycle_rounds : Array[Int] // 循环加压路径的圈数列表，默认 [2, 3]
} derive(Debug)

///|
/// 默认配置：环行走 2 圈与 3 圈
pub fn default_analyzer_config() -> AnalyzerConfig {
  AnalyzerConfig::{ cycle_rounds: [2, 3] }
}

///|
/// 图结构附加事实（DAG 专属算法仅无环时有值）
pub(all) struct GraphFacts {
  node_count : Int
  edge_count : Int
  weakly_connected : Bool // is_weakly_connected()：弱连通性快速检查
  is_dag : Bool // topological_sort() 成功即无环
  topological_order : Array[String]? // 有环时为 None
  longest_path_distances : Map[String, Int]? // dag_longest_paths()，有环时为 None
} derive(Debug)

///|
/// 分析结果：标准报告 + 图事实 + 带标注 DOT
pub(all) struct AnalyzeResult {
  report : PathReport
  facts : GraphFacts
  dot : String
} derive(Debug)

///|
/// 顶层入口（默认配置）：构建图并执行全部分析
pub fn analyze(
  states~ : Array[String],
  events~ : Array[String],
  transitions~ : Array[TransitionTarget],
  initial_state~ : String,
  terminal_states~ : Array[String],
) -> Result[AnalyzeResult, BuildError] {
  analyze_with_config(
    states~,
    events~,
    transitions~,
    initial_state~,
    terminal_states~,
    config=default_analyzer_config(),
  )
}

///|
/// 顶层入口（自定义配置）
pub fn analyze_with_config(
  states~ : Array[String],
  events~ : Array[String],
  transitions~ : Array[TransitionTarget],
  initial_state~ : String,
  terminal_states~ : Array[String],
  config~ : AnalyzerConfig,
) -> Result[AnalyzeResult, BuildError] {
  // 1. 图构建（含转移表校验）
  let ctx = match
    build_graph_context(
      states, events, transitions, initial_state, terminal_states,
    ) {
    Ok(ctx) => ctx
    Err(e) => return Err(e)
  }

  // 2. 四大图分析（全部经 moongraph 算子）
  let reachability = analyze_reachability(ctx)
  let dead = detect_dead_states(ctx, reachability)
  let cycles = detect_cycles(ctx)
  let shortest = generate_shortest_paths(ctx, reachability)
  let generator = make_path_generator(ctx, reachability, dead, cycles, shortest)

  // 3. 基础路径（类别 1-4）
  let base_paths = []
  for path in generator.shortest_reachable_paths() {
    base_paths.push(path)
  }
  for path in generator.complete_paths() {
    base_paths.push(path)
  }
  for path in generator.error_paths() {
    base_paths.push(path)
  }
  for path in generator.cycle_pressure_paths(rounds=config.cycle_rounds) {
    base_paths.push(path)
  }

  // 4. 首轮覆盖 → 未覆盖补充路径（类别 5）→ 终轮覆盖
  let first_pass = calculate_coverage(ctx, base_paths)
  let supplement = generator.uncovered_paths(first_pass.uncovered_transitions)
  let final_paths = base_paths.copy()
  for path in supplement {
    final_paths.push(path)
  }
  let final_coverage = calculate_coverage(ctx, final_paths)

  // 5. 降级判定：SCC 无法重建环行走时标记部分报告
  let mut ring_failures = 0
  for cycle in cycles.cycles {
    if generator.reconstruct_ring(cycle) is None {
      ring_failures = ring_failures + 1
    }
  }
  let (partial, degradation_reason) : (Bool, String?) = if ring_failures > 0 {
    (
      true,
      Some(
        "\{ring_failures} 个循环无法重建行走路径，循环加压路径缺失",
      ),
    )
  } else {
    (false, None)
  }

  // 6. 图事实 + 报告 + 渲染
  let facts = collect_graph_facts(ctx)
  let report = build_report(
    ctx,
    reachability,
    dead,
    cycles,
    final_paths,
    final_coverage,
    partial~,
    degradation_reason~,
  )
  let dot = to_annotated_dot(ctx, report)
  Ok(AnalyzeResult::{ report, facts, dot })
}

///|
/// 收集图结构事实：连通性走 is_weakly_connected()，
/// DAG 有序性走 topological_sort()，最长路径走 dag_longest_paths()
fn collect_graph_facts(ctx : GraphContext) -> GraphFacts {
  let topological_order = match ctx.graph.topological_sort() {
    Some(order) => {
      let names = []
      for nid in order {
        names.push(ctx.id_to_state.get(nid.value()).unwrap_or("?"))
      }
      Some(names)
    }
    None => None
  }

  // dag_longest_paths 仅对 DAG 有意义；从初始状态出发
  let longest_path_distances = match ctx.state_to_id.get(ctx.initial_state) {
    Some(start_id) =>
      match ctx.graph.dag_longest_paths(start_id) {
        Some(distances) => {
          let dist_map = Map([])
          for i = 0; i < ctx.graph.node_count(); i = i + 1 {
            match ctx.id_to_state.get(i) {
              Some(state) => dist_map.set(state, distances[i])
              None => ()
            }
          }
          Some(dist_map)
        }
        None => None
      }
    None => None
  }

  GraphFacts::{
    node_count: ctx.graph.node_count(),
    edge_count: ctx.graph.edge_count(),
    weakly_connected: ctx.graph.is_weakly_connected(),
    is_dag: topological_order is Some(_),
    topological_order,
    longest_path_distances,
  }
}

///|
test {
  // 端到端：线性链 a→b→c，全量分析
  let result = analyze(
    states=["a", "b", "c"],
    events=["e1", "e2"],
    transitions=make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "e2", "c", "Continue"),
    ]),
    initial_state="a",
    terminal_states=["c"],
  ).unwrap()

  let report = result.report
  assert_eq(report.reachable_states, ["a", "b", "c"])
  assert_eq(report.unreachable_states, [])
  assert_eq(report.dead_states, [])
  assert_eq(report.coverage_ratio, 1.0)
  assert_eq(report.uncovered_transitions, [])
  assert_false(report.partial)

  // 图事实：无环 DAG，拓扑有序
  let facts = result.facts
  assert_true(facts.weakly_connected)
  assert_true(facts.is_dag)
  assert_eq(facts.topological_order.unwrap(), ["a", "b", "c"])
  assert_true(facts.longest_path_distances is Some(_))

  // DOT 渲染
  assert_true(result.dot.contains("digraph fsm"))
  assert_true(result.dot.contains("[label=\"e1\"]"))
}

///|
test {
  // 端到端：不可达 + 死状态 + 循环 + Error + 未覆盖，二阶段路径补全
  let result = analyze(
    states=["a", "b", "c", "loop1", "loop2", "sink", "island"],
    events=["e1", "e2", "fail", "back", "fwd", "orphan"],
    transitions=make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "e2", "c", "Continue"),
      ("b", "fail", "sink", "Error"), // 错误路径（sink 无出边 → 死状态）
      ("a", "fwd", "loop1", "Continue"), // 三点环: a→loop1→loop2→a
      ("loop1", "back", "loop2", "Continue"),
      ("loop2", "back", "a", "Continue"),
      ("c", "orphan", "sink", "Continue"), // 需补充路径覆盖的转移
    ]),
    initial_state="a",
    terminal_states=["c"],
  ).unwrap()

  let report = result.report
  assert_eq(report.unreachable_states, ["island"])
  assert_eq(report.dead_states, ["sink"])
  assert_true(report.cycles.length() == 1)
  assert_eq(report.coverage_ratio, 1.0) // 二阶段补全后全覆盖
  assert_eq(report.uncovered_transitions, [])
  // 路径集合含：最短可达 ×5 + 完整 ×1 + 错误 ×1 + 加压 ×2 + 补充 ×1
  assert_true(report.generated_paths.length() >= 8)

  let facts = result.facts
  assert_false(facts.is_dag) // 有环
  assert_true(facts.topological_order is None)
  assert_true(facts.longest_path_distances is None)
  assert_false(facts.weakly_connected) // island 孤立

  // DOT：死状态红、不可达灰、Error 边红
  assert_true(result.dot.contains("\"sink\" [color=red"))
  assert_true(result.dot.contains("\"island\" [color=gray"))
  assert_true(result.dot.contains("[label=\"fail\", color=red"))
}

///|
test {
  // BuildError 直通 + 自定义加压圈数
  let bad = analyze(
    states=["a"],
    events=["e1"],
    transitions=make_transitions([("a", "e1", "ghost", "Continue")]),
    initial_state="a",
    terminal_states=[],
  )
  assert_true(bad is Err(UndefinedState(_)))

  let ctx = build_graph_context(
    ["a", "b"],
    ["e1", "e2"],
    make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "e2", "a", "Continue"),
    ]),
    "a",
    [],
  ).unwrap()
  let reach = analyze_reachability(ctx)
  let gen = make_path_generator(
    ctx,
    reach,
    detect_dead_states(ctx, reach),
    detect_cycles(ctx),
    generate_shortest_paths(ctx, reach),
  )
  let custom = gen.cycle_pressure_paths(rounds=[4])
  assert_eq(custom.length(), 1)
  // 环体 [b]：a b a b a b a b a
  assert_eq(custom[0], ["a", "b", "a", "b", "a", "b", "a", "b", "a"])
}
