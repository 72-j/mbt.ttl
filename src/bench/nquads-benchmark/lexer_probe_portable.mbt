///|
/// 词法探针（wasm / wasm-gc / js 兜底）：没有 C FFI，退到纯 MoonBit 词法器 `Lexermoon`。
///
/// 与 `lexer_probe_native.mbt` **互斥编译**（moon.pkg 的 `targets` 按目标二选一），
/// 两份文件导出同一对函数名：`lexer_probe_label` / `lexer_probe_tokens`。
/// 口径对齐：同一 token 字母表、同一计数规则（EOF token 不计入）。

///|
fn lexer_probe_label() -> String {
  "MoonBit Lexermoon（wasm/js 兜底，无 FFI）"
}

///|
/// 词法计数：EOF token 不计入（与 gen_nquads 内部 `Lexermoon::tokenize` 同口径）。
fn lexer_probe_tokens(data : FixedArray[Byte]) -> Int {
  let lexer = @nquads.Lexermoon::new(data[:])
  let mut token_count = 0
  for ;; {
    match lexer.next() {
      Some(@nquads.Token::EOF(_)) => break
      Some(_) => token_count = token_count + 1
      None => break
    }
  }
  token_count
}
