// ============================================================
// N-Triples 解析器
// 基于词法分析器 + 状态机引擎
// ============================================================

// ============================================================
// 辅助函数
// ============================================================

///|
fn is_eof_token(token : Token) -> Bool {
  token is Token::EOF(_)
}

///|
fn is_dot_token(token : Token) -> Bool {
  token is Token::Dot(_)
}

///|
/// 解析步骤结果
pub(all) enum StepResult {
  Continue // 继续解析
  Emit // 触发输出
  SkipLine // 跳过当前行
  SkipError(Span) // 带错误信息跳过
  Error(ParseError)
}

///|
pub fn nquads_parser(
  input : FixedArray[Byte],
  lenient? : Bool = false,
) -> (Array[QuadSpan], Array[ParseError]) {
  let engine = NQuadsEngine::from_bytes(input)
  let slice = SliceParser::new(engine, input, lenient~)
  slice.parse_all()
}

///|
/// N-Quads 序列化辅助函数
pub fn nquads_serializer(
  data : ArrayView[Byte],
  quads : Array[QuadEmit],
  mode? : StringView = "quad",
) -> String {
  Serializer::new(data, mode~).serialize_all(quads)
}
