
pub type IriRef[T] = Iri[T]
pub type Read = &@io.Reader
pub trait RangeView {
  view(self : Self,e: BytesView) -> StringView
}
impl RangeView for Range with view(self : Range, e: BytesView) -> StringView {

  let safe_start = Int::min(self.start, e.length())
  let safe_end = Int::min(self.end, e.length())
  @debug.to_string(e[safe_start:safe_end].to_array())
}

// pub trait LangTagView {
//   to_ascii_lowercase(self : Self) -> String
//   to_ascii_uppercase(self : Self) -> String
//   is_ascii_alphabetic(self : Self) -> Bool
//   unsafe_iter(self : Self) -> Iter[Char]
//   is_ascii_digitic(self : Self) -> Bool
// is_ascii_alphanumeric(self : Self) -> Bool
// }

///|
// pub trait IriOutput {
//   push(self : Self, c : Char) -> Int
//   clear(self : Self) -> Int
//   length(self : Self) -> Int
//   write_string(self : Self, s : StringView) -> StringView
// }

///|
// impl IriOutput for String with push(self : String, c : Char) -> Int {
//   self.length() + c.utf16_len()
// }

// ///|
// impl IriOutput for String with clear(self : String) -> Int {
//   ""
// }

// ///|
// impl IriOutput for String with length(self : String) -> Int {
//   self.length()
// }

// ///|
// impl IriOutput for String with write_string(self : String, s : StringView) -> StringView {
//   self + s.to_owned()
// }

// impl IriOutput for VoidOutputBuffer with push(self : VoidOutputBuffer, c : Char) -> VoidOutputBuffer {
//   self+ c.to_string()
// }
// impl IriOutput for VoidOutputBuffer with clear(self : VoidOutputBuffer) -> Int {
//   self.len = 0
// }
// impl IriOutput for VoidOutputBuffer with length(self : VoidOutputBuffer) -> Int {
//   self.len
// }

// impl IriOutput for VoidOutputBuffer with write_string(self : VoidOutputBuffer, s : StringView) -> StringView {
//     self + s.to_owned()

// }

pub trait IriOutput {
  push(Self, c : Char) -> Unit
  push_str(Self, s : String) -> Unit
  clear(Self) -> Unit
  truncate(Self, new_len : Int) -> Unit
  len(Self) -> Int
  as_str(Self) -> String
}

///|
impl IriOutput for VoidOutputBuffer with push(self : VoidOutputBuffer, c : Char) -> Unit {
  self.len += c.utf16_len()
}

///|
impl IriOutput for VoidOutputBuffer with push_str(
  self : VoidOutputBuffer,
  s : String,
) -> Unit {
  self.len += s.length()
}

///|
impl IriOutput for VoidOutputBuffer with clear(self : VoidOutputBuffer) -> Unit {
  self.len = 0
}

///|
impl IriOutput for VoidOutputBuffer with truncate(
  self : VoidOutputBuffer,
  new_len : Int,
) -> Unit {
  self.len = new_len
}

///|
impl IriOutput for VoidOutputBuffer with len(self : VoidOutputBuffer) -> Int {
  self.len
}

///|
impl IriOutput for VoidOutputBuffer with as_str(self : VoidOutputBuffer) -> String {
  ""
}

///|
// impl IriOutput for Array[Char] with push(self : Array[Char], c : Char) -> Unit {
//   self.push(c)
// }

// ///|
// impl IriOutput for Array[Char] with push_str(self : Array[Char], s : String) -> Unit {
//   String::iter(s).each(c => self.push(c))
// }

// ///|
// impl IriOutput for Array[Char] with clear(self : Array[Char]) -> Unit {
//   self.clear()
// }

// ///|
// impl IriOutput for Array[Char] with truncate(self : Array[Char], new_len : Int) -> Unit {
//   self.truncate(new_len)
// }

// ///|
// impl IriOutput for Array[Char] with len(self : Array[Char]) -> Int {
//   self.length()
// }

// ///|
// impl IriOutput for Array[Char] with as_str(self : Array[Char]) -> String {
//   String::from_iter(self.iter())
// }

impl IriOutput for StringBuilder with push(self : StringBuilder, c : Char) -> Unit {
  self.write_char(c)
}

///|
impl IriOutput for StringBuilder with push_str(self : StringBuilder, s : String) -> Unit {
  StringBuilder::write_stringview(self, s)
}

///|
impl IriOutput for StringBuilder with clear(self : StringBuilder) -> Unit {
  self.reset()
}

///|
impl IriOutput for StringBuilder with truncate(
  self : StringBuilder,
  new_len : Int,
) -> Unit {
  if new_len == 0 {
    self.reset()
  }
}

///|
impl IriOutput for StringBuilder with len(self : StringBuilder) -> Int {
  StringBuilder::to_string(self).length()
}

///|
impl IriOutput for StringBuilder with as_str(self : StringBuilder) -> String {
  StringBuilder::to_string(self)
}

///|
pub trait IriInput {
  to_string(self : Self) -> String
  len(self : Self) -> Int
  // char_at(self : Self, index : Int) -> Char
  substring(self : Self, start : Int, end : Int) -> StringView
}

///|
impl IriInput for String with to_string(self : String) -> String {
  self
}

///|
impl IriInput for String with len(self : String) -> Int {
  self.length()
}
// impl IriInput for String with char_at(self : String, index : Int) -> Char {
//   self[index]
// }

///|
impl IriInput for String with substring(self : String, start : Int, end : Int) -> StringView {
  self[start:end]
}

///|
pub trait IriView {
  /// 获取从 start 到 end 的子视图
  view(self : Self, start : Int, end : Int) -> StringView

  /// 获取总长度（用于边界检查）
  len(self : Self) -> Int

  /// 可选：获取起始偏移量，如果底层是 StringView 切片时很有用
  start_offset(self : Self) -> Int
}

///|
pub impl IriView for String with view(self : String, start : Int, end : Int) -> StringView {
  self[start:end]
}

///|
pub impl IriView for String with len(self : String) -> Int {
  self.length()
}

///|
pub impl IriView for String with start_offset(self : String) -> Int {
  0
}

///|
impl IriView for StringView with view(self : StringView, start : Int, end : Int) -> StringView {
  // StringView 的 view 方法也是返回 StringView，保持零拷贝
  self[start:end]
}

///|
impl IriView for StringView with len(self : StringView) -> Int {
  self.length()
}

///|
impl IriView for StringView with start_offset(self : StringView) -> Int {
  self.start_offset()
}
