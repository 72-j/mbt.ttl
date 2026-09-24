// ============================================================
// N3 序列化器（分水岭下游：只吃物化模型 QuadEmit）
// ------------------------------------------------------------
// 与 trig serialize_trig.mbt 同构的简化版（trig 336 行原型砍图轴）：
//   - N3 无图块语法：无 format/graph_policy 旋钮（TrigSerializer 的
//     SerializeFormat/GraphPolicy 两轴退役）；语句一律顶层三元组
//   - 图名位出现即不变量破坏，报错钉住（与 "PrefName 残留报错" 同规：
//     序列化是字节保真回写，不静默降级）
// 序列化是字节保真回写：词项 span 来自已验证输入，原样拷贝不重编码
// （物化层 deep_validate 门已保证流进来的 emit 合法；此处只钉结构不变量）
// 引用三元组壳（RDF 1.2 宾位）整段原文回写；三引号长串原样保真
// ============================================================

///|
pub struct N3Serializer {}

///|
/// 创建序列化器（无旋钮：N3 输出 = 顶层三元组语句，无损唯一形态）
pub fn N3Serializer::new() -> N3Serializer {
  N3Serializer::{ }
}

///|
/// 字节保真回写（decode_lossy 整体解码，严禁逐字节 to_char——多字节 UTF-8
/// 会被双重编码成乱码）
fn n3_ser_span(view : ArrayView[Byte], buf : StringBuilder) -> Unit {
  buf.write_string(@utf8.decode_lossy(Bytes::from_array(view)))
}

///|
/// 单条三元组本体：s p o（终结符由调用方管）
fn n3_append_terms(
  quad : @nquads.QuadEmit,
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  match quad.s_kind {
    @nquads.TermKind::Iri => n3_ser_span(quad.s_view, buf)
    @nquads.TermKind::BNode => n3_ser_span(quad.s_view, buf)
    // 引用三元组壳主语：整段原样写出（防御位：N3 表无主语位壳行）
    @nquads.TermKind::TripleTerm => n3_ser_span(quad.s_view, buf)
    // N3 语法无前缀名：物化层已展开，残留即不变量破坏，报错钉住
    @nquads.TermKind::PrefName =>
      return Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in serialized output",
          (0, 0),
        ),
      )
    // 变量 `?x`（ADR-004：只记身份）整段原文回写——名与位置即全部语义，
    // round-trip 不变量
    @nquads.TermKind::Variable => n3_ser_span(quad.s_view, buf)
    // N3 役10：verb ::= expression，主语位字面量合法——整段原文回写
    @nquads.TermKind::Literal => n3_ser_span(quad.s_view, buf)
    // N3 ADR-002：GraphTerm 公式主语整段原文回写（不透明，不断言为真）
    @nquads.TermKind::Formula => n3_ser_span(quad.s_view, buf)
    // 位-种类非法组合：DefaultGraph 只许图名位，主语位出现即不变量破坏
    @nquads.TermKind::DefaultGraph =>
      return Err(
        ParseError::SyntaxErr(
          "DefaultGraph is not valid in subject position",
          (0, 0),
        ),
      )
  }
  buf.write_char(' ')
  n3_ser_span(quad.predicate, buf)
  buf.write_char(' ')
  match quad.o_kind {
    @nquads.TermKind::Iri => n3_ser_span(quad.o_view, buf)
    @nquads.TermKind::BNode => n3_ser_span(quad.o_view, buf)
    @nquads.TermKind::Literal => n3_ser_span(quad.o_view, buf)
    // 引用三元组壳整段原文回写（round-trip 不变量）
    @nquads.TermKind::TripleTerm => n3_ser_span(quad.o_view, buf)
    @nquads.TermKind::PrefName =>
      return Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in serialized output",
          (0, 0),
        ),
      )
    @nquads.TermKind::Variable => n3_ser_span(quad.o_view, buf)
    // N3 ADR-002：公式宾语整段原文回写（round-trip 不变量）
    @nquads.TermKind::Formula => n3_ser_span(quad.o_view, buf)
    // 位-种类非法组合：DefaultGraph 只许图名位，宾语位出现即不变量破坏
    @nquads.TermKind::DefaultGraph =>
      return Err(
        ParseError::SyntaxErr(
          "DefaultGraph is not valid in object position",
          (0, 0),
        ),
      )
  }
  Ok(())
}

///|
/// 序列化 quad 集合为语句串。布局：每语句一行 `s p o .\n`。
/// 图名位出现即报错（N3 无图语法，不变量破坏不得静默降级）
pub fn N3Serializer::serialize(
  _self : N3Serializer,
  quads : Array[@nquads.QuadEmit],
) -> Result[String, ParseError] {
  let buf = StringBuilder()
  for quad in quads {
    // 图位封闭门（P3 运行时对应物，清点表第 2/5 条）：N3 无图语法，
    // g_kind ≠ DefaultGraph 一律报错（结构非法与方言越界同一门收口）
    if !(quad.g_kind is @nquads.TermKind::DefaultGraph) {
      return Err(
        ParseError::SyntaxErr("Graph term is not representable in N3", (0, 0)),
      )
    }
    match n3_append_terms(quad, buf) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
    buf.write_string(" .\n")
  }
  Ok(buf.to_string())
}
