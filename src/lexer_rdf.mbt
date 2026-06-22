///|
pub enum RdfLexerMode {
  NTriples
  Turtle
  N3
} derive(Eq)

///|
pub struct RdfLexer {
  mode : RdfLexerMode
  lenient : Bool
}

///|
impl TokenRecognizer for RdfLexer with fn recognize_next_token(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
  options : LexerOptions?,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
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
            Some((3, Ok(TokenOrLineJump::Token(N3Token::Punctuation("<<(")))))
          } else {
            Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("<<")))))
          }
        Some(b'=') if self.mode == RdfLexerMode::N3 =>
          if self.recognize_iri(data, options) is Some((consumed, result)) {
            Some(
              if result is Ok(result) {
                (consumed, Ok(result))
              } else {
                (2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("<="))))
              },
            )
          } else if is_ending {
            Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("<=")))))
          } else {
            None
          }
        Some(b'-') if self.mode == RdfLexerMode::N3 =>
          if self.recognize_iri(data, options) is Some((consumed, result)) {
            Some(
              if result is Ok(result) {
                (consumed, Ok(result))
              } else {
                (2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("<-"))))
              },
            )
          } else if is_ending {
            Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("<-")))))
          } else {
            None
          }
        _ => self.recognize_iri(data, options)
      }
    b'>' =>
      if data.get(1) == Some(b'>') {
        Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation(">>")))))
      } else {
        Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation(">")))))
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
          Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation(".")))))
        None =>
          if is_ending {
            Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation(".")))))
          } else {
            None
          }
      }
    b'^' =>
      if data.get(1) == Some(b'^') {
        Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("^^")))))
      } else {
        Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("^")))))
      }
    b'(' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("(")))))
    b')' =>
      if data.get(1) == Some(b'>') && data.get(2) == Some(b'>') {
        Some((3, Ok(TokenOrLineJump::Token(N3Token::Punctuation(")>>")))))
      } else {
        Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation(")")))))
      }
    b'[' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("[")))))
    b']' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("]")))))
    b'{' =>
      if data.get(1) == Some(b'|') {
        Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("{|")))))
      } else {
        Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("{")))))
      }
    b'}' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("}")))))
    b',' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation(",")))))
    b';' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation(";")))))
    b'!' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("!")))))
    b'|' =>
      if data.get(1) == Some(b'}') {
        Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("|}")))))
      } else {
        Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("|")))))
      }
    b'=' =>
      if data.get(1) == Some(b'>') {
        Some((2, Ok(TokenOrLineJump::Token(N3Token::Punctuation("=>")))))
      } else {
        Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("=")))))
      }
    b'~' => Some((1, Ok(TokenOrLineJump::Token(N3Token::Punctuation("~")))))
    b'0'..=b'9' | b'+' | b'-' => RdfLexer::recognize_number(data, is_ending)
    b'?' => self.recognize_variable(data, is_ending)
    _ => self.recognize_pname_or_keyword(data, is_ending)
  }
}

///|
pub fn RdfLexer::RdfLexer(mode : RdfLexerMode, lenient : Bool) -> RdfLexer {
  { mode, lenient }
}

///|
// fn RdfLexer::recognize_iri(
//   self : RdfLexer,
//   data : ArrayView[Byte],
//   options : LexerOptions,
// ) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
//   let string = []
//   let mut i = 1
//   for ;; {
//     let end_opt = array_view_memchr2(b'>', b'\'', data[i:])

//     let end = match end_opt {
//       Some(e) => e
//       None =>
//         // 如果未找到结束符，根据 N3 语法通常视为错误，或者取到末尾
//         // 这里为了保持类型一致并避免崩溃，假设取剩余长度，但后续 match data[i] 可能会越界
//         // 建议在此处检查并返回错误
//         return Some(
//           (
//             data.length(),
//             Err(
//               TokenRecognizerError::IriTruncated(
//                 data[i:],
//                 Range(i, i + data.length()),
//               ),
//             ),
//           ),
//         )
//     }
//     string.append(data[i:i + end])
//     i += end
//     match data[i] {
//       b'>' =>
//         return Some((i + 1, self.parse_iri(string, Range(0, i + 1), options)))
//       b'\'' => {
//         let (additional, c) = self.recognize_escape(data[i:], i, false).unwrap()
//         i += additional + 1
//         match c {
//           Ok(c) => string.append(char_to_utf8_bytes(c))
//           // Ok(c) => string.append(@utf8.encode("\{c}").to_array())
//           Err(e) => return Some((i, Err(e)))
//         }
//       }
//       _ => panic()
//     }
//   }
// }

///|
fn RdfLexer::recognize_iri(
  self : RdfLexer,
  data : ArrayView[Byte],
  options : LexerOptions,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  let string = []
  let mut i = 1

  // 循环直到找到 '>'
  for ;; {
    // 修复：只查找 '>'，不要查找 '\''。
    // N-Triples/Turtle IRI 中不支持反斜杠转义，单引号是合法字符。
    let end_opt = array_view_memchr(b'>', data[i:])

    let end = match end_opt {
      Some(e) => e
      None =>
        // 未找到结束符，返回截断错误
        return Some(
          (
            data.length(),
            Err(
              TokenRecognizerError::IriTruncated(
                data[i:],
                Range(i, i + data.length()),
              ),
            ),
          ),
        )
    }

    // 将中间的所有字节（包括 %, ', (, ) 等）追加到 string
    string.append(data[i:i + end])
    i += end

    // 此时 data[i] 必须是 '>'
    // 直接返回解析结果，不再处理任何转义逻辑
    return Some((i + 1, self.parse_iri(string, Range(0, i + 1), options)))
  }
}

///|
fn RdfLexer::parse_iri(
  self : RdfLexer,
  iri_bytes : Array[Byte],
  position : Range,
  options : LexerOptions,
) -> Result[TokenOrLineJump[N3Token], TokenRecognizerError] {
  // 1. 将字节数组转换为字符串，处理可能的 UTF-8 错误
  let iri_str = match string_from_utf8(iri_bytes, position) {
    Ok(s) => s
    Err(e) => return Err(e) // 或者直接使用: let iri_str = string_from_utf8(iri_bytes, position)?;
  }
  if iri_str.contains("\\") {
    return Err(
      TokenRecognizerError::InvalidErrMessage(
        iri_bytes, position, "IRIs in N-Triples cannot contain backslashes",
      ),
    )
  }
  // 2. 解析或解析并合并 Base IRI
  let final_iri = if options.base_iri is Some(base_iri) {
    // 如果有 base_iri，尝试解析相对 IRI
    let base_iri = base_iri.as_ref()
    if self.lenient {
      // 宽松模式：直接合并，不检查有效性
      Ok(base_iri.resolve_unchecked(iri_str))
    } else {
      // 严格模式：解析并检查有效性
      base_iri
      .resolve(iri_str)
      .map_err(fn(e) {
        TokenRecognizerError::IriParsingError(e.message(), position)
      })
    }
  } else {
    // 没有 base_iri，直接解析绝对 IRI
    let iri = Iri::new(iri_str)
    // let iri = IriRef::of_ref(iri)

    if self.lenient {
      // 宽松模式：这里可能需要一个不检查错误的 parse，或者假设 iri_str 已经是合法的
      // 如果 Iri 模块没有 unchecked_parse，可能需要借用严格模式的结果或自定义逻辑
      // 假设 lenient 模式下如果没有 base_iri 也至少要是合法格式，或者使用 try_parse

      Ok(IriRef::parse_unchecked(iri))
    } else {
      // 严格模式
      IriRef::parse(iri).map_err(fn(e) {
        TokenRecognizerError::IriParsingError(e.message(), position)
      })
    }
  }

  // 3. 返回 Token
  // 注意：这里假设 N3Token::IriRef 接受 Iri 类型。
  // 如果 N3Token::IriRef 定义为 IriRef(String)，请改为 N3Token::IriRef(final_iri.to_string())
  let final_iri = match final_iri {
    Ok(iri) => iri
    Err(e) => return Err(e)
  }
  Ok(TokenOrLineJump::Token(N3Token::Iri(final_iri.base_iri)))
}

///|
fn RdfLexer::recognize_pname_or_keyword(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  let mut i = 0

  // 解析前缀部分，直到遇到 ':'
  for ;; {
    match RdfLexer::recognize_unicode_char(data[i:], i) {
      Some(Ok((c, consumed))) =>
        if c == ':' {
          i += consumed
        } else if i == 0 {
          // 第一个字符必须符合 base 规则
          if !RdfLexer::is_possible_pn_chars_base(c) {
            return Some(
              (
                consumed,
                Err(
                  TokenRecognizerError::InvalidErrMessage(
                    data[0:consumed],
                    Range::Range(0, consumed),
                    "'\{c}' is not allowed at the beginning of a prefix name",
                  ),
                ),
              ),
            )
          }
          i += consumed
          // 后续字符可以是 pn_chars 或 '.'
        } else if RdfLexer::is_possible_pn_chars(c) || c == '.' {
          i += consumed
        } else {
          // 遇到无效字符，作为 PlainKeyword 返回
          while array_view_has_prefix(data[:i], b".") {
            i -= 1
          }
          return Some(
            (
              i,
              str_from_utf8(data[:i], Range::Range(0, i)).map(s => {
                TokenOrLineJump::Token(N3Token::PlainKeyword(s))
              }),
            ),
          )
        }
      Some(Err(e)) => return Some((e.range().end, Err(e)))
      None =>
        // 没有更多字符可解析
        if is_ending {
          while array_view_has_prefix(data[:i], b".") {
            i -= 1
          }
          return Some(
            if i == 0 {
              (
                1,
                Err(
                  TokenRecognizerError::UnexpectedEndOfInput(
                    data[0:1],
                    Range::Range(0, i),
                  ),
                ),
              )
            } else {
              (
                i,
                str_from_utf8(data[:i], Range::Range(0, i)).map(s => {
                  TokenOrLineJump::Token(N3Token::PlainKeyword(s))
                }),
              )
            },
          )
        } else {
          return None
        }
    }
  }
  // 提取前缀
  let pn_prefix = match str_from_utf8(data[:i - 1], Range::Range(0, i - 1)) {
    Ok(prefix) => prefix
    Err(e) => return Some((i, Err(e)))
  }

  // 前缀不能以 '.' 结尾
  if pn_prefix.has_suffix(".") {
    return Some(
      (
        i,
        Err(
          TokenRecognizerError::InvalidErrMessage(
            data[0:i],
            Range::Range(0, i),
            "'\{pn_prefix}' is not a valid prefix: prefixes are not allowed to end with '.'",
          ),
        ),
      ),
    )
  }

  // 解析本地部分
  match self.recognize_optional_pn_local(data[i:], is_ending) {
    Some((consumed, Ok((localx, might_be_invalid_iri)))) =>
      Some(
        (
          consumed + i,
          Ok(
            TokenOrLineJump::Token(
              N3Token::PrefixedName(
                prefix=pn_prefix,
                localx~,
                might_be_invalid_iri~,
              ),
            ),
          ),
        ),
      )
    Some((consumed, Err(e))) => Some((consumed + i, Err(e)))
    None => None
  }
}

///|
fn RdfLexer::recognize_variable(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  if data.is_empty() || data[0] != b'?' {
    return None
  }

  // 修复：对 Option 类型进行模式匹配
  match self.recognize_optional_pn_local(data[1:], is_ending) {
    Some((consumed, name_result)) => {
      let total_consumed = consumed + 1

      let token_result = match name_result {
        Ok((name, _)) if !name.is_empty() =>
          Ok(TokenOrLineJump::Token(N3Token::Variable(name)))
        Ok((name, _)) =>
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:total_consumed],
              Range::Range(0, total_consumed),
              "A variable name is not allowed to be empty",
            ),
          )
        Err(e) => Err(e)
      }

      Some((total_consumed, token_result))
    }
    None => None
  }
}

///|
fn RdfLexer::recognize_optional_pn_local(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
) -> (Int, Result[(String, Bool), TokenRecognizerError])? {
  let mut i = 0
  let mut buffer : StringBuilder? = None
  let mut position_that_is_already_in_buffer = 0
  let mut might_be_invalid_iri = false
  let mut ends_with_unescaped_dot = 0

  for ;; {
    if RdfLexer::recognize_unicode_char(data[i:], i) is Some(r) {
      match r {
        Ok((c, consumed)) =>
          if c == '%' {
            i += 1
            match (data.get(i), data.get(i + 1)) {
              (Some(byte_a), Some(byte_b)) => {
                let a = Byte::to_char(byte_a)
                i += 1
                let b = Byte::to_char(byte_b)
                if !a.is_ascii_hexdigit() || !b.is_ascii_hexdigit() {
                  return Some(
                    (
                      i + 1,
                      Err(
                        TokenRecognizerError::InvalidErrMessage(
                          data[i - 2:i],
                          Range::Range(i - 2, i),
                          "escapes in IRIs should be % followed by two hexadecimal characters, found '\{a}\{b}'",
                        ),
                      ),
                    ),
                  )
                }
                i += 1
                ends_with_unescaped_dot = 0
              }
              _ =>
                // 数据不足，等待更多输入
                return None
            }
          } else if c == '\'' {
            i += 1
            match data.get(i) {
              Some(next_byte) => {
                let a = Byte::to_char(next_byte)

                if self.lenient ||
                  a == '_' ||
                  a == '~' ||
                  a == '.' ||
                  a == '-' ||
                  a == '!' ||
                  a == '$' ||
                  a == '&' ||
                  a == '\'' ||
                  a == '(' ||
                  a == ')' ||
                  a == '*' ||
                  a == '+' ||
                  a == ',' ||
                  a == ';' ||
                  a == '=' {
                  // allowed
                } else if a == '/' ||
                  a == '?' ||
                  a == '#' ||
                  a == '@' ||
                  a == '%' {
                  might_be_invalid_iri = true
                } else {
                  return Some(
                    (
                      i + 1,
                      Err(
                        TokenRecognizerError::InvalidErrMessage(
                          data[i:i + 1],
                          Range::Range(i, i + 1),
                          "The character that are allowed to be escaped in IRIs are _~.-!$&'()*+,;=/?#@%, found '\{a}'",
                        ),
                      ),
                    ),
                  )
                }

                if buffer is None {
                  buffer = Some(StringBuilder::new())
                }
                match buffer {
                  Some(b) => {
                    if i - position_that_is_already_in_buffer > 1 {
                      match
                        str_from_utf8(
                          data[position_that_is_already_in_buffer:i - 1],
                          Range::Range(
                            position_that_is_already_in_buffer,
                            i - 1,
                          ),
                        ) {
                        Ok(data_str) => b.write_stringview(data_str)
                        Err(e) => return Some((i, Err(e)))
                      }
                    }
                    b.write_char(a)
                    i += 1
                    position_that_is_already_in_buffer = i
                    ends_with_unescaped_dot = 0
                  }
                  None => abort(" cannot happen")
                  // 理论上不可达，因为上面已经初始化了
                  // 可以留空或添加 debug assert
                }
              }
              None =>
                // 数据不足，等待更多输入
                return None
            }
          } else if i == 0 {
            if !(RdfLexer::is_possible_pn_chars_u(c) ||
              c == ':' ||
              c.is_ascii_digit()) {
              return Some((0, Ok(("".to_string(), false))))
            }
            if !self.lenient {
              might_be_invalid_iri = RdfLexer::is_possible_pn_chars_base_but_not_valid_iri(
                  c,
                ) ||
                c == ':'
            }
            i += consumed
          } else if RdfLexer::is_possible_pn_chars(c) || c == ':' {
            if !self.lenient {
              might_be_invalid_iri = RdfLexer::is_possible_pn_chars_base_but_not_valid_iri(
                  c,
                ) ||
                c == ':'
            }
            i += consumed
            ends_with_unescaped_dot = 0
          } else if c == '.' {
            i += consumed
            ends_with_unescaped_dot += 1
          } else {
            // 遇到非法字符，准备返回结果
            let result = if buffer is Some(buffer_val) {
              match
                str_from_utf8(
                  data[position_that_is_already_in_buffer:i],
                  Range::Range(position_that_is_already_in_buffer, i),
                ) {
                Ok(data_str) => buffer_val.write_stringview(data_str)
                Err(e) => return Some((i, Err(e)))
              }
              // 修复：将 StringBuilder 转为 String，然后去除末尾的点
              let mut res_str = buffer_val.to_string()
              // 简单去除末尾的 ends_with_unescaped_dot 个字符
              if ends_with_unescaped_dot > 0 {
                let len = res_str.length()
                if len >= ends_with_unescaped_dot {
                  res_str = res_str[:len - ends_with_unescaped_dot].to_owned()
                }
              }
              i -= ends_with_unescaped_dot
              res_str
            } else {
              let mut data_str = match
                str_from_utf8(data[:i], Range::Range(0, i)) {
                Ok(d) => d
                Err(e) => return Some((i, Err(e)))
              }
              data_str = data_str[:data_str.length() - ends_with_unescaped_dot].to_owned()
              i -= ends_with_unescaped_dot
              data_str
            }
            return Some((i, Ok((result, might_be_invalid_iri))))
          }
        Err(e) => return Some((e.range().end, Err(e)))
      }
    } else if is_ending {
      let result = if buffer is Some(buffer_val) {
        // 修复：处理缓冲区中剩余的数据
        if i - position_that_is_already_in_buffer > 0 {
          match
            str_from_utf8(
              data[position_that_is_already_in_buffer:i],
              Range::Range(position_that_is_already_in_buffer, i),
            ) {
            Ok(data_str) => buffer_val.write_stringview(data_str)
            Err(e) => return Some((i, Err(e)))
          }
        }
        let mut res_str = buffer_val.to_string()
        // 去除末尾的点
        while res_str.has_suffix(".") {
          let len = res_str.length()
          res_str = res_str[:len - 1].to_owned()
          i -= 1
        }
        res_str
      } else {
        let mut data_str = match str_from_utf8(data[:i], Range::Range(0, i)) {
          Ok(d) => d
          Err(e) => return Some((i, Err(e)))
        }
        while data_str.has_suffix(".") {
          data_str = data_str[:data_str.length() - 1].to_owned()
          i -= 1
        }
        data_str
      }
      return Some((i, Ok((result, might_be_invalid_iri))))
    } else {
      return None
    }
  }
}

///|
fn RdfLexer::recognize_blank_node_label(
  data : ArrayView[Byte],
  is_ending : Bool,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  let mut i = 2
  while true {
    match RdfLexer::recognize_unicode_char(data[i:], i) {
      Some(c) =>
        match c {
          Ok((c, consumed)) => {
            if (
                i == 2 &&
                (RdfLexer::is_possible_pn_chars_u(c) || c.is_ascii_digit())
              ) ||
              (i > 2 && RdfLexer::is_possible_pn_chars(c)) {

            } else if i == 2 {
              return Some(
                (
                  i,
                  Err(
                    TokenRecognizerError::InvalidErrMessage(
                      data[0:i],
                      Range::Range(0, i),
                      "A blank node ID cannot be empty",
                    ),
                  ),
                ),
              )
            } else if c == '.' {
              if data[i - 1] == b'.' {
                i -= 1
                return Some(
                  (
                    i,
                    str_from_utf8(data[2:i], Range::Range(2, i)).map(s => {
                      TokenOrLineJump::Token(N3Token::BlankNodeLabel(s))
                    }),
                  ),
                )
              }
            } else if data[i - 1] == b'.' {
              i -= 1
              return Some(
                (
                  i,
                  str_from_utf8(data[2:i], Range::Range(2, i)).map(s => {
                    TokenOrLineJump::Token(N3Token::BlankNodeLabel(s))
                  }),
                ),
              )
            } else {
              return Some(
                (
                  i,
                  str_from_utf8(data[2:i], Range::Range(2, i)).map(s => {
                    TokenOrLineJump::Token(N3Token::BlankNodeLabel(s))
                  }),
                ),
              )
            }
            i += consumed
          }
          Err(e) => return Some((e.range().end, Err(e)))
        }
      _ => break
    }
  }
  if is_ending {
    if data[i - 1] == b'.' {
      i -= 1
    }
    if i > 2 {
      return Some(
        (
          i,
          str_from_utf8(data[2:i], Range::Range(2, i)).map(s => {
            TokenOrLineJump::Token(N3Token::BlankNodeLabel(s))
          }),
        ),
      )
    } else {
      return Some(
        (
          i,
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:i],
              Range::Range(0, i),
              "A blank node ID cannot be empty",
            ),
          ),
        ),
      )
    }
  }

  None
}

///|
fn RdfLexer::recognize_lang_tag(
  self : RdfLexer,
  data : ArrayView[Byte],
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  let mut is_last_block_empty = true
  let mut are_digits_allowed = false
  let mut last_valid_index = 1 // 记录最后一个合法字符的位置

  for _item in data[1:].iter2() {
    let (i, c) = _item
    if (are_digits_allowed && is_ascii_alphanumeric(Byte::to_char(c))) ||
      (!are_digits_allowed && Byte::to_char(c).is_ascii_alphabetic()) {
      is_last_block_empty = false
      last_valid_index = i + 2 // i 是从 0 开始的索引，相对于 data[1:]，所以要 +2 才是相对于 data 的索引
    } else if i == 0 {
      // ... 错误处理 ...
    } else if is_last_block_empty {
      // ... 处理连字符逻辑 ...
    } else if c == b'-' {
      is_last_block_empty = true
      are_digits_allowed = true
    } else {
      // 遇到非字母数字字符（如空格、标点），说明语言标签结束
      return Some(
        (
          i + 1, // 消耗到当前字符之前
          self.parse_lang_tag(
            data[1:i + 1].to_owned(),
            None,
            Range::Range(1, i + 1),
          ),
        ),
      )
    }
  }

  // 循环结束，说明到了输入末尾
  if !is_last_block_empty {
    // 返回已识别的部分
    return Some(
      (
        last_valid_index,
        self.parse_lang_tag(
          data[1:last_valid_index].to_owned(),
          None,
          Range::Range(1, last_valid_index),
        ),
      ),
    )
  }

  None
}

///|
fn RdfLexer::parse_lang_tag(
  self : RdfLexer,
  lang_tag : ArrayView[Byte],
  direction : Bytes?,
  position : Range,
) -> Result[TokenOrLineJump[N3Token], TokenRecognizerError] {
  debug("Parsing lang tag from bytes: \{lang_tag}")

  // 1. 先将 bytes 转换为 string，处理可能的 UTF-8 错误
  let lang_str_result = str_from_utf8(lang_tag, position)

  let parsed_lang = match lang_str_result {
    Err(e) =>
      Err(
        TokenRecognizerError::InvalidErrMessage(
          lang_tag[position.start:position.end],
          position,
          e.message(), // 假设 e 有 message 方法，或者根据实际 Error 类型调整
        ),
      )
    Ok(lang_str) =>
      if self.lenient {
        Ok(lang_str)
      } else {
        // 修复：先 map 提取 string，再 map_err 转换错误类型
        LanguageTag::parse(lang_str)
        .map(fn(tag) { tag.to_string() }) // 假设 LanguageTag 有 to_string 或类似方法获取原始字符串
        .map_err(fn(e) {
          TokenRecognizerError::InvalidErrMessage(
            lang_tag[position.start:position.end],
            position,
            e.to_string(), // 根据实际 Error 类型调整
          )
        })
      }
  }

  match parsed_lang {
    Err(e) => Err(e)
    Ok(lang_str) => {
      let parsed_dir = match direction {
        None => Ok(None)
        Some(dir_bytes) =>
          if dir_bytes == b"ltr" {
            Ok(Some(BaseDirection::Ltr))
          } else if dir_bytes == b"rtl" {
            Ok(Some(BaseDirection::Rtl))
          } else {
            Err(
              TokenRecognizerError::InvalidErrMessage(
                dir_bytes.to_array(),
                Range::Range(position.end - dir_bytes.length(), position.end),
                "The allowed base directions are --ltr and --rtl, found --" +
                @utf8.decode_lossy(dir_bytes),
              ),
            )
          }
      }

      match parsed_dir {
        Err(e) => Err(e)
        Ok(dir_opt) =>
          Ok(
            TokenOrLineJump::Token(
              N3Token::LangTag(language=lang_str, direction=dir_opt),
            ),
          )
      }
    }
  }
}
// fn RdfLexer::parse_lang_tag(self : RdfLexer, lang_tag : Bytes, direction : Option[Bytes], position : Range) -> Result[TokenOrLineJump[N3Token], TokenRecognizerError] {
//   if direction is Some(direction) {
//     return Err(TokenRecognizerError::InvalidErrMessage(lang_tag[position.end - direction.length():position.end],Range::Range(position.end - direction.length(),position.end), "Literal base direction are only allowed in RDF 1.2"))
//   }
//   let lang_tag = str_from_utf8(lang_tag, position)
//   Ok({ language: if self.lenient {
//     lang_tag
//   } else {
//     LanguageTag::parse(lang_tag).map_err(fn(e) { (position, e.to_string()) })
//   }, direction: direction.map(fn(direction) {   Ok(match direction {
//     b"ltr" => BaseDirection::Ltr
//     b"rtl" => BaseDirection::Rtl
//     _ =>     return Err((position.end - direction.length():position.end, "The allowed base directions are --ltr and --rtl, found --\{String::from_utf8_lossy(direction)}"))
//   }) }).flatten() })
// }

///|
// fn RdfLexer::recognize_string(
//   self : RdfLexer,
//   data : BytesView,
//   delimiter : Byte,
// ) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
//   let string = StringBuilder::new()
//   let mut i = 1
//   for ;; {
//     let mut end = memchr2(delimiter, b'\'', data[i:]).unwrap()
//     if !self.lenient {
//       if memchr2(b'\'', b'\'', data[i:i + end]) is Some(line_jump_end) {
//         end = line_jump_end
//       }
//     }
//     match str_from_utf8(data[i:i + end], Range::Range(i, i + end)) {
//       Ok(s) => string.write_string(s)
//       Err(e) => return Some((end, Err(e)))
//     }
//     i += end
//     match data[i] {
//       c if c == delimiter =>
//         return Some(
//           (
//             i + 1,
//             Ok(TokenOrLineJump::Token(N3Token::String(string.to_string()))),
//           ),
//         )
//       b'\'' => {
//         let (additional, c) = self.recognize_escape(data[i:], i, true).unwrap()
//         i += additional + 1
//         match c {
//           Ok(c) => string.write_char(c)
//           Err(e) => {
//             let end = memchr(delimiter, data[i:]).unwrap()
//             return Some((i + end + 1, Err(e)))
//           }
//         }
//       }
//       b'\n' | b'\r' => {
//         let end = memchr(delimiter, data[i:]).unwrap()
//         return Some(
//           (
//             i + end + 1,
//             Err(
//               TokenRecognizerError::InvalidErrMessage(
//                 data[i:i + 1],
//                 Range::Range(i, i + 1),
//                 "Line jumps are not allowed in string literals, use \n",
//               ),
//             ),
//           ),
//         )
//       }
//       _ => abort("Unexpected character in string literal")
//     }
//   }
// }

///|

///|
fn RdfLexer::recognize_string(
  self : RdfLexer,
  data : ArrayView[Byte],
  delimiter : Byte,
  is_ending : Bool,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  debug("DEBUG: Entering recognize_string with delimiter \{delimiter}")

  let string = StringBuilder::new()
  let mut i = 1
  let mut loop_count = 0

  for ;; {
    loop_count += 1
    if loop_count > 100 {
      debug("Infinite loop detected in recognize_string")
    }
    // 1. 查找下一个定界符或反斜杠
    // 如果找不到，说明数据不足，返回 None 等待更多数据
    let end_opt = array_view_memchr2(delimiter, b'\\', data[i:])

    let mut end = match end_opt {
      Some(e) => {
        debug("DEBUG: Found end of string literal at index \{i + e}")
        e
      }
      None => {
        debug("DEBUG: No end of string literal found")
        if is_ending {
          return Some(
            (
              data.length(),
              Err(
                TokenRecognizerError::UnexpectedEndOfInput(
                  data[i:],
                  Range::Range(i, data.length()),
                ),
              ),
            ),
          )
        } else {
          return None
        }
      }
    }

    // 2. 在非宽松模式下，检查这段普通字符中是否包含未转义的换行符
    if !self.lenient {
      if array_view_memchr2(b'\n', b'\r', data[i:i + end])
        is Some(line_jump_end) {
        end = line_jump_end
      }
    }

    // 3. 将普通字符部分追加到字符串缓冲区
    match str_from_utf8(data[i:i + end], Range::Range(i, i + end)) {
      Ok(s) => string.write_string(s)
      Err(e) => return Some((i + end, Err(e)))
    }
    i += end

    // 4. 检查当前遇到的字符是什么
    // 注意：此时 data[i] 必须是 delimiter 或 b'\\' 或 (非lenient下的) 换行符
    if i >= data.length() {
      // 防御性检查：如果索引越界，说明数据不足
      return None
    }

    match data[i] {
      c if c == delimiter => {
        debug(
          "Returning String Token: '\{string.to_string()}', Consumed: \{i + 1}",
        )
        // 遇到定界符，字符串结束
        return Some(
          (
            i + 1,
            Ok(TokenOrLineJump::Token(N3Token::String(string.to_string()))),
          ),
        )
      }
      b'\\' => {
        // 遇到反斜杠，处理转义序列
        let escape_result = self.recognize_escape(data[i:], i, true)

        match escape_result {
          Some((additional, c_result)) => {
            i += additional + 1 // 移动过 \ 和转义字符
            if i > data.length() {
              return None // 数据不足
            }
            match c_result {
              Ok(c) => string.write_char(c)
              Err(e) => {
                // 转义错误：找到结束符并返回错误
                let end_opt = array_view_memchr(delimiter, data[i:])
                let final_end = match end_opt {
                  Some(e) => i + e + 1
                  None => data.length() // 或者返回 None
                }
                return Some((final_end, Err(e)))
              }
            }
          }
          None =>
            // 需要更多数据来识别转义序列
            return None
        }
      }
      b'\n' | b'\r' => {
        // 遇到未转义的换行符
        let end_opt = array_view_memchr(delimiter, data[i:])
        let final_end = match end_opt {
          Some(e) => i + e + 1
          None => i + 1
        }
        return Some(
          (
            final_end,
            Err(
              TokenRecognizerError::InvalidErrMessage(
                data[i:i + 1],
                Range::Range(i, i + 1),
                "Line jumps are not allowed in string literals, use \\n",
              ),
            ),
          ),
        )
      }
      _ =>
        // 理论上不会到达这里，除非 memchr2 逻辑有误
        // 为了安全，返回错误或 abort
        return Some(
          (
            i + 1,
            Err(
              TokenRecognizerError::InvalidErrMessage(
                data[i:i + 1],
                Range::Range(i, i + 1),
                "Unexpected character in string literal",
              ),
            ),
          ),
        )
    }
  }
}

///|
fn RdfLexer::recognize_long_string(
  self : RdfLexer,
  data : ArrayView[Byte],
  delimiter : Byte,
  is_ending : Bool,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  let string = StringBuilder::new()
  let mut i = 3
  for ;; {
    let end_opt = array_view_memchr2(delimiter, b'\\', data[i:])

    let mut end = match end_opt {
      Some(e) => e
      None =>
        return if is_ending {
          return Some(
            (
              data.length(),
              Err(
                TokenRecognizerError::UnexpectedEndOfInput(
                  data[i:],
                  Range::Range(i, data.length()),
                ),
              ),
            ),
          )
        } else {
          return None // 需要更多数据
        }
    } // 需要更多数据

    // 2. 在非宽松模式下，检查这段普通字符中是否包含未转义的换行符
    if !self.lenient {
      if array_view_memchr2(b'\n', b'\r', data[i:i + end])
        is Some(line_jump_end) {
        end = line_jump_end
      }
    }

    // let end = array_view_memchr2(delimiter, b'\'', data[i:]).unwrap()
    match str_from_utf8(data[i:i + end], Range::Range(i, i + end)) {
      Ok(s) => string.write_string(s)
      Err(e) => return Some((end, Err(e)))
    }
    i += end
    match data[i] {
      c if c == delimiter => {
        if data.get(i + 1) is Some(_delimiter) &&
          data.get(i + 2) is Some(_delimiter) {
          return Some(
            (
              i + 3,
              Ok(
                TokenOrLineJump::Token(N3Token::LongString(string.to_string())),
              ),
            ),
          )
        }
        i += 1
        string.write_char(Byte::to_char(delimiter))
      }
      b'\'' =>
        match self.recognize_escape(data[i:], i, true) {
          Some((additional, c_result)) => {
            i += additional + 1
            // 防御性检查：确保索引未越界（虽然 recognize_escape 通常只消耗固定长度，但安全起见）
            if i > data.length() {
              return None
            }
            match c_result {
              Ok(c) => string.write_char(c)
              Err(e) => return Some((i, Err(e)))
            }
          }
          None =>
            // 数据不足，需要更多输入来完整解析转义序列
            return None
        }
      _ =>
        return Some(
          (
            i + 1,
            Err(
              TokenRecognizerError::InvalidErrMessage(
                data[i:i + 1],
                Range::Range(i, i + 1),
                "Unexpected character in long string literal",
              ),
            ),
          ),
        )
    }
  }
}

///|
fn RdfLexer::recognize_number(
  data : ArrayView[Byte],
  is_ending : Bool,
) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])? {
  let mut i = 0
  // let c = data.first()
  match data.get(0) {
    Some(c) => if c == b'+' || c == b'-' { i += 1 }
    None =>
      // 如果数据为空，根据具体逻辑决定是返回 None 还是错误
      return None
  }
  let count_before = match RdfLexer::recognize_digits(data[i:], is_ending) {
    Some(count) => count
    None => return None // 数据不足
  }
  i += count_before
  let c = if data.get(i) is Some(c) {
    Some(c)
  } else if is_ending {
    None
  } else {
    return None
  }
  let count_after = if c == Some(b'.') {
    i += 1
    let count_after = match RdfLexer::recognize_digits(data[i:], is_ending) {
      Some(count) => count
      None => return None // 数据不足
    }
    i += count_after
    Some(count_after)
  } else {
    None
  }
  let c = if data.get(i) is Some(c) {
    Some(c)
  } else if is_ending {
    None
  } else {
    return None
  }
  if c is Some(b'e' | b'E') {
    i += 1
    let c = if data.get(i) is Some(c) {
      Some(c)
    } else if is_ending {
      None
    } else {
      return None
    }
    if c is Some(b'+' | b'-') {
      i += 1
    }
    let count_exp = match RdfLexer::recognize_digits(data[i:], is_ending) {
      Some(count) => count
      None => return None // 数据不足
    }
    i += count_exp
    Some(
      (
        i,
        if count_exp == 0 {
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:i],
              Range::Range(0, i),
              "A double exponent cannot be empty",
            ),
          )
        } else if count_before == 0 && count_after.unwrap_or(0) == 0 {
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:i],
              Range::Range(0, i),
              "A double should not be empty",
            ),
          )
        } else {
          str_from_utf8(data[:i], Range::Range(0, i)).map(s => {
            TokenOrLineJump::Token(N3Token::Double(s))
          })
        },
      ),
    )
  } else if count_after is Some(count_after) {
    if count_after == 0 {
      i -= 1
      Some(
        (
          i,
          if count_before == 0 {
            Err(
              TokenRecognizerError::InvalidErrMessage(
                data[0:i],
                Range::Range(0, i),
                "An integer should not be empty",
              ),
            )
          } else {
            str_from_utf8(data[:i], Range::Range(0, i)).map(s => {
              TokenOrLineJump::Token(N3Token::Integer(s))
            })
          },
        ),
      )
    } else {
      Some(
        (
          i,
          str_from_utf8(data[:i], Range::Range(0, i)).map(s => {
            TokenOrLineJump::Token(N3Token::Decimal(s))
          }),
        ),
      )
    }
  } else {
    Some(
      (
        i,
        if count_before == 0 {
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:i],
              Range::Range(0, i),
              "An integer should not be empty",
            ),
          )
        } else {
          str_from_utf8(data[:i], Range::Range(0, i)).map(s => {
            TokenOrLineJump::Token(N3Token::Integer(s))
          })
        },
      ),
    )
  }
}

///|
fn RdfLexer::recognize_digits(data : ArrayView[Byte], is_ending : Bool) -> Int? {
  for _item in data.iter2() {
    let (i, c) = _item
    if !Byte::to_char(c).is_ascii_digit() {
      return Some(i)
    }
  }
  if is_ending {
    Some(data.length())
  } else {
    None
  }
}

///|

///|
fn RdfLexer::recognize_escape(
  self : RdfLexer,
  data : ArrayView[Byte],
  position : Int,
  with_echar : Bool,
) -> (Int, Result[Char, TokenRecognizerError])? {
  match data.get(1) {
    Some(b'u') =>
      // 处理 \uXXXX
      match RdfLexer::recognize_hex_char(data[2:], 4, 'u', position) {
        Ok(Some(c)) => Some((5, Ok(c)))
        Ok(None) => None // 数据不足
        Err(e) =>
          if self.lenient {
            // 尝试处理 UTF-16 代理对 \uXXXX\uXXXX
            match RdfLexer::recognize_utf16_surrogate_pair(data[2:], position) {
              Ok(Some(c)) => Some((11, Ok(c)))
              Ok(None) => None
              Err(e) => Some((5, Err(e)))
            }
          } else {
            Some((5, Err(e)))
          }
      }
    Some(b'U') =>
      // 处理 \UXXXXXXXX
      match RdfLexer::recognize_hex_char(data[2:], 8, 'U', position) {
        Ok(Some(c)) => Some((9, Ok(c)))
        Ok(None) => None
        Err(e) => Some((9, Err(e)))
      }
    Some(b't') if with_echar => Some((1, Ok('\t')))
    Some(b'b') if with_echar => Some((1, Ok('\u{0008}'))) // \b
    Some(b'n') if with_echar => Some((1, Ok('\n')))
    Some(b'r') if with_echar => Some((1, Ok('\r')))
    Some(b'f') if with_echar => Some((1, Ok('\u{000C}'))) // \f
    Some(b'"') if with_echar => Some((1, Ok('"')))
    Some(b'\'') if with_echar => Some((1, Ok('\'')))
    Some(b'\\') if with_echar => Some((1, Ok('\\')))
    Some(c) =>
      // 未知转义字符
      Some(
        (
          1,
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[1:2],
              Range::Range(position + 1, position + 2),
              "Unexpected escape character \{c}",
            ),
          ),
        ),
      )
    None => None // 数据不足
  }
}
// fn RdfLexer::recognize_escape(self : RdfLexer, data : BytesView, position : Int, with_echar : Bool) -> Option[(Int, Result[Char, TokenRecognizerError])] {
//   match data.get(1) is Some(_c) {
//     b'u' => match RdfLexer::recognize_hex_char(data[2:].to_owned(), 4, 'u', position) {
//       Ok(c) => Some((5, Ok(c)))
//       Err(e) =>       if self.lenient {
//         match RdfLexer::recognize_utf16_surrogate_pair(data[2:], position) {
//           Ok(c) => Some((11, Ok(c!)))
//           Err(e) => Some((5, Err(e)))
//         }
//       } else {
//         Some((5, Err(e)))
//       }
//     }
//     b'U' => match RdfLexer::recognize_hex_char(data[2:], 8, 'U', position) {
//       Ok(c) => Some((9, Ok(c!)))
//       Err(e) => Some((9, Err(e)))
//     }
//     b't' if with_echar => Some((1, Ok('	')))
//     b'b' if with_echar => Some((1, Ok('')))
//     b'n' if with_echar => Some((1, Ok('
// ')))
//     b'r' if with_echar => Some((1, Ok('
// ')))
//     b'f' if with_echar => Some((1, Ok('')))
//     b'"' if with_echar => Some((1, Ok('"')))
//     b'\'' if with_echar => Some((1, Ok(''')))
//     b'\'' if with_echar => Some((1, Ok('\'')))
//     c => Some((1, Err((position:position + 2, "Unexpected escape character '\\{Byte::to_char(c)}'").into())))
//   }
// }

///|
fn RdfLexer::recognize_hex_char(
  data : ArrayView[Byte],
  len : Int,
  escape_char : Char,
  position : Int,
) -> Result[Char?, TokenRecognizerError] {
  if data.length() < len {
    return Ok(None)
  }
  let mut codepoint = 0
  for i in 0..<len {
    let c = data[i]
    // let c_char = Byte::to_char(c)

    codepoint = codepoint * 16 +
      Char::to_int(
        match c {
          b'0'..=b'9' => Byte::to_char(c - b'0')
          b'a'..=b'f' => Byte::to_char(c - b'a' + 10)
          b'A'..=b'F' => Byte::to_char(c - b'A' + 10)
          _ => {
            let val = @utf8.decode_lossy(array_to_view(data[:len]))
            return Err(
              TokenRecognizerError::InvalidErrMessage(
                data[position + i + 2:position + i + 3],
                Range::Range(position + i + 2, position + i + 3),
                "The escape sequence '\{escape_char}\{val}' is not a valid hexadecimal string",
              ),
            )
          }
        },
      )
  }
  let c = Int::unsafe_to_char(codepoint)
  // .ok_or_else(fn() {   let val = @utf8.decode_lossy(data[:len])
  // (position:position + len + 2, "The escape sequence '\{escape_char}\{val}' is encoding \{codepoint} that is not a valid unicode character") })
  Ok(Some(c))
}

///|
fn RdfLexer::recognize_utf16_surrogate_pair(
  data : ArrayView[Byte],
  position : Int,
) -> Result[Char?, TokenRecognizerError] {
  // 检查长度是否足够容纳 \uXXXX\uXXXX (2 + 4 + 2 + 4 = 12 个字符/字节)
  if data.length() < 12 {
    return Ok(None)
  }

  // 提取高代理项的十六进制字符串 \uXXXX
  // data[2:6] 是第一个 \u 后的4个十六进制字符
  let val_high_bytes = data[2:6]
  let val_high = match
    str_from_utf8(val_high_bytes, Range::Range(position + 2, position + 6)) {
    Ok(s) => s
    Err(e) => return Err(e)
  }

  let surrogate_high = match from_str_radix(val_high, 16) {
    Ok(v) => v
    Err(_) =>
      return Err(
        TokenRecognizerError::InvalidErrMessage(
          val_high_bytes,
          Range::Range(position + 2, position + 6),
          "The escape sequence '\\u{val_high}' is not a valid hexadecimal string",
        ),
      )
  }

  // 检查是否为高代理项范围 D800-DBFF
  if !(surrogate_high >= 0xD800 && surrogate_high <= 0xDBFF) {
    return Err(
      TokenRecognizerError::InvalidErrMessage(
        val_high_bytes,
        Range::Range(position + 2, position + 6),
        "The escape sequence '\\u{val_high}' is not a UTF-16 high surrogate",
      ),
    )
  }

  // 检查接下来的两个字符是否是 '\' 和 'u'
  if data[6] != b'\\' || data[7] != b'u' {
    return Err(
      TokenRecognizerError::InvalidErrMessage(
        data[6:8],
        Range::Range(position + 6, position + 8),
        "UTF-16 surrogate escape sequence must be followed by another surrogate escape sequence '\\u'",
      ),
    )
  }

  // 提取低代理项的十六进制字符串 \uXXXX
  let val_low_bytes = data[8:12]
  let val_low = match
    str_from_utf8(val_low_bytes, Range::Range(position + 8, position + 12)) {
    Ok(s) => s
    Err(e) => return Err(e)
  }

  let surrogate_low = match from_str_radix(val_low, 16) {
    Ok(v) => v
    Err(_) =>
      return Err(
        TokenRecognizerError::InvalidErrMessage(
          val_low_bytes,
          Range::Range(position + 8, position + 12),
          "The escape sequence '\\u\{val_low}' is not a valid hexadecimal string",
        ),
      )
  }

  // 检查是否为低代理项范围 DC00-DFFF
  if !(surrogate_low >= 0xDC00 && surrogate_low <= 0xDFFF) {
    return Err(
      TokenRecognizerError::InvalidErrMessage(
        val_low_bytes,
        Range::Range(position + 8, position + 12),
        "The escape sequence '\\u\{val_low}' is not a UTF-16 low surrogate",
      ),
    )
  }

  // 组合代理对
  let c = Int::to_char(
    ((UInt::reinterpret_as_int(surrogate_high) - 0xD800) << 10) +
    (UInt::reinterpret_as_int(surrogate_low) - 0xDC00) +
    0x10000,
  )

  match c {
    Some(char) => Ok(Some(char))
    None =>
      Err(
        TokenRecognizerError::InvalidErrMessage(
          data[2:12],
          Range::Range(position + 2, position + 12),
          "Escape sequences do not form a valid Unicode character",
        ),
      )
  }
}
// fn RdfLexer::recognize_utf16_surrogate_pair(data : Bytes, position : Int) -> Result[Option[Char], TokenRecognizerError] {
//   let Some(val_high_slice) = data.get(4)
//   let val_high = str_from_utf8(val_high_slice, position:position + 6)
//   let surrogate_high = UInt::from_str_radix(val_high, 16).map_err(fn(e) {   (position:position + 6, "The escape sequence '\u{val_high}' is not a valid hexadecimal string: {e}") })
//   if !(surrogate_high is 0xD800 ..= 0xDFFF) {
//     return Err((position:position + 6, "The escape sequence '\u{val_high}' is not a UTF-16 surrogate").into())
//   }
//   let Some(_) = data.get(4)
//   let Some(_) = data.get(5)
//   if d4 != b'\'' || d5 != b'u' {
//     return Err((position:position + 6, "UTF-16 surrogate escape sequence '\u{val_high}' must be followed by another surrogate escape sequence").into())
//   }
//   let Some(val_low_slice) = data.get(6:10)
//   let val_low = str_from_utf8(val_low_slice, position + 6:position + 12)
//   let surrogate_low = UInt::from_str_radix(val_low, 16).map_err(fn(e) {   (position + 6:position + 12, "The escape sequence '\u{val_low}' is not a valid hexadecimal string: {e}") })
//   let mut chars = Char::decode_utf16([surrogate_high, surrogate_low])
//   let c = chars.next().bind(Result::ok).ok_or_else(fn() {   (position:position + 12, "Escape sequences '\u{val_high}\u{val_low}' do not form a valid UTF-16 surrogate pair") })
//   debug_assert_eq(chars.next(), None, "Surrogate pair should combine to exactly one character")
//   Ok(Some(c))
// }

///|
fn RdfLexer::recognize_unicode_char(
  data : ArrayView[Byte],
  position : Int,
) -> Result[(Char, Int), TokenRecognizerError]? {
  let mut code_point : UInt = 0
  let mut bytes_needed : Int = 0
  let mut lower_boundary = 0x80
  let mut upper_boundary = 0xBF
  let byte = match data.get(0) {
    Some(b) => b
    None => return None // 数据不足
  }
  match byte {
    0x00..=0x7F => return Some(Ok((Byte::to_char(byte), 1)))
    0xC2..=0xDF => {
      bytes_needed = 1
      code_point = Byte::to_uint(byte) & 0x1F
    }
    0xE0..=0xEF => {
      if byte == 0xE0 {
        lower_boundary = 0xA0
      }
      if byte == 0xED {
        upper_boundary = 0x9F
      }
      bytes_needed = 2
      code_point = Byte::to_uint(byte) & 0xF
    }
    0xF0..=0xF4 => {
      if byte == 0xF0 {
        lower_boundary = 0x90
      }
      if byte == 0xF4 {
        upper_boundary = 0x8F
      }
      bytes_needed = 3
      code_point = Byte::to_uint(byte) & 0x7
    }
    _ =>
      return Some(
        Err(
          TokenRecognizerError::InvalidErrMessage(
            data[position:position + 1],
            Range::Range(position, position + 1),
            "Invalid UTF-8 character encoding",
          ),
        ),
      )
  }
  for i in 1..<=bytes_needed {
    let next_byte = match data.get(i) {
      Some(b) => b
      None => return None // 数据不足，需要更多输入
    }
    if next_byte < Int::to_byte(lower_boundary) ||
      upper_boundary < Byte::to_int(byte) {
      return Some(
        Err(
          TokenRecognizerError::InvalidErrMessage(
            data[position:position + i],
            Range::Range(position, position + i),
            "Invalid UTF-8 character encoding",
          ),
        ),
      )
    }
    lower_boundary = 0x80
    upper_boundary = 0xBF
    code_point = (code_point << 6) | (Byte::to_uint(byte) & 0x3F)
  }
  match Int::to_char(UInt::reinterpret_as_int(code_point)) {
    Some(c) => Some(Ok((c, bytes_needed + 1)))
    None => {
      let error_range = Range::Range(position, position + bytes_needed)
      let msg = "The codepoint \{code_point} is not a valid unicode character"

      Some(
        Err(
          TokenRecognizerError::InvalidErrMessage(
            data[position:position + bytes_needed],
            error_range,
            msg,
          ),
        ),
      )
    }
  }
  // Some(UInt::reinterpret_as_int(code_point)
  // .map(fn(c) { (c, bytes_needed + 1) }).ok_or_else(fn() { (data[position:position + bytes_needed], "The codepoint {code_point:X} is not a valid unicode character")}))
}

///|
fn RdfLexer::is_possible_pn_chars_base(c : Char) -> Bool {
  c
  is ('A'..='Z'
  | 'a'..='z'
  | '\u{00C0}'..='\u{00D6}'
  | '\u{00D8}'..='\u{00F6}'
  | '\u{00F8}'..='\u{02FF}'
  | '\u{0370}'..='\u{037D}'
  | '\u{037F}'..='\u{1FFF}'
  | '\u{200C}'..='\u{200D}'
  | '\u{2070}'..='\u{218F}'
  | '\u{2C00}'..='\u{2FEF}'
  | '\u{3001}'..='\u{D7FF}'
  | '\u{F900}'..='\u{FDCF}'
  | '\u{FDF0}'..='\u{FFFD}'
  | '\u{10000}'..='\u{EFFFF}')
}

///|
pub fn RdfLexer::is_possible_pn_chars_u(c : Char) -> Bool {
  RdfLexer::is_possible_pn_chars_base(c) || c == '_'
}

///|
pub fn RdfLexer::is_possible_pn_chars(c : Char) -> Bool {
  RdfLexer::is_possible_pn_chars_u(c) ||
  c
  is ('-'
  | '0'..='9'
  | '\u{00B7}'
  | '\u{0300}'..='\u{036F}'
  | '\u{203F}'..='\u{2040}')
}

///|
fn RdfLexer::is_possible_pn_chars_base_but_not_valid_iri(c : Char) -> Bool {
  c is ('\u{FFF0}'..='\u{FFFD}') ||
  Char::to_int(c) % Char::to_int('\u{FFFE}') == 0 ||
  Char::to_int(c) % Char::to_int('\u{FFFF}') == 0
}

///|
pub fn resolve_local_name(
  prefix : String,
  localx : String,
  might_be_invalid_iri : Bool,
  prefixes : Map[String, Iri],
) -> Result[NamedNodeRef, String] {
  if prefixes.get(prefix) is Some(start) {
    let iri = "\{start.into_string()}\{localx}"
    let iri = Iri::Iri(iri).as_ref()
    // let iri = IriRef::of_ref(iri)
    if might_be_invalid_iri || start.path() is Some("") {
      if IriRef::parse(iri) is Err(e) {
        return Err(
          "The prefixed name \{prefix}:\{localx} builds IRI \{iri.into_string()} that is invalid:\{e.to_string()}",
        )
      }
    }
    Ok(NamedNodeRef::new_unchecked(iri.into_string()))
  } else {
    Err("The prefix \{prefix}: has not been declared")
  }
}

///|
fn str_from_utf8(
  data : ArrayView[Byte],
  range : Range,
) -> Result[String, TokenRecognizerError] {
  let view = array_to_view(data)

  let s = try @utf8.decode(view.to_owned()) |> Ok() catch {
    _e => {
      let error_start = range.start
      let error_end = Int::min(range.end, error_start + 4)

      return Err(
        TokenRecognizerError::InvalidErrMessage(
          data[error_start:error_end],
          Range::Range(error_start, error_end),
          "Invalid UTF-8 sequence",
        ),
      )
    }
  }

  s
}

// 2. 使用 decode_lossy 直接获取 String
// 注意：decode_lossy 通常不返回 Result，而是直接返回 String
// match @utf8.decode_lossy(view) {
//   Ok(s) => s
//   Err(e) =>
//     return Err(
//       TokenRecognizerError::InvalidErrMessage(
//         data[range.start:range.end],
//         range,
//         "Invalid UTF-8 sequence at position \{range.start}: \{range.end}.",
//       ),
//     )

// }

// 3. 如果你仍然希望检测严重的 UTF-8 错误并报错，
//    你需要手动检查或者保留 decode。
//    但如果目的是“尽可能解析”，直接返回即可：
// catch {
//   _e =>
//     return Err(
//       TokenRecognizerError::InvalidErrMessage(
//         data[range.start:range.end],
//         range,
//         "Invalid UTF-8 sequence at position \{range.start}: \{range.end}.",
//       ),
//     )
// }
// guard s is Ok(s) else {
//   return Err(
//     TokenRecognizerError::InvalidErrMessage(
//       data[range.start:range.end],
//       range,
//       "Invalid UTF-8 sequence at position \{range.start}: \{range.end}.",
//     ),
//   )
// }

///|
fn string_from_utf8(
  data : Array[Byte],
  range : Range,
) -> Result[String, TokenRecognizerError] {
  str_from_utf8(data[:], range)
}

// fn str_from_utf8(data : BytesView, range : Range) -> Result[String, TokenRecognizerError] {
//   @utf8.decode(data).map_err(fn(e) {   (range.start + e.valid_up_to():min(range.end, range.start + e.valid_up_to() + 4), "Invalid UTF-8: {e}").into() })
// }
// fn string_from_utf8(data : Array[Byte], range : Range) -> Result[String, TokenRecognizerError] {
//   @utf8.decode_lossy(array_to_view(data)).map_err(fn(e) {   (range.start + e.utf8_error().valid_up_to():min(range.end, range.start + e.utf8_error().valid_up_to() + 4), "Invalid UTF-8: {e}").into() })
// }
