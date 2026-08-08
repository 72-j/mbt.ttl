///|
test "performance: small batch" {
  // 1000 tokens
  let input = {
    let mut s = ""
    for i = 0; i < 1000; i = i + 1 {
      s = s +
        "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
    }
    s
  }

  debug("input length: \{input.length()}")
  let data = @utf8.encode(input).to_fixedarray()
  debug("data length: \{data.length()}")

  let start = @bench.monotonic_clock_start()
  let lexer = @lib.Lexerc::new(data)

  let mut count = 0
  for ;; { // 限制最多 100000 次
    match lexer.next() {
      Some(@lib.Token::EOF(_)) => {
        debug("EOF at: \{count}")
        break
      }
      Some(_) => count = count + 1
      None => break
    }
  }

  lexer.destroy()
  let elapsed = @bench.monotonic_clock_end(start)

  debug("lexer count: \{count}, time: \{elapsed} us")
}

///|
test "full lexer test" {
  let input = "<subject> <predicate> \"object\" ."
  let data = @utf8.encode(input).to_fixedarray()
  let lexer = @lib.Lexerc::new(data)

  let tok1 = lexer.next()
  match tok1 {
    Some(@lib.Token::Iri(span)) => debug("S: \{lexer.extract(span)}")
    _ => debug("FAIL: \{@debug.to_string(tok1)}")
  }

  let tok2 = lexer.next()
  match tok2 {
    Some(@lib.Token::Iri(span)) => debug("P: \{lexer.extract(span)}")
    _ => debug("FAIL: \{@debug.to_string(tok2)}")
  }

  let tok3 = lexer.next()
  match tok3 {
    Some(@lib.Token::Literal(span)) => debug("O: \{lexer.extract(span)}")
    _ => debug("FAIL: \{@debug.to_string(tok3)}")
  }

  let tok4 = lexer.next()
  match tok4 {
    Some(@lib.Token::Dot(span)) => debug("sym: '.' offset=\{span.0}")
    Some(@lib.Token::Semicolon(span)) => debug("sym: ';' offset=\{span.0}")
    Some(@lib.Token::Comma(span)) => debug("sym: ',' offset=\{span.0}")
    Some(@lib.Token::Unknown(span)) => debug("Unknown: offset=\{span.0}")
    _ => debug("FAIL: \{@debug.to_string(tok4)}")
  }

  let tok5 = lexer.next()
  match tok5 {
    Some(@lib.Token::EOF(_)) => debug("EOF OK")
    _ => debug("FAIL: \{@debug.to_string(tok5)}")
  }

  lexer.destroy()
}

///|
test "debug parsing" {
  let input =
    #|hello 
    #|:asd  _:asd  
    #|ex:Alice :greeting "Hello"@en .
    #|ex:Alice :birthDate "1990-01-01"^^xsd:date .  
    #|ex:Book :description """sad"""@zh .
    #|ex:Config :json """
    #|{
    #|    "host": "localhost",
    #|    "port": 8080
    #|}
    #|"""^^ex:JSON .
    #|ex:Alice :age 30 .
    #|ex:Measurement :value 1.23e-4 .
    #|@prefix  BASE  PREFIX [ ] { }

  let data = @utf8.encode(input).to_fixedarray()
  debug("input: '\{input}'")
  let _ = data.length() // 确保 data 被使用，防止优化
  let lexer = @lib.Lexerc::new(data)

  for ;; {
    let tok = lexer.next()
    match tok {
      Some(t) =>
        match t {
          @lib.Token::Iri(span) =>
            debug(
              "IRI: offset=\{span.0}, length=\{span.1}, content='\{lexer.extract(span)}'",
            )
          @lib.Token::Literal(span) =>
            debug(
              "Literal: offset=\{span.0}, length=\{span.1}, content='\{lexer.extract(span)}'",
            )
          @lib.Token::BlankNode(span) =>
            debug(
              "BlankNode: offset=\{span.0}, length=\{span.1}, content='\{lexer.extract(span)}'",
            )
          @lib.Token::PrefName(span) =>
            debug(
              "BlankNode: offset=\{span.0}, length=\{span.1}, content='\{lexer.extract(span)}'",
            )
          @lib.Token::Dot(span) =>
            debug("Dot: offset=\{span.0}, length=\{span.1}")
          @lib.Token::Semicolon(span) =>
            debug("Semicolon: offset=\{span.0}, length=\{span.1}")
          @lib.Token::Comma(span) =>
            debug("Comma: offset=\{span.0}, length=\{span.1}")
          @lib.Token::Unknown(span) =>
            debug(
              "Unknown: offset=\{span.0}, length=\{span.1}, content='\{lexer.extract(span)}'",
            )
          @lib.Token::EOF(offset) => {
            debug("EOF at \{offset}")
            break
          }
        }
      None => {
        debug("None")
        break
      }
    }
  }

  lexer.destroy()
}

///|
test "basic token parsing" {
  let input = "<subject> <predicate> <object>"
  let data = @utf8.encode(input).to_fixedarray()

  debug("input: '\{input}'")
  debug("data length: \{data.length()}")

  let lexer = @lib.Lexerc::new(data)

  let tok1 = lexer.next()
  debug("tok1: \{@debug.to_string(tok1)}")

  let tok2 = lexer.next()
  debug("tok2: \{@debug.to_string(tok2)}")

  let tok3 = lexer.next()
  debug("tok3: \{@debug.to_string(tok3)}")

  lexer.destroy()
}

///|
test "literal token" {
  let input = "\"Test Item\""
  let data = @utf8.encode(input).to_fixedarray()
  let lexer = @lib.Lexerc::new(data)

  let tok = lexer.next()
  match tok {
    Some(@lib.Token::Literal(_span)) => {
      // 提取去掉引号的字面量
      let literal = lexer.extract_literal(tok.unwrap())
      // 或手动提取
      // let raw = lexer.extract(_,start, end)  // "Test Item"
      // let lit = lexer.extract(start + 1, end - 1)  // Test Item
      debug("literal: \{@utf8.decode_lossy(@lib.array_to_view(literal))}")
    }
    _ => debug("unexpected: \{@debug.to_string(tok)}")
  }

  lexer.destroy()
}

///|
test "check array layout" {
  let arr : FixedArray[Byte] = FixedArray::make(32, 0)
  debug("array length: \{arr.length()}")

  // 尝试访问不同位置
  debug(
    "arr[0]=\{arr[0].to_int()}, arr[15]=\{arr[15].to_int()}, arr[16]=\{arr[16].to_int()}",
  )
}

///|
test "small test - no crash" {
  let input = "<a> <b> <c> ."
  let data = @utf8.encode(input).to_fixedarray()
  debug("data length: \{data.length()}")

  let lexer = @lib.Lexerc::new(data)
  debug("lexer created")

  let mut count = 0
  for ;; {
    match lexer.next() {
      Some(@lib.Token::EOF(_)) => {
        debug("got EOF at count: \{count}")
        break
      }
      Some(_tok) => {
        count = count + 1
        if count > 100 {
          debug("too many tokens!")
          break
        }
      }
      None => break
    }
  }

  debug("count: \{count}")
  lexer.destroy()
  debug("lexer destroyed")
}

///|
async test "performance: lexer" {
  let file = "test_1000.nq"
  let test_dir = "/home/thy/moonttl/bak/benchmark"
  let filepath = test_dir + "/" + file

  let content = @fs.read_file(filepath).binary()
  let bytes = content.to_fixedarray()
  let data = bytes

  let start = @bench.monotonic_clock_start()

  let lexer = @lib.Lexerc::new(data)
  let mut count = 0
  for ;; {
    match lexer.next() {
      Some(@lib.Token::EOF(_)) => break
      Some(_) => count = count + 1
      None => break
    }
  }
  lexer.destroy()

  let elapsed_us = @bench.monotonic_clock_end(start) // 微秒

  debug("=== 性能测试 ===")
  debug("Token 数: \{count}")
  debug("总耗时(us): \{elapsed_us.to_int()}")
  debug("总耗时(ms): \{(elapsed_us / 1000.0).to_int()}")
  debug("每 Token(us): \{(elapsed_us / count.to_double()).to_int()}")
  debug(
    "吞吐量: \{(count.to_double() * 1_000_000.0 / elapsed_us).to_int()} tokens/s",
  )
}

///|
test "benchmark: lexer parsing" {
  // 预先生成测试数据（只生成一次）
  let input = {
    let mut s = ""
    for i = 0; i < 10000; i = i + 1 {
      s = s +
        "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
    }
    s
  }
  let data = @utf8.encode(input).to_fixedarray()
  // let token_count = 10000 * 5

  let bench = @bench.Bench()

  bench.bench(name="lexer 10000 quads", fn() {
    let lexer = @lib.Lexerc::new(data)
    let mut count = 0
    for ;; {
      match lexer.next() {
        Some(@lib.Token::EOF(_)) => break
        Some(_) => count = count + 1
        None => break
      }
    }
    lexer.destroy()
    ignore(count)
  })

  let summary = bench.dump_summaries()
  debug("=== 性能对比 ===")
  debug("Token 数量: \{summary}")
}
