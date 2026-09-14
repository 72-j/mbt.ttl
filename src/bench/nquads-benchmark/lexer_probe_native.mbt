///|
/// 词法探针（native）：走 C FFI 词法器 `Lexerc`——本包唯一需要 native-stub 的路径。
///
/// 与 `lexer_probe_portable.mbt` **互斥编译**（moon.pkg 的 `targets` 按目标二选一），
/// 两份文件导出同一对函数名：`lexer_probe_label` / `lexer_probe_tokens`。

///|
fn lexer_probe_label() -> String {
  "C FFI Lexerc（native）"
}

///|
/// 词法计数：EOF token 不计入（与 gen_nquads 内部 `Lexermoon::tokenize` 同口径）。
fn lexer_probe_tokens(data : FixedArray[Byte]) -> Int {
  let lexer = @nquads.Lexerc::new(data)
  let mut token_count = 0
  for ;; {
    match lexer.next() {
      Some(@nquads.Token::EOF(_)) => break
      Some(_) => token_count = token_count + 1
      None => break
    }
  }
  lexer.destroy()
  token_count
}
