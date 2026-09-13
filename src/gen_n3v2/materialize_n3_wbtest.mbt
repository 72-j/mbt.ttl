// 白盒测试：materialize_n3.mbt 物化层（役27a 自生产文件迁入，R-11 测试归位；
// 原 mat_* 辅助更名/收编——bytes_of、view_str 复用 engine_wbtest，见三件套注）

// ===== 物化器测试辅助（_wbtest 包内命名空间；bytes_of/view_str 复用 engine_wbtest） =====

///|
/// 全链路：解析 → 物化。data 由本函数持有（view 生命周期 = 调用方作用域）
fn parse_materialize(
  input : String,
  rdf12? : Bool = true,
) -> (Array[@nquads.QuadEmit], Array[ParseError]) {
  let data = bytes_of(input)
  let engine = N3Engine::from_bytes(data)
  let sec = data[:]
  let slice = N3SliceParser::new(engine, sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  if errors.length() > 0 {
    return ([], errors)
  }
  let mat = N3Materializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
    rdf12~,
  )
  mat.materialize_all(quads)
}

///|
/// 首个目标字节偏移（测试内动态定位开括号，免硬编码偏移）
fn first_offset_of(data : Array[Byte], b : Byte) -> Int {
  for i in 0..<data.length() {
    if data[i] == b {
      return i
    }
  }
  -1
}

///|
/// 枚举载荷抽取（断言用）：变体不符返回空串，断言自然爆。
/// 三件套收编原 `mat_vs ∘ mat_subj/mat_obj` 组合与 `.predicate` 直取——返 String，
/// 内部复用 view_str（decode_lossy 全幅，严禁逐字节 to_char 拼多字节）
fn emit_subject(e : @nquads.QuadEmit) -> String {
  match e.subject {
    Iri(v) => view_str(v, (0, v.length()))
    BNode(v) => view_str(v, (0, v.length()))
    PrefName(v) => view_str(v, (0, v.length()))
    // 役8 注解壳主语（<<s p o>> arena 合成）走 TT 臂
    TripleTerm(v) => view_str(v, (0, v.length()))
    // 役17 字面量主语臂（span 干净后字面量可居主位）
    Literal(v) => view_str(v, (0, v.length()))
    _ => ""
  }
}

///|
fn emit_predicate(e : @nquads.QuadEmit) -> String {
  let v = e.predicate
  view_str(v, (0, v.length()))
}

///|
fn emit_object(e : @nquads.QuadEmit) -> String {
  match e.object {
    Iri(v) => view_str(v, (0, v.length()))
    BNode(v) => view_str(v, (0, v.length()))
    Literal(v) => view_str(v, (0, v.length()))
    TripleTerm(v) => view_str(v, (0, v.length()))
    PrefName(v) => view_str(v, (0, v.length()))
    Variable(v) => view_str(v, (0, v.length()))
    Formula(v) => view_str(v, (0, v.length()))
  }
}

///|
test "物化: PrefName/DefaultPrefixIRI 均展开为全 IRI" {
  let (emits, errors) = parse_materialize(
    "@prefix ex: <http://example/> .\n@prefix : <http://dft/> .\nex:s ex:p ex:o .\n:s2 :p2 :o2 .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  assert_eq(emit_subject(emits[0]), "<http://example/s>")
  assert_eq(emit_predicate(emits[0]), "<http://example/p>")
  assert_eq(emit_object(emits[0]), "<http://example/o>")
  assert_eq(emit_subject(emits[1]), "<http://dft/s2>")
  assert_eq(emit_predicate(emits[1]), "<http://dft/p2>")
}

///|
test "物化: 'a' 缩写 → rdf:type，数值三型与布尔 → typed literal" {
  let (emits, errors) = parse_materialize(
    "@prefix ex: <http://example/> .\nex:s a ex:C .\nex:n ex:i 42 ; ex:d 1.5 ; ex:x 1.0e3 ; ex:b true, false .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 6)
  assert_eq(
    emit_predicate(emits[0]),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>",
  )
  let expect : Array[(String, String)] = [
    ("<http://example/i>", "\"42\"^^<http://www.w3.org/2001/XMLSchema#integer>"),
    (
      "<http://example/d>", "\"1.5\"^^<http://www.w3.org/2001/XMLSchema#decimal>",
    ),
    (
      "<http://example/x>", "\"1.0e3\"^^<http://www.w3.org/2001/XMLSchema#double>",
    ),
    (
      "<http://example/b>", "\"true\"^^<http://www.w3.org/2001/XMLSchema#boolean>",
    ),
    (
      "<http://example/b>", "\"false\"^^<http://www.w3.org/2001/XMLSchema#boolean>",
    ),
  ]
  for i in 0..<expect.length() {
    let (pv, ov) = expect[i]
    assert_eq(emit_predicate(emits[i + 1]), pv)
    assert_eq(emit_object(emits[i + 1]), ov)
  }
}

///|
test "物化: 字面量后缀 —— @lang 保真 / ^^PrefName 展开 / ^^<IRI> 保真" {
  let (emits, errors) = parse_materialize(
    "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n@prefix ex: <http://example/> .\nex:s ex:p \"lit\"@en-US .\nex:s ex:p \"x\"^^xsd:int .\nex:s ex:p \"y\"^^<http://d.example/dt> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  assert_eq(emit_object(emits[0]), "\"lit\"@en-US")
  assert_eq(
    emit_object(emits[1]),
    "\"x\"^^<http://www.w3.org/2001/XMLSchema#int>",
  )
  assert_eq(emit_object(emits[2]), "\"y\"^^<http://d.example/dt>")
}

///|
test "物化: TT 壳宾位整段保真" {
  let (emits, errors) = parse_materialize(
    "@prefix ex: <http://example/> .\nex:s ex:p << <http://a> <http://b> <http://c> >> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(emit_object(emits[0]), "<< <http://a> <http://b> <http://c> >>")
}

///|
test "物化: 集合单一 BNode 零链（ADR-003a）" {
  let input = "@prefix ex: <http://example/> .\nex:s ex:p ( 1 2 ) .\n"
  let data = bytes_of(input)
  let sec = data[:]
  let slice = N3SliceParser::new(N3Engine::from_bytes(data), sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  assert_eq(errors.length(), 0)
  // 元素 1、2 不产 quad：语句四元组即全部
  assert_eq(quads.length(), 1)
  let mat = N3Materializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, merrs) = mat.materialize_all(quads)
  assert_eq(merrs.length(), 0)
  assert_eq(emits.length(), 1)
  // 单一 BNode = `(` 自身 span → genid{off}
  assert_eq(emit_object(emits[0]), "_:genid\{first_offset_of(data, b'(')}")
}

///|
test "物化: 空集合 -> rdf:nil（ADR-003a pop nil 标记）" {
  let input = "@prefix ex: <http://example/> .\nex:s ex:p ( ) .\n"
  let data = bytes_of(input)
  let sec = data[:]
  let slice = N3SliceParser::new(N3Engine::from_bytes(data), sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 1)
  let mat = N3Materializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, merrs) = mat.materialize_all(quads)
  assert_eq(merrs.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(
    emit_object(emits[0]),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>",
  )
}

///|
test "物化: bnp fresh 身份共享（内部 quad 主语 = 语句宾语）" {
  let input = "@prefix ex: <http://example/> .\nex:s ex:p [ ex:q ex:z ] .\n"
  let data = bytes_of(input)
  let sec = data[:]
  let slice = N3SliceParser::new(N3Engine::from_bytes(data), sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  assert_eq(errors.length(), 0)
  assert_eq(quads.length(), 2)
  let mat = N3Materializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, merrs) = mat.materialize_all(quads)
  assert_eq(merrs.length(), 0)
  assert_eq(emits.length(), 2)
  let id = "_:genid\{first_offset_of(data, b'[')}"
  assert_eq(emit_subject(emits[0]), id)
  assert_eq(emit_object(emits[1]), id)
}

///|
test "物化: @base 相对 IRI 解析" {
  let (emits, errors) = parse_materialize(
    "@base <http://base/> .\n<rel> <http://p> <x#f> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(emit_subject(emits[0]), "<http://base/rel>")
  assert_eq(emit_object(emits[0]), "<http://base/x#f>")
}

///|
test "役3: 主位路径官方形——! 跳附节点，真谓词收口（cwm path1 口径）" {
  // 官方语料（cwm_syntax/path1.n3）：路径附于节点，后随真谓词 + 宾语
  // :albert!fam:mother fam:sister :auntieAnne ≡ (albert,!fam:mother→g) + (g,fam:sister,auntieAnne)
  let (emits, errors) = parse_materialize(
    "<http://ex/s> !<http://ex/p> <http://ex/q> <http://ex/o> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  let g1 = emit_object(emits[0])
  assert_true(g1.has_prefix("_:genid"))
  assert_eq(emit_subject(emits[0]), "<http://ex/s>")
  assert_eq(emit_predicate(emits[0]), "<http://ex/p>")
  assert_eq(emit_subject(emits[1]), g1)
  assert_eq(emit_predicate(emits[1]), "<http://ex/q>")
  assert_eq(emit_object(emits[1]), "<http://ex/o>")
  // 旧役3"直连 ≡ S P O"教义已翻案（ADR-011）：无真谓词的直连形官方非法 → 拒绝
  let (emits2, errors2) = parse_materialize(
    "<http://ex/s> !<http://ex/p> <http://ex/o> .\n",
  )
  assert_eq(errors2.length(), 1)
  assert_eq(emits2.length(), 0)
}

///|
test "役3: 主位路径官方形——^ 反跳附节点（cwm path1 口径）" {
  // :albert^fam:father fam:sister :nieceBertha ≡ (g,fam:father,albert) + (g,fam:sister,nieceBertha)
  let (emits, errors) = parse_materialize(
    "<http://ex/s> ^<http://ex/p> <http://ex/q> <http://ex/o> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  let g1 = emit_subject(emits[0])
  assert_true(g1.has_prefix("_:genid"))
  assert_eq(emit_predicate(emits[0]), "<http://ex/p>")
  assert_eq(emit_object(emits[0]), "<http://ex/s>")
  assert_eq(emit_subject(emits[1]), g1)
  assert_eq(emit_predicate(emits[1]), "<http://ex/q>")
  assert_eq(emit_object(emits[1]), "<http://ex/o>")
  // 直连形（无真谓词）官方非法 → 拒绝
  let (emits2, errors2) = parse_materialize(
    "<http://ex/s> ^<http://ex/p> <http://ex/o> .\n",
  )
  assert_eq(errors2.length(), 1)
  assert_eq(emits2.length(), 0)
}

///|
test "役3: 基动词 !/^ 中转 hop——desugar 双 quad，genid 同体" {
  // S P!Q O ≡ S P _:1 . _:1 Q O
  let (emits, errors) = parse_materialize(
    "<http://ex/s> <http://ex/p>!<http://ex/q> <http://ex/o> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  let g1 = emit_object(emits[0])
  assert_true(g1.has_prefix("_:genid"))
  assert_eq(emit_subject(emits[0]), "<http://ex/s>")
  assert_eq(emit_predicate(emits[0]), "<http://ex/p>")
  assert_eq(emit_subject(emits[1]), g1)
  assert_eq(emit_predicate(emits[1]), "<http://ex/q>")
  assert_eq(emit_object(emits[1]), "<http://ex/o>")
  // S P^Q O ≡ S P _:1 . O Q _:1（基跳恒正向；^ 只辖其后一步）
  let (emits2, errors2) = parse_materialize(
    "<http://ex/s> <http://ex/p>^<http://ex/q> <http://ex/o> .\n",
  )
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 2)
  let g2 = emit_object(emits2[0])
  assert_true(g2.has_prefix("_:genid"))
  assert_eq(emit_subject(emits2[1]), "<http://ex/o>")
  assert_eq(emit_predicate(emits2[1]), "<http://ex/q>")
  assert_eq(emit_object(emits2[1]), g2)
}

///|
test "役3: 主位链官方形——!P!Q 双跳 desugar + 混合方向当步旗标口径" {
  // 官方语料（cwm_syntax/path2.n3）：:albert!fam:mother :mentor!:inverse :auntieAnne
  // S !P!Q R O ≡ (S,P,g1) + (g1,Q,g2) + (g2,R,O)
  let (emits, errors) = parse_materialize(
    "<http://ex/s> !<http://ex/p>!<http://ex/q> <http://ex/r> <http://ex/o> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  let g1 = emit_object(emits[0])
  let g2 = emit_subject(emits[2])
  assert_true(g1.has_prefix("_:genid"))
  assert_true(g2.has_prefix("_:genid"))
  assert_false(g1 == g2)
  assert_eq(emit_subject(emits[0]), "<http://ex/s>")
  assert_eq(emit_predicate(emits[0]), "<http://ex/p>")
  assert_eq(emit_subject(emits[1]), g1)
  assert_eq(emit_predicate(emits[1]), "<http://ex/q>")
  assert_eq(emit_object(emits[1]), g2)
  assert_eq(emit_predicate(emits[2]), "<http://ex/r>")
  assert_eq(emit_object(emits[2]), "<http://ex/o>")
  // 混合方向主位链（!P^Q）官方语料未裁决；本机 hop 方向账 = 当步旗标口径：
  // 首边随末 op（^）反向出账 —— (g1,P,S) + (g2,Q,g1) + (g2,R,O)
  let (emits2, errors2) = parse_materialize(
    "<http://ex/s> !<http://ex/p>^<http://ex/q> <http://ex/r> <http://ex/o> .\n",
  )
  assert_eq(errors2.length(), 0)
  assert_eq(emits2.length(), 3)
  let h1 = emit_subject(emits2[0])
  let h2 = emit_subject(emits2[1])
  assert_true(h1.has_prefix("_:genid"))
  assert_true(h2.has_prefix("_:genid"))
  assert_false(h1 == h2)
  assert_eq(emit_predicate(emits2[0]), "<http://ex/p>")
  assert_eq(emit_object(emits2[0]), "<http://ex/s>")
  assert_eq(emit_predicate(emits2[1]), "<http://ex/q>")
  assert_eq(emit_object(emits2[1]), h1)
  assert_eq(emit_predicate(emits2[2]), "<http://ex/r>")
  assert_eq(emit_object(emits2[2]), "<http://ex/o>")
  // 直连裸链（无真谓词）官方非法 → 拒绝
  let (emits3, errors3) = parse_materialize(
    "<http://ex/s> !<http://ex/p>!<http://ex/q> <http://ex/o> .\n",
  )
  assert_eq(errors3.length(), 1)
  assert_eq(emits3.length(), 0)
}

///|
test "役3: 三跳链——中转节点逐跳 fresh（!p!q!r 双 genid 互异）" {
  let (emits, errors) = parse_materialize(
    "<http://ex/s> <http://ex/p>!<http://ex/q>!<http://ex/r> <http://ex/o> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  let g1 = emit_object(emits[0])
  let g2 = emit_subject(emits[2])
  assert_true(g1.has_prefix("_:genid"))
  assert_true(g2.has_prefix("_:genid"))
  assert_false(g1 == g2)
  assert_eq(emit_subject(emits[0]), "<http://ex/s>")
  assert_eq(emit_predicate(emits[0]), "<http://ex/p>")
  assert_eq(emit_subject(emits[1]), g1)
  assert_eq(emit_predicate(emits[1]), "<http://ex/q>")
  assert_eq(emit_object(emits[1]), g2)
  assert_eq(emit_predicate(emits[2]), "<http://ex/r>")
  assert_eq(emit_object(emits[2]), "<http://ex/o>")
}

///|
test "役3: 宾位链复合末跳 bnp——连接边 Dot 收口（官方形）" {
  // 旧钉输入（主位直连 + 复合谓词位）官方非法：路径主语后无真谓词 → 拒绝
  let (emits0, errors0) = parse_materialize(
    "<http://ex/s> !<http://ex/p> [ <http://ex/q> <http://ex/r> ] .\n",
  )
  assert_eq(errors0.length(), 1)
  assert_eq(emits0.length(), 0)
  // 官方形：宾位路径链 S P!Q [R T] ≡ (S,P,g1) + bnp 内部 (g2,R,T) + 连接边 (g1,Q,g2)
  let (emits, errors) = parse_materialize(
    "<http://ex/s> <http://ex/p>!<http://ex/q> [ <http://ex/r> <http://ex/t> ] .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  let g1 = emit_object(emits[0])
  assert_true(g1.has_prefix("_:genid"))
  assert_eq(emit_subject(emits[0]), "<http://ex/s>")
  assert_eq(emit_predicate(emits[0]), "<http://ex/p>")
  let g2 = emit_subject(emits[1])
  assert_true(g2.has_prefix("_:genid"))
  assert_false(g1 == g2)
  assert_eq(emit_predicate(emits[1]), "<http://ex/r>")
  assert_eq(emit_object(emits[1]), "<http://ex/t>")
  // 连接边 Dot 收口：g1 = 路径账 fresh，g2 = bnp 帧 fresh
  assert_eq(emit_subject(emits[2]), g1)
  assert_eq(emit_predicate(emits[2]), "<http://ex/q>")
  assert_eq(emit_object(emits[2]), g2)
}

///|
test "役3: 宾位链复合末跳集合——单 BNode 身份落连接边（官方形）" {
  // 主位直连形官方非法 → 拒绝
  let (emits0, errors0) = parse_materialize(
    "<http://ex/s> !<http://ex/p> ( <http://ex/a> <http://ex/b> ) .\n",
  )
  assert_eq(errors0.length(), 1)
  assert_eq(emits0.length(), 0)
  // 官方形：宾位路径链 S P!Q (A B) ≡ (S,P,g1) + (g1,Q,g2)；ADR-003a 集合零链
  let (emits, errors) = parse_materialize(
    "<http://ex/s> <http://ex/p>!<http://ex/q> ( <http://ex/a> <http://ex/b> ) .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  let g1 = emit_object(emits[0])
  assert_true(g1.has_prefix("_:genid"))
  assert_eq(emit_subject(emits[0]), "<http://ex/s>")
  assert_eq(emit_predicate(emits[0]), "<http://ex/p>")
  // ADR-003a 集合零链：无内部 quad，quad1 即连接边，g2 落宾位
  let g2 = emit_object(emits[1])
  assert_true(g2.has_prefix("_:genid"))
  assert_false(g1 == g2)
  assert_eq(emit_predicate(emits[1]), "<http://ex/q>")
  assert_eq(emit_subject(emits[1]), g1)
}

///|
test "役5 物化: a 失效——@keywords 未列出 → PrefName 裸名按 DefaultPrefixIRI 展开" {
  let (emits, errors) = parse_materialize(
    "@prefix : <http://dft/> .\n@keywords foo .\n:s a :o .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(emit_subject(emits[0]), "<http://dft/s>")
  // a 失格 = 冒号无前缀 PrefName → 默认前缀展开（非 rdf:type）
  assert_eq(emit_predicate(emits[0]), "<http://dft/a>")
  assert_eq(emit_object(emits[0]), "<http://dft/o>")
}

///|
test "役5 物化: a 复活——台账含 a 则 KeywordA 照常展开 rdf:type" {
  let (emits, errors) = parse_materialize(
    "@prefix : <http://dft/> .\n@keywords a .\n:s a :o .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(emit_subject(emits[0]), "<http://dft/s>")
  assert_eq(
    emit_predicate(emits[0]),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>",
  )
  assert_eq(emit_object(emits[0]), "<http://dft/o>")
}

///|
test "役6 物化: 倒装端到端——:a is :p of :b 序列化为 :b :p :a" {
  let (emits, errors) = parse_materialize(
    "@prefix : <http://dft/> .\n:a is :p of :b .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  // 语义序出账（引擎发射点已互换，物化层零感知）
  assert_eq(emit_subject(emits[0]), "<http://dft/b>")
  assert_eq(emit_predicate(emits[0]), "<http://dft/p>")
  assert_eq(emit_object(emits[0]), "<http://dft/a>")
}

///|
test "役6 物化: 'a' 倒装——KwA 出账 → rdf:type，主宾互换" {
  let (emits, errors) = parse_materialize(
    "@prefix : <http://dft/> .\n:x is a of :y .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(emit_subject(emits[0]), "<http://dft/y>")
  assert_eq(
    emit_predicate(emits[0]),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>",
  )
  assert_eq(emit_object(emits[0]), "<http://dft/x>")
}

///|
test "役7 物化: 等同端到端——:a = :b 展开谓词 owl:sameAs" {
  let (emits, errors) = parse_materialize(
    "@prefix : <http://dft/> .\n:a = :b .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(emit_subject(emits[0]), "<http://dft/a>")
  assert_eq(emit_predicate(emits[0]), "<http://www.w3.org/2002/07/owl#sameAs>")
  assert_eq(emit_object(emits[0]), "<http://dft/b>")
}

///|
test "役7 物化: 逗号连发——双 emit 同展开 owl:sameAs" {
  let (emits, errors) = parse_materialize(
    "@prefix : <http://dft/> .\n:a = :b, :c .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  assert_eq(emit_predicate(emits[0]), "<http://www.w3.org/2002/07/owl#sameAs>")
  assert_eq(emit_predicate(emits[1]), "<http://www.w3.org/2002/07/owl#sameAs>")
  assert_eq(emit_object(emits[0]), "<http://dft/b>")
  assert_eq(emit_object(emits[1]), "<http://dft/c>")
}

///|
test "役8: 注解壳主语物化——体 quad 主语合成 <<锚三元组原文>> TT 壳" {
  let (emits, errors) = parse_materialize(
    "<http://e/s> <http://e/p> <http://e/o> {| <http://e/q> <http://e/z> |} .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  // 主 quad：锚主语原样
  assert_eq(emit_subject(emits[0]), "<http://e/s>")
  // 体 quad：主语 = <<<s> <p> <o>>>（锚三元组原文整段，arena 合成）
  assert_eq(
    emit_subject(emits[1]),
    "<<<http://e/s> <http://e/p> <http://e/o>>>",
  )
  assert_eq(emit_object(emits[1]), "<http://e/z>")
}

///|
test "役8: 体区多 quad 同壳——逗号连发皆 TT 壳主语" {
  let (emits, errors) = parse_materialize(
    "<http://e/s> <http://e/p> <http://e/o> {| <http://e/q> <http://e/z1>, <http://e/z2> |} .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  assert_eq(
    emit_subject(emits[1]),
    "<<<http://e/s> <http://e/p> <http://e/o>>>",
  )
  assert_eq(
    emit_subject(emits[2]),
    "<<<http://e/s> <http://e/p> <http://e/o>>>",
  )
}

///|
/// 语法版本开关 `rdf12`（对齐 nquads 口径，ADR-32）：一个开关管两件事——
/// ① 方向后缀 `--ltr/--rtl`：1.2 放行 / 1.1 拒；② 转义代理：1.2 全禁（成对也不收）/
/// 1.1 成对合法。
test "深验: rdf12 语法版本开关——方向后缀 1.2 放行 / 1.1 拒 + 转义代理同向" {
  let with_dir = "<http://e/s> <http://e/p> \"x\"@ar--rtl .\n"
  let (emits12, errs12) = parse_materialize(with_dir, rdf12=true)
  assert_eq(emits12.length(), 1)
  assert_eq(errs12.length(), 0)
  let (emits11, errs11) = parse_materialize(with_dir, rdf12=false)
  assert_eq(emits11.length(), 0)
  assert_eq(errs11.length(), 1)
  let surro = "<http://e/s> <http://e/p> \"\\uD83C\\uDCA1\" .\n"
  let (e12, m12) = parse_materialize(surro, rdf12=true)
  assert_eq(e12.length(), 0)
  assert_eq(m12.length(), 1)
  let (e11, m11) = parse_materialize(surro, rdf12=false)
  assert_eq(e11.length(), 1)
  assert_eq(m11.length(), 0)
}
