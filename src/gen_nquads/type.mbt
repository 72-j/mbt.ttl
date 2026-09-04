// ===== 用户部分：基础类型 =====
// 参考 src/moon_ttl/src/term.mbt 与 error.mbt（手写版）
// Span / QuadSpan 由生成的 nquads.mbt（NQuadsEvent / NQuadsEffect）引用

///|
/// (offset, length)
pub type Span = (Int, Int)

///|
/// 词项类型
pub(all) enum TermType {
  Iri
  BNode
  Literal
  TripleTerm // <<( s p o )>>（RDF 1.2，只出现于宾语位）
} derive(Debug, Eq)

///|
/// 已切片的四元组（span → 数据视图 + 词项类型）
pub struct QuadSpan {
  subj : ArrayView[Byte]
  pred : ArrayView[Byte]
  obj : ArrayView[Byte]
  graph : ArrayView[Byte]? // 图名 span，缺省 None
  subj_type : TermType
  obj_type : TermType
} derive(Debug)


// PendingQuad 已由生成的 nquads.mbt 自带（槽位名 subject/predicate/object/graph），
// 此处手抄副本退役——字段名以生成契约为准。
///|
/// 解析错误（携带位置信息）
// pub(all) suberror ParseError {
//   StructSyntaxErr(String, Int, Span) // 结构错误（语法层，带行号）
//   SyntaxErr(String, Span) // 结构错误（语法层）
// } derive(Debug)

///|
/// 按 span 安全切分数据（越界返回空视图）
fn slice_span(data : ArrayView[Byte], span : Span) -> ArrayView[Byte] {
  let (off, len) = span
  if off < 0 || len < 0 || off + len > data.length() {
    return data[0:0]
  }
  data[off:off + len]
}
