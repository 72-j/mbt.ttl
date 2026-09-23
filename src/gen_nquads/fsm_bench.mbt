// ===== fsm 分层开销基准（白盒） =====
// 把引擎阶段拆成：step+actions 状态机层 / 完整引擎循环
// （P2 刀 a) 后词法器直产事件，Token→Event 转换层退役）

///|
test "fsm 分层开销: 事件转换 / step 重放 / 完整引擎" {
  // 内存语料（与手写版基准同型：1000 条四元组）
  let n = 1000
  let base = "http://example.org/"
  let buf = StringBuilder()
  for i = 0; i < n; i = i + 1 {
    buf.write_string(
      "<\{base}s\{i}> <\{base}p\{i}> <\{base}o\{i}> <\{base}g\{i}> .\n",
    )
  }
  let input = buf.to_string()
  let fa = @utf8.encode(input).to_fixedarray()

  // (0) 纯词法 → 事件数组（重放的输入，也是词法基线；P2 直产）
  // 注意：Lexermoon::next 到结尾永远返回 Some(NQuadsEOF)（pos 不推进），必须显式断环；
  // None 只在词法错误（未闭合 IRI 等）时出现
  let lexer = Lexermoon::new(fa[:])
  let events : Array[NQuadsEvent] = []
  for ;; {
    match lexer.next() {
      None => break
      Some(ev) => if ev is NQuadsEOF { break } else { events.push(ev) }
    }
  }

  // (1) step 重放：事件直驱生成的状态机 + actions 回调（无词法、无 FFI）
  // 语义对齐引擎主循环：EmitQuad 后按意图粒度重置 ctx，UnexpectedEvent 视为行错误重置
  let hooks = Hooks::new()
  let mut quads_replay = 0
  let start1 = @bench.monotonic_clock_start()
  let ctx = NQuadsContext::new()
  for event in events {
    match step(ctx, event, hooks) {
      Ok(effect) =>
        // mutable 契约：step 原地推进 ctx；发射后按 scope 重置复用同一 ctx（零分配）
        match effect {
          EmitQuad(scope) => {
            quads_replay = quads_replay + 1
            ctx.reset(scope)
          }
          _ => ()
        }
      // UnexpectedEvent 视为行错误重置（对齐引擎 recover 口径：清槽位 + 状态归位）
      Err(_) => {
        ctx.reset(ResetScope::All)
        ctx.state = NQuadsExpectSubject
      }
    }
  }
  let elapsed1 = @bench.monotonic_clock_end(start1)

  // (2) 完整链路（词法 + 事件 + 状态机 + 组装 + 验证），对照手写 Parser 阶段
  let start2 = @bench.monotonic_clock_start()
  let engine = NQuadsEngine::new(Lexermoon::new(fa[:]))
  let slice = SliceParser::new(engine, fa[:])
  let (quads_full, _errs) = slice.parse_all()
  let engine_count = quads_full.length()
  let elapsed2 = @bench.monotonic_clock_end(start2)

  println("=== fsm 分层开销（\{n} quads, \{events.length()} events）===")
  println(
    "step 重放:  \{elapsed1} µs (\{quads_replay} quads, 事件+状态机+回调)",
  )
  println(
    "完整引擎:   \{elapsed2} µs (\{engine_count} quads, 含词法+事件+循环)",
  )
  println(
    "引擎骨架:   \{elapsed2 - elapsed1} µs (完整-重放 = 词法+loop 每事件成本)",
  )
  assert_eq(quads_replay, n)
  assert_eq(engine_count, n)
}
