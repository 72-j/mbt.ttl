///|
/// Parse N-Quads file example
///
/// This example demonstrates how to parse N-Quads format RDF data from a file.
/// N-Quads is a line-based format for RDF triples/quads.
async fn main {
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
    let engine = @nquads.NQuadsEngine::from_bytes(data.to_array())
    let slice = @nquads.SliceParser::new(engine, Bytes::to_array(data))

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

    let (quads, mat_errors) = @nquads.materialize_all(quad_spans)

    println("Materialized \{quads.length()} quads")
    // Print materialize errors

    for err in mat_errors {
      println("Materialize Error: \{err}")
    }

    println("Materialized \{quads.length()} quads")

    // Serialize and print
    println("")
    println("=== Serialized Output ===")

    let output = match (@nquads.Serializer::new(format=@nquads.SerializeFormat::Quad)).serialize_all(quads) {
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
