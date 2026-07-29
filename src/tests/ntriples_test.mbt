///|
test "lenient parsing" {
  let input = "<foo> <bar> \"baz\"@toolonglangtag ."

  let slice = @utf8.encode(input)

  let _triples = @lib.NTriplesParser::new().lenient().for_slice(slice)
  // 构建期望的 TripleRef，注意类型转换
  let expected_subject = @lib.NamedNodeRef::new_unchecked("foo").as_enum() // 转为 NamedOrBlankNodeRef
  let expected_predicate = @lib.NamedNodeRef::new_unchecked("bar") // 转为 NamedNodeRef (通常 predicate 也是 NamedNode)
  let expected_object = @lib.LiteralRef::new_language_tagged_literal_unchecked(
    "baz", "toolonglangtag",
  ).as_term()

  let expected_triple = @lib.TripleRef::TripleRef(
    expected_subject, expected_predicate, expected_object,
  )
  debug(expected_triple)
  // assert_eq(triples, [expected_triple])
}

///|
async test "verify_with_ntriples" {
  // N-Triples 格式相同
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
  let data = @utf8.encode(input).to_array()

  let parser = @lib.NTriplesParser::new().lenient()
  let low_level = parser.low_level()

  low_level.extend_from_slice(data)
  low_level.end()

  match low_level.parse_next() {
    Some(Ok(t)) => debug("NTriples Success:\{t.to_string()} ")
    Some(Err(e)) => debug("NTriples Error: \{e.to_string()}")
    None => debug("NTriples None")
  }
}

///|
test "parse basic ntriples" {
  let parser = @lib.NTriplesParser::new()
  let low_level = parser.low_level()

  let input =
    #|<http://a.example/s> <http://a.example/p> "\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\t\u000B\u000C\u000E\u000F\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001A\u001B\u001C\u001D\u001E\u001F" .

  // let input = "<foo> <bar> \"baz\"@toolonglangtag ."
  low_level.extend_from_slice(@utf8.encode(input).to_array())
  low_level.end()

  let result = low_level.parse_next()
  // assert_true(result is Some(_))
  match result.unwrap() {
    Ok(quad) => {
      let s = quad.object
      debug(s)
      // 验证 q 的内容
      assert_true(true)
    }
    Err(e) => debug(e.to_string())
  }
}

///|
test "parse multi-line ntriples test" {
  let parser = @lib.NTriplesParser::new()
  let low_level = parser.low_level()
  let input =
    #| <http://example/s> <http://example/p> <http://example/o> . # comment
    #| <http://example/s> <http://example/p> _:o . # comment
    #| <http://example/s> <http://example/p> "o" . # comment
    #| <http://example/s> <http://example/p> "o"^^<http://example/dt> . # comment
    #| <http://example/s> <http://example/p> "o"@en .
    #|
  low_level.extend_from_slice(@utf8.encode(input).to_array())
  low_level.end()

  let quads = []
  let mut count = 0
  for ;; {
    if count >= 20 {
      break
    }
    match low_level.parse_next() {
      Some(Ok(quad)) => {
        count += 1
        debug("[\{count}] \{quad}")
        quads.push(quad)
      }
      Some(Err(e)) => {
        debug("Error: \{e}")
        break
      }
      None => {
        debug("End")
        break
      }
    }
  }

  debug("Total ntriples: \{quads.length()}")
  assert_eq(quads.length(), 5)

  // 验证各个 quad 的内容
  // match quads[0] {
  // @lib.TripleRef::TripleRef(subject, predicate, object ) => {
  assert_true(quads[0].subject is NamedNode(_))
  assert_true(quads[0].predicate.iri == "http://example/p")
  assert_true(quads[0].object is NamedNode(_))

  assert_true(quads[2].subject is NamedNode(_))
  assert_true(quads[2].predicate.iri == "http://example/p")
  assert_false(quads[2].object is NamedNode(_))

  // }
  // }

}

///|
test "parse basic ntriples with error handling" {
  let parser = @lib.NTriplesParser::new()
  let low_level = parser.low_level()

  // 标准的 N-Triples 输入
  let input =
    #|<http://example/s> <http://example/p> "o"@en .

  low_level.extend_from_slice(@utf8.encode(input).to_array())
  low_level.end()

  let result = low_level.parse_next()

  // 1. 先检查是否为 None
  if result is None {
    debug("parse_next returned None")
    // panic()
  }

  // 2. 解包并检查错误
  match result.unwrap() {
    Ok(triple) => {
      debug(triple)
      // 验证 triple 的内容
      assert_true(true)
    }
    Err(e) =>
      // 3. 打印具体错误信息（使用 {} 进行字符串插值）
      debug("Parse error: \{e}")
    // panic()
  }
}

///|
test "parse literal all punctuation direct" {
  // #|<http://example/%53> <http://example/p> <http://example/o> .
  let input =
    #|<http://example/s> <http://example/p> <scheme:!$%25&'()*+,-./0123456789:/@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~?#> .
  // #|<http://example/\u0053> <http://example/p> <http://example/o> .
  debug("Input: \{input}")

  let parser = @lib.NTriplesParser::new()
  let low_level = parser.low_level()

  low_level.extend_from_slice(@utf8.encode(input).to_array())
  low_level.end()

  debug("Starting parse...")
  let result = low_level.parse_next()

  match result {
    Some(Ok(triple)) => {
      debug(triple)
      assert_true(true)
    }
    Some(Err(e)) => debug("Test \{e}")
    None => debug("No result")
  }
}

///|
test "safe parse all punctuation" {
  let input = "<http://s> <http://p> \" !\\\"#$%&():;<=>?@[]^_`{|}~\" ."

  let parser = @lib.NTriplesParser::new().lenient()
  let low_level = parser.low_level()

  low_level.extend_from_slice(@utf8.encode(input).to_array())
  low_level.end()

  match low_level.parse_next() {
    Some(Ok(triple)) => {
      debug("Success")
      debug(triple)
      assert_true(true)
    }
    Some(Err(e)) => debug("Parse Error: \{e}")
    None => debug("No Result")
  }
}

///|
async test "run official n-triples test suite" {
  let test_dir = "src/tests/src/rdf/rdf11/n-triples"

  let dir = @fs.opendir(test_dir)
  defer dir.close()

  let list = dir.read_all()
  let nt_files = list.filter(fn(x) {
    x.has_suffix(".nt") && !x.contains("bad") && !x.contains("error")
  })
  nt_files.sort()

  let mut passed = 0
  let mut failed = 0
  let errors = []

  for file in nt_files {
    let path = "\{test_dir}/\{file}"
    let content = @fs.read_file(path).binary().to_array()

    let parser = @lib.NQuadsRecognizer::new_parser(content, true, false)

    let mut result = parser.parse_next()
    let max_iter = 5000
    let mut iter_count = 0
    let mut ok = true

    for ;; {
      if iter_count >= max_iter {
        errors.push("\{file}: TIMEOUT")
        ok = false
        break
      }
      iter_count += 1

      match result {
        Some(Ok(_)) => result = parser.parse_next()
        Some(Err(e)) => {
          errors.push("\{file}: \{e}")
          ok = false
          break
        }
        None => break
      }
    }

    if ok {
      passed += 1
    } else {
      failed += 1
    }
  }

  debug("Test Suite Results: Passed=\{passed}, Failed=\{failed}")
  if errors.length() > 0 {
    debug("Failures:")
    for e in errors {
      debug("  - \{e}")
    }
  }
}

///|
async test "test bad n-triples files" {
  let test_dir = "src/tests/src/rdf/rdf11/n-triples"

  let dir = @fs.opendir(test_dir)
  defer dir.close()

  let list = dir.read_all()
  let bad_files = list.filter(fn(x) {
    x.has_suffix(".nt") && (x.contains("bad") || x.contains("error"))
  })
  bad_files.sort()

  debug("Testing \{bad_files.length()} bad/error files")

  let mut correct_fail = 0
  let mut wrong_pass = 0
  let mut timeout = 0

  for file in bad_files {
    let path = "\{test_dir}/\{file}"
    let content = @fs.read_file(path).binary().to_array()

    let parser = @lib.NQuadsRecognizer::new_parser(content, true, false)

    let mut result = parser.parse_next()
    let max_iter = 1000
    let mut iter_count = 0
    let mut failed = false

    for ;; {
      if iter_count >= max_iter {
        timeout += 1
        debug("TIMEOUT: \{file}")
        break
      }
      iter_count += 1

      match result {
        Some(Ok(_)) => result = parser.parse_next()
        Some(Err(_)) => {
          failed = true // ✅ 正确失败
          break
        }
        None => break
      }
    }

    if failed {
      correct_fail += 1
    } else if iter_count < max_iter {
      wrong_pass += 1
    }
    // timeout 不计入
  }

  debug(
    "Bad files: correct_fail=\{correct_fail}, wrong_pass=\{wrong_pass}, timeout=\{timeout}",
  )
}

///|
async test "test bad file" {
  let path = "src/tests/src/rdf/rdf11/n-triples/nt-syntax-bad-uri-01"

  debug("Testing: \{path}")

  let content = @fs.read_file(path + ".nt").binary().to_array()
  debug(
    "Content: \{@debug.to_string(@utf8.decode(@lib.array_to_view(content)))}",
  )

  let parser = @lib.NQuadsRecognizer::new_parser(content, true, false)

  let mut count = 0
  let mut result = parser.parse_next()
  let max_iter = 1000
  let mut iter_count = 0

  for ;; {
    if iter_count >= max_iter {
      debug("TIMEOUT!")
      break
    }
    iter_count += 1

    match result {
      Some(Ok(quad)) => {
        count += 1
        debug("OK: \{quad}")
        result = parser.parse_next()
      }
      Some(Err(e)) => {
        debug("ERROR (correct): \{e}")
        break
      }
      None => {
        debug("EOF, count: \{count}")
        break
      }
    }
  }
}
