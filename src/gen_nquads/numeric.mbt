// ===== 词形识别共享面（役29 R-15 单一实现）=====
// 数值/布尔识别原在 gen_n3v2 与 gen_trig 各持一份（adapter 字节孪生 +
// 校验内联 + 物化 bool_at，六处易漂移——ADR-18 `^` 门事故同族欠账）。
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
  let c0 = data[off]
  if !(c0 == b'+' || c0 == b'-' || c0 == b'.' || (c0 >= b'0' && c0 <= b'9')) {
    return false
  }
  let mut has_digit = false
  for i in 0..<len {
    let c = data[off + i]
    if c >= b'0' && c <= b'9' {
      has_digit = true
    } else if !(c == b'.' || c == b'e' || c == b'E' || c == b'+' || c == b'-') {
      return false
    }
  }
  has_digit
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
