// type Read= &@io.Reader

// type TriGRecognizerContext

///|
// type NQuadsRecognizerContext
type Decimal = StringView

///|
// using @string {parse_double}

///|
using @io {trait Reader}

///|
using @io {trait Writer}

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

///|
enum VarDataType {
  IntVar(Int)
  DoubleVar(Double)
  // FloatVar(Float)
  StringVar(StringView)
  FalseVar
  TrueVar
  // UIntVar(UInt)
  DecimalVar(Decimal)
} derive(Debug, Eq, Hash)

///|
// fn VarDataType::to_type(self : VarDataType) -> String {
//   match self {
//     IntVar(i) => i.to_string()
//     DoubleVar(d) => d.to_string()
//     DecimalVar(d) => d.to_owned()
//     // FloatVar(f) => f.to_string()
//     StringVar(s) => s.to_owned()
//     TrueVar => "true"
//     FalseVar => "false"
//     // UIntVar(u) => u.to_string()
//   }
// }

///|
fn VarDataType::into_value(self : VarDataType) -> String {
  match self {
    IntVar(value) => value.to_string()
    DoubleVar(value) => value.to_string()
    DecimalVar(value) => value.to_owned()
    StringVar(value) => value.to_owned()
    TrueVar => "true"
    FalseVar => "false"
  }
}

// fn VarDataType::new(value: String, data_type:VarDataType ) -> VarDataType {
//   match (data_type, value) {
//     (TrueVar, _) => TrueVar
//     (FalseVar, _) => FalseVar
//     (StringVar(_), value) => StringVar(value)
//     (DoubleVar(_), value) => {
//       let value =try? @string.parse_double(value)
//       match value {
//         Ok(value) => DoubleVar(value)
//         Err(_) => StringVar("")
//       }
//     }
//     (IntVar(_), value) => {
//       let value = try? @string.parse_int(value)
//      match value {
//       Ok(value) => IntVar(value)
//       Err(_) => StringVar("")
//      }
//     }
//     (DecimalVar(_), value) => {
//       let value = try? @string.parse_double(value)
//       match value {
//         Ok(value) => DecimalVar(value.to_string())
//         Err(_) => StringVar("")
//       }
//     }
//     // IntVar(_) => ...
//     // DecimalVar(_) => ...
//   }
// }

///|
// fn VarDataType::from_name_node(data_type : NamedNode) -> VarDataType {
//   match data_type {
//     lwINT => IntVar(0)
//     lwFLOAT => DoubleVar(0.0)
//     lwDECIMAL => DecimalVar("")
//     lwSTRING => StringVar("")
//   }
// }

// trait Into {
//   fn into() -> Self
// }

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

// trait AsEnumContext {
//   fn as_ctx(self : Self) -> Context
// }

///|
// impl AsEnumContext for Context with fn as_ctx(self : Context) -> Context {
//   match self {
//     TriGRecognizerContext(c) => TriGRecognizerContext(c)
//     NQuadsRecognizerContext(c) => NQuadsRecognizerContext(c)
//   }
// }
