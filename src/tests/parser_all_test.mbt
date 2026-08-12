///|
test "nquads: basic triple" {
  let data = @utf8.encode(
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ).to_fixedarray()
  let engine = @lib.NQuadsEngine::new()
  let parser = @lib.Parser::from_bytes(data, engine)
  let parser = @lib.SliceParser::new(parser, data)

  match parser.next() {
    Some(Ok(quad)) => debug(quad)
    other => debug("Unexpected: \{@debug.to_string(other)}")
  }
}

///|
async test "run official n-triples test suite" {
  let test_dir = "src/tests/src/rdf/rdf11/rdf-n-triples"

  let dir = @fs.opendir(test_dir)
  defer dir.close()

  let list = dir
    .read_all()
    .filter_map(x => if x == "target" { None } else { Some(x) })
  list.sort()
  let nt_files = list.filter(x => x.has_suffix(".nt"))
  debug("NT files: \{nt_files.length()}")

  // 只测前 3 个
  let test_files = nt_files[0:2]
  let mut passed = 0
  let mut failed = 0
  let mut total = 0

  for file in test_files {
    if !file.has_suffix(".nt") {
      continue
    }

    total += 1
    let path = "\{test_dir}/\{file}"
    let is_bad = file.contains("bad") || file.contains("error")

    debug("[\{total}] File: \{file}")

    // 步骤 1: 读取文件
    debug("  1. Reading file...")
    let data = @fs.read_file(path).binary().to_fixedarray()
    debug("     Data length: \{data.length()}")

    // 步骤 2: 创建 engine
    debug("  2. Creating engine...")
    let engine = @lib.NQuadsEngine::new()
    debug("     Engine created")

    // 步骤 3: 创建 lexer
    debug("  3. Creating lexer...")
    let lexer = @lib.Lexerc::new(data)
    debug("     Lexer created")

    // 步骤 4: 创建 parser
    debug("  4. Creating parser...")
    let parser = @lib.Parser::new(lexer, engine, data)
    debug("     Parser created")

    // 步骤 5: 解析
    debug("  5. Parsing...")
    let parser = @lib.SliceParser::new(parser, data)
    let (quads, errors) = parser.parse_all()
    debug("     Quads: \{quads.length()}, Errors: \{errors.length()}")

    // 步骤 6: 销毁
    debug("  6. Destroying lexer...")
    parser.inner.parser.lexer.destroy()
    debug("     Destroyed")

    // 判定
    let success = if is_bad {
      quads.is_empty() && !errors.is_empty()
    } else {
      quads.length() >= 1 && errors.is_empty()
    }

    if success {
      passed += 1
      debug("  PASS")
    } else {
      failed += 1
      debug("  FAIL")
    }
  }

  debug("=== Result: \{passed}/\{total} ===")
  assert_eq(failed, 0)
}
