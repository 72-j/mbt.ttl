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
using @io {trait Writer, type BufferedWriter}

///|
using @fs {type File}

///|
// type BuffeWriter = @io.BufferedWriter[&Writer]

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
  IntVar(String)
  IntegerVar(String)
  DoubleVar(String)
  // FloatVar(Float)
  StringVar(String)
  FalseVar
  TrueVar
  // UIntVar(UInt)
  DecimalVar(Decimal)
  DateVar(String)
  TimeVar(String)
  DateTimeVar(String)
  DurationVar(String)
} derive(Debug, Eq, Hash)

///|
impl Show for VarDataType with fn output(self : VarDataType, logger : &Logger) -> Unit {
  match self {
    IntVar(i) => logger.write(i)
    IntegerVar(i) => logger.write(i)
    DoubleVar(d) => logger.write(d)
    DecimalVar(d) => logger.write(d) // 假设 Decimal (StringView) 可直接写入或需转换
    StringVar(s) => logger.write(s)
    TrueVar => logger.write("true")
    FalseVar => logger.write("false")
    DateVar(v) => logger.write(v)
    TimeVar(v) => logger.write(v)
    DateTimeVar(v) => logger.write(v)
    DurationVar(v) => logger.write(v)
  }
}

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
    IntVar(value) => value
    IntegerVar(value) => value
    DoubleVar(value) => value
    DecimalVar(value) => value.to_owned()
    StringVar(value) => value
    TrueVar => "true"
    FalseVar => "false"
    DateVar(value) => value
    TimeVar(value) => value
    DateTimeVar(value) => value
    DurationVar(value) => value
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
//   fn as_ctx(self : Self) -> RdfContext 
// }

///|
// impl AsEnumContext for RdfContext with fn as_ctx(self : RdfContext ) -> RdfContext {
//   match self {
//     TriGRecognizerContext(c) => TriGRecognizerContext(c)
//     NQuadsRecognizerContext(c) => NQuadsRecognizerContext(c)
//   }
// }
