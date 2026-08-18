# 自建轻量张量层架构设计

自建轻量张量层的核心架构设计为：以语义化维度标签和稀疏存储为底层基础，通过 14 个算子分阶段执行编译期代数优化，最终将张量完全销毁并展开为扁平代码，实现运行时零开销。

## 整体分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                    应用层（状态机编译器）                       │
│   construct → prune → minimize → fuse → slice → 代码生成     │
├─────────────────────────────────────────────────────────────┤
│                    算子层（14 个算子）                         │
│   基础变换 │ 组合算子 │ 优化算子 │ 验证算子                    │
├─────────────────────────────────────────────────────────────┤
│                    存储层（双格式稀疏）                        │
│   CSR（按状态压缩）  │  CSC（按事件压缩）                      │
├─────────────────────────────────────────────────────────────┤
│                    核心层（类型 + 标签）                       │
│   FsmTensor  │  Axis  │  LabelMap  │  Transition             │
└─────────────────────────────────────────────────────────────┘
```

## 核心层：类型与维度标签

### 核心类型定义

```
// 转移规则（张量元素）
struct Transition {
  next_state : String
  guard      : Guard?       // 守卫条件
  action     : Action?      // 动作
}

// 维度轴（带语义标签）
struct Axis {
  name   : String           // "state" | "event"
  labels : Array[String]    // ["Idle", "Running", ...]
  index  : Map[String, Int] // 反向查找：标签 → 下标
}

// 核心张量类型
struct FsmTensor {
  axes   : Array[Axis]      // 维度定义（有序）
  shape  : Array[Int]       // 各维度大小
  data   : SparseStorage    // 稀疏存储
}
```

**关键设计**：`Axis` 将纯数字下标包装为语义标签，使算子操作可通过 `tensor["Running", "Stop"]` 进行语义访问，而非 `tensor[1, 3]`。

## 存储层：双格式稀疏存储

### 为什么必须稀疏

转移张量天然稀疏：100 状态 × 50 事件 = 5000 槽位，实际转移通常仅 200 条，稀疏率 > 96%。

### COO 格式（构造期使用）

```
struct CooStorage {
  rows   : Array[Int]       // 状态下标
  cols   : Array[Int]       // 事件下标
  values : Array[Transition]
}
```

- 优点：构造简单，追加元素 O(1)
- 缺点：查找 O(n)，不适合频繁查询

### CSR 格式（代码生成期使用）

```
struct CsrStorage {
  row_ptr  : Array[Int]     // 每行起始位置
  col_idx  : Array[Int]     // 列下标
  values   : Array[Transition]
}
```

- 优点：按行切片 O(1) 定位，适合 `slice(state)` 遍历
- 适用：代码生成器按状态遍历所有转移

### CSC 格式（验证期使用）

```
struct CscStorage {
  col_ptr  : Array[Int]     // 每列起始位置
  row_idx  : Array[Int]     // 行下标
  values   : Array[Transition]
}
```

- 优点：按列切片 O(1) 定位，适合 `slice(event)` 遍历
- 适用：验证器按事件检查哪些状态受影响

### 格式转换

```
FsmTensor.to_csr() : CsrStorage    // COO → CSR
FsmTensor.to_csc() : CscStorage    // COO → CSC
```

**策略**：内部维护 COO 作为"可变格式"，算子执行前按需转换为 CSR/CSC。

## 算子层：14 个算子分阶段执行

### 阶段一：构建与索引（P0）

| 算子 | 输入 | 输出 | 核心逻辑 |
|------|------|------|---------|
| `construct` | `Array[TransitionDef]` | `FsmTensor` | 遍历规则列表，填充 COO 存储 |
| `index` | `String, Array[String]` | `Axis` | 建立标签下标双向映射 |
| `sparse` | `FsmTensor` | `FsmTensor` | COO → CSR/CSC 转换 |

### 阶段二：基础变换（P0-P1）

| 算子 | 输入 | 输出 | 核心逻辑 |
|------|------|------|---------|
| `slice` | `FsmTensor, axis, label` | `SubTensor` | CSR 行指针直接定位，O(1) |
| `contract` | `FsmTensor, axis, op` | `ReducedTensor` | 沿轴聚合（Any/All/Sum） |
| `broadcast` | `FsmTensor, target_shape` | `FsmTensor` | 低维→高维扩展 |
| `transpose` | `FsmTensor, perm` | `FsmTensor` | 交换维度顺序 |
| `reduce` | `FsmTensor, axes, fn` | `Tensor/Scalar` | 多维聚合 |

### 阶段三：组合算子（P2）

| 算子 | 输入 | 输出 | 核心逻辑 |
|------|------|------|---------|
| `product` | `FsmTensor × 2` | `FsmTensor` | 笛卡尔积，状态空间相乘 |
| `compose` | `FsmTensor × 2, bridge` | `FsmTensor` | 串联，前机输出事件→后机输入事件 |
| `overlay` | `parent, child, anchor` | `FsmTensor` | 子机叠加到父机某状态 |

### 阶段四：优化算子（P3）

| 算子 | 输入 | 输出 | 核心逻辑 |
|------|------|------|---------|
| `minimize` | `FsmTensor, equiv_fn` | `FsmTensor` | 等价类划分，合并等价行 |
| `prune` | `FsmTensor, root` | `FsmTensor` | BFS 可达性分析，删除不可达行/列 |
| `fuse` | `FsmTensor, condition` | `FsmTensor` | 合并可串联的转移链 |

## 算子执行管线

```
源码规则列表
       │
       ▼
┌──────────┐
│ construct │  → COO 格式
└────┬─────┘
       ▼
┌──────────┐
│  sparse  │  → CSR + CSC 双格式
└────┬─────┘
       ▼
┌──────────┐
│  prune   │  → 删除不可达（BFS）
└────┬─────┘
       ▼
┌──────────┐
│ minimize │  → 合并等价状态（行比较）
└────┬─────┘
       ▼
┌──────────┐
│  fuse    │  → 融合转移链
└────┬─────┘
       ▼
┌──────────┐
│  slice   │  → 按状态切片，生成 match 分支
└────┬─────┘
       ▼
生成的源代码（张量在此销毁）
```

## 关键设计决策

### 不可变性

所有算子返回**新张量**，不修改输入。

- 理由：编译期优化需要回溯（如 `minimize` 失败需回退），不可变数据天然支持版本化。

### 惰性求值

`product`、`compose` 等昂贵算子支持惰性求值：

```
// 不立即计算笛卡尔积，而是记录"待计算"
lazy_product = product(a, b)  // 返回 LazyTensor
// 仅在 slice/prune 时才真正计算
result = prune(lazy_product, "Idle")
```

- 理由：避免中间张量物化，减少内存峰值。

### 算子融合

借鉴 XLA 思想，将多个算子合并为单次遍历：

```
// 融合前：3 次遍历
pruned = prune(T)
minimized = minimize(pruned)
sliced = slice(minimized, "state", "Running")

// 融合后：1 次遍历
result = fused_pipeline(T, [prune, minimize, slice("Running")])
```

## 与 MoonBit 库的对比

| 维度 | 自建轻量张量层 | MoonBit 库 |
|------|-------------|-----------|
| 维度语义 | 标签化（state/event） | 纯整数 |
| 稀疏存储 | CSR/CSC 双格式 | 无 |
| FSM 算子 | 14 个专用算子 | 仅通用算子 |
| 组合爆炸防护 | 惰性求值 + 融合 | 无 |
| 依赖复杂度 | 零依赖 | 需引入库 |
| 开发成本 | 初期较高 | 开箱即用 |

## 实施路线建议

- **Phase 1（2 周）**：实现核心层 + 存储层 + 4 个 P0 算子（construct, sparse, slice, contract）
- **Phase 2（2 周）**：实现 5 个 P1 算子（broadcast, reduce, transpose, product, index）
- **Phase 3（3 周）**：实现 3 个 P2 组合算子（compose, overlay, fuse）
- **Phase 4（2 周）**：实现 3 个 P3 优化算子（minimize, prune, fuse）+ 算子融合

自建轻量张量层是**值得投入**的——它完全贴合 FSM 语义，无冗余依赖，且编译期优化能力远超通用张量库。初期开发量约 9 周，但换来的是完全可控的编译期 IR 和零运行时开销。
