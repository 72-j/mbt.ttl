// 等价类划分
///|
struct Partition {
  groups : Array[Array[String]] // 每个 group 是一组等价状态
}

///|
fn Partition::new() -> Partition {
  Partition::{ groups: [] }
}

// 查找状态所属的等价类索引

///|
fn Partition::class_of(self : Partition, state : String) -> Int {
  for i = 0; i < self.groups.length(); i = i + 1 {
    if self.groups[i].contains(state) {
      return i
    }
  }
  panic()
}

// 分裂：将指定状态从原等价类中分离出来，形成新类

///|
fn Partition::split_off(self : Partition, state : String) -> Unit {
  for i = 0; i < self.groups.length(); i = i + 1 {
    let group = self.groups[i]
    if group.contains(state) && group.length() > 1 {
      // 从原组移除
      let new_group = group.filter(s => s != state)
      self.groups[i] = new_group
      // 创建新组
      self.groups.push([state])
      return
    }
  }
}

// 获取两个状态的转移目标（按事件对齐）
// fn get_transition_target(
//   tensor : FsmTensor,
//   state  : String,
//   event  : String,
// ) -> Option[String] {
//   let csr = tensor.ensure_csr()
//   let row = tensor.state_axis().label_to_idx(state)
//   let col = tensor.event_axis().label_to_idx(event)
//   let row_entries = csr.get_row(row)

//   for c, trans in row_entries {
//     if c == col {
//       let (_str, tran)=trans
//       return Some(tran.next_state)
//     }
//   }
//   None
// }

///| 最小化：合并转移行为完全相同的状态
// pub fn minimize(ir: FsmIR) -> FsmIR {
//   // 特殊处理：单状态或无转移直接返回
//   if ir.states.length() <= 1 || ir.transitions.is_empty() {
//     return ir
//   }

//   // 初始化：每个状态在独立的等价类
//   let mut partition = Array::make(ir.states.length(), 0)
//   let mut changed = true
//   let mut iteration = 0
//   let max_iterations = ir.states.length()

//   // 迭代直到稳定
//   while changed && iteration < max_iterations {
//     changed = false
//     iteration = iteration + 1

//     // 按当前等价类重新分组
//     let mut class_mapping = Map([])
//     let mut next_class_id = 0

//     for i = 0; i < ir.states.length(); i = i + 1 {
//       let signature = compute_state_signature(ir, i, partition)
//       let key = "(\{partition[i]}, \{signature})"

//       match class_mapping.get(key) {
//         Some(class_id) => {
//           partition[i] = class_id
//         }
//         None => {
//           class_mapping.set(key, next_class_id)
//           partition[i] = next_class_id
//           next_class_id = next_class_id + 1
//         }
//       }
//     }
//   }

//   // 如果没有合并，返回原 IR
//   let class_count = {
//     let mut max = 0
//     for p in partition {
//       if p > max { max = p }
//     }
//     max + 1
//   }

//   if class_count == ir.states.length() {
//     return ir
//   }

//   // 构建最小化后的 FsmIR
//   build_minimized_ir(ir, partition)
// }

///|
/// 计算状态的签名（用于等价判断）
fn compute_state_signature(
  ir : FsmIR,
  state_idx : Int,
  partition : Array[Int],
) -> String {
  let parts = []

  // 获取该状态的所有出边，收集目标等价类和事件
  for t in ir.transitions {
    if t.from_state == state_idx {
      let target_class = partition[t.to_state]
      let event_name = ir.events[t.on_event].name
      parts.push("(\{event_name}->\{target_class})")
    }
  }

  // 排序确保顺序一致
  parts.sort()
  parts.join("|")
}

///|
/// 根据等价类划分构建新的 FsmIR
fn build_minimized_ir(ir : FsmIR, partition : Array[Int]) -> FsmIR {
  let mut new_ir = FsmIR::new()

  // 复制事件
  for event in ir.events {
    let (updated, _) = new_ir.add_event(event.name)
    new_ir = updated
  }

  // 建立类 ID 到新状态 ID 的映射
  let class_to_new_id = Map([])
  let class_representatives = Map([]) // 类 ID → 代表状态索引

  // 第一次遍历：创建新状态
  for i = 0; i < ir.states.length(); i = i + 1 {
    let class_id = partition[i]
    if not(class_to_new_id.contains(class_id)) {
      let old_state = ir.states[i]
      let (updated_ir, new_id) = new_ir.add_state(
        old_state.name,
        is_initial=old_state.is_initial,
        is_nestable=old_state.is_nestable,
        exit_event=old_state.exit_event,
      )
      new_ir = updated_ir
      class_to_new_id.set(class_id, new_id)
      class_representatives.set(class_id, i)
    }
  }

  // 第二次遍历：复制转移（只从代表状态复制）
  for i = 0; i < ir.states.length(); i = i + 1 {
    let class_id = partition[i]

    // 检查是否是代表状态
    match class_representatives.get(class_id) {
      Some(rep_idx) => {
        if rep_idx != i {
          continue // 不是代表状态，跳过
        }

        // 现在 rep_idx 在这个作用域内是有效的
        match class_to_new_id.get(class_id) {
          Some(fid) =>
            for t in ir.transitions {
              if t.from_state == rep_idx {
                match class_to_new_id.get(partition[t.to_state]) {
                  Some(tid) =>
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
          _ => ()
        }
      }
      None => continue // 没有代表状态，跳过
    }
  }

  new_ir
}

///|
/// 最小化：合并转移行为完全相同的状态
pub fn minimize(ir : FsmIR) -> FsmIR {
  // 特殊处理：单状态或无转移直接返回
  if ir.states.length() <= 1 {
    return ir
  }

  // 初始化：每个状态在独立的等价类
  let partition = Array::make(ir.states.length(), 0)
  let mut class_count = ir.states.length()
  let mut changed = true
  let mut iteration = 0
  let max_iterations = ir.states.length()

  // 迭代直到稳定
  while changed && iteration < max_iterations {
    changed = false
    iteration = iteration + 1

    // 按当前等价类重新分组
    let new_partition = Array::make(ir.states.length(), 0)
    let class_mapping = Map([]) // (class_id, transition_signature) -> new_class_id
    let mut next_class_id = 0

    for i = 0; i < ir.states.length(); i = i + 1 {
      let signature = compute_state_signature(ir, i, partition)
      let key = "(\{partition[i]}, \{signature})"

      match class_mapping.get(key) {
        Some(class_id) => new_partition[i] = class_id
        None => {
          class_mapping.set(key, next_class_id)
          new_partition[i] = next_class_id
          next_class_id = next_class_id + 1
        }
      }
    }

    // 检查是否变化
    for i = 0; i < ir.states.length(); i = i + 1 {
      if new_partition[i] != partition[i] {
        changed = true
        partition[i] = new_partition[i]
      }
    }

    class_count = next_class_id
  }

  // 如果没有合并，返回原 IR
  if class_count == ir.states.length() {
    return ir
  }

  // 构建最小化后的 FsmIR
  build_minimized_ir(ir, partition)
}
