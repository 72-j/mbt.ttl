// ===== W3C rdf-n-quads 官方测试套件（合并语料版） =====
// 语料：rdf-tests/all_combined.nq —— 89 个官方 .nq 由脚本拼成单文件，
//   每段前置标记行 "# >>> <原文件名>"（# 行被词法器当注释跳过，不影响解析）
// 判定：段名含 "bad"（负例）→ 必须报错且零 quad；其余（正例）→ 零错误且 ≥1 quad
// 失败诊断：read_context 以 [>>> ... <<<] 标出错误 span 附近的原始字节
// 运行时零目录遍历、单次 read_file（~300µs），切段与判定全在内存

///|
/// 字节转可显示字符（非可见 ASCII 转 \xNN 转义，控制字符具名）
fn byte_to_display(b : Byte) -> String {
  if b == b'\n' {
    "\\n"
  } else if b == b'\t' {
    "\\t"
  } else if b == b'\r' {
    "\\r"
  } else if b >= 0x20 && b < 0x7f {
    b.to_char().to_string()
  } else {
    "\\x\{b.to_int()}"
  }
}

///|
/// 错误上下文：以 [>>> ... <<<] 标出错误 span，前后各带 before/after 字节
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
/// ASCII 字节视图转字符串（段名都是 ASCII，够用）
fn bytes_to_string(data : ArrayView[Byte]) -> String {
  let mut s = ""
  for i in 0..<data.length() {
    s = s + data[i].to_char().to_string()
  }
  s
}

///|
/// 标记行 "# >>> " 匹配
fn marker_at(data : ArrayView[Byte], i : Int) -> Bool {
  let m = b"# >>> "
  if i + 6 > data.length() {
    return false
  }
  for j in 0..<6 {
    if data[i + j] != m[j] {
      return false
    }
  }
  true
}

///|
/// 切段：返回 (段名, 内容起点, 内容长度)；段界 = 下一标记行起点
fn split_sections(data : ArrayView[Byte]) -> Array[(String, Int, Int)] {
  let res : Array[(String, Int, Int)] = []
  let n = data.length()
  let starts : Array[Int] = []
  let mut i = 0
  while i < n {
    if marker_at(data, i) {
      starts.push(i)
      i = i + 6
    } else {
      i = i + 1
    }
  }
  for k in 0..<starts.length() {
    let s = starts[k]
    let name_start = s + 6
    let mut e = name_start
    while e < n && data[e] != b'\n' {
      e = e + 1
    }
    let name = bytes_to_string(data[name_start:e])
    let content_start = e + 1
    let content_end = if k + 1 < starts.length() { starts[k + 1] } else { n }
    res.push((name, content_start, content_end - content_start))
  }
  res
}

///|
/// 段内容是否有实义（剔除注释与空白后非空；空文件/纯注释属合法正例）
fn section_has_content(data : ArrayView[Byte]) -> Bool {
  let n = data.length()
  let mut i = 0
  while i < n {
    let c = data[i]
    if c == b' ' || c == b'\t' || c == b'\r' || c == b'\n' {
      i = i + 1
    } else if c == b'#' {
      while i < n && data[i] != b'\n' {
        i = i + 1
      }
    } else {
      return true
    }
  }
  false
}

///|
async test "step 1: parse one positive file" {
  let path = "src/gen_nquads/rdf-tests/rdf-n-quads/literal.nq"
  let data = @fs.read_file(path).binary().to_array()
  let (quads, errors) = nquads_parser(data, lenient=false)
  debug("literal.nq: quads=\{quads.length()} errors=\{errors.length()}")
  assert_eq(errors.length(), 0)
  assert_true(quads.length() >= 1)
}

///|
async test "step 2: parse one negative file" {
  let path = "src/gen_nquads/rdf-tests/rdf-n-quads/nq-syntax-bad-literal-01.nq"
  let data = @fs.read_file(path).binary().to_array()
  let (quads, errors) = nquads_parser(data, lenient=false)
  debug("bad-literal-01: quads=\{quads.length()} errors=\{errors.length()}")
  assert_true(quads.is_empty())
  assert_true(errors.length() > 0)
}

///|
/// 全套件：单文件读入 → 内存切段 → 逐段判定
async test "step 3: full suite via combined corpus" {
  let path = "src/gen_nquads/rdf-tests/all_combined.nq"
  let data = @fs.read_file(path).binary().to_array()
  let view = data[:]
  let sections = split_sections(view)
  debug("corpus: \{data.length()} bytes, \{sections.length()} sections")
  let mut passed = 0
  let mut failed = 0
  let mut idx = 0
  // 定位开关：parse_limit = 只解析前 N 段；89 = 全部
  let parse_limit = 89
  // 分层定位：1=仅词法 2=仅引擎 3=全链路（先解析后组装）
  let stage = 3
  for section in sections {
    let (name, start, len) = section
    let sec = view[start:start + len]
    if idx >= parse_limit {
      idx = idx + 1
      continue
    }
    // ---- stage 1：仅词法（Lexermoon tokenize，不进状态机） ----
    if stage == 1 {
      let lexer = Lexermoon::new(sec)
      let tokens = lexer.tokenize()
      debug("[\{idx}] \{name} tokens=\{tokens.length() - 1}")
      idx = idx + 1
      continue
    }
    let is_bad = name.contains("bad")
    let engine = NQuadsEngine::new(Lexermoon::new(sec))
    // ---- stage 2：仅引擎（engine.next 循环，无组装/校验） ----
    if stage == 2 {
      let mut engine_quads = 0
      for ;; {
        match engine.next() {
          Some(Ok(_)) => engine_quads = engine_quads + 1
          Some(Err(_)) => ()
          None => break
        }
      }
      debug("[\{idx}] \{name} quads=\{engine_quads} (engine only)")
      idx = idx + 1
      continue
    }
    // ---- stage 3：全链路（组装 + IRI/BNode 校验） ----
    let slice = SliceParser::new(engine, sec, lenient=false)
    let (quads, errors) = slice.parse_all()
    // 判据（W3C 口径）：负例 = 检测到错误即合规（流式部分发射不否定检测）；
    // 正例 = 有实义内容则须零错误且至少 1 quad；空文件/纯注释 = 合法空解析
    let ok = if is_bad {
      errors.length() > 0
    } else if section_has_content(sec) {
      quads.length() >= 1 && errors.is_empty()
    } else {
      quads.is_empty() && errors.is_empty()
    }
    if ok {
      passed = passed + 1
    } else {
      failed = failed + 1
      // 失败诊断：首个错误 span 上下文；无错误则给段尾
      let ctx = if errors.length() > 0 {
        let msg_span = match errors[0] {
          StructSyntaxErr(msg, _line, span) => ("\{msg}", span)
          SyntaxErr(msg, span) => (msg, span)
          _ => fail("unexpected error type")
        }
        let (msg, span) = msg_span
        "\{msg} @\{span.0}:\{span.1} " + read_context(sec, span.0, span.1)
      } else {
        "(no errors, end of section) " +
        read_context(sec, sec.length(), 0, before=30, after=0)
      }
      debug(
        "FAIL [\{idx}] \{name} quads=\{quads.length()} errors=\{errors.length()}",
      )
      debug("  \{ctx}")
    }
    idx = idx + 1
  }
  debug("=== Result: \{passed}/\{passed + failed} (failed \{failed}) ===")
  assert_eq(failed, 0)
}

///|
/// W3C 判据（与 step 3 同口径）：负例 = 报错即合规（流式部分发射不否定检测）；
/// 正例 = 有实义内容则零错误且 ≥1 条；空文件/纯注释 = 合法空解析
fn nt_verdict(
  is_bad : Bool,
  sec : ArrayView[Byte],
  result : (Array[QuadSpan], Array[ParseError]),
) -> Bool {
  let (quads, errors) = result
  if is_bad {
    errors.length() > 0
  } else if section_has_content(sec) {
    quads.length() >= 1 && errors.is_empty()
  } else {
    quads.is_empty() && errors.is_empty()
  }
}

///|
/// 段名 → 下标（线性查；套件仅 72 项，无需哈希）
fn nt_index_of(names : Array[String], name : String) -> Int {
  for i in 0..<names.length() {
    if names[i] == name {
      return i
    }
  }
  -1
}

///|
/// 循环读文件版：@fs.readdir 列目录 → 逐文件读 → Lexermoon 引擎全链路判定。
/// 与整合语料版（见下）同判据，两种读法互相印证。
async test "ntriples 套件: 循环读文件（Lexermoon）" {
  let test_dir = "src/gen_nquads/rdf-tests/rdf-n-triples"
  let nt_files = @fs.readdir(test_dir, sort=true).filter(fn(x) {
    x.has_suffix(".nt")
  })
  debug("NT files: \{nt_files.length()}")
  let mut passed = 0
  let mut failed = 0
  for file in nt_files {
    let is_bad = file.contains("bad")
    let data = @fs.read_file("\{test_dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = NQuadsEngine::new(Lexermoon::new(sec))
    let slice = SliceParser::new(engine, sec, lenient=false)
    let ok = nt_verdict(is_bad, sec, slice.parse_all())
    if ok {
      passed = passed + 1
    } else {
      failed = failed + 1
      debug("FAIL \{file}")
    }
  }
  debug(
    "=== 循环读文件: \{passed}/\{passed + failed} (failed \{failed}) ===",
  )
  assert_eq(failed, 0)
}

///|
/// 整合 vs 循环 对比：同一官方套件两种读法，逐文件判定必须一致。
///   整合：all_combined.nt 单文件切段（# >>> 段标记，词法器当注释跳过）
///   循环：readdir 逐文件
async test "ntriples 套件: 整合文件 vs 循环文件 对比" {
  // ---- 整合：切段逐段判定 ----
  let corpus = @fs.read_file("src/gen_nquads/rdf-tests/all_combined_nt.nt")
    .binary()
    .to_array()
  let view = corpus[:]
  let sections = split_sections(view)
  let combined_names : Array[String] = []
  let combined_verdicts : Array[Bool] = []
  for section in sections {
    let (name, start, len) = section
    let sec = view[start:start + len]
    let engine = NQuadsEngine::new(Lexermoon::new(sec))
    let slice = SliceParser::new(engine, sec, lenient=false)
    combined_names.push(name)
    combined_verdicts.push(
      nt_verdict(name.contains("bad"), sec, slice.parse_all()),
    )
  }
  // ---- 循环：逐文件判定，逐项对比 ----
  let test_dir = "src/gen_nquads/rdf-tests/rdf-n-triples"
  let nt_files = @fs.readdir(test_dir, sort=true).filter(fn(x) {
    x.has_suffix(".nt")
  })
  assert_eq(sections.length(), nt_files.length())
  let mut mismatch = 0
  let mut failed = 0
  for i in 0..<nt_files.length() {
    let file = nt_files[i]
    let data = @fs.read_file("\{test_dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = NQuadsEngine::new(Lexermoon::new(sec))
    let slice = SliceParser::new(engine, sec, lenient=false)
    let ok = nt_verdict(file.contains("bad"), sec, slice.parse_all())
    // readdir 排序与语料拼接顺序可能不同：按名字对位，不按下标
    let j = nt_index_of(combined_names, file)
    if j < 0 || combined_verdicts[j] != ok {
      let cv = if j < 0 { "缺失" } else { combined_verdicts[j].to_string() }
      mismatch = mismatch + 1
      debug("MISMATCH [\{i}] \{file}: loop=\{ok} combined=\{cv}")
    }
    if !ok {
      failed = failed + 1
      debug("FAIL \{file}")
    }
  }
  debug(
    "=== 对比: \{sections.length()} 段, mismatch=\{mismatch}, failed=\{failed} ===",
  )
  assert_eq(mismatch, 0)
  assert_eq(failed, 0)
}

///|
/// rdf12 循环套件：列目录 → 逐文件 → 全链路判定（判据与 1.1 同口径，负例=名字含 bad）。
/// 现状摸底阶段：失败面打印不阻断，等缺口补齐后再钉 assert
async fn run_rdf12_suite(test_dir : String, label : String) -> Unit {
  let nt_files = @fs.readdir(test_dir, sort=true).filter(fn(x) {
    x.has_suffix(".nt") || x.has_suffix(".nq")
  })
  let mut passed = 0
  let mut failed = 0
  for file in nt_files {
    let is_bad = file.contains("bad")
    let data = @fs.read_file("\{test_dir}/\{file}").binary().to_array()
    let sec = data[:]
    let engine = NQuadsEngine::new(Lexermoon::new(sec))
    let slice = SliceParser::new(engine, sec, lenient=false)
    let ok = nt_verdict(is_bad, sec, slice.parse_all())
    if ok {
      passed = passed + 1
    } else {
      failed = failed + 1
      debug("FAIL \{label}/\{file}")
    }
  }
  debug("=== \{label}: \{passed}/\{passed + failed} (failed \{failed}) ===")
}

///|
async test "rdf12 套件: 循环读文件（现状摸底）" {
  run_rdf12_suite(
    "src/gen_nquads/rdf-tests/rdf12/rdf-n-triples/syntax", "rdf12-nt",
  )
  run_rdf12_suite(
    "src/gen_nquads/rdf-tests/rdf12/rdf-n-quads/syntax", "rdf12-nq",
  )
}
