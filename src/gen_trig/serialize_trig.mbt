// ============================================================
// Turtle / TriG 序列化器（分水岭下游：只吃物化模型 QuadEmit）
// ------------------------------------------------------------
// 与 @nquads Serializer 同构的旋钮设计（正交，不混轴）：
//   format       —— 输出语法开关：TriG 允许图块区；Turtle 禁图名
//   graph_policy —— format=Turtle 时图名的语义：
//                    Strict = 报错阻断（无损保证，默认）
//                    Drop   = 静默丢弃（有损导出，必须显式选择）
// 序列化是字节保真回写：词项 span 来自已验证输入，原样拷贝不重编码
// （物化层 deep_validate 门已保证流进来的 emit 合法；此处只钉结构不变量，
//   与 serialize_nquads 同规：PrefName 残留报错而非透传）
// 与 nquads 行式输出的差异：语句按图分组——默认图先输出（顶层三元组，
// 纯默认图文档即合法 Turtle），其后命名图按首次出现序各成一个图块区；
// 同名图按字节内容归并（arena 展开切片与原 data 切片视为同图）
// 引用三元组壳（RDF 1.2）整段原文回写；三引号长串原样保真（规范化待后续）
// ============================================================

///|
/// 输出语法开关
pub(all) enum SerializeFormat {
  Turtle // 默认图三元组，图名位不得出现
  TriG // 默认图三元组 + 命名图块区
} derive(Debug, Eq)

///|
/// 图名策略（仅 format=Turtle 时生效；format=TriG 下空转）
pub(all) enum GraphPolicy {
  Strict // 图名存在 → 报错（拒绝有损）
  Drop // 图名存在 → 丢弃（有损导出）
} derive(Debug, Eq)

///|
pub struct TrigSerializer {
  format : SerializeFormat
  graph_policy : GraphPolicy
}

///|
/// 创建序列化器。默认 TriG + Strict：无损是底线，有损必须显式选 Drop
pub fn TrigSerializer::new(
  format? : SerializeFormat = TriG,
  graph_policy? : GraphPolicy = Strict,
) -> TrigSerializer {
  { format, graph_policy, }
}

///|
/// 字节保真回写（与 @nquads Serializer 同规：decode_lossy 整体解码，
/// 严禁逐字节 to_char——多字节 UTF-8 会被双重编码成乱码）
fn trig_ser_span(view : ArrayView[Byte], buf : StringBuilder) -> Unit {
  buf.write_string(@utf8.decode_lossy(Bytes::from_array(view)))
}

///|
/// view 内容相等（分组用：同一图名的不同字节切片视为同图）
fn trig_ser_view_eq(a : ArrayView[Byte], b : ArrayView[Byte]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// 命名图分组条目（首次出现序）
priv struct GraphGroup {
  name : ArrayView[Byte]
  triples : Array[@nquads.QuadEmit]
}

///|
/// 单条三元组本体：s p o（终结符与图块区结构由调用方管）
fn append_terms(
  quad : @nquads.QuadEmit,
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  match quad.subject {
    Iri(v) => trig_ser_span(v, buf)
    BNode(v) => trig_ser_span(v, buf)
    // RDF 1.2 引用三元组壳主语：整段原样写出（同宾语位 TT 保真口径）
    TripleTerm(v) => trig_ser_span(v, buf)
    // Turtle/TriG 语法无前缀名：物化层已展开，残留即不变量破坏，报错钉住
    PrefName(_) =>
      return Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in serialized output",
          (0, 0),
        ),
      )
  }
  buf.write_char(' ')
  trig_ser_span(quad.predicate, buf)
  buf.write_char(' ')
  match quad.object {
    Iri(v) => trig_ser_span(v, buf)
    BNode(v) => trig_ser_span(v, buf)
    Literal(v) => trig_ser_span(v, buf)
    // 引用三元组壳整段原文回写（RDF 1.2；round-trip 不变量）
    TripleTerm(v) => trig_ser_span(v, buf)
    PrefName(_) =>
      return Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in serialized output",
          (0, 0),
        ),
      )
  }
  Ok(())
}

///|
/// 序列化 quad 集合为对象字符串。
/// 布局：默认图三元组先输出（顶层，Turtle 兼容），其后命名图按首次出现序
/// 各成一个图块区 `name { triple . \n ... }`
pub fn TrigSerializer::serialize(
  self : TrigSerializer,
  quads : Array[@nquads.QuadEmit],
) -> Result[String, ParseError] {
  let buf = StringBuilder()
  let default_graph : Array[@nquads.QuadEmit] = []
  let groups : Array[GraphGroup] = []
  // 分组：默认图直收；命名图按内容归并（保持首次出现序）
  for quad in quads {
    match quad.graph {
      None => default_graph.push(quad)
      Iri(v) | BNode(v) => {
        let mut hit : GraphGroup? = None
        for group in groups {
          if trig_ser_view_eq(group.name, v) {
            hit = Some(group)
            break
          }
        }
        match hit {
          Some(group) => group.triples.push(quad)
          None => groups.push({ name: v, triples: [quad], })
        }
      }
    }
  }
  // Turtle：图名存在按策略裁决（Strict 阻断 / Drop 丢弃）
  if self.format is Turtle && groups.length() > 0 {
    match self.graph_policy {
      Strict =>
        return Err(
          ParseError::SyntaxErr(
            "Graph term is not representable in Turtle (use TriG format or Drop policy)",
            (0, 0),
          ),
        )
      Drop => ()
    }
  }
  // 1) 默认图：顶层三元组语句
  for quad in default_graph {
    match append_terms(quad, buf) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
    buf.write_string(" .\n")
  }
  // 2) 命名图：TriG 照写图块区；Turtle+Drop 降级为顶层三元组
  //    （与 nquads Drop 同规：丢图名字段，不丢数据行）
  if self.format is TriG {
    for group in groups {
      trig_ser_span(group.name, buf)
      buf.write_string(" {\n")
      for quad in group.triples {
        buf.write_string("  ")
        match append_terms(quad, buf) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
        buf.write_string(" .\n")
      }
      buf.write_string("}\n")
    }
  } else {
    for group in groups {
      for quad in group.triples {
        match append_terms(quad, buf) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
        buf.write_string(" .\n")
      }
    }
  }
  Ok(buf.to_string())
}

///|
test "序列化: TriG 默认图先输出 + 命名图按内容归并（首次出现序）" {
  let s1 = @utf8.encode("<http://e.org/s>").to_array()
  let p1 = @utf8.encode("<http://e.org/p>").to_array()
  let o1 = @utf8.encode("<http://e.org/o>").to_array()
  let s2 = @utf8.encode("<http://e.org/s2>").to_array()
  let p2 = @utf8.encode("<http://e.org/p2>").to_array()
  let o2 = @utf8.encode("<http://e.org/o2>").to_array()
  let s3 = @utf8.encode("<http://e.org/s3>").to_array()
  let g1a = @utf8.encode("<http://e.org/g>").to_array()
  // 同一图名的两份不同切片（模拟 arena 展开 vs 原 data）——按内容归并
  let g1b = @utf8.encode("<http://e.org/").to_array() +
    @utf8.encode("g>").to_array()
  let g2 = @utf8.encode("<http://e.org/h>").to_array()
  let quads : Array[@nquads.QuadEmit] = [
    { subject: Iri(s1[:]), predicate: p1[:], object: Iri(o1[:]), graph: None, },
    {
      subject: Iri(s2[:]),
      predicate: p2[:],
      object: Iri(o2[:]),
      graph: Iri(g1a[:]),
    },
    {
      subject: Iri(s3[:]),
      predicate: p2[:],
      object: Iri(o2[:]),
      graph: Iri(g1b[:]),
    },
    {
      subject: Iri(s1[:]),
      predicate: p1[:],
      object: Iri(o1[:]),
      graph: Iri(g2[:]),
    },
  ]
  let ser = TrigSerializer::new() // 默认 TriG + Strict
  match ser.serialize(quads) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n<http://e.org/g> {\n  <http://e.org/s2> <http://e.org/p2> <http://e.org/o2> .\n  <http://e.org/s3> <http://e.org/p2> <http://e.org/o2> .\n}\n<http://e.org/h> {\n  <http://e.org/s> <http://e.org/p> <http://e.org/o> .\n}\n",
      )
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}

///|
test "序列化: Turtle 开关——Strict 阻断图名 / Drop 有损丢弃（默认图不受影响）" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let g = @utf8.encode("<http://e.org/g>").to_array()
  let named : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: Iri(g[:]),
  }
  let plain : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  // Turtle + Strict（默认）：图名阻断
  let strict = TrigSerializer::new(format=Turtle)
  assert_true(strict.serialize([named, plain]) is Err(_))
  // Turtle + Drop：图名丢弃，其余照写
  let drop = TrigSerializer::new(format=Turtle, graph_policy=Drop)
  match drop.serialize([named, plain]) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n",
      )
    Err(_) => assert_false(true)
  }
}

///|
test "序列化: PrefName 残留报错钉住（主语/宾语位）" {
  let s = @utf8.encode("ex:name").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let o = @utf8.encode("<http://e.org/o>").to_array()
  let bad_subj : @nquads.QuadEmit = {
    subject: PrefName(s[:]),
    predicate: p[:],
    object: Iri(o[:]),
    graph: None,
  }
  let bad_obj : @nquads.QuadEmit = {
    subject: Iri(o[:]),
    predicate: p[:],
    object: PrefName(s[:]),
    graph: None,
  }
  let ser = TrigSerializer::new()
  assert_true(ser.serialize([bad_subj]) is Err(_))
  assert_true(ser.serialize([bad_obj]) is Err(_))
}

///|
test "序列化: 引用三元组壳整段回写" {
  let s = @utf8.encode("<http://e.org/s>").to_array()
  let p = @utf8.encode("<http://e.org/p>").to_array()
  let tt = @utf8.encode("<< <http://a> <http://b> <http://c> >>").to_array()
  let quad : @nquads.QuadEmit = {
    subject: Iri(s[:]),
    predicate: p[:],
    object: TripleTerm(tt[:]),
    graph: None,
  }
  let ser = TrigSerializer::new()
  match ser.serialize([quad]) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> << <http://a> <http://b> <http://c> >> .\n",
      )
    Err(_) => assert_false(true)
  }
}

///|
test "序列化: 全链路 解析→物化→TrigSerializer（前缀展开 + 数值 + 图块区）" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p ex:o .\nex:g { ex:s2 ex:p2 42 . }\n",
  )
  assert_eq(errors.length(), 0)
  let ser = TrigSerializer::new()
  match ser.serialize(emits) {
    Ok(out) =>
      assert_eq(
        out, "<http://example/s> <http://example/p> <http://example/o> .\n<http://example/g> {\n  <http://example/s2> <http://example/p2> \"42\"^^<http://www.w3.org/2001/XMLSchema#integer> .\n}\n",
      )
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}
