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
  match quad.subject {
    Iri(v) => n3_ser_span(v, buf)
    BNode(v) => n3_ser_span(v, buf)
    // 引用三元组壳主语：整段原样写出（防御位：N3 表无主语位壳行）
    TripleTerm(v) => n3_ser_span(v, buf)
    // N3 语法无前缀名：物化层已展开，残留即不变量破坏，报错钉住
    PrefName(_) =>
      return Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in serialized output",
          (0, 0),
        ),
      )
    // 变量 `?x`（ADR-004：只记身份）整段原文回写——名与位置即全部语义，
    // round-trip 不变量
    Variable(v) => n3_ser_span(v, buf)
  }
  buf.write_char(' ')
  n3_ser_span(quad.predicate, buf)
  buf.write_char(' ')
  match quad.object {
    Iri(v) => n3_ser_span(v, buf)
    BNode(v) => n3_ser_span(v, buf)
    Literal(v) => n3_ser_span(v, buf)
    // 引用三元组壳整段原文回写（round-trip 不变量）
    TripleTerm(v) => n3_ser_span(v, buf)
    PrefName(_) =>
      return Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in serialized output",
          (0, 0),
        ),
      )
    Variable(v) => n3_ser_span(v, buf)
  }
  Ok(())
}

///|
/// 序列化 quad 集合为语句串。布局：每语句一行 `s p o .\n`。
/// 图名位出现即报错（N3 无图语法，不变量破坏不得静默降级）
pub fn N3Serializer::serialize(
  self : N3Serializer,
  quads : Array[@nquads.QuadEmit],
) -> Result[String, ParseError] {
  let buf = StringBuilder()
  for quad in quads {
    if !(quad.graph is None) {
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

///|
test "序列化: 基本语句回写" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let quad : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  match N3Serializer::new().serialize([quad]) {
    Ok(out) =>
      assert_eq(out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n")
    Err(_) => assert_false(true)
  }
}

///|
test "序列化: PrefName 残留报错钉住" {
  let s = @utf8.encode("ex:name").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let bad : @nquads.QuadEmit = {
    subject: PrefName(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  assert_true(N3Serializer::new().serialize([bad]) is Err(_))
}

///|
test "序列化: 图名残留报错钉住（N3 无图语法）" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let g = @utf8.encode("<http://e.org/g>").to_array()
  let bad : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: Iri(g[:]),
  }
  assert_true(N3Serializer::new().serialize([bad]) is Err(_))
}

///|
test "序列化: 全链路 解析→物化→N3Serializer（前缀展开 + 集合 genid）" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p ( 1 2 ) .\n",
  )
  assert_eq(errors.length(), 0)
  match N3Serializer::new().serialize(emits) {
    Ok(out) =>
      assert_eq(out, "<http://example/s> <http://example/p> _:genid42 .\n")
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}
