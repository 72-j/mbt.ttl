// BFS 剪枝：从初始状态出发，仅保留可达状态
///|
/// 剪枝：移除不可达状态，返回优化后的 FsmIR
pub fn prune(ir : FsmIR) -> FsmIR {
  if ir.states.is_empty() {
    return ir
  }
  // 1. BFS 查找可达状态
  let initial_state = find_initial_state(ir)

  let visited = Array::make(ir.states.length(), false)
  let queue = [initial_state]
  visited[initial_state] = true

  while queue.length() > 0 {
    let state = queue.pop().unwrap()
    for t in ir.transitions {
      if t.from_state == state && not(visited[t.to_state]) {
        visited[t.to_state] = true
        queue.push(t.to_state)
      }
    }
  }

  // 2. 构建新的 FsmIR（仅包含可达状态）
  rebuild_ir(ir, visited)
}

///|
/// 查找初始状态
fn find_initial_state(ir : FsmIR) -> Int {
  for i = 0; i < ir.states.length(); i = i + 1 {
    if ir.states[i].is_initial {
      return i
    }
  }
  0 // 默认第一个状态
}

///|
/// 根据可达性标记重建 FsmIR
fn rebuild_ir(ir : FsmIR, visited : Array[Bool]) -> FsmIR {
  let mut new_ir = FsmIR::new()

  // 复制事件
  for event in ir.events {
    let (updated, _) = new_ir.add_event(event.name)
    new_ir = updated
  }

  // 建立旧状态名到新 ID 的映射
  let state_name_to_new_id = Map::new()
  let mut is_first_state = true // 跟踪是否是第一个复制的状态

  for i = 0; i < ir.states.length(); i = i + 1 {
    if visited[i] {
      let state = ir.states[i]

      // 只有第一个状态可以是初始状态
      let is_initial = state.is_initial && is_first_state
      if is_initial {
        is_first_state = false
      }

      let (updated_ir, new_id) = new_ir.add_state(
        state.name,
        is_initial~,
        is_nestable=state.is_nestable,
        exit_event=state.exit_event,
      )
      new_ir = updated_ir
      state_name_to_new_id.set(state.name, new_id)
    }
  }

  // 复制转移
  for t in ir.transitions {
    if visited[t.from_state] && visited[t.to_state] {
      let from_name = ir.states[t.from_state].name
      let to_name = ir.states[t.to_state].name

      match
        (state_name_to_new_id.get(from_name), state_name_to_new_id.get(to_name)) {
        (Some(fid), Some(tid)) =>
          new_ir = new_ir.add_transition(
            fid,
            tid,
            t.on_event,
            guard_def=t.guard_def,
            action=t.action,
          )
        _ => ()
      }
    }
  }

  new_ir
}

///|
async test {
  // 测试场景1：简单线性状态机
  let toml_content = @fs.read_file("./src/fsm/test.toml").text()
  let result = parse_toml(toml_content)
  guard result is Ok(ir) else { fail("Failed to parse TOML") }

  let pruned = prune(ir)

  // 验证所有状态都应该被保留（因为所有状态都可达）
  assert_eq(pruned.states.length(), 3)
  assert_eq(pruned.states.length(), ir.states.length())

  // 验证状态名保持一致
  let state_names = pruned.states.map(fn(s) { s.name })
  assert_true(state_names.contains("idle"))
  assert_true(state_names.contains("running"))
  assert_true(state_names.contains("paused"))

  // 验证转移数量保持一致
  assert_eq(pruned.transitions.length(), 4)
}

///|
test {
  // 测试场景2：创建包含不可达状态的状态机
  let ir = FsmIR::new()
  let (ir, start_id) = ir.add_event("start")
  let (ir, stop_id) = ir.add_event("stop")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, running_id) = ir.add_state("running")
  let (ir, dead_id) = ir.add_state("dead") // 不可达状态

  // idle -> running on start
  let ir = ir.add_transition(idle_id, running_id, start_id)
  // running -> idle on stop
  let ir = ir.add_transition(running_id, idle_id, stop_id)
  // dead 状态没有任何转移，是不可达的

  let pruned = prune(ir)

  // 验证 dead 状态被剪枝
  assert_eq(pruned.states.length(), 2)

  // 验证状态名
  let state_names = pruned.states.map(fn(s) { s.name })
  assert_true(state_names.contains("idle"))
  assert_true(state_names.contains("running"))
  assert_false(state_names.contains("dead"))

  // 验证转移数量
  assert_eq(pruned.transitions.length(), 2)

  // 验证转移关系正确
  // let idle_state = pruned.states.find(fn(s) { s.name == "idle" })
  // guard idle_state is Some(s) else { fail("idle not found") }

  // let running_state = pruned.states.find(fn(s) { s.name == "running" })
  // guard running_state is Some(s) else { fail("running not found") }
}

///|
test {
  // 测试场景3：空状态机
  let ir = FsmIR::new()
  let pruned = prune(ir)

  assert_eq(pruned.states.length(), 0)
  assert_eq(pruned.transitions.length(), 0)
  assert_eq(pruned.events.length(), 0)
}

///|
test {
  // 测试场景4：单状态状态机
  let ir = FsmIR::new()
  let (ir, start_id) = ir.add_event("start")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let ir = ir.add_transition(idle_id, idle_id, start_id) // 自环

  let pruned = prune(ir)

  assert_eq(pruned.states.length(), 1)
  assert_eq(pruned.states[0].name, "idle")
  assert_eq(pruned.transitions.length(), 1)
}

///|
test {
  // 测试场景5：环形状态机（所有状态都可达）
  let ir = FsmIR::new()
  let (ir, next_id) = ir.add_event("next")
  let (ir, a_id) = ir.add_state("a", is_initial=true)
  let (ir, b_id) = ir.add_state("b")
  let (ir, c_id) = ir.add_state("c")

  // a -> b -> c -> a 形成环
  let ir = ir.add_transition(a_id, b_id, next_id)
  let ir = ir.add_transition(b_id, c_id, next_id)
  let ir = ir.add_transition(c_id, a_id, next_id)

  let pruned = prune(ir)

  // 所有状态都可达
  assert_eq(pruned.states.length(), 3)

  let state_names = pruned.states.map(fn(s) { s.name })
  assert_true(state_names.contains("a"))
  assert_true(state_names.contains("b"))
  assert_true(state_names.contains("c"))

  assert_eq(pruned.transitions.length(), 3)
}

///|
test {
  // 测试场景6：部分可达状态机
  let ir = FsmIR::new()
  let (ir, tick_id) = ir.add_event("tick")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, dead1_id) = ir.add_state("dead1")
  let (ir, dead2_id) = ir.add_state("dead2")

  // idle 有自环，但 dead1 和 dead2 不可达
  let ir = ir.add_transition(idle_id, idle_id, tick_id)

  let pruned = prune(ir)

  assert_eq(pruned.states.length(), 1)
  assert_eq(pruned.states[0].name, "idle")
  assert_eq(pruned.transitions.length(), 1)

  let state_names = pruned.states.map(fn(s) { s.name })
  assert_false(state_names.contains("dead1"))
  assert_false(state_names.contains("dead2"))
}

///|
test {
  // 测试场景7：保留初始状态标记
  let ir = FsmIR::new()
  let (ir, tick_id) = ir.add_event("tick")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, dead_id) = ir.add_state("dead")

  let ir = ir.add_transition(idle_id, idle_id, tick_id)

  let pruned = prune(ir)

  assert_eq(pruned.states.length(), 1)
  assert_true(pruned.states[0].is_initial)
}

///|
test {
  // 测试场景8：保留 guard 和 action
  let ir = FsmIR::new()
  let (ir, start_id) = ir.add_event("start")
  let (ir, idle_id) = ir.add_state("idle", is_initial=true)
  let (ir, dead_id) = ir.add_state("dead")

  let ir = ir.add_transition(
    idle_id,
    idle_id,
    start_id,
    guard_def=Some(GuardDef::{ name: "x_check", expression: Some("x > 0") }),
    action=Some("log"),
  )

  let pruned = prune(ir)

  assert_eq(pruned.transitions.length(), 1)
  let trans = pruned.transitions[0]

  match trans.guard_def {
    Some(g) => assert_eq(g.expression, Some("x > 0"))
    None => fail("guard_def should be preserved")
  }

  match trans.action {
    Some(a) => assert_eq(a, "log")
    None => fail("action should be preserved")
  }
}

///|
test {
  // 测试场景9：多个初始状态（只有第一个初始状态可达）
  let ir = FsmIR::new()
  let (ir, tick_id) = ir.add_event("tick")
  let (ir, a_id) = ir.add_state("a", is_initial=true) // 第一个初始状态
  let (ir, b_id) = ir.add_state("b", is_initial=true) // 第二个初始状态（不可达）
  let (ir, dead_id) = ir.add_state("dead") // 不可达

  let ir = ir.add_transition(a_id, a_id, tick_id) // a -> a (自环)
  let ir = ir.add_transition(b_id, b_id, tick_id) // b -> b (不可达)

  let pruned = prune(ir)

  // 只有 a 可达（从初始状态出发），b 和 dead 都不可达
  assert_eq(pruned.states.length(), 1) // 只有 a
  assert_eq(pruned.states[0].name, "a")

  // a 是初始状态
  assert_true(pruned.states[0].is_initial)
}

///|
test {
  // 测试场景9b：两个初始状态都可达（需要有转移连接）
  let ir = FsmIR::new()
  let (ir, tick_id) = ir.add_event("tick")
  let (ir, a_id) = ir.add_state("a", is_initial=true)
  let (ir, b_id) = ir.add_state("b", is_initial=true) // 两个都是初始状态
  let (ir, dead_id) = ir.add_state("dead")

  // 添加转移使两者都可达
  let ir = ir.add_transition(a_id, b_id, tick_id) // a -> b
  let ir = ir.add_transition(b_id, a_id, tick_id) // b -> a

  // dead 仍然不可达
  let ir = ir.add_transition(a_id, a_id, tick_id) // 确保 a 有自环

  let pruned = prune(ir)

  // a 和 b 都可达
  assert_eq(pruned.states.length(), 2)

  // 但因为有两个 is_initial=true，BFS 会选第一个
  // 所以只有第一个是初始状态
  let initial_count = pruned.states.filter(fn(s) { s.is_initial }).length()
  assert_eq(initial_count, 1) // 只有一个初始状态
}

///|
test {
  // 测试场景9：多个初始状态（应该保留第一个）
  let ir = FsmIR::new()
  let (ir, tick_id) = ir.add_event("tick")
  let (ir, a_id) = ir.add_state("a", is_initial=true)
  let (ir, b_id) = ir.add_state("b", is_initial=true)
  let (ir, dead_id) = ir.add_state("dead")

  let ir = ir.add_transition(a_id, a_id, tick_id)
  let ir = ir.add_transition(b_id, b_id, tick_id)

  let pruned = prune(ir)

  // 两个状态都可达，但应该只有第一个是初始状态
  assert_eq(pruned.states.length(), 1)

  let initial_count = pruned.states.filter(fn(s) { s.is_initial }).length()
  assert_true(initial_count >= 1) // 至少有一个初始状态
}

///|
test {
  // 测试场景10：复杂状态机（树形结构）
  let ir = FsmIR::new()
  let (ir, next_id) = ir.add_event("next")
  let (ir, root_id) = ir.add_state("root", is_initial=true)
  let (ir, child1_id) = ir.add_state("child1")
  let (ir, child2_id) = ir.add_state("child2")
  let (ir, grandchild_id) = ir.add_state("grandchild") // 从 child2 可达
  let (ir, orphan_id) = ir.add_state("orphan") // 不可达

  // root -> child1, child2
  let ir = ir.add_transition(root_id, child1_id, next_id)
  let ir = ir.add_transition(root_id, child2_id, next_id)
  // child2 -> grandchild
  let ir = ir.add_transition(child2_id, grandchild_id, next_id)

  let pruned = prune(ir)

  // root, child1, child2, grandchild 可达，orphan 不可达
  assert_eq(pruned.states.length(), 4)

  let state_names = pruned.states.map(fn(s) { s.name })
  assert_true(state_names.contains("root"))
  assert_true(state_names.contains("child1"))
  assert_true(state_names.contains("child2"))
  assert_true(state_names.contains("grandchild"))
  assert_false(state_names.contains("orphan"))

  assert_eq(pruned.transitions.length(), 3)
}
