// ============================================================
// RDF 图/数据集同构比较器（bnode 标签无关；eval 套件门基建，U2）
// ------------------------------------------------------------
// 安放裁定（U2 侦察）：候选位 gen_shared 被 C-T8 章程排除（只收
// 「两包逐字节同源」函数）；本包是 RDF 词项语义面（canonical_serialize
// 同律同源），gen_trig 本就 import @nquads——零新依赖边，解码律单源。
//
// 接口：quad 行 = (graph, subject, predicate, object) 词项原文四元组
// （span_text 形，bnode 含 `_:` 前缀、字面量含引号与后缀、复合项整壳）。
// 比较律（RDF Concepts 术语等 + 同构）：
//   · 非空 bnode 词项外，逐词项**值等**——IRI/字面量转义解码后比、
//     langtag 小写比、简写形式与显式 ^^<xsd:string> 同一、长/短引号
//     同一（调用方两侧文件写法可异，故先规范化再比）
//   · bnode 标签**无关**——双侧 bnode 走双射回溯（签名剪枝 + 叶判）
//   · graph 槽参与行键（数据集级；bnode 图标签同一双射）
//   · 行多重集比（顺序无关，不排序输入）
// 复合项内嵌 bnode 同入双射（整壳规范化后回扫标签）。
// ============================================================

///|
/// 同构判定：两侧 quad 行集（graph/s/p/o 词项原文）RDF 等价。
pub fn rows_isomorphic(
  left : Array[(String, String, String, String)],
  right : Array[(String, String, String, String)],
) -> Bool raise {
  // 规范化 + 集合去重先行（U3b：长度快拒必须在去重后——物化层的块透明
  // 设计有意产出重复行，按图语义折叠后再对拍）
  let nl = norm_rows(left)
  let nr = norm_rows(right)
  if nl.length() != nr.length() {
    return false
  }
  // 地面行（全行无 bnode）：多重集直比
  let ground_l = nl.filter(row_is_ground)
  let ground_r = nr.filter(row_is_ground)
  if ground_l.length() != ground_r.length() {
    return false
  }
  if sort_rows(ground_l) != sort_rows(ground_r) {
    return false
  }
  let bn_l = bnode_rows(nl)
  let bn_r = bnode_rows(nr)
  if bn_l.length() != bn_r.length() {
    return false
  }
  let labels_l = row_bnodes_of_rows(bn_l)
  let labels_r = row_bnodes_of_rows(bn_r)
  if labels_l.length() != labels_r.length() {
    return false
  }
  // 逐标签出现次数签名（四槽计数向量）必须多重集相等——剪枝与快拒
  if sort_rows(sig_rows(labels_l, bn_l)) != sort_rows(sig_rows(labels_r, bn_r)) {
    return false
  }
  match_rows(bn_l, bn_r, labels_l, labels_r)
}

///|
/// 行规范化：四槽各过 norm_term + 集合语义去重（U3b：RDF 图 = 三元组集合
/// 非多重集——块透明设计的重复主行/reifies 行按图语义折叠后对拍）
fn norm_rows(
  rows : Array[(String, String, String, String)],
) -> Array[(String, String, String, String)] raise {
  let out : Array[(String, String, String, String)] = []
  for row in rows {
    let normed = (
      norm_term(row.0),
      norm_term(row.1),
      norm_term(row.2),
      norm_term(row.3),
    )
    let mut seen = false
    for prior in out {
      if prior == normed {
        seen = true
        break
      }
    }
    if !seen {
      out.push(normed)
    }
  }
  out
}

///|
/// 词项规范化键：bnode 保标（双射认领）；IRI 解转义；字面量解码 +
/// langtag 小写 + 简形并 xsd:string；复合项递归（内嵌 bnode 保标）
fn norm_term(text : String) -> String raise {
  if text.has_prefix("_:") {
    return text
  }
  if text.has_prefix("<<(") {
    let bytes = @utf8.encode(text).to_array()
    let view : ArrayView[Byte] = bytes[:]
    let len = view.length()
    if len < 6 ||
      view[len - 3] != b')' ||
      view[len - 2] != b'>' ||
      view[len - 1] != b'>' {
      return text
    }
    let inner = view[3:len - 3]
    let (_, s_start, s_next) = tt_scan_term(inner, 0)
    let (_, p_start, p_next) = tt_scan_term(inner, s_next)
    let (_, o_start, o_next) = tt_scan_term(inner, p_next)
    let part = fn(a : Int32, b : Int32) -> String raise {
      norm_term(span_text_of_bytes(inner[a:b]))
    }
    return "<<(" +
      part(s_start, s_next) +
      " " +
      part(p_start, p_next) +
      " " +
      part(o_start, o_next) +
      " )>>"
  }
  if text.has_prefix("<") {
    let buf = StringBuilder()
    canonical_iri_text(text, buf)
    return buf.to_string()
  }
  norm_literal(text)
}

///|
/// 字节视图原文解码（复用 canonical 侧同律）
fn span_text_of_bytes(view : ArrayView[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(view))
}

///|
/// 字面量规范化键：四引形判别 → 体转义解码 → 尾段规范化
/// （无后缀 = 显式 xsd:string；@lang 小写；^^<dt> 解转义；跨白剥除）
fn norm_literal(text : String) -> String raise {
  let len = text.length()
  if len < 2 {
    return text
  }
  let u0 = text[0].to_int()
  // 三引形判别（""" 或 '''）
  let triple = len >= 6 &&
    text[1] == text[0] &&
    text[2] == text[0] &&
    (u0 == 0x22 || u0 == 0x27)
  let q = if triple { text[2] } else { text[0] }
  let open_len = if triple { 3 } else { 1 }
  // 体扫描：转义成对跳过；引号连跑 ≥3 且与开壳同种 = 闭壳（末尾三连律，
  // 连跑前 n-3 个属体）
  let mut i = open_len
  let mut close = -1
  let mut run_content = 0
  while i < len {
    let u = text[i].to_int()
    if u == 0x5C {
      i += 2
      continue
    }
    if u == q.to_int() {
      let mut run = 0
      while i + run < len && text[i + run].to_int() == q.to_int() {
        run += 1
      }
      if run >= 3 && triple {
        close = i
        run_content = run - 3
        break
      }
      if run >= 1 && !triple {
        close = i
        run_content = 0
        break
      }
      i += run
      continue
    }
    i += 1
  }
  if close < 0 {
    return text
  }
  let body = text[open_len:close].to_owned()
  let body_buf = StringBuilder()
  body_buf.write_string(decode_lexical(body))
  for _ in 0..<run_content {
    body_buf.write_char(Int32::unsafe_to_char(q.to_int()))
  }
  let out = body_buf.to_string()
  // 尾段：跨白 → @lang 小写 / ^^<dt> 规范；无后缀 = 简形并 xsd:string
  let mut suf = close + open_len
  while suf < len && (text[suf].to_int() == 0x20 || text[suf].to_int() == 0x09) {
    suf += 1
  }
  if suf >= len {
    return out + "^^<http://www.w3.org/2001/XMLSchema#string>"
  }
  if text[suf].to_int() == 0x40 {
    return out + ascii_lower(text[suf:len].to_owned())
  }
  if text[suf].to_int() == 0x5E &&
    suf + 1 < len &&
    text[suf + 1].to_int() == 0x5E {
    let mut dt = suf + 2
    while dt < len && (text[dt].to_int() == 0x20 || text[dt].to_int() == 0x09) {
      dt += 1
    }
    if dt < len && text[dt].to_int() == 0x3C {
      let dt_text = text[dt:len].to_owned()
      let dt_buf = StringBuilder()
      canonical_iri_text(dt_text, dt_buf)
      return out + "^^" + dt_buf.to_string()
    }
  }
  // 不可识尾段：原样（已验证语料不应触达）
  out + text[suf:len].to_owned()
}

///|
/// 词法体转义解码：ECHAR 集 + \u/\U → 原生字符；UTF-16 代理对合成
fn decode_lexical(body : String) -> String raise {
  let len = body.length()
  let buf = StringBuilder()
  let mut i = 0
  while i < len {
    let u = body[i].to_int()
    if u == 0x5C && i + 1 < len {
      let e = body[i + 1].to_int()
      if e == 0x74 {
        buf.write_char(Int32::unsafe_to_char(0x09))
        i += 2
        continue
      }
      if e == 0x62 {
        buf.write_char(Int32::unsafe_to_char(0x08))
        i += 2
        continue
      }
      if e == 0x6E {
        buf.write_char(Int32::unsafe_to_char(0x0A))
        i += 2
        continue
      }
      if e == 0x72 {
        buf.write_char(Int32::unsafe_to_char(0x0D))
        i += 2
        continue
      }
      if e == 0x66 {
        buf.write_char(Int32::unsafe_to_char(0x0C))
        i += 2
        continue
      }
      if e == 0x27 || e == 0x22 || e == 0x5C {
        buf.write_char(Int32::unsafe_to_char(e))
        i += 2
        continue
      }
      if e == 0x75 && i + 6 <= len {
        buf.write_char(Int32::unsafe_to_char(hex_from_text(body, i + 2, 4)))
        i += 6
        continue
      }
      if e == 0x55 && i + 10 <= len {
        buf.write_char(Int32::unsafe_to_char(hex_from_text(body, i + 2, 8)))
        i += 10
        continue
      }
      buf.write_char(Int32::unsafe_to_char(u))
      i += 1
      continue
    }
    if u >= 0xD800 && u <= 0xDBFF && i + 1 < len {
      let lo = body[i + 1].to_int()
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
  buf.to_string()
}

///|
/// 槽位 bnode 标签结构化提取：仅 `_:` 前缀词项与复合项内嵌成分计为
/// bnode；IRI/字面量槽零标签（字面量体内 `_:` 文本非 bnode，不入账）
fn slot_bnode_labels(text : String) -> Array[String] raise {
  if text.has_prefix("_:") {
    return [text]
  }
  if text.has_prefix("<<(") {
    let bytes = @utf8.encode(text).to_array()
    let view : ArrayView[Byte] = bytes[:]
    let len = view.length()
    if len < 6 ||
      view[len - 3] != b')' ||
      view[len - 2] != b'>' ||
      view[len - 1] != b'>' {
      return []
    }
    let inner = view[3:len - 3]
    let out : Array[String] = []
    let (_, s_start, s_next) = tt_scan_term(inner, 0)
    let (_, p_start, p_next) = tt_scan_term(inner, s_next)
    let (_, o_start, o_next) = tt_scan_term(inner, p_next)
    for
      span in [
        inner[s_start:s_next],
        inner[p_start:p_next],
        inner[o_start:o_next],
      ] {
      for label in slot_bnode_labels(span_text_of_bytes(span)) {
        out.push(label)
      }
    }
    return out
  }
  []
}

///|
/// 槽位含标签判（含复合项内嵌）
fn slot_has(label : String, slot_labels : Array[String]) -> Bool {
  for l in slot_labels {
    if l == label {
      return true
    }
  }
  false
}

///|
/// 行是否全地面（四槽结构化无 bnode）
fn row_is_ground(row : (String, String, String, String)) -> Bool raise {
  slot_bnode_labels(row.0).length() == 0 &&
  slot_bnode_labels(row.1).length() == 0 &&
  slot_bnode_labels(row.2).length() == 0 &&
  slot_bnode_labels(row.3).length() == 0
}

///|
fn bnode_rows(
  rows : Array[(String, String, String, String)],
) -> Array[(String, String, String, String)] raise {
  rows.filter(fn(row) raise { !row_is_ground(row) })
}

///|
/// 行集内全部 bnode 标签（去重，结构化提取）
fn row_bnodes_of_rows(
  rows : Array[(String, String, String, String)],
) -> Array[String] raise {
  let seen : Map[String, Bool] = Map([])
  for row in rows {
    for slot in [row.0, row.1, row.2, row.3] {
      for label in slot_bnode_labels(slot) {
        seen[label] = true
      }
    }
  }
  seen.keys().collect()
}

///|
/// 标签签名行：每标签一行**无标签**计数向量（s/p 与 o/g 两打包槽）——
/// 多重集相等是双射存在必要条件；槽位出现 = 结构化标签含之（复合项
/// 内嵌计满额）。键内不含标签：换标等价不因签名行词面异而误杀。
fn sig_rows(
  labels : Array[String],
  rows : Array[(String, String, String, String)],
) -> Array[(String, String, String, String)] raise {
  labels.map(fn(label) raise {
    let mut cs = 0
    let mut cp = 0
    let mut co = 0
    let mut cg = 0
    for row in rows {
      if slot_has(label, slot_bnode_labels(row.0)) {
        cg += 1
      }
      if slot_has(label, slot_bnode_labels(row.1)) {
        cs += 1
      }
      if slot_has(label, slot_bnode_labels(row.2)) {
        cp += 1
      }
      if slot_has(label, slot_bnode_labels(row.3)) {
        co += 1
      }
    }
    ("\{cs}/\{cp}", "\{co}/\{cg}", "", "")
  })
}

///|
/// 行多重集比较：排序后逐行（词面串序；仅用于比较，不落盘）
fn sort_rows(
  rows : Array[(String, String, String, String)],
) -> Array[(String, String, String, String)] {
  let out = rows.copy()
  out.sort_by(fn(a, b) { row_key(b).compare(row_key(a)) })
  out
}

///|
fn row_key(row : (String, String, String, String)) -> String {
  row.0 + "\u{1}" + row.1 + "\u{1}" + row.2 + "\u{1}" + row.3
}

///|
/// bnode 双射回溯：逐左标签试右标签（签名剪枝），全配后替换左行多重集
/// 与右行多重集比对。规模 = 套件级（标签 ≤ 数个），叶判直比。
fn match_rows(
  bn_l : Array[(String, String, String, String)],
  bn_r : Array[(String, String, String, String)],
  labels_l : Array[String],
  labels_r : Array[String],
) -> Bool raise {
  let n = labels_l.length()
  let mapping : Map[String, String] = Map([])
  let used : Map[String, Bool] = Map([])
  // 右标签按签名分组，剪枝候选
  let r_sigs : Map[String, Array[String]] = Map([])
  for r in labels_r {
    let key = sig_key(r, bn_r)
    match r_sigs.get(key) {
      Some(arr) => arr.push(r)
      None => r_sigs[key] = [r]
    }
  }
  fn rec(k : Int32) -> Bool raise {
    if k >= n {
      // 全配：替换左行 → 多重集与右行比
      let substituted = bn_l.map(fn(row) {
        (
          sub_label(row.0, mapping),
          sub_label(row.1, mapping),
          sub_label(row.2, mapping),
          sub_label(row.3, mapping),
        )
      })
      return sort_rows(substituted) == sort_rows(bn_r)
    }
    let l = labels_l[k]
    let key = sig_key(l, bn_l)
    match r_sigs.get(key) {
      None => return false
      Some(candidates) =>
        for r in candidates {
          if !used.get(r).unwrap_or(false) {
            mapping[l] = r
            used[r] = true
            if rec(k + 1) {
              return true
            }
            used.remove(r)
            mapping.remove(l)
          }
        }
    }
    false
  }

  rec(0)
}

///|
/// 标签签名键（四槽结构化计数打包；match_rows 的剪枝候选分组键）
fn sig_key(
  label : String,
  rows : Array[(String, String, String, String)],
) -> String raise {
  let mut cs = 0
  let mut cp = 0
  let mut co = 0
  let mut cg = 0
  for row in rows {
    if slot_has(label, slot_bnode_labels(row.0)) {
      cg += 1
    }
    if slot_has(label, slot_bnode_labels(row.1)) {
      cs += 1
    }
    if slot_has(label, slot_bnode_labels(row.2)) {
      cp += 1
    }
    if slot_has(label, slot_bnode_labels(row.3)) {
      co += 1
    }
  }
  "\{cs}/\{cp}/\{co}/\{cg}"
}

///|
/// bnode 标签替换（token 边界拼接：`_:` 出现点须左邻词界（串首/空白/
/// 左括），标签止于右词界（空白/右括/串尾）；复合项内嵌标签同径替换。
/// 字面量体内偶合 `_:` 文本不在语料契约内（eval 语料无此形），注释在案）
fn sub_label(text : String, mapping : Map[String, String]) -> String {
  if !text.contains("_:") {
    return text
  }
  let len = text.length()
  let buf = StringBuilder()
  let mut i = 0
  while i < len {
    let u = text[i].to_int()
    let left_ok = i == 0 ||
      text[i - 1].to_int() == 0x20 ||
      text[i - 1].to_int() == 0x28
    if left_ok && u == 0x5F && i + 1 < len && text[i + 1].to_int() == 0x3A {
      let mut j = i + 2
      while j < len && text[j].to_int() != 0x20 && text[j].to_int() != 0x29 {
        j += 1
      }
      let label = text[i:j].to_owned()
      match mapping.get(label) {
        Some(rep) => buf.write_string(rep)
        None => buf.write_string(label)
      }
      i = j
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
  buf.to_string()
}
