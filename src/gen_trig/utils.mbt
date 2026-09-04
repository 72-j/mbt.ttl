// utils.mbt - stubbed (original had tempo dependency issues)

///|
pub fn is_pchar(c : Char) -> Bool {
  c.is_ascii_alphabetic() ||
  c.is_ascii_digit() ||
  c == ':' ||
  c == '@' ||
  c == '&' ||
  c == '=' ||
  c == '+' ||
  c == '$' ||
  c == ',' ||
  c == ';' ||
  c == '-' ||
  c == '.' ||
  c == '_' ||
  c == '~'
}

///|
pub fn is_unreserved(c : Char) -> Bool {
  c.is_ascii_alphabetic() ||
  c.is_ascii_digit() ||
  c == '-' ||
  c == '.' ||
  c == '_' ||
  c == '~'
}

///|
pub fn is_valid_hex_string(hex : String) -> Bool {
  for c in hex {
    if !((c >= '0' && c <= '9') ||
      (c >= 'A' && c <= 'F') ||
      (c >= 'a' && c <= 'f')) {
      return false
    }
  }
  true
}

///|
pub fn from_str_radix(s : String, radix : Int) -> Result[Int, String] {
  if s.is_empty() {
    return Err("Empty string")
  }
  if radix < 2 || radix > 36 {
    return Err("Invalid radix")
  }
  let mut result = 0
  for c in s {
    let digit = match c {
      '0'..='9' => Char::to_int(c) - Char::to_int('0')
      'a'..='z' => Char::to_int(c) - Char::to_int('a') + 10
      'A'..='Z' => Char::to_int(c) - Char::to_int('A') + 10
      _ => return Err("Invalid character")
    }
    if digit >= radix {
      return Err("Digit out of range")
    }
    result = result * radix + digit
  }
  Ok(result)
}

///|
pub fn array_to_view(arr : ArrayView[Byte]) -> BytesView {
  let bytes : Bytes = Bytes::from_array(arr)
  return bytes
}
