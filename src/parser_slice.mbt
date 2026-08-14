///|
pub struct ParserIter[E] {
  parser : Parser[E]
}

///|
pub fn[E] ParserIter::new(
  parser : Parser[E],
  // last_error_span : Span,
) -> ParserIter[E] {
  { parser, }
}

///|
/// ParserIter 添加 get_errors 方法
// pub fn[E] ParserIter::get_error(self : ParserIter[E]) -> ParseError? {
//   self.parser.get_error()
// }

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
  errors : Array[ParseError] // 收集的结构错误
}

///|
pub fn[E] SliceParser::new(
  parser : Parser[E],
  data : ArrayView[Byte],
  lenient? : Bool = false,
) -> SliceParser[E] {
  { inner: ParserIter::new(parser), data, lenient, errors: [] }
}

///|
/// 链式调用设置宽松模式
pub fn[E] SliceParser::lenient(self : SliceParser[E]) -> SliceParser[E] {
  { ..self, lenient: true }
}

///|
/// 实现 Iter trait

///|
pub fn[E : ParserEngine] SliceParser::next(
  self : SliceParser[E],
) -> Result[QuadSpan, ParseError]? {
  for ;; {
    match self.inner.next() {
      None =>
        return {
          // 检查最后是否有未处理的错误
          match self.inner.parser.last_error {
            Some((span, line)) =>
              self.errors.push(
                ParseError::StructSyntaxErr("Structure error", line, span),
              )
            None => ()
          }
          return None
        }
      Some(Err(e)) => return Some(Err(e))
      Some(Ok(pending)) =>
        // 收集 Parser 中的结构错误
        // match self.inner.get_error() {
        //   Some(err) => {
        //     debug("Parser error: \{err}")
        //     self.errors.push(err)
        //   }
        //   None => ()
        // }

        // if !pending.is_complete() {
        //   continue
        // }

        match self.validate(pending) {
          Ok(q) => return Some(Ok(q))
          Err(e) => {
            self.errors.push(e)
            continue
          }
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
  let errors = self.errors

  for ;; {
    match self.next() {
      Some(Ok(q)) => quads.push(q)
      Some(Err(_e)) => continue
      None => break
    }
  }

  (quads, errors)
}

///|
fn[E] SliceParser::validate(
  self : SliceParser[E],
  pending : PendingQuad,
) -> Result[QuadSpan, ParseError] {
  // 提取 span 并切分 data
  let (subj_off, subj_len) = pending.subj
  let (pred_off, pred_len) = pending.pred
  let (obj_off, obj_len) = pending.obj

  // 边界检查
  if subj_off < 0 || subj_off + subj_len > self.data.length() {
    return Err(ParseError::SyntaxErr("Invalid subject span", pending.subj))
  }
  if pred_off < 0 || pred_off + pred_len > self.data.length() {
    return Err(ParseError::SyntaxErr("Invalid predicate span", pending.pred))
  }
  if obj_off < 0 || obj_off + obj_len > self.data.length() {
    return Err(ParseError::SyntaxErr("Invalid object span", pending.obj))
  }

  let subject = self.data[subj_off:subj_off + subj_len]
  let predicate = self.data[pred_off:pred_off + pred_len]
  let object = self.data[obj_off:obj_off + obj_len]

  // 检测主语和宾语的类型
  let subj_type = if subject[0] == b'_' {
    TermType::BNode
  } else {
    TermType::Iri
  }

  let obj_type = if object[0] == b'_' {
    TermType::BNode
  } else if object[0] == b'"' {
    TermType::Literal
  } else {
    TermType::Iri
  }
  // 严格模式：验证 IRI 格式
  if !self.lenient {
    // 验证 IRI
    if subj_type == TermType::Iri {
      match validate_iri(subject) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    if obj_type == TermType::Iri {
      match validate_iri(object) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    // 验证 BlankNode
    if subj_type == TermType::BNode {
      match validate_bnode(subject) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
    if obj_type == TermType::BNode {
      match validate_bnode(object) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    }
  }
  // 图名

  let (g_off, g_len) = pending.graph
  if g_len > 0 {
    if g_off < 0 || g_off + g_len > self.data.length() {
      return Err(ParseError::SyntaxErr("Invalid graph span", pending.graph))
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
    // line: pending.line,
    subj_type,
    obj_type,
    // has_err: pending.has_err,
  })
}

///|
/// IRI 验证
fn validate_iri(iri : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let len = iri.length()

  if len < 2 || iri[0] != b'<' || iri[len - 1] != b'>' {
    return Err(ParseError::SyntaxErr("IRI must be wrapped in <>", (0, len)))
  }

  if len == 2 {
    return Err(ParseError::SyntaxErr("IRI cannot be empty", (0, len)))
  }

  // 可选：验证协议
  let inner = iri[1:len - 1]
  let first = inner[0]

  if !(first == b'h' || first == b'f' || first == b'm' || first == b'/') {
    return Err(
      ParseError::SyntaxErr(
        "IRI must start with http://, https://, or ftp://",
        (1, inner.length()),
      ),
    )
  }

  Ok(())
}

///|
/// BNode 验证
fn validate_bnode(bnode : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let len = bnode.length()

  if len < 3 || bnode[0] != b'_' || bnode[1] != b':' {
    return Err(ParseError::SyntaxErr("Blank node must start with _:", (0, len)))
  }

  let first = bnode[2]
  if !((first >= b'a' && first <= b'z') ||
    (first >= b'A' && first <= b'Z') ||
    first == b'_') {
    return Err(
      ParseError::SyntaxErr(
        "Blank node label must start with letter or underscore",
        (2, 1),
      ),
    )
  }

  Ok(())
}
