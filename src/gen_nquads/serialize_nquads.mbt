// ============================================================
// N-Triples / N-Quads 序列化器（分水岭下游：只吃物化模型 QuadEmit）
// ------------------------------------------------------------
// 旋钮设计（正交，不混轴）：
//   format           —— 输出语法：graph 字段允不允许写出来
//   graph_policy     —— format=Triple 时 graph 存在的语义：
//                         Strict = 报错阻断（无损保证，默认）
//                         Drop   = 静默丢弃（有损导出，必须显式选择）
//   only_named_graph —— 行选择（查询语义，独立于格式）：仅输出带图名的行
// 序列化是字节保真回写：词项 span 来自已验证输入，原样拷贝不重编码
// （round-trip 不变量：serialize ∘ parse = 恒等，Drop/行选择除外——它们是有损的显式选择）
// ============================================================

///|
/// 输出语法
pub(all) enum SerializeFormat {
  Triple // N-Triples：graph 字段不得出现
  Quad // N-Quads：graph 字段照写
} derive(Debug, Eq)

///|
/// graph 字段策略（仅 format=Triple 时生效；format=Quad 下空转）
pub(all) enum GraphPolicy {
  Strict // graph 存在 → 报错（拒绝有损）
  Drop // graph 存在 → 丢弃（有损导出）
} derive(Debug, Eq)

///|
pub struct Serializer {
  format : SerializeFormat
  graph_policy : GraphPolicy
  only_named_graph : Bool // 行选择：仅序列化带图名的 quad
}

///|
/// 创建序列化器。默认 N-Triples + Strict：无损是底线，有损必须显式选 Drop
pub fn Serializer::new(
  format? : SerializeFormat = Triple,
  graph_policy? : GraphPolicy = Strict,
  only_named_graph? : Bool = false,
) -> Serializer {
  { format, graph_policy, only_named_graph, }
}

///|
/// 序列化单个 Quad（与批量同口径：同一分派函数）
pub fn Serializer::serialize(
  self : Serializer,
  quad : QuadEmit,
) -> Result[String, ParseError] {
  let buf = StringBuilder()
  match self.append_dispatch(quad, buf) {
    Ok(_) => Ok(buf.to_string())
    Err(e) => Err(e)
  }
}

///|
/// 批量序列化：遇错即断（Strict 的阻断语义）
pub fn Serializer::serialize_all(
  self : Serializer,
  quads : Array[QuadEmit],
) -> Result[String, ParseError] {
  let buf = StringBuilder()
  for quad in quads {
    match self.append_dispatch(quad, buf) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  Ok(buf.to_string())
}

///|
/// 字节保真回写：span 原样拷贝。
/// 词项 span 是已验证输入的原文（合法 UTF-8），解码后重编码字节相同；
/// 严禁逐字节 to_char——多字节 UTF-8 会被双重编码成乱码
fn Serializer::append_span(
  _self : Serializer,
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Unit {
  buf.write_string(@utf8.decode_lossy(Bytes::from_array(view)))
}

///|
/// 序列化主语（BNode 原文回写，含 _: 前缀，不剥不重拼）
fn Serializer::append_subject(
  self : Serializer,
  subject : Subject,
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  match subject {
    Subject::Iri(view) => {
      self.append_span(view, buf)
      Ok(())
    }
    Subject::BNode(view) => {
      self.append_span(view, buf)
      Ok(())
    }
    // RDF 1.2 引用三元组壳：整段原样写出（与 Object::TripleTerm 同口径）
    Subject::TripleTerm(view) => {
      self.append_span(view, buf)
      Ok(())
    }
    // N-Triples/N-Quads 语法无前缀名：解析侧已挡死，此处不可达；
    // 透传会把非法语法写出，故报错钉住不变量
    Subject::PrefName(_) =>
      Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
  }
}

///|
/// 序列化宾语
fn Serializer::append_object(
  self : Serializer,
  object : Object,
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  match object {
    Object::Iri(view) => {
      self.append_span(view, buf)
      Ok(())
    }
    Object::BNode(view) => {
      self.append_span(view, buf)
      Ok(())
    }
    Object::Literal(view) => {
      self.append_span(view, buf)
      Ok(())
    }
    // 三元组词项整段原文回写（round-trip 不变量；内部拆解属下游语义层职责）
    Object::TripleTerm(view) => {
      self.append_span(view, buf)
      Ok(())
    }
    Object::PrefName(_) =>
      Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
  }
}

///|
/// 写主/谓/宾三元组本体（终结符与 graph 追加与否由分派决定，不在此处）
fn Serializer::append_terms(
  self : Serializer,
  quad : QuadEmit,
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  match self.append_subject(quad.subject, buf) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  buf.write_char(' ')
  self.append_span(quad.predicate, buf)
  buf.write_char(' ')
  match self.append_object(quad.object, buf) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(())
}

///|
/// per-quad 分派（唯一分派点，单条/批量共用）：
/// 行选择 → 格式 × graph 策略 → 句点终结。append_quad / append_triple 的重复由此收敛
fn Serializer::append_dispatch(
  self : Serializer,
  quad : QuadEmit,
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  // 行选择：仅带图名的行（查询语义，独立于格式）
  if self.only_named_graph && quad.graph is GraphName::None {
    return Ok(())
  }
  match self.format {
    Quad => {
      // N-Quads：graph 照写
      match self.append_terms(quad, buf) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match quad.graph {
        // BNode 图名与 IRI 一样原文回写（字节保真）
        GraphName::Iri(view) | GraphName::BNode(view) => {
          buf.write_char(' ')
          self.append_span(view, buf)
        }
        GraphName::None => ()
      }
      buf.write_string(" .\n")
      Ok(())
    }
    Triple =>
      // N-Triples：graph 字段按策略裁决
      match quad.graph {
        GraphName::None => {
          match self.append_terms(quad, buf) {
            Ok(_) => ()
            Err(e) => return Err(e)
          }
          buf.write_string(" .\n")
          Ok(())
        }
        GraphName::Iri(_) | GraphName::BNode(_) =>
          match self.graph_policy {
            Strict =>
              Err(
                ParseError::SyntaxErr(
                  "Graph term is not representable in N-Triples (use Quad format or Drop policy)",
                  (0, 0),
                ),
              )
            Drop => {
              // 有损：显式选择的 Drop
              match self.append_terms(quad, buf) {
                Ok(_) => ()
                Err(e) => return Err(e)
              }
              buf.write_string(" .\n")
              Ok(())
            }
          }
      }
  }
}

///|
test "序列化: Quad 往返（BNode 原文回写 + UTF-8 字节保真）" {
  let subj = @utf8.encode("_:b0").to_array()
  let pred = @utf8.encode("<http://e.org/p>").to_array()
  let obj = @utf8.encode("\"中文 \\u00e9\"").to_array()
  let graph = @utf8.encode("<http://e.org/g>").to_array()
  let s = Serializer::new(format=Quad)
  let quad : QuadEmit = {
    subject: Subject::BNode(subj[:]),
    predicate: pred[:],
    object: Object::Literal(obj[:]),
    graph: GraphName::Iri(graph[:]),
  }
  match s.serialize(quad) {
    Ok(out) =>
      assert_eq(
        out, "_:b0 <http://e.org/p> \"中文 \\u00e9\" <http://e.org/g> .\n",
      )
    Err(_) => assert_true(false)
  }
}

///|
test "序列化: N-Triples + Strict（默认）拒绝带图名 quad，单条/批量同阻断" {
  let subj = @utf8.encode("<http://e.org/s>").to_array()
  let pred = @utf8.encode("<http://e.org/p>").to_array()
  let obj = @utf8.encode("<http://e.org/o>").to_array()
  let graph = @utf8.encode("<http://e.org/g>").to_array()
  let quad : QuadEmit = {
    subject: Subject::Iri(subj[:]),
    predicate: pred[:],
    object: Object::Iri(obj[:]),
    graph: GraphName::Iri(graph[:]),
  }
  let s = Serializer::new() // 默认 Triple + Strict
  assert_true(s.serialize(quad) is Err(_))
  assert_true(s.serialize_all([quad]) is Err(_))
}

///|
test "序列化: N-Triples + Drop 显式有损（graph 丢弃，无图名行不受影响）" {
  let subj = @utf8.encode("<http://e.org/s>").to_array()
  let pred = @utf8.encode("<http://e.org/p>").to_array()
  let obj = @utf8.encode("<http://e.org/o>").to_array()
  let graph = @utf8.encode("<http://e.org/g>").to_array()
  let named : QuadEmit = {
    subject: Subject::Iri(subj[:]),
    predicate: pred[:],
    object: Object::Iri(obj[:]),
    graph: GraphName::Iri(graph[:]),
  }
  let plain : QuadEmit = {
    subject: Subject::Iri(subj[:]),
    predicate: pred[:],
    object: Object::Iri(obj[:]),
    graph: GraphName::None,
  }
  let s = Serializer::new(format=Triple, graph_policy=Drop)
  match s.serialize_all([named, plain]) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n<http://e.org/s> <http://e.org/p> <http://e.org/o> .\n",
      )
    Err(_) => assert_true(false)
  }
}

///|
test "序列化: 行选择 only_named_graph 独立于格式（丢行，不是丢字段）" {
  let subj = @utf8.encode("<http://e.org/s>").to_array()
  let pred = @utf8.encode("<http://e.org/p>").to_array()
  let obj = @utf8.encode("<http://e.org/o>").to_array()
  let graph = @utf8.encode("<http://e.org/g>").to_array()
  let plain : QuadEmit = {
    subject: Subject::Iri(subj[:]),
    predicate: pred[:],
    object: Object::Iri(obj[:]),
    graph: GraphName::None,
  }
  let named : QuadEmit = {
    subject: Subject::Iri(subj[:]),
    predicate: pred[:],
    object: Object::Iri(obj[:]),
    graph: GraphName::Iri(graph[:]),
  }
  let s = Serializer::new(format=Quad, only_named_graph=true)
  match s.serialize_all([plain, named]) {
    Ok(out) =>
      assert_eq(
        out, "<http://e.org/s> <http://e.org/p> <http://e.org/o> <http://e.org/g> .\n",
      )
    Err(_) => assert_true(false)
  }
}

///|
test "序列化: PrefName 不可达不变量（报错而非透传非法语法）" {
  let subj = @utf8.encode("ex:name").to_array()
  let pred = @utf8.encode("<http://e.org/p>").to_array()
  let obj = @utf8.encode("<http://e.org/o>").to_array()
  let quad : QuadEmit = {
    subject: Subject::PrefName(subj[:]),
    predicate: pred[:],
    object: Object::Iri(obj[:]),
    graph: GraphName::None,
  }
  let s = Serializer::new(format=Quad)
  assert_true(s.serialize(quad) is Err(_))
}
