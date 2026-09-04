// ===== 纯 MoonBit 词法器（Token 类型与 span 口径与 C 版 Lexerc 完全对齐） =====
// 复用 lexerc.mbt 的 Token：统一 (offset, length)，全词含定界符。
// 本文件不再有 Tokenfast —— 两条词法路径共用同一 Token 字母表与同一
// Token→Event 映射（engine.mbt token_to_event），span 口径天然一致。
// 词法语义以 C 版（lexerc_ffi.c）为标准对齐：
//   - 字面量分三引号/普通两种；含转义；后缀 ^^datatype / @lang 并入 Literal
//   - _:name → BlankNode；字母/:起头 → PrefName；数字（可带±符号）→ Unknown
//   - 未闭合 IRI/字面量宽容出词（不再 None 硬错）；其余单字符一律 Unknown(1)
//   - PrefName 无脑扫：名字内 : / 内部 '.' / \X 转义对 / %HH / 多字节一律并入，
//     尾部裸 '.' 回退；语法对错归验证层（词法加宽口径，双引擎同机械）
// EOF 协议：结尾返回 Some(Token::EOF(pos))（pos 不再推进，调用方按变体断环）；
// None 仅保留给异常分支，正常流不会出现。
// 热路径纪律：view/len 以局部缓存参与每字节循环（debug 构建不内联字段加载），
// 逐字节判别内联比较，不做任何函数调用。

///|
pub(all) struct Lexermoon {
  view : ArrayView[Byte]
  mut pos : Int
  mut len : Int
}

///|
pub fn Lexermoon::new(view : ArrayView[Byte]) -> Lexermoon {
  Lexermoon::{ view, pos: 0, len: view.length(), }
}

///|
/// 获取当前位置（用于错误报告）
pub fn Lexermoon::current_pos(self : Lexermoon) -> Int {
  self.pos
}

///|
fn is_alpha(c : Byte) -> Bool {
  (c >= b'a' && c <= b'z') || (c >= b'A' && c <= b'Z')
}

///|
/// 名字字符：字母数字下划线连字符点（与 C 版 is_name_char 对齐）
fn is_name_char(c : Byte) -> Bool {
  is_alpha(c) || (c >= b'0' && c <= b'9') || c == b'_' || c == b'-' || c == b'.'
}

///|
/// 十六进制位（%HH 百分号对判定用）
fn is_hex(c : Byte) -> Bool {
  (c >= b'0' && c <= b'9') ||
  (c >= b'a' && c <= b'f') ||
  (c >= b'A' && c <= b'F')
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
/// 后缀门（lists-05 口径）：紧邻字节须 ^^(datatype) 或 @lang 才进后缀扫描；
/// 其余字节（`)`/`]`/`,`/`;` 等结构符紧贴闭引号）不是后缀，立即收束留给引擎——
/// 旧"只认空白收束"把 `"a")` 的闭括号吞进词项，集合元素位直接失配
fn Lexermoon::scan_literal_suffix(self : Lexermoon) -> Unit {
  let v = self.view
  let l = self.len
  if self.pos >= l || (v[self.pos] != b'^' && v[self.pos] != b'@') {
    return
  }
  while self.pos < l &&
        v[self.pos] != b' ' &&
        v[self.pos] != b'\t' &&
        v[self.pos] != b'\r' &&
        v[self.pos] != b'\n' {
    self.pos = self.pos + 1
  }
}

///|
/// 获取下一个 Token（与 lexerc_ffi.c 的 lexer_next 分支一一对应）
pub fn Lexermoon::next(self : Lexermoon) -> Token? {
  let v = self.view // 热循环局部缓存：字段加载不内联，每 token 只取一次
  let l = self.len
  // 空白/注释跳过（换行直接跳过不产出 token；行号由上层按数据惰性统计）
  for ;; {
    if self.pos >= l {
      return Some(Token::EOF(self.pos))
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
    self.pos = self.pos + 3
    while self.pos + 2 < l {
      let ch = v[self.pos]
      if ch == b'\\' && self.pos + 1 < l {
        // 转义对整对消费（ECHAR/UCHAR）：`\\` 是字面反斜杠，其后闭 `"""`
        // 照常闭壳（pos-1 单字节嗅探会把 `\\"""` 误判成转义引号——LITERAL_LONG2 坑）
        self.pos = self.pos + 2
      } else if ch == c && v[self.pos + 1] == c && v[self.pos + 2] == c {
        // 闭壳 = 引号连跑的末尾 quote_run 个：`""""` = 内容引号 + 闭三连
        //（Turtle '"""' (...)* '"'? '"""' 口径）；连跑被转义对跳过自然打断
        while self.pos < l && v[self.pos] == c {
          self.pos = self.pos + 1
        }
        break
      } else {
        self.pos = self.pos + 1
      }
    }
    self.scan_literal_suffix()
    return Some(Token::Literal((start, self.pos - start)))
  }
  // 普通字符串（含转义；后缀 ^^ / @ 一并切出）
  if c == b'"' || c == b'\'' {
    self.pos = self.pos + 1
    while self.pos < l && v[self.pos] != c {
      if v[self.pos] == b'\\' && self.pos + 1 < l {
        self.pos = self.pos + 2
      } else {
        self.pos = self.pos + 1
      }
    }
    if self.pos < l {
      self.pos = self.pos + 1 // 消费结尾引号
    }
    self.scan_literal_suffix()
    return Some(Token::Literal((start, self.pos - start)))
  }
  // _:name → BlankNode（名字含 .，与 C 版一致；多字节标签字符加宽同 PrefName 口径）
  if c == b'_' && self.pos + 1 < l && v[self.pos + 1] == b':' {
    self.pos = self.pos + 2
    while self.pos < l {
      let ch = v[self.pos]
      if is_name_char(ch) {
        self.pos = self.pos + 1
      } else {
        let adv = utf8_name_advance(v, self.pos, l)
        if adv == 0 {
          break
        }
        self.pos = self.pos + adv
      }
    }
    return Some(Token::BlankNode((start, self.pos - start)))
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
      return Some(Token::TripleTerm((start, self.pos - start)))
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
      return Some(Token::TripleTerm((start, self.pos - start)))
    }
    if self.pos + 1 < l && v[self.pos + 1] == b'=' {
      // N3 预埋：<= 整词 Unknown(2)（{|/|} 同机械，适配层按双字节分类）
      self.pos = self.pos + 2
      return Some(Token::Unknown((start, 2)))
    }
    self.pos = self.pos + 1
    while self.pos < l {
      let ch = v[self.pos]
      // 内联判别：'>' 收口，空白视为未闭合（热路径不做函数调用）
      if ch == b'>' || ch == b' ' || ch == b'\t' || ch == b'\r' || ch == b'\n' {
        break
      }
      self.pos = self.pos + 1
    }
    if self.pos < l && v[self.pos] == b'>' {
      self.pos = self.pos + 1
    }
    return Some(Token::Iri((start, self.pos - start)))
  }
  // > → Unknown(1)（>> 收尾等）
  if c == b'>' {
    self.pos = self.pos + 1
    return Some(Token::Unknown((start, 1)))
  }
  // 字母/:起头（或多字节 PN_CHARS_BASE 字母）→ PrefName。PN_LOCAL 加宽口径：
  // 名字内允许 : 与名字字符（含内部 '.'、\X 转义对、%HH 百分号对、多字节 UTF-8）；
  // 语法对错（转义字符集/首字符限制）归验证层。尾部裸 '.' 回退留给语句终结符
  //（\X 转义的 '.' 是字面点，不回退）
  let lead = utf8_name_advance(v, self.pos, l)
  if lead > 0 || is_alpha(c) || c == b':' {
    self.pos = self.pos + (if lead > 0 { lead } else { 1 })
    while self.pos < l {
      let ch = v[self.pos]
      if ch == b'\\' && self.pos + 1 < l {
        // 转义对整段并入（PN_LOCAL_ESC 字符集校验在验证层）
        self.pos = self.pos + 2
      } else if ch == b'%' &&
        self.pos + 2 < l &&
        is_hex(v[self.pos + 1]) &&
        is_hex(v[self.pos + 2]) {
        // %HH 百分号对整段并入（不足两 hex 位时 '%' 到 break，负例 bad-pname-02）
        self.pos = self.pos + 3
      } else if ch == b':' || is_name_char(ch) {
        self.pos = self.pos + 1
      } else {
        let adv = utf8_name_advance(v, self.pos, l)
        if adv == 0 {
          break
        }
        self.pos = self.pos + adv
      }
    }
    // 尾部裸 '.' 回退（PN_LOCAL/PN_PREFIX 不得以裸点收尾）；转义点不回退
    while self.pos > start + 1 &&
          v[self.pos - 1] == b'.' &&
          v[self.pos - 2] != b'\\' {
      self.pos = self.pos - 1
    }
    return Some(Token::PrefName((start, self.pos - start)))
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
    if v[self.pos] == b'.' {
      // 前导点形态 '.5'：吞点 + 整数部
      self.pos = self.pos + 1
      while self.pos < l && v[self.pos] >= b'0' && v[self.pos] <= b'9' {
        self.pos = self.pos + 1
      }
    } else {
      // 整数部
      self.pos = self.pos + 1
      while self.pos < l && v[self.pos] >= b'0' && v[self.pos] <= b'9' {
        self.pos = self.pos + 1
      }
      // 小数部：'.' 后随数字吞整段；'.' 后随指数前导（[eE][+-]?[0-9]）只吞点（`123.E+1`）
      if self.pos + 1 < l && v[self.pos] == b'.' {
        let d = v[self.pos + 1]
        let exp_ahead = (d == b'e' || d == b'E') &&
          self.pos + 2 < l &&
          (
            (v[self.pos + 2] >= b'0' && v[self.pos + 2] <= b'9') ||
            v[self.pos + 2] == b'+' ||
            v[self.pos + 2] == b'-'
          )
        if d >= b'0' && d <= b'9' {
          self.pos = self.pos + 1
          while self.pos < l && v[self.pos] >= b'0' && v[self.pos] <= b'9' {
            self.pos = self.pos + 1
          }
        } else if exp_ahead {
          self.pos = self.pos + 1
        }
      }
    }
    // 指数部：[eE] 后随数字或带符号数字才并入（EXPONENT 要求指数数字，`1e` 垃圾不并）
    if self.pos + 1 < l && (v[self.pos] == b'e' || v[self.pos] == b'E') {
      let d = v[self.pos + 1]
      let has_exp = (d >= b'0' && d <= b'9') ||
        (
          (d == b'+' || d == b'-') &&
          self.pos + 2 < l &&
          v[self.pos + 2] >= b'0' &&
          v[self.pos + 2] <= b'9'
        )
      if has_exp {
        self.pos = self.pos + 1
        if self.pos < l && (v[self.pos] == b'+' || v[self.pos] == b'-') {
          self.pos = self.pos + 1
        }
        while self.pos < l && v[self.pos] >= b'0' && v[self.pos] <= b'9' {
          self.pos = self.pos + 1
        }
      }
    }
    return Some(Token::Unknown((start, self.pos - start)))
  }
  // 结构标点（# 不可达：skip 已处理）
  if c == b'.' {
    self.pos = self.pos + 1
    return Some(Token::Dot((start, 1)))
  }
  if c == b';' {
    self.pos = self.pos + 1
    return Some(Token::Semicolon((start, 1)))
  }
  if c == b',' {
    self.pos = self.pos + 1
    return Some(Token::Comma((start, 1)))
  }
  // RDF 1.2 注解定界符：{| 与 |} 整词出（单 token 机械，适配层按双字节分类；
  // 裸 | 与裸 { 仍是 Unknown(1)）
  if c == b'{' && self.pos + 1 < l && v[self.pos + 1] == b'|' {
    self.pos = self.pos + 2
    return Some(Token::Unknown((start, 2)))
  }
  if c == b'|' && self.pos + 1 < l && v[self.pos + 1] == b'}' {
    self.pos = self.pos + 2
    return Some(Token::Unknown((start, 2)))
  }
  // N3 预埋：=> 整词 Unknown(2)（裸 = 仍是 Unknown(1)；>= 不存在，N3 无此操作符）
  if c == b'=' && self.pos + 1 < l && v[self.pos + 1] == b'>' {
    self.pos = self.pos + 2
    return Some(Token::Unknown((start, 2)))
  }
  // 其余字符一律 Unknown(1)，词法不中断
  self.pos = self.pos + 1
  Some(Token::Unknown((start, 1)))
}

///|
/// 解析所有 Token（含末位 EOF；调用方按 EOF 变体判终止）
pub fn Lexermoon::tokenize(self : Lexermoon) -> Array[Token] {
  let tokens : Array[Token] = []
  while true {
    match self.next() {
      Some(token) => {
        tokens.push(token)
        if token is Token::EOF(_) {
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
/// 从 Token 提取 IRI（去掉 <> 包裹）
pub fn Lexermoon::extract_iri(self : Lexermoon, token : Token) -> String {
  match token {
    Token::Iri((start, length)) => {
      let end = start + length
      if length > 2 && self.view[start] == b'<' && self.view[end - 1] == b'>' {
        self.extract(start + 1, end - 1)
      } else {
        self.extract(start, end)
      }
    }
    _ => ""
  }
}

///|
test "cursor tokenizer" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  let data = @utf8.encode(input).to_array()
  let tokenizer = Lexermoon::new(data[:])
  let tokens = tokenizer.tokenize()
  for token in tokens {
    match token {
      Token::Iri((start, _)) =>
        debug("IRI: \{tokenizer.extract_iri(token)} at [\{start}:...]")
      Token::Dot((start, _)) => debug("Dot at [\{start}:...]")
      Token::EOF(pos) => debug("EOF at \{pos}")
      _ => ()
    }
  }
  // 3 IRI + Dot + EOF
  assert_eq(tokens.length(), 5)
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
      Some(Token::EOF(_)) => break
      Some(t) =>
        kinds.push(
          match t {
            Token::Iri(_) => "iri"
            Token::BlankNode(_) => "bnode"
            Token::Literal(_) => "literal"
            Token::PrefName(_) => "prefname"
            Token::Dot(_) => "dot"
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
  let tokens = tokenizer.tokenize()
  let mut count = 0
  for token in tokens {
    match token {
      Token::Iri(_) => count = count + 1
      _ => ()
    }
  }
  let elapsed1 = @bench.monotonic_clock_end(start1)
  println("=== MoonBit 解析 test_1000.nq ===")
  println("")
  println("=== 性能数据 ===")
  println("Lexer:       \{elapsed1} µs (\{count} iri tokens)")
}

// ===== 词法口径测试（仅 Lexermoon，仅词法层：token 种类 + span，不涉语法/引擎）=====
// 口径约定：span = (offset, length) 全词含定界符；官方要素逐项 pin。

///|
fn lexer_test_fmt_token(t : Token) -> String {
  match t {
    Token::Dot((o, l)) => "Dot(\{o},\{l})"
    Token::Semicolon((o, l)) => "Semicolon(\{o},\{l})"
    Token::Comma((o, l)) => "Comma(\{o},\{l})"
    Token::Iri((o, l)) => "Iri(\{o},\{l})"
    Token::Literal((o, l)) => "Literal(\{o},\{l})"
    Token::BlankNode((o, l)) => "BlankNode(\{o},\{l})"
    Token::PrefName((o, l)) => "PrefName(\{o},\{l})"
    Token::TripleTerm((o, l)) => "TripleTerm(\{o},\{l})"
    Token::Unknown((o, l)) => "Unknown(\{o},\{l})"
    Token::EOF(o) => "EOF(\{o})"
  }
}

///|
/// Lexermoon 词法流口径串（EOF 不计：终端 token 单独 pin）
fn lexer_test_moon_stream(input : String) -> String {
  let data = @utf8.encode(input).to_array()
  let lexer = Lexermoon::new(data[:])
  let buf = StringBuilder()
  for ;; {
    match lexer.next() {
      None => break
      Some(Token::EOF(_)) => break
      Some(t) => {
        buf.write_string(lexer_test_fmt_token(t))
        buf.write_string(" ")
      }
    }
  }
  buf.to_string()
}

///|
/// 官方 N-Quads 要素逐项：输入 → 期望词法流
fn lexer_test_battery() -> Array[(String, String)] {
  [
    // 完整 URI：<...> 全词含定界符
    ("<http://example.org/a>", "Iri(0,22) "),
    ("<http://e.org/s> <http://e.org/o>", "Iri(0,16) Iri(17,16) "),
    // 空白节点：_: 前缀 + 标签
    ("_:b0", "BlankNode(0,4) "),
    // 纯字面量：含转义引号
    ("\"text\"", "Literal(0,6) "),
    ("\"a\\\"b\"", "Literal(0,6) "),
    // 语言标签：@ 后缀并入 Literal
    ("\"text\"@en", "Literal(0,9) "),
    ("\"text\"@en-US", "Literal(0,12) "),
    // 类型字面量：^^<...> 后缀并入 Literal（域名中的 . 不得切断）
    ("\"42\"^^<http://www.w3.org/2001/XMLSchema#integer>", "Literal(0,48) "),
    // 语句结束与结构标点（单词符）
    (".", "Dot(0,1) "),
    (";", "Semicolon(0,1) "),
    (",", "Comma(0,1) "),
    // 命名图：第 4 元素（URI 或空白节点）
    ("<s> <p> <o> <g> .", "Iri(0,3) Iri(4,3) Iri(8,3) Iri(12,3) Dot(16,1) "),
    (
      "_:s <p> <o> _:g .", "BlankNode(0,3) Iri(4,3) Iri(8,3) BlankNode(12,3) Dot(16,1) ",
    ),
    // 数字：无脑扫出 Unknown（整型/浮点/科学计数整段一词）
    ("42", "Unknown(0,2) "),
    ("4.2e-1", "Unknown(0,6) "),
    ("-1", "Unknown(0,2) "),
    ("+1.5e-3", "Unknown(0,7) "),
    ("1.", "Unknown(0,1) Dot(1,1) "),
    // 前导点 / 点后接指数（Turtle DECIMAL/DOUBLE 数字部可空）
    (".5", "Unknown(0,2) "),
    ("-.2e3", "Unknown(0,5) "),
    ("123.E+1", "Unknown(0,7) "),
    ("1.e5", "Unknown(0,4) "),
    // PrefName：字母 / : 起头
    ("ex:p", "PrefName(0,4) "),
    (":p", "PrefName(0,2) "),
    // 词法加宽口径（双引擎一致）：\X 转义对 / %HH 百分号对 / 内部点 / 尾点回退 /
    // 转义尾点不回退 / 多字节名字字符 / 多字节起头整词
    ("ex:a\\~\\.\\-\\!", "PrefName(0,12) "),
    (":a%3Eb", "PrefName(0,6) "),
    ("ex:a.b", "PrefName(0,6) "),
    ("ex:o.", "PrefName(0,4) Dot(4,1) "),
    ("ex:o\\.", "PrefName(0,6) "),
    ("p:a·̀ͯ‿.⁀", "PrefName(0,16) "),
    ("_:b·", "BlankNode(0,5) "),
    ("é:x", "PrefName(0,4) "),
    // 空白与注释跳过，不产出 token，span 保持全局定位
    ("# comment\n<s> <p> .", "Iri(10,3) Iri(14,3) Dot(18,1) "),
    // 无脑扫尾巴：后缀只认空白，尾点并入词内（结构裁决归引擎/校验层）
    // 三元组词项 <<( )>>：平衡配对出整词（RDF 1.2；嵌套/引号内容不参与配对）
    ("<<( <s> <p> <o> )>>", "TripleTerm(0,19) "),
    ("<<(<s><p><o>)>>.", "TripleTerm(0,15) Dot(15,1) "),
    // RDF 1.2 裸 << >> 引用三元组（可嵌套，深度配对）
    ("<< <s> <p> <o> >>", "TripleTerm(0,17) "),
    ("<< :a << :b :c :d >> :e >>", "TripleTerm(0,26) "),
    ("<<:s :p :o >>.", "TripleTerm(0,13) Dot(13,1) "),
    ("<<(<a><b><<(<c><d><e>)>>)>>", "TripleTerm(0,27) "),
    ("<<( <s> <p> \"a)>>b\" )>>", "TripleTerm(0,23) "),
    // RDF 1.2 裸 << >>（RDF 1.2 起为合法引用三元组壳，不再是垃圾口径）：
    // 词法整词出壳，壳内语法（项是否齐全/合法）由验证/引擎层裁决
    ("<< <s> >>", "TripleTerm(0,9) "),
    // 容错口径：未闭合 IRI / 字面量 / 引用三元组壳宽容出词
    ("<<a>", "TripleTerm(0,4) "),
    ("<http://a", "Iri(0,9) "),
    ("\"abc", "Literal(0,4) "),
    ("_ x", "Unknown(0,1) PrefName(2,1) "),
    ("@x", "Unknown(0,1) PrefName(1,1) "),
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
  // "text". → 闭引号后非 ^/@：立即收束，尾点出独立 Dot（旧吞点口径退役——
  // "a") 紧邻结构符被吞进词项，集合元素位失配）。语句点语义裁决仍归引擎
  assert_eq(lexer_test_moon_stream("\"text\"."), "Literal(0,6) Dot(6,1) ")
  // @ 门通过：@lang 后缀照旧吞到空白，尾点并入词内（引擎 trim 兜底不变）
  assert_eq(lexer_test_moon_stream("\"text\"@en."), "Literal(0,10) ")
  // 名字字符含 . ：_:b0. 整词吞点
  assert_eq(lexer_test_moon_stream("_:b0."), "BlankNode(0,5) ")
  // 对照：IRI 的 > 自身定界，尾点正常出 Dot
  assert_eq(lexer_test_moon_stream("<s>."), "Iri(0,3) Dot(3,1) ")
}

///|
test "词法口径: <<( )>> 平衡配对（已升入共享电池，双引擎一致性测试覆盖 C 版）" {
  // 电池已 pin 全部口径；此处保留未闭合壳的 Lexermoon 出词边界（不进电池：
  // 宽容出词的残余 token 顺序属实现细节，双引擎对齐以整词口径为准）
  assert_eq(
    lexer_test_moon_stream("<<( <s>"),
    "TripleTerm(0,5) PrefName(5,1) Unknown(6,1) ",
  )
}

///|
test "词法口径: EOF 协议（EOF(pos) 冻结，重复 next 恒同值）" {
  let data = @utf8.encode("a").to_array()
  let lexer = Lexermoon::new(data[:])
  let _ = lexer.next() // PrefName(0,1)
  assert_true(
    match lexer.next() {
      Some(Token::EOF(1)) => true
      _ => false
    },
  )
  assert_true(
    match lexer.next() {
      Some(Token::EOF(1)) => true
      _ => false
    },
  )
}

///|
test "词法口径一致性: Lexermoon ≡ Lexerc（同输入同 token 流，EOF 归一化）" {
  // 分歧口径（2026-09-04）：字面量后缀门收紧后，`"text".` 形态 moon 出
  // Literal+Dot、C 版（FFI 冻结）仍吞点——该形态已移出共享电池，生产引擎
  // 只走 Lexermoon（from_bytes），C 版仅存于本对照测试
  for pair in lexer_test_battery() {
    let (input, _) = pair
    let data = @utf8.encode(input).to_fixedarray()
    let lexer = Lexerc::new(data)
    let buf = StringBuilder()
    for ;; {
      match lexer.next() {
        None => break // C 版以 None 收束（EOF token 不外露）
        Some(t) => {
          buf.write_string(lexer_test_fmt_token(t))
          buf.write_string(" ")
        }
      }
    }
    lexer.destroy()
    assert_eq(lexer_test_moon_stream(input), buf.to_string())
  }
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
      Some(Token::EOF(_)) => break
      Some(t) => println("\{lexer_test_fmt_token(t)}")
    }
  }
  assert_true(true)
}
