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
// 产物模型：Subject/Object/GraphName 三枚举并入单 TermKind 轴，词项零箱；
// 图位封闭由运行时门钉住（原类型级保证的运行时对应物，沿革见 perf-review.txt）：
// 图名位只许 Iri/BNode/DefaultGraph，其余 kind 报错而非透传
// ============================================================

///|
/// 输出语法
pub(all) enum SerializeFormat {
  Triple // N-Triples：graph 字段不得出现
  Quad // N-Quads：graph 字段照写
} derive(Debug, Eq)

///|
// 工具链 `implicit_impl_as_method` 弃用 ⇒ trait 方法显式提升。
pub extend SerializeFormat with Eq::{equal, not_equal}

///|
// 工具链 `implicit_impl_as_method` 弃用 ⇒ trait 方法显式提升。
pub extend SerializeFormat with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// graph 字段策略（仅 format=Triple 时生效；format=Quad 下空转）
pub(all) enum GraphPolicy {
  Strict // graph 存在 → 报错（拒绝有损）
  Drop // graph 存在 → 丢弃（有损导出）
} derive(Debug, Eq)

///|
// 工具链 `implicit_impl_as_method` 弃用 ⇒ trait 方法显式提升。
pub extend GraphPolicy with Eq::{equal, not_equal}

///|
// 工具链 `implicit_impl_as_method` 弃用 ⇒ trait 方法显式提升。
pub extend GraphPolicy with @moonbitlang/core/debug.Debug::{to_repr}

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
/// 序列化主语（BNode 原文回写，含 _: 前缀，不剥不重拼）。
/// 位-种类合法性（运行时门）：
/// 受纳 Iri/BNode/TripleTerm；拒 PrefName/Variable/Literal/Formula
fn Serializer::append_subject(
  self : Serializer,
  kind : TermKind,
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  match kind {
    TermKind::Iri => {
      self.append_span(view, buf)
      Ok(())
    }
    TermKind::BNode => {
      self.append_span(view, buf)
      Ok(())
    }
    // RDF 1.2 引用三元组壳：整段原样写出（与宾语位 TripleTerm 同口径）
    TermKind::TripleTerm => {
      self.append_span(view, buf)
      Ok(())
    }
    // N-Triples/N-Quads 语法无前缀名：解析侧已挡死，此处不可达；
    // 透传会把非法语法写出，故报错钉住不变量
    TermKind::PrefName =>
      Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
    // N-Triples/N-Quads 无变量（guides/nquads/terms/variable-reserved.md）：
    // 方言不产出，透传会写出上层语言语法，报错钉住不变量
    TermKind::Variable =>
      Err(
        ParseError::SyntaxErr(
          "Variables are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
    // N-Triples/N-Quads 无字面量主语/公式词项（N3 方言专属）：
    // 方言不产出，透传会写出上层语言语法，报错钉住不变量
    TermKind::Literal =>
      Err(
        ParseError::SyntaxErr(
          "Literal subjects are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
    TermKind::Formula =>
      Err(
        ParseError::SyntaxErr(
          "Formulas are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
    // 位-种类非法组合：DefaultGraph 只许图名位，主语位出现即不变量破坏
    TermKind::DefaultGraph =>
      Err(
        ParseError::SyntaxErr(
          "DefaultGraph is not valid in subject position",
          (0, 0),
        ),
      )
  }
}

///|
/// 序列化宾语。位-种类合法性（运行时门）：受纳 Iri/BNode/Literal/TripleTerm；
/// 拒 PrefName/Variable/Formula；DefaultGraph 同为主语位式非法组合
fn Serializer::append_object(
  self : Serializer,
  kind : TermKind,
  view : ArrayView[Byte],
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  match kind {
    TermKind::Iri => {
      self.append_span(view, buf)
      Ok(())
    }
    TermKind::BNode => {
      self.append_span(view, buf)
      Ok(())
    }
    TermKind::Literal => {
      self.append_span(view, buf)
      Ok(())
    }
    // 三元组词项整段原文回写（round-trip 不变量；内部拆解属下游语义层职责）
    TermKind::TripleTerm => {
      self.append_span(view, buf)
      Ok(())
    }
    TermKind::PrefName =>
      Err(
        ParseError::SyntaxErr(
          "Prefixed names are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
    TermKind::Variable =>
      Err(
        ParseError::SyntaxErr(
          "Variables are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
    // N-Triples/N-Quads 无公式词项（N3 方言专属，n3v2 ADR-002 GraphTerm 不透明）：
    // 方言不产出，透传会写出上层语言语法，报错钉住不变量
    TermKind::Formula =>
      Err(
        ParseError::SyntaxErr(
          "Formulas are not valid in N-Triples/N-Quads",
          (0, 0),
        ),
      )
    // 位-种类非法组合：DefaultGraph 只许图名位，宾语位出现即不变量破坏
    TermKind::DefaultGraph =>
      Err(
        ParseError::SyntaxErr(
          "DefaultGraph is not valid in object position",
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
  match self.append_subject(quad.s_kind, quad.s_view, buf) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  buf.write_char(' ')
  self.append_span(quad.predicate, buf)
  buf.write_char(' ')
  match self.append_object(quad.o_kind, quad.o_view, buf) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(())
}

///|
/// per-quad 分派（唯一分派点，单条/批量共用）：
/// 行选择 → 格式 × graph 策略 → 句点终结。append_quad / append_triple 的重复由此收敛。
/// 图位封闭门（类型级保证的运行时对应物）：图名位只许 Iri/BNode/DefaultGraph，
/// 其余 kind 无论格式与策略一律报错——透传会写出非法语法
fn Serializer::append_dispatch(
  self : Serializer,
  quad : QuadEmit,
  buf : StringBuilder,
) -> Result[Unit, ParseError] {
  // 行选择：仅带图名的行（查询语义，独立于格式）
  if self.only_named_graph && quad.g_kind is TermKind::DefaultGraph {
    return Ok(())
  }
  match self.format {
    Quad => {
      // N-Quads：graph 照写
      match self.append_terms(quad, buf) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match quad.g_kind {
        // BNode 图名与 IRI 一样原文回写（字节保真）
        TermKind::Iri | TermKind::BNode => {
          buf.write_char(' ')
          self.append_span(quad.g_view, buf)
        }
        TermKind::DefaultGraph => ()
        // 图位封闭门：结构非法（如 Literal 塞图名位），策略再宽也不放行
        _ =>
          return Err(
            ParseError::SyntaxErr(
              "Graph term kind is not valid in graph position (only IRI/blank node/default graph)",
              (0, 0),
            ),
          )
      }
      buf.write_string(" .\n")
      Ok(())
    }
    Triple =>
      // N-Triples：graph 字段按策略裁决
      match quad.g_kind {
        TermKind::DefaultGraph => {
          match self.append_terms(quad, buf) {
            Ok(_) => ()
            Err(e) => return Err(e)
          }
          buf.write_string(" .\n")
          Ok(())
        }
        TermKind::Iri | TermKind::BNode =>
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
        // 图位封闭门：结构非法，Strict/Drop 之外无处可落
        _ =>
          Err(
            ParseError::SyntaxErr(
              "Graph term kind is not valid in graph position (only IRI/blank node/default graph)",
              (0, 0),
            ),
          )
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
    s_kind: TermKind::BNode,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Literal,
    o_view: obj[:],
    g_kind: TermKind::Iri,
    g_view: graph[:],
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
    s_kind: TermKind::Iri,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Iri,
    o_view: obj[:],
    g_kind: TermKind::Iri,
    g_view: graph[:],
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
    s_kind: TermKind::Iri,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Iri,
    o_view: obj[:],
    g_kind: TermKind::Iri,
    g_view: graph[:],
  }
  let plain : QuadEmit = {
    s_kind: TermKind::Iri,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Iri,
    o_view: obj[:],
    g_kind: TermKind::DefaultGraph,
    g_view: pred[0:0],
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
    s_kind: TermKind::Iri,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Iri,
    o_view: obj[:],
    g_kind: TermKind::DefaultGraph,
    g_view: pred[0:0],
  }
  let named : QuadEmit = {
    s_kind: TermKind::Iri,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Iri,
    o_view: obj[:],
    g_kind: TermKind::Iri,
    g_view: graph[:],
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
    s_kind: TermKind::PrefName,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Iri,
    o_view: obj[:],
    g_kind: TermKind::DefaultGraph,
    g_view: pred[0:0],
  }
  let s = Serializer::new(format=Quad)
  assert_true(s.serialize(quad) is Err(_))
}

///|
test "图位封闭门: Literal 塞图名位必须报错（Quad/Triple 同拒，Drop 不放行）" {
  let subj = @utf8.encode("<http://e.org/s>").to_array()
  let pred = @utf8.encode("<http://e.org/p>").to_array()
  let obj = @utf8.encode("<http://e.org/o>").to_array()
  let lit = @utf8.encode("\"x\"").to_array()
  let bad : QuadEmit = {
    s_kind: TermKind::Iri,
    s_view: subj[:],
    predicate: pred[:],
    o_kind: TermKind::Iri,
    o_view: obj[:],
    g_kind: TermKind::Literal,
    g_view: lit[:],
  }
  // Quad 格式：照写路径上的结构门
  assert_true(Serializer::new(format=Quad).serialize(bad) is Err(_))
  // Triple 格式：Drop 策略也越不过结构门（有损选择 ≠ 结构放行）
  assert_true(
    Serializer::new(format=Triple, graph_policy=Drop).serialize(bad) is Err(_),
  )
}
