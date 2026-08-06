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
  for i = 0; i < 1000; i = i + 1 { // 限制最多 100000 次
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

  debug("count: \{count}, time: \{elapsed} us")
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
test "final test" {
  let data : FixedArray[Byte] = [b'a', b'b', b'c', b' ', b'd', b'e', b'f']
  let lexer = @lib.Lexerc::new(data)

  for ;; {
    let tok = lexer.next()
    match tok {
      Some(@lib.Token::Unknown(span)) =>
        debug("Token: '\{lexer.extract(span)}'")
      Some(@lib.Token::EOF(_)) => {
        debug("EOF")
        break
      }
      _ => debug("other: \{@debug.to_string(tok)}")
    }
  }

  lexer.destroy()
}

///|
test "debug token buf - single call" {
  let data : FixedArray[Byte] = [b'a', b'b', b'c', b' ', b'd', b'e', b'f']

  // 方式 1：用单独的 token_buf，不通过 lexer.next()
  let lexer = @lib.Lexerc::new(data)
  let token_buf = FixedArray::make(12, b'0')
  let ok = @lib.lexer_next(lexer.ptr, token_buf)
  debug("ok: \{ok.to_string()}")

  // 手动解析
  let ctype = token_buf[0]
  let offset = token_buf[4]
  let length = token_buf[8]
  debug("ctype=\{ctype}, offset=\{offset}, length=\{length}")

  lexer.destroy()

  // 方式 2：用 lexer.next()
  let lexer2 = @lib.Lexerc::new(data)
  let tok = lexer2.next()
  debug("lexer.next: \{@debug.to_string(tok)}")
  lexer2.destroy()
}

///|
test "clean lexer test" {
  let data : FixedArray[Byte] = [
    b'a', b'b', b'c', b' ', b'd', b'e', b'f',
  ]
let data : FixedArray[Byte] =FixedArray::from_array([
    b'a', b'b', b'c', b' ', b'd', b'e', b'f',
  ])
  // 确保 data.length() 被使用
  // debug("data length: \{data.length()}")

  let lexer = @lib.Lexerc::new(data)

  for ;; {
    let tok = lexer.next()
    match tok {
      Some(@lib.Token::Unknown(span)) =>
        debug("Token: '\{lexer.extract(span)}'")
      Some(@lib.Token::EOF(_)) => {
        debug("EOF")
        break
      }
      _ => debug("other")
    }
  }

  lexer.destroy()
}


///|
test "newline in middle" {
  // 模拟 "abc\ndef"
  let data : FixedArray[Byte] = [b'a', b'b', b'c', b' ', b' ', b'd', b'e', b'f']
  // debug("data length: \{data[0]}")
  let lexer = @lib.Lexerc::new(data)

  // 第一个 Token
  let tok1 = lexer.next()
  match tok1 {
    Some(@lib.Token::Unknown(span)) =>
      debug("tok1 ok: '\{lexer.extract(span)}'")
    _ => debug("tok1 err: \{@debug.to_string(tok1)}")
  }

  // 第二个 Token
  let tok2 = lexer.next()
  match tok2 {
    Some(@lib.Token::Unknown(span)) => debug("tok2: '\{lexer.extract(span)}'")
    _ => debug("tok2: \{@debug.to_string(tok2)}")
  }

  // 第三个 Token 应该是 EOF
  let tok3 = lexer.next()
  match tok3 {
    Some(@lib.Token::EOF(_)) => debug("tok3: EOF OK")
    _ => debug("tok3: \{@debug.to_string(tok3)}")
  }

  lexer.destroy()
}

///|
test "tabs and spaces skip" {
  // 模拟 "  \t  abc  \n  def  "
  let data : FixedArray[Byte] = [
    b' ', b' ', b'\t', b' ', b'a', b'b', b'c', b' ', b' ', b'\n', b' ', b' ', b'd',
    b'e', b'f', b' ', b' ',
  ]
  let lexer = @lib.Lexerc::new(data)

  for ;; {
    let tok = lexer.next()
    match tok {
      Some(@lib.Token::EOF(_)) => {
        debug("EOF")
        break
      }
      Some(@lib.Token::Unknown(span)) =>
        debug("Token: '\{lexer.extract(span)}'")
      _ => debug("other: \{@debug.to_string(tok)}")
    }
  }

  lexer.destroy()
}

///|
test "debug parsing" {
  let input =
    #|:asd _:asd  
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
    #|ex:User :active a .
    #|ex:Alice :speaks @en .
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

  // 检查每个字节
  for i = 0; i < data.length(); i = i + 1 {
    debug("data[\{i}]: '\{data[i].to_char()}' (0x\{data[i].to_hex()})")
  }

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
    Some(@lib.Token::Literal(span)) => {
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
async test "performance: lexer" {
  let file = "test_100000.nq"
  let test_dir = "/home/thy/moonttl/bak/benchmark"
  let filepath = test_dir + "/" + file

  let content = @fs.read_file(filepath).binary()
  let bytes = content.to_fixedarray()
  let data = bytes

  // 估算 token 数：每行约 5 个 token
  let token_per_line = 5
  let line_count = content.to_array().length() / 50 // 估算
  let token_count = line_count * token_per_line

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

// test "batch parsing" {
//   let input = {
//     let mut s = ""
//     for i = 0; i < 1000; i = i + 1 {
//       s = s + "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
//     }
//     s
//   }
//   let data = @utf8.encode(input).to_fixedarray()
//   let lexer = @lib.Lexerc::new(data)

//   // 测试 batch
//   let batch = lexer.next_batch(64)
//   debug("batch size: \{batch.length()}")

//   // 检查内容
//   for i in 0..<batch.length().min(5) {
//     debug("token \{i}: \{batch[i]}")
//   }

//   lexer.destroy()
// }

// test "benchmark: batch vs single" {
//   let input = {
//     let mut s = ""
//     for i = 0; i < 10000; i = i + 1 {
//       s = s + "<http://example.org/s\{i}> <http://example.org/p\{i}> <http://example.org/o\{i}> .\n"
//     }
//     s
//   }
//   let data = @utf8.encode(input).to_fixedarray()
//   // let token_count = 10000 * 5

//   let bench = @bench.Bench()

//   bench.bench(name="single parse", fn() {
//     let lexer = @lib.Lexerc::new(data)
//     let mut count = 0
//     for ;; {
//       match lexer.next() {
//         Some(@lib.Token::EOF(_)) => break
//         Some(_) => count = count + 1
//         None => break
//       }
//     }
//     lexer.destroy()
//     ignore(count)
//   })

//   bench.bench(name="batch 64", fn() {
//     let lexer = @lib.Lexerc::new(data)
//     let mut total = 0
//     for ;; {
//       let batch = lexer.next_batch(64)
//       if batch.is_empty() { break }
//       total = total + batch.length()
//     }
//     lexer.destroy()
//     ignore(total)
//   })

//   bench.bench(name="batch 256", fn() {
//     let lexer = @lib.Lexerc::new(data)
//     let mut total = 0
//     for ;; {
//       let batch = lexer.next_batch(256)
//       if batch.is_empty() { break }
//       total = total + batch.length()
//     }
//     lexer.destroy()
//     ignore(total)
//   })

//   bench.bench(name="batch 1024", fn() {
//     let lexer = @lib.Lexerc::new(data)
//     let mut total = 0
//     for ;; {
//       let batch = lexer.next_batch(1024)
//       if batch.is_empty() { break }
//       total = total + batch.length()
//     }
//     lexer.destroy()
//     ignore(total)
//   })

//   let summary = bench.dump_summaries()
//   debug("=== 50,000 tokens ===")
//   debug("\{summary}")
// }
