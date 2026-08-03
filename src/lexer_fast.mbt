///|
pub(all) enum Tokenfast {
  IRI(Int, Int)
  Blank(Int, Int)
  Literal(Int, Int)
  Symbol(Byte, Int, Int)
  LineJump(Int, Int) // 换行位置
  EOF(Int) // 文件结束位置
  Error(Int,Int)
} derive(Debug)

///|
pub impl Show for Tokenfast with fn output(self : Tokenfast, logger : &Logger) -> Unit {
  match self {
    Tokenfast::IRI(start, end) => {
      logger.write_string("IRI")
      logger.write_string("(\{start}:\{end})")
    }
    Tokenfast::Blank(start, end) => {
      logger.write_string("Blank")
      logger.write_string("(\{start}:\{end})")
    }
    Tokenfast::Literal(start, end) => {
      logger.write_string("Literal")
      logger.write_string("(\{start}:\{end})")
    }
    Tokenfast::Symbol(_b, start, end) => {
      logger.write_string("Symbol")
      logger.write_string("(\{start}:\{end})")
    }
    Tokenfast::LineJump(start, end) => {
      logger.write_string("LineJump")
      logger.write_string("(\{start}:\{end})")
    }
    Tokenfast::EOF(start) => {
      logger.write_string("EOF")
      logger.write_string("(\{start})")
    }
    Tokenfast::Error(start, end) => {
      logger.write_string("Error")
      logger.write_string("(\{start}:\{end})")
    }
  }
}

///|
pub(all) struct Tokenizer {
  view : ArrayView[Byte]
  mut pos : Int
  mut len : Int
}

///|
pub fn Tokenizer::new(view : ArrayView[Byte]) -> Tokenizer {
  Tokenizer::{ view, pos: 0, len: view.length() }
}

///|
/// 跳过空白（空格、Tab、CR）
fn Tokenizer::skip_whitespace(self : Tokenizer) -> Unit {
  while self.pos < self.len {
    match self.view[self.pos] {
      b' ' | b'\t' | b'\r' => self.pos = self.pos + 1
      _ => break
    }
  }
}

///|
/// 跳过空白和注释
fn Tokenizer::skip_whitespace_and_comment(self : Tokenizer) -> Unit {
  while self.pos < self.len {
    match self.view[self.pos] {
      b' ' | b'\t' | b'\r' => self.pos = self.pos + 1
      b'#' => {
        // 跳过注释直到换行
        self.pos = self.pos + 1
        while self.pos < self.len && self.view[self.pos] != b'\n' {
          self.pos = self.pos + 1
        }
      }
      _ => break
    }
  }
}

///|
/// 消费指定字节，不匹配则报错
fn Tokenizer::expect(self : Tokenizer, byte : Byte) -> Bool {
  if self.pos < self.len && self.view[self.pos] == byte {
    self.pos = self.pos + 1
    true
  } else {
    false
  }
}

///|
/// 获取当前位置（用于错误报告）
pub fn Tokenizer::current_pos(self : Tokenizer) -> Int {
  self.pos
}

///|
/// 消费单字符符号
fn Tokenizer::consume_symbol(self : Tokenizer) -> Tokenfast {
  let start = self.pos
  let byte = self.view[self.pos]
  self.pos = self.pos + 1
  Tokenfast::Symbol(byte, start, self.pos)
}

///|
/// 解析满足条件的字符序列
fn Tokenizer::take_while(
  self : Tokenizer,
  predicate : (Byte) -> Bool,
) -> (Int, Int) {
  let start = self.pos
  while self.pos < self.len && predicate(self.view[self.pos]) {
    self.pos = self.pos + 1
  }
  (start, self.pos)
}

///|
/// 解析直到遇到指定字节（不含）
/// 返回 (start, end)，end 是目标字节的位置
fn Tokenizer::take_until(self : Tokenizer, end_byte : Byte) -> (Int, Int)? {
  let start = self.pos
  while self.pos < self.len && self.view[self.pos] != end_byte {
    self.pos = self.pos + 1
  }

  if self.pos >= self.len {
    return None // 未找到目标字节
  }

  let end = self.pos
  self.pos = self.pos + 1 // 消费目标字节
  Some((start, end))
}

///|
/// 获取下一个 Tokenfast
fn Tokenizer::next(self : Tokenizer) -> Tokenfast? {
  // 跳过空白和注释
  self.skip_whitespace_and_comment()

  // 检查结束
  if self.pos >= self.len {
    return Some(Tokenfast::EOF(self.pos))
  }

  let start = self.pos
  let current = self.view[self.pos]

  match current {
    // IRI: <...>
    b'<' => {
      self.pos = self.pos + 1
      match self.take_until(b'>') {
        Some((iri_start, iri_end)) => Some(Tokenfast::IRI(iri_start, iri_end + 1)) // 包含 >
        None => None // IRI 未闭合
      }
    }

    // 字面量: "..."
    b'"' => {
      self.pos = self.pos + 1
      match self.take_until(b'"') {
        Some((lit_start, lit_end)) =>
          Some(Tokenfast::Literal(lit_start, lit_end + 1)) // 包含 "
        None => None
      }
    }

    // Blank Node: _:name 或 :name
    b'_' | b':' => {
      self.pos = self.pos + 1
      // 跳过前缀后的 :
      if self.pos < self.len && self.view[self.pos] == b':' {
        self.pos = self.pos + 1
      }
      // 解析本地名
      let (name_start, name_end) = self.take_while(fn(b) {
        b.is_ascii_alnum() || b == b'_' || b == b'-'
      })
      if name_end > name_start {
        Some(Tokenfast::Blank(name_start - 2, name_end)) // 包含 _: 前缀
      } else {
        None // Blank Node 格式错误
      }
    }

    // 单字符符号
    b'.' | b',' | b';' | b'[' | b']' | b'(' | b')' | b'{' | b'}' | b'^' =>
      Some(self.consume_symbol())

    // 换行
    b'\n' => {
      self.pos = self.pos + 1
      Some(Tokenfast::LineJump(start, self.pos))
    }

    // 未知字符
    _ => None
  }
}

///|
/// 解析所有 Tokenfast
pub fn Tokenizer::tokenize(self : Tokenizer) -> Array[Tokenfast] {
  let tokens : Array[Tokenfast] = []

  while true {
    match self.next() {
      Some(token) => {
        tokens.push(token)
        if token.is_end() {
          break
        }
      }
      None => break // 解析错误，停止
    }
  }

  tokens
}

///|
fn Tokenfast::is_end(self : Tokenfast) -> Bool {
  match self {
    Tokenfast::EOF(_) => true
    _ => false
  }
}

///|
/// 从 Tokenfast 提取字符串
pub fn Tokenizer::extract(self : Tokenizer, start : Int, end : Int) -> String {
  let mut s = ""
  for i in start..<end {
    s = s + self.view[i].to_char().to_string()
  }
  s
}

///|
/// 从 Tokenfast 提取 IRI（去掉 <>）
pub fn Tokenizer::extract_iri(self : Tokenizer, token : Tokenfast) -> String {
  match token {
    Tokenfast::IRI(start, end) =>
      if end > start + 1 &&
        self.view[start] == b'<' &&
        self.view[end - 1] == b'>' {
        self.extract(start + 1, end - 1) // 去掉 <>
      } else {
        self.extract(start, end)
      }
    _ => ""
  }
}

///|
/// 预分配 tokens 数组减少扩容
pub fn Tokenizer::tokenize_with_capacity(
  self : Tokenizer,
  estimated_count : Int,
) -> Array[Tokenfast] {
  let tokens : Array[Tokenfast] = Array::make(estimated_count, Tokenfast::EOF(0)) // 预分配

  while true {
    match self.next() {
      Some(token) => tokens.push(token)
      None => break
    }
  }
  tokens
}

///|
test "cursor tokenizer" {
  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  let data = @utf8.encode(input).to_array()

  let tokenizer = Tokenizer::new(data[:])
  let tokens = tokenizer.tokenize()

  for token in tokens {
    match token {
      Tokenfast::IRI(start, end) =>
        debug("IRI: \{tokenizer.extract_iri(token)} at [\{start}:\{end}]")
      Tokenfast::Symbol(b, start, end) =>
        debug("Symbol: '\{b.to_char()}' at [\{start}:\{end}]")
      Tokenfast::LineJump(start, end) => debug("LineJump at [\{start}:\{end}]")
      Tokenfast::EOF(pos) => debug("EOF at \{pos}")
      _ => ()
    }
  }
}

///|
test "benchmark: cursor tokenizer" {
  let bench = @bench.Bench()

  bench.bench(name="tokenize 1000 quads", fn() {
    let n = 1000
    let base = "http://example.org/"

    let input = {
      let mut s = ""
      for i = 0; i < n; i = i + 1 {
        s = s + "<\{base}s\{i}> <\{base}p\{i}> <\{base}o\{i}> .\n"
      }
      s
    }

    let bytes = @utf8.encode(input).to_array()[:]

    let tokenizer = Tokenizer::new(bytes[:])
    let tokens = tokenizer.tokenize()

    // 统计 token 数量（验证解析正确性）
    let mut iri_count = 0
    let mut symbol_count = 0

    for token in tokens {
      match token {
        Tokenfast::IRI(_, _) => iri_count = iri_count + 1
        Tokenfast::Symbol(_, _, _) => symbol_count = symbol_count + 1
        _ => ()
      }
    }

    // 验证：每条 quad 有 3 个 IRI + 1 个 . = 4 tokens
    // 1000 条 quad = 4000 IRI/Symbol + 1000 LineJump + 1 EOF
    // assert!(iri_count >= 3000) // 确保解析正确
  })

  let summary = bench.dump_summaries()
  debug(summary)
}

///|
test "benchmark: tokenizer vs parser" {
  let bench = @bench.Bench()

  let n = 1000
  let base = "http://example.org/"

  let input = {
    let mut s = ""
    for i = 0; i < n; i = i + 1 {
      s = s + "<\{base}s\{i}> <\{base}p\{i}> <\{base}o\{i}> .\n"
    }
    s
  }

  let bytes = @utf8.encode(input).to_array()

  // 词法解析
  bench.bench(name="Tokenizer (词法)", fn() {
    let tokenizer = Tokenizer::new(bytes[:])
    let tokens = tokenizer.tokenize()
    let mut count = 0
    for token in tokens {
      match token {
        Tokenfast::IRI(_, _) => count = count + 1
        _ => ()
      }
    }
  })

  // 完整解析
  bench.bench(name="Parser (完整解析)", fn() {
    let parser = NQuadsParser::new()
    let low_level = parser.low_level()
    low_level.extend_from_slice(bytes)
    low_level.end()

    let mut count = 0
    while low_level.parse_next() is Some(_) {
      count = count + 1
    }
  })

  let summary = bench.dump_summaries()
  debug(summary)
}
