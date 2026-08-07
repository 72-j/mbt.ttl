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
  obj_type : ObjType
  subj_type : SubjType
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
  logger.write("obj_type: ")
  logger.write(self.obj_type)
  logger.write(", ")
  logger.write("subj_type: ")
  logger.write(self.subj_type)
  logger.write("}")
}

///|
// 主语类型
pub(all) enum SubjType {
  Iri
  BNode
  Prefix
} derive(Debug)

///|
pub impl Show for SubjType with fn output(self : SubjType, logger : &Logger) -> Unit {
  match self {
    Iri => logger.write("Iri")
    BNode => logger.write("BNode")
    Prefix => logger.write("Prefix")
  }
}
// 宾语类型

///|
pub(all) enum ObjType {
  Iri
  BNode
  Prefix
  Literal
} derive(Debug)

///|
pub impl Show for ObjType with fn output(self : ObjType, logger : &Logger) -> Unit {
  match self {
    Iri => logger.write("Iri")
    BNode => logger.write("BNode")
    Prefix => logger.write("Prefix")
    Literal => logger.write("Literal")
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

  for result in self.next() {
    match result {
      Ok(quad) => quads.push(quad)
      Err(err) => errors.push(err)
    }
  }

  (quads, errors)
}

///|
/// 验证 PendingQuad

///|
fn[E] SliceParser::validate(
  self : SliceParser[E],
  pending : PendingQuad,
) -> Result[QuadSpan, ParseError] {
  // 1. 验证主语
  let (subj, subj_type) = match pending.subj {
    Some(s) =>
      if self.is_bnode_start(s) {
        match validate_bnode(self.data, s) {
          Ok(_) => (s, SubjType::BNode)
          Err(e) => return Err(e)
        }
      } else if self.is_iri_start(s) {
        match validate_iri(self.data, s) {
          Ok(_) => (s, SubjType::Iri)
          Err(e) => return Err(e)
        }
      } else if self.is_prefix_start(s) {
        match validate_prefix_name(self.data, s) {
          Ok(_) => (s, SubjType::Prefix)
          Err(e) => return Err(e)
        }
      } else {
        return Err(ParseError::from_span("Invalid subject", s))
      }
    None =>
      return Err(
        ParseError::from_span("Missing subject", pending.compute_span()),
      )
  }

  // 2. 验证谓语
  let pred = match pending.pred {
    Some(p) => {
      if !self.is_iri_start(p) {
        return Err(ParseError::from_span("Predicate must be an IRI", p))
      }
      match validate_iri(self.data, p) {
        Ok(_) => p
        Err(e) => return Err(e)
      }
    }
    None =>
      return Err(
        ParseError::from_span("Missing predicate", pending.compute_span()),
      )
  }

  // 3. 验证宾语
  let (obj, obj_type) = match pending.obj {
    Some(o) =>
      if self.is_iri_start(o) {
        match validate_iri(self.data, o) {
          Ok(_) => (o, ObjType::Iri)
          Err(e) => return Err(e)
        }
      } else if self.is_bnode_start(o) {
        match validate_bnode(self.data, o) {
          Ok(_) => (o, ObjType::BNode)
          Err(e) => return Err(e)
        }
      } else if self.is_literal_start(o) {
        match validate_literal(self.data, o) {
          Ok(_) => (o, ObjType::Literal)
          Err(e) => return Err(e)
        }
      } else if self.is_prefix_start(o) {
        match validate_prefix_name(self.data, o) {
          Ok(_) => (o, ObjType::Prefix)
          Err(e) => return Err(e)
        }
      } else {
        return Err(ParseError::from_span("Invalid object", o))
      }
    None =>
      return Err(
        ParseError::from_span("Missing object", pending.compute_span()),
      )
  }

  // 4. 验证图名
  let graph = match pending.graph {
    Some(g) => {
      if !self.is_iri_start(g) {
        return Err(ParseError::from_span("Graph must be an IRI", g))
      }
      match validate_iri(self.data, g) {
        Ok(_) => Some(g)
        Err(e) => return Err(e)
      }
    }
    None => None
  }

  // 5. 检查结束符
  if !pending.has_dot && graph is None {
    return Err(
      ParseError::from_span(
        "Quad must end with '.' or have a graph",
        pending.compute_span(),
      ),
    )
  }

  Ok({ subj, pred, obj, graph, line: pending.line, subj_type, obj_type })
}
// ============================================================
// 类型判断辅助函数
// ============================================================

///|
fn[E] SliceParser::is_iri_start(self : SliceParser[E], span : Span) -> Bool {
  let (offset, _) = span
  self.data[offset] == b'<'
}

///|
fn[E] SliceParser::is_bnode_start(self : SliceParser[E], span : Span) -> Bool {
  let (offset, _) = span
  self.data[offset] == b'_' &&
  offset + 1 < self.data.length() &&
  self.data[offset + 1] == b':'
}

///|
fn[E] SliceParser::is_literal_start(self : SliceParser[E], span : Span) -> Bool {
  let (offset, _) = span
  let c = self.data[offset]
  c == b'"' || c == b'\''
}

///|
fn[E] SliceParser::is_prefix_start(self : SliceParser[E], span : Span) -> Bool {
  let (offset, _) = span
  let c = self.data[offset]
  // 不是 <, 不是 _: , 不是 " 或 '
  (c >= b'a' && c <= b'z') || (c >= b'A' && c <= b'Z') || c == b':'
}

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
fn validate_prefix_name(
  data : ArrayView[Byte],
  span : Span,
) -> Result[Span, ParseError] {
  let (offset, length) = span
  let end = offset + length

  // 查找冒号位置
  let mut colon_pos = -1
  for i = offset; i < end; i = i + 1 {
    if data[i] == b':' {
      colon_pos = i
      break
    }
  }

  if colon_pos < 0 {
    return Err(ParseError::from_span("Invalid prefix: missing ':'", span))
  }

  // 前缀名部分（冒号前）
  let prefix_start = offset
  let prefix_end = colon_pos

  if prefix_end == prefix_start {
    return Err(ParseError::from_span("Prefix name is empty", span))
  }

  // 前缀名第一个字符必须是字母或下划线
  if !is_pn_chars_u(data[prefix_start]) {
    return Err(
      ParseError::from_span("Prefix must start with letter or underscore", span),
    )
  }

  // 前缀名后续字符
  let mut last = prefix_start
  for i = prefix_start + 1; i < prefix_end; i = i + 1 {
    if !is_pn_chars(data[i]) {
      return Err(ParseError::from_span("Invalid character in prefix", span))
    }
    last = i
  }

  if data[last] == b'.' && last > prefix_start {
    return Err(ParseError::from_span("Prefix cannot end with '.'", span))
  }

  Ok(span)
}

// ============================================================
// 字面量验证
// ============================================================

///|
/// 验证字面量
/// 支持：单行 "..." / '...'，多行 """...""" / '''...'''
fn validate_literal(
  data : ArrayView[Byte],
  span : Span,
) -> Result[Span, ParseError] {
  let (offset, length) = span
  let end = offset + length

  if length < 2 {
    return Err(ParseError::from_span("Literal too short", span))
  }

  let quote = data[offset]

  // 检查多行字符串
  if length >= 3 && data[offset + 1] == quote && data[offset + 2] == quote {
    // 多行字符串：允许换行，不需要转义
    validate_multiline_literal(data, offset, end, quote)
  } else {
    // 单行字符串：不允许未转义的换行符
    validate_single_line_literal(data, offset, end, quote)
  }
}

///|
/// 单行字面量验证
/// 规则：内容中不能包含未转义的换行符
fn validate_single_line_literal(
  data : ArrayView[Byte],
  start : Int,
  end : Int,
  quote : Byte,
) -> Result[Span, ParseError] {
  let content_start = start + 1
  let content_end = end - 1

  // 从后往前找结束引号
  let mut close_pos = -1
  let mut i = end - 1
  while i > start {
    if data[i] == quote && (i == 0 || data[i - 1] != b'\\') {
      close_pos = i
      break
    }
    i -= 1
  }

  if close_pos < 0 {
    return Err(
      ParseError::from_span("Unterminated string", (start, end - start)),
    )
  }

  // 检查内容中的换行符
  let mut i = content_start
  while i < content_end - 1 {
    let c = data[i]

    // 检查转义
    if c == b'\\' && i + 1 < content_end {
      i += 2 // 跳过转义字符
      continue
    }

    // 检查换行符（单行字符串不允许）
    if c == b'\n' || c == b'\r' {
      return Err(
        ParseError::from_span(
          "Single-line literal cannot contain newline",
          (start, end - start),
        ),
      )
    }

    i += 1
  }

  Ok((start, end - start))
}

///|
/// 多行字面量验证
/// 规则：结束符必须是三个相同引号
fn validate_multiline_literal(
  data : ArrayView[Byte],
  start : Int,
  end : Int,
  quote : Byte,
) -> Result[Span, ParseError] {
  // 结束符检查：最后三个字符必须是引号
  if end < start + 6 {
    return Err(
      ParseError::from_span(
        "Unterminated multiline string",
        (start, end - start),
      ),
    )
  }

  let last3 = end - 3
  if !(data[last3] == quote &&
    data[last3 + 1] == quote &&
    data[last3 + 2] == quote) {
    return Err(
      ParseError::from_span(
        "Multiline string must end with three quotes",
        (start, end - start),
      ),
    )
  }

  // 多行字符串内容可以是任意字符
  Ok((start, end - start))
}
