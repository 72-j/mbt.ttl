///|
/// SliceParser[L] - 泛型引擎的切片解析器
/// L 为词法器类型（经 NQuadsEngine[L] 包装）：Tokenizer（纯 MoonBit）/ Lexerc（C FFI）
pub struct SliceParser[L] {
  engine : NQuadsEngine[L]
  data : ArrayView[Byte]
  lenient : Bool // lenient 模式下跳过验证
  rdf12 : Bool // 语法版本：true=RDF 1.2（langdir 等），false=1.1 严格契约
  errors : Array[ParseError] // 收集的结构错误
}

///|
pub fn[L] SliceParser::new(
  engine : NQuadsEngine[L],
  data : ArrayView[Byte],
  lenient? : Bool = false,
  rdf12? : Bool = true,
) -> SliceParser[L] {
  { engine, data, lenient, rdf12, errors: [], }
}

///|
/// 链式调用设置宽松模式
pub fn[L] SliceParser::lenient(self : SliceParser[L]) -> SliceParser[L] {
  { ..self, lenient: true, }
}

///|
/// 组装机械唯一地点：NQuadsPendingQuad 快照 → QuadSpan。
/// 先切视图装产物，验证在组装之后（validate_helper.mbt，view 直查）。
/// 缺槽/校验失败统一回 ParseError。
fn[L] SliceParser::assemble(
  self : SliceParser[L],
  pending : NQuadsPendingQuad,
) -> Result[QuadSpan, ParseError] {
  match (pending.subj, pending.pred, pending.obj) {
    (Some(_), Some(_), Some(_)) => self.validate(pending)
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
/// 统计 offset 之前的换行数（0 基行号；词法器不吐换行 token，统一按数据统计）
fn[L] SliceParser::line_before(self : SliceParser[L], offset : Int) -> Int {
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
pub fn[L : LexerSource] SliceParser::parse_next(
  self : SliceParser[L],
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
    Some(Ok(pending)) =>
      match self.assemble(pending) {
        Ok(quad) => Some(Ok(quad))
        Err(e) => {
          self.errors.push(e)
          self.parse_next() // 组装/校验失败：记错误继续下一条
        }
      }
  }
}

///|
/// 解析全部
pub fn[L : LexerSource] SliceParser::parse_all(
  self : SliceParser[L],
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
