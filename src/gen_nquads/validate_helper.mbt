// ===== 组装后验证（用户手写版演进）=====
// 架构口径：词法器保持无脑扫，语法对错全部在此裁决（W3C rdf-n-quads 套件实证）。
// 验证在组装之后：span → view 切分完成后逐词项在 view 上校验；
// 错误 span 用 (全局基偏移 + 视图内偏移) 定位，供上层 read_context 诊断。

///|
fn[L] SliceParser::validate(
  self : SliceParser[L],
  pending : NQuadsPendingQuad,
) -> Result[QuadSpan, ParseError] {
  // 提取 span 并切分 data（零拷贝视图；失败路径只报错不持数据）
  let (subj_off, subj_len) = pending.subj.unwrap_or((0, 0))
  let (pred_off, pred_len) = pending.pred.unwrap_or((0, 0))
  let (obj_off, obj_len) = pending.obj.unwrap_or((0, 0))

  // 边界检查（短路序：先界后索引）
  if subj_len <= 0 || subj_off < 0 || subj_off + subj_len > self.data.length() {
    return Err(
      ParseError::SyntaxErr(
        "Invalid subject span",
        pending.subj.unwrap_or((0, 0)),
      ),
    )
  }
  if pred_len <= 0 || pred_off < 0 || pred_off + pred_len > self.data.length() {
    return Err(
      ParseError::SyntaxErr(
        "Invalid predicate span",
        pending.pred.unwrap_or((0, 0)),
      ),
    )
  }
  if obj_len <= 0 || obj_off < 0 || obj_off + obj_len > self.data.length() {
    return Err(
      ParseError::SyntaxErr(
        "Invalid object span",
        pending.obj.unwrap_or((0, 0)),
      ),
    )
  }

  let subject = self.data[subj_off:subj_off + subj_len]
  let predicate = self.data[pred_off:pred_off + pred_len]
  let object = self.data[obj_off:obj_off + obj_len]

  // 类型探测：主语不可能为 Literal（nquads 语法），字面量起头的主语按 IRI 校验必败
  let subj_type = if subject[0] == b'_' {
    TermType::BNode
  } else {
    TermType::Iri
  }
  let obj_type = if object[0] == b'_' {
    TermType::BNode
  } else if object[0] == b'"' || object[0] == b'\'' {
    TermType::Literal
  } else if object.length() >= 3 &&
    object[0] == b'<' &&
    object[1] == b'<' &&
    object[2] == b'(' {
    TermType::TripleTerm
  } else {
    TermType::Iri
  }

  // 严格模式：逐词项验证（谓语恒为 IRI）
  if !self.lenient {
    match validate_iri(predicate, pred_off) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
    if subj_type == TermType::BNode {
      match validate_bnode(subject, subj_off) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    } else {
      match validate_iri(subject, subj_off) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    if obj_type == TermType::BNode {
      match validate_bnode(object, obj_off) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    } else if obj_type == TermType::Literal {
      match validate_literal(object, obj_off, self.rdf12) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    } else if obj_type == TermType::TripleTerm {
      match validate_triple_term(object, obj_off, self.rdf12) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    } else {
      match validate_iri(object, obj_off) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
  }

  // 图名（第 4 元素）：同样按 BNode / IRI 校验
  let (g_off, g_len) = pending.graph.unwrap_or((0, 0))
  if g_len > 0 {
    if g_off < 0 || g_off + g_len > self.data.length() {
      return Err(
        ParseError::SyntaxErr(
          "Invalid graph span",
          pending.graph.unwrap_or((0, 0)),
        ),
      )
    }
    if !self.lenient {
      let graph_view = self.data[g_off:g_off + g_len]
      if graph_view[0] == b'_' {
        match validate_bnode(graph_view, g_off) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      } else {
        match validate_iri(graph_view, g_off) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      }
    }
  }
  let graph = if g_len > 0 {
    Some(self.data[g_off:g_off + g_len])
  } else {
    None
  }

  Ok({
    subj: subject,
    pred: predicate,
    obj: object,
    graph,
    subj_type,
    obj_type,
  })
}

///|
/// IRI 验证（view 直查 + 全局基偏移定位）：
/// <> 包裹非空 + 绝对 scheme（[A-Za-z][A-Za-z0-9+.-]*:）+ RFC 3986 禁用字符集外。
/// 相对 IRI（<g> <p> <dt> 等）在此拒绝
fn validate_iri(iri : ArrayView[Byte], base : Int) -> Result[Unit, ParseError] {
  let len = iri.length()
  if len < 2 || iri[0] != b'<' || iri[len - 1] != b'>' {
    return Err(ParseError::SyntaxErr("IRI must be wrapped in <>", (base, len)))
  }
  if len == 2 {
    return Err(ParseError::SyntaxErr("IRI cannot be empty", (base, len)))
  }
  if !is_alpha(iri[1]) {
    return Err(
      ParseError::SyntaxErr(
        "IRI must be absolute (scheme required)",
        (base + 1, 1),
      ),
    )
  }
  // scheme 尾：字母数字与 + - . 直到冒号
  let mut i = 2
  while i < len - 1 && iri[i] != b':' {
    let c = iri[i]
    if !(is_alpha(c) ||
      (c >= b'0' && c <= b'9') ||
      c == b'+' ||
      c == b'-' ||
      c == b'.') {
      return Err(
        ParseError::SyntaxErr(
          "IRI must be absolute (scheme required)",
          (base + i, 1),
        ),
      )
    }
    i = i + 1
  }
  if i >= len - 1 {
    return Err(
      ParseError::SyntaxErr(
        "IRI must be absolute (scheme required)",
        (base + 1, len - 2),
      ),
    )
  }
  // scheme 之后：禁字符/转义扫描抽为可复用原语（trig 侧相对 IRI 也走此段）
  match validate_iri_body(iri, base, i, len) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
/// IRI 禁字符/转义扫描原语（view 直查 + 全局基偏移）：
/// 扫 [start, end)：禁用 " { } | ^ ` 与控制/空格（< > 已由包裹定界排除）；
/// 反斜杠仅允许 UCHAR 转义 \uXXXX / \UXXXXXXXX，其余一律非法。
/// pub 供跨包复用（trig 相对 IRI 的 charset 段），nquads 内部由 validate_iri 调用
pub fn validate_iri_body(
  iri : ArrayView[Byte],
  base : Int,
  start : Int,
  end : Int,
) -> Result[Unit, ParseError] {
  // 边界约定：iri[end-1] 是闭 '>'，内容区 = [start, end-1)（与 nquads span 同构）
  let body_end = end - 1
  let mut i = start
  while i < body_end {
    let c = iri[i]
    if c == b'\\' {
      if i + 1 >= body_end {
        return Err(
          ParseError::SyntaxErr(
            "IRI contains forbidden character",
            (base + i, 1),
          ),
        )
      }
      let e = iri[i + 1]
      let n = if e == b'u' {
        4
      } else if e == b'U' {
        8
      } else {
        return Err(ParseError::SyntaxErr("Bad IRI escape", (base + i, 2)))
      }
      if i + 1 + n > body_end - 1 {
        return Err(ParseError::SyntaxErr("Bad IRI escape", (base + i, n + 2)))
      }
      for k in 1..<=n {
        if !is_hex_byte(iri[i + 1 + k]) {
          return Err(
            ParseError::SyntaxErr("Bad IRI escape", (base + i + 1 + k, 1)),
          )
        }
      }
      // 解码码点复核（eval-bad-01..03 "good escape, bad character" /
      // bad-numeric-escape-09/10 代理区）：UCHAR 语法合法不够——解码值须为
      // Unicode 标量（非代理区、不越 0x10FFFF）且落在 IRIREF 允许集内
      let mut cp = 0
      for k in 1..<=n {
        let d = iri[i + 1 + k]
        let v = if d >= b'0' && d <= b'9' {
          d.to_int() - 0x30
        } else if d >= b'a' && d <= b'f' {
          d.to_int() - 0x61 + 10
        } else {
          d.to_int() - 0x41 + 10
        }
        cp = cp * 16 + v
      }
      if (cp >= 0xD800 && cp <= 0xDFFF) || cp > 0x10FFFF {
        return Err(
          ParseError::SyntaxErr(
            "IRI escape must be a Unicode scalar value",
            (base + i, n + 2),
          ),
        )
      }
      if cp < 0x21 ||
        cp == 0x22 || // "
        cp == 0x3C || // <
        cp == 0x3E || // >
        cp == 0x5C || // backslash
        cp == 0x7B || // {
        cp == 0x7C || // |
        cp == 0x7D || // }
        cp == 0x5E || // ^
        cp == 0x60 { // `
        return Err(
          ParseError::SyntaxErr(
            "IRI escape decodes to forbidden character",
            (base + i, n + 2),
          ),
        )
      }
      i = i + n + 2
    } else if c < b'!' ||
      c == b'"' ||
      c == b'{' ||
      c == b'}' ||
      c == b'|' ||
      c == b'^' ||
      c == b'`' {
      return Err(
        ParseError::SyntaxErr("IRI contains forbidden character", (base + i, 1)),
      )
    } else {
      i = i + 1
    }
  }
  Ok(())
}

///|
/// BNode 验证：_: 前缀 + 标签；W3C BLANK_NODE_LABEL 允许数字起头，标签不以 . 收尾
/// （pub：跨包复用，trig 组装后深验直接调用）
pub fn validate_bnode(
  bnode : ArrayView[Byte],
  base : Int,
) -> Result[Unit, ParseError] {
  let len = bnode.length()
  if len < 3 || bnode[0] != b'_' || bnode[1] != b':' {
    return Err(
      ParseError::SyntaxErr("Blank node must start with _:", (base, len)),
    )
  }
  let first = bnode[2]
  if !((first >= b'a' && first <= b'z') ||
    (first >= b'A' && first <= b'Z') ||
    (first >= b'0' && first <= b'9') ||
    first == b'_') {
    return Err(
      ParseError::SyntaxErr(
        "Blank node label must start with letter, digit or underscore",
        (base + 2, 1),
      ),
    )
  }
  // 正常应被引擎尾点裁决掉，此处双保险
  if bnode[len - 1] == b'.' {
    return Err(
      ParseError::SyntaxErr(
        "Blank node label must not end with '.'",
        (base + len - 1, 1),
      ),
    )
  }
  Ok(())
}

///|
/// 十六进制字节（\u / \U 转义校验用）
fn is_hex_byte(c : Byte) -> Bool {
  (c >= b'0' && c <= b'9') ||
  (c >= b'a' && c <= b'f') ||
  (c >= b'A' && c <= b'F')
}

///|
/// 字符串体扫描原语（跨包复用，nquads validate_literal 内部亦走此）：
/// 扫 [start, len)：转义成对消费（\u 后 4 位 / \U 后 8 位十六进制、通用转义字符），
/// 连续 quote_run 个引号 q 为闭定界，返回闭定界起点。
/// quote_run=1 = 单引号串（N-Quads）；=3 = 三引号长串（TriG/Turtle，体内单个 " 合法）
pub fn scan_string_body(
  lit : ArrayView[Byte],
  base : Int,
  start : Int,
  quote_run : Int,
) -> Result[Int, ParseError] {
  let len = lit.length()
  let q = lit[0]
  let mut i = start
  while i < len {
    let c = lit[i]
    if c == b'\\' {
      if i + 1 >= len {
        return Err(ParseError::SyntaxErr("Bad string escape", (base + i, 1)))
      }
      let e = lit[i + 1]
      if e == b'"' ||
        e == b'\'' ||
        e == b'\\' ||
        e == b'b' ||
        e == b'f' ||
        e == b'n' ||
        e == b'r' ||
        e == b't' {
        i = i + 2
      } else if e == b'u' {
        if i + 6 > len {
          return Err(
            ParseError::SyntaxErr("Bad string escape", (base + i, len - i)),
          )
        }
        for k in 2..<6 {
          if !is_hex_byte(lit[i + k]) {
            return Err(
              ParseError::SyntaxErr("Bad string escape", (base + i + k, 1)),
            )
          }
        }
        i = i + 6
      } else if e == b'U' {
        if i + 10 > len {
          return Err(
            ParseError::SyntaxErr("Bad string escape", (base + i, len - i)),
          )
        }
        for k in 2..<10 {
          if !is_hex_byte(lit[i + k]) {
            return Err(
              ParseError::SyntaxErr("Bad string escape", (base + i + k, 1)),
            )
          }
        }
        i = i + 10
      } else {
        return Err(ParseError::SyntaxErr("Bad string escape", (base + i, 2)))
      }
    } else if c == q {
      let mut r = 1
      while r < quote_run && i + r < len && lit[i + r] == q {
        r = r + 1
      }
      if r == quote_run {
        return Ok(i)
      }
      i = i + 1
    } else {
      i = i + 1
    }
  }
  Err(ParseError::SyntaxErr("Unterminated literal", (base, len)))
}

///|
/// @lang 后缀验证原语（BCP47 字节版，零分配；跨包复用）：
/// lit[at] 是 '@'，标签必须消费到 len（span 尾即标签尾）。
/// 主子标签字母 2-3 或 5-8（4 无效），'-' 子标签字母数字 1-8；
/// rdf12=true 接受 --ltr/--rtl 方向后缀（小写精确），false 一律拒绝
pub fn validate_lang_suffix(
  lit : ArrayView[Byte],
  base : Int,
  at : Int,
  len : Int,
  rdf12 : Bool,
) -> Result[Unit, ParseError] {
  let tail = at + 1
  if tail >= len {
    return Err(
      ParseError::SyntaxErr(
        "Language tag must start with a letter",
        (base + at, 1),
      ),
    )
  }
  let mut i = tail
  // 主子标签
  while i < len && is_alpha(lit[i]) {
    i = i + 1
  }
  let n = i - tail
  if n == 0 {
    return Err(
      ParseError::SyntaxErr(
        "Language tag must start with a letter",
        (base + at, 1),
      ),
    )
  }
  if !(n >= 2 && n <= 3) && !(n >= 5 && n <= 8) {
    return Err(
      ParseError::SyntaxErr(
        "Language tag primary subtag length must be 2-3 or 5-8 (BCP47)",
        (base + tail, n),
      ),
    )
  }
  // '-' 子标签；空子标签（'--'）跳出交给方向后缀裁决
  while i < len && lit[i] == b'-' {
    let mut m = 0
    while i + 1 + m < len &&
          (
            is_alpha(lit[i + 1 + m]) ||
            (lit[i + 1 + m] >= b'0' && lit[i + 1 + m] <= b'9')
          ) {
      m = m + 1
    }
    if m == 0 {
      break
    }
    if m > 8 {
      return Err(
        ParseError::SyntaxErr(
          "Language tag subtag must be at most 8 characters",
          (base + i + 1, m),
        ),
      )
    }
    i = i + 1 + m
  }
  // RDF 1.2 方向后缀：'--ltr' / '--rtl'（小写精确）；1.1 口径一律拒绝
  if i < len && lit[i] == b'-' && i + 1 < len && lit[i + 1] == b'-' {
    let dir_ok = rdf12 &&
      i + 5 == len &&
      (
        (lit[i + 2] == b'l' && lit[i + 3] == b't' && lit[i + 4] == b'r') ||
        (lit[i + 2] == b'r' && lit[i + 3] == b't' && lit[i + 4] == b'l')
      )
    if !dir_ok {
      let msg = if rdf12 {
        "Direction must be '--ltr' or '--rtl'"
      } else {
        "Directional language tags are not allowed in RDF 1.1"
      }
      return Err(ParseError::SyntaxErr(msg, (base + i, len - i)))
    }
    i = len
  }
  if i != len {
    return Err(
      ParseError::SyntaxErr(
        "Unexpected content after language tag",
        (base + i, len - i),
      ),
    )
  }
  Ok(())
}

///|
/// \u/\U 转义码点检查原语（surrogate 深验；跨包复用）：
/// 扫 [start, end)：孤代理（高位 D800-DBFF 无配对低代理 / 无前驱的低位 DC-DFFF）
/// 拒绝；十六进制合法性由 scan_string_body 保证，此处只裁决码点。
/// scalar_only（RDF 1.2 严格口径，默认关）：代理一律拒——每个 UCHAR 须独立
/// 解码为 Unicode 标量值，成对代理（\uD83C\uDCA1 编码 SMP）也不收
///（surrogate-pair-bad 口径；1.1 宽容口径成对合法，故做开关不做全局）
pub fn validate_escapes_unicode(
  lit : ArrayView[Byte],
  base : Int,
  start : Int,
  end : Int,
  scalar_only? : Bool = false,
) -> Result[Unit, ParseError] {
  let mut i = start
  while i < end {
    let c = lit[i]
    if c == b'\\' && i + 1 < end && (lit[i + 1] == b'u' || lit[i + 1] == b'U') {
      let n = if lit[i + 1] == b'u' { 4 } else { 8 }
      if i + 2 + n > end {
        return Err(
          ParseError::SyntaxErr("Bad string escape", (base + i, end - i)),
        )
      }
      let mut cp = 0
      for k in 0..<n {
        cp = cp * 16 + hex_val(lit[i + 2 + k])
      }
      if scalar_only && cp >= 0xD800 && cp <= 0xDFFF {
        return Err(
          ParseError::SyntaxErr(
            "Surrogate escape is not a Unicode scalar value",
            (base + i, n + 2),
          ),
        )
      }
      if cp >= 0xD800 && cp <= 0xDBFF {
        // 高代理：必须紧跟一个码点落在 DC00-DFFF 的转义（\u/\U 形式不限）
        let j = i + 2 + n
        let mut ok = false
        let mut n2 = 0
        if j + 2 <= end &&
          lit[j] == b'\\' &&
          (lit[j + 1] == b'u' || lit[j + 1] == b'U') {
          n2 = if lit[j + 1] == b'u' { 4 } else { 8 }
          if j + 2 + n2 <= end {
            let mut cp2 = 0
            for k in 0..<n2 {
              cp2 = cp2 * 16 + hex_val(lit[j + 2 + k])
            }
            if cp2 >= 0xDC00 && cp2 <= 0xDFFF {
              ok = true
            }
          }
        }
        if !ok {
          return Err(
            ParseError::SyntaxErr(
              "Lone high surrogate in escape",
              (base + i, n + 2),
            ),
          )
        }
        i = j + 2 + n2 // 成对代理一并消费，防低代理被下一轮误判孤侧
      } else if cp >= 0xDC00 && cp <= 0xDFFF {
        return Err(
          ParseError::SyntaxErr(
            "Lone low surrogate in escape",
            (base + i, n + 2),
          ),
        )
      } else {
        i = i + 2 + n
      }
    } else {
      i = i + 1
    }
  }
  Ok(())
}

///|
/// 十六进制字节 → 数值（validate_escapes_unicode 专用；合法性已由上游保证）
fn hex_val(c : Byte) -> Int {
  if c >= b'0' && c <= b'9' {
    (c - b'0').to_int()
  } else if c >= b'a' && c <= b'f' {
    (c - b'a').to_int() + 10
  } else {
    (c - b'A').to_int() + 10
  }
}

///|
/// Literal 验证（N-Quads 口径）：
///   单引号对（三引号是 Turtle/TriG 语法，N-Quads 无）+ 转义合法性
///   （\u 后 4 位 / \U 后 8 位十六进制）+ @lang 首字符为字母
///   + ^^<绝对 IRI> + 闭引号后不得有残余（无脑扫吞入的 . ; , 尾巴在此裁决）
/// rdf12=true（RDF 1.2，默认）：接受 --ltr/--rtl 方向后缀，禁止显式 langString/dirLangString
/// rdf12=false（1.1 严格契约）：langdir 一律拒绝
fn validate_literal(
  lit : ArrayView[Byte],
  base : Int,
  rdf12 : Bool,
) -> Result[Unit, ParseError] {
  let len = lit.length()
  if len < 2 || (lit[0] != b'"' && lit[0] != b'\'') {
    return Err(ParseError::SyntaxErr("Malformed literal", (base, len)))
  }
  let q = lit[0]
  if len >= 3 && lit[1] == q && lit[2] == q {
    return Err(
      ParseError::SyntaxErr("Long strings are not valid in N-Quads", (base, 3)),
    )
  }
  // 内容扫描：转义成对消费，定位配对闭引号（原语复用：单引号口径 quote_run=1）
  let close = match scan_string_body(lit, base, 1, 1) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  // 闭引号之后：@lang / ^^<datatype>，其余残余一律拒绝
  if close + 1 < len {
    let s = lit[close + 1]
    if s == b'@' {
      // BCP47 口径（与对象级 LanguageTag 一致），原语复用（验证热路径零分配）
      match validate_lang_suffix(lit, base, close + 1, len, rdf12) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    } else if s == b'^' {
      if close + 3 >= len || lit[close + 2] != b'^' || lit[close + 3] != b'<' {
        return Err(
          ParseError::SyntaxErr(
            "Datatype must be an IRI (^^<...>)",
            (base + close + 1, 2),
          ),
        )
      }
      match validate_iri(lit[close + 3:len], base + close + 3) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      // RDF 1.2：langString/dirLangString 只能由 @lang 派生，显式 ^^ 写法非法
      // （口径：按 #后缀 判定，与 rdf: 命名空间约定一致）
      if rdf12 && is_banned_langstring_iri(lit[close + 3:len]) {
        return Err(
          ParseError::SyntaxErr(
            "langString/dirLangString cannot be written explicitly (use @lang)",
            (base + close + 3, len - close - 3),
          ),
        )
      }
    } else {
      return Err(
        ParseError::SyntaxErr(
          "Unexpected content after literal",
          (base + close + 1, 1),
        ),
      )
    }
  }
  Ok(())
}

///|
/// RDF 1.2 禁令：显式写的 rdf:langString / rdf:dirLangString datatype。
/// 口径：按 `#langString>` / `#dirLangString>` 后缀判定（零分配字节比对）
/// （pub：跨包复用，trig 的 ^^<IRI> datatype 分支同口径）
pub fn is_banned_langstring_iri(view : ArrayView[Byte]) -> Bool {
  let n = view.length()
  if n >= 12 {
    let s = n - 12
    if view[s] == b'#' &&
      view[s + 1] == b'l' &&
      view[s + 2] == b'a' &&
      view[s + 3] == b'n' &&
      view[s + 4] == b'g' &&
      view[s + 5] == b'S' &&
      view[s + 6] == b't' &&
      view[s + 7] == b'r' &&
      view[s + 8] == b'i' &&
      view[s + 9] == b'n' &&
      view[s + 10] == b'g' &&
      view[s + 11] == b'>' {
      return true
    }
  }
  if n >= 15 {
    let s = n - 15
    if view[s] == b'#' &&
      view[s + 1] == b'd' &&
      view[s + 2] == b'i' &&
      view[s + 3] == b'r' &&
      view[s + 4] == b'L' &&
      view[s + 5] == b'a' &&
      view[s + 6] == b'n' &&
      view[s + 7] == b'g' &&
      view[s + 8] == b'S' &&
      view[s + 9] == b't' &&
      view[s + 10] == b'r' &&
      view[s + 11] == b'i' &&
      view[s + 12] == b'n' &&
      view[s + 13] == b'g' &&
      view[s + 14] == b'>' {
      return true
    }
  }
  false
}

///|
test "rdf12 开关: langdir 按 1.2 接受 / 按 1.1 拒绝" {
  let input = "<http://e.org/s> <http://e.org/p> \"Hello\"@en--ltr .\n"
  let data = @utf8.encode(input).to_array()
  let (q12, e12) = nquads_parser(data, rdf12=true)
  assert_true(e12.is_empty() && q12.length() == 1)
  let (q11, e11) = nquads_parser(data, rdf12=false)
  assert_true(e11.length() > 0 && q11.is_empty())
}

///|
test "rdf12 规则: 坏方向/坏长度/显式 langString 全部拒绝（默认 1.2 口径）" {
  let cases = [
    "<http://e.org/s> <http://e.org/p> \"H\"@en--unk .\n", "<http://e.org/s> <http://e.org/p> \"H\"@en--LTR .\n",
    "<http://e.org/s> <http://e.org/p> \"H\"@cantbethislong .\n", "<http://e.org/s> <http://e.org/p> \"H\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#langString> .\n",
    "<http://e.org/s> <http://e.org/p> \"H\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#dirLangString> .\n",
  ]
  for case in cases {
    let data = @utf8.encode(case).to_array()
    let (_, errors) = nquads_parser(data)
    assert_true(errors.length() > 0)
  }
}

///|
test "1.1/1.2 通用: 常规 langtag 两版都过" {
  let input = "<http://e.org/s> <http://e.org/p> \"chat\"@fr-FR .\n"
  let data = @utf8.encode(input).to_array()
  let (q12, e12) = nquads_parser(data, rdf12=true)
  assert_true(e12.is_empty() && q12.length() == 1)
  let (q11, e11) = nquads_parser(data, rdf12=false)
  assert_true(e11.is_empty() && q11.length() == 1)
}

///|
/// 三元组词项扫描辅助：词项间空白跳过（词项自定界，空白可有可无）
fn tt_skip_ws(view : ArrayView[Byte], start : Int) -> Int {
  let mut i = start
  let n = view.length()
  while i < n &&
        (
          view[i] == b' ' ||
          view[i] == b'\t' ||
          view[i] == b'\r' ||
          view[i] == b'\n'
        ) {
    i = i + 1
  }
  i
}

///|
/// 词项终点扫描（三元组词项内部专用）：返回词项终点（不含）。
/// 词项自定界：IRI 扫到 >；BNode 扫名字尾；Literal 扫配对闭引号 + @/^^ 后缀
/// （转义感知）；TripleTerm 平衡扫描。未知起点原样返回，交由 validate_* 报错。
/// 零分配：view 直查纯字节分支（宪法：验证热路径不做对象级解析）
fn tt_term_end(view : ArrayView[Byte], start : Int) -> Int {
  let mut i = start
  let n = view.length()
  let c = view[i]
  if c == b'<' {
    if i + 2 < n && view[i + 1] == b'<' && view[i + 2] == b'(' {
      // 嵌套三元组词项：深度计数到配对闭壳（与词法同机械）
      i = i + 3
      let mut depth = 1
      while i + 2 < n && depth > 0 {
        if view[i] == b'<' && view[i + 1] == b'<' && view[i + 2] == b'(' {
          depth = depth + 1
          i = i + 3
        } else if view[i] == b')' && view[i + 1] == b'>' && view[i + 2] == b'>' {
          depth = depth - 1
          i = i + 3
        } else {
          i = i + 1
        }
      }
      i
    } else {
      i = i + 1
      while i < n && view[i] != b'>' {
        i = i + 1
      }
      if i < n {
        i + 1
      } else {
        i
      }
    }
  } else if c == b'_' {
    // 与词法器同口径：_: 前缀 + 名字字符（: 不是名字字符，须显式消费）
    i = i + 1
    if i < n && view[i] == b':' {
      i = i + 1
      while i < n && is_name_char(view[i]) {
        i = i + 1
      }
    }
    i
  } else if c == b'"' || c == b'\'' {
    let q = c
    i = i + 1
    while i < n && view[i] != q {
      if view[i] == b'\\' && i + 1 < n {
        i = i + 2
      } else {
        i = i + 1
      }
    }
    if i < n {
      i = i + 1 // 闭引号
    }
    // 后缀：@lang（字母数字-）/ ^^<IRI>；其余字符自然收束词项边界
    if i < n && view[i] == b'@' {
      i = i + 1
      while i < n &&
            (
              is_alpha(view[i]) ||
              (view[i] >= b'0' && view[i] <= b'9') ||
              view[i] == b'-'
            ) {
        i = i + 1
      }
    } else if i + 1 < n && view[i] == b'^' && view[i + 1] == b'^' {
      i = i + 2
      if i < n && view[i] == b'<' {
        while i < n && view[i] != b'>' {
          i = i + 1
        }
        if i < n {
          i = i + 1
        }
      }
    }
    i
  } else {
    i
  }
}

///|
/// 三元组词项验证（RDF 1.2，view 直查 + 全局基偏移，零分配）：
/// 壳 `<<( ... )>>`，内部恰三个自定界词项（空白可有可无）：
///   s: IRI | BNode    p: IRI    o: IRI | BNode | Literal | TripleTerm（可嵌套）
/// 位置规则在此裁决（主语/谓语不得为字面量等）；词项内部细节复用各 validate_*。
/// rdf12 沿传：嵌套词项内的 langdir/显式 langString 禁令与外层同口径
fn validate_triple_term(
  tt : ArrayView[Byte],
  base : Int,
  rdf12 : Bool,
) -> Result[Unit, ParseError] {
  let len = tt.length()
  // 壳检查：<<( ... )>>
  if len < 6 ||
    tt[0] != b'<' ||
    tt[1] != b'<' ||
    tt[2] != b'(' ||
    tt[len - 3] != b')' ||
    tt[len - 2] != b'>' ||
    tt[len - 1] != b'>' {
    return Err(
      ParseError::SyntaxErr(
        "Triple term must be wrapped in <<( )>>",
        (base, len),
      ),
    )
  }
  let inner_base = base + 3
  let inner = tt[3:len - 3]
  let n = inner.length()
  let mut i = 0
  // --- 主语：IRI | BNode（字面量按 IRI 校验必败，与外层同口径） ---
  i = tt_skip_ws(inner, i)
  if i >= n {
    return Err(ParseError::SyntaxErr("Triple term is empty", (inner_base, n)))
  }
  let s_start = i
  let s_end = tt_term_end(inner, i)
  if s_end == s_start {
    return Err(
      ParseError::SyntaxErr(
        "Bad triple term subject",
        (inner_base + s_start, 1),
      ),
    )
  }
  let sv = inner[s_start:s_end]
  if sv[0] == b'_' {
    match validate_bnode(sv, inner_base + s_start) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  } else {
    match validate_iri(sv, inner_base + s_start) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  i = s_end
  // --- 谓语：IRI ---
  i = tt_skip_ws(inner, i)
  if i >= n {
    return Err(
      ParseError::SyntaxErr(
        "Triple term missing predicate",
        (inner_base + i, 1),
      ),
    )
  }
  let p_start = i
  let p_end = tt_term_end(inner, i)
  if p_end == p_start {
    return Err(
      ParseError::SyntaxErr(
        "Bad triple term predicate",
        (inner_base + p_start, 1),
      ),
    )
  }
  match validate_iri(inner[p_start:p_end], inner_base + p_start) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  i = p_end
  // --- 宾语：IRI | BNode | Literal | TripleTerm（嵌套递归） ---
  i = tt_skip_ws(inner, i)
  if i >= n {
    return Err(
      ParseError::SyntaxErr("Triple term missing object", (inner_base + i, 1)),
    )
  }
  let o_start = i
  let o_end = tt_term_end(inner, i)
  if o_end == o_start {
    return Err(
      ParseError::SyntaxErr("Bad triple term object", (inner_base + o_start, 1)),
    )
  }
  let ov = inner[o_start:o_end]
  let oc = ov[0]
  if oc == b'_' {
    match validate_bnode(ov, inner_base + o_start) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  } else if oc == b'"' || oc == b'\'' {
    match validate_literal(ov, inner_base + o_start, rdf12) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  } else if ov.length() >= 3 && oc == b'<' && ov[1] == b'<' && ov[2] == b'(' {
    match validate_triple_term(ov, inner_base + o_start, rdf12) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  } else {
    match validate_iri(ov, inner_base + o_start) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  i = o_end
  // --- 收尾：恰三词项，残余一律拒绝 ---
  i = tt_skip_ws(inner, i)
  if i != n {
    return Err(
      ParseError::SyntaxErr(
        "Unexpected content after triple term object",
        (inner_base + i, n - i),
      ),
    )
  }
  Ok(())
}

///|
test "三元组词项: 正例（常规/零空白/嵌套/bnode 主语）全过" {
  let r = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies>"
  let cases = [
    "<http://example/a> \{r} <<( <http://example/s> <http://example/p> <http://example/o> )>> .\n",
    "<http://example/s>\{r}<<( <http://example/s2><http://example/p2><http://example/o2> )>>.\n",
    "<http://example/a>\{r}<<( <http://example/s2><http://example/q2><<( <http://example/s3><http://example/p3><http://example/o3> )>> )>>.\n",
    "_:b1 \{r} <<( _:b0 <http://example/p> <http://example/o> )>> .\n",
    "<http://example/a> \{r} <<( <http://example/s> <http://example/p> \"lit\"@en--ltr )>> .\n",
  ]
  for case in cases {
    let data = @utf8.encode(case).to_array()
    let (quads, errors) = nquads_parser(data)
    assert_true(errors.is_empty())
    assert_true(quads.length() == 1)
  }
}

///|
test "三元组词项: 负例全拒（字面量主/谓、旧式 << >>、主语位/谓语位/图名位、残余）" {
  let r = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies>"
  let cases = [
    // 字面量主语 / 字面量谓语（壳内位置规则）
    "<http://example/q> \{r} <<( \"XYZ\" <http://example/p> <http://example/o> )>> .\n",
    "<http://example/q> \{r} <<( <http://example/s> \"XYZ\" <http://example/o> )>> .\n",
    // 旧式 << >> 无括号：词法保持垃圾，验证/引擎拒绝
    "<http://example/x> <http://example/p> << <http://example/s> <http://example/p> <http://example/o> >> .\n",
    // 三元组词项落主语位（表无此边）
    "<<( <http://example/s> <http://example/p> <http://example/o> )>> <http://example/a> <http://example/z> .\n",
    // 三元组词项落谓语位（表无此边）
    "<http://example/a> <<( <http://example/s> <http://example/p> <http://example/o> )>> <http://example/z> .\n",
    // 壳内多余残余
    "<http://example/q> \{r} <<( <http://example/s> <http://example/p> <http://example/o> <http://example/x> )>> .\n",
  ]
  for case in cases {
    let data = @utf8.encode(case).to_array()
    let (_, errors) = nquads_parser(data)
    assert_true(errors.length() > 0)
  }
}
