// ===== bench 冒烟（役 A 结构性裁决）：四段管线计时直调，2026-09-20 =====
// bench 包此前 0 测试宿主；提取 `bench_all` 后 wbtest 直调同链
// （词法/引擎/验证/物化四段全点亮；main 只留 argv/路径解析）。

///|
async test "wb·bench 冒烟：四段管线直调（1k 档）" {
  bench_all(
    "./src/bench/test_1000.nq",
    @fs.read_file("./src/bench/test_1000.nq").binary(),
  )
}
