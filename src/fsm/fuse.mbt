
// ========================================
// 3. Fuse：融合转移链
// ========================================

///|
/// 融合：合并可串联的转移链 A→B→C → A→C
pub fn fuse(ir : FsmIR) -> FsmIR {
  // 构建出度和入度映射
  let out_degree = Array::make(ir.states.length(), 0)
  let in_degree = Array::make(ir.states.length(), 0)

  for t in ir.transitions {
    out_degree[t.from_state] = out_degree[t.from_state] + 1
    in_degree[t.to_state] = in_degree[t.to_state] + 1
  }

  // 查找可以融合的中间状态（出度=1，入度=1，且不是初始状态）
  let can_fuse = Array::make(ir.states.length(), false)
  for i = 0; i < ir.states.length(); i = i + 1 {
    let state = ir.states[i]
    // 条件：出度=1，入度=1，不是初始状态
    if out_degree[i] == 1 && in_degree[i] == 1 && not(state.is_initial) {
      can_fuse[i] = true
    }
  }

  // 构建转移映射：from -> (event -> transition)
  let trans_map = Map([])
  for t in ir.transitions {
    let key = "\{t.from_state}|\{t.on_event}"
    trans_map.set(key, t)
  }

  // 构建新转移
  let new_transitions = []
  let skipped_ids = Set::new()

  for t in ir.transitions {
    // 如果这条转移已经被跳过，跳过
    if skipped_ids.contains(t.id) {
      continue
    }

    // 检查目标状态是否可以融合
    if can_fuse[t.to_state] {
      // 查找目标状态的出边
      let target_key = "\{t.to_state}|\{t.on_event}"
      match trans_map.get(target_key) {
        Some(next_t) =>
          // 只有当源状态不是融合状态时才融合
          if not(can_fuse[t.from_state]) {
            // 检查是否会产生循环（目标状态的下一跳回到源状态）
            if next_t.to_state != t.from_state {
              // A -> B -> C 融合为 A -> C
              let fused_trans = TransitionDef::{
                id: t.id,
                from_state: t.from_state,
                to_state: next_t.to_state,
                on_event: t.on_event,
                guard_def: t.guard_def,
                action: t.action,
                metadata: Map([]),
              }
              new_transitions.push(fused_trans)
              skipped_ids.add(next_t.id)
              skipped_ids.add(t.id)
              continue
            }
          }
        _ => ()
      }
    }

    // 保留原转移（如果还没被跳过）
    if not(skipped_ids.contains(t.id)) {
      new_transitions.push(t)
    }
  }

  // 构建新的 FsmIR
  let mut new_ir = FsmIR::new()

  // 复制事件
  for event in ir.events {
    let (updated, _) = new_ir.add_event(event.name)
    new_ir = updated
  }

  // 复制状态
  for state in ir.states {
    let (updated_ir, _) = new_ir.add_state(
      state.name,
      is_initial=state.is_initial,
      is_nestable=state.is_nestable,
      exit_event=state.exit_event,
    )
    new_ir = updated_ir
  }

  // 添加新转移
  for t in new_transitions {
    new_ir = new_ir.add_transition(
      t.from_state,
      t.to_state,
      t.on_event,
      guard_def=t.guard_def,
      action=t.action,
    )
  }

  new_ir
}
