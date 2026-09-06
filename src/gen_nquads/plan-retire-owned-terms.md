# 方案：owned term 家族退役（NamedNode + Literal → NamedNodeRef + LiteralRef 单轨）

2026-09-06 定案。审计结论：owned/borrowed 双轨是 Rust 移植期遗留，生产管线
零消费（热路径货币 = ArrayView[Byte] span；vocab 76 常量全是静态 NamedNodeRef）。
保留借用半边作 term 身份类型，owned 半边整体退役。

## 触点普查（2026-09-06 实测）

- owned `NamedNode` 生产调用 = 0（仅 literal_wbtest 自销）
- owned `Literal` 生产构造 = 0（`TypedLiteral`/`LiteralContent::`/`destruct`
  /`value()` 全部只在 literal.mbt 本体 + literal_wbtest）
- gen_n3 波及 = **零**：全包仅 materialize_n3.mbt:501
  `push_vocab(@nquads.rdf_boolean)`（NamedNodeRef 常量，不受影响）；gen_trig 零
- `append_escaped_str` / `String::lpad` 仅服务 LiteralRef::to_string，保留
- 机器料 gen_check 两目录：无引用

## 步骤 0：基线快照

    cd /home/thy/moonttl/src/ttl
    moon test src/gen_nquads   # 124/124
    moon test src/gen_n3       # 104/104
    moon test src/gen_trig     # 80/80
    cd /home/thy/moonttl && moon test src/rdf   # 16/16

## 步骤 1：literal.mbt — NamedNode 面退役

删（连带 derive(Default) 一并消亡）：
- [ ] `pub(all) struct NamedNode`（literal.mbt:39）+ `impl Show for NamedNode`（:45）
- [ ] `NamedNode::as_ref`（:59）
- [ ] `NamedNodeRef::into_owned`（:56）

强制重命名（associated fn 不能挂在已删类型上）：
- [ ] `NamedNode::new_unchecked` → `NamedNodeRef::new_unchecked`（语义不变，
      本来就返回 NamedNodeRef——旧名是误导源）

## 步骤 2：literal.mbt — Literal 面退役（构造器/访问器迁 LiteralRef::*）

迁移（改宿主 + 改视图签名，逻辑逐字节保留——这些是 RDF 1.1 语义钉）：

| owned（删） | 迁到 LiteralRef:: |
|---|---|
| `struct Literal` + `LiteralContent`（:24/:103）+ `Show for Literal`（:67） | 删壳；LiteralRef/LiteralRefContent/Show 已在（:246/:250/:334） |
| `new_simple_literal(value: String)`（:116） | 同名，value: StringView |
| `new_language_tagged_literal`（:122，验证 + to_lower） | 同名，value: StringView |
| `new_language_tagged_literal_unchecked`（:141） | 同名，value: StringView |
| `new_directional_language_tagged_literal(_unchecked)`（:150/:169） | 同名，value: StringView |
| `value() -> String`（:183） | 删（LiteralRef::as_value 已在，返回 StringView） |
| `language() -> String?`（:195） | 迁，返回 StringView?（Ref variant 字段是 StringView） |
| `direction() -> BaseDirection?`（:206） | 迁，逐字节同构 |
| `datatype()`（:216） | 删（LiteralRef::datatype 已在 :295） |
| `new_simple_literal_unchecked`（:274） | 删或迁（wbtest 未用则删） |
| `new_typed_literal_unchecked`（:280，注意返回本就是 LiteralRef） | 改宿主 LiteralRef::*（rdf_string 折叠 String variant 行为保留） |
| `destruct()`（:227） | 删 |
| `LiteralRef::into_owned`（:307） | 删 |

## 步骤 3（推荐同役）：LiteralRefContent 字段型归一

现状混装（:251-258）：`String(StringView)` / `LanguageTaggedString(value~ : String,
language~ : StringView)` / `Directional(value~ : StringView, ..)` /
`TypedLiteral(value~ : String, ..)`。两处 `String` 归一为 `StringView`，
与迁移后的构造器签名对齐，零拷贝口径贯穿。Show/as_value 无需改动。

## 步骤 4：vocab.mbt 机械重命名

    # 76 处，sed 后抽查 + 编译验证
    sed -i 's/NamedNode::new_unchecked(/NamedNodeRef::new_unchecked(/g' src/ttl/src/gen_nquads/vocab.mbt

## 步骤 5：literal_wbtest.mbt 重写（403 行，4 类机械改）

1. 9× `NamedNode::new_unchecked(...)` → `NamedNodeRef::new_unchecked(...)`
   （参数若是 `x.to_string()` 直接改 view——GC 下 view 保活母串，无悬垂）
2. `Literal::X(...)` → `LiteralRef::X(...)`（构造器按步骤 2 迁移表）
3. 4× `lit.into_owned().value()` → `lit.as_value()`（:28/:39/:48/:164）
4. `lit.datatype()` 断言不动（Ref 版同签名返回 NamedNodeRef）

**坑**：`assert_eq(lit.as_value(), "true")` 类型不齐——StringView ≠ String。
测试断言一律 `lit.as_value().to_string() == "true"` 或对期望值建 view 变量
（测试内 to_owned/to_string 不计性能账）。

## 步骤 6：验收门

    cd /home/thy/moonttl/src/ttl
    moon check src/gen_nquads && moon test src/gen_nquads   # 124/124 不破
    moon test src/gen_n3    # 104/104（gen_n3 零波及的实证）
    moon test src/gen_trig  # 80/80
    cd /home/thy/moonttl && moon test src/rdf               # 16/16
    # 残留清零（应无输出）：
    grep -rn "NamedNode\b" src/ttl/src --include="*.mbt" | grep -v NamedNodeRef | grep -v wbtest
    grep -rn "LiteralContent\|into_owned\|Literal::destruct" src/ttl/src --include="*.mbt" | grep -v gen_check

## 顺序与回退

1 → 4 → 2 → 3 → 5 → 6（NamedNode 先退役解锁 vocab sed；每步编译可断，
失败即回退单文件）。全程不触 gen_n3 / gen_trig / src/rdf。
