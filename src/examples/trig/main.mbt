///|
/// TriG 示例总入口，顺序执行多个 case
async fn main {
  let path = "./example.trig"
  @async.with_task_group() <| root => {
    root.add_defer(() => @fs.remove(path))

    case_basic()
    case_prefix_and_base()
    case_blank_node_graph()
    case_collection_nested()
    case_relpath_under_base()
    case_turtle_dialect()
    case_serialize_strict_drop()
    case_at_prefixed_directives()

    println("done: all trigger samples printed")
  }
}

///|
/// case_basic: 基础 TriG，混合默认图与命名图
async fn case_basic() -> Unit {
  println("-- case_basic --")
  let content =
    #|<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .
    #|<http://ex.org/s2> <http://ex.org/p2> <http://ex.org/o2> .
    #|<http://ex.org/g3> {
    #|  <http://ex.org/s4> <http://ex.org/p4> <http://ex.org/o4> .
    #|}
  run_demo(content)
}

///|
/// case_prefix_and_base: 展示 prefix/base 关键字用法
async fn case_prefix_and_base() -> Unit {
  println("-- case_prefix_and_base --")
  let content =
    #|@prefix ex: <http://ex.org/> .
    #|@base <http://ex.org/base/> .
    #|ex:s1 ex:p1 ex:o1 .
    #|ex:s2 ex:p2 </relative> .
  run_demo(content)
}

///|
/// case_blank_node_graph: 图名位为空白节点
async fn case_blank_node_graph() -> Unit {
  println("-- case_blank_node_graph --")
  let content =
    #|<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .
    #|_:lbl {
    #|  _:b1 <http://ex.org/p> <http://ex.org/o> .
    #|}
  run_demo(content)
}

///|
/// case_collection_nested: 使用列表和嵌套结构
async fn case_collection_nested() -> Unit {
  println("-- case_collection_nested --")
  let content =
    #|_:subject <http://ex.org/hasList> ("a" "b" "c") .
    #|_:subject <http://ex.org/nestedList> (1 2 (3 4)) .
  run_demo(content)
}

///|
/// case_relpath_under_base: 展示相对 IRI 在 base 下解析
async fn case_relpath_under_base() -> Unit {
  println("-- case_relpath_under_base --")
  let content =
    #|@base <http://example.org/base/> .
    #|<http://example.org/s> <http://example.org/p> <../other> .
    #|<http://example.org/s> <http://example.org/p> <./same/dir> .
  run_demo(content)
}

///|
/// case_turtle_dialect: 仅解析 Turtle 子集，图块区不被允许
async fn case_turtle_dialect() -> Unit {
  println("-- case_turtle_dialect --")
  let content =
    #|@prefix ex: <http://ex.org/> .
    #|ex:s ex:p ex:o .
  run_demo_turtle(content)
}

///|
/// case_serialize_strict_drop: 展示序列化时 Turtle 模式下的 strict/drop 行为
async fn case_serialize_strict_drop() -> Unit {
  println("-- case_serialize_strict_drop --")
  let content =
    #|@prefix ex: <http://ex.org/> .
    #|ex:g { ex:s ex:p ex:o . }
  run_demo_strict_drop(content)
}

///|
/// case_at_prefixed_directives: 展示 @ 风格的指令名前缀
async fn case_at_prefixed_directives() -> Unit {
  println("-- case_at_prefixed_directives --")
  let content =
    #|<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .
    #|@prefix ex: <http://ex.org/> .
    #|@base <http://ex.org> .
    #|ex:s ex:p ex:o .
  run_demo(content)
}

///|
/// 公共演示管线：写盘 -> 读字节 -> 解析（统计/错误）-> 物化 -> 序列化打印
async fn demo(content : String, ser : @gen_trig.TrigSerializer) -> Unit {
  let path = "./example.trig"
  @fs.write_file(path, content, create_mode=CreateOrTruncate)
  let data = @fs.read_file(path).binary()
  let engine = @gen_trig.TrigEngine::from_bytes(data.to_array())
  let slice = @gen_trig.TrigSliceParser::new(engine, Bytes::to_array(data))
  let (quad_spans, parse_errors) = slice.parse_all()
  println(
    "parsed quads=\{quad_spans.length()}, errors=\{parse_errors.length()}",
  )
  for err in parse_errors {
    println("   ERR: \{err}")
  }
  let mat = @gen_trig.TrigMaterializer::new(
    data.to_array()[:],
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, mat_errors) = mat.materialize_all(quad_spans)
  for err in mat_errors {
    println("   MAT-ERR: \{err}")
  }
  match ser.serialize(emits) {
    Ok(text) => if text.length() > 0 { println(text) }
    Err(err) => println("   SER-ERR: \{err}")
  }
}

///|
/// 通用执行器：TriG 格式化输出（默认图三元组 + 命名图块区）
async fn run_demo(content : String) -> Unit {
  demo(content, @gen_trig.TrigSerializer::new())
}

///|
/// Turtle 方言演示：Turtle 格式输出
async fn run_demo_turtle(content : String) -> Unit {
  demo(
    content,
    @gen_trig.TrigSerializer::new(format=@gen_trig.SerializeFormat::Turtle),
  )
}

///|
/// strict/drop 序列化演示：同一输入两种图名策略对比
async fn run_demo_strict_drop(content : String) -> Unit {
  println("-- strict --")
  demo(
    content,
    @gen_trig.TrigSerializer::new(format=@gen_trig.SerializeFormat::Turtle),
  )
  println("-- drop --")
  demo(
    content,
    @gen_trig.TrigSerializer::new(
      format=@gen_trig.SerializeFormat::Turtle,
      graph_policy=@gen_trig.GraphPolicy::Drop,
    ),
  )
}
