// ===== Visualizer - 图可视化输出 =====
// 规范第十五节 + 算子映射表：图导出 → to_dot()（快速调试）+ weighted_edge_list()（带标注渲染）
// 标注规范：初始 = 绿色填充加粗；终止 = 双圈；死状态 = 红色；不可达 = 灰色虚线；
//           Error 转移 = 红色边。边标签为事件名。

///|
/// 无标注 DOT：直接走 to_dot() 算子（快速调试用）
pub fn to_plain_dot(ctx : GraphContext) -> String {
  ctx.graph.to_dot(fn(node) { node }, fn(weight) {
    ctx.weight_to_event.get(weight).unwrap_or("?")
  })
}

///|
/// 带语义标注的 DOT：状态分类着色 + 错误边高亮
/// 数据源为 weighted_edge_list() 算子导出的边表，节点按插入序输出
pub fn to_annotated_dot(ctx : GraphContext, report : PathReport) -> String {
  let buf = StringBuilder::new()
  buf.write(
    "digraph fsm {\n  rankdir=LR;\n  node [shape=circle, fontname=\"Helvetica\"];\n\n",
  )

  // ---- 节点（按插入序）----
  for i = 0; i < ctx.graph.node_count(); i = i + 1 {
    match ctx.id_to_state.get(i) {
      Some(state) => {
        let attrs : Array[String] = []
        if state == ctx.initial_state {
          attrs.push("style=filled")
          attrs.push("fillcolor=lightgreen")
          attrs.push("penwidth=2")
        }
        if ctx.is_terminal(state) {
          attrs.push("shape=doublecircle")
        }
        if report.dead_states.contains(state) {
          attrs.push("color=red")
          attrs.push("fontcolor=red")
        }
        if report.unreachable_states.contains(state) {
          attrs.push("color=gray")
          attrs.push("style=dashed")
          attrs.push("fontcolor=gray")
        }
        buf.write("  \"\{state}\" [\{attrs.join(", ")}];\n")
      }
      None => ()
    }
  }

  // ---- 边（weighted_edge_list 算子导出）----
  buf.write("\n")
  for pair in ctx.graph.weighted_edge_list() {
    let (from_id, to_id, weight) = pair
    let from = ctx.id_to_state.get(from_id.value()).unwrap_or("?")
    let to = ctx.id_to_state.get(to_id.value()).unwrap_or("?")
    let event = ctx.weight_to_event.get(weight).unwrap_or("?")
    // Error 转移红色标注
    let is_error_edge = ctx.transitions.any(fn(t) {
      t.state == from &&
      t.target == to &&
      t.event == event &&
      t.effect is Error(_)
    })
    if is_error_edge {
      buf.write(
        "  \"\{from}\" -> \"\{to}\" [label=\"\{event}\", color=red, fontcolor=red];\n",
      )
    } else {
      buf.write("  \"\{from}\" -> \"\{to}\" [label=\"\{event}\"];\n")
    }
  }

  // ---- 图例 ----
  buf.write(
    "\n  // 图例: 绿色=初始 双圈=终止 红=死状态 灰虚线=不可达 红边=Error 转移\n",
  )
  buf.write("}\n")
  buf.to_string()
}

///|
test {
  // 标注渲染：初始/终止/死状态/不可达/Error 边
  let ctx2 = build_graph_context(
    ["a", "b", "sink", "island"],
    ["e1", "fail"],
    make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "fail", "sink", "Error"),
    ]),
    "a",
    ["b"],
  ).unwrap()
  let reach = analyze_reachability(ctx2)
  let dead = detect_dead_states(ctx2, reach)
  let cycles = detect_cycles(ctx2)
  let paths = [["a", "b"], ["a", "b", "sink"]]
  let coverage = calculate_coverage(ctx2, paths)
  let report = build_report(ctx2, reach, dead, cycles, paths, coverage)

  let dot = to_annotated_dot(ctx2, report)
  assert_true(dot.contains("digraph fsm"))
  assert_true(dot.contains("\"a\" [style=filled, fillcolor=lightgreen")) // 初始
  assert_true(dot.contains("\"b\" [shape=doublecircle")) // 终止
  assert_true(dot.contains("\"sink\" [color=red")) // 死状态
  assert_true(dot.contains("\"island\" [color=gray")) // 不可达
  assert_true(dot.contains("[label=\"fail\", color=red")) // Error 边
  assert_false(dot.contains("[label=\"e1\", color=red"))

  // to_plain_dot 走 to_dot 算子
  let plain = to_plain_dot(ctx2)
  assert_true(plain.contains("digraph"))
  assert_true(plain.contains("e1"))
}
