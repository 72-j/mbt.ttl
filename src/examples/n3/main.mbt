///|
/// N3 示例总入口：顺序跑若干 N3 特性 case（公式/规则/集合/属性列表/路径/@keywords），
/// 每个 case 走"解析 → 物化 → 序列化打印"同一条管线（API 全部来自 `gen_n3v2` 公共面）。
async fn main {
  let path = "./example.n3"
  @async.with_task_group() <| root => {
    root.add_defer(() => @fs.remove(path))

    case_basic()
    case_prefix_and_base()
    case_formula_and_rule()
    case_collection_and_bnode()
    case_operators()
    case_keywords()

    println("done: all n3 samples printed")
  }
}

///|
/// 公共演示管线：写盘 → 读字节 → 解析（统计/错误）→ 物化 → 序列化打印
async fn demo(content : String) -> Unit {
  let path = "./example.n3"
  @fs.write_file(path, content, create_mode=CreateOrTruncate)
  let data = @fs.read_file(path).binary()
  let engine = @gen_n3v2.N3Engine::from_bytes(data.to_array())
  let slice = @gen_n3v2.N3SliceParser::new(engine, Bytes::to_array(data))
  let (quad_spans, parse_errors) = slice.parse_all()
  println(
    "parsed quads=\{quad_spans.length()}, errors=\{parse_errors.length()}",
  )
  for err in parse_errors {
    println("   ERR: \{err}")
  }
  // 物化：前缀账本与 base 链经窄入口取出（ctx 已收为包内可见）
  let mat = @gen_n3v2.N3Materializer::new(
    data.to_array()[:],
    slice.prefixes(),
    bases=slice.bases(),
  )
  let (emits, mat_errors) = mat.materialize_all(quad_spans)
  for err in mat_errors {
    println("   MAT-ERR: \{err}")
  }
  match @gen_n3v2.N3Serializer::new().serialize(emits) {
    Ok(text) => if text.length() > 0 { println(text) }
    Err(err) => println("   SER-ERR: \{err}")
  }
}

///|
/// case_basic：最朴素的 N3 三元组
async fn case_basic() -> Unit {
  println("-- case_basic --")
  let content =
    #|<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .
  demo(content)
}

///|
/// case_prefix_and_base：`@prefix` 与 `@base` 指令（相对 IRI 按 base 解析）
async fn case_prefix_and_base() -> Unit {
  println("-- case_prefix_and_base --")
  let content =
    #|@prefix ex: <http://ex.org/> .
    #|@base <http://ex.org/base/> .
    #|ex:s ex:p <rel> .
  demo(content)
}

///|
/// case_formula_and_rule：公式 `{ ... }`（不透明值）+ 规则 `=>`（N3 核心特性）
async fn case_formula_and_rule() -> Unit {
  println("-- case_formula_and_rule --")
  let content =
    #|@prefix ex: <http://ex.org/> .
    #|{ ex:a ex:b ex:c } => { ex:c ex:b ex:a } .
    #|ex:holder ex:rule { ex:a ex:b ex:c } .
  demo(content)
}

///|
/// case_collection_and_bnode：集合 `( ... )` 与属性列表 `[ ... ]`（fresh 节点）
async fn case_collection_and_bnode() -> Unit {
  println("-- case_collection_and_bnode --")
  let content =
    #|@prefix ex: <http://ex.org/> .
    #|ex:s ex:list ( 1 2 3 ) .
    #|ex:s ex:node [ ex:p ex:o ] .
  demo(content)
}

///|
/// case_operators：N3 操作符谓词——`=>`（蕴含）/ `<=`（被蕴含）/ `=`（等同）
async fn case_operators() -> Unit {
  println("-- case_operators --")
  let content =
    #|@prefix ex: <http://ex.org/> .
    #|ex:a ex:p ex:b .
    #|{ ex:a ex:p ex:b } => { ex:b ex:p ex:a } .
    #|{ ex:y ex:q ex:x } <= { ex:x ex:q ex:y } .
    #|ex:m = ex:n .
  demo(content)
}

///|
/// case_keywords：`@keywords` 声明 + `a` 缩写（`a` → rdf:type）
async fn case_keywords() -> Unit {
  println("-- case_keywords --")
  let content =
    #|@keywords a .
    #|@prefix ex: <http://ex.org/> .
    #|ex:s a ex:C .
  demo(content)
}
