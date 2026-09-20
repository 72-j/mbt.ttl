// ===== CLI 冒烟（役 A 结构性裁决）：argv 分发直调，2026-09-20 =====
// cmd 包此前 0 测试宿主；argv 获取（进程态）与分发（纯链路）拆开后，
// wbtest 直调 `cmd_parse_argv` 点亮全臂：内联/文件/usage/未知旗/verbose 双臂/错误循环。

///|
async test "wb·CLI 冒烟：argv 分发全臂" {
  // 内联输入 + verbose ⇒ parse_content(verbose=true)
  let verbose_inline = [
    "-v", "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .",
  ]
  cmd_parse_argv(verbose_inline[:])
  // 内联输入（verbose=false ⇒ 序列化打印臂）
  let inline = ["<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> ."]
  cmd_parse_argv(inline[:])
  // 略畸形输入 ⇒ 解析错误循环臂
  let bad = ["<s <p ."]
  cmd_parse_argv(bad[:])
  // 文件路（-f）：临时文件（用后即删）
  @fs.write_file(
    "./cmd_smoke_tmp.nq",
    "<http://ex.org/s> <http://ex.org/p> <http://ex.org/o> .\n",
    create_mode=CreateOrTruncate,
  )
  cmd_parse_argv(["-f", "./cmd_smoke_tmp.nq"][:])
  @fs.remove("./cmd_smoke_tmp.nq")
  // 未知旗 ⇒ Err 分支
  let unknown = ["--nope", "x"]
  cmd_parse_argv(unknown[:])
  // usage 臂（无输入）
  let empty : Array[String] = []
  cmd_parse_argv(empty[:])
}
