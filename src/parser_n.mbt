// ============================================================
// Slice 解析器（用于并发和验证物化）
// ============================================================

///|
pub type Span = (Int, Int)

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
/// 链式调用设置宽松模式
pub fn[E] SliceParser::lenient(self : SliceParser[E]) -> SliceParser[E] {
  { ..self, lenient: true }
}

///|
/// 实现 Iter trait
pub fn[E : ParserEngine] SliceParser::next(
  self : SliceParser[E],
) -> Result[QuadSpan, ParseError]? {
  let result = self.inner.next()
  match result {
    None => None
    Some(Err(e)) => Some(Err(e))
    Some(Ok(pending)) => {
      let validated = self.validate(pending)
      // 这里 validated 如果是 Err，应该返回 Some(Err(...))
      // 如果是 Ok，应该返回 Some(Ok(...))
      // 但不能返回 None
      match validated {
        Ok(q) => Some(Ok(q))
        Err(e) => Some(Err(e))
      }
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
    match self.next() {
      Some(Ok(q)) => quads.push(q)
      Some(Err(e)) => errors.push(e)
      None => break
    }
  }
  // let (valid_quads, seq_errors) = validate_quad_span_sequential(quads)

  // for e in seq_errors {
  //   errors.push(e)
  // }

  (quads, errors)
}

///|
/// 物化 Quad（批量优化）
pub fn materialize_quad(
  quad : QuadSpan,
  data : ArrayView[Byte],
) -> Result[QuadEmit, ParseError] {
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

  Ok({ subject, predicate, object, graph_name, line: quad.line })
}

///|
/// 批量物化（优化：减少函数调用开销）
pub fn materialize_all(
  quads : Array[QuadSpan],
  data : ArrayView[Byte],
) -> (Array[QuadEmit], Array[ParseError]) {
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
) -> Result[Subject, ParseError] {
  let (offset, length) = span
  let end = offset + length

  // 边界检查
  if offset < 0 || end > data.length() || offset >= end {
    return Err(ParseError::from_span("Invalid span bounds", span))
  }
  match t {
    TermType::Iri =>
      match validate_iri(data, span) {
        Ok(_) => Ok(Subject::Iri(span))
        Err(e) => Err(e)
      }
    TermType::BNode =>
      match validate_bnode(data, span) {
        Ok(_) => Ok(Subject::BNode(span))
        Err(e) => Err(e)
      }
    TermType::PrefName =>
      Err(
        ParseError::from_span("N-Quads does not support prefixed names", span),
      )
    TermType::Literal =>
      Err(ParseError::from_span("Subject cannot be literal", span))
    TermType::Unknown => Err(ParseError::from_span("Invalid subject", span))
  }
}

///|
/// 物化宾语
fn materialize_object(
  span : Span,
  t : TermType,
  data : ArrayView[Byte],
) -> Result[Object, ParseError] {
  // 边界检查
  let (offset, length) = span
  let end = offset + length

  // 边界检查
  if offset < 0 || end > data.length() || offset >= end {
    return Err(ParseError::from_span("Invalid span bounds", span))
  }
  match t {
    TermType::Iri =>
      match validate_iri(data, span) {
        Ok(_) => Ok(Object::Iri(span))
        Err(e) => Err(e)
      }
    TermType::BNode =>
      match validate_bnode(data, span) {
        Ok(_) => Ok(Object::BNode(span))
        Err(e) => Err(e)
      }
    TermType::Literal => Ok(Object::Literal(span))
    TermType::PrefName =>
      Err(
        ParseError::from_span("N-Quads does not support prefixed names", span),
      )
    TermType::Unknown => Err(ParseError::from_span("Invalid object", span))
  }
}

///|
/// 物化谓语（只能是 IRI）
fn materialize_predicate(
  span : Span,
  data : ArrayView[Byte],
) -> Result[Predicate, ParseError] {
  let (offset, length) = span
  let end = offset + length
  // println("predicate span: offset=\{offset}, length=\{length}, end=\{end}")
  // if offset >= 0 && end <= data.length() && offset < end {
  //   let first_char = data[offset]
  //   println(
  //     "  first char: '\{first_char.to_char()}' (0x\{first_char.to_hex()})",
  //   )
  // }
  // 边界检查
  if offset < 0 || end > data.length() || offset >= end {
    return Err(ParseError::from_span("Invalid span bounds", span))
  }
  match validate_iri(data, span) {
    Ok(_) => Ok(span)
    Err(e) => Err(e)
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
        Ok(_) => Ok(GraphName::Iri(g))
        Err(e) => Err(e)
      }
    None => Ok(GraphName::None)
  }
}

/// 验证 PendingQuad
// fn validate_quad_span_sequential(
//   quads : Array[QuadSpan],
// ) -> (Array[QuadSpan], Array[ParseError]) {
//   let valid = []
//   let errors = []
//   let mut last_offset = -1

//   for q in quads {
//     // 检查 offset 是否递增
//     if q.subj.0 <= last_offset {
//       errors.push(ParseError::from_span(
//         "Quad spans not sequential, possible lexer corruption",
//         q.subj,
//       ))
//       continue
//     }
//     last_offset = q.subj.0 + q.subj.1
//     valid.push(q)
//   }

//   (valid, errors)
// }

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

  // 严格模式：验证 IRI 格式
  if !self.lenient {
    // 验证 IRI
    if subj_type == TermType::Iri {
      match validate_iri(self.data, subj) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    if obj_type == TermType::Iri {
      match validate_iri(self.data, obj) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    // 验证 BlankNode
    if subj_type == TermType::BNode {
      match validate_bnode(self.data, subj) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    if obj_type == TermType::BNode {
      match validate_bnode(self.data, obj) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
  }

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

///|
/// IRI 验证
pub fn validate_iri(
  data : ArrayView[Byte],
  span : Span,
) -> Result[Span, ParseError] {
  let (offset, length) = span
  let end = offset + length

  // 边界检查
  if offset < 0 || end > data.length() || offset >= end {
    return Err(ParseError::from_span("Invalid span", span))
  }

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

  // 协议检查 - 问题可能在这里！
  // http:// 需要 8 个字符
  // ftp:// 也需要 8 个字符，但协议不是 http/https
  let c0 = data[content_start]

  let is_http = content_len >= 8 &&
    c0 == b'h' &&
    data[content_start + 1] == b't' &&
    data[content_start + 2] == b't' &&
    data[content_start + 3] == b'p' &&
    data[content_start + 4] == b':' &&
    data[content_start + 5] == b'/' &&
    data[content_start + 6] == b'/'

  let is_https = content_len >= 9 &&
    c0 == b'h' &&
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

  // 字符检查
  for i = content_start; i < content_end; i = i + 1 {
    if is_illegal_iri_char(data[i]) {
      return Err(ParseError::from_span("IRI contains illegal character", span))
    }
  }

  Ok(span)
}

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
  // debug("detect_term_type: first='\{first.to_char()}', length=\{length}")

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
