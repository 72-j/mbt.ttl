///|
/// Parse N-Quads file example
///
/// This example demonstrates how to parse N-Quads format RDF data from a file.
/// N-Quads is a line-based format for RDF triples/quads.
async fn main {
  demo_all()
  validate_mode_demo()
}

///|
/// 档位用法（B2）：**默认 Deep / 显式 Light** 各跑一次——README「档位分档」片段的可编译出处。
/// 示例包**不可加 `@nquads` 别名**（与包自身同名），故用默认别名 `@gen_nquads`；写盘须带 `create_mode`。
async fn validate_mode_demo() -> Unit {
  @async.with_task_group() <| root => {
    let path = "./mode_demo.nq"
    root.add_defer(() => @fs.remove(path))
    let content =
      #|<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .
      #|<http://ex.org/s2> <http://ex.org/p2> <http://ex.org/o2> .
    @fs.write_file(path, @utf8.encode(content), create_mode=CreateOrTruncate)
    let data = @fs.read_file(path).binary().to_fixedarray()
    let deep = @gen_nquads.SliceParser::new(
      @gen_nquads.NQuadsEngine::from_bytes(Array::from_fixed_array(data)),
      data[:],
    )
    let (q1, _) = deep.parse_all()
    let (e1, _) = @gen_nquads.materialize_all(q1)
    let light = @gen_nquads.SliceParser::new(
      @gen_nquads.NQuadsEngine::from_bytes(Array::from_fixed_array(data)),
      data[:],
      mode=@gen_nquads.ValidateMode::Light,
    )
    let (q2, _) = light.parse_all()
    let (e2, _) = @gen_nquads.materialize_all(q2)
    println(
      "档位演示：Deep quads=\{e1.length()} / Light quads=\{e2.length()}（两档等价 ⇒ 轻验不误拒）",
    )
  }
}

///|
async test "档位冒烟：Deep 与 Light 两档 quad 数等价（轻验不误拒）" {
  validate_mode_demo()
}

///|
/// 冒烟/演示本体（wbtest 直调同链；main 只留进程入口）
async fn demo_all() -> Unit {
  // Create a task group for cleanup
  @async.with_task_group() <| root => {
    let path = "./example.nq"
    root.add_defer(() => @fs.remove(path))

    // Sample N-Quads content
    let content =
      #|<http://ex.org/s1> <http://ex.org/p1> <http://ex.org/o1> .
      #|<http://ex.org/s2> <http://ex.org/p2> <http://ex.org/o2> .
      #|<http://ex.org/s3> <http://ex.org/p3> <http://ex.org/o3> <http://ex.org/g3> .

    // Write content to file
    @fs.write_file(path, content, create_mode=CreateOrTruncate)
    println("Written N-Quads content to: \{path}")

    // Read file content as binary
    let data = @fs.read_file(path).binary()
    println("Data length: \{data.length()} bytes")

    // Create parser
    let engine = @gen_nquads.NQuadsEngine::from_bytes(data.to_array())
    let slice = @gen_nquads.SliceParser::new(engine, Bytes::to_array(data))

    // Parse all quads
    println("")
    println("=== Parsing N-Quads ===")

    let (quad_spans, parse_errors) = slice.parse_all()

    // Print parse errors
    for err in parse_errors {
      println("Parse Error: \{err}")
    }

    println("Parsed \{quad_spans.length()} quads")

    // Materialize
    println("")
    println("=== Materializing ===")

    let (quads, mat_errors) = @gen_nquads.materialize_all(quad_spans)

    println("Materialized \{quads.length()} quads")
    // Print materialize errors

    for err in mat_errors {
      println("Materialize Error: \{err}")
    }

    println("Materialized \{quads.length()} quads")

    // Serialize and print
    println("")
    println("=== Serialized Output ===")

    let output = match
      @gen_nquads.Serializer::new(format=@gen_nquads.SerializeFormat::Quad).serialize_all(
        quads,
      ) {
      Ok(value) => value
      Err(error) => {
        println("Serialize Error: \{error}")
        ""
      }
    }
    println(output)

    // Summary
    println("")
    println("=== Summary ===")
    println("Total quads: \{quads.length()}")
    println("Parse errors: \{parse_errors.length()}")
    println("Materialize errors: \{mat_errors.length()}")
  }
}
