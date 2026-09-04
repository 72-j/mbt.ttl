///|
test "词法口径一致性: Lexermoon ≡ Lexerc（同输入同 token 流，EOF 归一化）" {
  // 分歧口径（2026-09-04）：字面量后缀门收紧后，`"text".` 形态 moon 出
  // Literal+Dot、C 版（FFI 冻结）仍吞点——该形态已移出共享电池，生产引擎
  // 只走 Lexermoon（from_bytes），C 版仅存于本对照测试
  for pair in lexer_test_battery() {
    let (input, _) = pair
    let data = @utf8.encode(input).to_fixedarray()
    let lexer = Lexerc::new(data)
    let buf = StringBuilder()
    for ;; {
      match lexer.next() {
        None => break // C 版以 None 收束（EOF token 不外露）
        Some(t) => {
          buf.write_string(lexer_test_fmt_token(t))
          buf.write_string(" ")
        }
      }
    }
    lexer.destroy()
    assert_eq(lexer_test_moon_stream(input), buf.to_string())
  }
}
