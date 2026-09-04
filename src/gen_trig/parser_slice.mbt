// ===== 用户部分：TrigSliceParser 切片解析器（与 nquads 分层同构） =====
// 组装机械唯一地点：TrigPendingQuad 快照 → QuadSpan；验证在组装之后（view 直查）。
// 本轮验证面（骨架口径，回灌后对齐 nquads validate_helper 深度）：
//   - 缺槽检测（s/p/o 必须齐）
//   - IRI 轻校验（<> 包裹非空）
//   - BNode 前缀校验（_: 起头）
//   - PrefName 存在性检查：前缀必须在 ctx.prefixes 声明账本中（后声明覆盖先声明，
//     逐 quad 发射时检查 = 先用后声明自然拒绝）；谓词位 "a" 缩写豁免

///|
pub struct TrigSliceParser[L] {
  engine : TrigEngine[L]
  data : ArrayView[Byte]
  lenient : Bool // lenient 模式下跳过验证
  errors : Array[ParseError] // 收集的结构错误
}

///|
pub fn[L] TrigSliceParser::new(
  engine : TrigEngine[L],
  data : ArrayView[Byte],
  lenient? : Bool = false,
) -> TrigSliceParser[L] {
  { engine, data, lenient, errors: [], }
}

///|
/// 统计 offset 之前的换行数（0 基行号；词法器不吐换行 token，统一按数据统计）
fn[L] TrigSliceParser::line_before(
  self : TrigSliceParser[L],
  offset : Int,
) -> Int {
  let limit = if offset < self.data.length() {
    offset
  } else {
    self.data.length()
  }
  let mut n = 0
  for i in 0..<limit {
    if self.data[i] == b'\n' {
      n = n + 1
    }
  }
  n
}

///|
/// PrefName 存在性检查：prefix 必须在声明账本中（从尾向前扫 = 后声明覆盖）。
/// "no colon" 的裸词在此拒绝（裸词不是合法词项）。
fn prefix_declared(
  data : ArrayView[Byte],
  prefixes : Array[(Span, Span)],
  span : Span,
) -> Bool {
  let (off, len) = span
  // 找词内第一个 ':'；没有 = 裸词，拒绝
  let mut colon = -1
  for i in 0..<len {
    if data[off + i] == b':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    return false
  }
  let mut j = prefixes.length() - 1
  while j >= 0 {
    let (name, _) = prefixes[j]
    // 声明 token 自带尾冒号（"ex:" / 空前缀声明 ":"），归一化剥掉再比；
    // 空前缀声明的 IRI 术语 = DefaultPrefixIRI
    let dn_len = if name.1 > 0 && data[name.0 + name.1 - 1] == b':' {
      name.1 - 1
    } else {
      name.1
    }
    if dn_len == colon {
      let mut same = true
      for k in 0..<colon {
        if data[off + k] != data[name.0 + k] {
          same = false
          break
        }
      }
      if same {
        return true
      }
    }
    j = j - 1
  }
  false
}

///|
/// 轻校验（骨架口径）：<...> 包裹非空 / _: 前缀 / PrefName 存在性

///|
/// RDF 1.2 引用三元组壳的内部项提取（span 口径，轻量验证）：
/// 剥壳后按顶层切三项（字符串物理单元、嵌套壳深度感知、IRI 无空白直吞）。
/// 返回的每一项 span 交 validate_term 递归验证（嵌套壳自然回落到本分支）。
/// 项数 != 3 的壳非法（bad-04/05/08）；壳内项的种类核验归物化层深验。
/// 三项后的 `~ [reifier]` 尾巴整段吞掉不计项（RDF 1.2 壳内 reifier：
/// `:o1 ~ :id` 分写 / `~_:id` 连写 / 裸 `~` fresh；骨架口径与壳外
/// TildeEnd 驻留同策，reifier 语义位后置）
fn triple_term_inner_terms(data : ArrayView[Byte], span : Span) -> Array[Span] {
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
        while i < e && (data[i] == b' ' || data[i] == b'\t' || data[i] == b'\r' || data[i] == b'\n') {
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
          while i < e && data[i] != b' ' && data[i] != b'\t' && data[i] != b'\r' && data[i] != b'\n' {
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

///|
fn validate_term(
  data : ArrayView[Byte],
  prefixes : Array[(Span, Span)],
  span : Span,
  is_predicate : Bool,
) -> ParseError? {
  let view = slice_span(data, span)
  let n = view.length()
  if n == 0 {
    // ★3 集合 rdf:nil 标记（Span(open.0, 0)，长度 0 = 无字节词项）：放行；
    // 真实词项长度恒 >= 1（词法整词出），长度 0 只能来自集合收口标记
    return None
  }
  let c0 = view[0]
  if c0 == b'<' && n > 1 && view[1] == b'<' {
    // RDF 1.2 引用三元组壳（span 口径，轻量验证）：剥壳后逐项递归验证
    //（项数 != 3 在此拒绝；壳内项的种类核验归物化层深验）
    let terms = triple_term_inner_terms(data, span)
    if terms.length() != 3 {
      return Some(
        ParseError::SyntaxErr("Triple term must have exactly 3 terms", span),
      )
    }
    for t in terms {
      match validate_term(data, prefixes, t, false) {
        Some(e) => return Some(e)
        None => ()
      }
    }
    return None
  }
  if c0 == b'<' {
    if n < 2 || view[n - 1] != b'>' {
      return Some(ParseError::SyntaxErr("IRI must be wrapped in <>", span))
    }
    return None
  }
  if c0 == b'_' {
    if n < 3 || view[1] != b':' {
      return Some(ParseError::SyntaxErr("Blank node must start with _:", span))
    }
    return None
  }
  if c0 == b'[' || c0 == b'(' {
    // ★3 fresh 结构词：`[`/`(` 开括号 token 自身 span 作 fresh bnode 身份。
    // 语法闭合由引擎表保证（栈判脏在 EOF 收尾），此处只认形态
    return None
  }
  if c0 == b'"' || c0 == b'\'' {
    // 字面量：词法已配对定界（引号 + @lang/^^ 后缀并入单 span），深度校验在物化层
    return None
  }
  // 数值/布尔字面量（span 口径，轻量验证）：物化层展开 typed literal，无前缀依赖。
  // 数值族（含前导点 `.1`/符号 `-.2e3`）统一交 is_numeric_span 复核（词法同口径）
  if c0 == b'.' || c0 == b'+' || c0 == b'-' || (c0 >= b'0' && c0 <= b'9') {
    if is_numeric_span(data, span.0, span.1) {
      return None
    }
  }
  if (
      n == 4 &&
      view[0] == b't' &&
      view[1] == b'r' &&
      view[2] == b'u' &&
      view[3] == b'e'
    ) ||
    (
      n == 5 &&
      view[0] == b'f' &&
      view[1] == b'a' &&
      view[2] == b'l' &&
      view[3] == b's' &&
      view[4] == b'e'
    ) {
    return None
  }
  // PrefName / 'a' 缩写
  if is_predicate && n == 1 && c0 == b'a' {
    return None // 'a' → rdf:type：物化层加宽批次：词法已整段出词，验证层收紧
  }
  // PN_PREFIX/PN_LOCAL 语法面（词法加宽后的收紧点，bad-pname-03 /
  // bad-missing-ns-dot-end / bad-ln-dash-start 桶口径）
  match validate_prefname(data, span) {
    Some(e) => return Some(e)
    None => ()
  }
  if !prefix_declared(data, prefixes, span) {
    return Some(ParseError::SyntaxErr("Undeclared prefix", span))
  }
  None
}

///|
/// PrefName 语法面收紧（词法加宽批次的验证层职责）：
///   前缀部：不得以裸 '.' 结尾（PN_PREFIX 无尾点；bad-missing-ns-dot-end）
///   本地部：首字符不许 '.'/'-'（PN_LOCAL 首字符集；bad-ln-dash-start）
///           \X 转义只许 PN_LOCAL_ESC 字符集（bad-pname-03：\u 非法）
/// 百分号 %HH 两 hex 位已由词法整段保证；无冒号形态交 prefix_declared 报错
fn validate_prefname(data : ArrayView[Byte], span : Span) -> ParseError? {
  let (off, len) = span
  let mut colon = -1
  for i in 0..<len {
    if data[off + i] == b':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    return None // 无冒号：非前缀名形态，交 prefix_declared 口径
  }
  // 前缀部尾点
  if colon > 0 && data[off + colon - 1] == b'.' {
    return Some(ParseError::SyntaxErr("Prefix must not end with '.'", span))
  }
  // 本地部首字符
  if colon + 1 < len {
    let f = data[off + colon + 1]
    if f == b'.' || f == b'-' {
      return Some(
        ParseError::SyntaxErr("Local name must not start with '.' or '-'", span),
      )
    }
  }
  // 本地部 \X 转义字符集
  let mut i = colon + 1
  while i < len {
    let c = data[off + i]
    if c == b'\\' {
      if i + 1 >= len {
        return Some(ParseError::SyntaxErr("Dangling escape", span))
      }
      let e = data[off + i + 1]
      let ok = e == b'_' ||
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
      if !ok {
        return Some(ParseError::SyntaxErr("Invalid PN_LOCAL_ESC escape", span))
      }
      i = i + 2
    } else {
      i = i + 1
    }
  }
  None
}

///|
/// 组装机械唯一地点：TrigPendingQuad 快照 → QuadSpan（缺槽/校验失败统一回 ParseError）
fn[L] TrigSliceParser::assemble(
  self : TrigSliceParser[L],
  pending : TrigPendingQuad,
) -> Result[QuadSpan, ParseError] {
  // ★3 合成谓词归一：集合链 quad 谓词无字节（p 槽 None + pk 标记），
  // 以 (0,0) 占位过缺槽检测——物化层按 pk 合成词表 IRI，永不读 p 字节
  let pending = if pending.pk is PredKind::Normal {
    pending
  } else {
    { ..pending, pred: Some((0, 0)) }
  }
  match (pending.subj, pending.pred, pending.obj) {
    (Some(s), Some(p), Some(o)) => {
      if !self.lenient {
        let prefixes = self.engine.ctx.prefixes
        match validate_term(self.data, prefixes, s, false) {
          Some(e) => return Err(e)
          None => ()
        }
        match validate_term(self.data, prefixes, p, true) {
          Some(e) => return Err(e)
          None => ()
        }
        match validate_term(self.data, prefixes, o, false) {
          Some(e) => return Err(e)
          None => ()
        }
        match pending.graph {
          Some(g) =>
            match validate_term(self.data, prefixes, g, false) {
              Some(e) => return Err(e)
              None => ()
            }
          None => ()
        }
      }
      Ok({ s, p, o, g: pending.graph, pk: pending.pk, pver: pending.pver, bver: pending.bver })
    }
    // RDF 1.2 引用三元组壳独立成句：`<< s p o >> .`——壳落主语槽后无谓词/宾语，
    // 语句即断言壳内三元组（组装层拆壳，三项交 validate_term 递归验证）
    (Some(s), None, None) =>
      match self.tt_shell_terms(s) {
        Some((ts, tp, to)) =>
          if self.lenient {
            Ok({ s: ts, p: tp, o: to, g: pending.graph, pk: pending.pk, pver: pending.pver, bver: pending.bver })
          } else {
            let prefixes = self.engine.ctx.prefixes
            match validate_term(self.data, prefixes, ts, false) {
              Some(e) => return Err(e)
              None => ()
            }
            match validate_term(self.data, prefixes, tp, true) {
              Some(e) => return Err(e)
              None => ()
            }
            match validate_term(self.data, prefixes, to, false) {
              Some(e) => return Err(e)
              None => ()
            }
            match pending.graph {
              Some(g) =>
                match validate_term(self.data, prefixes, g, false) {
                  Some(e) => return Err(e)
                  None => ()
                }
              None => ()
            }
            Ok({ s: ts, p: tp, o: to, g: pending.graph, pk: pending.pk, pver: pending.pver, bver: pending.bver })
          }
        None => Err(ParseError::SyntaxErr("Incomplete quad at emission", s))
      }
    _ =>
      Err(
        ParseError::SyntaxErr(
          "Incomplete quad at emission",
          pending.subj.unwrap_or((0, 0)),
        ),
      )
  }
}

///|
/// 壳作主语的拆壳：span 为 `<< … >>` 形态且内部恰三项时返回 (s, p, o) 内部 span
fn[L] TrigSliceParser::tt_shell_terms(
  self : TrigSliceParser[L],
  span : Span,
) -> (Span, Span, Span)? {
  let view = slice_span(self.data, span)
  if view.length() > 1 && view[0] == b'<' && view[1] == b'<' {
    let terms = triple_term_inner_terms(self.data, span)
    if terms.length() == 3 {
      return Some((terms[0], terms[1], terms[2]))
    }
  }
  None
}

///|
/// 实现 Iter trait
pub fn[L : LexerSource] TrigSliceParser::parse_next(
  self : TrigSliceParser[L],
) -> Result[QuadSpan, ParseError]? {
  match self.engine.next() {
    None => {
      // 检查最后是否有未处理的错误
      match self.engine.last_error {
        Some(span) => {
          let line = self.line_before(span.0)
          self.errors.push(
            ParseError::StructSyntaxErr("Structure error", line, span),
          )
        }
        None => ()
      }
      None
    }
    Some(Err(e)) => Some(Err(e))
    Some(Ok(pending)) => {
      // ★3 空 fresh 结构独立成句（`[] .`）：主槽 fresh + 谓/宾全空 = 空属性列表
      // 断言零三元组，静默跳过（不进组装——组装层会当缺槽误报 Incomplete quad）。
      // 只认 `[`：`(...)` 集合独立成句是非法文法（bad-list-01 口径），必须进组装报错
      match pending.subj {
        Some(s) => {
          let v = slice_span(self.data, s)
          if pending.pred is None &&
            pending.obj is None &&
            v.length() > 0 &&
            v[0] == b'[' {
            return self.parse_next()
          }
        }
        None => ()
      }
      match self.assemble(pending) {
        Ok(quad) => Some(Ok(quad))
        Err(e) => {
          self.errors.push(e)
          self.parse_next() // 组装/校验失败：记错误继续下一条
        }
      }
    }
  }
}

///|
/// 解析全部
pub fn[L : LexerSource] TrigSliceParser::parse_all(
  self : TrigSliceParser[L],
) -> (Array[QuadSpan], Array[ParseError]) {
  let quads : Array[QuadSpan] = []
  let errors = self.errors
  for ;; {
    match self.parse_next() {
      Some(Ok(q)) => quads.push(q)
      Some(Err(e)) => {
        // 引擎级错误（EOF 不完整/业务失败）一并收集，不能静默吞掉
        self.errors.push(e)
        continue
      }
      None => break
    }
  }
  (quads, errors)
}
