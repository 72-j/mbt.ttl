///|
test "nquads: basic triple" {
  let data =
    #|_:o <http://example/s> <http://example/p> . # comment

  let data = @utf8.encode(data).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.Parser::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(quad)) => debug(quad)
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}

///|

///|
test "nquads: basic triple all" {
  let data =
    #| <http://example/s> _:o <http://example/p> . # comment
  let data = @utf8.encode(data).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.Parser::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  let (quad_spans, errs) = parser.parse_all()

  for quad in quad_spans {
    debug("Quad:")
    debug(quad)
  }
  for err in errs {
    debug("Error: \{err}")
  }
}

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
    debug("Error[\{i}]: \{e}")
    let (offset, len) = e.to_span()
    let context = read_context(data, offset, len, before=20, after=20)
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

  let mut ctx = ""
  for i = start; i < end; i = i + 1 {
    let c = data[i]
    if c == b'\n' {
      ctx = ctx + "\\n"
    } else if c == b'\r' {
      ctx = ctx + "\\r"
    } else {
      ctx = ctx + c.to_char().to_string()
    }
  }

  // 在错误位置插入标记
  let marker = (offset - start).min(ctx.length())
  let marker_end = (offset + len - start).min(ctx.length())

  let before_part = ctx[0:marker]
  let error_part = ctx[marker:marker_end]
  let after_part = ctx[marker_end:ctx.length()]

  "...\{before_part}[>>>\{error_part}<<<]\{after_part}..."
}
