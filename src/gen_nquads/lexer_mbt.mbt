// ===== 纯 MoonBit 词法器（直产 NQuadsEvent）=====
// 出词点直接构造事件枚举：消 Token→Event 双箱往返（每 token −1 分配）。
// span 口径：**全词含定界符**，与 C 版 Token 逐字对齐（双词法器同口径钉看护）；
// Token 字母表为 Lexerc FFI 专用（token.mbt/lexerc.mbt）。
// 词法语义（层 1）——以 C 版（lexerc_ffi.c）为标准对齐源：
//   - 字面量分三引号/普通两种；含转义；后缀 ^^datatype / @lang 并入 Literal
//   - _:name → BlankNode；字母/:起头 → PrefName；数字（可带±符号）→ Unknown
//   - 未闭合 IRI/字面量宽容出词（不再 None 硬错）；其余单字符一律 Unknown(1)
//   - PrefName 无脑扫：名字内 : / 内部 '.' / \X 转义对 / %HH / 多字节一律并入，
//     尾部裸 '.' 回退；语法对错归验证层（词法加宽口径，双引擎同机械）
// EOF 协议：结尾返回 Some(NQuadsEOF)（pos 冻结，由 current_pos() 钉）；
// None 仅保留给异常分支，正常流不会出现。
// **四类词法决策的起因与完整口径**（加宽口径 / 单 `^` 门 / 右括族停扫 / 数值·布尔判定件）
// 见 **ADR-NQ-011**；词法段性能沿革见 `perf-review.txt`。
// Unknown/结构事件 span 不在生成契约（NQuadsUnknown 为常量构造子）——出词点
// 把 span 写入 last_unknown 单槽旁路（消费方 Unknown 事件后即读；trig/n3v2
// 适配层结构分类与 ANON 校验依赖此面）。
// 热路径纪律：view/len 以局部缓存参与每字节循环（debug 构建不内联字段加载），
// 逐字节判别内联比较，不做任何函数调用。

///|
pub(all) struct Lexermoon {
  view : ArrayView[Byte]
  mut pos : Int
  mut len : Int
  mut last_unknown : Span // 单槽旁路：Unknown 出词点 span（P2 刀 a) 生成契约无 span 载荷）
}

///|
pub fn Lexermoon::new(view : ArrayView[Byte]) -> Lexermoon {
  Lexermoon::{ view, pos: 0, len: view.length(), last_unknown: (0, 0), }
}

///|
/// Unknown span 单槽旁路：NQuadsUnknown 为常量构造子（生成契约无
/// span 载荷），出词点把 span 写入 last_unknown 槽；消费方（trig/n3v2 适配层
/// 分类结构字符、ANON 吞槽校验）收到 Unknown 事件后**立即**读取本槽——两次
/// next() 之间读才不失真（后一次 Unknown 会覆盖）。
pub fn Lexermoon::last_unknown_span(self : Lexermoon) -> Span {
  self.last_unknown
}

///|
/// 获取当前位置（用于错误报告）
pub fn Lexermoon::current_pos(self : Lexermoon) -> Int {
  self.pos
}

///|
/// 字节类表：把 `is_name_char` 的**逐字节 5 次比较**收成 **1 次查表**
/// （`FixedArray` + `unsafe_get`，热循环零边界检查；与 `validate_helper.mbt` 的 `iri_cls` 同法）。
/// 位义：`1` = alpha；`2` = 非字母的 name 追加（`0-9` / `_` / `-` / `.`）；`4` = hex 位。
/// ⇒ `is_name_char = (cls & 3) != 0`、`is_alpha = (cls & 1) != 0`、`is_hex = (cls & 4) != 0`
/// （**逐字节同义**：本表只是同一判据的查表实现，不改任何接受面）。
let lexer_cls : FixedArray[Int] = {
  let t : FixedArray[Int] = FixedArray::make(256, 0)
  for i in 0..<256 {
    let c = i.to_byte()
    let is_alpha = (c >= b'a' && c <= b'z') || (c >= b'A' && c <= b'Z')
    let is_num = (c >= b'0' && c <= b'9') || c == b'_' || c == b'-' || c == b'.'
    let is_hex = (c >= b'0' && c <= b'9') ||
      (c >= b'a' && c <= b'f') ||
      (c >= b'A' && c <= b'F')
    let mut cls = 0
    if is_alpha {
      cls = cls | 1
    }
    if is_num {
      cls = cls | 2
    }
    if is_hex {
      cls = cls | 4
    }
    // 位 8 = IRI 扫描终止符（`>` 收口 / 空白视为未闭合——IRI 热循环的同一判据）
    if c == b'>' || c == b' ' || c == b'\t' || c == b'\r' || c == b'\n' {
      cls = cls | 8
    }
    t[i] = cls
  }
  t
}

///|
fn is_alpha(c : Byte) -> Bool {
  (lexer_cls.unsafe_get(c.to_int()) & 1) != 0
}

///|
/// 名字字符：字母数字下划线连字符点（与 C 版 is_name_char 对齐）
fn is_name_char(c : Byte) -> Bool {
  (lexer_cls.unsafe_get(c.to_int()) & 3) != 0
}

///|
/// 十六进制位（%HH 百分号对判定用）
fn is_hex(c : Byte) -> Bool {
  (lexer_cls.unsafe_get(c.to_int()) & 4) != 0
}

///|
/// UTF-8 码点解码（字节级零分配）：返回 (码点, 消耗字节数)；非法形态 (-1, 0)。
/// 拒收：裸续字节 / C0-C1 过长前导 / F5-FF 越界前导 / 断尾 / E0-F0-F4 下的
/// 过短编码 / 代理区（ED A0+）/ >U+10FFFF（F4 90+）
fn utf8_cp_at(v : ArrayView[Byte], pos : Int, l : Int) -> (Int, Int) {
  if pos >= l {
    return (-1, 0)
  }
  let c = v[pos]
  if c < b'\x80' {
    return (c.to_int(), 1)
  }
  if c < b'\xC2' {
    return (-1, 0)
  }
  if c < b'\xE0' {
    if pos + 1 >= l || !(v[pos + 1] >= b'\x80' && v[pos + 1] <= b'\xBF') {
      return (-1, 0)
    }
    return (((c.to_int() & 0x1F) << 6) | (v[pos + 1].to_int() & 0x3F), 2)
  }
  if c < b'\xF0' {
    if pos + 2 >= l {
      return (-1, 0)
    }
    let c1 = v[pos + 1]
    let c2 = v[pos + 2]
    if !(c1 >= b'\x80' && c1 <= b'\xBF') || !(c2 >= b'\x80' && c2 <= b'\xBF') {
      return (-1, 0)
    }
    if c == b'\xE0' && c1 < b'\xA0' {
      return (-1, 0) // 过短编码
    }
    if c == b'\xED' && c1 >= b'\xA0' {
      return (-1, 0) // 代理区
    }
    return (
      ((c.to_int() & 0x0F) << 12) |
      ((c1.to_int() & 0x3F) << 6) |
      (c2.to_int() & 0x3F),
      3,
    )
  }
  if c < b'\xF5' {
    if pos + 3 >= l {
      return (-1, 0)
    }
    let c1 = v[pos + 1]
    let c2 = v[pos + 2]
    let c3 = v[pos + 3]
    if !(c1 >= b'\x80' && c1 <= b'\xBF') ||
      !(c2 >= b'\x80' && c2 <= b'\xBF') ||
      !(c3 >= b'\x80' && c3 <= b'\xBF') {
      return (-1, 0)
    }
    if c == b'\xF0' && c1 < b'\x90' {
      return (-1, 0) // 过短编码
    }
    if c == b'\xF4' && c1 >= b'\x90' {
      return (-1, 0) // > U+10FFFF
    }
    return (
      ((c.to_int() & 0x07) << 18) |
      ((c1.to_int() & 0x3F) << 12) |
      ((c2.to_int() & 0x3F) << 6) |
      (c3.to_int() & 0x3F),
      4,
    )
  }
  (-1, 0)
}

///|
/// 多字节名字字符（Turtle PN_CHARS 非 ASCII 全集：PN_CHARS_BASE ∪ 组合记号
/// U+0300-036F ∪ U+203F-2040 ∪ ZWJ/ZWNJ U+200C-200D ∪ 中点 U+00B7）：
/// 返回消耗字节数（0 = 非名字字符）。码点合法性由 utf8_cp_at 保证
fn utf8_name_advance(v : ArrayView[Byte], pos : Int, l : Int) -> Int {
  let r = utf8_cp_at(v, pos, l)
  let cp = r.0
  let n = r.1
  if n <= 0 {
    return 0
  }
  if cp == 0x00B7 {
    return n
  }
  if (cp >= 0x00C0 && cp <= 0x00D6) ||
    (cp >= 0x00D8 && cp <= 0x00F6) ||
    (cp >= 0x00F8 && cp <= 0x02FF) ||
    (cp >= 0x0300 && cp <= 0x036F) ||
    (cp >= 0x0370 && cp <= 0x037D) ||
    (cp >= 0x037F && cp <= 0x1FFF) ||
    (cp >= 0x200C && cp <= 0x200D) ||
    (cp >= 0x203F && cp <= 0x2040) ||
    (cp >= 0x2070 && cp <= 0x218F) ||
    (cp >= 0x2C00 && cp <= 0x2FEF) ||
    (cp >= 0x3001 && cp <= 0xD7FF) ||
    (cp >= 0xF900 && cp <= 0xFDCF) ||
    (cp >= 0xFDF0 && cp <= 0xFFFD) ||
    (cp >= 0x10000 && cp <= 0xEFFFF) {
    return n
  }
  0
}

///|
/// 字面量后缀（无脑扫）：^^datatype / @lang 一并扫入，只认空白收束。
/// 尾部被吞的语句点等结构问题交引擎/校验层判定，词法器不做语法判断。
/// 后缀门（**层 1：只在这里说语义**）：紧邻字节须 `^^`(datatype) 或 `@lang` 才是后缀；
/// 其余结构符紧贴闭引号（`)` `]` `}` 等）**立即收束**留给引擎；**单个 `^` 不收**
/// （须成对才是 datatype）——`"lit"^:prop` 的 `^` 独立成 token，走引擎路径 desugar。
/// 三条起因（集合元素位失配 / N3Tests `path2`·`caret_pos` 残差）与完整口径见 **ADR-NQ-011**。
fn Lexermoon::scan_literal_suffix(self : Lexermoon) -> Unit {
  let v = self.view
  let l = self.len
  // `self.pos` 局部化为 `p` + `unsafe_get`（守卫/判据/分支序逐一照抄）
  let mut p = self.pos
  if p >= l {
    return
  }
  let caret_dt = v.unsafe_get(p) == b'^' &&
    p + 1 < l &&
    v.unsafe_get(p + 1) == b'^'
  if !caret_dt && v.unsafe_get(p) != b'@' {
    return
  }
  while p < l &&
        v.unsafe_get(p) != b' ' &&
        v.unsafe_get(p) != b'\t' &&
        v.unsafe_get(p) != b'\r' &&
        v.unsafe_get(p) != b'\n' &&
        v.unsafe_get(p) != b')' &&
        v.unsafe_get(p) != b']' &&
        v.unsafe_get(p) != b'}' {
    p = p + 1
  }
  self.pos = p
  // 右括族 `) ] }` 停扫（后缀合法域 = IRIREF / PrefName / langtag）；`.` `,` `;` 仍并入词尾，
  // 由引擎侧尾标点补偿 + 合成 Dot 承接（同族实现见 `src/gen_n3v2/engine.mbt` 的 `trim_trailing_punct`）。
  // 起因与完整口径见 **ADR-NQ-011**。
}

///|
/// 获取下一个 Token（与 lexerc_ffi.c 的 lexer_next 分支一一对应）
pub fn Lexermoon::next(self : Lexermoon) -> NQuadsEvent? {
  let v = self.view // 热循环局部缓存：字段加载不内联，每 token 只取一次
  let l = self.len
  // 空白/注释跳过（换行直接跳过不产出 token；行号由上层按数据惰性统计）
  for ;; {
    if self.pos >= l {
      return Some(NQuadsEOF)
    }
    match v[self.pos] {
      b' ' | b'\t' | b'\r' | b'\n' => self.pos = self.pos + 1
      b'#' => {
        self.pos = self.pos + 1
        while self.pos < l && v[self.pos] != b'\n' {
          self.pos = self.pos + 1
        }
      }
      _ => break
    }
  }
  let start = self.pos
  let c = v[self.pos]
  // 三引号长字符串 """...""" / '''...'''（含后缀）
  if (c == b'"' || c == b'\'') &&
    self.pos + 2 < l &&
    v[self.pos + 1] == c &&
    v[self.pos + 2] == c {
    // `self.pos` 局部化为 `p` + `unsafe_get`（守卫/判据/分支序逐一照抄）
    let mut p = self.pos + 3
    while p + 2 < l {
      let ch = v.unsafe_get(p)
      if ch == b'\\' && p + 1 < l {
        // 转义对整对消费（ECHAR/UCHAR）：`\\` 是字面反斜杠，其后闭 `"""`
        // 转义对以**整对**消费：`\\` 是字面反斜杠，其后闭 `"""` 照常闭壳
        //（若只看 pos-1 单字节会把它误判成被转义的引号）
        p = p + 2
      } else if ch == c && v.unsafe_get(p + 1) == c && v.unsafe_get(p + 2) == c {
        // 闭壳 = 引号连跑的**末尾**三连：`""""` = 内容引号 + 闭三连（连跑被转义对跳过后自然打断）
        while p < l && v.unsafe_get(p) == c {
          p = p + 1
        }
        break
      } else {
        p = p + 1
      }
    }
    self.pos = p
    self.scan_literal_suffix()
    return Some(NQuadsLiteral((start, self.pos - start)))
  }
  // 普通字符串（含转义；后缀 ^^ / @ 一并切出）
  if c == b'"' || c == b'\'' {
    // `self.pos` 局部化为 `p` + `unsafe_get`（守卫/判据/分支序逐一照抄）
    let mut p = self.pos + 1
    while p < l && v.unsafe_get(p) != c {
      if v.unsafe_get(p) == b'\\' && p + 1 < l {
        p = p + 2
      } else {
        p = p + 1
      }
    }
    if p < l {
      p = p + 1 // 消费结尾引号
    }
    self.pos = p
    self.scan_literal_suffix()
    return Some(NQuadsLiteral((start, self.pos - start)))
  }
  // _:name → BlankNode（名字含 .，与 C 版一致；多字节标签字符加宽同 PrefName 口径）
  if c == b'_' && self.pos + 1 < l && v[self.pos + 1] == b':' {
    self.pos = self.pos + 2
    // ASCII 门后 utf8_name_advance（多字节标签才走），收束字节省空转调用
    while self.pos < l {
      let ch = v[self.pos]
      if is_name_char(ch) {
        self.pos = self.pos + 1
      } else if ch.to_int() >= 0x80 {
        let adv = utf8_name_advance(v, self.pos, l)
        if adv == 0 {
          break
        }
        self.pos = self.pos + adv
      } else {
        break
      }
    }
    return Some(NQuadsBlankNode((start, self.pos - start)))
  }
  // <...> → IRI；<<(...)>> → TripleTerm（平衡配对）；<< → Unknown(1)；未闭合宽容出词
  if c == b'<' {
    if self.pos + 2 < l && v[self.pos + 1] == b'<' && v[self.pos + 2] == b'(' {
      // 三元组词项壳：<<( ... )>> 深度计数到配对闭壳。字符串是物理单元，
      // 引号内内容不参与配对（转义感知跳过）；词项内容不认识，语法对错归验证层
      self.pos = self.pos + 3
      let mut depth = 1
      while self.pos + 2 < l && depth > 0 {
        let d = v[self.pos]
        if d == b'"' || d == b'\'' {
          self.pos = self.pos + 1
          while self.pos < l && v[self.pos] != d {
            if v[self.pos] == b'\\' && self.pos + 1 < l {
              self.pos = self.pos + 2
            } else {
              self.pos = self.pos + 1
            }
          }
          if self.pos < l {
            self.pos = self.pos + 1 // 消费闭引号
          }
        } else if d == b'<' &&
          v[self.pos + 1] == b'<' &&
          v[self.pos + 2] == b'(' {
          depth = depth + 1
          self.pos = self.pos + 3
        } else if d == b')' &&
          v[self.pos + 1] == b'>' &&
          v[self.pos + 2] == b'>' {
          depth = depth - 1
          self.pos = self.pos + 3
        } else {
          self.pos = self.pos + 1
        }
      }
      return Some(NQuadsTripleTerm((start, self.pos - start)))
    }
    if self.pos + 1 < l && v[self.pos + 1] == b'<' {
      // RDF 1.2 引用三元组壳：<< s p o >>（可嵌套）。`<<(` 括号壳已在上分支，
      // 此处裸 `<<` 同机械：深度计数到配对 `>>`，字符串是物理单元（引号内不参与
      // 配对，转义感知跳过）；词项内容不认识，语法对错归验证层。未闭合宽容出词
      self.pos = self.pos + 2
      let mut depth = 1
      while self.pos < l && depth > 0 {
        let d = v[self.pos]
        if d == b'"' || d == b'\'' {
          self.pos = self.pos + 1
          while self.pos < l && v[self.pos] != d {
            if v[self.pos] == b'\\' && self.pos + 1 < l {
              self.pos = self.pos + 2
            } else {
              self.pos = self.pos + 1
            }
          }
          if self.pos < l {
            self.pos = self.pos + 1 // 消费闭引号
          }
        } else if d == b'<' && self.pos + 1 < l && v[self.pos + 1] == b'<' {
          depth = depth + 1
          self.pos = self.pos + 2
        } else if d == b'>' && self.pos + 1 < l && v[self.pos + 1] == b'>' {
          depth = depth - 1
          self.pos = self.pos + 2
        } else {
          self.pos = self.pos + 1
        }
      }
      return Some(NQuadsTripleTerm((start, self.pos - start)))
    }
    if self.pos + 1 < l && v[self.pos + 1] == b'=' {
      // N3 预埋：<= 整词 Unknown(2)（{|/|} 同机械，适配层按双字节分类）
      self.pos = self.pos + 2
      self.last_unknown = (start, self.pos - start)
      return Some(NQuadsUnknown)
    }
    // `self.pos` 局部化为 `p` + `unsafe_get` + 类表终止位（同一判据的查表实现，
    // 逐字节同义）⇒ 每字节省一次边界检查与一次字段 load/store。
    let mut p = self.pos + 1
    while p < l {
      if (lexer_cls.unsafe_get(v.unsafe_get(p).to_int()) & 8) != 0 {
        break
      }
      p = p + 1
    }
    if p < l && v.unsafe_get(p) == b'>' {
      p = p + 1
    }
    self.pos = p
    return Some(NQuadsIri((start, self.pos - start)))
  }
  // > → Unknown(1)（>> 收尾等）
  if c == b'>' {
    self.pos = self.pos + 1
    self.last_unknown = (start, self.pos - start)
    return Some(NQuadsUnknown)
  }
  // 字母/:起头（或多字节 PN_CHARS_BASE 字母）→ PrefName。PN_LOCAL 加宽口径：
  // 名字内允许 : 与名字字符（含内部 '.'、\X 转义对、%HH 百分号对、多字节 UTF-8）；
  // 语法对错（转义字符集/首字符限制）归验证层。尾部裸 '.' 回退留给语句终结符
  //（\X 转义的 '.' 是字面点，不回退）
  // ASCII 首字节直判——utf8_name_advance 收录码点全 ≥ 0xB7，ASCII
  // 字节必然 0；门后调用只留多字节前导（每个 PrefName 省一次调用 + 码点解码
  // + 14 段区间级联）
  let lead = if c.to_int() >= 0x80 {
    utf8_name_advance(v, self.pos, l)
  } else {
    0
  }
  if lead > 0 || is_alpha(c) || c == b':' {
    self.pos = self.pos + (if lead > 0 { lead } else { 1 })
    // 同一循环体，`self.pos` 局部化为 `p` + `unsafe_get`（守卫/判据/分支序逐一照抄）
    let mut p = self.pos
    while p < l {
      let ch = v.unsafe_get(p)
      if ch == b'\\' && p + 1 < l {
        // 转义对整段并入（PN_LOCAL_ESC 字符集校验在验证层）
        p = p + 2
      } else if ch == b'%' &&
        p + 2 < l &&
        is_hex(v.unsafe_get(p + 1)) &&
        is_hex(v.unsafe_get(p + 2)) {
        // %HH 百分号对整段并入（不足两 hex 位时 '%' 到 break，负例 bad-pname-02）
        p = p + 3
      } else if ch == b':' || is_name_char(ch) {
        p = p + 1
      } else if ch.to_int() >= 0x80 {
        // ASCII 字节必然 0（同首字节门），门后只留多字节——
        // 每个 PrefName 的收束字节（空白/结构符）省一次空转调用
        let adv = utf8_name_advance(v, p, l)
        if adv == 0 {
          break
        }
        p = p + adv
      } else {
        break
      }
    }
    self.pos = p
    // 尾部裸 '.' 回退（PN_LOCAL/PN_PREFIX 不得以裸点收尾）；转义点不回退
    while self.pos > start + 1 &&
          v[self.pos - 1] == b'.' &&
          v[self.pos - 2] != b'\\' {
      self.pos = self.pos - 1
    }
    return Some(NQuadsPrefName((start, self.pos - start)))
  }
  // 数字（可带±符号、可前导点）→ Unknown（Turtle 数值口径）：
  //   INTEGER [+-]?[0-9]+；DECIMAL [+-]?([0-9]+'.'[0-9]+ | '.'[0-9]+)；
  //   DOUBLE 再并 EXPONENT（[0-9]+'.'[0-9]*EXPONENT，数字部可空：`123.E+1`、`-.2e3` 整词出）。
  //   '.' 仅在后随数字或指数前导时并入：`1.` = INTEGER 1 + 语句点，不吞
  if (c == b'+' || c == b'-') &&
    self.pos + 1 < l &&
    (
      (v[self.pos + 1] >= b'0' && v[self.pos + 1] <= b'9') ||
      (
        v[self.pos + 1] == b'.' &&
        self.pos + 2 < l &&
        v[self.pos + 2] >= b'0' &&
        v[self.pos + 2] <= b'9'
      )
    ) {
    self.pos = self.pos + 1
  }
  let is_number = (v[self.pos] >= b'0' && v[self.pos] <= b'9') ||
    (
      v[self.pos] == b'.' &&
      self.pos + 1 < l &&
      v[self.pos + 1] >= b'0' &&
      v[self.pos + 1] <= b'9'
    )
  if is_number {
    // `self.pos` 局部化为 `p` + `unsafe_get`（守卫/判据/分支序逐一照抄）
    let mut p = self.pos
    if v.unsafe_get(p) == b'.' {
      // 前导点形态 '.5'：吞点 + 整数部
      p = p + 1
      while p < l && v.unsafe_get(p) >= b'0' && v.unsafe_get(p) <= b'9' {
        p = p + 1
      }
    } else {
      // 整数部
      p = p + 1
      while p < l && v.unsafe_get(p) >= b'0' && v.unsafe_get(p) <= b'9' {
        p = p + 1
      }
      // 小数部：'.' 后随数字吞整段；'.' 后随指数前导（[eE][+-]?[0-9]）只吞点（`123.E+1`）
      if p + 1 < l && v.unsafe_get(p) == b'.' {
        let d = v.unsafe_get(p + 1)
        let exp_ahead = (d == b'e' || d == b'E') &&
          p + 2 < l &&
          (
            (v.unsafe_get(p + 2) >= b'0' && v.unsafe_get(p + 2) <= b'9') ||
            v.unsafe_get(p + 2) == b'+' ||
            v.unsafe_get(p + 2) == b'-'
          )
        if d >= b'0' && d <= b'9' {
          p = p + 1
          while p < l && v.unsafe_get(p) >= b'0' && v.unsafe_get(p) <= b'9' {
            p = p + 1
          }
        } else if exp_ahead {
          p = p + 1
        }
      }
    }
    // 指数部：[eE] 后随数字或带符号数字才并入（EXPONENT 要求指数数字，`1e` 垃圾不并）
    if p + 1 < l && (v.unsafe_get(p) == b'e' || v.unsafe_get(p) == b'E') {
      let d = v.unsafe_get(p + 1)
      let has_exp = (d >= b'0' && d <= b'9') ||
        (
          (d == b'+' || d == b'-') &&
          p + 2 < l &&
          v.unsafe_get(p + 2) >= b'0' &&
          v.unsafe_get(p + 2) <= b'9'
        )
      if has_exp {
        p = p + 1
        if p < l && (v.unsafe_get(p) == b'+' || v.unsafe_get(p) == b'-') {
          p = p + 1
        }
        while p < l && v.unsafe_get(p) >= b'0' && v.unsafe_get(p) <= b'9' {
          p = p + 1
        }
      }
    }
    self.pos = p
    self.last_unknown = (start, self.pos - start)
    return Some(NQuadsUnknown)
  }
  // 结构标点（# 不可达：skip 已处理）
  if c == b'.' {
    self.pos = self.pos + 1
    return Some(NQuadsDot)
  }
  if c == b';' {
    self.pos = self.pos + 1
    return Some(NQuadsSemicolon)
  }
  if c == b',' {
    self.pos = self.pos + 1
    return Some(NQuadsComma)
  }
  // RDF 1.2 注解定界符：{| 与 |} 整词出（单 token 机械，适配层按双字节分类；
  // 裸 | 与裸 { 仍是 Unknown(1)）
  if c == b'{' && self.pos + 1 < l && v[self.pos + 1] == b'|' {
    self.pos = self.pos + 2
    self.last_unknown = (start, self.pos - start)
    return Some(NQuadsUnknown)
  }
  if c == b'|' && self.pos + 1 < l && v[self.pos + 1] == b'}' {
    self.pos = self.pos + 2
    self.last_unknown = (start, self.pos - start)
    return Some(NQuadsUnknown)
  }
  // N3 预埋：=> 整词 Unknown(2)（裸 = 仍是 Unknown(1)；>= 不存在，N3 无此操作符）
  if c == b'=' && self.pos + 1 < l && v[self.pos + 1] == b'>' {
    self.pos = self.pos + 2
    self.last_unknown = (start, self.pos - start)
    return Some(NQuadsUnknown)
  }
  // 其余字符一律 Unknown(1)，词法不中断
  self.pos = self.pos + 1
  self.last_unknown = (start, self.pos - start)
  Some(NQuadsUnknown)
}

///|
/// 解析全部事件（含末位 NQuadsEOF 哨兵；调用方按哨兵判终止）
fn Lexermoon::tokenize(self : Lexermoon) -> Array[NQuadsEvent] {
  let tokens : Array[NQuadsEvent] = []
  while true {
    match self.next() {
      Some(token) => {
        tokens.push(token)
        if token is NQuadsEOF {
          break
        }
      }
      None => break
    }
  }
  tokens
}

///|
/// 从 span 提取字符串
pub fn Lexermoon::extract(self : Lexermoon, start : Int, end : Int) -> String {
  let mut s = ""
  for i in start..<end {
    s = s + self.view[i].to_char().to_string()
  }
  s
}

///|
test "cursor tokenizer" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  let data = @utf8.encode(input).to_array()
  let tokenizer = Lexermoon::new(data[:])
  let events = tokenizer.tokenize()
  for ev in events {
    match ev {
      NQuadsIri(span) =>
        debug(
          "IRI: \{tokenizer.extract(span.0 + 1, span.0 + span.1 - 1)} at [\{span.0}:...]",
        )
      NQuadsDot => debug("Dot at [\{tokenizer.current_pos() - 1}:...]")
      NQuadsEOF => debug("EOF at \{tokenizer.current_pos()}")
      _ => ()
    }
  }
  // 3 IRI + Dot + EOF
  assert_eq(events.length(), 5)
}

///|
test "token 类型与 span 口径与 C 版对齐（全词含定界符/后缀并入）" {
  let input = "<http://e.org/s> _:b1 \"hi\"@en ex:p ."
  let data = @utf8.encode(input).to_array()
  let lexer = Lexermoon::new(data[:])
  let kinds : Array[String] = []
  for ;; {
    match lexer.next() {
      None => break
      Some(NQuadsEOF) => break
      Some(ev) =>
        kinds.push(
          match ev {
            NQuadsIri(_) => "iri"
            NQuadsBlankNode(_) => "bnode"
            NQuadsLiteral(_) => "literal"
            NQuadsPrefName(_) => "prefname"
            NQuadsDot => "dot"
            _ => "other"
          },
        )
    }
  }
  // 字母起头的 ex:p 现在出 PrefName 被词法宽容化，状态机层再按表拒绝
  assert_eq(kinds, ["iri", "bnode", "literal", "prefname", "dot"])
}

///|
test "benchmark: tokenizer 1000 quad" {
  let n = 1000
  let base = "http://example.org/"
  let input = {
    let mut s = ""
    for i = 0; i < n; i = i + 1 {
      s = s + "<\{base}s\{i}> <\{base}p\{i}> <\{base}o\{i}> .\n"
    }
    s
  }
  let bytes = @utf8.encode(input).to_array()
  let start1 = @bench.monotonic_clock_start()
  let tokenizer = Lexermoon::new(bytes[:])
  let events = tokenizer.tokenize()
  let mut count = 0
  for ev in events {
    match ev {
      NQuadsIri(_) => count = count + 1
      _ => ()
    }
  }
  let elapsed1 = @bench.monotonic_clock_end(start1)
  println("=== MoonBit 解析 test_1000.nq ===")
  println("")
  println("=== 性能数据 ===")
  println("Lexer:       \{elapsed1} µs (\{count} iri tokens)")
}

// ===== 词法口径测试（仅 Lexermoon，仅词法层：事件种类 + span/结构起点，不涉语法/引擎）=====
// 口径约定：span = (offset, length) 全词含定界符；官方要素逐项 pin。

///|
/// 事件流口径串（判据本体：下面的构造规则即"什么算一致"）：字面事件保 span 串（与原 Token span 同值）；
/// 结构事件 span 已在直产时收窄 ⇒ 以 "@<start>" 钉起点（钉力与原 span 同价——
/// start = current_pos()−1，单字符消费后回退一位 = 原 Token span.0）
fn lexer_test_fmt_event_at(ev : NQuadsEvent, start : Int) -> String {
  match ev {
    NQuadsIri(s) => "Iri(\{s.0},\{s.1})"
    NQuadsBlankNode(s) => "BlankNode(\{s.0},\{s.1})"
    NQuadsLiteral(s) => "Literal(\{s.0},\{s.1})"
    NQuadsPrefName(s) => "PrefName(\{s.0},\{s.1})"
    NQuadsTripleTerm(s) => "TripleTerm(\{s.0},\{s.1})"
    NQuadsUnknown => "Unknown" // 生成契约无 span（宽度语义由终点 EOF@ 钉）
    NQuadsDot => "Dot@\{start}"
    NQuadsSemicolon => "Semicolon@\{start}"
    NQuadsComma => "Comma@\{start}"
    NQuadsEOF => "EOF@\{start}"
  }
}

///|
/// Lexermoon 事件流口径串（EOF 不计：终端事件单独 pin）
fn lexer_test_moon_stream(input : String) -> String {
  let data = @utf8.encode(input).to_array()
  let lexer = Lexermoon::new(data[:])
  let buf = StringBuilder()
  for ;; {
    match lexer.next() {
      None => break
      Some(ev) => {
        // 终点 EOF@<pos> 一并入串：钉整词宽度（补 Unknown 无 span 的宽度语义）；
        // 结构事件起点 = pos−1（单字符消费后回退）；EOF 无宽，起点 = pos
        let after = lexer.current_pos()
        let start = if ev is NQuadsEOF { after } else { after - 1 }
        buf.write_string(lexer_test_fmt_event_at(ev, start))
        buf.write_string(" ")
        if ev is NQuadsEOF {
          break
        }
      }
    }
  }
  buf.to_string()
}

///|
/// 官方 N-Quads 要素逐项：输入 → 期望事件流
/// （口径：字面事件保 span 串；结构/Unknown 事件以 @<pos> 钉消费位；
///   终点 EOF@<len> 钉整词宽度——补 Unknown 无 span 的宽度语义）
fn lexer_test_battery() -> Array[(String, String)] {
  [
    // 完整 URI：<...> 全词含定界符
    ("<http://example.org/a>", "Iri(0,22) EOF@22 "),
    ("<http://e.org/s> <http://e.org/o>", "Iri(0,16) Iri(17,16) EOF@33 "),
    // 空白节点：_: 前缀 + 标签
    ("_:b0", "BlankNode(0,4) EOF@4 "),
    // 纯字面量：含转义引号
    ("\"text\"", "Literal(0,6) EOF@6 "),
    ("\"a\\\"b\"", "Literal(0,6) EOF@6 "),
    // 语言标签：@ 后缀并入 Literal
    ("\"text\"@en", "Literal(0,9) EOF@9 "),
    ("\"text\"@en-US", "Literal(0,12) EOF@12 "),
    // 类型字面量：^^<...> 后缀并入 Literal（域名中的 . 不得切断）
    (
      "\"42\"^^<http://www.w3.org/2001/XMLSchema#integer>", "Literal(0,48) EOF@48 ",
    ),
    // 语句结束与结构标点（单词符）
    (".", "Dot@0 EOF@1 "),
    (";", "Semicolon@0 EOF@1 "),
    (",", "Comma@0 EOF@1 "),
    // 命名图：第 4 元素（URI 或空白节点）
    ("<s> <p> <o> <g> .", "Iri(0,3) Iri(4,3) Iri(8,3) Iri(12,3) Dot@16 EOF@17 "),
    (
      "_:s <p> <o> _:g .", "BlankNode(0,3) Iri(4,3) Iri(8,3) BlankNode(12,3) Dot@16 EOF@17 ",
    ),
    // 数字：无脑扫出 Unknown（整型/浮点/科学计数整段一词；宽度由 EOF@ 终点钉）
    ("42", "Unknown EOF@2 "),
    ("4.2e-1", "Unknown EOF@6 "),
    ("-1", "Unknown EOF@2 "),
    ("+1.5e-3", "Unknown EOF@7 "),
    ("1.", "Unknown Dot@1 EOF@2 "),
    // 前导点 / 点后接指数（Turtle DECIMAL/DOUBLE 数字部可空）
    (".5", "Unknown EOF@2 "),
    ("-.2e3", "Unknown EOF@5 "),
    ("123.E+1", "Unknown EOF@7 "),
    ("1.e5", "Unknown EOF@4 "),
    // PrefName：字母 / : 起头
    ("ex:p", "PrefName(0,4) EOF@4 "),
    (":p", "PrefName(0,2) EOF@2 "),
    // 词法加宽口径（双引擎一致）：\X 转义对 / %HH 百分号对 / 内部点 / 尾点回退 /
    // 转义尾点不回退 / 多字节名字字符 / 多字节起头整词
    ("ex:a\\~\\.\\-\\!", "PrefName(0,12) EOF@12 "),
    (":a%3Eb", "PrefName(0,6) EOF@6 "),
    ("ex:a.b", "PrefName(0,6) EOF@6 "),
    ("ex:o.", "PrefName(0,4) Dot@4 EOF@5 "),
    ("ex:o\\.", "PrefName(0,6) EOF@6 "),
    ("p:a·̀ͯ‿.⁀", "PrefName(0,16) EOF@16 "),
    ("_:b·", "BlankNode(0,5) EOF@5 "),
    ("é:x", "PrefName(0,4) EOF@4 "),
    // 空白与注释跳过，不产出事件，span 保持全局定位
    ("# comment\n<s> <p> .", "Iri(10,3) Iri(14,3) Dot@18 EOF@19 "),
    // 无脑扫尾巴：后缀只认空白，尾点并入词内（结构裁决归引擎/校验层）
    // 三元组词项 <<( )>>：平衡配对出整词（RDF 1.2；嵌套/引号内容不参与配对）
    ("<<( <s> <p> <o> )>>", "TripleTerm(0,19) EOF@19 "),
    ("<<(<s><p><o>)>>.", "TripleTerm(0,15) Dot@15 EOF@16 "),
    // RDF 1.2 裸 << >> 引用三元组（可嵌套，深度配对）
    ("<< <s> <p> <o> >>", "TripleTerm(0,17) EOF@17 "),
    ("<< :a << :b :c :d >> :e >>", "TripleTerm(0,26) EOF@26 "),
    ("<<:s :p :o >>.", "TripleTerm(0,13) Dot@13 EOF@14 "),
    ("<<(<a><b><<(<c><d><e>)>>)>>", "TripleTerm(0,27) EOF@27 "),
    ("<<( <s> <p> \"a)>>b\" )>>", "TripleTerm(0,23) EOF@23 "),
    // RDF 1.2 裸 << >>（RDF 1.2 起为合法引用三元组壳，不再是垃圾口径）：
    // 词法整词出壳，壳内语法（项是否齐全/合法）由验证/引擎层裁决
    ("<< <s> >>", "TripleTerm(0,9) EOF@9 "),
    // 容错口径：未闭合 IRI / 字面量 / 引用三元组壳宽容出词
    ("<<a>", "TripleTerm(0,4) EOF@4 "),
    ("<http://a", "Iri(0,9) EOF@9 "),
    ("\"abc", "Literal(0,4) EOF@4 "),
    ("_ x", "Unknown PrefName(2,1) EOF@3 "),
    ("@x", "Unknown PrefName(1,1) EOF@2 "),
  ]
}

///|
test "词法口径: 官方要素逐项（token 种类 + span）" {
  for pair in lexer_test_battery() {
    let (input, expect) = pair
    assert_eq(lexer_test_moon_stream(input), expect)
  }
}

///|
test "词法口径: 无脑扫尾巴——后缀门收紧，结构字节出独立 Dot（lists-05 口径）" {
  // "text". → 闭引号后非 ^/@：立即收束，尾点出独立 Dot；**不得把紧邻结构符**
  //（如 `"a")` 的 `)`）吞进词项——起因（集合元素位失配）见 **ADR-NQ-011**；语句点语义裁决仍归引擎
  assert_eq(lexer_test_moon_stream("\"text\"."), "Literal(0,6) Dot@6 EOF@7 ")
  // @ 门通过：@lang 后缀照旧吞到空白，尾点并入词内（引擎 trim 兜底不变）
  assert_eq(lexer_test_moon_stream("\"text\"@en."), "Literal(0,10) EOF@10 ")
  // 名字字符含 . ：_:b0. 整词吞点
  assert_eq(lexer_test_moon_stream("_:b0."), "BlankNode(0,5) EOF@5 ")
  // 对照：IRI 的 > 自身定界，尾点正常出 Dot
  assert_eq(lexer_test_moon_stream("<s>."), "Iri(0,3) Dot@3 EOF@4 ")
}

///|
test "词法口径: <<( )>> 平衡配对（已升入共享电池，双引擎一致性测试覆盖 C 版）" {
  // 电池已 pin 全部口径；此处保留未闭合壳的 Lexermoon 出词边界（不进电池：
  // 宽容出词的残余 token 顺序属实现细节，双引擎对齐以整词口径为准）
  assert_eq(
    lexer_test_moon_stream("<<( <s>"),
    "TripleTerm(0,5) PrefName(5,1) Unknown EOF@7 ",
  )
}

///|
test "词法口径: EOF 协议（EOF 哨兵冻结，重复 next 恒同值）" {
  let data = @utf8.encode("a").to_array()
  let lexer = Lexermoon::new(data[:])
  let _ = lexer.next() // PrefName(0,1)
  // EOF 载荷：事件**不带** EOF 载荷，词法位置由 `current_pos()` 钉死
  assert_true(lexer.next() is Some(NQuadsEOF))
  assert_eq(lexer.current_pos(), 1)
  assert_true(lexer.next() is Some(NQuadsEOF))
  assert_eq(lexer.current_pos(), 1)
}

///|
test "lexdbg: 三引号壳内 4 连引号 + 双反斜杠" {
  let b : Array[Byte] = []
  b.push(b'"')
  b.push(b'"')
  b.push(b'"')
  for c in "test-" {
    b.push(c.to_int().to_byte())
  }
  b.push(b'\\')
  b.push(b'\\')
  b.push(b'"')
  b.push(b'"')
  b.push(b'"')
  b.push(b'"')
  let lexer = Lexermoon::new(b[:])
  for ;; {
    match lexer.next() {
      None => break
      Some(NQuadsEOF) => break
      Some(ev) =>
        println("\{lexer_test_fmt_event_at(ev, lexer.current_pos() - 1)}")
    }
  }
  assert_true(true)
}
