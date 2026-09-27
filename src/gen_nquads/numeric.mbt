// ===== 词形识别共享面（单一实现；裁定 ADR-NQ-011）=====
// 数值/布尔识别原在 gen_n3v2 与 gen_trig 各持一份（adapter 字节孪生 +
// 校验内联 + 物化 bool_at，六处易漂移——n3v2 ADR-18 `^` 门事故同族欠账）。
// 本包是两包公共依赖，判定件独此一份：
//   is_numeric_span  —— 词法整段扫描口径复核（adapter 分类 / 校验放行 /
//                       物化展开三面同源）；
//   is_boolean_word  —— 小写精确布尔词（true/false），识别面唯一权威。
// 展开件（expand_number/expand_boolean）留驻各物化层：arena 发射是包内
// 职责，识别才是共享面。

///|
/// 数值形态复核（词法整段扫描口径：[+-]?([0-9]+('.'[0-9]*)? | '.'[0-9]+)([eE][+-]?[0-9]+)?）：
/// 首字节 数字/+/−/.，至少一个数字，其余仅 . e E + -
pub fn is_numeric_span(data : ArrayView[Byte], off : Int, len : Int) -> Bool {
  // A 笔（2026-09-27）：**零长防御**——`len == 0` 时原实现 `data[off]` 越界 panic（未定义行为）。
  if len == 0 {
    return false
  }
  // B 笔（2026-09-27）：**结构校验**——按本函数头注自述口径
  //   `[+-]?([0-9]+('.'[0-9]*)? | '.'[0-9]+)([eE][+-]?[0-9]+)?`
  // 逐段判定（旧实现只做"首字节 + 字符集 + 至少一数字"，故 `1e`/`1e+`/`++1`/`--1`/`1.2.3` 被误收）。
  let digit = fn(c : Byte) -> Bool { c >= b'0' && c <= b'9' }
  let mut i = 0
  if data[off] == b'+' || data[off] == b'-' {
    i = 1
  }
  let mut int_digits = false
  while i < len && digit(data[off + i]) {
    int_digits = true
    i += 1
  }
  let mut frac_digits = false
  if i < len && data[off + i] == b'.' {
    i += 1
    while i < len && digit(data[off + i]) {
      frac_digits = true
      i += 1
    }
  }
  // 整数位与小数位至少一者有数字（覆盖 `1.` / `.5` / `1`；排除 `.` / `+` / `1.2.3` 结构残缺）
  if !int_digits && !frac_digits {
    return false
  }
  if i < len && (data[off + i] == b'e' || data[off + i] == b'E') {
    i += 1
    if i < len && (data[off + i] == b'+' || data[off + i] == b'-') {
      i += 1
    }
    let mut exp_digits = false
    while i < len && digit(data[off + i]) {
      exp_digits = true
      i += 1
    }
    if !exp_digits {
      return false
    }
  }
  i == len
}

///|
/// 布尔词判定（小写精确：true/false；物化层展开 xsd:boolean，词法/校验/
/// 物化三面同源——原 n3v2 eq_lower 内联、trig 字节内联、双 bool_at 收编）
pub fn is_boolean_word(data : ArrayView[Byte], off : Int, len : Int) -> Bool {
  if len == 4 {
    data[off] == b't' &&
    data[off + 1] == b'r' &&
    data[off + 2] == b'u' &&
    data[off + 3] == b'e'
  } else if len == 5 {
    data[off] == b'f' &&
    data[off + 1] == b'a' &&
    data[off + 2] == b'l' &&
    data[off + 3] == b's' &&
    data[off + 4] == b'e'
  } else {
    false
  }
}
