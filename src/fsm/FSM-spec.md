# 设计总览

```
┌─────────────┐     ┌──────────┐     ┌───────────┐     ┌──────────┐
│  TOML 描述   │────│  Loader  │────│ Validator │────│Generator │
│  (用户编写)   │     │ (解析)    │     │ (校验)     │     │ (产出代码) │
└─────────────┘     └──────────┘     └───────────┘     └──────────┘
                                                           │
                                                    ┌──────┴──────┐
                                                    │  Cache 层    │
                                                    │ (增量判定)    │
                                                    └─────────────┘
```

---

## 一、TOML 描述格式（Schema）

一个 TOML 文件描述一个完整的 FSM，分为三个顶层 section：

```toml
[meta]
name = "turtle_parser"
version = "0.1.0"
prefix = "Turtle"            # 可选：生成代码命名空间前缀；缺省从 name 派生（剔除特殊字符转 PascalCase）
trait_name = "TurtleActions" # 可选：Actions trait 名；缺省 "{prefix}Actions"
default_effect = "Continue"  # 可选：无 action 转移的默认 Effect 变体；缺省 "Continue"

[[events]]
id = "IRIREF"

[[states]]
id = "Start"
kind = "initial"        # initial | final | ""（省略即可）
nestable = false

[[transitions]]
from = "Start"
on = "IRIREF"
goto = "ExpectPredicate"
action = "push"         # push | pop | pop_or_goto | ""（省略即可）
semantic = "set_subject" # 语义动作名，可选
```

**设计要点：**

- 字段名全部小写 + 下划线，与 TOML 惯例一致
- 可选字段直接省略（不用空字符串占位），Loader 侧给默认值
- action 和 semantic 分离——前者是 FSM 机制（push/pop），后者是业务语义（emit_triple）

---

## 二、模块划分

| 模块 | 职责 | 输入 → 输出 |
|------|------|------------|
| **loader** | TOML → 中间结构 | String → FsmSpec |
| **validator** | 静态不变量检查 | FsmSpec → Array[Diag] |
| **codegen** | 中间结构 → 源码字符串 | FsmSpec + Config → String |
| **cache** | 增量判定 | (FsmSpec, Config) → bool |
| **cli** | 命令行入口 | 解析参数，串联上述模块 |

每个模块**单文件、单职责、纯函数优先**，模块间只通过数据结构传递。

---

## 三、核心数据结构

```
FsmSpec
├── meta: Meta
│   ├── name: String
│   └── version: String
├── events: Array[Event]
│   └── Event { id }
├── states: Array[State]
│   └── State { id, kind, nestable, exit_event? }
└── transitions: Array[Transition]
    └── Transition { from, on, goto, action?, semantic? }
```

**关键决策：**

- exit_event 只在 nestable = true 时出现，由 Validator 强制约束
- action 和 semantic 都是可选字段，缺省 = 普通 goto / 无副作用
- 所有 ID 用 String，不做枚举——保持描述文件的开放扩展性

---

## 四、Validator 不变量

| 编号 | 规则 | 严重度 |
|------|------|--------|
| V1 | from / goto 必须引用已定义状态 | Error |
| V2 | on 必须引用已定义事件 | Error |
| V3 | 有且仅有一个 initial 状态 | Error |
| V4 | nestable 状态必须声明 exit_event | Error |
| V5 | exit_event 必须引用已定义事件 | Error |
| V6 | 同一 (from, on) 不允许重复定义 | Warning |

输出统一为 `Diag { rule, severity, message, location? }`，方便后续接入 IDE 诊断。

---

## 五、Codegen 设计

Codegen 内部按**模板片段**组织，每个片段是一个纯函数：

```
codegen(FsmSpec, Config)
├── emit_header()
├── emit_token_enum(events)
├── emit_state_enum(states)
├── emit_step_fn(transitions, config)
│     └── 按 from 分组 → 每个状态一个 match 分支
├── emit_action_dispatch(semantic_actions)
└── emit_debug_helpers()?     // 仅 debug=true 时
```

**debug 开关的实现方式：**

- 不改变 AST 结构，仅在 emit_step_fn 中注入 println! 调用
- 注入点固定三处：转移前、push/pop 时、错误兜底时
- 生成的日志格式统一为 `[FSM] {pos}: {from} --[{event}]--> {to}`

---

## 六、Cache 与增量生成

Cache 文件 (`.fsm_cache.json`)：

```json
{
  "input_hash": "sha256...",
  "config_hash": "sha256...",
  "state_hashes": {
    "Start": "abc123...",
    "ExpectPredicate": "def456..."
  }
}
```

**判定流程：**

1. input_hash 变了？ → 必须重新生成
2. config_hash 变了？ → 必须重新生成（debug 开关切换等）
3. 都没变？ → 跳过，输出 "up to date"

由于 MoonBit 不支持 partial file patch，增量生成的价值在于**跳过写入 + 报告变更范围**，而非真正的 partial write。

---

## 七、CLI 接口

```
fsm-gen <input.toml> [options]

Options:
  -o, --output <path>     输出文件路径（默认: <input_name>_gen.mbt）
  -d, --debug             生成带追踪日志的代码
  --full                  全量生成（默认）
  --incremental           增量模式（对比缓存）
  --cache <path>          缓存文件路径（默认: .fsm_cache.json）
  --check                 仅校验，不生成代码
  --dump-spec             打印解析后的 FsmSpec（调试用）
```

---

## 八、文件结构

```
fsm-gen/
├── moon.pkg.json
├── main.mbt              # CLI 入口
├── loader.mbt            # TOML → FsmSpec
├── validator.mbt         # FsmSpec → Diagnostics
├── codegen.mbt           # FsmSpec → String
├── cache.mbt             # 哈希 + 缓存读写
├── types.mbt             # FsmSpec / Diag / Config 定义
└── test/
    ├── turtle_parser.toml
    └── expected/
        └── turtle_parser_gen.mbt   # 快照测试
```

---

## 九、设计原则总结

| 原则 | 体现 |
|------|------|
| **数据驱动** | TOML 是唯一输入，所有行为由数据决定 |
| **管道清晰** | Load → Validate → Generate，每步可独立测试 |
| **零魔法** | 没有隐式约定，所有规则显式写在 Validator 中 |
| **渐进增强** | 前期 TOML 够用，后期可替换为自举 DSL，中间结构不变 |
| **可观测** | debug 开关 + --dump-spec + --check，每一步都能检查 |

---

> 这个大纲可以直接作为开发蓝图。
