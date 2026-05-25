// type Read= &@io.Reader
using @io{trait Reader}
using @io{trait Writer}
///|
type CharMatch = Array[Char]

///|
type CharMatchRule = (Char, Char?)

///|
// type IriRef = Iri[String]
type BlankNodeRef= BlankNode
// type NamedNodeRef= NamedNode
// type NamedOrBlankNode

type Triple
type Literal
type LiteralRef