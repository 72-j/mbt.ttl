// ===== Path Generator - 五类测试路径生成策略 =====
// 规范第十二节：基于图分析结果生成测试路径
//   1. 最短可达路径：初始 → 每个可达状态（含死状态，暴露缺陷）
//   2. 完整路径：初始 → 终止状态
//   3. 错误路径：以 Error 效果转移结尾的路径
//   4. 循环加压路径：环行走 2 圈 / 3 圈
//   5. 未覆盖补充路径：针对覆盖盲区的定点路径（由 analyzer 二阶段注入）

///|
/// 路径生成器：聚合各分析结果，产出测试路径（路径 = 状态序列）
pub(all) struct PathGenerator {
  ctx : GraphContext
  reachability : ReachabilityResult
  dead : DeadStateResult
  cycles : CycleResult
  shortest : ShortestPathResult
}

///|
/// 构造路径生成器
pub fn make_path_generator(
  ctx : GraphContext,
  reachability : ReachabilityResult,
  dead : DeadStateResult,
  cycles : CycleResult,
  shortest : ShortestPathResult,
) -> PathGenerator {
  PathGenerator::{ ctx, reachability, dead, cycles, shortest }
}

///|
/// 类别 1：初始 → 每个可达状态的最短路径
/// 跳过初始状态自身（空路径不驱动任何转移）；死状态照常生成以暴露缺陷
pub fn PathGenerator::shortest_reachable_paths(
  self : PathGenerator,
) -> Array[Array[String]] {
  let paths = []
  for state in self.reachability.reachable {
    if state == self.ctx.initial_state {
      continue
    }
    match self.shortest.state_paths.get(state) {
      Some(path) => if path.length() > 1 { paths.push(path) }
      None => ()
    }
  }
  paths
}

///|
/// 类别 2：初始 → 终止状态的完整路径（_fsm 到达终态即完成一轮完整生命周期）
pub fn PathGenerator::complete_paths(
  self : PathGenerator,
) -> Array[Array[String]] {
  let paths = []
  for terminal in self.ctx.terminal_states {
    match self.shortest.state_paths.get(terminal) {
      Some(path) => if path.length() > 1 { paths.push(path) }
      None => () // 不可达的终止状态无法生成
    }
  }
  paths
}

///|
/// 类别 3：错误路径。以 Error 效果转移 (from --e--> target) 结尾：
/// 前缀 = 初始 → from 的最短路径，再走一步错误转移
pub fn PathGenerator::error_paths(self : PathGenerator) -> Array[Array[String]] {
  let paths = []
  for t in self.ctx.transitions {
    if t.effect is Error(_) {
      match self.shortest.state_paths.get(t.state) {
        Some(prefix) => {
          let path = prefix.copy()
          path.push(t.target)
          paths.push(path)
        }
        None => () // from 不可达（不应发生，可达性已过滤）
      }
    }
  }
  paths
}

///|
/// 类别 4：循环加压路径。重建 SCC 内的一条环行走，按 rounds 圈重复（默认 2、3 圈）：
/// prefix(初始→环起点) + (环体, 回到起点) × r
pub fn PathGenerator::cycle_pressure_paths(
  self : PathGenerator,
  rounds? : Array[Int] = [2, 3],
) -> Array[Array[String]] {
  let paths = []
  for cycle in self.cycles.cycles {
    match self.reconstruct_ring(cycle) {
      Some(ring) => {
        // ring = [s0, s1, ..., sm]，闭合边 sm→s0；环体 = ring[1:]
        let entry = ring[0]
        let body = []
        for i = 1; i < ring.length(); i = i + 1 {
          body.push(ring[i])
        }

        let prefix = match self.shortest.state_paths.get(entry) {
          Some(p) => p
          None => continue
        }

        for r in rounds {
          let path = prefix.copy()
          for _step = 0; _step < r; _step = _step + 1 {
            for s in body {
              path.push(s)
            }
            path.push(entry) // 走完一圈回到起点
          }
          paths.push(path)
        }
      }
      None => () // 无法重建环行走（极端 SCC 结构），跳过
    }
  }
  paths
}

///|
/// 类别 5：未覆盖补充路径。针对覆盖盲区 (from, on)：
/// 前缀 = 初始 → from 的最短路径，再走该未覆盖事件
pub fn PathGenerator::uncovered_paths(
  self : PathGenerator,
  uncovered : Array[(String, String)],
) -> Array[Array[String]] {
  let paths = []
  for pair in uncovered {
    let (from, _on) = pair
    let prefix = match self.shortest.state_paths.get(from) {
      Some(p) => p
      None => continue
    }
    // 找到 (from, on) 对应的目标状态
    for t in self.ctx.transitions {
      if t.state == from && t.event == _on {
        let path = prefix.copy()
        path.push(t.target)
        paths.push(path)
      }
    }
  }
  paths
}

///|
/// 全量生成：类别 1-4 + 未覆盖补充（类别 5 由 analyzer 在首次覆盖计算后注入），去重
pub fn PathGenerator::generate_all(
  self : PathGenerator,
  uncovered : Array[(String, String)],
) -> Array[Array[String]] {
  let all = []
  for path in self.shortest_reachable_paths() {
    all.push(path)
  }
  for path in self.complete_paths() {
    all.push(path)
  }
  for path in self.error_paths() {
    all.push(path)
  }
  for path in self.cycle_pressure_paths() {
    all.push(path)
  }
  for path in self.uncovered_paths(uncovered) {
    all.push(path)
  }
  dedup_paths(all)
}

///|
/// 重建 SCC 内的一条环行走：从 scc[0] 出发，贪心跟随 SCC 内
/// 未访问状态的转移，回到起点即闭合；步数预算耗尽则放弃
fn PathGenerator::reconstruct_ring(
  self : PathGenerator,
  scc : Array[String],
) -> Array[String]? {
  if scc.length() == 0 {
    return None
  }
  // 环入口规范化：取 SCC 中距初始状态最近者（并列取先声明者），
  // 消除 tarjan_scc 内部顺序对输出确定性的影响
  let start = canonical_cycle_entry(self, scc)
  let ring = [start]
  let mut current = start
  let budget = scc.length() * 3

  for _step = 0; _step < budget; _step = _step + 1 {
    // 候选：current 的 SCC 内后继
    let candidates = []
    for t in self.ctx.transitions {
      if t.state == current && scc.contains(t.target) {
        candidates.push(t.target)
      }
    }
    if candidates.length() == 0 {
      return None // 不应发生（强连通必有出边）
    }
    // 优先回到起点闭合环
    if ring.length() > 1 && candidates.contains(start) {
      return Some(ring)
    }
    // 否则走第一个未访问的状态
    let mut next : String? = None
    for cand in candidates {
      if !ring.contains(cand) {
        next = Some(cand)
        break
      }
    }
    match next {
      Some(s) => {
        ring.push(s)
        current = s
      }
      None => return Some(ring) // 全部已访问但未回到起点：退化为已走部分
    }
  }
  None
}

///|
/// 选择环入口：SCC 内距初始状态最短者；距离并列时取节点插入序靠前者
/// （事件权重可为 0 导致并列，须用声明序消除 tarjan_scc 内部顺序的影响）
fn canonical_cycle_entry(gen : PathGenerator, scc : Array[String]) -> String {
  let mut best = scc[0]
  let mut best_dist = UNREACHABLE_DISTANCE
  let mut best_order = UNREACHABLE_DISTANCE
  for state in scc {
    let dist = gen.shortest.distances.get(state).unwrap_or(UNREACHABLE_DISTANCE)
    let order = gen.ctx.state_to_id
      .get(state)
      .unwrap_or(@moongraph.NodeIndex::new(UNREACHABLE_DISTANCE))
      .value()
    if dist < best_dist || (dist == best_dist && order < best_order) {
      best_dist = dist
      best_order = order
      best = state
    }
  }
  best
}

///|
/// 路径去重：以 "s1/s2/..." 为键
fn dedup_paths(paths : Array[Array[String]]) -> Array[Array[String]] {
  let seen : Array[String] = []
  let result = []
  for path in paths {
    let buf = StringBuilder::new()
    for i = 0; i < path.length(); i = i + 1 {
      if i > 0 {
        buf.write("/")
      }
      buf.write(path[i])
    }
    let key = buf.to_string()
    if !seen.contains(key) {
      seen.push(key)
      result.push(path)
    }
  }
  result
}

///|
test {
  // 线性链 a→b→c：类别 1/2 各覆盖 b、c
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
  let reach = analyze_reachability(ctx)
  let dead = detect_dead_states(ctx, reach)
  let cycles = detect_cycles(ctx)
  let sp = generate_shortest_paths(ctx, reach)
  let gen = make_path_generator(ctx, reach, dead, cycles, sp)

  let shortest = gen.shortest_reachable_paths()
  assert_eq(shortest, [["a", "b"], ["a", "b", "c"]])

  let complete = gen.complete_paths()
  assert_eq(complete, [["a", "b", "c"]])

  let all = gen.generate_all([])
  assert_eq(all.length(), 2) // 去重后无重复
}

///|
test {
  // 环 a↔b：加压路径走 2 圈与 3 圈
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
  let dead = detect_dead_states(ctx, reach)
  let cycles = detect_cycles(ctx)
  let sp = generate_shortest_paths(ctx, reach)
  let gen = make_path_generator(ctx, reach, dead, cycles, sp)

  let pressure = gen.cycle_pressure_paths()
  assert_eq(pressure.length(), 2) // ×2 与 ×3
  let two = pressure[0]
  let three = pressure[1]
  // 环体 [b]，闭合回 a：a b a b a / a b a b a b a
  assert_eq(two, ["a", "b", "a", "b", "a"])
  assert_eq(three, ["a", "b", "a", "b", "a", "b", "a"])
}

///|
test {
  // 错误路径 + 未覆盖补充路径
  let ctx = build_graph_context(
    ["a", "b", "err", "c"],
    ["e1", "fail", "e2"],
    make_transitions([
      ("a", "e1", "b", "Continue"),
      ("b", "fail", "err", "Error"),
      ("b", "e2", "c", "Continue"),
    ]),
    "a",
    ["c"],
  ).unwrap()
  let reach = analyze_reachability(ctx)
  let dead = detect_dead_states(ctx, reach)
  let cycles = detect_cycles(ctx)
  let sp = generate_shortest_paths(ctx, reach)
  let gen = make_path_generator(ctx, reach, dead, cycles, sp)

  let errors = gen.error_paths()
  assert_eq(errors, [["a", "b", "err"]])

  let uncovered = gen.uncovered_paths([("b", "e2")])
  assert_eq(uncovered, [["a", "b", "c"]])
}
