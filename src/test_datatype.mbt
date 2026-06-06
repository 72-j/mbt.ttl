test "VarDataType: IntVar" {
  let int_val = IntVar(42)
  assert_eq(int_val, IntVar(42))
  
  // 测试匹配
  match int_val {
    IntVar(v) => assert_eq(v, 42)
    _ => fail("Expected IntVar")
  }
}

test "VarDataType: IntegerVar (Int64)" {
  let large_int = IntegerVar(9223372036854775807L)
  assert_eq(large_int, IntegerVar(9223372036854775807L))
  
  match large_int {
    IntegerVar(v) => assert_eq(v, 9223372036854775807L)
    _ => fail("Expected IntegerVar")
  }
}

test "VarDataType: DoubleVar" {
  let double_val = DoubleVar(3.14159)
  assert_eq(double_val, DoubleVar(3.14159))
  assert_not_eq(double_val, DoubleVar(2.71828))
  
  match double_val {
    DoubleVar(v) => assert_eq(v, 3.14159)
    _ => fail("Expected DoubleVar")
  }
}

test "VarDataType: StringVar" {
  let string_val = StringVar("Hello RDF")
  assert_eq(string_val, StringVar("Hello RDF"))
  
  match string_val {
    StringVar(v) => assert_eq(v, "Hello RDF")
    _ => fail("Expected StringVar")
  }
}

test "VarDataType: Boolean (TrueVar/FalseVar)" {
  let true_val = TrueVar
  let false_val = FalseVar
  
  assert_eq(true_val, TrueVar)
  assert_eq(false_val, FalseVar)
  assert_not_eq(true_val, false_val)
  
  match true_val {
    TrueVar => ()
    _ => fail("Expected TrueVar")
  }
  
  match false_val {
    FalseVar => ()
    _ => fail("Expected FalseVar")
  }
}

test "VarDataType: DecimalVar" {
  let decimal_val = DecimalVar("123.456")
  assert_eq(decimal_val, DecimalVar("123.456"))
  
  match decimal_val {
    DecimalVar(v) => assert_eq(v.to_owned(), "123.456")
    _ => fail("Expected DecimalVar")
  }
}

test "VarDataType: DateVar" {
  let date_val = DateVar("2024-03-15")
  assert_eq(date_val, DateVar("2024-03-15"))
  
  match date_val {
    DateVar(v) => {
      assert_eq(v, "2024-03-15")
      // 验证格式
      // assert!(@regex.is_match(r"^\d{4}-\d{2}-\d{2}$", v))
    }
    _ => fail("Expected DateVar1")
  }
}

test "VarDataType: TimeVar" {
  let time_val = TimeVar("10:30:00")
  assert_eq(time_val, TimeVar("10:30:00"))
  
  match time_val {
    TimeVar(v) => {
      assert_eq(v, "10:30:00")

      // 验证格式
      let regex = @string.Regex("^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}$")
       guard regex.execute(v) is Some(m) else { fail("Expected match") }
         inspect(m.content(), content="10:30:00")

    }
    _ => fail("Expected TimeVar")
  }
}

test "VarDataType: DateTimeVar" {
  let datetime_val = DateTimeVar("2024-03-15T10:30:00Z")
  assert_eq(datetime_val, DateTimeVar("2024-03-15T10:30:00Z"))
  
  match datetime_val {
    DateTimeVar(v) => {
      let regex = @string.Regex("^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}T[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}Z?$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="2024-03-15T10:30:00Z")
    }
    _ => fail("Expected DateTimeVar")
  }
}

test "VarDataType: DurationVar" {
  let duration_val = DurationVar("P1DT12H")
  assert_eq(duration_val, DurationVar("P1DT12H"))
  
  match duration_val {
    DurationVar(v) => {
      let regex = @string.Regex("^P.*$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="P1DT12H")
    }
    _ => fail("Expected DurationVar")
  }
}

test "VarDataType: equality and hash" {
  let val1 = IntVar(42)
  let val2 = IntVar(42)
  let val3 = IntVar(100)
  
  assert_eq(val1, val2)
  assert_not_eq(val1, val3)
  
  // 不同类型不应相等
  let string_val = StringVar("42")
  assert_not_eq(val1, string_val)
}

test "VarDataType: pattern matching with all types" {
  let test_cases : Array[VarDataType] = [
    IntVar(42),
    IntegerVar(100L),
    DoubleVar(3.14),
    StringVar("test"),
    TrueVar,
    FalseVar,
    DecimalVar("10.99"),
    DateVar("2024-03-15"),
    TimeVar("10:30:00"),
    DateTimeVar("2024-03-15T10:30:00Z"),
    DurationVar("P1DT12H")
  ]
  
  for case in test_cases {
    match case {
      IntVar(v) => debug("Int: \{v}")
      IntegerVar(v) => debug("Integer: \{v}")
      DoubleVar(v) => debug("Double: \{v}")
      StringVar(v) => debug("String: \{v}")
      TrueVar => debug("Boolean: true")
      FalseVar => debug("Boolean: false")
      DecimalVar(v) => debug("Decimal: \{v}")
      DateVar(v) => debug("Date: \{v}")
      TimeVar(v) => debug("Time: \{v}")
      DateTimeVar(v) => debug("DateTime: \{v}")
      DurationVar(v) => debug("Duration: \{v}")
    }
  }
}

test "VarDataType: from xsd conversion" {
  // 测试从 XSD 类型转换的端到端流程
  let int_node = lwINT
  let result = int_node.into_datatype("123")
  match result {
    IntVar(v) => assert_eq(v, 123)
    _ => fail("Expected IntVar")
  }
  
  let date_node = lwDATE
  let result2 = date_node.into_datatype("2024-03-15")
  match result2 {
    DateVar(v) => assert_eq(v, "2024-03-15")
    _ => fail("Expected DateVar")
  }
  
  let duration_node = lwDURATION
  let result3 = duration_node.into_datatype("PT1H30M")
  match result3 {
    DurationVar(v) => assert_eq(v, "PT1H30M")
    _ => fail("Expected DurationVar")
  }
  
  let invalid_node = lwINT
  let result4 = invalid_node.into_datatype("not a number")
  match result4 {
    StringVar(v) => assert_eq(v, "NAN")
    _ => fail("Expected StringVar for invalid input")
  }
}

test "parse_duration simplified" {
  // 使用 match 进行简单验证
  match parse_duration("PT30M") {
    Ok(v) => debug("Pass: \{v}")
    Err(e) => fail(e)
  }
  
  match parse_duration("P1DT12H") {
    Ok(v) => debug("Pass: \{v}")
    Err(e) => fail(e)
  }
  
  debug("All duration tests passed!")
}

test "into_datatype: duration types" {
  // 假设 lwDURATION 已定义
  let duration_node = lwDURATION
  
  let result1 = duration_node.into_datatype("PT1H30M")
  match result1 {
    DurationVar(v) => assert_eq(v, "PT1H30M")
    _ => fail("Expected DurationVar1")
  }
  
  let result2 = duration_node.into_datatype("P2DT12H")
  match result2 {
    DurationVar(v) => assert_eq(v, "P2DT12H")
    _ => fail("Expected DurationVar")
  }
  
  let result3 = duration_node.into_datatype("invalid")
  debug(result3);
  match result3 {
    StringVar(v) => assert_eq(v, "NAN")
    _ => fail("Expected StringVar for invalid input")
  }
}

test "VarDataType: TimeVar validation" {
  let time_val = TimeVar("10:30:00")
  match time_val {
    TimeVar(v) => {
      let regex = @string.Regex("^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="10:30:00")
    }
    _ => fail("Expected TimeVar")
  }
}

test "VarDataType: DateVar validation" {
  let date_val = DateVar("2024-03-15")
  match date_val {
    DateVar(v) => {
      let regex = @string.Regex("^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="2024-03-15")
    }
    _ => fail("Expected DateVar")
  }
}

test "VarDataType: DateTimeVar validation" {
  let datetime_val = DateTimeVar("2024-03-15T10:30:00Z")
  match datetime_val {
    DateTimeVar(v) => {
      let regex = @string.Regex("^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}T[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}Z?$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="2024-03-15T10:30:00Z")
    }
    _ => fail("Expected DateTimeVar")
  }
}

test "VarDataType: DurationVar validation" {
  let duration_val = DurationVar("P1DT12H")
  match duration_val {
    DurationVar(v) => {
      let regex = @string.Regex("^P.*$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="P1DT12H")
    }
    _ => fail("Expected DurationVar")
  }
}

test "VarDataType: DecimalVar validation" {
  let decimal_val = DecimalVar("123.456")
  match decimal_val {
    DecimalVar(v) => {
      let s = v.to_owned()
      let regex = @string.Regex("^[[:digit:]]+\\.[[:digit:]]+$")
      guard regex.execute(s) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="123.456")
    }
    _ => fail("Expected DecimalVar")
  }
}

test "VarDataType: IntVar validation" {
  let int_val = IntVar(42)
  match int_val {
    IntVar(v) => {
      inspect(v, content="42")
    }
    _ => fail("Expected IntVar")
  }
}

test "VarDataType: IntegerVar (Int64) validation" {
  let large_int = IntegerVar(9223372036854775807L)
  match large_int {
    IntegerVar(v) => {
      inspect(v, content="9223372036854775807")
    }
    _ => fail("Expected IntegerVar")
  }
}

test "VarDataType: DoubleVar validation" {
  let double_val = DoubleVar(3.14159)
  match double_val {
    DoubleVar(v) => {
      inspect(v, content="3.14159")
    }
    _ => fail("Expected DoubleVar")
  }
}

test "VarDataType: StringVar validation" {
  let string_val = StringVar("Hello RDF")
  match string_val {
    StringVar(v) => {
      inspect(v, content="Hello RDF")
    }
    _ => fail("Expected StringVar")
  }
}

test "VarDataType: Boolean validation" {
  let true_val = TrueVar
  let false_val = FalseVar
  
  match true_val {
    TrueVar => ()
    _ => fail("Expected TrueVar")
  }
  
  match false_val {
    FalseVar => ()
    _ => fail("Expected FalseVar")
  }
  
  inspect(true_val, content=TrueVar.to_string())
  inspect(false_val, content=FalseVar.to_string())
}

test "VarDataType: equality" {
  let val1 = IntVar(42)
  let val2 = IntVar(42)
  let val3 = IntVar(100)
  
  assert_eq(val1, val2)
  assert_not_eq(val1, val3)
  
  // 不同类型不应相等
  let string_val = StringVar("42")
  assert_not_eq(val1, string_val)
  
  let time_val = TimeVar("10:30:00")
  let time_val2 = TimeVar("10:30:00")
  assert_eq(time_val, time_val2)
  
  let date_val = DateVar("2024-03-15")
  let date_val2 = DateVar("2024-03-15")
  assert_eq(date_val, date_val2)
}

test "VarDataType: pattern matching" {
  let test_cases = [
    IntVar(42),
    IntegerVar(100L),
    DoubleVar(3.14),
    StringVar("test"),
    TrueVar,
    FalseVar,
    DecimalVar("10.99"),
    DateVar("2024-03-15"),
    TimeVar("10:30:00"),
    DateTimeVar("2024-03-15T10:30:00Z"),
    DurationVar("P1DT12H")
  ]
  
  for case in test_cases {
    match case {
      IntVar(v) => inspect(v.to_string(), content="42")
      IntegerVar(v) => inspect(v.to_string(), content="100")
      DoubleVar(v) => inspect(v.to_string(), content="3.14")
      StringVar(v) => inspect(v.to_string(), content="test")
      TrueVar => debug("Boolean: true")
      FalseVar => debug("Boolean: false")
      DecimalVar(v) => debug("Decimal: \{v}")
      DateVar(v) => {
        let regex = @string.Regex("^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}$")
        guard regex.execute(v) is Some(_) else { fail("Invalid date format") }
      }
      TimeVar(v) => {
        let regex = @string.Regex("^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}$")
        guard regex.execute(v) is Some(_) else { fail("Invalid time format") }
      }
      DateTimeVar(v) => {
        let regex = @string.Regex("^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}T[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}Z?$")
        guard regex.execute(v) is Some(_) else { fail("Invalid datetime format") }
      }
      DurationVar(v) => {
        let regex = @string.Regex("^P.*$")
        guard regex.execute(v) is Some(_) else { fail("Invalid duration format") }
      }
    }
  }
}


test "VarDataType: from xsd conversion with validation" {
  // 测试从 XSD 类型转换的端到端流程
  let int_node = lwINT
  let result = int_node.into_datatype("123")
  match result {
    IntVar(v) => inspect(v, content="123")
    _ => fail("Expected IntVar")
  }
  
  let date_node = lwDATE
  let result2 = date_node.into_datatype("2024-03-15")
  match result2 {
    DateVar(v) => {
      let regex = @string.Regex("^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="2024-03-15")
    }
    _ => fail("Expected DateVar")
  }
  
  let time_node = lwTIME
  let result3 = time_node.into_datatype("10:30:00")
  match result3 {
    TimeVar(v) => {
      let regex = @string.Regex("^[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="10:30:00")
    }
    _ => fail("Expected TimeVar")
  }
  
  let duration_node = lwDURATION
  let result4 = duration_node.into_datatype("PT1H30M")
  match result4 {
    DurationVar(v) => {
      let regex = @string.Regex("^PT.*$")
      guard regex.execute(v) is Some(m) else { fail("Expected match") }
      inspect(m.content(), content="PT1H30M")
    }
    _ => fail("Expected DurationVar")
  }
  
  let invalid_node = lwINT
  let result5 = invalid_node.into_datatype("not a number")
  match result5 {
    StringVar(v) => inspect(v, content="NAN")
    _ => fail("Expected StringVar for invalid input")
  }
}