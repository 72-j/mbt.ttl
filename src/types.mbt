///|
type Decimal = StringView

///|
pub type Event = LocatedTokenOrLineJump

///|
pub type Ctx = RdfContext

///|
pub type O = RdfOut

///|
using @io {trait Reader}

///|
using @io {trait Writer, type BufferedWriter}

///|
using @fs {type File}

///|
pub using @ref {type Ref}

///|
using @string {trait FromStr}

///|
type CharMatch = Array[Char]

///|
type CharMatchRule = (Char, Char?)
