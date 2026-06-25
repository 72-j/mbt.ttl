///|
impl TokenRecognizer for RdfLexer with fn recognize_next_token(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
  options : LexerOptions?,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
  let base_iri_opt = match options {
    Some(options) =>
      match options.base_iri {
        Some(iri_str) => {
          let iri_ref = iri_str.as_ref()
          if self.lenient {
            // 宽松模式：使用 unchecked 解析，即使格式不完美也尝试使用
            Some(IriRef::parse_unchecked(iri_ref))
          } else {
            // 严格模式：必须通过标准解析验证
            match IriRef::parse(iri_ref) {
              Ok(parsed_iri) => Some(parsed_iri)
              Err(_) => None
            }
          }
        }
        None => None
      }
    None => None
  }
  let options = LexerOptions::default(base_iri_opt)
  if data.is_empty() {
    return None
  }
  match data[0] {
    b'<' =>
      match data.get(1) {
        Some(b'<') =>
          if data.get(2) == Some(b'(') {
            Some(
              (
                3,
                Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("<<("), Range::default()))),
              ),
            )
          } else {
            Some(
              (
                2,
                Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("<<"), Range::default()))),
              ),
            )
          }
        Some(b'=') if self.mode == RdfLexerMode::N3 =>
          if self.recognize_iri(data, options) is Some((consumed, result)) {
            Some(
              if result is Ok(result) {
                (consumed, Ok(result))
              } else {
                (
                  2,
                  Ok(
                    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("<="),Range::default())),
                  ),
                )
              },
            )
          } else if is_ending {
            Some(
              (
                2,
                Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("<="), Range::default()))),
              ),
            )
          } else {
            None
          }
        Some(b'-') if self.mode == RdfLexerMode::N3 =>
          if self.recognize_iri(data, options) is Some((consumed, result)) {
            Some(
              if result is Ok(result) {
                (consumed, Ok(result))
              } else {
                (
                  2,
                  Ok(
                    LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("<-"),Range::default())),
                  ),
                )
              },
            )
          } else if is_ending {
            Some(
              (
                2,
                Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("<-"), Range::default()))),
              ),
            )
          } else {
            None
          }
        _ => self.recognize_iri(data, options)
      }
    b'>' =>
      if data.get(1) == Some(b'>') {
        Some(
          (2, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(">>"), Range::default())))),
        )
      } else {
        Some(
          (1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(">"), Range::default())))),
        )
      }
    b'_' =>
      match data.get(1) {
        Some(b':') => RdfLexer::recognize_blank_node_label(data, is_ending)
        Some(c) =>
          Some((1, Err(TokenRecognizerError::InvalidToken([c], Range(1, 2)))))
        None =>
          Some(
            (
              1,
              Err(
                TokenRecognizerError::UnexpectedEndOfInput(
                  data[0:1],
                  Range(0, 1),
                ),
              ),
            ),
          )
      }
    b'"' =>
      if self.mode != RdfLexerMode::NTriples &&
        data.get(1) == Some(b'"') &&
        data.get(2) == Some(b'"') {
        self.recognize_long_string(data, b'"', is_ending)
      } else {
        self.recognize_string(data, b'"', is_ending)
      }
    b'\'' if self.mode != RdfLexerMode::NTriples =>
      if data.get(1) == Some(b'\'') && data.get(2) == Some(b'\'') {
        self.recognize_long_string(data, b'\'', is_ending)
      } else {
        self.recognize_string(data, b'\'', is_ending)
      }
    b'@' => self.recognize_lang_tag(data)
    b'.' =>
      match data.get(1) {
        Some(b'0'..=b'9') => RdfLexer::recognize_number(data, is_ending)
        Some(_) =>
          Some(
            (1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("."), Range::default())))),
          )
        None =>
          if is_ending {
            Some(
              (
                1,
                Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("."), Range::default()))),
              ),
            )
          } else {
            None
          }
      }
    b'^' =>
      if data.get(1) == Some(b'^') {
        Some(
          (2, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("^^"), Range::default())))),
        )
      } else {
        Some(
          (1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("^"), Range::default())))),
        )
      }
    b'(' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("("), Range::default())))))
    b')' =>
      if data.get(1) == Some(b'>') && data.get(2) == Some(b'>') {
        Some(
          (3, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(")>>"),Range::default())))),
        )
      } else {
        Some(
          (1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(")"),Range::default())))),
        )
      }
    b'[' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("["), Range::default())))))
    b']' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("]"), Range::default())))))
    b'{' =>
      if data.get(1) == Some(b'|') {
        Some(
          (2, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("{|"), Range::default())))),
        )
      } else {
        Some(
          (1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("{"), Range::default())))),
        )
      }
    b'}' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("}"), Range::default())))))
    b',' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(","), Range::default())))))
    b';' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation(";"), Range::default())))))
    b'!' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("!"), Range::default())))))
    b'|' =>
      if data.get(1) == Some(b'}') {
        Some(
          (2, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("|}"), Range::default())))),
        )
      } else {
        Some(
          (1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("|"), Range::default())))),
        )
      }
    b'=' =>
      if data.get(1) == Some(b'>') {
        Some(
          (2, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("=>"), Range::default())))),
        )
      } else {
        Some(
          (1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("="), Range::default())))),
        )
      }
    b'~' =>
      Some((1, Ok(LocatedTokenOrLineJump::LocatedN3Token(LocatedN3Token(N3Token::Punctuation("~"), Range::default())))))
    b'0'..=b'9' | b'+' | b'-' => RdfLexer::recognize_number(data, is_ending)
    b'?' => self.recognize_variable(data, is_ending)
    _ => self.recognize_pname_or_keyword(data, is_ending)
  }
}
