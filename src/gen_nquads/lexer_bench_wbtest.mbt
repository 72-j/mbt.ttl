// ===== 词法性能役 P1：Lexermoon 提速测量仪（native-only，含 C FFI 基准线）=====
// 正式口径 = **`--release` + native**（P1 结论，ADR-NQ-009）：
//   moon test --target native --release src/gen_nquads -f "*词法役 P1*"
// debug 档数字只作代码形状回归用，不作性能结论（同一份代码差 8×）。
// 口径：
//   - 只测**纯词法**（`next()` 拉取循环），不涉引擎/验证/物化——便于逐 step 归因；
//   - P2 刀 a)（2026-09-23）起 Lexermoon 直产 NQuadsEvent：月侧口径 = 出事件
//     （含事件构造），与 C 侧（出 Token）**不再逐字同口径**，比值列仅作参考；
//   - token 计数规则两引擎一致：EOF 不计（Lexermoon 的 EOF 变体 / Lexerc 的 None 都不计）；
//   - 语料优先取 `src/bench/` 真实文件，缺省内存生成同形状语料（<s> <p> <o> . 每行）；
//   - 单次计时，同一进程内先后跑（对照的是同一批机器状态）。
// P1 基线（release / 10k 真实语料，三轮交错中位）：
//   Lexermoon ≈ 1505 µs（33.2M tok/s）vs Lexerc ≈ 3039 µs（16.5M tok/s）
//   ⇒ 纯 MoonBit 词法器比 C FFI 路径**快 ~2×**：每 token 一次跨界调用（+12 字节
//   清零 + 3×read_int32）比它省下的 C 扫描时间更贵。

///|
/// 内存生成语料：n 行 `<base s{i}> <base p{i}> <base o{i}> .`
fn lexer_bench_generated(n : Int) -> String {
  let base = "http://example.org/"
  let buf = StringBuilder()
  for i = 0; i < n; i = i + 1 {
    buf.write_string("<\{base}s\{i}> <\{base}p\{i}> <\{base}o\{i}> .\n")
  }
  buf.to_string()
}

///|
/// 纯 MoonBit 词法器：拉取循环（生产路径 = 引擎 step 的取词方式）
fn lexer_bench_moon(data : Array[Byte]) -> Int {
  let lexer = Lexermoon::new(data[:])
  let mut token_count = 0
  for ;; {
    match lexer.next() {
      Some(NQuadsEOF) => break
      Some(_) => token_count = token_count + 1
      None => break
    }
  }
  token_count
}

///|
/// C FFI 词法器：拉取循环（基准线）
fn lexer_bench_c(data : FixedArray[Byte]) -> Int {
  let lexer = Lexerc::new(data)
  let mut token_count = 0
  for ;; {
    match lexer.next() {
      Some(Token::EOF(_)) => break
      Some(_) => token_count = token_count + 1
      None => break
    }
  }
  lexer.destroy()
  token_count
}

///|
/// 单档对照：打印 Lexermoon / Lexerc / 比值
fn lexer_bench_one(label : String, text : String) -> Unit {
  let data = @utf8.encode(text).to_array()
  let fixed = @utf8.encode(text).to_fixedarray()
  // Lexermoon
  let t1 = @bench.monotonic_clock_start()
  let n_moon = lexer_bench_moon(data)
  let d1 = @bench.monotonic_clock_end(t1)
  // Lexerc
  let t2 = @bench.monotonic_clock_start()
  let n_c = lexer_bench_c(fixed)
  let d2 = @bench.monotonic_clock_end(t2)
  let m_tok_s = if d1 > 0.0 { n_moon.to_double() / d1 } else { 0.0 }
  let c_tok_s = if d2 > 0.0 { n_c.to_double() / d2 } else { 0.0 }
  let ratio = if d2 > 0.0 { d1 / d2 } else { 0.0 }
  println(
    "\{label}: Lexermoon \{d1} µs (\{n_moon} tok, \{m_tok_s} M tok/s) | Lexerc \{d2} µs (\{n_c} tok, \{c_tok_s} M tok/s) | 比 \{ratio}×",
  )
}

///|
async test "词法役 P1: Lexermoon vs Lexerc（1k / 10k 纯词法）" {
  println(
    "--- 词法役 P1 纯词法对照（EOF 不计；M tok/s = tokens/µs）---",
  )
  for
    pair in [
      ("1k", "./src/bench/test_1000.nq"),
      ("10k", "./src/bench/test_10000.nq"),
    ] {
    let (label, path) = pair
    if @fs.exists(path) {
      lexer_bench_one("\{label} 真实语料", @fs.read_file(path).text())
    } else {
      lexer_bench_one(
        "\{label} 生成语料",
        lexer_bench_generated(if label == "1k" { 1000 } else { 10000 }),
      )
    }
  }
}
