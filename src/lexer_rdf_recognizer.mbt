///|
pub impl TokenRecognizer for RdfLexer with fn recognize_next_token(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
  options : LexerOptions?,
  location_pos : SourcePos,
) -> (Int, Result[LocatedToken, TokenRecognizerError])? {
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

  // 辅助函数：构建基于 location_pos 的 Range
  let make_range = fn(start_offset : Int, length : Int) -> Range {
    Range(start_offset, start_offset + length)
  }

  match data[0] {
    b'<' =>
      match data.get(1) {
        Some(b'<') =>
          if data.get(2) == Some(b'(') {
            Some(
              (
                3,
                Ok(
                  LocatedToken(
                    N3Token::Punctuation("<<("),
                    make_range(location_pos.offset, 3),
                  ),
                ),
              ),
            )
          } else {
            Some(
              (
                2,
                Ok(
                  LocatedToken(
                    N3Token::Punctuation("<<"),
                    make_range(location_pos.offset, 2),
                  ),
                ),
              ),
            )
          }
        Some(b'=') if self.mode == RdfLexerMode::N3 =>
          if self.recognize_iri(data, options, location_pos)
            is Some((consumed, result)) {
            Some(
              if result is Ok(result) {
                (consumed, Ok(result))
              } else {
                (
                  2,
                  Ok(
                    LocatedToken(
                      N3Token::Punctuation("<="),
                      make_range(location_pos.offset, 2),
                    ),
                  ),
                )
              },
            )
          } else if is_ending {
            Some(
              (
                2,
                Ok(
                  LocatedToken(
                    N3Token::Punctuation("<="),
                    make_range(location_pos.offset, 2),
                  ),
                ),
              ),
            )
          } else {
            None
          }
        Some(b'-') if self.mode == RdfLexerMode::N3 =>
          if self.recognize_iri(data, options, location_pos)
            is Some((consumed, result)) {
            Some(
              if result is Ok(result) {
                (consumed, Ok(result))
              } else {
                (
                  2,
                  Ok(
                    LocatedToken(
                      N3Token::Punctuation("<-"),
                      make_range(location_pos.offset, 2),
                    ),
                  ),
                )
              },
            )
          } else if is_ending {
            Some(
              (
                2,
                Ok(
                  LocatedToken(
                    N3Token::Punctuation("<-"),
                    make_range(location_pos.offset, 2),
                  ),
                ),
              ),
            )
          } else {
            None
          }
        _ => self.recognize_iri(data, options, location_pos)
      }
    b'>' =>
      if data.get(1) == Some(b'>') {
        Some(
          (
            2,
            Ok(
              LocatedToken(
                N3Token::Punctuation(">>"),
                make_range(location_pos.offset, 2),
              ),
            ),
          ),
        )
      } else {
        Some(
          (
            1,
            Ok(
              LocatedToken(
                N3Token::Punctuation(">"),
                make_range(location_pos.offset, 1),
              ),
            ),
          ),
        )
      }
    b'_' =>
      match data.get(1) {
        Some(b':') =>
          RdfLexer::recognize_blank_node_label(data, is_ending, location_pos)
        Some(c) =>
          Some(
            (
              1,
              Err(
                TokenRecognizerError::InvalidToken(
                  [c],
                  make_range(location_pos.offset + 1, 1),
                ),
              ),
            ),
          )
        None =>
          Some(
            (
              1,
              Err(
                TokenRecognizerError::UnexpectedEndOfInput(
                  data[0:1],
                  make_range(location_pos.offset, 1),
                ),
              ),
            ),
          )
      }
    b'"' =>
      if self.mode != RdfLexerMode::NTriples &&
        data.get(1) == Some(b'"') &&
        data.get(2) == Some(b'"') {
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
    b'.' =>
      match data.get(1) {
        Some(b'0'..=b'9') =>
          RdfLexer::recognize_number(data, is_ending, location_pos)
        Some(_) =>
          Some(
            (
              1,
              Ok(
                LocatedToken(
                  N3Token::Punctuation("."),
                  make_range(location_pos.offset, 1),
                ),
              ),
            ),
          )
        None =>
          if is_ending {
            Some(
              (
                1,
                Ok(
                  LocatedToken(
                    N3Token::Punctuation("."),
                    make_range(location_pos.offset, 1),
                  ),
                ),
              ),
            )
          } else {
            None
          }
      }
    b'^' =>
      if data.get(1) == Some(b'^') {
        Some(
          (
            2,
            Ok(
              LocatedToken(
                N3Token::Punctuation("^^"),
                make_range(location_pos.offset, 2),
              ),
            ),
          ),
        )
      } else {
        Some(
          (
            1,
            Ok(
              LocatedToken(
                N3Token::Punctuation("^"),
                make_range(location_pos.offset, 1),
              ),
            ),
          ),
        )
      }
    b'(' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation("("),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b')' =>
      if data.get(1) == Some(b'>') && data.get(2) == Some(b'>') {
        Some(
          (
            3,
            Ok(
              LocatedToken(
                N3Token::Punctuation(")>>"),
                make_range(location_pos.offset, 3),
              ),
            ),
          ),
        )
      } else {
        Some(
          (
            1,
            Ok(
              LocatedToken(
                N3Token::Punctuation(")"),
                make_range(location_pos.offset, 1),
              ),
            ),
          ),
        )
      }
    b'[' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation("["),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b']' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation("]"),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b'{' =>
      if data.get(1) == Some(b'|') {
        Some(
          (
            2,
            Ok(
              LocatedToken(
                N3Token::Punctuation("{|"),
                make_range(location_pos.offset, 2),
              ),
            ),
          ),
        )
      } else {
        Some(
          (
            1,
            Ok(
              LocatedToken(
                N3Token::Punctuation("{"),
                make_range(location_pos.offset, 1),
              ),
            ),
          ),
        )
      }
    b'}' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation("}"),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b',' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation(","),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b';' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation(";"),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b'!' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation("!"),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b'|' =>
      if data.get(1) == Some(b'}') {
        Some(
          (
            2,
            Ok(
              LocatedToken(
                N3Token::Punctuation("|}"),
                make_range(location_pos.offset, 2),
              ),
            ),
          ),
        )
      } else {
        Some(
          (
            1,
            Ok(
              LocatedToken(
                N3Token::Punctuation("|"),
                make_range(location_pos.offset, 1),
              ),
            ),
          ),
        )
      }
    b'=' =>
      if data.get(1) == Some(b'>') {
        Some(
          (
            2,
            Ok(
              LocatedToken(
                N3Token::Punctuation("=>"),
                make_range(location_pos.offset, 2),
              ),
            ),
          ),
        )
      } else {
        Some(
          (
            1,
            Ok(
              LocatedToken(
                N3Token::Punctuation("="),
                make_range(location_pos.offset, 1),
              ),
            ),
          ),
        )
      }
    b'~' =>
      Some(
        (
          1,
          Ok(
            LocatedToken(
              N3Token::Punctuation("~"),
              make_range(location_pos.offset, 1),
            ),
          ),
        ),
      )
    b'0'..=b'9' | b'+' | b'-' =>
      RdfLexer::recognize_number(data, is_ending, location_pos)
    b'?' => self.recognize_variable(data, is_ending, location_pos)

    // b':' if self.mode == RdfLexerMode::N3 =>
    // match self.recognize_optional_pn_local(data, is_ending, location_pos.offset + 1) {
    //   Some((consumed, Ok((localx, might_be_invalid_iri)))) => {
    //     // 需要有 prefix...
    //     // 如果 context 中保存了 pn_prefix，可以使用它
    //     Some((
    //       consumed + 1,
    //       Ok(
    //         
    //           LocatedToken(
    //             // 需要知道 prefix...可能需要在函数中传递
    //             N3Token::PrefixedName(
    //               prefix="",
    //               localx~,
    //               might_be_invalid_iri~,
    //             ),
    //             make_range(location_pos.offset, consumed + 1),
    //           ),
    //         ),
    //       ),
    //     ))
    //   }
    //   _ => None
    // }  
    _ => self.recognize_pname_or_keyword(data, is_ending, location_pos)
  }
}
