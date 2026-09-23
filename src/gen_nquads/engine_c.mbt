// ===== 装配层（Assembly）：C FFI 词法适配（对比版） =====
// 状态机与 loop 均复用 engine.mbt；本文件只做 C 词法器侧的适配：
//   - Token → NQuadsEvent 映射（token_to_event 本文件持有：Lexermoon 自
//     P2 刀 a) 起直产事件，此处是它唯一消费者；span 口径与 C 版逐字对齐）
//   - LexerSource 运行时接口实现（仅 next/pos）
// 构造/释放是 Lexerc 的显式 API（Lexerc::new / Lexerc::destroy），
// 由入口函数负责调用；LexerSource 只约束 next/pos 运行时接口。

///|
/// Token(offset,length) → 事件载荷 Span（Lexerc FFI 专用；span 全词含定界符，
/// 零补偿透传——Lexermoon 直产后不再共用）
fn token_to_event(token : Token) -> NQuadsEvent {
  match token {
    Token::Iri(span) => NQuadsEvent::NQuadsIri(span)
    Token::BlankNode(span) => NQuadsEvent::NQuadsBlankNode(span)
    Token::Literal(span) => NQuadsEvent::NQuadsLiteral(span)
    Token::PrefName(span) => NQuadsEvent::NQuadsPrefName(span)
    Token::TripleTerm(span) => NQuadsEvent::NQuadsTripleTerm(span)
    Token::Dot(_) => NQuadsEvent::NQuadsDot
    Token::Comma(_) => NQuadsEvent::NQuadsComma
    Token::Semicolon(_) => NQuadsEvent::NQuadsSemicolon
    Token::Unknown(_) => NQuadsEvent::NQuadsUnknown
    Token::EOF(_) => NQuadsEvent::NQuadsEOF // 已被 LexerSource 过滤，保底映射
  }
}

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
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
// 注：本文件是 **native-only**（`moon.pkg` 的 `targets` 里限 "native"）⇒ 默认 wasm 档的
// `moon check` 看不见它；CI 的 `moon test --deny-warn --target native` 会看见——故必须在此补齐
// （**口径**：诊断核查要**按档跑**，wasm 绿 ≠ native 绿）。
pub extend Lexerc with LexerSource::{byte_at, pos}

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
