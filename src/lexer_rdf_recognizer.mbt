///|
type ByteParser[A] = @parserc.Parser[Byte, Result[A, TokenRecognizerError]]

///|
fn iri_token() -> ByteParser[N3Token] {
  @parserc.Parser::new(fn(
    input : @parserc.Seq[Byte],
  ) -> (Result[N3Token, TokenRecognizerError], @parserc.Seq[Byte])? {
    // 1. 匹配 <
    match input.uncons() {
      Some((b'<', rest1)) => {
        // 2. 消费直到 >
        let content = []
        let mut rest = rest1

        for ;; {
          match rest.uncons() {
            Some((b'>', rest2)) => {
              // 3. 构建 IRI token
              let s = content.fold(init="", fn(a, b : Byte) {
                a + b.to_int().unsafe_to_char().to_string()
              })
              return Some((Ok(N3Token::Iri(s)), rest2))
            }
            Some((b, rest2)) => {
              content.push(b)
              rest = rest2
            }
            None => return None
          }
        }
      }
      _ => None
    }
  })
}

///|
fn blank_token() -> ByteParser[N3Token] {
  @parserc.Parser::new(fn(
    input : @parserc.Seq[Byte],
  ) -> (Result[N3Token, TokenRecognizerError], @parserc.Seq[Byte])? {
    // _:name
    match input.uncons() {
      Some((b'_', rest1)) =>
        match rest1.uncons() {
          Some((b':', rest2)) => {
            let name = []
            let mut rest = rest2

            for ;; {
              match rest.uncons() {
                Some((b, r)) if b != b' ' && b != b'.' && b != b'\n' => {
                  name.push(b)
                  rest = r
                }
                _ => {
                  let s = name.fold(init="", fn(a, b) {
                    a + b.to_int().unsafe_to_char().to_string()
                  })
                  return Some((Ok(N3Token::BlankNodeLabel(s)), rest))
                }
              }
            }
          }
          _ => None
        }
      _ => None
    }
  })
}

///|
fn punct_p_multi() -> ByteParser[N3Token] {
  @parserc.Parser::new(fn(input) {
    match input.uncons() {
      Some((b'>', r1)) =>
        match r1.uncons() {
          Some((b'>', r2)) => Some((Ok(N3Token::Punctuation(">>")), r2))
          _ => Some((Ok(N3Token::Punctuation(">")), r1))
        }
      Some((b'<', r1)) =>
        match r1.uncons() {
          Some((b'<', r2)) =>
            match r2.uncons() {
              Some((b'(', r3)) => Some((Ok(N3Token::Punctuation("<<(")), r3))
              _ => Some((Ok(N3Token::Punctuation("<<")), r2))
            }
          Some((b'=', r2)) => Some((Ok(N3Token::Punctuation("<=")), r2))
          Some((b'-', r2)) => Some((Ok(N3Token::Punctuation("<-")), r2))
          _ => Some((Ok(N3Token::Punctuation("<")), r1))
        }
      Some((b'^', r1)) =>
        match r1.uncons() {
          Some((b'^', r2)) => Some((Ok(N3Token::Punctuation("^^")), r2))
          _ => Some((Ok(N3Token::Punctuation("^")), r1))
        }
      Some((b, rest)) if is_punct_byte(b) =>
        Some(
          (
            Ok(N3Token::Punctuation(b.to_int().unsafe_to_char().to_string())),
            rest,
          ),
        )
      _ => None
    }
  })
}

///|
fn is_punct_byte(b : Byte) -> Bool {
  match b {
    b'('
    | b')'
    | b'['
    | b']'
    | b'{'
    | b'}'
    | b','
    | b';'
    | b'.'
    | b'!'
    | b'~'
    | b'|'
    | b'^'
    | b'*'
    | b'+'
    | b'=' => true
    _ => false
  }
}

///|
pub impl TokenRecognizer for RdfLexer with fn recognize_next_token(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
  options : LexerOptions?,
  location_pos : SourcePos,
) -> (Int, Result[LocatedToken, TokenRecognizerError])? {
  if data.is_empty() {
    return None
  }

  let iri = IriR::default()
  let base_iri_opt = match options {
    Some(options) =>
      match options.base_iri {
        Some(irir) => {
          let irir = irir.into_string()
          if self.lenient {
            // 宽松模式：使用 unchecked 解析，即使格式不完美也尝试使用
            Some(iri.parse_unchecked(irir))
          } else {
            // 严格模式：必须通过标准解析验证
            match iri.parse(irir) {
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
  let make_range = fn(start : Int, len : Int) -> Range {
    Range(start, start + len)
  }

  // 创建 Seq
  let input = @parserc.Seq::from_array(data)

  // 1️⃣ 尝试 parserc 解析器（简单 token）
  let simple_p = iri_token().or_else(blank_token()).or_else(punct_p_multi())
  // .or_else(lang_tag_token()) // 可选添加

  match simple_p.run(input) {
    Some((Ok(token), rest)) => {
      let consumed = data.length() - rest.length()
      return Some(
        (
          consumed,
          Ok(LocatedToken(token, make_range(location_pos.offset, consumed))),
        ),
      )
    }
    _ => ()
  }
  match data[0] {
    b'<' => self.recognize_iri(data, options, location_pos)
    b'_' => self.recognize_blank_node_label(data, is_ending, location_pos)
    b'"' =>
      if data.get(1) == Some(b'"') && data.get(2) == Some(b'"') {
        self.recognize_long_string(data, b'"', is_ending, location_pos)
      } else {
        self.recognize_string(data, b'"', is_ending, location_pos)
      }
    b'\'' if self.mode != RdfLexerMode::NTriples =>
      if data.get(1) == Some(b'\'') && data.get(2) == Some(b'\'') {
        self.recognize_long_string(data, b'\'', is_ending, location_pos)
      } else {
        self.recognize_string(data, b'\'', is_ending, location_pos)
      }
    b'@' => self.recognize_lang_tag(data, location_pos)
    b'0'..=b'9' | b'+' | b'-' =>
      self.recognize_number(data, is_ending, location_pos)
    b'?' => self.recognize_variable(data, is_ending, location_pos)
    _ => self.recognize_pname_or_keyword(data, is_ending, location_pos)
  }
}
