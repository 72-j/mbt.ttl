// type Read= &@io.Reader

///|
using @io {trait Reader}

///|
using @io {trait Writer}
using @string {trait FromStr}

///|
type CharMatch = Array[Char]

///|
type CharMatchRule = (Char, Char?)

///|
type NamedOrBlankNodeRef = NamedOrBlankNode

///|
type NamedNodeRef = NamedNode

///|
type BlankNodeRef = BlankNode

///|
type QuadRef = Quad

///|
type GraphNameRef = GraphName

///|
type Triple

///|
enum VarDataType {
  IntVar(Int)
  FloatVar(Float)
  StringVar(String)
  FalseVar
  TrueVar
  UIntVar(UInt)
  // DecimalVar(Decimal)
} derive(Debug, Hash, Eq)
// fn VarDataType::into_var(self : VarDataType) -> String {
//   match self {
//     IntVar(i) => i
//     FloatVar(f) => FloatVar(f)
//     StringVar(s) => StringVar(s)
//     TrueVar(b) => TrueVar(b)
//     FalseVar(b) => FalseVar(b)
//     UIntVar(u) => UIntVar(u)
//   }
// }

///|
impl Show for VarDataType with fn to_string(self : VarDataType) -> String {
  match self {
    IntVar(i) => i.to_string()
    FloatVar(f) => f.to_string()
    StringVar(s) => s
    TrueVar => "true"
    FalseVar => "false"
    UIntVar(u) => u.to_string()
  }
}

///|
// trait IntoValue {
//   fn into_value(self : Self) -> Literal
// }

///|
// impl IntoValue for LiteralContent with fn into_value(self : LiteralContent) -> Literal {
//   match self {
//     String(s) => Literal(LiteralContent::String(s))
//     LanguageTaggedString(value~, language~) => Literal(LiteralContent::LanguageTaggedString(value~, language~))
//     DirectionalLanguageTaggedString(value~, language~, direction~) => Literal(LiteralContent::DirectionalLanguageTaggedString(value~, language~, direction~))
//     TypedLiteral(value~, ..) =>
//       match value {
//         VarDataType::BoolVar(_) =>  Literal(LiteralContent::TypedLiteral(value="Bool", datatype=lwBOOLEAN.into_owned()))
//       }
//   }
// }
