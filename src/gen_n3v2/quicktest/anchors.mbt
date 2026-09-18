// ========================================
// Anchors — 语义锚点与注入门（n3 quicktest / **手维护补充层**，P5.5 第二笔）
// FSM: n3_parser | Config: n3_quick_machine
// ========================================
// 分离纪律：同 metrics.mbt——手维护层文件，生成器再生不覆盖。
//
// 定位（照 trig anchors.mbt 同构，ADR-QM-011"值锚点属规格、不由生成器产"）：
// **脚本化确定路径**上的模型 ⟺ 引擎双面锚点 + 手写期望值——随机门对"两侧同错"
// 是盲的（spec §5 固有盲区），这里用独立于两侧的手写期望值当规格护栏。
// 随机门正片已盖的机械不重复铺脚本——只钉随机抽样给不了"逐值/逐码确定性"的块。
//
// 门清单：
//   ① 三档清槽 quad 值锚点（模型侧 + 引擎侧逐值断言 + 双执行逐步同响应）
//   ② 指令脊柱：@路全 Continue；**双守卫 Error(0) 钉**（directive_at /
//      version_lit_ok 都已被 guard 收养进模型——比 trig P4.2d 盲区强：
//      trig 只能绕开 directive_at，n3 两侧都判得出 Error(0)，直接钉死）
//   ③ 符号期槽位 ExpectPredicate（Symbolic 引用：槽位保持、状态照常推进）
//   ④ 双注入门：约定外错误码（error_codes 只约定 0/1）+ quad 载荷篡改
//      （graph 塞假图）——script 模式 assert_check 确定性检出 + 负控
// ========================================

///|
/// scripted assert_check 包装：script 模式（游标生成器）跑固定脚本，
/// Err = 机器检出漂移。cases=1 且 max_commands=脚本长——脚本耗尽即止，
/// 不给 Deadlock 留口子（trig 同款）。
fn scripted_check(
  script : Array[Command],
  system_call? : (Command, System) -> Response = run_command,
) -> Result[@qcs.RunReport[Command, Response, Command, Response], Error] {
  let config : @qcs.RunConfig = {
    ..quick_run_config(),
    cases: 1,
    max_commands: script.length(),
  }
  Ok(
    @qcs.assert_check(
      quick_state_machine(script=Some(script), system_call~),
      config~,
    ),
  ) catch {
    err => Err(err)
  }
}

///|
/// 三档清槽脚本：一次跑出 EmitQuad(Object)/EmitQuad(PredObj)/EmitQuad(SPO)
/// 三档发射 + 三种清槽粒度（emit_* = 全快照 + 粒度清槽，ADR-QM-009）。
/// **边界**：不带 bnp/路径/注解（帧族排除片，quicktest todo §6.2）。
fn scopes_script() -> Array[Command] {
  [
    Iri(Concrete({ id: 1, })), // subject
    Iri(Concrete({ id: 2, })), // predicate
    Literal(Concrete({ id: 3, })), // object
    Comma, // emit 快照 (1,2,3,None)，Object 粒度清槽
    Iri(Concrete({ id: 4, })), // object
    Semicolon, // emit (1,2,4,None)，PredObj 粒度清槽（subject 保留）
    Iri(Concrete({ id: 2, })), // predicate
    Iri(Concrete({ id: 6, })), // object
    Dot, // emit (1,2,6,None)，SPO 粒度清槽
  ]
}

///|
/// 模型侧跑脚本收集 EmitQuad（值序列，供两侧比对）
fn anchor_model_emitted_quads(script : Array[Command]) -> Array[Quad] {
  let emitted : Array[Quad] = []
  let mut model = model_empty()
  for command in script {
    let (next, response) = model_execute(model, command)
    match response {
      EmitQuad(quad) => emitted.push(quad)
      _ => ()
    }
    model = next
  }
  emitted
}

///|
/// 引擎侧跑脚本：逐步断言引擎响应 == 模型预测（双执行逐步同响应，含错误码），
/// 收集引擎 EmitQuad 值序列
fn anchor_engine_step_agree(script : Array[Command]) -> Array[Quad] raise {
  let system = system_init()
  let emitted : Array[Quad] = []
  let mut model = model_empty()
  for command in script {
    let engine_response = run_command(command, system)
    let (next, expected) = model_execute(model, command)
    assert_eq(engine_response, expected) // 双执行逐步一致
    match engine_response {
      EmitQuad(quad) => emitted.push(quad)
      _ => ()
    }
    model = next
  }
  emitted
}

///|
/// 模型跑完整脚本的**最后一响应**（守卫路的期望值手写锚：钉 Error(0) 用）
fn anchor_model_last_response(script : Array[Command]) -> Response {
  let mut model = model_empty()
  let mut response = Continue
  for command in script {
    let (next, r) = model_execute(model, command)
    model = next
    response = r
  }
  response
}

///|
/// ① 三档清槽 quad 值锚点：模型侧与引擎侧的 quad **逐值断言**——清错槽/不清槽/
/// 多清槽、或引擎发射错 id，都会在这里红。期望值手写在断言里，不来自任何一侧。
test "锚点·三档清槽: quad 值级锚点（模型 ⟺ 引擎双面）" {
  let script = scopes_script()
  // 模型侧逐值
  let emitted_model = anchor_model_emitted_quads(script)
  assert_eq(emitted_model.length(), 3)
  assert_eq(emitted_model[0], {
    subject: Some({ id: 1, }),
    predicate: Some({ id: 2, }),
    object: Some({ id: 3, }),
    graph: None,
  })
  assert_eq(emitted_model[1], {
    subject: Some({ id: 1, }),
    predicate: Some({ id: 2, }),
    object: Some({ id: 4, }),
    graph: None,
  })
  assert_eq(emitted_model[2], {
    subject: Some({ id: 1, }),
    predicate: Some({ id: 2, }),
    object: Some({ id: 6, }),
    graph: None,
  })
  // 引擎侧逐步同响应 + quad 值**逐条**断言（期望值独立于两侧）
  let emitted_engine = anchor_engine_step_agree(script)
  assert_eq(emitted_engine.length(), 3)
  assert_eq(emitted_engine[0], {
    subject: Some({ id: 1, }),
    predicate: Some({ id: 2, }),
    object: Some({ id: 3, }),
    graph: None,
  })
  assert_eq(emitted_engine[1], {
    subject: Some({ id: 1, }),
    predicate: Some({ id: 2, }),
    object: Some({ id: 4, }),
    graph: None,
  })
  assert_eq(emitted_engine[2], {
    subject: Some({ id: 1, }),
    predicate: Some({ id: 2, }),
    object: Some({ id: 6, }),
    graph: None,
  })
}

///|
/// ② 指令脊柱：四条指令路。n3 与 trig 的分野：trig 模型无 directive_at 字段
/// （P4.2d 盲区，非 @ 指令路只能避开 Dot）；n3 的 directive_at 与 version_lit_ok
/// 都被 guard 收养进模型（P5.3 guard_def 裸名修的产出），两条守卫路可以**双面
/// 钉死 Error(0)**——期望值手写，不借任何一侧。
test "锚点·指令脊柱: @路 Continue + 双守卫 Error(0) 钉" {
  // @路：At(directive_at=true) → kind → 名字 → IRI → Dot 收（守卫放行）
  let at_path : Array[Command] = [
    At,
    PrefixKw,
    PrefName(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Dot,
  ]
  ignore(anchor_engine_step_agree(at_path)) // 全 Continue 逐步同响应
  // 非 @ 直 PREFIX 路：directive_at=false ⇒ Dot 必 Error(0)（两侧同判）
  let prefix_dot_path : Array[Command] = [
    PrefixKw,
    PrefName(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Dot,
  ]
  assert_eq(anchor_model_last_response(prefix_dot_path), Error(0)) // 手写期望
  ignore(anchor_engine_step_agree(prefix_dot_path)) // 引擎同判
  // BASE 路：directive_at=false ⇒ 不能以 Dot 收，续接三元组（emit 值钉）
  let base_path : Array[Command] = [
    BaseKw,
    Iri(Concrete({ id: 2, })), // base IRI
    Iri(Concrete({ id: 5, })), // 续接三元组主语
    Iri(Concrete({ id: 6, })),
    Literal(Concrete({ id: 3, })),
    Dot, // emit (5,6,3,None)
  ]
  let emitted = anchor_engine_step_agree(base_path)
  assert_eq(emitted.length(), 1)
  assert_eq(emitted[0], {
    subject: Some({ id: 5, }),
    predicate: Some({ id: 6, }),
    object: Some({ id: 3, }),
    graph: None,
  })
  // VERSION 路：version_lit_ok 初值 false 且无写点（引擎 n3.mbt:201 / 模型
  // model_empty 同false）⇒ 指令字面量必 Error(0)（两侧同判，守卫现行）
  let version_path : Array[Command] = [VersionKw, Literal(Concrete({ id: 3, }))]
  assert_eq(anchor_model_last_response(version_path), Error(0)) // 手写期望
  ignore(anchor_engine_step_agree(version_path)) // 引擎同判
}

///|
/// ③ 符号期槽位保持：Symbolic 引用无法解析具体值——槽位保持、状态照常推进
/// （set_* 的 None 分支）。符号执行期 mock 的关键语义：序列生成只关心状态推进，
/// 不依赖具体值。Concrete 引用照常落槽作对照。
test "锚点·符号期槽位保持" {
  let (next, response) = model_execute(
    model_empty(),
    Iri(Symbolic(@qcs.Var::{ id: 0, })),
  )
  assert_eq(response, Continue)
  assert_eq(next.state, ExpectPredicate)
  assert_false(next.subject is Some(_))
  // 对照组：Concrete 引用照常落槽
  let (concrete_next, _) = model_execute(
    model_empty(),
    Iri(Concrete({ id: 1, })),
  )
  assert_eq(concrete_next.subject, Some({ id: 1, }))
}

///|
/// ③ 姊妹门（笔 3a 同笔）：符号期**全矩阵扫**——55 态 × 41 命令全对以 Symbolic
/// 载荷驱动。3a 把 set_* 辅助的 None 半区展开成逐行内联 `match ref_id`（普查命令
/// 恒 Concrete 打不亮）；本扫验证"槽位保持、状态照常推进"（ADR-QM-009 符号期
/// 口径）在每一行都成立，兼当全行体无爆炸的冒烟 + 帧哨兵点亮。
test "锚点·符号期全矩阵扫: 槽位保持语义逐行成立" {
  let states = [
    ExpectSubject, ExpectPredicate, ExpectObject, ExpectDotOrGraph,
    ExpectDirectiveKind, ExpectPrefixName, ExpectPrefixIri, ExpectBaseIri,
    ExpectVersionLiteral, ExpectDirectiveEnd, ExpectKeywordsList,
    ExpectVerbOrEnd, ExpectVerbOrDot, ExpectVerbRequired, ExpectTildeEnd,
    AnnotExpectVerb, AnnotExpectVerbTail, AnnotExpectObject, AnnotExpectEnd,
    BnpExpectPredicate, BnpExpectIdNode, BnpExpectObject, BnpAfterObject,
    BnpIdAfterClose, ListExpectElemOrEnd, ListAfterElem,
    FormulaExpectSubject, FormulaExpectPredicate, FormulaExpectObject,
    FormulaAfterObject, PathExpectVerb, PathAfterStep,
    FormulaPathExpectVerb, FormulaPathAfterStep, ExpectIsProp, ExpectIsOf,
    BnpExpectIsProp, BnpExpectIsOf, FormulaExpectIsProp, FormulaExpectIsOf,
    QuantExpectVar, QuantExpectVarOrDot, FormulaDirectiveKind,
    FormulaQuantExpectVar, FormulaQuantExpectVarOrDot, SubjTrailExpectVerb,
    SubjTrailAfterStep, SubjTrailVerbDone, SubjTrailExpectVerbFormula,
    SubjTrailAfterStepFormula, SubjTrailVerbDoneFormula, ListPathExpectVerb,
    ListPathAfterStep, ObjTrailExpectVerb, ObjTrailAfterStep,
  ]
  let sym : @qcs.Ref[RefId] = Symbolic(@qcs.Var::{ id: 0, })
  let commands = [
    Iri(sym), BlankNode(sym), Literal(sym), PrefName(sym), TripleTerm(sym),
    BracketTripleTerm(sym), KeywordA(sym), Variable(sym), KeywordX(sym),
    Equals(sym), Is, Of, Has, At, PrefixKw, BaseKw, VersionKw, Tilde,
    AnnotStart, AnnotEnd, ForAllKw, ForSomeKw, KeywordsKw, Comma, Semicolon,
    Dot, Lbrace(sym), Rbrace, Lbracket(sym), Rbracket, Lparen(sym), Rparen,
    Anon(sym), Bang(sym), Caret(sym), Implies(sym), ImpliedBy(sym),
    Unknown(sym), Id, Invert, EOF,
  ]
  for state in states {
    for command in commands {
      // 符号期口径：全对不炸、照常返回（穷尽性由表结构与类型保证）
      let (next, _) = model_execute({ ..model_empty(), state: state }, command)
      ignore(next)
    }
  }
  // 逐值锚 1：内联 None 半区 = 旧槽值保持、状态照常推进（3a 内联化后的行级钉）
  let keep = {
    ..model_empty(),
    state: ExpectPredicate,
    predicate: Some({ id: 9 }),
  }
  let (kept, _) = model_execute(keep, Equals(sym))
  assert_eq(kept.predicate, Some({ id: 9 })) // None 半区保持
  assert_eq(kept.state, ExpectObject) // 状态照常推进
  // 逐值锚 2：trail 行 Symbolic 载荷——path_tail 保持、fwd 照常拨真
  let trail = {
    ..model_empty(),
    state: SubjTrailAfterStep,
    path_src: Some({ id: 1 }),
    path_pend: Some({ id: 3 }),
    path_tail: Some({ id: 2 }),
  }
  let (tnext, tres) = model_execute(trail, Bang(sym))
  assert_true(tres is EmitQuad(_))
  assert_eq(tnext.path_tail, Some({ id: 2 })) // Symbolic ⇒ 保持
  assert_eq(tnext.path_fwd, true) // hop 后照常拨 fwd
  // 逐值锚 3：frame_push 符号期哨兵 RefId(0)
  let (fnext, _) = model_execute(
    { ..model_empty(), state: ExpectObject },
    Lparen(sym),
  )
  assert_eq(fnext.frames.length(), 1)
  assert_eq(fnext.frames[0].open_span, { id: 0 })
}

///|
/// ④ 双注入门：反例注入验证"机器真能发现漂移"——先证明尺子会咬人，再信绿。
/// script 模式 + assert_check：脚本驱动确定性检出，不依赖随机探索。
test "锚点·注入: 约定外错误码必须被检出（unexpected error code）" {
  // 反例注入：系统把 Continue 翻成约定外错误码 Error(99)（约定只认
  // 0=未定义转移 / 1=action 失败）。首命令 Iri 的模型预测是 Continue ⇒
  // 检出是确定性的。
  let code_flipping = fn(command : Command, system : System) -> Response {
    match run_command(command, system) {
      Continue => Error(99)
      other => other
    }
  }
  match
    scripted_check(
      [
        Iri(Concrete({ id: 1, })),
        Iri(Concrete({ id: 2, })),
        Iri(Concrete({ id: 3, })),
        Dot,
      ],
      system_call=code_flipping,
    ) {
    Ok(_) =>
      fail("约定外错误码必须被检出（unexpected error code）")
    Err(_) => () // 检出 ✓
  }
}

///|
/// ④ 姊妹门：quad 载荷篡改必须被检出——引擎侧把发射 quad 的 graph 塞上假图名，
/// 模型快照 graph 恒 None（正片无图事件）。首发射在 Comma ⇒ 确定性检出。
test "锚点·注入: quad 载荷篡改必须被检出" {
  let quad_tamper = fn(command : Command, system : System) -> Response {
    match run_command(command, system) {
      EmitQuad(quad) => EmitQuad({ ..quad, graph: Some({ id: 0, }), })
      other => other
    }
  }
  match scripted_check(scopes_script(), system_call=quad_tamper) {
    Ok(_) => fail("quad 载荷篡改必须被检出")
    Err(_) => () // 检出 ✓
  }
}

///|
/// 对照组（门的负控）：未注入的 scopes 脚本经 qcs 全组装（script 模式 +
/// assert_check）必须通过——证明注入门的"检出"来自注入本身，不是组装面自带漂移。
test "锚点·负控: 未注入脚本经全组装通过" {
  match scripted_check(scopes_script()) {
    Ok(report) => assert_eq(report.commands_run, scopes_script().length())
    Err(failure) => fail("负控失败（组装面自带漂移）: \{failure}")
  }
}

///|
/// ⑤ 公式帧族锚点（笔 3c 下半·三，放开权重前的确定性复跑）：三位置 + 空式 + 嵌套，
/// 逐值手写期望——罩内发射被压制（ADR-002）、弹帧后正片恢复、占位 = 帧引用（与 Bnp
/// 占位同口径）。此五案在权重 0 时代被随机门掩盖（组合路径，census 逐对新鲜复位
/// 看不见）：谓位案 F3 曾是**真分道**（引擎 (1,7,6) vs 模型 (1,None,6)，as_pred
/// 缺口的公式孪生），弹帧回写占位后两侧同步。
fn anchor_expect_quads(script : Array[Command], expected : Array[Quad]) -> Unit raise {
  let emitted_model = anchor_model_emitted_quads(script)
  assert_eq(emitted_model.length(), expected.length())
  for i = 0; i < expected.length(); i = i + 1 {
    assert_eq(emitted_model[i], expected[i])
  }
  // 引擎侧逐步同响应（含错误码）+ quad 逐条断言（期望值独立于两侧）
  let emitted_engine = anchor_engine_step_agree(script)
  assert_eq(emitted_engine.length(), expected.length())
  for i = 0; i < expected.length(); i = i + 1 {
    assert_eq(emitted_engine[i], expected[i])
  }
}

///|
test "锚点·公式帧族: 三位置 + 空式 + 嵌套（罩内压制 + 弹帧回写占位）" {
  // F1 宾位 + 罩内两条（; 续）：全压制；弹帧后 Dot 发外层 (1,2,9)
  anchor_expect_quads(
    [
      Iri(Concrete({ id: 1, })), Iri(Concrete({ id: 2, })), Lbrace(Concrete({ id: 9, })),
      Iri(Concrete({ id: 3, })), Iri(Concrete({ id: 4, })), Iri(Concrete({ id: 5, })),
      Semicolon, Iri(Concrete({ id: 6, })), Iri(Concrete({ id: 7, })), Rbrace, Dot,
    ],
    [{ subject: Some({ id: 1 }), predicate: Some({ id: 2 }), object: Some({ id: 9 }), graph: None }],
  )
  // F2 主位：弹帧回写主槽（as_subject 既有机械），后续三元组发 (8,2,6)
  anchor_expect_quads(
    [
      Lbrace(Concrete({ id: 8, })), Iri(Concrete({ id: 3, })), Iri(Concrete({ id: 4, })),
      Iri(Concrete({ id: 5, })), Rbrace, Iri(Concrete({ id: 2, })), Iri(Concrete({ id: 6, })), Dot,
    ],
    [{ subject: Some({ id: 8 }), predicate: Some({ id: 2 }), object: Some({ id: 6 }), graph: None }],
  )
  // F3 谓位（权重 0 时代被掩盖的真分道，历史反例族）：弹帧回写谓词槽，发 (1,7,6)
  anchor_expect_quads(
    [
      Iri(Concrete({ id: 1, })), Lbrace(Concrete({ id: 7, })), Iri(Concrete({ id: 3, })),
      Iri(Concrete({ id: 4, })), Iri(Concrete({ id: 5, })), Rbrace, Iri(Concrete({ id: 6, })), Dot,
    ],
    [{ subject: Some({ id: 1 }), predicate: Some({ id: 7 }), object: Some({ id: 6 }), graph: None }],
  )
  // F4 空公式（开括号即收口）：发 (1,2,7)
  anchor_expect_quads(
    [Iri(Concrete({ id: 1, })), Iri(Concrete({ id: 2, })), Lbrace(Concrete({ id: 7, })), Rbrace, Dot],
    [{ subject: Some({ id: 1 }), predicate: Some({ id: 2 }), object: Some({ id: 7 }), graph: None }],
  )
  // F5 嵌套（公式套公式，宾位）：双层罩全压制，外层弹净后发 (1,2,9)
  anchor_expect_quads(
    [
      Iri(Concrete({ id: 1, })), Iri(Concrete({ id: 2, })), Lbrace(Concrete({ id: 9, })),
      Iri(Concrete({ id: 3, })), Iri(Concrete({ id: 4, })), Lbrace(Concrete({ id: 10, })),
      Iri(Concrete({ id: 5, })), Iri(Concrete({ id: 6, })), Iri(Concrete({ id: 7, })),
      Rbrace, Rbrace, Dot,
    ],
    [{ subject: Some({ id: 1 }), predicate: Some({ id: 2 }), object: Some({ id: 9 }), graph: None }],
  )
}

///|
/// ⑥ 谓位 Bnp 反例复跑（笔 3c 下半·三）：`:_b [:i :o] 58 ;`——quick_machine_n3.toml
/// 头部口径载明的反例（引擎 (3,59,58)、模型丢谓词发 (3,None,58)）。as_pred 弹帧
/// 回写后两侧同步；Bnp 族权重仍 0（放开属下一笔同款确认舞），但机械已值级钉死。
/// 发射两枚：内层 (59,4,5) 在 `]`（emit_predobj+pop，PredObj 粒度）、外层 (3,59,58)
/// 在 `;`——旧反例注释只记了当年分道的外层枚。
test "锚点·谓位 Bnp 反例复跑: 内层 + 占位回写双枚值级钉死" {
  anchor_expect_quads(
    [
      BlankNode(Concrete({ id: 3, })), Lbracket(Concrete({ id: 59, })),
      Iri(Concrete({ id: 4, })), Iri(Concrete({ id: 5, })), Rbracket,
      Literal(Concrete({ id: 58, })), Semicolon,
    ],
    [
      { subject: Some({ id: 59 }), predicate: Some({ id: 4 }), object: Some({ id: 5 }), graph: None },
      { subject: Some({ id: 3 }), predicate: Some({ id: 59 }), object: Some({ id: 58 }), graph: None },
    ],
  )
}
