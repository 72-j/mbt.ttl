///|
extend BlankNode with Show::{to_string}

///|
extend BlankNodeRef with Show::{to_string}

///|
extend NamedNode with Show::{to_string}

///|
extend GraphName with Show::{to_string}

///|
extend Quad with Show::{to_string}

///|
extend NQuadsState with Show::{to_string}

///|
// extend N3State with Show::{to_string}

///|
extend SourcePos with Show::{to_string}

///|
type Decimal = StringView

///|
pub type Event = LocatedToken

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
// using @string {trait FromStr}

///|
// type CharMatch = Array[Char]

///|
// type CharMatchRule = (Char, Char?)
// ===== 定义 Result 类型 =====

pub type TransitionResult[TR, S, O] = Result[(TR, S, O), RuleRecognizerError]
