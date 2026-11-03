// ============================================================
// 规范形序列化器（Canonical N-Triples / N-Quads；RDF 1.2 §Canonical form）
// ------------------------------------------------------------
// 与 serialize_nquads.mbt 的字节保真回写相对：本面从词项 span 解码后
// 按规范形律重编（c14n 套件门 = rdf_suite_wbtest 的 run_c14n_suite）。
// 律（规范 §Canonical + 语料期望件双钉）：
//   · 词间单空格，行尾 " ." + LF，尾行必 LF；顺序保持，不排序不去重
//   · ECHAR 集出两字符形（\t \b \n \r \f \" \\）——' 不在其中，原样
//   · 必转义集走 \u + 4 位大写 HEX：C0 控制符（ECHAR 集除外）、DEL、
//     代理区、U+FFFE/U+FFFF（非 XML11 Char 全集）
//   · 其余码点原生 UTF-8（非 ASCII 可印字符不转义，U+FFFD 照写）
//   · xsd:string 数据型省略（"x"^^<...#string> → "x"）
//   · langtag 规范形小写（"@EN" → "@en"；--dir 段随同小写无伤）
//   · IRI 内 \u/\U 转义解出原生字符（nt-syntax-uri-02/03 实证）
//   · 复合项壳 <<( )>> 内单空格；内体手写三分（IRI/bnode/字面量/
//     嵌套壳深度计），不回引擎——内体词间空白可有可无皆收
//   · bnode 标签原文回写；字符串与标注间空白（词法器新律）剥除
// ============================================================

///|
/// 规范形文档化：quad 顺序保持，逐行 s SP p SP o [SP g] SP "." LF。
/// 输入 = 已验证 parse_all 产物；错误臂为防御钉（已验证输入不应触达）。
pub fn canonical_document(quads : Array[QuadSpan]) -> String raise ParseError {
  let buf = StringBuilder()
  for quad in quads {
    canonical_term(quad.subj_type, quad.subj, buf)
    buf.write_string(" ")
    canonical_term(TermType::Iri, quad.pred, buf)
    buf.write_string(" ")
    canonical_term(quad.obj_type, quad.obj, buf)
    match quad.graph {
      Some(graph) => {
        buf.write_string(" ")
        if graph[0] == b'_' {
          buf.write_string(span_text(graph))
        } else {
          canonical_iri(graph, buf)
        }
      }
      None => ()
    }
    buf.write_string(" .\n")
  }
  buf.to_string()
}

///|
/// 词项 span 原文解码（词法保证合法 UTF-8，解码无损）
fn span_text(view : ArrayView[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(view))
}

///|
/// 词项规范形分发
fn canonical_term(
  kind : TermType,
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Unit raise ParseError {
  match kind {
    TermType::Iri => canonical_iri(view, buf)
    TermType::BNode => buf.write_string(span_text(view))
    TermType::Literal => canonical_literal(view, buf)
    TermType::TripleTerm => canonical_triple_term(view, buf)
  }
}

///|
/// IRI 规范形：壳内 \u/\U 解出原生字符，其余原文
fn canonical_iri(
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Unit raise ParseError {
  canonical_iri_text(span_text(view), buf)
}

///|
/// IRI 文本规范形：\u/\U 转义解原生；UTF-16 代理对合成原生码点；
/// 必转义集（代理区/FFFE/FFFF）防御性回 \u 形
fn canonical_iri_text(
  text : String,
  buf : StringBuilder,
) -> Unit raise ParseError {
  let len = text.length()
  let mut i = 0
  while i < len {
    let u = text[i].to_int()
    if u == 0x5C && i + 1 < len {
      let e = text[i + 1].to_int()
      if e == 0x75 && i + 6 <= len {
        iri_emit_cp(hex_from_text(text, i + 2, 4), buf)
        i += 6
        continue
      }
      if e == 0x55 && i + 10 <= len {
        iri_emit_cp(hex_from_text(text, i + 2, 8), buf)
        i += 10
        continue
      }
      buf.write_char(Int32::unsafe_to_char(u))
      i += 1
      continue
    }
    if u >= 0xD800 && u <= 0xDBFF && i + 1 < len {
      let lo = text[i + 1].to_int()
      if lo >= 0xDC00 && lo <= 0xDFFF {
        buf.write_char(
          Int32::unsafe_to_char(((u - 0xD800) << 10) + (lo - 0xDC00) + 0x10000),
        )
        i += 2
        continue
      }
    }
    buf.write_char(Int32::unsafe_to_char(u))
    i += 1
  }
}

///|
/// 字面量规范形：转义感知找闭引号 → 体解码重编 + 尾段处理
/// （跨白剥除；@lang 小写；^^<dt> 壳原样内 IRI 规范形；xsd:string 省）
fn canonical_literal(
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Unit raise ParseError {
  let len = view.length()
  if len < 2 || view[0] != b'"' {
    raise ParseError::ValidationErr("canonical: literal must start with quote")
  }
  let mut close = -1
  let mut i = 1
  while i < len {
    let u = view[i].to_int()
    if u == 0x5C {
      i += 2
      continue
    }
    if u == 0x22 {
      close = i
      break
    }
    i += 1
  }
  if close < 0 {
    raise ParseError::ValidationErr("canonical: literal quote not closed")
  }
  buf.write_string("\"")
  canonical_body(view[1:close], buf)
  buf.write_string("\"")
  let mut suf = close + 1
  while suf < len && (view[suf] == b' ' || view[suf] == b'\t') {
    suf = suf + 1
  }
  if suf >= len {
    return
  }
  let head = view[suf]
  if head == b'^' {
    if suf + 1 >= len || view[suf + 1] != b'^' {
      raise ParseError::ValidationErr("canonical: bad datatype suffix")
    }
    let mut dt = suf + 2
    while dt < len && (view[dt] == b' ' || view[dt] == b'\t') {
      dt = dt + 1
    }
    if dt >= len || view[dt] != b'<' {
      raise ParseError::ValidationErr("canonical: bad datatype suffix")
    }
    let dt_text = span_text(view[dt:len])
    if dt_text == "<http://www.w3.org/2001/XMLSchema#string>" {
      return
    }
    buf.write_string("^^")
    canonical_iri_text(dt_text, buf)
    return
  }
  let suffix_text = span_text(view[suf:len])
  if head == b'@' {
    buf.write_string(ascii_lower(suffix_text))
  } else {
    buf.write_string(suffix_text)
  }
}

///|
/// ASCII 小写（langtag/dir 后缀域；非 ASCII 单位不动）
fn ascii_lower(text : String) -> String {
  let buf = StringBuilder()
  let len = text.length()
  let mut i = 0
  while i < len {
    let u = text[i].to_int()
    if u >= 0x41 && u <= 0x5A {
      buf.write_char(Int32::unsafe_to_char(u + 0x20))
    } else {
      buf.write_char(Int32::unsafe_to_char(u))
    }
    i += 1
  }
  buf.to_string()
}

///|
/// 体规范形：转义解码 → 律重编。输入十六进制大小写不限（词法已收），
/// 输出一律大写 HEX。
fn canonical_body(
  body : ArrayView[Byte],
  buf : StringBuilder,
) -> Unit raise ParseError {
  let len = body.length()
  let mut i = 0
  while i < len {
    let u = body[i].to_int()
    if u == 0x5C {
      if i + 1 >= len {
        raise ParseError::ValidationErr("canonical: dangling escape")
      }
      let e = body[i + 1].to_int()
      if e == 0x74 {
        canonical_escape(0x09, buf)
        i += 2
      } else if e == 0x62 {
        canonical_escape(0x08, buf)
        i += 2
      } else if e == 0x6E {
        canonical_escape(0x0A, buf)
        i += 2
      } else if e == 0x72 {
        canonical_escape(0x0D, buf)
        i += 2
      } else if e == 0x66 {
        canonical_escape(0x0C, buf)
        i += 2
      } else if e == 0x22 {
        canonical_escape(0x22, buf)
        i += 2
      } else if e == 0x5C {
        canonical_escape(0x5C, buf)
        i += 2
      } else if e == 0x27 {
        canonical_escape(0x27, buf)
        i += 2
      } else if e == 0x75 {
        if i + 6 > len {
          raise ParseError::ValidationErr("canonical: truncated \\u escape")
        }
        canonical_escape(hex_span(body, i + 2, 4), buf)
        i += 6
      } else if e == 0x55 {
        if i + 10 > len {
          raise ParseError::ValidationErr("canonical: truncated \\U escape")
        }
        canonical_escape(hex_span(body, i + 2, 8), buf)
        i += 10
      } else {
        raise ParseError::ValidationErr("canonical: unknown escape")
      }
      continue
    }
    let (cp, width) = utf8_decode(body, i)
    canonical_escape(cp, buf)
    i += width
  }
}

///|
/// 规范形字符发射：ECHAR 集两字符形；必转义集 \u 大写 HEX；
/// 其余原生 UTF-8（代理区已入必转义集，不触 unsafe_to_char 坏域）
fn canonical_escape(cp : Int32, buf : StringBuilder) -> Unit {
  if cp == 0x08 {
    buf.write_string("\\b")
  } else if cp == 0x09 {
    buf.write_string("\\t")
  } else if cp == 0x0A {
    buf.write_string("\\n")
  } else if cp == 0x0C {
    buf.write_string("\\f")
  } else if cp == 0x0D {
    buf.write_string("\\r")
  } else if cp == 0x22 {
    buf.write_string("\\\"")
  } else if cp == 0x5C {
    buf.write_string("\\\\")
  } else {
    let must_uchar = cp < 0x20 ||
      cp == 0x7F ||
      (cp >= 0xD800 && cp <= 0xDFFF) ||
      cp == 0xFFFE ||
      cp == 0xFFFF
    if must_uchar {
      emit_uchar4(cp, buf)
    } else {
      buf.write_char(Int32::unsafe_to_char(cp))
    }
  }
}

///|
/// \u + 4 位大写 HEX 发射（必转义集用）
fn emit_uchar4(cp : Int32, buf : StringBuilder) -> Unit {
  buf.write_string("\\u")
  for k in 0..<4 {
    let digit = (cp >> ((3 - k) * 4)) & 0xF
    buf.write_char(hex_digit(digit))
  }
}

///|
/// IRI 内码点发射：IRIREF 无 ECHAR 形——非 XML11 Char（控制符/代理区/
/// FFFE/FFFF）一律 \u 大写 HEX，其余原生字符
fn iri_emit_cp(cp : Int32, buf : StringBuilder) -> Unit {
  let must_uchar = cp < 0x20 ||
    cp == 0x7F ||
    (cp >= 0xD800 && cp <= 0xDFFF) ||
    cp == 0xFFFE ||
    cp == 0xFFFF
  if must_uchar {
    emit_uchar4(cp, buf)
  } else {
    buf.write_char(Int32::unsafe_to_char(cp))
  }
}

///|
/// HEX 位 → 大写字符（0-9 / A-F）
fn hex_digit(digit : Int32) -> Char {
  Int32::unsafe_to_char(if digit < 10 { 0x30 + digit } else { 0x37 + digit })
}

///|
/// String 域十六进制段求值（IRI 内 \u/\U；位序高位在前，大小写不限）
fn hex_from_text(
  text : String,
  start : Int32,
  digits : Int32,
) -> Int32 raise ParseError {
  let mut value = 0
  for k in 0..<digits {
    let c = text[start + k].to_int()
    let d = if c >= 0x30 && c <= 0x39 {
      c - 0x30
    } else if c >= 0x41 && c <= 0x46 {
      c - 0x37
    } else if c >= 0x61 && c <= 0x66 {
      c - 0x57
    } else {
      raise ParseError::ValidationErr("canonical: bad hex digit")
    }
    value = value * 16 + d
  }
  value
}

///|
/// Byte 域十六进制段求值（字符串体 \u/\U；位序高位在前）
fn hex_span(
  body : ArrayView[Byte],
  start : Int32,
  digits : Int32,
) -> Int32 raise ParseError {
  let mut value = 0
  for k in 0..<digits {
    let c = body[start + k].to_int()
    let d = if c >= 0x30 && c <= 0x39 {
      c - 0x30
    } else if c >= 0x41 && c <= 0x46 {
      c - 0x37
    } else if c >= 0x61 && c <= 0x66 {
      c - 0x57
    } else {
      raise ParseError::ValidationErr("canonical: bad hex digit")
    }
    value = value * 16 + d
  }
  value
}

///|
/// 原生 UTF-8 多字节解码（词法保证合法序列；防御性截断报错）
fn utf8_decode(
  body : ArrayView[Byte],
  at : Int32,
) -> (Int32, Int32) raise ParseError {
  let lead = body[at].to_int()
  let need = if lead < 0x80 {
    1
  } else if lead < 0xE0 {
    2
  } else if lead < 0xF0 {
    3
  } else {
    4
  }
  if at + need > body.length() {
    raise ParseError::ValidationErr("canonical: truncated UTF-8 sequence")
  }
  if lead < 0x80 {
    (lead, 1)
  } else if lead < 0xE0 {
    let value = ((lead & 0x1F) << 6) | (body[at + 1].to_int() & 0x3F)
    (value, 2)
  } else if lead < 0xF0 {
    let value = ((lead & 0x0F) << 12) |
      ((body[at + 1].to_int() & 0x3F) << 6) |
      (body[at + 2].to_int() & 0x3F)
    (value, 3)
  } else {
    let value = ((lead & 0x07) << 18) |
      ((body[at + 1].to_int() & 0x3F) << 12) |
      ((body[at + 2].to_int() & 0x3F) << 6) |
      (body[at + 3].to_int() & 0x3F)
    (value, 4)
  }
}

///|
/// 复合项规范形：壳核验 → 内体手写三分 → 壳内单空格律重编
/// （不回引擎：内体词间空白可有可无；嵌套壳深度计）
fn canonical_triple_term(
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Unit raise ParseError {
  let len = view.length()
  if len < 6 ||
    view[0] != b'<' ||
    view[1] != b'<' ||
    view[2] != b'(' ||
    view[len - 3] != b')' ||
    view[len - 2] != b'>' ||
    view[len - 1] != b'>' {
    raise ParseError::ValidationErr("canonical: triple term shell mismatch")
  }
  let inner = view[3:len - 3]
  let (s_kind, s_start, s_next) = tt_scan_term(inner, 0)
  let (p_kind, p_start, p_next) = tt_scan_term(inner, s_next)
  let (o_kind, o_start, o_next) = tt_scan_term(inner, p_next)
  let mut tail = o_next
  let ilen = inner.length()
  while tail < ilen && (inner[tail] == b' ' || inner[tail] == b'\t') {
    tail += 1
  }
  if tail != ilen {
    raise ParseError::ValidationErr("canonical: triple term trailing content")
  }
  buf.write_string("<<( ")
  canonical_term(s_kind, inner[s_start:s_next], buf)
  buf.write_string(" ")
  canonical_term(p_kind, inner[p_start:p_next], buf)
  buf.write_string(" ")
  canonical_term(o_kind, inner[o_start:o_next], buf)
  buf.write_string(" )>>")
}

///|
/// 复合项内体词项扫描：起点跨白 → 判形（嵌套壳/IRI/bnode/字面量+后缀）
/// → 返回（种类, 词起, 词止）。字面量后缀与主词间空白可隔（新律同口径）。
fn tt_scan_term(
  inner : ArrayView[Byte],
  start : Int32,
) -> (TermType, Int32, Int32) raise ParseError {
  let len = inner.length()
  let mut i = start
  while i < len && (inner[i] == b' ' || inner[i] == b'\t') {
    i += 1
  }
  let term_start = i
  if i >= len {
    raise ParseError::ValidationErr("canonical: triple term missing component")
  }
  let c = inner[i]
  // 嵌套复合项：<<( 深度计扫描；引号体整对跳过（内嵌字面量不得
  // 干扰壳配对——词法已保证字面量内裸 <<( 不出现于合法语料）
  if c == b'<' && i + 2 < len && inner[i + 1] == b'<' && inner[i + 2] == b'(' {
    let mut depth = 1
    i += 3
    while i < len && depth > 0 {
      let u = inner[i].to_int()
      if u == 0x22 {
        i += 1
        while i < len {
          let w = inner[i].to_int()
          if w == 0x5C {
            i += 2
            continue
          }
          i += 1
          if w == 0x22 {
            break
          }
        }
        continue
      }
      if u == 0x3C &&
        i + 2 < len &&
        inner[i + 1].to_int() == 0x3C &&
        inner[i + 2].to_int() == 0x28 {
        depth += 1
        i += 3
        continue
      }
      if u == 0x29 &&
        i + 2 < len &&
        inner[i + 1].to_int() == 0x3E &&
        inner[i + 2].to_int() == 0x3E {
        depth -= 1
        i += 3
        continue
      }
      i += 1
    }
    if depth != 0 {
      raise ParseError::ValidationErr("canonical: unbalanced triple term shell")
    }
    return (TermType::TripleTerm, term_start, i)
  }
  if c == b'<' {
    while i < len && inner[i] != b'>' {
      i += 1
    }
    if i >= len {
      raise ParseError::ValidationErr(
        "canonical: unterminated iri in triple term",
      )
    }
    return (TermType::Iri, term_start, i + 1)
  }
  if c == b'_' {
    i += 2
    while i < len && inner[i] != b' ' && inner[i] != b'\t' {
      i += 1
    }
    return (TermType::BNode, term_start, i)
  }
  if c == b'"' {
    i += 1
    let mut closed = false
    while i < len {
      let u = inner[i].to_int()
      if u == 0x5C {
        i += 2
        continue
      }
      i += 1
      if u == 0x22 {
        closed = true
        break
      }
    }
    if !closed {
      raise ParseError::ValidationErr(
        "canonical: unterminated literal in triple term",
      )
    }
    let mut j = i
    while j < len && (inner[j] == b' ' || inner[j] == b'\t') {
      j += 1
    }
    if j < len && inner[j] == b'@' {
      j += 1
      while j < len && inner[j] != b' ' && inner[j] != b'\t' {
        j += 1
      }
      i = j
    } else if j < len && inner[j] == b'^' {
      j += 2
      while j < len && inner[j] != b'>' {
        j += 1
      }
      if j >= len {
        raise ParseError::ValidationErr(
          "canonical: unterminated datatype in triple term",
        )
      }
      i = j + 1
    }
    return (TermType::Literal, term_start, i)
  }
  raise ParseError::ValidationErr("canonical: bad triple term component")
}
