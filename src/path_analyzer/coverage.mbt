// ===== Coverage - 转移覆盖率计算 =====
// 规范第十三节：基于生成的测试路径计算转移覆盖率
//   - total_transitions: 转移表总转移数
//   - covered_transitions: 已覆盖转移数  
//   - uncovered_transitions: 未覆盖 (state, event) 集合
//   - coverage_ratio: 覆盖率 0.0 ~ 1.0

///|
/// 覆盖率结果
pub(all) struct CoverageResult {
  total_transitions : Int // 转移表总转移数
  covered_transitions : Int // 已覆盖转移数
  uncovered_transitions : Array[(String, String)] // 未覆盖 (state, event) 数组
  coverage_ratio : Double // 覆盖率 0.0 ~ 1.0
} derive(Debug)

///|
/// 计算转移覆盖率
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
  // 1. 构建转移集合（用于快速查找）
  let transition_set = build_transition_set(ctx.transitions)

  // 2. 执行路径覆盖率追踪
  let covered = trace_path_coverage(ctx, generated_paths)

  // 3. 计算未覆盖转移
  let (uncovered_transitions, covered_count) = diff_transitions(
    ctx.transitions,
    covered,
  )

  // 4. 计算覆盖率
  let total = ctx.transitions.length()
  let ratio = if total > 0 {
    covered_count.to_double() / total.to_double()
  } else {
    0.0
  }

  CoverageResult::{
    total_transitions: total,
    covered_transitions: covered_count,
    uncovered_transitions,
    coverage_ratio: ratio,
  }
}

///|
/// 构建转移集合（用于 O(1) 查找）
fn build_transition_set(
  transitions : Array[TransitionTarget],
) -> Set[(String, String)] {
  let set = Set([])
  for t in transitions {
    set.add((t.state, t.event))
  }
  set
}

///|
/// 追踪路径覆盖率：收集所有路径覆盖的转移
/// 
/// 对于每条路径 [s0, s1, ..., sn]，覆盖的转移为：
///   (s0, e01), (s1, e12), ..., (s{n-1}, e{n-1}n)
/// 其中 e{ij} 是 si → sj 的转移事件
fn trace_path_coverage(
  ctx : GraphContext,
  paths : Array[Array[String]],
) -> Set[(String, String)] {
  let covered = Set::new()

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
        Some(event) => covered.add((from, event))
        None => () // 未找到对应转移（理论上不可能）
      }
    }
  }

  covered
}

///|
/// 查找源状态到目标状态的转移事件
/// 若有多条转移，优先选择权重最小的事件（确定性）
fn find_transition(ctx : GraphContext, from : String, to : String) -> String? {
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

  best
}

///|
/// 计算未覆盖转移（总转移 - 已覆盖）
fn diff_transitions(
  all : Array[TransitionTarget],
  covered : Set[(String, String)],
) -> (Array[(String, String)], Int) {
  let uncovered = []
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

///|
/// 检查是否达到目标覆盖率
pub fn CoverageResult::is_satisfied(
  self : CoverageResult,
  target : Double,
) -> Bool {
  self.coverage_ratio >= target
}

///|
/// 获取覆盖率百分比字符串（保留 2 位小数）
pub fn CoverageResult::percentage_string(self : CoverageResult) -> String {
  // core strconv 无 format_float：整数化四舍五入到两位小数后手工拼接
  let cents = (self.coverage_ratio * 10000.0 + 0.5).to_int()
  let whole = cents / 100
  let frac = cents % 100
  if frac < 10 {
    "\{whole}.0\{frac}%"
  } else {
    "\{whole}.\{frac}%"
  }
}

// ==================== 单元测试 ====================

///|
test {
  // 简单线性链：a→b→c
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

  // 完整覆盖路径
  let paths = [["a", "b", "c"]]
  let result = calculate_coverage(ctx, paths)

  assert_eq(result.total_transitions, 2)
  assert_eq(result.covered_transitions, 2)
  assert_eq(result.uncovered_transitions.length(), 0)
  assert_true(result.coverage_ratio >= 0.99)
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
  assert_true(result.coverage_ratio >= 0.49)
  assert_true(result.coverage_ratio < 0.51)
}

///|
test {
  // 空路径：无可覆盖转移
  let ctx = build_graph_context(
    ["a", "b"],
    ["e1"],
    make_transitions([("a", "e1", "b", "Continue")]),
    "a",
    ["b"],
  ).unwrap()

  let result = calculate_coverage(ctx, [])

  assert_eq(result.total_transitions, 1)
  assert_eq(result.covered_transitions, 0)
  assert_eq(result.uncovered_transitions.length(), 1)
  assert_eq(result.coverage_ratio, 0.0)
}

///|
test {
  // 多路径覆盖：分支图
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

  // 两条路径覆盖所有转移
  let paths = [["a", "b", "d"], ["a", "c", "d"]]
  let result = calculate_coverage(ctx, paths)

  assert_eq(result.total_transitions, 4)
  assert_eq(result.covered_transitions, 4)
  assert_eq(result.uncovered_transitions.length(), 0)
  assert_eq(result.coverage_ratio, 1.0)
  assert_true(result.is_satisfied(1.0))
  assert_eq(result.percentage_string(), "100.00%")
}

///|
test {
  // 重复路径不应重复计数
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

  // 同一路径重复添加
  let paths = [
    ["a", "b", "c"],
    ["a", "b", "c"], // 重复
  ]
  let result = calculate_coverage(ctx, paths)

  assert_eq(result.total_transitions, 2)
  assert_eq(result.covered_transitions, 2) // 不应变成 4
  assert_eq(result.coverage_ratio, 1.0)
}

///|
test {
  // 环路径覆盖
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

  // 环行走
  let paths = [["a", "b", "a", "b", "c"]]
  let result = calculate_coverage(ctx, paths)

  assert_eq(result.total_transitions, 3)
  assert_eq(result.covered_transitions, 3)
  assert_eq(result.coverage_ratio, 1.0)
}
