# gen_trig 宪法（const）

版本：v1.0.0（2026-09-12 自 `todo.md` §1 拆出）

**效力与时效**（`bangto/world/const.md` §5.1/§5.2）：本卷是**红线条款**——**冻结，只减不增**；
改一条必须由用户裁决并以 `adr.md` 条目留痕；**只对 `src/ttl/src/gen_trig/` 有效**。
术语以 `bangto/world/vocabulary.spec.md`（v2.0）为准：契约成员 = `Actions` / `EffectHandler` / `Supervisor`
（`LoopPolicy` 为废弃别名；本包代码现名 `TrigLoopPolicy`，回灌归 T13）。

---

## 1 生成契约三条线（必须）

1. **决策在表**：`step` 只产出 Effect 意图；发射意图 `EmitQuad(ResetScope)` 携带收拾粒度，
   "发完怎么收拾"写在转移行上；`Sequence` 只是意图的串列打包。**禁止**在 loop 里判断业务语义。
2. **机械在模板**：主循环 = 生成器固定模板（`engine.mbt` 的 `next`，所有 FSM 同形）——
   入口/终止 → step 步进 → Effect 分发 → 错误降级，四节点零领域逻辑；切片组装与 `ctx.reset(scope)`
   都发生在 loop。**禁止**引擎或表触碰槽位切片。
3. **领域知识在契约成员**：三成员各守一方——`TrigActions`（槽位写入，热路径）、
   `TrigEffectHandler`（Effect 执行，冷路径/下游输出）、`TrigSupervisor`（控制流钩子：
   `begin_record` / `recover` / `finish_at_end` / `on_business_failed`；代码现名 `TrigLoopPolicy`）。

## 2 口径铁律（必须 / 禁止）

- **action 统一 Span 口径**：所有 action 参数一律 `Span`（全词含定界符）；`enter_graph` 的 label 为
  `Span?`（`None` = 默认图）；无 payload 的事件固定绑 `(0,0)`；错误兜底位置由 loop 用 `lexer.pos()` 补。
- **EOF 是数据边界，不进表**：由 loop 判脏收尾（`finish_at_end`）。词法器协议：结尾
  `Some(EOF(pos))`，`None` 仅保留异常分支。
- **未列举组合 → `UnexpectedEvent` 兜底**：错误不经 action/effect 表达；loop 走 `Supervisor::recover`
  口径（登记 → 消费到 Dot/Rbrace → state 归位）。
- **Effect 面向演进只加变体**：`Continue` / `EmitQuad` / `Done`（继承 gen_nquads 三件套）+
  trig 追加 `EnterGraph` / `ExitGraph` / `Sequence` / `PopBnp` / `ListStep` / `OpenSlot`；
  **禁止**修改既有变体签名。
- **图块区域与顶层彻底分离**：`TrigGraphExpect*` 无 `Lbrace` 出边 ⇒ 嵌套图块不可达，**表即合法性裁决者**；
  TriG 无四元组语法，`graph` 槽位只由 `enter_graph` 填。
- **全文件 TOML 可表达**：枚举 / ctx 槽位 / action 面 / step 表四段声明齐备，**禁止**表外业务逻辑
  （词内尾点合成 Dot、token 分类属适配层/loop 模板的机械）。
- **`ResetScope` 粒度正交**：每变体显式列出"清谁"，未列字段一律保留；粒度**不回头写 state**
  （state 由转移表 `to=` 负责）。四档：`Object` / `PredObj` / `SPO` / `All`。
- **词内尾点裁决在引擎归位点**：词法无脑扫把语句点吞进词尾时，`trim_trailing_dot` 剥离 +
  loop 合成 `Dot` 回灌转移表（决策仍在表，机械在此）。
- **TT 壳拆解只在组装层**：`<< s p o >>` 拆壳归 `parser_slice`（`triple_term_inner_terms`），
  **禁止**把结构判断提前回词法/归位层。

## 3 数据与生命周期（必须）

- **Span / View / Arena 双源不变量**：`data` 只读原串；`arena` 只追加（`push_view` / `push_byte` /
  `blit_to` 自动扩容）；物化产物 span **可能指向 arena**（如 `^^PrefName` 展开串），
  消费方不得假设单源。
- **`prefixes` 生命周期由调用方保证**，解析后只读（`TrigMaterializer::new` 文档注明）。
- **单遍口径**：轻嗅探 + 按需深验——四门 `gate_iri` / `gate_bnode` / `gate_tt` / `gate_literal`
  融合在物化构词点；`deep_validate` 由 `materialize_all(deep_validate)` 设定；
  `lenient=true` 只跳**轻验**，深验仍在。
- **命名纪律**（`AGENTS.md`）：规范术语保规范拼写（`BNode`）；空前缀 IRI = `DefaultPrefixIRI`。

## 4 action / effect 边界（必须）

- **action** = 修改解析器内部状态（状态转移、槽位写、栈操作）：纯内部、确定性、可重放。
- **effect** = 跨边界可观测，仅两族：`err` 向上游（解析失败）、`emit/on_*` 向下游（输出结果）。
- 压栈/弹栈、`reset`、fresh bnode **全是 action**；发射与报错才是 effect。
  **禁止**在 action 里发射或报错；**禁止**在 effect 里改槽位。

## 5 生成物与再生纪律（禁止）

- `trig.mbt` 是**生成物**（DO NOT EDIT）：**禁止手编**；改它 = 改生成面 → 再生。
- 再生的门：IR 侧 `src/rdf/trig_domain_toml_gen.mbt`「双文件编译 ≡ `fsm_out/trig_fsm.toml`」；
  **产物侧黄金门尚未建立**（T10 立）——门建立前，**禁止**在无对拍的情况下改生成面。
- 生成面改动是**跨仓原子变更**：`src/rdf`（domain/IR）→ `fsm_out/trig_fsm.toml` → `src/fsm`（codegen）
  → `trig.mbt` → 子仓测试，**必须同笔**。
