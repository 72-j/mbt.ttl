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
    let data = @fs.read_file(path).binary().to_fixedarray()
    println("Data length: \{data.length()} bytes")

    // Create parser
    let engine = @lib.NQuadsEngine::new()
    let parser = @lib.Parser::from_bytes(data, engine)
    let slice = @lib.SliceParser::new(parser, data)

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

    let (quads, mat_errors) = @lib.materialize_all(quad_spans, data)

    // Print materialize errors
    for err in mat_errors {
      println("Materialize Error: \{err}")
    }

    println("Materialized \{quads.length()} quads")

    // Serialize and print
    println("")
    println("=== Serialized Output ===")

    let serializer = @lib.Serializer::new(data)
    let output = serializer.serialize_all(quads)
    println(output)

    // Summary
    println("")
    println("=== Summary ===")
    println("Total quads: \{quads.length()}")
    println("Parse errors: \{parse_errors.length()}")
    println("Materialize errors: \{mat_errors.length()}")
  }
}
