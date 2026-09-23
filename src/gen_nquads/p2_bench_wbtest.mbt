// ===== P2 引擎 step 逐层剖析（役：引擎 3.14 → 1.5-2 ms，第①步）=====
// 分层口径（native release；2026-09-23 P2 开役同笔校准）：
//   A 引擎裸跑（= P1 剖析器 A 段，含词法 + 适配 + FSM + loop 骨架）
//   F 词法→事件适配净（LexerSource.next + 尾点只读检查，含 sink 交通）
//   （T0/T1 切分段退役：P2 刀 a) 后词法器直产事件，Token→Event 转换层不存在）
//   E FSM 净（预构造事件数组直驱 step + hooks + 发射点 snapshot/reset，无词法/loop）
//   ⇒ FSM 层开销 ≈ A − F − E；开役基线（刀前）见 §AP.17
// 分配嫌疑（50k 事件）：Token/Event 双枚举分配 / Span 元组 / set_* 的 Some 装箱 /
//   snapshot 的 PendingQuad+Some 族 / step 的 Result 包装。
// 纪律：读数只留证；本测试断言只做计数一致性。

///|
async fn p2_bench_data() -> Array[Byte] {
  let path = "./src/bench/test_10000.nq"
  Array::from_fixed_array(@fs.read_file(path).binary().to_fixedarray())
}

///|
/// 强制 LexerSource trait 分派（引擎 self.lexer.next() 的真实调度形）
fn[F : LexerSource] p2_trait_next(lexer : F) -> NQuadsEvent? {
  lexer.next()
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

  // F 适配净 ×3：LexerSource.next（P2 直产后 = EOF 滤哨 + 零转换透传）
  // + loop 适配（词尾点只读检查；标准语料点=false，strip 冷路径不走）
  // —— 2026-09-23 P2 开役同笔校准：旧 F 段量的是勘役前 normalize 旧形，读数虚高退役
  let f_elapsed : Array[Double] = []
  for _rep in 0..<3 {
    let lexer = Lexermoon::new(data.copy()[:])
    let start = @bench.monotonic_clock_start()
    let mut count = 0
    let sink : Array[NQuadsEvent] = []
    for ;; {
      match p2_trait_next(lexer) {
        None => break
        Some(ev) => {
          // event_ends_with_dot 等价（词尾字节只读；span 剥点判定同 engine.mbt）
          let span = span_of_event(ev)
          let dot = span.1 > 0 && lexer.byte_at(span.0 + span.1 - 1) == b'.'
          let ev2 = if dot { strip_trailing_dot_event(ev) } else { ev }
          sink.push(ev2)
          count = count + 1
        }
      }
    }
    f_elapsed.push(@bench.monotonic_clock_end(start))
    assert_eq(count, 50_000)
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

