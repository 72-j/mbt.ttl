///|
using @fs {type File}

///|
pub using @ref {type Ref}

///|
pub type IriParser[A] = @parserc.Parser[Char, Result[A, IriError]]

///|
pub type ResParser[A] = (Result[A, IriError], @parserc.Seq[Char])?
