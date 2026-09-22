// ===== P2 引擎 step 逐层剖析（役：引擎 3.14 → 1.5-2 ms，第①步）=====
// 分层口径（native release）：
//   A 引擎裸跑（= P1 剖析器 A 段，含词法 + 适配 + FSM + loop 骨架）
//   F 词法→事件适配净（lexer.next + token_to_event + normalize_term_span，无 FSM）
//   E FSM 净（预构造事件数组直驱 step + hooks + 发射点 snapshot/reset，无词法/loop）
//   ⇒ FSM 层开销 ≈ A − F − E（loop 骨架 + 每事件分支/Option 往返）
// 分配嫌疑（50k 事件）：lexer.next Option 装箱 / normalize+trim 两个返回元组 /
//   token_to_event 枚举重建 / set_* 的 Some(payload) 装箱 / step 的 Result 包装。
// 纪律：读数只留证；本测试断言只做计数一致性。

///|
async fn p2_bench_data() -> Array[Byte] {
  let path = "./src/bench/test_10000.nq"
  Array::from_fixed_array(@fs.read_file(path).binary().to_fixedarray())
}

///|
/// 预构造事件流（10k 行 × 5 事件 = 50k；span 用真实递增偏移防常量折叠）
fn p2_events(data : Array[Byte]) -> Array[NQuadsEvent] {
  let events : Array[NQuadsEvent] = []
  let mut off = 0
  for _i in 0..<10000 {
    // 每行 5 事件：subj pred obj graph（Iri）+ Dot；span 载荷照真实偏移推进
    for k in 0..<5 {
      let span = (off, 8)
      events.push(
        if k == 4 {
          off = off + 9
          NQuadsEvent::NQuadsDot
        } else {
          off = off + 26
          NQuadsEvent::NQuadsIri(span)
        },
      )
    }
  }
  let _ = data
  events
}

///|
async test "P2 逐层剖析: 引擎分层计时（A 全链 / F 适配净 / E FSM 净）" {
  let data = p2_bench_data()
  let events = p2_events(data)
  assert_eq(events.length(), 50000)

  // A 引擎裸跑 ×3（与 P1 剖析器 A 段同口径，同笔复读对照抖动）
  let a_elapsed : Array[Double] = []
  for _rep in 0..<3 {
    let engine = NQuadsEngine::from_bytes(data.copy())
    let start = @bench.monotonic_clock_start()
    let mut count = 0
    for ;; {
      match engine.next() {
        Some(Ok(_)) => count = count + 1
        Some(Err(_)) => ()
        None => break
      }
    }
    a_elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(count, 10000)
  }

  // F 适配净 ×3：lexer.next + token_to_event + normalize（50k 事件全走）
  let f_elapsed : Array[Double] = []
  for _rep in 0..<3 {
    let lexer = Lexermoon::new(data.copy()[:])
    let start = @bench.monotonic_clock_start()
    let mut count = 0
    let sink : Array[NQuadsEvent] = []
    for ;; {
      match lexer.next() {
        None => break
        Some(token) =>
          if token is Token::EOF(_) {
            break
          } else {
            let ev = token_to_event(token)
            let (ev2, _dot) = normalize_term_span_for_bench(lexer, ev)
            sink.push(ev2)
            count = count + 1
          }
      }
    }
    f_elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(count, 50000)
    let _ = sink
  }

  // E FSM 净 ×3：预构造事件直驱 step（LoopPolicy 等价机械内联在此：
  // EmitQuad(All) 时 snapshot+reset；begin_record 语义 = reset(All) 已由发射点覆盖）
  let hooks = Hooks::new()
  let e_elapsed : Array[Double] = []
  for _rep in 0..<3 {
    let ctx = NQuadsContext::new()
    let start = @bench.monotonic_clock_start()
    let mut emitted = 0
    let sink : Array[NQuadsPendingQuad] = []
    for ev in events {
      match step(ctx, ev, hooks) {
        Ok(NQuadsEffect::Continue) => ()
        Ok(NQuadsEffect::EmitQuad(scope)) => {
          sink.push(ctx.snapshot())
          ctx.reset(scope)
          emitted = emitted + 1
        }
        Ok(NQuadsEffect::Done) => ()
        Err(NQuadsActionError::UnexpectedEvent(_, _)) => ()
        Err(NQuadsActionError::BusinessFailed(_)) => ()
      }
    }
    e_elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(emitted, 10000)
    let _ = sink
  }

  println(
    "=== P2 引擎逐层剖析（10k 全 IRI 语料 / native release / 3 次取均值）===",
  )
  println(
    "A 引擎全链:   \{a_elapsed[0]} / \{a_elapsed[1]} / \{a_elapsed[2]} µs",
  )
  println(
    "F 适配净:     \{f_elapsed[0]} / \{f_elapsed[1]} / \{f_elapsed[2]} µs",
  )
  println(
    "E FSM 净:     \{e_elapsed[0]} / \{e_elapsed[1]} / \{e_elapsed[2]} µs",
  )
  println(
    "分解: FSM 层开销 ≈ A[\{a_elapsed[2]}] − F[\{f_elapsed[2]}] − E[\{e_elapsed[2]}] = \{a_elapsed[2] - f_elapsed[2] - e_elapsed[2]} µs",
  )
}

///|
/// bench 专用适配（engine.mbt 的 normalize_term_span 是泛型私有扩展；此处等价复刻，
/// 走同一 trim_trailing_dot 机械——F 段量的是"词法→事件"链的真实成本）
fn normalize_term_span_for_bench(
  lexer : Lexermoon,
  event : NQuadsEvent,
) -> (NQuadsEvent, Bool) {
  match event {
    NQuadsIri(span) => {
      let (span2, dot) = trim_trailing_dot(lexer, span)
      (NQuadsIri(span2), dot)
    }
    other => (other, false)
  }
}
