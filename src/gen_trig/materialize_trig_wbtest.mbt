// ===== 物化器测试辅助与用例（T14 归位：自 materialize_trig.mbt 迁出）=====

// ===== 物化器测试辅助（包内私有；inline test 直接可见） =====

///|
fn mat_bytes(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
/// view → String（与序列化器同口径：decode_lossy，严禁逐字节 to_char 拼多字节）
fn mat_vs(v : ArrayView[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(v))
}

///|
/// 全链路：解析 → 物化。data 由本函数持有（view 生命周期 = 调用方作用域）
fn mat_chain(input : String) -> (Array[@nquads.QuadEmit], Array[ParseError]) {
  let data = mat_bytes(input)
  let engine = TrigEngine::from_bytes(data)
  let sec = data[:]
  let slice = TrigSliceParser::new(engine, sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  if errors.length() > 0 {
    return ([], errors)
  }
  let mat = TrigMaterializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  mat.materialize_all(quads)
}

///|
let mat_empty : Array[Byte] = []

///|
/// 枚举载荷抽取（断言用）：变体不符返回空视图，断言自然爆
fn mat_subj(e : @nquads.QuadEmit) -> ArrayView[Byte] {
  match e.subject {
    Iri(v) => v
    BNode(v) => v
    PrefName(v) => v
    // 役9：TT 壳主语（注解体 quad）直通
    TripleTerm(v) => v
    _ => mat_empty[:]
  }
}

///|
fn mat_obj(e : @nquads.QuadEmit) -> ArrayView[Byte] {
  match e.object {
    Iri(v) => v
    BNode(v) => v
    Literal(v) => v
    TripleTerm(v) => v
    PrefName(v) => v
    Variable(v) => v
    Formula(v) => v
  }
}

///|
fn mat_graph(e : @nquads.QuadEmit) -> ArrayView[Byte] {
  match e.graph {
    Iri(v) => v
    BNode(v) => v
    None => mat_empty[:]
  }
}

///|
/// 判定图名位是否为默认图（None 变体）
fn mat_has_graph(e : @nquads.QuadEmit) -> Bool {
  match e.graph {
    None => false
    _ => true
  }
}

///|
test "物化: PrefName/DefaultPrefixIRI/图名 均展开为全 IRI" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\n@prefix : <http://dft/> .\nex:s ex:p ex:o .\n:s2 :p2 :o2 .\nex:g { ex:s3 ex:p3 ex:o3 . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  // quad1：ex:s ex:p ex:o（默认图）
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://example/s>")
  assert_eq(mat_vs(emits[0].predicate), "<http://example/p>")
  assert_eq(mat_vs(mat_obj(emits[0])), "<http://example/o>")
  assert_false(mat_has_graph(emits[0]))
  // quad2：DefaultPrefixIRI 展开 :s2 :p2 :o2
  assert_eq(mat_vs(mat_subj(emits[1])), "<http://dft/s2>")
  assert_eq(mat_vs(emits[1].predicate), "<http://dft/p2>")
  // quad3：图块区图名 ex:g 展开
  assert_eq(mat_vs(mat_graph(emits[2])), "<http://example/g>")
  assert_eq(mat_vs(mat_subj(emits[2])), "<http://example/s3>")
}

///|
test "物化: 'a' 缩写 → rdf:type，数值三型与布尔 → typed literal" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s a ex:C .\nex:n ex:i 42 ; ex:d 1.5 ; ex:x 1.0e3 ; ex:b true, false .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 6)
  // ex:s a ex:C → 谓词 = rdf:type
  assert_eq(
    mat_vs(emits[0].predicate),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>",
  )
  // 数值三型 + 布尔（第 2..6 条，pred/obj 成对）
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
    let (p, o) = expect[i]
    assert_eq(mat_vs(emits[i + 1].predicate), p)
    assert_eq(mat_vs(mat_obj(emits[i + 1])), o)
  }
}

///|
test "物化: 字面量后缀 —— @lang 保真 / ^^PrefName 展开 / ^^<IRI> 保真" {
  let (emits, errors) = mat_chain(
    "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n@prefix ex: <http://example/> .\nex:s ex:p \"lit\"@en-US .\nex:s ex:p \"x\"^^xsd:int .\nex:s ex:p \"y\"^^<http://d.example/dt> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  assert_eq(mat_vs(mat_obj(emits[0])), "\"lit\"@en-US")
  assert_eq(
    mat_vs(mat_obj(emits[1])),
    "\"x\"^^<http://www.w3.org/2001/XMLSchema#int>",
  )
  assert_eq(mat_vs(mat_obj(emits[2])), "\"y\"^^<http://d.example/dt>")
}

///|
test "物化: 引用三元组壳整段保真 + bnode 图名零拷贝" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p << <http://a> <http://b> <http://c> >> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_obj(emits[0])), "<< <http://a> <http://b> <http://c> >>")
}

///|
test "物化: bnode 图名块" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\n_:b { ex:s2 ex:p2 ex:o2 . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_graph(emits[0])), "_:b")
}

///|
test "物化: 全链路 → nquads Serializer(format=Quad) 输出" {
  let data = mat_bytes(
    "@prefix ex: <http://example/> .\nex:s ex:p ex:o .\nex:s ex:i 42 .\n",
  )
  let engine = TrigEngine::from_bytes(data)
  let sec = data[:]
  let slice = TrigSliceParser::new(engine, sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  assert_eq(errors.length(), 0)
  let mat = TrigMaterializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, merrs) = mat.materialize_all(quads)
  assert_eq(merrs.length(), 0)
  let ser = @nquads.Serializer::new(format=@nquads.SerializeFormat::Quad)
  match ser.serialize_all(emits) {
    Ok(out) =>
      assert_eq(
        out, "<http://example/s> <http://example/p> <http://example/o> .\n<http://example/s> <http://example/i> \"42\"^^<http://www.w3.org/2001/XMLSchema#integer> .\n",
      )
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}

///|
/// 分层链路：(emits, 深验错误, 解析错误)——pin 深验层：parse 层零错、深验层报错
fn mat_chain_deep(
  input : String,
  deep : Bool,
  rdf12? : Bool = true,
) -> (Array[@nquads.QuadEmit], Array[ParseError], Array[ParseError]) {
  let data = mat_bytes(input)
  let engine = TrigEngine::from_bytes(data)
  let sec = data[:]
  let slice = TrigSliceParser::new(engine, sec, lenient=true)
  let (quads, perrs) = slice.parse_all()
  if perrs.length() > 0 {
    return ([], [], perrs)
  }
  let mat = TrigMaterializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
    rdf12~,
  )
  let (emits, merrs) = mat.materialize_all(quads, deep_validate=deep)
  (emits, merrs, [])
}

///|
test "深验: 默认开——langtag/相对IRI/banned datatype/孤代理 全部进 errors" {
  // 1) langtag.mbt 拦字节版词法放行的标签（extlang 超限）
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@ab-abc-abc-abc-abc .\n", true,
  )
  assert_eq(p1.length(), 0) // 表层面（字节版）放行
  assert_eq(e1.length(), 0) // 不流到序列化
  assert_eq(m1.length(), 1)
  // 2) 相对 IRI 无 base：物化层 iri_term 直接拒（改写不受开关门控，base-bad 桶口径）
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <relative/path> .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(e2.length(), 0)
  assert_eq(m2.length(), 1)
  // 3) banned datatype：rdf:langString 禁显式使用
  let (e3, m3, p3) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#langString> .\n",
    true,
  )
  assert_eq(p3.length(), 0)
  assert_eq(e3.length(), 0)
  assert_eq(m3.length(), 1)
  // 4) 孤代理转义（surrogate 桶）
  let (e4, m4, p4) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"a\\uDC00b\" .\n", true,
  )
  assert_eq(p4.length(), 0)
  assert_eq(e4.length(), 0)
  assert_eq(m4.length(), 1)
}

///|
test "@base: 相对 IRI 四位改写（路径合并 / 同文档引用 / dot-segment / 图名位）" {
  let (emits, errors) = mat_chain(
    "@base <http://ex.org/a/b> .\n@prefix ex: <http://example/> .\n<rel> <p> <#frag> .\n<g> { ex:s ex:p <../c> . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  // 主语位 <rel>：路径合并 /a/b + rel → /a/rel（RFC 3986 5.2.2）
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://ex.org/a/rel>")
  // 谓词位 <p> → /a/p
  assert_eq(mat_vs(emits[0].predicate), "<http://ex.org/a/p>")
  // 宾语位 <#frag>：同文档引用 → 继承 base 路径 /a/b + #frag
  assert_eq(mat_vs(mat_obj(emits[0])), "<http://ex.org/a/b#frag>")
  // 图名位 <g> → /a/g
  assert_eq(mat_vs(mat_graph(emits[1])), "<http://ex.org/a/g>")
  // <../c>：合并 /a/../c → dot-segment 移除 → /c（宾语位）
  assert_eq(mat_vs(mat_obj(emits[1])), "<http://ex.org/c>")
  // PrefName 词项不受 base 影响（零拷贝展开口径不变）
  assert_eq(mat_vs(mat_subj(emits[1])), "<http://example/s>")
}

///|
test "@base: 无 base 相对 IRI 物化层直接拒（开关关也拒——改写非验证）" {
  // 开关开：错误来自 materialize_quad 的改写路径（深验门未及）
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <rel> .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 开关关：仍拒——iri_term 是物化语义，不受 deep_validate 门控
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <rel> .\n", false,
  )
  assert_eq(p2.length(), 0)
  assert_eq(e2.length(), 0)
  assert_eq(m2.length(), 1)
}

///|
test "@base: 绝对 base 必要 + 相对 base 拒绝" {
  // 相对 @base 自身（无 scheme）→ 按无 base 论，报错
  let (e1, m1, p1) = mat_chain_deep(
    "@base <relbase> .\n<rel> <p> <o> .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 绝对词项不受 base 影响：零拷贝原样
  let (e2, m2, p2) = mat_chain_deep(
    "@base <http://ex.org/a/b> .\n<http://abs.org/x> <http://abs.org/p> <http://abs.org/o> .\n",
    true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
  assert_eq(mat_vs(mat_subj(e2[0])), "<http://abs.org/x>")
}

///|
test "深验: TT 壳内 term-kind —— 数字主语拒 / 字面量谓词拒 / 合法形态保真" {
  // 1) 数字主语（trig12-syntax-bad-02 同款：三项齐全，仅深验门可拦）
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <<3 ex:b ex:c >> .\n", true,
  )
  assert_eq(p1.length(), 0) // parse 层三项齐全放行
  assert_eq(e1.length(), 0) // 不流到序列化
  assert_eq(m1.length(), 1) // 深验门拦下
  // 2) 字面量作谓词
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << ex:a \"lit\" ex:c >> .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(e2.length(), 0)
  assert_eq(m2.length(), 1)
  // 3) bnode 作谓词
  let (e3, m3, p3) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << ex:a _:b ex:c >> .\n", true,
  )
  assert_eq(p3.length(), 0)
  assert_eq(e3.length(), 0)
  assert_eq(m3.length(), 1)
  // 4) 合法形态：壳内字面量宾语 + 布尔谓词位外的全部种类放行，壳整段保真
  let (e4, m4, p4) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << ex:a ex:b \"lit\" >> .\n", true,
  )
  assert_eq(p4.length(), 0)
  assert_eq(m4.length(), 0)
  assert_eq(e4.length(), 1)
  assert_eq(mat_vs(mat_obj(e4[0])), "<< ex:a ex:b \"lit\" >>")
  // 5) 嵌套壳：合法递归放行 / 内层数字谓词递归拒
  let (e5, m5, p5) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << << ex:a ex:b ex:c >> ex:p2 ex:o2 >> .\n",
    true,
  )
  assert_eq(p5.length(), 0)
  assert_eq(m5.length(), 0)
  assert_eq(e5.length(), 1)
  let (e6, m6, p6) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << << ex:a 3 ex:c >> ex:p2 ex:o2 >> .\n",
    true,
  )
  assert_eq(p6.length(), 0)
  assert_eq(e6.length(), 0)
  assert_eq(m6.length(), 1)
}

///|
test "深验: deep_validate=false 穿透 + 方向后缀合法放行 / 大写方向拒" {
  // 开关关：同一输入直通
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@ab-abc-abc-abc-abc .\n", false,
  )
  assert_eq(p1.length(), 0)
  assert_eq(m1.length(), 0)
  assert_eq(e1.length(), 1)
  // RDF 1.2 方向后缀：拆 --rtl 后基础标签合法 → 放行
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@ar--rtl .\n",
    true,
    rdf12=true,
  )
  assert_eq(p2.length(), 0)
  // 1.1 模式（显式 rdf12=false）：方向后缀是 1.2 特征 ⇒ 拒（0 emit + 1 merr）
  let (e1b, m1b, _) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@ar--rtl .\n",
    true,
    rdf12=false,
  )
  assert_eq(e1b.length(), 0)
  assert_eq(m1b.length(), 1)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
  // 方向后缀大写非法（小写精确）
  let (e3, m3, p3) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@en--LTR .\n", true,
  )
  assert_eq(p3.length(), 0)
  assert_eq(e3.length(), 0)
  assert_eq(m3.length(), 1)
}

///|
test "词法加宽: PN_LOCAL_ESC 解码 / 百分号保真 / 内部点与尾点回退 / 多字节" {
  let pre = "@prefix : <http://www.w3.org/2013/TurtleTests/> .\n"
  // 1) 转义族整段解码（pname-esc-01 同款）：\X → X 进 IRI
  let (e1, m1, p1) = mat_chain_deep(pre + ":s :p :\\~\\.\\-\\! .\n", true)
  assert_eq(p1.length(), 0)
  assert_eq(m1.length(), 0)
  assert_eq(e1.length(), 1)
  assert_eq(mat_vs(mat_obj(e1[0])), "<http://www.w3.org/2013/TurtleTests/~.-!>")
  // 2) 百分号对保真（%25 起始 / %3E 中部，syntax-prefix-04/09 同款）
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix : <http://a.example/>.\n:%25 <http://a.example/p> :a%3Eb .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
  assert_eq(mat_vs(mat_subj(e2[0])), "<http://a.example/%25>")
  assert_eq(mat_vs(mat_obj(e2[0])), "<http://a.example/a%3Eb>")
  // 3) 内部点 + 尾点回退（ln-dots 同款）：:o..2. → local "o..2" + 语句点
  let (e3, m3, p3) = mat_chain_deep(pre + ":s..2 :p..2 :o..2.\n", true)
  assert_eq(p3.length(), 0)
  assert_eq(m3.length(), 0)
  assert_eq(e3.length(), 1)
  assert_eq(
    mat_vs(mat_subj(e3[0])),
    "<http://www.w3.org/2013/TurtleTests/s..2>",
  )
  assert_eq(mat_vs(mat_obj(e3[0])), "<http://www.w3.org/2013/TurtleTests/o..2>")
  // 4) 前缀名含内部点（ns-dots 同款）
  let (e4, m4, p4) = mat_chain_deep(
    "@prefix e.g: <http://www.w3.org/2013/TurtleTests/> .\ne.g:s e.g:p e.g:o .\n",
    true,
  )
  assert_eq(p4.length(), 0)
  assert_eq(m4.length(), 0)
  assert_eq(e4.length(), 1)
  assert_eq(mat_vs(mat_subj(e4[0])), "<http://www.w3.org/2013/TurtleTests/s>")
  // 5) 多字节非首字符扩展（non_leading_extras 同款）+ 数字首 local
  let (e5, m5, p5) = mat_chain_deep(
    "@prefix p: <http://a.example/>.\np:a·̀ͯ‿.⁀ <http://a.example/p> p:3.s .\n",
    true,
  )
  assert_eq(p5.length(), 0)
  assert_eq(m5.length(), 0)
  assert_eq(e5.length(), 1)
  assert_eq(mat_vs(mat_subj(e5[0])), "<http://a.example/a·̀ͯ‿.⁀>")
  assert_eq(mat_vs(mat_obj(e5[0])), "<http://a.example/3.s>")
}

///|
test "深验: 长串扩跑+后缀拒（bad-string-06）/ 无后缀扩并放行（LITERAL_LONG2）" {
  // 扩跑且紧跟 @lang 后缀 → 深验拒
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"\"\"abc\"\"\"\"@en .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 同形态无后缀：贪右闭壳扩并恰无后缀 → 放行（turtle LITERAL_LONG2 14B 正例口径）
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"\"\"test-\\\"\"\"\" .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
}

///|
test "深验: IRI 转义解码码点——代理/禁字符拒（good escape, bad character）" {
  // \uDC00 代理码点
  let (_e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <http://example/\\uDC00> .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(m1.length(), 1)
  // \u0022 解码为 `"`（IRI 禁字符）
  let (_e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <http://example/\\u0022> .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 1)
}

///|
test "深验: rdf12 模式开关——1.2 成对代理拒 / 1.1 成对合法（test-38 口径）" {
  let lit = "@prefix ex: <http://example/> .\nex:s ex:p \"\\uD83C\\uDCA1\" .\n"
  // 开关开（RDF 1.2）：成对代理也拒——每个 UCHAR 须独立为标量值
  let (e1, m1, p1) = mat_chain_deep(lit, true, rdf12=true)
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 开关关（1.1 宽容，显式）：成对合法放行（孤代理仍拒）
  let (e2, m2, p2) = mat_chain_deep(lit, true, rdf12=false)
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
}
