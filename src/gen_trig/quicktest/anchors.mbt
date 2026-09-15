// ========================================
// Anchors — 语义锚点与注入门（trig quicktest / **手维护补充层**）
// FSM: trig_parser | Config: trig_quick_machine
// ========================================
// 分离纪律：同 metrics.mbt——手维护层文件，生成器再生不覆盖。
//
// 定位（与 metrics.mbt 的单元级指标门互补）：**脚本化确定路径**上的模型 ⟺ 引擎
// 双面锚点。随机探索的漂移领土（注解收集态 / 图块 / bnp / list 的保守臂，P4.2d）
//一律不进脚本——每条脚本边界都在注释里写明"为什么不写它"（口径纪律）。
//
// 门清单：
//   ① 三档清槽 quad 值锚点（模型侧 + 引擎侧逐值断言 + 双执行逐步同响应）
//   ② 指令脊柱响应锚点（At/Prefix/Base/Version 四路，纯 Continue 路径）
//   ③ 符号期槽位 ExpectPredicate（Symbolic 引用：槽位保持、状态照常推进）
//   ④ 双注入门：约定外错误码（spec §5 第三档）+ quad 载荷篡改——script 模式
//      下 assert_check 必须检出，检出是确定性的（不依赖随机探索）
// ========================================

///|
/// scripted assert_check 包装：script 模式（游标生成器）跑固定脚本，
/// Err = 机器检出漂移。cases=1 且 max_commands=脚本长——脚本耗尽即止，
/// 不给 Deadlock 留口子。
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
/// 三档清槽脚本（默认图领土，P4.2c 已修面）：一次跑出 EmitQuad(Object)/
/// EmitQuad(PredObj)/EmitQuad(SPO) 三档发射 + 三种清槽粒度。
/// **边界**：不带图块（引擎 graph=Some 模型看不见，P4.2d）、不带注解/bnp/list
/// （收集态保守臂，P4.2d）。
fn scopes_script() -> Array[Command] {
  [
    Iri(Concrete({ id: 1, })), // subject
    Iri(Concrete({ id: 2, })), // predicate
    Literal(Concrete({ id: 3, })), // object
    Comma, // emit (1,2,3,None)，Object 粒度清槽
    Iri(Concrete({ id: 4, })), // object
    Semicolon, // emit (1,2,4,None)，PredObj 粒度清槽（subject 保留）
    Iri(Concrete({ id: 2, })), // predicate
    Iri(Concrete({ id: 6, })), // object
    Dot, // emit (1,2,6,None)，SPO 粒度清槽
  ]
}

///|
/// 模型侧跑脚本收集 EmitQuad（值序列，供两侧比对）
fn model_emitted_quads(script : Array[Command]) -> Array[Quad] {
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
fn engine_step_agree(script : Array[Command]) -> Array[Quad] raise {
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
/// ① 三档清槽 quad 值锚点：模型侧与引擎侧的 quad **逐值断言**——清错槽/不清槽/
/// 多清槽、或引擎发射错 id，都会在这里红。这是对"双执行比较对两侧同错是盲的"
/// （spec §5 固有盲区）的独立规格护栏：期望值手写在断言里，不来自任何一侧。
test "锚点·三档清槽: quad 值级锚点（模型 ⟺ 引擎双面）" {
  let script = scopes_script()
  // 模型侧逐值
  let emitted_model = model_emitted_quads(script)
  assert_eq(emitted_model.length(), 3)
  assert_eq(emitted_model[0], {
    subject: { id: 1, },
    predicate: { id: 2, },
    object: { id: 3, },
    graph: None,
  })
  assert_eq(emitted_model[1], {
    subject: { id: 1, },
    predicate: { id: 2, },
    object: { id: 4, },
    graph: None,
  })
  assert_eq(emitted_model[2], {
    subject: { id: 1, },
    predicate: { id: 2, },
    object: { id: 6, },
    graph: None,
  })
  // 引擎侧逐步同响应 + quad 值**逐条**断言（期望值独立于两侧，spec §5 同错盲区护栏）
  let emitted_engine = engine_step_agree(script)
  assert_eq(emitted_engine.length(), 3)
  assert_eq(emitted_engine[0], {
    subject: { id: 1, },
    predicate: { id: 2, },
    object: { id: 3, },
    graph: None,
  })
  assert_eq(emitted_engine[1], {
    subject: { id: 1, },
    predicate: { id: 2, },
    object: { id: 4, },
    graph: None,
  })
  assert_eq(emitted_engine[2], {
    subject: { id: 1, },
    predicate: { id: 2, },
    object: { id: 6, },
    graph: None,
  })
}

///|
/// ② 指令脊柱响应锚点：四条指令路（@前缀式/PREFIX/BASE/VERSION）——
/// 模型与引擎逐步同响应。指令态不落槽（全空形态族），引擎的 prefixes/bases
/// 不进模型，响应面不可见；**但 directive_at 是例外**：引擎 (ExpectDirectiveEnd,
/// Dot) 挂 directive_at 守卫，模型无此字段恒预测 Continue——这是本门锚点路
/// 避开"非 @ 指令 + Dot"组合的原因（详见路内注释，P4.2d 领土）。
test "锚点·指令脊柱: 四路指令逐步同响应" {
  // At 前缀式: @prefix → 名字 → IRI → Dot 回主语态（@ 路的 Dot 引擎接受）
  let at_path : Array[Command] = [
    At,
    PrefixKw,
    PrefName(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Dot,
  ]
  ignore(engine_step_agree(at_path))
  // 非 @ 指令路（PREFIX/BASE/VERSION）：**不能以 Dot 收尾**——引擎 (ExpectDirectiveEnd,
  // Dot) 挂 directive_at 守卫（@ 路置 true，PREFIX/BASE/VERSION 置 false ⇒ Error(0)）。
  // 模型无 directive_at 字段 ⇒ 恒预测 Continue——模型盲区（P4.2d 领土），锚点路改续三元组。
  let prefix_path : Array[Command] = [
    PrefixKw,
    PrefName(Concrete({ id: 1, })),
    Iri(Concrete({ id: 2, })),
    Iri(Concrete({ id: 5, })), // 续接三元组主语
    Iri(Concrete({ id: 6, })),
    Literal(Concrete({ id: 3, })),
    Dot, // emit (5,6,3,None)
  ]
  ignore(engine_step_agree(prefix_path))
  // BASE: BASE → IRI → 续接三元组
  let base_path : Array[Command] = [
    BaseKw,
    Iri(Concrete({ id: 2, })),
    Iri(Concrete({ id: 5, })),
    Iri(Concrete({ id: 6, })),
    Literal(Concrete({ id: 3, })),
    Dot,
  ]
  ignore(engine_step_agree(base_path))
  // VERSION: VERSION → 字面量 → 续接三元组
  let version_path : Array[Command] = [
    VersionKw,
    Literal(Concrete({ id: 3, })),
    Iri(Concrete({ id: 5, })),
    Iri(Concrete({ id: 6, })),
    Literal(Concrete({ id: 3, })),
    Dot,
  ]
  ignore(engine_step_agree(version_path))
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
/// ④ 双注入门：反例注入验证"机器真能发现漂移"——先证明尺子会咬人，再信绿。
/// script 模式 + assert_check：脚本驱动确定性检出，不依赖随机探索（随机门
/// P4.2d 待开，但注入门走 script 生成器，无需随机领土）。
test "锚点·注入: 约定外错误码必须被检出（unexpected error code）" {
  // 反例注入：系统把 Continue 翻成约定外错误码 Error(99)（[type_mapping].
  // error_codes 只约定 0=未定义转移 / 1=action 失败）。首命令 Iri 的模型预测是
  // Continue ⇒ 检出是确定性的。
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
/// 模型预测 graph 恒 None（metrics 结构钉子门已钉）。首发射在 Comma ⇒ 确定性检出。
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
