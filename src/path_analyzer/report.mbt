// ===== Report - PathReport 组装 =====
// 规范第十四节：汇总各分析模块结果为标准报告

///|
/// 组装标准路径分析报告
///
/// # 参数
/// - reachability: 可达性结果（提供可达/不可达集合）
/// - dead: 死状态结果
/// - cycles: 循环检测结果
/// - generated_paths: 最终测试路径集合（状态序列）
/// - coverage: 最终覆盖率结果
/// - partial~: 是否部分报告（默认 false）
/// - degradation_reason~: 降级原因（部分报告时填写）
pub fn build_report(
  ctx : GraphContext,
  reachability : ReachabilityResult,
  dead : DeadStateResult,
  cycles : CycleResult,
  generated_paths : Array[Array[String]],
  coverage : CoverageResult,
  partial? : Bool = false,
  degradation_reason? : String? = None,
) -> PathReport {
  // 不可达状态按节点插入序（reachability 已保证），死状态/循环直接透传
  let _ = ctx // 字段已由各结果携带，ctx 保留给未来扩展
  PathReport::{
    reachable_states: reachability.reachable,
    unreachable_states: reachability.unreachable_states,
    dead_states: dead.dead_states,
    cycles: cycles.cycles,
    uncovered_transitions: coverage.uncovered_transitions,
    generated_paths,
    coverage_ratio: coverage.coverage_ratio,
    partial,
    degradation_reason,
  }
}

///|
/// 报告摘要（供 CLI verbose 输出/日志）
pub fn report_summary(report : PathReport) -> String {
  let buf = StringBuilder::new()
  buf.write(
    "状态: \{report.reachable_states.length()} 可达 / \{report.unreachable_states.length()} 不可达 / \{report.dead_states.length()} 死状态\n",
  )
  buf.write("循环: \{report.cycles.length()} 个\n")
  buf.write("测试路径: \{report.generated_paths.length()} 条\n")
  buf.write(
    "覆盖率: \{report.coverage_ratio * 100.0}%（未覆盖转移 \{report.uncovered_transitions.length()} 条）",
  )
  if report.partial {
    buf.write("\n[部分报告] ")
    buf.write(report.degradation_reason.unwrap_or("存在算法降级"))
  }
  buf.to_string()
}

///|
test {
  let ctx = build_graph_context(
    ["a", "b", "island"],
    ["e1"],
    make_transitions([("a", "e1", "b", "Continue")]),
    "a",
    ["b"],
  ).unwrap()
  let reach = analyze_reachability(ctx)
  let dead = detect_dead_states(ctx, reach)
  let cycles = detect_cycles(ctx)
  let paths = [["a", "b"]]
  let coverage = calculate_coverage(ctx, paths)

  let report = build_report(ctx, reach, dead, cycles, paths, coverage)
  assert_eq(report.reachable_states, ["a", "b"])
  assert_eq(report.unreachable_states, ["island"])
  assert_eq(report.dead_states, [])
  assert_eq(report.coverage_ratio, 1.0)
  assert_false(report.partial)
  assert_true(report.degradation_reason is None)

  let summary = report_summary(report)
  assert_true(summary.contains("覆盖率"))
  assert_true(summary.contains("1 不可达"))
}
