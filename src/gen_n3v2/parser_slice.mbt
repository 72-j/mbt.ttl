// ===== 用户部分：N3SliceParser 切片解析器（trig parser_slice.mbt 同构） =====
// 组装机械唯一地点：N3PendingQuad 快照 → QuadSpan；验证在组装之后（view 直查）。
// 与 trig 的差异（均有据可查）：
//   - TT 壳独立成句臂已补（rdf12 syntax-basic-04/05/06 驱动，trig 同款拆壳递归
//     验证；iri_version 快照槽随行）；`[] .` 空属性列表静默跳过臂保留（parse_next）。
//   - QuadSpan 载 iri_version：ADR-003b 显式链账本版本槽（快照四槽对齐 N3PendingQuad）。
// 验证面（骨架口径，@nquads validate_helper 深度对齐归 4E-6）：
//   - 缺槽检测（s/p/o 必须齐）
//   - IRI 轻校验（<> 包裹非空）
//   - BNode 前缀校验（_: 起头）
//   - PrefName 存在性检查：前缀必须在 ctx.prefixes 声明账本中（后声明覆盖先声明；
//     谓词位 "a" 缩写豁免）

///|
pub struct N3SliceParser[L] {
  engine : N3Engine[L]
  data : ArrayView[Byte]
  lenient : Bool // lenient 模式下跳过验证
  errors : Array[ParseError] // 收集的结构错误
}

///|
pub fn[L] N3SliceParser::new(
  engine : N3Engine[L],
  data : ArrayView[Byte],
  lenient? : Bool = false,
) -> N3SliceParser[L] {
  { engine, data, lenient, errors: [], }
}

///|
/// 统计 offset 之前的换行数（0 基行号；词法器不吐换行 token，统一按数据统计）
fn[L] N3SliceParser::line_before(self : N3SliceParser[L], offset : Int) -> Int {
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
/// 引擎结构错排空（役23 R-05：error_spans 累积 → 行号化 ParseError 转入
/// errors 数组后清空——drain 点 = 每次 parse_next 入口 + 终态清尾，多坏
/// 语句逐条落账不再只报最后一条）
fn[L] N3SliceParser::drain_engine_errors(self : N3SliceParser[L]) -> Unit {
  for span in self.engine.error_spans {
    let line = self.line_before(span.0)
    self.errors.push(ParseError::StructSyntaxErr("Structure error", line, span))
  }
  self.engine.error_spans.clear()
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
/// RDF 1.2 引用三元组壳的内部项提取（span 口径，轻量验证；N3 宾位壳同款）：
/// 剥壳后按顶层切三项（字符串物理单元、嵌套壳深度感知、IRI 无空白直吞）。
/// 返回的每一项 span 交 validate_term 递归验证。项数 != 3 的壳非法。
/// 三项后的 `~ [reifier]` 尾巴整段吞掉不计项（与壳外 Tilde 驻留同策）。
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
      // 壳内 reifier 尾巴：`~` 粘着第 3 项尾时就地断项凑齐；三项收齐后
      // `~ [reifier]` 整段吞掉不计项
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
    // 集合 rdf:nil 标记（Span(open.0, 0)，长度 0 = 无字节词项）：放行；
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
  if c0 == b'?' {
    // 变量形（ADR-004：只记身份）：`?` + 非空 varname。轻验只收词形——
    // 谓词位变量不接（表无行 + 明确报错），其余深验在物化层 gate_variable
    if is_predicate {
      return Some(
        ParseError::SyntaxErr(
          "Variable is not allowed in predicate position", span,
        ),
      )
    }
    if n < 2 {
      return Some(ParseError::SyntaxErr("Variable must have a name", span))
    }
    return None
  }
  if c0 == b'[' || c0 == b'(' || c0 == b'!' || c0 == b'^' {
    // fresh 结构词：`[`/`(` 开括号 token 自身 span 作 fresh 身份（`[]`/集合
    // 单一 BNode/nil 标记）；`!`/`^` 路径操作符 span = 中间节点身份（役3，
    // 引擎铸 identities，用户文本不可达此形）。语法闭合由引擎表保证
    //（栈判脏在 EOF 收尾），此处只认形态
    return None
  }
  if c0 == b'"' || c0 == b'\'' {
    // 字面量：词法已配对定界（引号 + @lang/^^ 后缀并入单 span），深度校验在物化层
    return None
  }
  // 数值/布尔字面量（span 口径，轻量验证）：物化层展开 typed literal，无前缀依赖。
  // 数值族（含前导点/符号/指数）统一交 is_numeric_span 复核（词法同口径）
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
  // PN_PREFIX/PN_LOCAL 语法面（词法加宽后的收紧点）
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
///   前缀部：不得以裸 '.' 结尾（PN_PREFIX 无尾点）
///   本地部：首字符不许 '.'/'-'（PN_LOCAL 首字符集）
///           \X 转义只许 PN_LOCAL_ESC 字符集
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
/// 组装机械唯一地点：N3PendingQuad 快照 → QuadSpan（缺槽/校验失败统一回 ParseError）
fn[L] N3SliceParser::assemble(
  self : N3SliceParser[L],
  pending : N3PendingQuad,
) -> Result[QuadSpan, ParseError] {
  // 合成谓词归一（同构保留位）：链 quad 谓词无字节时以 (0,0) 占位过缺槽检测
  //（N3 引擎 pk 恒 Normal，ADR-003b 显式链接表后启用）
  let pending = if pending.pk is PredKind::Normal {
    pending
  } else {
    { ..pending, pred: Some((0, 0)), }
  }
  match (pending.subj, pending.pred, pending.obj) {
    (Some(s), Some(p), Some(o)) => {
      if !self.lenient {
        let prefixes = self.engine.ctx.prefixes
        // 役8 壳主语：s = 锚三元组原文 span（非单一词项），跳过主语深验——
        // 分量已在主 quad（AnnotStart 出账）组装点各自过验；物化层据此合成壳
        if !pending.subj_shell {
          match validate_term(self.data, prefixes, s, false) {
            Some(e) => return Err(e)
            None => ()
          }
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
      Ok({
        s,
        p,
        o,
        g: pending.graph,
        pk: pending.pk,
        prefix_version: pending.prefix_version,
        base_version: pending.base_version,
        iri_version: pending.iri_version,
        subj_shell: pending.subj_shell,
      })
    }
    // RDF 1.2 triple-term shell standalone statement: `<< s p o >> .` --
    // shell lands in subject slot with no pred/obj; the statement IS the
    // shell's inner triple (assemble unwraps, terms re-validated recursively)
    (Some(s), None, None) => {
      let terms = triple_term_inner_terms(self.data, s)
      if terms.length() == 3 {
        let ts = terms[0]
        let tp = terms[1]
        let to = terms[2]
        if !self.lenient {
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
        }
        Ok({
          s: ts,
          p: tp,
          o: to,
          g: pending.graph,
          pk: pending.pk,
          prefix_version: pending.prefix_version,
          base_version: pending.base_version,
          iri_version: pending.iri_version,
          subj_shell: false,
        })
      } else {
        Err(ParseError::SyntaxErr("Incomplete quad at emission", s))
      }
    }
    _ =>
      // N3 无壳独立成句形态（表无主语位壳行；`[] .` 空属性列表已在
      // parse_next 静默跳过）；缺谓/宾 = 缺槽
      Err(
        ParseError::SyntaxErr(
          "Incomplete quad at emission",
          pending.subj.unwrap_or((0, 0)),
        ),
      )
  }
}

///|
/// 实现 Iter trait：逐条解析（引擎级错误也收集——EOF 不完整/业务失败不能静默吞）
pub fn[L : LexerSource] N3SliceParser::parse_next(
  self : N3SliceParser[L],
) -> Result[QuadSpan, ParseError]? {
  // 役23 R-05：上一轮积累的引擎结构错先转报（错误序 = 语句序，drain 后清）
  self.drain_engine_errors()
  match self.engine.next() {
    None => {
      // 终态清尾：finish_at_end 的不完整语句错误走 return 通道不入数组
      self.drain_engine_errors()
      None
    }
    Some(Err(e)) => {
      // 役23 R-05：业务错上报前先转报其前积累的结构错（跨型错误也保文件序）
      self.drain_engine_errors()
      Some(Err(e))
    }
    Some(Ok(pending)) => {
      // 空 fresh 结构独立成句（`[] .`）：主槽 fresh + 谓/宾全空 = 空属性列表
      // 断言零三元组，静默跳过。只认 `[`：`(...)` 集合独立成句非法，必须进组装报错
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
pub fn[L : LexerSource] N3SliceParser::parse_all(
  self : N3SliceParser[L],
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
