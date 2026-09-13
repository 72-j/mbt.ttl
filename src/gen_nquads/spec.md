# gen_nquads 架构规格（spec）

版本：v1.0.0
分工：const.md = 宪法（生成契约）；本文件 = 结构事实与已验证口径；todo.md = 记录。
首版动机：2026-09-05 词法事件槽位形状验证（三 term 事件是否拆 (span, span)）。

---

## 1. 数据面（已验证）

- QuadSpan 五槽（type.mbt）：subj / pred / obj 均单 `ArrayView[Byte]`，graph 可空，
  subj_type / obj_type 标词项类别——**字节保真单 span 槽**，无内部细分槽。
- QuadEmit（@nquads 物化模型）同口径：view 或指原 data（零拷贝）。
- literal.mbt 的 `LiteralContent::TypedLiteral(value, datatype)` 是规范化构造器，
  吃**已分离**的两段——它不重扫原始 span。

## 2. 词法事件槽位口径（2026-09-05 验证定案）

三个 term 事件 `NQuadsBlankNode / NQuadsLiteral / NQuadsPrefName` 均为**单 span**，
不拆 (span, span)。词法无脑扫出的词项内部分界线，由 validate 单点裁决与产出，
不进事件/槽位形状：

| 事件 | 裁决 | 证据 |
|---|---|---|
| NQuadsPrefName | 不拆：N-Quads 无 prefixed name，全包**零表行**（仅 nquads.mbt:13 枚举声明），永远 UnexpectedEvent | grep 全包唯一命中 |
| NQuadsBlankNode | 不拆：`_:` 定界固定 off+2 常量算术，无模糊性 | materialize / serialize 直写 label |
| NQuadsLiteral | 不拆（有真分界，但归属 validate 单点）：闭引号 → `@lang` / `^^<dt>` 分界已由 `validate_literal`（validate_helper.mbt）单遍扫出（scan_string_body → close），裁决后即弃——**门卫不出槽位** | materialize_quad 零 lang/^^ 处理；调用点仅主门与嵌套内层两处 |

- 拆事件的代价面：`span_of_event` → normalize 归位 → 生成表 payload → QuadSpan →
  QuadEmit 五道签名穿透，违反「词法无脑扫 / 引擎尾点归位 / 组装后 validate_helper」
  分层（const.md §4）——结构判断不得提前回词法/归位层。
- **与 gen_n3 的对照**（为何 n3 拆了、nquads 不拆）：n3 的 `N3Literal(span, lang)`
  双载荷是 Lexermoon 吞边界 + langtag 恰覆盖子标签的物化口径逼出来的（n3 物化层要发
  langString，需要 lang 精确 span）；nquads 物化层字节保真直写，无此需求。

## 3. 演进位（最小改动通道）

若将来物化/规范化需要两段内容（lang/dt 独立 span、canonicalization）：
**门卫升级为 splitter**——`validate_literal -> Result[Unit, ParseError]`
改富裁决 `Result[LiteralSplit, ParseError]`（在已算出 close 的位置顺手产出
value / suffix span），下游从门卫结果取两段。
词法事件形状与三层宪法边界一寸不动。
