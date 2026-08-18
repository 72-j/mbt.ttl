// 编译验证用的桩类型（模拟宿主模块中的载荷类型）
///|
pub(all) struct Span {
  start : Int
  end_ : Int
}

///|
pub(all) struct QuadSpan {
  s : Span
  p : Span
  o : Span
  g : Span?
}
