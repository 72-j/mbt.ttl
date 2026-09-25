// B2 Light 档探针（白盒，2026-09-25）：合成语料 + **同进程交替 A/B**（A=Deep、B=Light），
// 只量 `parse_all + materialize_all`（不含建库/进程启动）。判据见 `../gen_nquads/const.md` §X：
// **带不交叠才下结论**，交叠记"无结论"（禁硬编差距）。

///|
/// 合成 N 行 turtle（每行一条绝对 IRI 三元组，避开前缀/转义干扰）
fn synth_turtle(n : Int) -> Array[Byte] {
  let mut s = ""
  for i in 0..<n {
    s = s +
      "<http://e/s" +
      i.to_string() +
      "> <http://e/p" +
      i.to_string() +
      "> \"o\" .\n"
  }
  bytes_of(s)
}

///|
/// 单次量：解析 + 物化为给定档位，返回 (ms, quad 数)
fn timed_once(data : Array[Byte], mode : @nquads.ValidateMode) -> (Double, Int) {
  let start = @bench.monotonic_clock_start()
  let engine = TrigEngine::from_bytes(data)
  let sec = data[:]
  let slice = TrigSliceParser::new(engine, sec, mode~)
  let (quads, _) = slice.parse_all()
  let mat = TrigMaterializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, _) = mat.materialize_all(quads, mode~)
  let us = @bench.monotonic_clock_end(start)
  (us / 1000.0, emits.length())
}

///|
test "B2 Light 档探针（trig）：交错 A/B" {
  let n = 10000
  let data = synth_turtle(n)
  let deep : Array[Double] = []
  let light : Array[Double] = []
  let mut quads = 0
  for _ in 0..<5 {
    let (d, q) = timed_once(data, @nquads.ValidateMode::Deep)
    deep.push(d)
    quads = q
    let (l, _) = timed_once(data, @nquads.ValidateMode::Light)
    light.push(l)
  }
  let dmin = deep
    .iter()
    .fold(init=999999.0, (a, b) => if b < a { b } else { a })
  let lmin = light
    .iter()
    .fold(init=999999.0, (a, b) => if b < a { b } else { a })
  println("=== B2 Light 档探针 trig（n=\{n} quads=\{quads}）===")
  println(
    "  deep 五轮: \{deep[0]} / \{deep[1]} / \{deep[2]} / \{deep[3]} / \{deep[4]}",
  )
  println(
    "  light 五轮: \{light[0]} / \{light[1]} / \{light[2]} / \{light[3]} / \{light[4]}",
  )
  println(
    "  deep 最优=\{dmin}  light 最优=\{lmin}  省幅=\{1.0 - lmin / dmin}",
  )
  println(
    "  判据：带不交叠才下结论（deep 最低 vs light 最高）",
  )
}

///|
/// 分段拆解（B2 ②，trig）：同 n3v2 形；trig 物化构造无 `rdf12` 形参。
fn split_once(
  data : Array[Byte],
  mode : @nquads.ValidateMode,
) -> (Double, Double, Int) {
  let t1 = @bench.monotonic_clock_start()
  let slice = TrigSliceParser::new(TrigEngine::from_bytes(data), data[:], mode~)
  let (quads, _) = slice.parse_all()
  let us1 = @bench.monotonic_clock_end(t1)
  let t2 = @bench.monotonic_clock_start()
  let mat = TrigMaterializer::new(
    data[:],
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, _) = mat.materialize_all(quads, mode~)
  let us2 = @bench.monotonic_clock_end(t2)
  (us1 / 1000.0, us2 / 1000.0, emits.length())
}

///|
test "B2 分段拆解（trig）" {
  let n = 10000
  let data = synth_turtle(n)
  let (dp, dm, q) = split_once(data, @nquads.ValidateMode::Deep)
  let (lp, lm, _) = split_once(data, @nquads.ValidateMode::Light)
  println("=== B2 分段拆解 trig（n=\{n} quads=\{q}）===")
  println("  deep  解析=\{dp} ms  物化=\{dm} ms")
  println("  light 解析=\{lp} ms  物化=\{lm} ms")
}
