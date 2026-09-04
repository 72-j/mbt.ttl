///|
struct Range {
  start : Int
  end : Int
} derive(Debug, Default, Eq)

///|
fn Range::Range(start : Int, end : Int) -> Range {
  { start, end, }
}

///|
enum BaseDirection {
  Ltr
  Rtl
} derive(Eq, Debug, Hash, ToJson)

///|
impl Show for BaseDirection with fn output(self : BaseDirection, f : &Logger) -> Unit {
  match self {
    BaseDirection::Ltr => f.write("ltr")
    BaseDirection::Rtl => f.write("rtl")
  }
}
