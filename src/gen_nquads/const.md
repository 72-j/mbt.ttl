# gen_nquads 宪法 const（2026-09-03 整理；FSM 生成链路第一样板，gen_trig 为第二样板）

## 1 三条线（生成契约总纲）

- **决策在表**：step 只产出 Effect 意图；`EmitQuad(ResetScope)` 变体携参带上收拾粒度，
  "发完怎么收拾"写在转移行上。TOML 后续可用显式行收紧兜底面。
- **机械在模板**：主循环 = 生成器固定模板（engine.mbt 的 `next`：
  入口/终止 → step 步进 → Effect 分发 → 错误降级，四节点零领域逻辑）。
  切片组装（snapshot → QuadSpan）与 `ctx.reset(scope)` 都在 loop 发生，
  引擎绝不触碰槽位切片。
- **业务在 trait**：三业务面各守一方——
  `NQuadsActions`（槽位写入，热路径，高频）、
  `NQuadsEffectHandler`（Effect 执行，冷路径，下游输出）、
  `NQuadsLoopPolicy`（begin_record / recover / finish_at_end / on_business_failed，
  恢复与收尾策略）。

## 2 分层文件职责

| 文件 | 层 | 职责 |
|---|---|---|
| nquads.mbt | 生成契约（src/fsm 产物，DO NOT EDIT） | Event / State / ResetScope / Effect / ActionError / Context / PendingQuad / LoopPolicy trait / Actions trait / `step()` / EffectHandler trait |
| engine.mbt | 机械层 | loop 模板 + `LexerSource` trait（next/pos/byte_at）+ 词内尾点裁决 + LoopPolicy 的 Engine 实现 |
| parser_slice.mbt | 加工层 | 组装（PendingQuad → QuadSpan）+ 验证调度 + 行号统计（engine 不持 data） |
| validate_helper.mbt | 验证层 | 语法对错全部在此裁决（span → view 切分后逐词项校验） |
| actions.mbt | 业务热路径 | Hooks 单载体双 trait（NQuadsActions + NQuadsEffectHandler），引擎只持一个实例 |
| materialize_quad.mbt | 物化层 | QuadSpan → QuadEmit |
| serialize_nquads.mbt | 序列化层 | 只吃物化模型 QuadEmit，字节保真回写 |

## 3 口径铁律

- **action 只写槽位返回 Continue**：永不重置 ctx、拿不到数据视图；
  切 span 组装、粒度重置都是引擎 loop 的独占机械。
- **action 统一 Span 口径**：所有 action 参数一律 Span，全词含定界符；
  无 payload 的事件固定绑 `(0,0)`，错误兜底位置由 loop 用 `lexer.pos()` 补。
- **EOF 是数据边界不进表**：LexerSource 在词法源层吞掉 EOF 变体回 None，
  loop 判脏收尾（finish_at_end：state 未归位或任一槽位残留 → 不完整记录）。
  词法器协议：结尾 `Some(EOF(pos))`，None 仅保留异常分支。
- **未列举组合 → UnexpectedEvent 兜底**：错误不经 action/effect 表达；
  loop 走 LoopPolicy 的 `recover`：登记（record_error）→ consume_to_dot
  （消费整行 + 全清）→ state 归位。
- **ResetScope 粒度正交**：每变体显式列出"清谁"，未列字段一律保留（防错误重置）；
  粒度不回头写 state——state 由转移表 to= 负责，两者正交。
  现有四档：Object / PredObj / SPO（TriG 图块口径预埋）/ All（N-Quads 行口径）。
- **Effect 三件套只加变体**：Continue / EmitQuad / Done；
  表中无转移产出 Done（Done 留给 loop 终止分支）；trig 追加
  EnterGraph/ExitGraph/Sequence 不改既有签名。
- **词内尾点裁决（引擎归位点）**：词法无脑扫把语句点吞进词尾时，
  `trim_trailing_dot` 剥离 + loop 合成 Dot 事件回灌转移表（决策仍在表，机械在此）。

## 4 验证分层（W3C 89/89 实证）

- 词法器保持**无脑扫（加宽口径）**：语法对错全部在 validate_helper 裁决，
  验证在组装之后——span → view 切分完成后逐词项在 view 上校验。
- 引擎只负责**尾点归位**与结构转移；错误 span 用全局偏移定位，
  行号由持 data 的 SliceParser 统计（line_before）。
- 错误四变体：StructSyntaxErr（带行号）/ SyntaxErr / ValidationErr / IriErr。

## 5 flavor 差异沉外层

- **全文件 TOML 可表达（OML spec）**：枚举/事件/状态/转移表全在 spec 段内，
  无表外逻辑（尾点合成 Dot、token 分类都在适配层/loop 模板）。
- `;`/`,` 转移边为 TriG 复用预埋（表共享），nquads 语义下由组装层兜。
- triple/quad 开关放序列化层（format 旋钮）；.nt 72/72 实证口径无损。
- 双词法器同 Token 字母表（Lexermoon 纯 MoonBit / Lexerc C FFI，Token 与
  span 口径完全对齐），`token_to_event` 映射共用、零补偿透传；
  词法语义以 C 版（lexerc_ffi.c）为标准对齐源。
- **单泛型轴**：泛型只落在词法器 L 上（`LexerSource`），
  Hooks 单载体双 trait 避免第二泛型轴；C 侧复用同一 loop（engine_c.mbt 薄适配）。
