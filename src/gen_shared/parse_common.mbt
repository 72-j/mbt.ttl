// ===== 共享装配层件（T17 / C-T8 双包重复治理，2026-09-20 立）=====
// 口径：**零方言语义纯函数**（入参出参只含 Byte / ArrayView[Byte] / Bytes / String / Int / Bool / Span 族）。
// 来源：逐字摘取；去注释后两包代码**逐字一致**（唯一分歧 `deep_check_literal` 的 `rdf12` 门控已取**严者**=trig 版，
//       见两包 `spec.md` C-T8 裁定表；注释取 trig 侧（方言中立化））。
// 引入方式：方言包 `using @gs { fn <name> }` ⇒ 本地调用点**零改写**。

///|
pub fn triple_term_inner_terms(
  data : ArrayView[Byte],
  span : Span,
) -> Array[Span] {
  let terms : Array[Span] = []
  let (off, len) = span
  let end = off + len
  // 剥头：<< 或 <<(；剥尾：>> 或 )>>
  let mut i = off + 2
  if i < end && data[i] == b'(' {
    i = i + 1
  }
  let mut e = end
  if e - 2 >= off && data[e - 1] == b'>' && data[e - 2] == b'>' {
    e = e - 2
    if e > i && data[e - 1] == b')' {
      e = e - 1
    }
  } else {
    return terms
  }
  if e <= i {
    return terms
  }
  // 顶层项切分：进入项首记起点，整项消费完即断项（in_item 归零——
  // 无空格连写 <s><p><o> 依赖此归零，不能只靠空白断项）
  let mut item_start = -1
  let mut depth = 0
  let mut tail_seen = false
  while i < e {
    let c = data[i]
    if c == b'"' || c == b'\'' {
      // 字符串物理单元：配对消费（转义感知）；嵌套壳内不切项
      if depth == 0 {
        if item_start < 0 {
          item_start = i
        }
        let q = c
        i = i + 1
        while i < e && data[i] != q {
          if data[i] == b'\\' && i + 1 < e {
            i = i + 2
          } else {
            i = i + 1
          }
        }
        i = i + 1 // 闭引号
        terms.push((item_start, i - item_start))
        item_start = -1
      } else {
        i = i + 1
      }
      continue
    }
    if c == b'<' && i + 1 < e && data[i + 1] == b'<' {
      // 嵌套壳：词法已保证平衡，这里配对消费到同级 >>
      if depth == 0 && item_start < 0 {
        item_start = i
      }
      depth = depth + 1
      i = i + 2
      continue
    }
    if c == b'>' && i + 1 < e && data[i + 1] == b'>' && depth > 0 {
      depth = depth - 1
      i = i + 2
      if depth == 0 {
        terms.push((item_start, i - item_start))
        item_start = -1
      }
      continue
    }
    if c == b'<' {
      // <iri>：IRI 内无空白，直吞到 >（仅顶层；嵌套壳内为普通项内容）
      if depth == 0 {
        if item_start < 0 {
          item_start = i
        }
        while i < e && data[i] != b'>' {
          i = i + 1
        }
        i = i + 1
        terms.push((item_start, i - item_start))
        item_start = -1
      } else {
        i = i + 1
      }
      continue
    }
    if c == b' ' || c == b'\t' || c == b'\r' || c == b'\n' {
      if depth == 0 && item_start >= 0 {
        terms.push((item_start, i - item_start))
        item_start = -1
      }
      i = i + 1
      continue
    }
    if c == b'~' && depth == 0 {
      // 壳内 reifier 尾巴：`~` 粘着第 3 项尾时就地断项凑齐（`:o1~_:id`
      // 全连写词法同分写）；三项收齐后 `~ [reifier]` 整段吞掉不计项。
      // 第 4 项在途 / 未满三项 / 二次 `~` 的落默认切项走项数判拒
      if terms.length() == 2 && item_start >= 0 {
        terms.push((item_start, i - item_start))
        item_start = -1
      }
      if terms.length() == 3 && item_start < 0 && !tail_seen {
        tail_seen = true
        i = i + 1
        while i < e &&
              (
                data[i] == b' ' ||
                data[i] == b'\t' ||
                data[i] == b'\r' ||
                data[i] == b'\n'
              ) {
          i = i + 1
        }
        if i < e && data[i] == b'<' {
          // <iri> reifier：直吞到 >
          while i < e && data[i] != b'>' {
            i = i + 1
          }
          if i < e {
            i = i + 1
          }
        } else {
          // PrefName / BlankNode reifier：吞到空白或壳尾
          while i < e &&
                data[i] != b' ' &&
                data[i] != b'\t' &&
                data[i] != b'\r' &&
                data[i] != b'\n' {
            i = i + 1
          }
        }
        continue
      }
      if item_start < 0 {
        item_start = i
      }
      i = i + 1
      continue
    }
    if item_start < 0 {
      item_start = i
    }
    i = i + 1
  }
  if depth == 0 && item_start >= 0 {
    terms.push((item_start, i - item_start))
  }
  terms
}
