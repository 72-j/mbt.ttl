// ===== 共享装配层件（T17 / C-T8 双包重复治理，2026-09-20 立）=====
// 口径：**零方言语义纯函数**（入参出参只含 Byte / ArrayView[Byte] / Bytes / String / Int / Bool / Span 族）。
// 来源：逐字摘取；去注释后两包代码**逐字一致**（唯一分歧 `deep_check_literal` 的 `rdf12` 门控已取**严者**=trig 版，
//       见两包 `spec.md` C-T8 裁定表；注释取 trig 侧（方言中立化））。
// 引入方式：方言包 `using @gs { fn <name> }` ⇒ 本地调用点**零改写**。

///|
pub fn deep_check_literal(
  view : ArrayView[Byte],
  rdf12 : Bool,
) -> Result[Unit, ParseError] {
  let len = view.length()
  if len < 2 {
    return Err(ParseError::ValidationErr("Literal too short"))
  }
  let q = view[0]
  if q != b'"' && q != b'\'' {
    return Err(ParseError::ValidationErr("Literal must start with a quote"))
  }
  let quote_run = if len >= 3 && view[1] == q && view[2] == q { 3 } else { 1 }
  // 引号体：转义序列合法性 + 闭引号定位（bad-esc / bad-string 桶）
  // scan_string_body 贪左返回首个 quote_run 连续引号；三引号串体内紧邻闭定界的
  // 未转义内容引号（`""""` = 内容 `"` + 闭 `"""`，LITERAL_LONG2 口径）使连跑
  // 长于 quote_run——闭定界向右扩到连跑尽头，取"末尾 quote_run 个"
  let close0 = match @nquads.scan_string_body(view, 0, quote_run, quote_run) {
    Ok(pos) => pos
    Err(e) => return Err(ParseError::ValidationErr("Bad literal body: \{e}"))
  }
  let mut close = close0
  if quote_run == 3 {
    while close + 3 < len && view[close + 3] == q {
      close = close + 1
    }
  }
  // W3C bad-string-06/07 口径：闭壳连跑被右扩（连跑长于 quote_run = `""""` 悬空
  // 引号歧义按内容引号吞并）且紧跟 @lang / ^^dt 后缀 → 非法——官方按贪左闭壳，
  // 悬空引号破坏后续语法（`"""abc""""@en` 负例）。无后缀时扩并合法
  //（turtle LITERAL_LONG2 `"""test-\\""""` 正例：扩过后恰无后缀）
  if close > close0 && close + quote_run < len {
    return Err(ParseError::ValidationErr("Malformed literal suffix"))
  }
  // \u/\U 孤代理（surrogate 桶）
  // rdf12（RDF 1.2 模式开关）：代理一律拒，成对也不收（surrogate-pair-bad
  // 口径）；1.1 宽容口径成对合法（test-38 正例 \ud801\udc69 编 SMP），按装配层注入
  match
    @nquads.validate_escapes_unicode(
      view,
      0,
      quote_run,
      close,
      scalar_only=rdf12,
    ) {
    Ok(_) => ()
    Err(e) => return Err(ParseError::ValidationErr("Bad literal escape: \{e}"))
  }
  let at = close + quote_run
  if at >= len {
    return Ok(()) // 无后缀：simple literal
  }
  if view[at] == b'@' {
    // langtag.mbt 全量 RFC 5646；RDF 1.2 方向后缀（小写精确）拆出后验基础标签。
    // **1.2 模式开关门控**：`--ltr/--rtl` 是 RDF 1.2 新增特征——1.1 模式下整词
    // 按普通 langtag 验（含 `-` 段非法 ⇒ 拒），与 WG 语法一致。
    let tag_str = @utf8.decode_lossy(Bytes::from_array(view[at + 1:len]))
    let has_dir = tag_str.has_suffix("--ltr") || tag_str.has_suffix("--rtl")
    // 门控显式化：langtag 文法本身认方向后缀（共享件），1.1 模式在此拒
    if has_dir && !rdf12 {
      return Err(
        ParseError::ValidationErr(
          "Language direction suffix (--ltr/--rtl) requires RDF 1.2",
        ),
      )
    }
    let base_tag = if has_dir && rdf12 {
      tag_str[:tag_str.length() - 5]
    } else {
      tag_str[:]
    }
    match @nquads.LanguageTag::parse(base_tag) {
      Ok(_) => ()
      Err(e) => return Err(ParseError::ValidationErr("Bad language tag: \{e}"))
    }
    return Ok(())
  }
  if view[at] == b'^' && at + 1 < len && view[at + 1] == b'^' {
    let dt = view[at + 2:len]
    if dt.length() > 1 && dt[0] == b'<' {
      // banned datatype（rdf:langString / rdf:dirLangString 不可显式使用）
      if @nquads.is_banned_langstring_iri(dt) {
        return Err(
          ParseError::ValidationErr(
            "rdf:langString / rdf:dirLangString must not be used as explicit datatype",
          ),
        )
      }
      check_iri_view(dt)
    } else {
      // ^^PrefName 泄漏兜底（组装层应已展开或拒绝）
      Err(ParseError::ValidationErr("Literal datatype must be an IRI"))
    }
  } else {
    Err(ParseError::ValidationErr("Malformed literal suffix"))
  }
}

///|
pub fn deep_check_tt(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let len = view.length()
  if len < 5 ||
    view[0] != b'<' ||
    view[1] != b'<' ||
    view[len - 1] != b'>' ||
    view[len - 2] != b'>' {
    return Err(ParseError::ValidationErr("Malformed triple-term shell"))
  }
  let terms = triple_term_inner_terms(view, (0, len))
  if terms.length() != 3 {
    return Err(
      ParseError::ValidationErr("Triple term must have exactly 3 terms"),
    )
  }
  // 主语位：字面量族（引号 / 数值首字节 / true/false）拒绝；嵌套壳递归
  let s = slice_span(view, terms[0])
  if s.length() > 0 {
    let c0 = s[0]
    if c0 == b'"' ||
      c0 == b'\'' ||
      c0 == b'.' ||
      c0 == b'+' ||
      c0 == b'-' ||
      (c0 >= b'0' && c0 <= b'9') ||
      tt_bool_word(s, "true") ||
      tt_bool_word(s, "false") {
      return Err(
        ParseError::ValidationErr("Triple term subject must not be a literal"),
      )
    }
  }
  if s.length() >= 2 && s[0] == b'<' && s[1] == b'<' {
    match deep_check_tt(s) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  // 谓词位：IRI 直过；嵌套壳 / bnode（_: 也含冒号，须显式排除）拒；其余须 PrefName 形
  let p = slice_span(view, terms[1])
  let p_ok = if p.length() >= 2 && p[0] == b'<' && p[1] == b'<' {
    false
  } else if p.length() > 0 && p[0] == b'<' {
    true
  } else if p.length() >= 2 && p[0] == b'_' && p[1] == b':' {
    false
  } else {
    let mut has_colon = false
    for b in p {
      if b == b':' {
        has_colon = true
        break
      }
    }
    has_colon
  }
  if !p_ok {
    return Err(
      ParseError::ValidationErr("Triple term predicate must be an IRI"),
    )
  }
  // 宾语位：全种类合法，仅嵌套壳递归
  let o = slice_span(view, terms[2])
  if o.length() >= 2 && o[0] == b'<' && o[1] == b'<' {
    match deep_check_tt(o) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  Ok(())
}

///|
pub fn literal_body_end(data : ArrayView[Byte], span : Span) -> Int {
  let (off, len) = span
  let q = data[off]
  if off + 2 < off + len && data[off + 1] == q && data[off + 2] == q {
    // 三引号长串：扫配对 """
    let mut i = off + 3
    while i + 2 < off + len {
      if data[i] == q && data[i + 1] == q && data[i + 2] == q {
        return i + 3
      }
      if data[i] == b'\\' {
        i = i + 2
      } else {
        i = i + 1
      }
    }
    return off + len // 防御路径也须返回绝对偏移（off>0 时 len 是错位）
  }
  // 单引号串
  let mut i = off + 1
  while i < off + len {
    if data[i] == b'\\' {
      i = i + 2
      continue
    }
    if data[i] == q {
      return i + 1
    }
    i = i + 1
  }
  off + len // 同上：绝对偏移
}

///|
pub fn is_pn_local_esc(e : Byte) -> Bool {
  e == b'_' ||
  e == b'~' ||
  e == b'.' ||
  e == b'-' ||
  e == b'!' ||
  e == b'$' ||
  e == b'&' ||
  e == b'\'' ||
  e == b'(' ||
  e == b')' ||
  e == b'*' ||
  e == b'+' ||
  e == b',' ||
  e == b';' ||
  e == b'=' ||
  e == b'/' ||
  e == b'?' ||
  e == b'#' ||
  e == b'@' ||
  e == b'%'
}

///|
pub fn check_iri_view(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let len = view.length()
  if len < 3 || view[0] != b'<' || view[len - 1] != b'>' {
    return Err(ParseError::ValidationErr("IRI must be wrapped in <>"))
  }
  // 绝对性：scheme 嗅探（iri.mbt parse_scheme 同文法）替代整段 @nquads.parse。
  // 相对 IRI 已由 iri_term 按 base 改写，无 scheme 即拒（防御臂）
  if !view_has_scheme(view[1:len - 1]) {
    return Err(ParseError::ValidationErr("Relative IRI not allowed"))
  }
  // 禁字符 / UCHAR 转义（内容区 [1, len-1)，闭 '>' 由约定排除）
  match @nquads.validate_iri_body(view, 0, 1, len) {
    Ok(_) => ()
    Err(e) => return Err(ParseError::ValidationErr("Bad IRI: \{e}"))
  }
  Ok(())
}

///|
pub fn check_bnode_view(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  match @nquads.validate_bnode(view, 0) {
    Ok(_) => ()
    Err(e) => return Err(ParseError::ValidationErr("Bad blank node: \{e}"))
  }
  Ok(())
}

///|
pub fn tt_bool_word(v : ArrayView[Byte], word : String) -> Bool {
  if v.length() != word.length() {
    return false
  }
  for i in 0..<word.length() {
    if v[i] != word[i].to_byte() {
      return false
    }
  }
  true
}

///|
pub fn is_scheme_byte(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') ||
  (b >= b'A' && b <= b'Z') ||
  (b >= b'a' && b <= b'z') ||
  b == b'+' ||
  b == b'-' ||
  b == b'.'
}

///|
pub fn view_has_scheme(view : ArrayView[Byte]) -> Bool {
  let len = view.length()
  let mut i = 0
  while i < len && is_scheme_byte(view[i]) {
    i = i + 1
  }
  i > 0 && i < len && view[i] == b':'
}
