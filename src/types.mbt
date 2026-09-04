///|
using @fs {type File}

///|
pub using @ref {type Ref}
///|
pub const MIN_BUFFER_SIZE : Int = 4096

///|
pub const MAX_BUFFER_SIZE : Int = 4096 * 4096

///|
// pub using @utf8 {type Bytes}

///|
pub fn from_bytes(data : Bytes) -> Array[Byte] {
  data.to_array()
}

///|
pub const MIN_PARALLEL_CHUNK_SIZE : Int = 16384

// ///|
// pub type IriParser[A] = @parserc.Parser[Char, Result[A, IriError]]

// ///|
// pub type ResParser[A] = (Result[A, IriError], @parserc.Seq[Char])?
