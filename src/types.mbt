// type Read= &@io.Reader

type Decimal = StringView
///|
pub type Event = LocatedTokenOrLineJump
pub type Ctx = RdfContext
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

///|
// type NamedOrBlankNodeRef = NamedOrBlankNode

///|
// type NamedNodeRef = NamedNode

///|
// type BlankNodeRef = BlankNode

///|
// type QuadRef = Quad

///|
// type GraphNameRef = GraphName

///|
// type TermRef = Term

///|
// type Triple
