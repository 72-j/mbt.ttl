///|
test "basic token parsing" {
  // 测试基本 RDF 语句
  let input = "<http://example.org/item1> <http://example.org/name> \"Test Item\" ."
  let data = @utf8.encode(input).to_fixedarray()
  let lexer = @lib.Lexerc::new(data)

  // 第一个 Token: IRI <http://example.org/item1>
  let tok1 = lexer.next()
  match tok1 {
    Some(@lib.Token::IRI(_,start, end)) => {
      debug(tok1)
      assert_eq(start, 0)
      assert_true(end > start)
    }
    _ => debug(tok1)
  }

  // 第二个 Token: Symbol '.'
  let tok2 = lexer.next()
  match tok2 {
    Some(@lib.Token::Symbol(_,_, start, end)) => {
      let sym = lexer.extract(start, end)
      assert_eq(sym, ".")
    }
    _ => debug(tok2)
  }

  // 第三个 Token: EOF
  let tok3 = lexer.next()
  match tok3 {
    Some(@lib.Token::EOF(_)) => ()
    _ => debug(tok3)
  }

  lexer.destroy()
}

///|
test "literal token" {
  let input = "\"Test Item\""
  let data = @utf8.encode(input).to_fixedarray()
  let lexer = @lib.Lexerc::new(data)

  let tok = lexer.next()
  match tok {
    Some(@lib.Token::Literal(_,start, end)) => {
      // 提取去掉引号的字面量
      let literal = lexer.extract_iri(data, @lib.Token::Literal(0,start, end))
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
test "check bytes structure" {
  let buf : Bytes = Bytes::make(16, 0xFF)

  debug("bytes length: \{buf.length()}") // 应该是 16
}

///|
test "diagnose FFI bytes" {
  let input = "<test>"
  let data = @utf8.encode(input).to_fixedarray()

  // 创建 lexer
  let ptr = @lib.lexer_create(data, data.length())

  // 测试 Bytes::make 创建的 buffer
  let buf1 : FixedArray[Byte] = FixedArray::make(32, 0)
  debug("Bytes::make length: \{buf1.length()}")

  // 尝试直接获取原始指针
  let ok1 = @lib.lexer_next(ptr, buf1)
  debug("Bytes::make ok: \{ok1.to_string()}")
  debug("buf1[0]: \{buf1[0].to_int()}")

  // 销毁
  @lib.lexer_destroy(ptr)
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
test "check array C write" {
  let data = @utf8.encode("<test>").to_fixedarray()
  let ptr = @lib.lexer_create(data, data.length())
  let arr : FixedArray[Byte] = FixedArray::make(32, 0)

  let ok = @lib.lexer_next(ptr, arr)
  debug("ok: \{ok.to_string()}")

  // 打印所有 32 个元素
  let mut s = "arr: ["
  for i in 0..<32 {
    if i > 0 {
      s = s + ", "
    }
    s = s + arr[i].to_int().to_string()
  }
  s = s + "]"
  debug(s)

  @lib.lexer_destroy(ptr)
}


///|
test "simple lexer test" {
  let input = "<test>"
  let data = @utf8.encode(input).to_fixedarray()

  debug("data length: \{data.length()}")

  let lexer = @lib.Lexerc::new(data)
  debug("lexer created")

  let tok = lexer.next()
  debug("got token: \{@debug.to_string(tok)}")

  lexer.destroy()
  debug("lexer destroyed")
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
test "performance: small batch" {
  // 1000 tokens
  let input = {
    let mut s = ""
    for i = 0; i < 10000; i = i + 1 {
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
  for i = 0; i < 10000; i = i + 1 { // 限制最多 100000 次
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

  debug("count: \{count}, time: \{elapsed} ms")
}

///|
async test "performance: lexer" {
  // let input = {
  //   let mut s = ""
  //   for i = 0; i < 1000; i = i + 1 {
  //     s = s +
  //       "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
  //   }
  //   s
  // }
  let file = "test_10000.nq"
  let test_dir = "/home/thy/moonttl/bak/benchmark"
  let filepath = test_dir + "/" + file

  let content = @fs.read_file(filepath).binary()
  let bytes = content.to_fixedarray()
  let data = bytes
  let token_count = 10000 * 5 // 每行 5 个 token

  let runs = 1
  let start = @bench.monotonic_clock_start()

  // for _ in 0..<runs {
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
  // }

  let elapsed_ms = @bench.monotonic_clock_end(start) // 毫秒

  debug("=== 性能测试 ===")
  debug("Token 数/次: \{token_count}")
  // debug("运行次数: \{runs}")
  // debug("总 Token 数: \{token_count * runs}")
  debug("总耗时(ns): \{elapsed_ms}")
  debug("每次运行(ns): \{elapsed_ms / runs.to_double()}")
  debug(
    "每 Token(ns): \{(elapsed_ms * 1_000.0 / runs.to_double() / token_count.to_double()).to_int()}",
  )
  debug(
    "吞吐量: \{(token_count.to_double() * runs.to_double()*1000_000 / (elapsed_ms ))} tokens/s",
  )
}

///|
test "check time unit" {
  let start = @bench.monotonic_clock_start()

  // 空循环，理论上应该很快
  for i in 0..<100000000 {
    ignore(i)
  }

  let elapsed = @bench.monotonic_clock_end(start)

  debug("elapsed raw: \{elapsed}")

  // 看看 1 秒对应的值
  // 如果 elapsed 约等于 1.0，说明是秒
  // 如果 elapsed 约等于 1000.0，说明是毫秒
  // 如果 elapsed 约等于 1000000.0，说明是微秒
}

///|
test "benchmark: lexer parsing 2" {
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


  test "batch parsing" {
    let input = {
      let mut s = ""
      for i = 0; i < 1000; i = i + 1 {
        s = s + "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
      }
      s
    }
    let data = @utf8.encode(input).to_fixedarray()
    let lexer = @lib.Lexerc::new(data)

    // 测试 batch
    let batch = lexer.next_batch(64)
    debug("batch size: \{batch.length()}")

    // 检查内容
    for i in 0..<batch.length().min(5) {
      debug("token \{i}: \{batch[i]}")
    }

    lexer.destroy()
  }


  
  test "benchmark: batch vs single" {
    let input = {
      let mut s = ""
      for i = 0; i < 10000; i = i + 1 {
        s = s + "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
      }
      s
    }
    let data = @utf8.encode(input).to_fixedarray()
    // let token_count = 10000 * 5

    let bench = @bench.Bench()

    bench.bench(name="single parse", fn() {
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

    bench.bench(name="batch 64", fn() {
      let lexer = @lib.Lexerc::new(data)
      let mut total = 0
      for ;; {
        let batch = lexer.next_batch(64)
        if batch.is_empty() { break }
        total = total + batch.length()
      }
      lexer.destroy()
      ignore(total)
    })

    bench.bench(name="batch 256", fn() {
      let lexer = @lib.Lexerc::new(data)
      let mut total = 0
      for ;; {
        let batch = lexer.next_batch(256)
        if batch.is_empty() { break }
        total = total + batch.length()
      }
      lexer.destroy()
      ignore(total)
    })

    bench.bench(name="batch 1024", fn() {
      let lexer = @lib.Lexerc::new(data)
      let mut total = 0
      for ;; {
        let batch = lexer.next_batch(1024)
        if batch.is_empty() { break }
        total = total + batch.length()
      }
      lexer.destroy()
      ignore(total)
    })

    let summary = bench.dump_summaries()
    debug("=== 50,000 tokens ===")
    debug("\{summary}")
  }
