step 返回:  Result[(State, Context, Effect), Error]
                    │        │       │
                    │        │       └─ 副作用意图 + 控制流（纯数据）
                    │        └───────── 新上下文（action 更新）
                    └────────────────── 默认下一状态（来自 transition table 的 goto）

Effect 覆盖:  Effect::Goto(State)  优先级 >  step 返回的默认 State

Loop 职责:    1. 根据 Goto/默认 决定下一状态
              2. 分发 Effect（写三元组、跳行、终止）