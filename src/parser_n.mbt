// ============================================================
// Slice 解析器（用于并发和验证物化）
// ============================================================

///|
pub struct QuadSpan {
  subj : Span
  pred : Span
  obj : Span
  graph : Span?
  line : Int
  subj_type : TermType // 主语类型
  obj_type : TermType // 宾语类型  
} derive(Debug)

///|
pub impl Show for QuadSpan with fn output(self : QuadSpan, logger : &Logger) -> Unit {
  logger.write("QuadSpan")
  logger.write("{ ")
  logger.write("subj: ")
  logger.write(@debug.to_string(self.subj))
  logger.write(", ")
  logger.write("pred: ")
  logger.write(@debug.to_string(self.pred))
  logger.write(", ")
  logger.write("obj: ")
  logger.write(@debug.to_string(self.obj))
  logger.write(", ")
  logger.write("graph: ")
  if self.graph is Some(graph) {
    logger.write(@debug.to_string(graph))
  }
  logger.write(", ")
  logger.write("line: ")
  logger.write(self.line)
  logger.write(", ")
  logger.write("subj_type: ")
  logger.write(@debug.to_string(self.subj_type))
  logger.write(", ")
  logger.write("obj_type: ")
  logger.write(@debug.to_string(self.obj_type))
  logger.write("}")
}

///|
// 主语类型
// pub(all) enum SubjType {
//   Iri
//   BNode
//   Prefix
// } derive(Debug)

///|
// pub impl Show for SubjType with fn output(self : SubjType, logger : &Logger) -> Unit {
//   match self {
//     Iri => logger.write("Iri")
//     BNode => logger.write("BNode")
//     Prefix => logger.write("Prefix")
//   }
// }
// // 宾语类型

// ///|
// pub(all) enum ObjType {
//   Iri
//   BNode
//   Prefix
//   Literal
// } derive(Debug)

// ///|
// pub impl Show for ObjType with fn output(self : ObjType, logger : &Logger) -> Unit {
//   match self {
//     Iri => logger.write("Iri")
//     BNode => logger.write("BNode")
//     Prefix => logger.write("Prefix")
//     Literal => logger.write("Literal")
//   }
// }
pub(all) enum TermType {
  Unknown
  Iri
  BNode
  Literal
  PrefName
} derive(Debug, Eq)

///|
pub impl Show for TermType with fn output(self : TermType, logger : &Logger) -> Unit {
  match self {
    Iri => logger.write("Iri")
    BNode => logger.write("BNode")
    PrefName => logger.write("PrefName")
    Literal => logger.write("Literal")
    Unknown => logger.write("Unknown")
  }
}

///|
pub struct ParserIter[E] {
  parser : ParserE[E]
}

///|
pub fn[E] ParserIter::new(parser : ParserE[E]) -> ParserIter[E] {
  { parser, }
}

///|
pub fn[E : ParserEngine] ParserIter::next(
  self : ParserIter[E],
) -> Result[PendingQuad, ParseError]? {
  self.parser.next()
}

///|
pub struct SliceParser[E] {
  inner : ParserIter[E]
  data : ArrayView[Byte]
  lenient : Bool // lenient 模式下跳过验证
}

///|
pub fn[E] SliceParser::new(
  parser : ParserE[E],
  data : ArrayView[Byte],
  lenient? : Bool = false,
) -> SliceParser[E] {
  { inner: ParserIter::new(parser), data, lenient }
}

///|
/// 实现 Iter trait
pub fn[E : ParserEngine] SliceParser::next(
  self : SliceParser[E],
) -> Result[QuadSpan, ParseError]? {
  match self.inner.next() {
    None => None
    Some(Err(err)) => Some(Err(err))
    Some(Ok(pending)) =>
      match self.validate(pending) {
        Ok(quad) => Some(Ok(quad))
        Err(e) => Some(Err(e))
      }
  }
}

///|
/// 解析全部
pub fn[E : ParserEngine] SliceParser::parse_all(
  self : SliceParser[E],
) -> (Array[QuadSpan], Array[ParseError]) {
  let quads : Array[QuadSpan] = []
  let errors = []

  for ;; {
    match self.inner.next() {
      Some(Ok(pending)) =>
        match self.validate(pending) {
          Ok(q) => quads.push(q)
          Err(e) => errors.push(e)
        }
      Some(Err(e)) => errors.push(e)
      None => break
    }
  }

  (quads, errors)
}

///|
/// 物化 Quad
pub fn materialize_quad(
  quad : QuadSpan,
  data : ArrayView[Byte],
) -> Result[Quad, ParseError] {
  let subject = match materialize_subject(quad.subj, quad.subj_type, data) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let predicate = match materialize_predicate(quad.pred, data) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let object = match materialize_object(quad.obj, quad.obj_type, data) {
    Ok(o) => o
    Err(e) => return Err(e)
  }
  let graph_name = match materialize_graph_name(quad.graph, data) {
    Ok(g) => g
    Err(e) => return Err(e)
  }

  Ok({ subject, predicate, object, graph_name })
}

///|
/// 批量物化
pub fn materialize_all(
  quads : Array[QuadSpan],
  data : ArrayView[Byte],
) -> (Array[Quad], Array[ParseError]) {
  let results = []
  let errors = []

  for quad in quads {
    match materialize_quad(quad, data) {
      Ok(q) => results.push(q)
      Err(e) => errors.push(e)
    }
  }

  (results, errors)
}

///|
/// 物化主语
fn materialize_subject(
  span : Span,
  t : TermType,
  data : ArrayView[Byte],
) -> Result[NamedOrBlankNode, ParseError] {
  match t {
    TermType::Iri =>
      match validate_iri(data, span) {
        Ok(_) =>
          Ok(NamedOrBlankNode::NamedNode({ iri: extract_iri(span, data) }))
        Err(e) => Err(e)
      }
    TermType::BNode =>
      match validate_bnode(data, span) {
        Ok(_) =>
          Ok(
            NamedOrBlankNode::BlankNode(
              BlankNode::Named(extract_label(span, data)),
            ),
          )
        Err(e) => Err(e)
      }
    TermType::PrefName =>
      // N-Quads 不支持前缀名
      Err(
        ParseError::from_span("N-Quads does not support prefixed names.", span),
      )
    TermType::Literal =>
      Err(ParseError::from_span("Subject cannot be a literal", span))
    TermType::Unknown => Err(ParseError::from_span("Invalid subject", span))
  }
}

///|
/// 物化谓语（必须是 IRI）
fn materialize_predicate(
  span : Span,
  data : ArrayView[Byte],
) -> Result[NamedNode, ParseError] {
  match validate_iri(data, span) {
    Ok(_) => Ok({ iri: extract_iri(span, data) })
    Err(e) => Err(e)
  }
}

///|
/// 物化宾语
fn materialize_object(
  span : Span,
  t : TermType,
  data : ArrayView[Byte],
) -> Result[Term, ParseError] {
  match t {
    TermType::Iri =>
      match validate_iri(data, span) {
        Ok(_) => Ok(Term::NamedNode({ iri: extract_iri(span, data) }))
        Err(e) => Err(e)
      }
    TermType::BNode =>
      match validate_bnode(data, span) {
        Ok(_) =>
          Ok(Term::BlankNode(BlankNode::Named(extract_label(span, data))))
        Err(e) => Err(e)
      }
    TermType::Literal => Ok(Term::Literal(parse_literal(span, data)))
    TermType::PrefName =>
      // N-Quads 中前缀名当作字面量或错误（根据需求）
      Err(
        ParseError::from_span("N-Quads does not support prefixed names", span),
      )
    TermType::Unknown =>
      // 可能是不支持的字符，尝试当作 Literal
      Err(ParseError::from_span("Invalid object", span))
  }
}

///|
/// 物化图名
fn materialize_graph_name(
  span : Span?,
  data : ArrayView[Byte],
) -> Result[GraphName, ParseError] {
  match span {
    Some(g) =>
      match validate_iri(data, g) {
        Ok(_) => Ok(GraphName::NamedNode({ iri: extract_iri(g, data) }))
        Err(e) => Err(e)
      }
    None => Ok(GraphName::DefaultGraph)
  }
}
// ============================================================
// 辅助提取函数
// ============================================================

///|
/// 提取 IRI（去掉 <>）
fn extract_iri(span : Span, data : ArrayView[Byte]) -> String {
  let (offset, length) = span
  let end = offset + length
  if length > 2 && data[offset] == b'<' && data[end - 1] == b'>' {
    bytes_to_string(data[offset + 1:end - 1])
  } else {
    bytes_to_string(data[offset:end])
  }
}

///|
/// 提取 Blank Node 标签（去掉 _: 前缀）
fn extract_label(span : Span, data : ArrayView[Byte]) -> String {
  let (offset, length) = span
  // _:b1 → b1
  if length >= 2 && data[offset] == b'_' && data[offset + 1] == b':' {
    bytes_to_string(data[offset + 2:offset + length])
  } else {
    bytes_to_string(data[offset:offset + length])
  }
}

///|
/// 字面量转 Term

///|
/// 解析字面量
fn parse_literal(span : Span, data : ArrayView[Byte]) -> Literal {
  let (offset, length) = span
  let end = offset + length

  // 找到引号范围
  if length < 2 {
    return Literal::new_simple_literal(bytes_to_string(data[offset:end]))
  }

  let quote = data[offset]
  if quote != b'"' && quote != b'\'' {
    return Literal::new_simple_literal(bytes_to_string(data[offset:end]))
  }

  // 从后往前找结束引号
  let mut close_quote = end - 1
  while close_quote > offset && data[close_quote] != quote {
    close_quote -= 1
  }

  // 提取内容（去掉引号）
  let content = data[offset + 1:close_quote]
  let suffix = data[close_quote + 1:end]

  // 检查是否有 @lang 或 ^^datatype
  let suffix_str = bytes_to_string(suffix).trim()

  if suffix_str.has_prefix("^^") {
    // 数据类型：^^<datatype> 或 ^^prefix:local
    let dt_str = suffix_str[2:]
    if dt_str.has_prefix("<") && dt_str.has_suffix(">") {
      // IRI 格式
      let iri = dt_str[1:dt_str.length() - 1]
      LiteralRef::new_typed_literal(
        bytes_to_string(content),
        NamedNodeRef::NamedNodeRef(iri),
      ).into_owned()
    } else {
      // 前缀格式（简化处理，假设 xsd:）
      LiteralRef::new_typed_literal(
        bytes_to_string(content),
        NamedNodeRef::NamedNodeRef(
          "http://www.w3.org/2001/XMLSchema\\#" + dt_str.to_owned(),
        ),
      ).into_owned()
    }
  } else if suffix_str.has_prefix("@") {
    // 语言标签
    let lang = suffix_str[1:]
    match
      Literal::new_language_tagged_literal(
        bytes_to_string(content),
        lang.to_owned(),
      ) {
      Ok(lit) => lit
      Err(_) => Literal::new_simple_literal(bytes_to_string(content))
    }
  } else {
    // 简单字面量
    Literal::new_simple_literal(bytes_to_string(content))
  }
}

///|
/// 字节数组转字符串
fn bytes_to_string(bytes : ArrayView[Byte]) -> String {
  let buf = StringBuilder::new()
  for b in bytes {
    buf.write_char(b.to_char())
  }
  buf.to_string()
}

// fn NQuadsSerializer::extract_iri(self : NQuadsSerializer, span : Span) -> String {
//   extract_iri(span, self.data)
// }

///|
/// 验证 PendingQuad

///|
fn[E] SliceParser::validate(
  self : SliceParser[E],
  pending : PendingQuad,
) -> Result[QuadSpan, ParseError] {
  // 结构检查
  let subj = match pending.subj {
    Some(s) => s
    None =>
      return Err(
        ParseError::from_span("Missing subject", pending.compute_span()),
      )
  }
  let pred = match pending.pred {
    Some(p) => p
    None =>
      return Err(
        ParseError::from_span("Missing predicate", pending.compute_span()),
      )
  }
  let obj = match pending.obj {
    Some(o) => o
    None =>
      return Err(
        ParseError::from_span("Missing object", pending.compute_span()),
      )
  }

  // 检测主语和宾语的类型
  let subj_type = detect_term_type(subj, self.data)
  let obj_type = detect_term_type(obj, self.data)

  Ok({
    subj,
    pred,
    obj,
    graph: pending.graph,
    line: pending.line,
    subj_type,
    obj_type,
  })
}

// ============================================================
// 类型判断辅助函数
// ============================================================

// ///|
// fn[E] SliceParser::is_iri_start(self : SliceParser[E], span : Span) -> Bool {
//   let (offset, _) = span
//   self.data[offset] == b'<'
// }

// ///|
// fn[E] SliceParser::is_bnode_start(self : SliceParser[E], span : Span) -> Bool {
//   let (offset, _) = span
//   self.data[offset] == b'_' &&
//   offset + 1 < self.data.length() &&
//   self.data[offset + 1] == b':'
// }

// ///|
// fn[E] SliceParser::is_literal_start(self : SliceParser[E], span : Span) -> Bool {
//   let (offset, _) = span
//   let c = self.data[offset]
//   c == b'"' || c == b'\''
// }

// ///|
// fn[E] SliceParser::is_prefix_start(self : SliceParser[E], span : Span) -> Bool {
//   let (offset, _) = span
//   let c = self.data[offset]
//   // 不是 <, 不是 _: , 不是 " 或 '
//   (c >= b'a' && c <= b'z') || (c >= b'A' && c <= b'Z') || c == b':'
// }

///|
/// 优化的 IRI 验证
pub fn validate_iri(
  data : ArrayView[Byte],
  span : Span,
) -> Result[Span, ParseError] {
  let (offset, length) = span
  let end = offset + length

  // 格式检查：<> 包裹
  if length < 2 || data[offset] != b'<' || data[end - 1] != b'>' {
    return Err(ParseError::from_span("IRI must be wrapped in <>", span))
  }

  let content_start = offset + 1
  let content_end = end - 1
  let content_len = content_end - content_start

  // 非空检查
  if content_len == 0 {
    return Err(ParseError::from_span("IRI cannot be empty", span))
  }

  // 协议检查
  if content_len >= 8 {
    let c0 = data[content_start]
    let is_http = c0 == b'h' &&
      data[content_start + 1] == b't' &&
      data[content_start + 2] == b't' &&
      data[content_start + 3] == b'p' &&
      data[content_start + 4] == b':' &&
      data[content_start + 5] == b'/' &&
      data[content_start + 6] == b'/'
    let is_https = c0 == b'h' &&
      data[content_start + 1] == b't' &&
      data[content_start + 2] == b't' &&
      data[content_start + 3] == b'p' &&
      data[content_start + 4] == b's' &&
      data[content_start + 5] == b':' &&
      data[content_start + 6] == b'/' &&
      data[content_start + 7] == b'/'

    if !(is_http || is_https) {
      return Err(
        ParseError::from_span("IRI must start with http:// or https://", span),
      )
    }
  } else {
    return Err(
      ParseError::from_span("IRI must start with http:// or https://", span),
    )
  }

  // 字符检查（O(1) 查表）
  for i = content_start; i < content_end; i = i + 1 {
    if is_illegal_iri_char(data[i]) {
      return Err(ParseError::from_span("IRI contains illegal character", span))
    }
  }

  Ok(span)
}

// ============================================================
// 前缀 :本地名（用于简化前缀，如 :name）
// ============================================================
// ============================================================
// 空白节点 _:xxx
// ============================================================

///|
fn validate_bnode(
  data : ArrayView[Byte],
  span : Span,
) -> Result[Span, ParseError] {
  let (offset, length) = span
  let end = offset + length

  if length < 2 || !(data[offset] == b'_' && data[offset + 1] == b':') {
    return Err(ParseError::from_span("Blank node must start with _:", span))
  }

  let label_start = offset + 2
  if label_start >= end {
    return Err(ParseError::from_span("Blank node label is empty", span))
  }

  if !is_pn_chars_u(data[label_start]) {
    return Err(
      ParseError::from_span(
        "Blank node label must start with letter or underscore", span,
      ),
    )
  }

  let mut last = label_start
  let mut i = label_start + 1
  while i < end && is_pn_chars(data[i]) {
    last = i
    i += 1
  }

  if data[last] == b'.' && last > label_start {
    return Err(ParseError::from_span("Blank node cannot end with '.'", span))
  }

  Ok(span)
}

///|
let first_byte_type : FixedArray[TermType] = {
  let table = FixedArray::make(256, TermType::Unknown)
  table[b'_'.to_int()] = TermType::BNode // _: 开头
  table[b'"'.to_int()] = TermType::Literal
  table[b'\''.to_int()] = TermType::Literal
  table['<'.to_int()] = TermType::Iri // ← 添加
  table
}

///|
fn detect_term_type(span : Span, data : ArrayView[Byte]) -> TermType {
  let (offset, length) = span
  if length == 0 {
    return TermType::Unknown
  }

  let first = data[offset]
  let t = first_byte_type[first.to_int()]
  match t {
    TermType::Iri =>
      if length >= 2 && first == b'<' && data[offset + length - 1] == b'>' {
        TermType::Iri
      } else {
        TermType::PrefName
      }
    TermType::BNode =>
      if length >= 2 && data[1] == b':' {
        TermType::BNode
      } else {
        TermType::PrefName
      }
    TermType::Literal => TermType::Literal
    _ =>
      if is_numeric_string(span, data) {
        TermType::Literal
      } else {
        TermType::PrefName
      }
  }
}

///|
/// 检测是否是数字字符串
fn is_numeric_string(span : Span, data : ArrayView[Byte]) -> Bool {
  let (offset, length) = span
  if length == 0 {
    return false
  }
  let first = data[offset]
  if first >= b'0' && first <= b'9' {
    return true
  }
  if first == b'-' || first == b'+' {
    return length > 1 && data[offset + 1] >= b'0' && data[offset + 1] <= b'9'
  }
  false
}
