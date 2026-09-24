// ===== 共享装配层件（T17 / C-T8 双包重复治理）=====
// 口径：**零方言语义纯函数**（入参出参只含 Byte / ArrayView[Byte] / Bytes / String / Int / Bool / Span 族）。
// 来源：逐字摘取；去注释后两包代码**逐字一致**（唯一分歧 `deep_check_literal` 的 `rdf12` 门控已取**严者**=trig 版，
//       见两包 `spec.md` C-T8 裁定表；注释取 trig 侧（方言中立化））。
// 引入方式：方言包 `using @gs { fn <name> }` ⇒ 本地调用点**零改写**。

///|
/// 共享词表再导出（包级一份；`@nquads` 持 `Span` / `ParseError` / `Token` —— 与两包 `types.mbt` 同口径）。
/// 注：MoonBit 的 `using` 属**包级**作用域 ⇒ 本包只在此处声明一次（其余分文件重复声明会撞"declared twice"）。
using @nquads {type ParseError, type Span}

///|
pub fn slice_span(data : ArrayView[Byte], span : Span) -> ArrayView[Byte] {
  let (off, len) = span
  if off < 0 || len < 0 || off + len > data.length() {
    return data[0:0]
  }
  data[off:off + len]
}
