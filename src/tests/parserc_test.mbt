///|
test "parserc basic test" {
  // 测试 pchar
  let p = @parserc.pchar('a')
  let result = p.run(@parserc.Seq::from_string("a c"))
  match result {
    Some((c, rest)) => {
      @debug.assert_eq(c, 'a')
      // @debug.assert_eq(rest.uncons().0, 'b')
      match rest.uncons() {
        Some((' ', _)) => () // ok
        Some((c, _)) => fail("Expected space, got: \{c}")
        None => fail("Expected rest to have space")
      }
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc string test" {
  // 测试 pstring
  let p = @parserc.pstring("hello")
  let result = p.run(@parserc.Seq::from_string("hello world"))
  match result {
    Some((s, _rest)) => @debug.assert_eq(s, "hello")
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc and_then test" {
  // 测试 and_then
  let p = @parserc.pstring("hello").and_then(@parserc.pstring(" "))
  let result = p.run(@parserc.Seq::from_string("hello world"))
  match result {
    Some(((s1, s2), _rest)) => {
      @debug.assert_eq(s1, "hello")
      @debug.assert_eq(s2, " ")
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc map test" {
  // 测试 map
  let p = @parserc.pstring("123").map(fn(s) { s.length() })
  let result = p.run(@parserc.Seq::from_string("123"))
  match result {
    Some((len, _)) => @debug.assert_eq(len, 3)
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc optional test" {
  // 测试 optional
  let p = @parserc.pstring("hello").optional()
  let result = p.run(@parserc.Seq::from_string("hello"))
  match result {
    Some((opt, _)) =>
      match opt {
        Some(s) => @debug.assert_eq(s, "hello")
        None => fail("Expected Some, got None")
      }
    None => fail("Expected Some, got None")
  }

  // optional 在失败时返回 None
  let result2 = p.run(@parserc.Seq::from_string("world"))
  match result2 {
    Some((opt, _)) =>
      match opt {
        Some(_) => fail("Expected None")
        None => () // ok
      }
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc or_else test" {
  // 测试 or_else
  let p = @parserc.pstring("hello").or_else(@parserc.pstring("world"))

  // 匹配第一个
  let result1 = p.run(@parserc.Seq::from_string("hello"))
  match result1 {
    Some((s, _)) => @debug.assert_eq(s, "hello")
    None => fail("Expected Some")
  }

  // 匹配第二个
  let result2 = p.run(@parserc.Seq::from_string("world"))
  match result2 {
    Some((s, _)) => @debug.assert_eq(s, "world")
    None => fail("Expected Some")
  }

  // 两个都失败
  let result3 = p.run(@parserc.Seq::from_string("foo"))
  match result3 {
    Some(_) => fail("Expected None")
    None => () // ok
  }
}

///|
test "parserc repeat test" {
  // 测试 repeat
  let p = @parserc.pchar('a').repeat()
  let result = p.run(@parserc.Seq::from_string("aaaab"))
  match result {
    Some((chars, _rest)) => @debug.assert_eq(chars.length(), 4)
    // @debug.assert_eq(rest.uncons().0, 'b')
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc repeat_with_sep test" {
  // 测试 repeat_with_sep (逗号分隔)
  let p = @parserc.pstring("a").repeat_with_sep(@parserc.pchar(','))
  let result = p.run(@parserc.Seq::from_string("a,a,a"))
  match result {
    Some((items, _rest)) => @debug.assert_eq(items.length(), 3)
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc take_while test" {
  // 测试消费满足条件的字符
  let p = @parserc.pvalue(fn(c : Char) {
      if c.is_ascii_digit() {
        Some(c)
      } else {
        None
      }
    })
    .repeat()
    .map(fn(chars) {
      chars.iter().fold(init="", fn(a, b) { a + b.to_string() })
    })
  let result = p.run(@parserc.Seq::from_string("123 bc"))
  match result {
    Some((s, rest)) => {
      @debug.assert_eq(s, "123")
      match rest.uncons() {
        Some((' ', _)) => () // ok
        Some((c, _)) => fail("Expected space, got: \{c}")
        None => fail("Expected rest to have space")
      }
    }
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc nquads subject test" {
  // 测试 N-Quads 主语解析（简化版）
  let content_parser = @parserc.pvalue(fn(c : Char) {
    if c != '>' {
      Some(c)
    } else {
      None
    }
  }).repeat()

  let iri_parser = @parserc.pchar('<')
    .and_then(content_parser)
    .and_then(@parserc.pchar('>'))
    .map(fn(tuple) {
      let ((_, content), _) = tuple
      let s = content.iter().fold(init="", fn(a, b) { a + b.to_string() })
      "<\{s}>"
    })

  let result = iri_parser.run(
    @parserc.Seq::from_string("<http://example.org/s>"),
  )
  match result {
    Some((iri, _rest)) => @debug.assert_eq(iri, "<http://example.org/s>")
    None => fail("Expected Some, got None")
  }
}

///|
test "parserc nquads blank node test" {
  // 测试空白节点
  let blank_parser = @parserc.pstring("_:")
    .and_then(
      @parserc.pvalue(fn(c : Char) {
        if c != ' ' && c != '.' && c != '\n' {
          Some(c)
        } else {
          None
        }
      }).repeat(),
    )
    .omit_first()
    .map(fn(chars) {
      let s = chars.iter().fold(init="", fn(a, b) { a + b.to_string() })
      "_:\{s}"
    })

  let result = blank_parser.run(@parserc.Seq::from_string("_:blank1 "))
  match result {
    Some((node, _rest)) => @debug.assert_eq(node, "_:blank1")
    None => fail("Expected Some, got None")
  }
}
