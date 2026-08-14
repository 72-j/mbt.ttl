///|

///|
async test "collect test files" {
  // let test_dir = "src/tests/src/rdf/rdf11/rdf-n-triples"
  let output_file = "./src/benchmark/test_collected.nq"

  // 1. 读取测试文件列表
  // let dir = @fs.opendir(test_dir)
  // defer dir.close()

  // let list = dir
  //   .read_all()
  //   .filter_map(x => if x == "target" { None } else { Some(x) })
  // list.sort()

  // let nt_files = list.filter(x => x.has_suffix(".nt"))
  // debug("NT files: \{nt_files.length()}")

  // 2. 把所有测试用例写入一个文件
  // let mut combined = ""
  // for file in nt_files {
  //   let path = "\{test_dir}/\{file}"
  //   let content = @fs.read_file(path).text()
  //   combined = combined + content + "\n"
  // }

  // @fs.write_file(output_file, combined, create_mode=CreateOrTruncate)
  // debug("Written combined file: \{output_file}")

  // 3. 从汇总文件测试
  let data = @fs.read_file(output_file).binary().to_fixedarray()
  debug("Combined file size: \{data.length()} bytes")

  let parser = @lib.nquads_parser(data)
  let start = @bench.monotonic_clock_start()
  let parser = @lib.SliceParser::new(parser, data)

  let (quads, errors) = parser.parse_all()
  let elapsed = @bench.monotonic_clock_end(start)

  parser.inner.parser.lexer.destroy()

  debug("=== Results ===")
  debug("Quads: \{quads.length()}, Errors: \{errors.length()}")
  // 简单输出所有错误
  for i, e in errors {
    let (offset, len, line) = match e {
      StructSyntaxErr(_, line, span) => (span.0, span.1, line)
      SyntaxErr(_, span) => (span.0, span.1, 0)
      _ => (0, 0, 0)
      // ...
    }
    debug("Error[\{i}] at line \{line}: \{e}")
    let context = read_context(data, offset, len, before=40, after=40)
    debug("  Context: \{context}")
  }
  debug("Time: \{elapsed} µs")
}

///|
fn read_context(
  data : ArrayView[Byte],
  offset : Int,
  len : Int,
  before? : Int = 20,
  after? : Int = 20,
) -> String {
  let start = (offset - before).max(0)
  let end = (offset + len + after).min(data.length())

  let mut result = "..."

  // before
  for i = start; i < offset && i < end; i = i + 1 {
    result = result + byte_to_display(data[i])
  }

  result = result + "[>>>"

  // error
  for i = offset; i < offset + len && i < end; i = i + 1 {
    result = result + byte_to_display(data[i])
  }

  result = result + "<<<]"

  // after
  for i = offset + len; i < end; i = i + 1 {
    result = result + byte_to_display(data[i])
  }

  result + "..."
}

///|
fn byte_to_display(b : Byte) -> String {
  if b == b'\n' {
    "\\n"
  } else if b == b'\r' {
    "\\r"
  } else if b == b'\t' {
    "\\t"
  } else {
    b.to_char().to_string()
  }
}

///|
/// 带图名的三元组
test "nquads: valid triple with graph" {
  let data = "<http://example/s> <http://example/p> <http://example/o> <http://example/g> ."
  let bytes = @utf8.encode(data).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.Parser::from_bytes(bytes, engine)
  let parser = @lib.SliceParser::new(parser, bytes)

  let (quads, errs) = parser.parse_all()

  @debug.assert_eq(quads.length(), 1)
  @debug.assert_eq(errs.length(), 0)
}
