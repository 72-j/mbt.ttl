// ===== 用户部分：C FFI 词法适配（对比版） =====
// 状态机与 loop 均复用 engine.mbt；本文件只做 C 词法器侧的适配：
//   - Token → NQuadsEvent 共用 engine.mbt 的 token_to_event
//     （Lexermoon 的 Token 类型与 span 口径已与 C 版对齐，映射零补偿透传）
//   - LexerSource 运行时接口实现（仅 next/pos）
// 构造/释放是 Lexerc 的显式 API（Lexerc::new / Lexerc::destroy），
// 由入口函数负责调用；LexerSource 只约束 next/pos 运行时接口。

///|
/// Lexerc 实现 LexerSource（运行时接口仅 next/pos）
pub impl LexerSource for Lexerc with fn next(self : Lexerc) -> NQuadsEvent? {
  // EOF 边界在词法源层吞掉：直接回 None
  match Lexerc::next(self) {
    None => None // 输入结束
    Some(Token::EOF(_)) => None
    Some(token) => Some(token_to_event(token))
  }
}

///|
pub impl LexerSource for Lexerc with fn pos(self : Lexerc) -> Int {
  Lexerc::position(self)
}

///|
pub impl LexerSource for Lexerc with fn byte_at(self : Lexerc, offset : Int) -> Byte {
  self.data[offset]
}

///|
/// C FFI 词法版便捷入口：显式构造与释放（LexerSource 不再约束生命周期）
pub fn nquads_parser_c(
  input : FixedArray[Byte],
  lenient? : Bool = false,
) -> (Array[QuadSpan], Array[ParseError]) {
  let lexer = Lexerc::new(input)
  let engine : NQuadsEngine[Lexerc] = NQuadsEngine::new(lexer)
  let slice = SliceParser::new(engine, input[:], lenient~)
  let result = slice.parse_all()
  Lexerc::destroy(engine.lexer)
  result
}
