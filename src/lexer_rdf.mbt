///|
pub(all) enum RdfLexerMode {
  NTriples
  // Turtle
  N3
} derive(Eq)

///|
pub(all) struct RdfLexer {
  mode : RdfLexerMode
  lenient : Bool
}

///|
pub fn RdfLexer::RdfLexer(mode : RdfLexerMode, lenient : Bool) -> RdfLexer {
  { mode, lenient }
}

///|
 fn RdfLexer::recognize_iri(
    self : RdfLexer,
    data : ArrayView[Byte],
    options : LexerOptions,
    location_ctx : SourcePos,
  ) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
    let string = []
    let mut i = 1

    // 循环直到找到 '>'
    for ;; {
      let end_opt = array_view_memchr(b'>', data[i:])

      let end = match end_opt {
        Some(e) => e
        None =>
          return Some(
            (
              data.length(),
              Err(
                TokenRecognizerError::IriTruncated(
                  data[i:],
                  Range(
                    location_ctx.offset + i,
                    location_ctx.offset + i + data.length(),
                  ),
                ),
              ),
            ),
          )
      }

      // 将内容追加到 string，同时处理 Unicode 转义
      let mut j = i
      while j < i + end {
        let byte = data[j]
        if byte == b'\\' && j + 1 < data.length() {
          let next_byte = data[j + 1]
          if next_byte == b'u' && j + 5 < i + end {
            // \uXXXX - 4 位十六进制
            let hex = str_from_utf8(data[j + 2:j + 6],Range::Range(j+2,j+6)).unwrap_or("0000")
            let code = hex.to_upper()
            let codepoint = hex_to_uint(code)
            let ch = UInt::to_byte(codepoint)
            string.append([ch])
            j += 6
          } else if next_byte == b'U' && j + 9 < i + end {
            // \UXXXXXXXX - 8 位十六进制
            let hex = str_from_utf8(data[j + 2:j + 10],Range::Range(j+2,j+6)).unwrap_or("00000000")
            let code = hex.to_upper()
            let codepoint =hex_to_uint(code)
            let ch = UInt::to_byte(codepoint)
            string.append([ch])
            j += 10
          } else {
            // 其他转义，保持原样
            string.push(byte)
            j += 1
          }
        } else {
          string.push(byte)
          j += 1
        }
      }

      i += end + 1

      return Some(
        (
          i,
          self.parse_iri(
            string,
            Range(location_ctx.offset, location_ctx.offset + i),
            options,
          ),
        ),
      )
    }
  }
///|
fn RdfLexer::parse_iri(
  self : RdfLexer,
  iri_bytes : Array[Byte],
  position : Range,
  options : LexerOptions,
) -> Result[LocatedTokenOrLineJump, TokenRecognizerError] {
  // 1. 将字节数组转换为字符串，处理可能的 UTF-8 错误
  let iri_str = match string_from_utf8(iri_bytes, position) {
    Ok(s) => s
    Err(e) => return Err(e)
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
        TokenRecognizerError::IriParsingError(e.to_string(), position)
      })
    }
  } else {
    // 没有 base_iri，直接解析绝对 IRI
    let iri = Iri::new(iri_str)

    if self.lenient {
      Ok(IriRef::parse_unchecked(iri))
    } else {
      // 严格模式
      IriRef::parse(iri).map_err(fn(e) {
        TokenRecognizerError::IriParsingError(e.to_string(), position)
      })
    }
  }

  // 3. 返回 Token
  let final_iri = match final_iri {
    Ok(iri) => iri
    Err(e) => return Err(e)
  }
  // 使用传入的 position (已经是全局 Range)
  Ok(
    LocatedTokenOrLineJump::LocatedN3Token(
      LocatedN3Token(N3Token::Iri(final_iri.base_iri), position),
    ),
  )
}

///|
fn RdfLexer::recognize_pname_or_keyword(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
  location_ctx : SourcePos,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
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
                    Range(location_ctx.offset, location_ctx.offset + consumed),
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
          let range = Range(location_ctx.offset, location_ctx.offset + i)

          return Some(
            (
              i,
              str_from_utf8(
                data[:i],
                Range(location_ctx.offset, location_ctx.offset + i),
              ).map(s => {
                LocatedTokenOrLineJump::LocatedN3Token(
                  LocatedN3Token(N3Token::PlainKeyword(s), range),
                )
              }),
            ),
          )
        }
      Some(Err(e)) => return Some((e.range().end - location_ctx.offset, Err(e))) // 注意：子函数返回的 range 可能需要调整，这里假设 e.range 是局部的
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
                    Range(location_ctx.offset, location_ctx.offset + 1),
                  ),
                ),
              )
            } else {
              (
                i,
                str_from_utf8(
                  data[:i],
                  Range(location_ctx.offset, location_ctx.offset + i),
                ).map(s => {
                  LocatedTokenOrLineJump::LocatedN3Token(
                    LocatedN3Token(
                      N3Token::PlainKeyword(s),
                      Range(location_ctx.offset, location_ctx.offset + i),
                    ),
                  )
                }),
              )
            },
          )
        } else {
          return None
        }
    }
  }

  // 提取前缀 (如果代码能到达这里，说明遇到了 ':')
  let pn_prefix = match
    str_from_utf8(
      data[:i - 1],
      Range(location_ctx.offset, location_ctx.offset + i - 1),
    ) {
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
            Range(location_ctx.offset, location_ctx.offset + i),
            "'\{pn_prefix}' is not a valid prefix: prefixes are not allowed to end with '.'",
          ),
        ),
      ),
    )
  }

  // 解析本地部分
  match
    self.recognize_optional_pn_local(
      data[i:],
      is_ending,
      location_ctx.offset + i,
    ) {
    Some((consumed, Ok((localx, might_be_invalid_iri)))) => {
      let total_consumed = consumed + i
      let range = Range(
        location_ctx.offset,
        location_ctx.offset + total_consumed,
      )

      Some(
        (
          total_consumed,
          Ok(
            LocatedTokenOrLineJump::LocatedN3Token(
              LocatedN3Token::new(
                N3Token::PrefixedName(
                  prefix=pn_prefix,
                  localx~,
                  might_be_invalid_iri~,
                ),
                range,
              ),
            ),
          ),
        ),
      )
    }
    Some((consumed, Err(e))) => Some((consumed + i, Err(e)))
    None => None
  }
}

///|
fn RdfLexer::recognize_variable(
  self : RdfLexer,
  data : ArrayView[Byte],
  is_ending : Bool,
  location_ctx : SourcePos,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
  if data.is_empty() || data[0] != b'?' {
    return None
  }

  // 修复：对 Option 类型进行模式匹配
  // 传递 ? 之后的起始位置
  match
    self.recognize_optional_pn_local(
      data[1:],
      is_ending,
      location_ctx.offset + 1,
    ) {
    Some((consumed, name_result)) => {
      let total_consumed = consumed + 1

      let token_result = match name_result {
        Ok((name, _)) if !name.is_empty() =>
          Ok(
            LocatedTokenOrLineJump::LocatedN3Token(
              LocatedN3Token::new(
                N3Token::Variable(name),
                Range(location_ctx.offset, location_ctx.offset + total_consumed),
              ),
            ),
          )
        Ok((_name, _)) =>
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:total_consumed],
              Range(location_ctx.offset, location_ctx.offset + total_consumed),
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
  start_offset : Int, // 接收起始全局偏移量
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
                          Range(start_offset + i - 2, start_offset + i),
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
                          Range(start_offset + i, start_offset + i + 1),
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
                          Range(
                            start_offset + position_that_is_already_in_buffer,
                            start_offset + i - 1,
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
                  Range(
                    start_offset + position_that_is_already_in_buffer,
                    start_offset + i,
                  ),
                ) {
                Ok(data_str) => buffer_val.write_stringview(data_str)
                Err(e) => return Some((i, Err(e)))
              }
              let mut res_str = buffer_val.to_string()
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
                str_from_utf8(data[:i], Range(start_offset, start_offset + i)) {
                Ok(d) => d
                Err(e) => return Some((i, Err(e)))
              }
              data_str = data_str[:data_str.length() - ends_with_unescaped_dot].to_owned()
              i -= ends_with_unescaped_dot
              data_str
            }
            return Some((i, Ok((result, might_be_invalid_iri))))
          }
        Err(e) => return Some((e.range().end - start_offset, Err(e)))
      }
    } else if is_ending {
      let result = if buffer is Some(buffer_val) {
        if i - position_that_is_already_in_buffer > 0 {
          match
            str_from_utf8(
              data[position_that_is_already_in_buffer:i],
              Range(
                start_offset + position_that_is_already_in_buffer,
                start_offset + i,
              ),
            ) {
            Ok(data_str) => buffer_val.write_stringview(data_str)
            Err(e) => return Some((i, Err(e)))
          }
        }
        let mut res_str = buffer_val.to_string()
        while res_str.has_suffix(".") {
          let len = res_str.length()
          res_str = res_str[:len - 1].to_owned()
          i -= 1
        }
        res_str
      } else {
        let mut data_str = match
          str_from_utf8(data[:i], Range(start_offset, start_offset + i)) {
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
  location_ctx : SourcePos,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
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
                      Range(location_ctx.offset, location_ctx.offset + i),
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
                    str_from_utf8(
                      data[2:i],
                      Range(location_ctx.offset + 2, location_ctx.offset + i),
                    ).map(s => {
                      LocatedTokenOrLineJump::LocatedN3Token(
                        LocatedN3Token::new(
                          N3Token::BlankNodeLabel(s),
                          Range(
                            location_ctx.offset + 2,
                            location_ctx.offset + i,
                          ),
                        ),
                      )
                    }),
                  ),
                )
              }
            } else if data[i - 1] == b'.' {
              i -= 1
              return Some(
                (
                  i,
                  str_from_utf8(
                    data[2:i],
                    Range(location_ctx.offset + 2, location_ctx.offset + i),
                  ).map(s => {
                    LocatedTokenOrLineJump::LocatedN3Token(
                      LocatedN3Token::new(
                        N3Token::BlankNodeLabel(s),
                        Range(location_ctx.offset + 2, location_ctx.offset + i),
                      ),
                    )
                  }),
                ),
              )
            } else {
              return Some(
                (
                  i,
                  str_from_utf8(
                    data[2:i],
                    Range(location_ctx.offset + 2, location_ctx.offset + i),
                  ).map(s => {
                    LocatedTokenOrLineJump::LocatedN3Token(
                      LocatedN3Token::new(
                        N3Token::BlankNodeLabel(s),
                        Range(location_ctx.offset + 2, location_ctx.offset + i),
                      ),
                    )
                  }),
                ),
              )
            }
            i += consumed
          }
          Err(e) => return Some((e.range().end - location_ctx.offset, Err(e)))
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
          str_from_utf8(
            data[2:i],
            Range(location_ctx.offset + 2, location_ctx.offset + i),
          ).map(s => {
            LocatedTokenOrLineJump::LocatedN3Token(
              LocatedN3Token::new(
                N3Token::BlankNodeLabel(s),
                Range(location_ctx.offset + 2, location_ctx.offset + i),
              ),
            )
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
              Range(location_ctx.offset, location_ctx.offset + i),
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
  location_ctx : SourcePos,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
  let mut is_last_block_empty = true
  let mut are_digits_allowed = false
  let mut last_valid_index = 1

  for _item in data[1:].iter2() {
    let (i, c) = _item
    if (are_digits_allowed && is_ascii_alphanumeric(Byte::to_char(c))) ||
      (!are_digits_allowed && Byte::to_char(c).is_ascii_alphabetic()) {
      is_last_block_empty = false
      last_valid_index = i + 2
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
          i + 1,
          self.parse_lang_tag(
            data[1:i + 1].to_owned(),
            None,
            Range(location_ctx.offset + 1, location_ctx.offset + i + 1),
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
          Range(location_ctx.offset + 1, location_ctx.offset + last_valid_index),
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
) -> Result[LocatedTokenOrLineJump, TokenRecognizerError] {
  let lang_str_result = str_from_utf8(lang_tag, position)

  let parsed_lang = match lang_str_result {
    Err(e) =>
      Err(
        TokenRecognizerError::InvalidErrMessage(
          lang_tag[position.start:position.end],
          position,
          e.to_string(),
        ),
      )
    Ok(lang_str) =>
      if self.lenient {
        Ok(lang_str)
      } else {
        LanguageTag::parse(lang_str)
        .map(fn(tag) { tag.to_string() })
        .map_err(fn(e) {
          TokenRecognizerError::InvalidErrMessage(
            lang_tag[position.start:position.end],
            position,
            e.to_string(),
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
                Range(position.end - dir_bytes.length(), position.end),
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
            LocatedTokenOrLineJump::LocatedN3Token(
              LocatedN3Token::new(
                N3Token::LangTag(language=lang_str, direction=dir_opt),
                Range(position.start, position.end),
              ),
            ),
          )
      }
    }
  }
}

///|
fn RdfLexer::recognize_string(
  self : RdfLexer,
  data : ArrayView[Byte],
  delimiter : Byte,
  is_ending : Bool,
  location_ctx : SourcePos,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
  let string = StringBuilder::new()
  let mut i = 1

  for ;; {
    // 1. 查找下一个定界符或反斜杠
    let end_opt = array_view_memchr2(delimiter, b'\\', data[i:])

    let mut end = match end_opt {
      Some(e) => e
      None =>
        if is_ending {
          return Some(
            (
              data.length(),
              Err(
                TokenRecognizerError::UnexpectedEndOfInput(
                  data[i:],
                  Range(
                    location_ctx.offset + i,
                    location_ctx.offset + data.length(),
                  ),
                ),
              ),
            ),
          )
        } else {
          return None
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
    match
      str_from_utf8(
        data[i:i + end],
        Range(location_ctx.offset + i, location_ctx.offset + i + end),
      ) {
      Ok(s) => string.write_string(s)
      Err(e) => return Some((i + end, Err(e)))
    }
    i += end

    if i >= data.length() {
      return None
    }

    match data[i] {
      c if c == delimiter =>
        // 遇到定界符，字符串结束
        return Some(
          (
            i + 1,
            Ok(
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token::new(
                  N3Token::String(string.to_string()),
                  Range(location_ctx.offset, location_ctx.offset + i + 1),
                ),
              ),
            ),
          ),
        )
      b'\\' => {
        // 遇到反斜杠，处理转义序列
        let escape_result = self.recognize_escape(
          data[i:],
          location_ctx.offset + i,
          true,
        )

        match escape_result {
          Some((additional, c_result)) => {
            i += additional + 1
            if i > data.length() {
              return None
            }
            match c_result {
              Ok(c) => string.write_char(c)
              Err(e) => {
                let end_opt = array_view_memchr(delimiter, data[i:])
                let final_end = match end_opt {
                  Some(e) => i + e + 1
                  None => data.length()
                }
                return Some((final_end, Err(e)))
              }
            }
          }
          None => return None
        }
      }
      b'\n' | b'\r' => {
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
                Range(location_ctx.offset + i, location_ctx.offset + i + 1),
                "Line jumps are not allowed in string literals, use \\n",
              ),
            ),
          ),
        )
      }
      _ =>
        return Some(
          (
            i + 1,
            Err(
              TokenRecognizerError::InvalidErrMessage(
                data[i:i + 1],
                Range(location_ctx.offset + i, location_ctx.offset + i + 1),
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
  location_ctx : SourcePos,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
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
                  Range(
                    location_ctx.offset + i,
                    location_ctx.offset + data.length(),
                  ),
                ),
              ),
            ),
          )
        } else {
          return None
        }
    }

    if !self.lenient {
      if array_view_memchr2(b'\n', b'\r', data[i:i + end])
        is Some(line_jump_end) {
        end = line_jump_end
      }
    }

    match
      str_from_utf8(
        data[i:i + end],
        Range(location_ctx.offset + i, location_ctx.offset + i + end),
      ) {
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
                LocatedTokenOrLineJump::LocatedN3Token(
                  LocatedN3Token::new(
                    N3Token::LongString(string.to_string()),
                    Range(location_ctx.offset, location_ctx.offset + i + 3),
                  ),
                ),
              ),
            ),
          )
        }
        i += 1
        string.write_char(Byte::to_char(delimiter))
      }
      b'\'' =>
        match self.recognize_escape(data[i:], location_ctx.offset + i, true) {
          Some((additional, c_result)) => {
            i += additional + 1
            if i > data.length() {
              return None
            }
            match c_result {
              Ok(c) => string.write_char(c)
              Err(e) => return Some((i, Err(e)))
            }
          }
          None => return None
        }
      _ =>
        return Some(
          (
            i + 1,
            Err(
              TokenRecognizerError::InvalidErrMessage(
                data[i:i + 1],
                Range(location_ctx.offset + i, location_ctx.offset + i + 1),
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
  location_ctx : SourcePos,
) -> (Int, Result[LocatedTokenOrLineJump, TokenRecognizerError])? {
  let mut i = 0
  match data.get(0) {
    Some(c) => if c == b'+' || c == b'-' { i += 1 }
    None => return None
  }
  let count_before = match RdfLexer::recognize_digits(data[i:], is_ending) {
    Some(count) => count
    None => return None
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
      None => return None
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
      None => return None
    }
    i += count_exp
    Some(
      (
        i,
        if count_exp == 0 {
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:i],
              Range(location_ctx.offset, location_ctx.offset + i),
              "A double exponent cannot be empty",
            ),
          )
        } else if count_before == 0 && count_after.unwrap_or(0) == 0 {
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[0:i],
              Range(location_ctx.offset, location_ctx.offset + i),
              "A double should not be empty",
            ),
          )
        } else {
          str_from_utf8(
            data[:i],
            Range(location_ctx.offset, location_ctx.offset + i),
          ).map(s => {
            LocatedTokenOrLineJump::LocatedN3Token(
              LocatedN3Token::new(
                N3Token::Double(s),
                Range(location_ctx.offset, location_ctx.offset + i),
              ),
            )
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
                Range(location_ctx.offset, location_ctx.offset + i),
                "An integer should not be empty",
              ),
            )
          } else {
            str_from_utf8(
              data[:i],
              Range(location_ctx.offset, location_ctx.offset + i),
            ).map(s => {
              LocatedTokenOrLineJump::LocatedN3Token(
                LocatedN3Token::new(
                  N3Token::Integer(s),
                  Range(location_ctx.offset, location_ctx.offset + i),
                ),
              )
            })
          },
        ),
      )
    } else {
      Some(
        (
          i,
          str_from_utf8(
            data[:i],
            Range(location_ctx.offset, location_ctx.offset + i),
          ).map(s => {
            LocatedTokenOrLineJump::LocatedN3Token(
              LocatedN3Token::new(
                N3Token::Decimal(s),
                Range(location_ctx.offset, location_ctx.offset + i),
              ),
            )
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
              Range(location_ctx.offset, location_ctx.offset + i),
              "An integer should not be empty",
            ),
          )
        } else {
          str_from_utf8(
            data[:i],
            Range(location_ctx.offset, location_ctx.offset + i),
          ).map(s => {
            LocatedTokenOrLineJump::LocatedN3Token(
              LocatedN3Token::new(
                N3Token::Integer(s),
                Range(location_ctx.offset, location_ctx.offset + i),
              ),
            )
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
  position : Int, // 全局起始位置
  with_echar : Bool,
) -> (Int, Result[Char, TokenRecognizerError])? {
  match data.get(1) {
    Some(b'u') =>
      match RdfLexer::recognize_hex_char(data[2:], 4, 'u', position) {
        Ok(Some(c)) => Some((5, Ok(c)))
        Ok(None) => None
        Err(e) =>
          if self.lenient {
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
      match RdfLexer::recognize_hex_char(data[2:], 8, 'U', position) {
        Ok(Some(c)) => Some((9, Ok(c)))
        Ok(None) => None
        Err(e) => Some((9, Err(e)))
      }
    Some(b't') if with_echar => Some((1, Ok('\t')))
    Some(b'b') if with_echar => Some((1, Ok('\u{0008}')))
    Some(b'n') if with_echar => Some((1, Ok('\n')))
    Some(b'r') if with_echar => Some((1, Ok('\r')))
    Some(b'f') if with_echar => Some((1, Ok('\u{000C}')))
    Some(b'"') if with_echar => Some((1, Ok('"')))
    Some(b'\'') if with_echar => Some((1, Ok('\'')))
    Some(b'\\') if with_echar => Some((1, Ok('\\')))
    Some(c) =>
      Some(
        (
          1,
          Err(
            TokenRecognizerError::InvalidErrMessage(
              data[1:2],
              Range(position + 1, position + 2),
              "Unexpected escape character \{c}",
            ),
          ),
        ),
      )
    None => None
  }
}

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
                Range(position + i + 2, position + i + 3),
                "The escape sequence '\{escape_char}\{val}' is not a valid hexadecimal string",
              ),
            )
          }
        },
      )
  }
  let c = Int::unsafe_to_char(codepoint)
  Ok(Some(c))
}

///|
fn RdfLexer::recognize_utf16_surrogate_pair(
  data : ArrayView[Byte],
  position : Int,
) -> Result[Char?, TokenRecognizerError] {
  if data.length() < 12 {
    return Ok(None)
  }

  let val_high_bytes = data[2:6]
  let val_high = match
    str_from_utf8(val_high_bytes, Range(position + 2, position + 6)) {
    Ok(s) => s
    Err(e) => return Err(e)
  }

  let surrogate_high = match from_str_radix(val_high, 16) {
    Ok(v) => v
    Err(_) =>
      return Err(
        TokenRecognizerError::InvalidErrMessage(
          val_high_bytes,
          Range(position + 2, position + 6),
          "The escape sequence '\\u{val_high}' is not a valid hexadecimal string",
        ),
      )
  }

  if !(surrogate_high >= 0xD800 && surrogate_high <= 0xDBFF) {
    return Err(
      TokenRecognizerError::InvalidErrMessage(
        val_high_bytes,
        Range(position + 2, position + 6),
        "The escape sequence '\\u{val_high}' is not a UTF-16 high surrogate",
      ),
    )
  }

  if data[6] != b'\\' || data[7] != b'u' {
    return Err(
      TokenRecognizerError::InvalidErrMessage(
        data[6:8],
        Range(position + 6, position + 8),
        "UTF-16 surrogate escape sequence must be followed by another surrogate escape sequence '\\u'",
      ),
    )
  }

  let val_low_bytes = data[8:12]
  let val_low = match
    str_from_utf8(val_low_bytes, Range(position + 8, position + 12)) {
    Ok(s) => s
    Err(e) => return Err(e)
  }

  let surrogate_low = match from_str_radix(val_low, 16) {
    Ok(v) => v
    Err(_) =>
      return Err(
        TokenRecognizerError::InvalidErrMessage(
          val_low_bytes,
          Range(position + 8, position + 12),
          "The escape sequence '\\u\{val_low}' is not a valid hexadecimal string",
        ),
      )
  }

  if !(surrogate_low >= 0xDC00 && surrogate_low <= 0xDFFF) {
    return Err(
      TokenRecognizerError::InvalidErrMessage(
        val_low_bytes,
        Range(position + 8, position + 12),
        "The escape sequence '\\u\{val_low}' is not a UTF-16 low surrogate",
      ),
    )
  }

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
          Range(position + 2, position + 12),
          "Escape sequences do not form a valid Unicode character",
        ),
      )
  }
}

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
    None => return None
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
            Range(position, position + 1),
            "Invalid UTF-8 character encoding",
          ),
        ),
      )
  }
  for i in 1..<=bytes_needed {
    let next_byte = match data.get(i) {
      Some(b) => b
      None => return None
    }
    if next_byte < Int::to_byte(lower_boundary) ||
      upper_boundary < Byte::to_int(byte) {
      return Some(
        Err(
          TokenRecognizerError::InvalidErrMessage(
            data[position:position + i],
            Range(position, position + i),
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
      let error_range = Range(position, position + bytes_needed)
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
          Range(error_start, error_end),
          "Invalid UTF-8 sequence",
        ),
      )
    }
  }

  s
}

///|
fn string_from_utf8(
  data : Array[Byte],
  range : Range,
) -> Result[String, TokenRecognizerError] {
  str_from_utf8(data[:], range)
}
