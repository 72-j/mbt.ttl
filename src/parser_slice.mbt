///|
pub struct ParserIter[E] {
  parser : Parser[E]
}

///|
pub fn[E] ParserIter::new(parser : Parser[E]) -> ParserIter[E] {
  { parser, }
}

///|
pub fn[E : ParserEngine] ParserIter::next(
  self : ParserIter[E],
) -> Result[PendingQuad, ParserError]? {
  self.parser.next()
}

///|
pub struct SliceParser[E] {
  inner : ParserIter[E]
  data : ArrayView[Byte]
  lenient : Bool // lenient 模式下跳过验证
  errors : Array[ParserError] // 收集的结构错误
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
pub fn[E : ParserEngine] SliceParser::next(
  self : SliceParser[E],
) -> Result[QuadSpan, ParserError]? {
  let result = self.inner.next()
  match result {
    None => None
    Some(Err(e)) => Some(Err(e))
    Some(Ok(pending)) => {
      let validated = self.validate(pending)

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
) -> (Array[QuadSpan], Array[ParserError]) {
  let quads : Array[QuadSpan] = []
  let errors = self.errors

  for ;; {
    match self.next() {
      Some(Ok(q)) => quads.push(q)
      Some(Err(e)) => errors.push(e)
      None => break
    }
  }

  (quads, errors)
}
