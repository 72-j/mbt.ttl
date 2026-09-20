// ===== 共享装配层件（T17 / C-T8 双包重复治理，2026-09-20 立）=====
// 口径：**零方言语义纯函数**（入参出参只含 Byte / ArrayView[Byte] / Bytes / String / Int / Bool / Span 族）。
// 来源：逐字摘取；去注释后两包代码**逐字一致**（唯一分歧 `deep_check_literal` 的 `rdf12` 门控已取**严者**=trig 版，
//       见两包 `spec.md` C-T8 裁定表；注释取 trig 侧（方言中立化））。
// 引入方式：方言包 `using @gs { fn <name> }` ⇒ 本地调用点**零改写**。

///|
pub fn eq_ignore_case(data : ArrayView[Byte], off : Int, kw : Bytes) -> Bool {
  let n = kw.length()
  for i in 0..<n {
    let c = data[off + i]
    let k = kw[i]
    // 归一大小写后比对
    let c1 = if c >= b'A' && c <= b'Z' { c + 32 } else { c }
    let k1 = if k >= b'A' && k <= b'Z' { k + 32 } else { k }
    if c1 != k1 {
      return false
    }
  }
  true
}

///|
pub fn eq_lower(data : ArrayView[Byte], off : Int, kw : Bytes) -> Bool {
  for i in 0..<kw.length() {
    if data[off + i] != kw[i] {
      return false
    }
  }
  true
}

///|
pub fn at_style_kw(data : ArrayView[Byte], off : Int) -> Bool {
  off > 0 && data[off - 1] == b'@'
}
