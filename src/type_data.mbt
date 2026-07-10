///|
pub(all) enum VarDataType {
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
} derive(Debug, Eq, Hash, ToJson)

///|
pub impl Show for VarDataType with fn output(
  self : VarDataType,
  logger : &Logger,
) -> Unit {
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
