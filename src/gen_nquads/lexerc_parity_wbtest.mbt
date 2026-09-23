///|
test "词法口径一致性: Lexermoon ≡ Lexerc（同输入同事件流，C 侧经 token_to_event 同分母）" {
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
        None => {
          // 终点 EOF@<pos> 同钉（月侧 moon_stream 同形），分母一致
          buf.write_string("EOF@\{lexer.position()} ")
          break
        }
        Some(t) => {
          let ev = token_to_event(t)
          // 结构 Token 的 span 携带起点；字面事件 span 自带（start 不参与）
          let start = match t {
            Token::Dot(s) => s.0
            Token::Semicolon(s) => s.0
            Token::Comma(s) => s.0
            _ => 0
          }
          buf.write_string(lexer_test_fmt_event_at(ev, start))
          buf.write_string(" ")
        }
      }
    }
    lexer.destroy()
    assert_eq(lexer_test_moon_stream(input), buf.to_string())
  }
}
