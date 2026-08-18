// ===== COO 格式（构造期，追加 O(1)） =====
///|
pub struct CooStorage {
  rows : Array[Int]
  cols : Array[Int]
  values : Array[Transition]
}

///|
pub fn CooStorage::empty() -> CooStorage {
  CooStorage::{ rows: [], cols: [], values: [] }
}

///|
pub fn CooStorage::append(
  self : CooStorage,
  row : Int,
  col : Int,
  val : Transition,
) -> Unit {
  self.rows.push(row)
  self.cols.push(col)
  self.values.push(val)
}

///|
pub fn CooStorage::nnz(self : CooStorage) -> Int {
  self.values.length()
}

// ===== CSR 格式（代码生成期，按行切片 O(1)） =====

///|
pub struct CsrStorage {
  row_ptr : Array[Int] // 长度 = n_rows + 1
  col_idx : Array[Int]
  values : Array[Transition]
}

// COO → CSR 转换

///|
pub fn CsrStorage::from_coo(coo : CooStorage, n_rows : Int) -> CsrStorage {
  // 1. 统计每行元素个数
  let row_counts = Array::make(n_rows, 0)
  for i = 0; i < coo.nnz(); i = i + 1 {
    let row = coo.rows[i]
    row_counts[row] = row_counts[row] + 1
  }

  // 2. 计算行指针（前缀和）
  let row_ptr = Array::make(n_rows + 1, 0)
  for r = 0; r < n_rows; r = r + 1 {
    row_ptr[r + 1] = row_ptr[r] + row_counts[r]
  }

  // 3. 按行主序填充 col_idx 和 values
  let col_idx = Array::make(coo.nnz(), 0)
  let values = Array::make(coo.nnz(), Transition::new("", None, None))
  let offsets = Array::make(n_rows, 0) // 每行当前写入位置

  for i = 0; i < coo.nnz(); i = i + 1 {
    let row = coo.rows[i]
    let pos = row_ptr[row] + offsets[row]
    col_idx[pos] = coo.cols[i]
    values[pos] = coo.values[i]
    offsets[row] = offsets[row] + 1
  }

  CsrStorage::{ row_ptr, col_idx, values }
}

// 按行切片：返回该行的 (col_idx, value) 列表

///|
pub fn CsrStorage::get_row(
  self : CsrStorage,
  row : Int,
) -> Array[(Int, Transition)] {
  let start = self.row_ptr[row]
  let end = self.row_ptr[row + 1]
  let result = []
  for i = start; i < end; i = i + 1 {
    result.push((self.col_idx[i], self.values[i]))
  }
  result
}

///|
test {
  // 测试 COO 创建和追加
  let coo = CooStorage::empty()

  assert_eq(coo.nnz(), 0)

  // 追加转移规则
  let trans1 = Transition::new("running", None, None)
  coo.append(0, 0, trans1) // idle --start--> running

  assert_eq(coo.nnz(), 1)
  assert_eq(coo.rows[0], 0)
  assert_eq(coo.cols[0], 0)

  let trans2 = Transition::new("idle", None, None)
  coo.append(1, 1, trans2) // running --stop--> idle

  assert_eq(coo.nnz(), 2)
  assert_eq(coo.rows[1], 1)
  assert_eq(coo.cols[1], 1)
}

///|
test {
  // 测试 COO 追加顺序
  let coo = CooStorage::empty()

  // 添加4条转移规则（对应 test.toml）
  let start_trans = Transition::new("running", None, None)
  let stop_trans = Transition::new("idle", None, None)
  let pause_trans = Transition::new("paused", None, None)
  let resume_trans = Transition::new("running", None, None)

  coo.append(0, 0, start_trans) // idle --start--> running
  coo.append(1, 1, stop_trans) // running --stop--> idle
  coo.append(1, 2, pause_trans) // running --pause--> paused
  coo.append(2, 3, resume_trans) // paused --resume--> running

  assert_eq(coo.nnz(), 4)

  // 验证顺序
  assert_eq(coo.rows[0], 0)
  assert_eq(coo.cols[0], 0)
  assert_eq(coo.values[0].next_state, "running")

  assert_eq(coo.rows[1], 1)
  assert_eq(coo.cols[1], 1)
  assert_eq(coo.values[1].next_state, "idle")

  assert_eq(coo.rows[2], 1)
  assert_eq(coo.cols[2], 2)
  assert_eq(coo.values[2].next_state, "paused")

  assert_eq(coo.rows[3], 2)
  assert_eq(coo.cols[3], 3)
  assert_eq(coo.values[3].next_state, "running")
}

///|
test {
  // 测试 CSR 转换
  let coo = CooStorage::empty()

  // 添加转移规则
  coo.append(0, 0, Transition::new("running", None, None)) // idle --start--> running
  coo.append(1, 1, Transition::new("idle", None, None)) // running --stop--> idle
  coo.append(1, 2, Transition::new("paused", None, None)) // running --pause--> paused
  coo.append(2, 3, Transition::new("running", None, None)) // paused --resume--> running

  let csr = CsrStorage::from_coo(coo, 3) // 3 个状态

  // 验证行指针
  assert_eq(csr.row_ptr.length(), 4) // n_rows + 1

  // idle (行0): 1 条转移
  assert_eq(csr.row_ptr[0], 0)
  assert_eq(csr.row_ptr[1], 1)

  // running (行1): 2 条转移
  assert_eq(csr.row_ptr[1], 1)
  assert_eq(csr.row_ptr[2], 3)

  // paused (行2): 1 条转移
  assert_eq(csr.row_ptr[2], 3)
  assert_eq(csr.row_ptr[3], 4)
}

///|
test {
  // 测试 CSR 按行切片
  let coo = CooStorage::empty()

  // 添加转移规则
  coo.append(0, 0, Transition::new("running", None, None)) // idle --start--> running
  coo.append(1, 1, Transition::new("idle", None, None)) // running --stop--> idle
  coo.append(1, 2, Transition::new("paused", None, None)) // running --pause--> paused
  coo.append(2, 3, Transition::new("running", None, None)) // paused --resume--> running

  let csr = CsrStorage::from_coo(coo, 3)

  // idle 行
  let idle_row = csr.get_row(0)
  assert_eq(idle_row.length(), 1)
  let (col, trans) = idle_row[0]
  assert_eq(col, 0) // start 事件
  assert_eq(trans.next_state, "running")

  // running 行
  let running_row = csr.get_row(1)
  assert_eq(running_row.length(), 2)

  let (col1, trans1) = running_row[0]
  assert_eq(col1, 1) // stop 事件
  assert_eq(trans1.next_state, "idle")

  let (col2, trans2) = running_row[1]
  assert_eq(col2, 2) // pause 事件
  assert_eq(trans2.next_state, "paused")

  // paused 行
  let paused_row = csr.get_row(2)
  assert_eq(paused_row.length(), 1)
  let (col, trans) = paused_row[0]
  assert_eq(col, 3) // resume 事件
  assert_eq(trans.next_state, "running")
}

///|
test {
  // 测试空行
  let coo = CooStorage::empty()

  // 只添加一个转移（行1）
  coo.append(1, 0, Transition::new("running", None, None))

  let csr = CsrStorage::from_coo(coo, 3) // 3 行，但只有行1有元素

  // 行0应该为空
  let row0 = csr.get_row(0)
  assert_eq(row0.length(), 0)

  // 行1应该有1个元素
  let row1 = csr.get_row(1)
  assert_eq(row1.length(), 1)

  // 行2应该为空
  let row2 = csr.get_row(2)
  assert_eq(row2.length(), 0)
}

///|
test {
  // 测试单行多列
  let coo = CooStorage::empty()

  // 行0有3个元素
  coo.append(0, 0, Transition::new("a", None, None))
  coo.append(0, 1, Transition::new("b", None, None))
  coo.append(0, 2, Transition::new("c", None, None))

  let csr = CsrStorage::from_coo(coo, 1)

  let row0 = csr.get_row(0)
  assert_eq(row0.length(), 3)

  assert_eq(row0[0].0, 0) // 列索引
  assert_eq(row0[0].1.next_state, "a")
  assert_eq(row0[1].0, 1)
  assert_eq(row0[1].1.next_state, "b")
  assert_eq(row0[2].0, 2)
  assert_eq(row0[2].1.next_state, "c")
}

///|
test {
  // 测试多行单列
  let coo = CooStorage::empty()

  // 列0有3个元素
  coo.append(0, 0, Transition::new("a", None, None))
  coo.append(1, 0, Transition::new("b", None, None))
  coo.append(2, 0, Transition::new("c", None, None))

  let csr = CsrStorage::from_coo(coo, 3)

  for row = 0; row < 3; row = row + 1 {
    let r = csr.get_row(row)
    assert_eq(r.length(), 1)
    assert_eq(r[0].0, 0) // 列索引都是0
  }

  assert_eq(csr.get_row(0)[0].1.next_state, "a")
  assert_eq(csr.get_row(1)[0].1.next_state, "b")
  assert_eq(csr.get_row(2)[0].1.next_state, "c")
}

///|
test {
  // 测试大规模稀疏矩阵
  let coo = CooStorage::empty()

  // 100x100 矩阵，只有10个非零元素
  let positions = [
    (0, 0),
    (10, 10),
    (20, 20),
    (30, 30),
    (40, 40),
    (50, 50),
    (60, 60),
    (70, 70),
    (80, 80),
    (90, 90),
  ]

  for i = 0; i < positions.length(); i = i + 1 {
    let (row, col) = positions[i]
    coo.append(row, col, Transition::new("state_\{i}", None, None))
  }

  assert_eq(coo.nnz(), 10)

  let csr = CsrStorage::from_coo(coo, 100)

  // 验证行指针
  assert_eq(csr.row_ptr.length(), 101)

  // 验证每个非零元素都在正确位置
  for i = 0; i < positions.length(); i = i + 1 {
    let (row, col) = positions[i]
    let r = csr.get_row(row)
    assert_eq(r.length(), 1)
    assert_eq(r[0].0, col)
  }
}

// async test {
//   // 测试 CSR 缓存机制（多次调用应返回相同结果）
//   let toml_content = @fs.read_file("./src/fsm/test.toml").text()
//   let result = parse_toml(toml_content)
//   guard result is Ok(ir) else { fail("Failed to parse TOML") }

//   let tensor = FsmTensor::from_ir(ir)

//   // 多次调用 ensure_csr
//   let csr1 = tensor.ensure_csr()
//   let csr2 = tensor.ensure_csr()

//   // 验证结果一致
//   assert_eq(csr1.row_ptr.length(), csr2.row_ptr.length())
//   assert_eq(csr1.col_idx.length(), csr2.col_idx.length())
//   assert_eq(csr1.values.length(), csr2.values.length())
// }
