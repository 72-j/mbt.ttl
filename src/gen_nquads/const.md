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

## X. 档位口径表（B1，2026-09-25 立；B1 只量口径、**不动 API**）

1. **⚠ `lenient ≠ 轻验档`（跨方言同名不同义，最容易踩的一坑）**：
   - **nquads 侧**：`SliceParser::new(..., lenient=true)` **就是轻验档**——它直接跳四面深验
     （`validate_iri` / `validate_bnode` / `validate_literal` / `validate_triple_term`，见 `validate_helper.mbt`）。
   - **n3v2 / trig 侧**：`lenient` **只跳轻验**，**深验仍在**；轻验档还须 `deep_validate=false`
     （物化层四门 `gate_iri`/`gate_bnode`/`gate_tt`/`gate_literal` 总开关，默认 `true`；见 `gen_trig/const.md` §3 单遍口径）。
   ⇒ **口径表读到这，先把两个名字分家**：`lenient` = 轻验开关；"档位" = 轻验 + 深验 **两把开关的合称**。
2. **实测判据（交错 A/B，沿用 `perf-review.txt` 读数纪律）**：A=deep / B=light **交替跑 ≥3 轮**，
   **带不交叠才下结论**；带交叠 = 机噪 > 效应 ⇒ **记"无结论"**（禁硬编差距）。
   **B1 实测（本机 Ryzen 7 5700G · 10k · `--target native --release` · `--validate=light|deep`）**：
   deep **5.948647 / 5.680446 / 5.603535 ms** vs light **4.968277 / 4.673587 / 5.170636 ms**
   ⇒ 带**不交叠**（deep 最低 5.60 > light 最高 5.17）⇒ **轻验档 −12.5%（≈1.14×）**。
   ⚠ **与初估差很大**（原按"验证段占 84%"估 4–5×）：该语料**全合法**，深验走**接受快路**，故省幅有限；
   **n3v2/trig 侧（四门融合在物化构词点）的省幅另量**（B2 需同法在 n3v2/trig 加档位开关再测）。
3. **红线（B2 前置，须按档、显式、入册）**：轻验档下深验面**不可达** ⇒ 可达账/G11/覆盖率棘轮必须
   **按档声明不可达**（**不是把数字藏起来**）。**B1 预研清单**（B2 按档声明用）：
   nquads = `validate_helper.mbt` 的 `validate_iri:192` / `validate_iri_body:245` / `validate_bnode:338` /
   `validate_lang_suffix:462` / `validate_escapes_unicode:559` / `validate_literal:652` / `validate_triple_term:907`
   ＋ 各处 `if !self.lenient` 臂（`:66` / `:121` 等）；n3v2/trig = `gate_iri:1077` / `gate_bnode:1092` /
   `gate_tt:1126` / `gate_literal:1141` ＋组装层 `validate_term` / `validate_prefname`。
4. **B1 边界（别误读）**：bench 开关**只改 bench 自己的调用**（`src/bench/nquads-benchmark/main.mbt`
   `--validate=light|deep`，缺省 deep）；**套件/测试调用面一律未动** ⇒ **覆盖率/可达账在 B1 不会下降**；
   下降只会在 B2 把 Light 作为正式档跑套件时出现——那时按第 3 条声明。

### X.1 B2 分步（2026-09-25 开工）：公开面档位 → 按档不可达 → 分档数字

**步序（每步自带门，不并笔）**：

1. **步① 公开面档位参数**：对外收成一个档位入口（`Light` / `Deep`，**默认 Deep**），内部映射现有两开关；
   **`lenient` 保留为内部形参语义**（口径表第 1 条），避免"同名不同义"外泄。改 `.mbti` ⇒ **属 API 变更**，须同笔 CHANGELOG。
2. **步② 按档不可达声明**：把口径表第 3 条的清单**入可达账**（`[档外不可达]` 类），并让 G11/覆盖率棘轮按档扣除；
   **红线**：显式 + 按档 + 入册，**禁**"把数字藏起来"。
3. **步③ 分档数字 + 冒烟门**：README/CHANGELOG 性能分档（现对外单值 ≈1.35× 须标注基准档 = Deep）；
   新增 **Light 档冒烟**（合法语料两档 quad 数等价 ⇒ 轻验不误拒）。

**落点勘定（开工第一件，须先核完再动手）**：

- **手维护（可手改）实证**：`src/gen_trig/quicktest/`、`src/gen_nquads/quicktest/` 两处有 `.hand-maintained` 标记
  （语义：物化/再生**不得覆盖**；缺标记但有实例 ⇒ 生成通道 fail）。
- **再生件（禁手改）**：清单**未在子仓 `ci/*.sh` 内**（该豁免名单在主仓 CI，§Q.3-F1 口径）⇒ **步①/步② 动手前必须先取其清单核对**，
  否则会出现"手改被再生覆盖"的假绿（役6 清残余一役已踩过同类：生成物内锚只能走模板/改符号名）。
- **bench 开关回卷记录**：B1 的 `--validate=light|deep` 原型因触发 1 例测试红 + 面三分母 +1 而**回卷**；
  步③ 落开关时须**同笔重生 `coverage-review.txt`**（复核表口径：改代码必须同笔重生成）+ 定位那 1 例红（有牙提示：
  该例对 bench 输出/调用面敏感，加开关时同步改它）。
