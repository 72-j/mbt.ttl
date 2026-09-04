// ============================================================
// Token 类型定义（全目标；C 词法器与 Moon 词法器共用同一词法口径）
// ============================================================

///|
// type Span = (Int, Int) // (offset, length)

///|
pub(all) enum Token {
  // 结构标点
  Dot(Span) // .
  Semicolon(Span) // ;
  Comma(Span) // ,

  // 标识符
  Iri(Span) // <...> 或 _:name 或 :name

  // 字符串
  Literal(Span) // "..."
  BlankNode(Span)
  PrefName(Span) // 字母或:开头（可能是前缀名）
  TripleTerm(Span) // <<( ... )>> 三元组词项（RDF 1.2；平衡配对是物理边界，语法归验证层）
  // 容错
  Unknown(Span) // 其他字符

  // 结束
  EOF(Int) // 文件结束
} derive(Debug)

///|
pub impl Show for Token with fn output(self : Token, logger : &Logger) -> Unit {
  match self {
    Token::Dot(span) => {
      let (offset, length) = span
      logger.write_string("Dot(\{offset},\{length})")
    }
    Token::Semicolon(span) => {
      let (offset, length) = span
      logger.write_string("Semicolon(\{offset},\{length})")
    }
    Token::Comma(span) => {
      let (offset, length) = span
      logger.write_string("Comma(\{offset},\{length})")
    }
    Token::Iri(span) => {
      let (offset, length) = span
      logger.write_string("Iri(\{offset},\{length})")
    }
    Token::Literal(span) => {
      let (offset, length) = span
      logger.write_string("Literal(\{offset},\{length})")
    }
    Token::BlankNode(span) => {
      let (offset, length) = span
      logger.write_string("BlankNode(\{offset},\{length})")
    }
    Token::PrefName(span) => {
      let (offset, length) = span
      logger.write_string("PrefName(\{offset},\{length})")
    }
    Token::TripleTerm(span) => {
      let (offset, length) = span
      logger.write_string("TripleTerm(\{offset},\{length})")
    }
    Token::Unknown(span) => {
      let (offset, length) = span
      logger.write_string("Unknown(\{offset},\{length})")
    }
    Token::EOF(offset) => logger.write_string("EOF(\{offset})")
  }
}
