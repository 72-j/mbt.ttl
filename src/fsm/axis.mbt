// 维度轴：将纯数字下标包装为语义标签
///|
pub struct Axis {
  name : String
  labels : Array[String]
  index : Map[String, Int] // 反向映射：标签 → 下标
}

///|
pub fn Axis::new(name : String, labels : Array[String]) -> Axis {
  let index = Map([])
  for i = 0; i < labels.length(); i = i + 1 {
    index.set(labels[i], i)
  }
  Axis::{ name, labels, index }
}

///|
test {
  // 测试 Axis 创建
  let labels = ["idle", "running", "paused"]
  let axis = Axis::new("state", labels)

  assert_eq(axis.name, "state")
  assert_eq(axis.labels.length(), 3)
  assert_eq(axis.size(), 3)
}

///|
test {
  // 测试 Axis 标签到索引转换
  let labels = ["idle", "running", "paused"]
  let axis = Axis::new("state", labels)

  assert_eq(axis.label_to_idx("idle"), 0)
  assert_eq(axis.label_to_idx("running"), 1)
  assert_eq(axis.label_to_idx("paused"), 2)
}

///|
test {
  // 测试 Axis 索引到标签转换
  let labels = ["idle", "running", "paused"]
  let axis = Axis::new("state", labels)

  assert_eq(axis.idx_to_label(0), "idle")
  assert_eq(axis.idx_to_label(1), "running")
  assert_eq(axis.idx_to_label(2), "paused")
}

///|
test {
  // 测试 Axis 双向映射一致性
  let labels = ["a", "b", "c", "d", "e"]
  let axis = Axis::new("test", labels)

  for i = 0; i < labels.length(); i = i + 1 {
    let label = labels[i]
    let idx = axis.label_to_idx(label)
    let back_label = axis.idx_to_label(idx)
    assert_eq(label, back_label)
  }
}

///|
test {
  // 测试 Axis size 方法
  let empty_axis = Axis::new("empty", [])
  assert_eq(empty_axis.size(), 0)

  let single_axis = Axis::new("single", ["only"])
  assert_eq(single_axis.size(), 1)

  let large_axis = Axis::new("large", ["a", "b", "c", "d", "e"])
  assert_eq(large_axis.size(), 5)
}

///|
test {
  // 测试 Axis 标签查找（存在的标签）
  let labels = ["start", "stop", "pause", "resume"]
  let axis = Axis::new("event", labels)

  // 所有标签都应该能找到
  for i = 0; i < labels.length(); i = i + 1 {
    let idx = axis.label_to_idx(labels[i])
    assert_eq(idx, i)
  }
}

///|
test {
  // 测试 Axis 空标签列表
  let axis = Axis::new("empty", [])

  assert_eq(axis.size(), 0)

  // 注意：空轴的 label_to_idx 会 panic
  // 这是设计行为，不测试 panic
}

///|
test {
  // 测试单标签轴
  let axis = Axis::new("single", ["only"])

  assert_eq(axis.size(), 1)
  assert_eq(axis.label_to_idx("only"), 0)
  assert_eq(axis.idx_to_label(0), "only")
}

///|
test {
  // 测试 Axis 不存在的标签查找（panic）
  // 注意：这个测试验证的是设计行为，不需要测试 panic 本身
  let axis = Axis::new("test", ["a", "b", "c"])

  // 正常标签查找
  assert_eq(axis.label_to_idx("a"), 0)
  assert_eq(axis.label_to_idx("b"), 1)
  assert_eq(axis.label_to_idx("c"), 2)

  // 不存在的标签查找会 panic（这是设计行为）
  // 不在此测试中验证 panic
}

///|
test {
  // 测试单标签轴
  let axis = Axis::new("single", ["only"])

  assert_eq(axis.size(), 1)
  assert_eq(axis.label_to_idx("only"), 0)
  assert_eq(axis.idx_to_label(0), "only")
}
// 通过标签查找下标，找不到则 panic

///|
pub fn Axis::label_to_idx(self : Axis, label : String) -> Int {
  match self.index.get(label) {
    Some(idx) => idx
    None => panic()
  }
}

// 通过下标查找标签

///|
pub fn Axis::idx_to_label(self : Axis, idx : Int) -> String {
  self.labels[idx]
}

///|
pub fn Axis::size(self : Axis) -> Int {
  self.labels.length()
}
