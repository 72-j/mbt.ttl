// ===== fsm 分层开销基准（白盒） =====
// 把引擎阶段拆成：Token→Event 转换层 / step+actions 状态机层 / 完整引擎循环
// 用于定位生成器（nquads.mbt 的 step）相对手写版的每 token 开销来源

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

  // (0) 纯词法 → Token 数组（重放的输入，也是词法基线）
  // 注意：Lexermoon::next 到结尾永远返回 Some(EOF)（pos 不推进），必须显式断环；
  // None 只在词法错误（未闭合 IRI 等）时出现
  let lexer = Lexermoon::new(fa[:])
  let tokens : Array[Token] = []
  for ;; {
    match lexer.next() {
      None => break
      Some(t) => if t is Token::EOF(_) { break } else { tokens.push(t) }
    }
  }

  // (1) 仅事件转换：Token → NQuadsEvent（生成的词法适配层）
  let start1 = @bench.monotonic_clock_start()
  let mut conv_count = 0
  for t in tokens {
    ignore(token_to_event(t))
    conv_count = conv_count + 1
  }
  let elapsed1 = @bench.monotonic_clock_end(start1)

  // (2) step 重放：转换 + 生成的状态机 + actions 回调（无词法、无 FFI）
  // 语义对齐引擎主循环：EmitQuad 后按意图粒度重置 ctx，UnexpectedEvent 视为行错误重置
  let hooks = Hooks::new()
  let mut quads_replay = 0
  let start2 = @bench.monotonic_clock_start()
  let ctx = NQuadsContext::new()
  for t in tokens {
    let event = token_to_event(t)
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
  let elapsed2 = @bench.monotonic_clock_end(start2)

  // (3) 完整链路（词法 + 转换 + 状态机 + 组装 + 验证），对照手写 Parser 阶段
  let start3 = @bench.monotonic_clock_start()
  let engine = NQuadsEngine::new(Lexermoon::new(fa[:]))
  let slice = SliceParser::new(engine, fa[:])
  let (quads_full, _errs) = slice.parse_all()
  let engine_count = quads_full.length()
  let elapsed3 = @bench.monotonic_clock_end(start3)

  println("=== fsm 分层开销（\{n} quads, \{tokens.length()} tokens）===")
  println(
    "事件转换:   \{elapsed1} µs (\{conv_count} tokens, 仅 Token→Event)",
  )
  println(
    "step 重放:  \{elapsed2} µs (\{quads_replay} quads, 转换+状态机+回调)",
  )
  println(
    "完整引擎:   \{elapsed3} µs (\{engine_count} quads, 含词法+转换+循环)",
  )
  println(
    "纯状态机:   \{elapsed2 - elapsed1} µs (重放-转换 = step+actions 每token成本)",
  )
  assert_eq(quads_replay, n)
  assert_eq(engine_count, n)
}
