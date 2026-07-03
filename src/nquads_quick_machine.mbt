
///|
// ============================================================
// 1. 核心类型定义
// ============================================================


///|
// ============================================================
// 2. Command / Response 定义
// ============================================================

///|
/// 可生成的命令：模拟逐行输入 N-Quads
pub(all) enum Command {
  // 解析一行完整四元组（含命名图）
  ParseQuad(NamedOrBlankNodeRef, NamedNodeRef, TermRef, GraphNameRef)

  // 解析一行三元组（默认图，省略 graph）
  ParseTriple(NamedOrBlankNodeRef, NamedNodeRef, TermRef)

  // 解析带语言标签的字面量
  ParseLiteralQuad(
    NamedOrBlankNodeRef,
    NamedNodeRef,
    String,
    String,
    GraphNameRef
  )
  // (subject, predicate, literal_value, lang_tag, graph)

  // 解析带数据类型的字面量
  ParseTypedLiteral(
    NamedOrBlankNodeRef,
    NamedNodeRef,
    String,
    NamedNodeRef,
    GraphNameRef
  )
  // (subject, predicate, literal_value, datatype, graph)

  // Blank Node 作为 subject
  ParseBlankSubject(BlankNodeRef, NamedNodeRef, TermRef, GraphNameRef)

  // Blank Node 作为 object
  ParseBlankObject(
    NamedOrBlankNodeRef,
    NamedNodeRef,
    BlankNodeRef,
    GraphNameRef
  )
} derive(Eq, Debug)

///|
/// 解析响应
pub(all) enum Response {
  QuadParsed
  TripleParsed
  LiteralParsed
  TypedLiteralParsed
  BlankSubjectParsed
  BlankObjectParsed
} derive(Eq, Debug)

///|
// ============================================================
// 3. Model（纯函数规范 — 预言机）
// ============================================================

///|
/// 纯模型：N-Quads 文档"应该"包含的内容
pub(all) struct Model {
  quads : Array[Quad]
} derive(Debug)

///|
/// 1️⃣ init_symbolic_model
/// 意图：创建初始符号模型（空状态）
fn init_symbolic_model() -> Model {
  { quads: [] }
}

///|
/// 1️⃣ init_concrete_model  
/// 意图：创建初始具体模型（与符号模型同构）
fn init_concrete_model() -> Model {
  { quads: [] }
}

///|
/// 模型辅助：追加四元组
fn model_add_quad(model : Model, quad : Quad) -> Model {
  let quads = model.quads.copy()
  quads.push(quad)
  { quads, }
}

///|
/// 模型辅助：构建 Quad
fn make_quad(
  subject : NamedOrBlankNodeRef,
  predicate : NamedNodeRef,
  object : TermRef,
  graph_name : GraphNameRef,
) -> Quad {
  {
    subject: subject.into_owned(),
    predicate: predicate.into_owned(),
    object: object.into_owned(),
    graph_name: graph_name.into_owned(),
  }
}

///|
// ============================================================
// 4. System Under Test（被测系统）
// ============================================================

///|
/// 包装真实 N-Quads 解析器
/// 这里用简单状态模拟，实际替换为你的解析器
pub(all) struct NQuadsSystem {
  quads : Array[Quad]
  mut line_number : Int
}

///|
/// 2️⃣ init_system
/// 意图：初始化被测系统（空状态）
fn init_system() -> NQuadsSystem {
  { quads: [], line_number: 0 }
}

///|
/// 系统辅助：执行真实语义
fn semantics(command : Command, system : NQuadsSystem) -> Response {
  system.line_number += 1

  match command {
    ParseQuad(subject, predicate, object, graph) => {
      let quad = make_quad(subject, predicate, object, graph)
      system.quads.push(quad)
      QuadParsed
    }
    ParseTriple(subject, predicate, object) => {
      let quad = make_quad(subject, predicate, object, DefaultGraph)
      system.quads.push(quad)
      TripleParsed
    }
    ParseLiteralQuad(subject, predicate, value, lang, graph) => {
      let literal = LiteralRef::new_language_tagged_literal_unchecked(
        value, lang,
      )
      let quad = make_quad(
        subject,
        predicate,
        TermRef::LiteralRef(literal),
        graph,
      )
      system.quads.push(quad)
      LiteralParsed
    }
    ParseTypedLiteral(subject, predicate, value, datatype, graph) => {
      // let datatype = NamedNodeRef::new_unchecked(datatype_str)
      let data_value = datatype.into_datatype(value)
      let literal = LiteralRef::new_typed_literal(data_value, datatype)
      let quad = make_quad(
        subject,
        predicate,
        TermRef::LiteralRef(literal),
        graph,
      )
      system.quads.push(quad)
      TypedLiteralParsed
    }
    ParseBlankSubject(bnode, predicate, object, graph) => {
      let quad = make_quad(
        NamedOrBlankNodeRef::BlankNodeRef(bnode),
        predicate,
        object,
        graph,
      )
      system.quads.push(quad)
      BlankSubjectParsed
    }
    ParseBlankObject(subject, predicate, bnode, graph) => {
      let quad = make_quad(
        subject,
        predicate,
        TermRef::BlankNodeRef(bnode),
        graph,
      )
      system.quads.push(quad)
      BlankObjectParsed
    }
  }
}

///|
// ============================================================
// 5. Precondition（前置条件）
// ============================================================

///|
/// 3️⃣ precondition
/// 意图：检查命令在当前模型下是否业务合法
/// N-Quads 每行独立，主要检查格式合法性
fn precondition(model : Model, command : Command) -> @qs.Logic {
  ignore(model) // N-Quads 无状态依赖，每行独立

  let ok = match command {
    // NamedNodeRef 必须非空
    ParseQuad(s, p, o, g) =>
      valid_subject(s) &&
      valid_predicate(p) &&
      valid_object(o) &&
      valid_graph(g)
    ParseTriple(s, p, o) =>
      valid_subject(s) && valid_predicate(p) && valid_object(o)

    // 字面量值和语言标签必须非空
    ParseLiteralQuad(s, p, value, lang, g) =>
      valid_subject(s) &&
      valid_predicate(p) &&
      value.length() > 0 &&
      lang.length() > 0 &&
      valid_graph(g)

    // 数据类型必须合法 NamedNodeRef
    ParseTypedLiteral(s, p, value, dt, g) =>
      valid_subject(s) &&
      valid_predicate(p) &&
      value.length() > 0 &&
      valid_predicate(dt) &&
      valid_graph(g)

    // Blank Node 标签必须非空
    ParseBlankSubject(bn, p, o, g) =>
      bn.to_string().length() > 0 &&
      valid_predicate(p) &&
      valid_object(o) &&
      valid_graph(g)
    ParseBlankObject(s, p, bn, g) =>
      valid_subject(s) &&
      valid_predicate(p) &&
      bn.to_string().length() > 0 &&
      valid_graph(g)
  }

  @qs.Logic::predicate(name="valid nquads syntax", value=ok)
}

///|
fn valid_predicate(node : NamedNodeRef) -> Bool {
  node.iri.length() > 0
}

///|
fn valid_subject(subject : NamedOrBlankNodeRef) -> Bool {
  match subject {
    NamedNodeRef(iri) => valid_predicate(iri)
    BlankNodeRef(label) => label.to_string().length() > 0
  }
}

///|
fn valid_object(object : TermRef) -> Bool {
  match object {
    NamedNodeRef(iri) => valid_predicate(iri)
    BlankNodeRef(label) => label.to_string().length() > 0
    LiteralRef(lit) => lit.to_string().length() > 0
    TripleRef(triple) =>
      valid_subject(triple.subject) &&
      valid_predicate(triple.predicate) &&
      valid_object(triple.object)
  }
}

///|
fn valid_graph(graph : GraphNameRef) -> Bool {
  match graph {
    DefaultGraph => true
    NamedNodeRef(iri) => valid_predicate(iri)
    BlankNodeRef(label) => label.to_string().length() > 0
  }
}

///|
// ============================================================
// 6. Transition（状态转换 — 预言机）
// ============================================================

///|
/// 4️⃣ transition_symbolic / transition_concrete
/// 意图：根据命令和响应，纯函数地更新模型
/// 符号和具体模型共用同一个实现
fn transition(model : Model, command : Command, response : Response) -> Model {
  match (command, response) {
    (ParseQuad(s, p, o, g), QuadParsed) =>
      model_add_quad(model, make_quad(s, p, o, g))
    (ParseTriple(s, p, o), TripleParsed) =>
      model_add_quad(model, make_quad(s, p, o, DefaultGraph))
    (ParseLiteralQuad(s, p, v, lang, g), LiteralParsed) => {
      let literal = LiteralRef::new_language_tagged_literal_unchecked(v, lang)
      model_add_quad(model, make_quad(s, p, TermRef::LiteralRef(literal), g))
    }
    (ParseTypedLiteral(s, p, v, dt, g), TypedLiteralParsed) => {
      let data_value = dt.into_datatype(v)
      let lit = LiteralRef::new_typed_literal(data_value, dt)
      model_add_quad(model, make_quad(s, p, TermRef::LiteralRef(lit), g))
    }
    (ParseBlankSubject(bn, p, o, g), BlankSubjectParsed) =>
      model_add_quad(
        model,
        make_quad(NamedOrBlankNodeRef::BlankNodeRef(bn), p, o, g),
      )
    (ParseBlankObject(s, p, bn, g), BlankObjectParsed) =>
      model_add_quad(model, make_quad(s, p, TermRef::BlankNodeRef(bn), g))

    // 不匹配：保持原状（理论上不应发生，因为 precondition 已过滤）
    _ => model
  }
}

///|
// ============================================================
// 7. Postcondition（后置条件）
// ============================================================

///|
/// 5️⃣ postcondition
/// 意图：校验真实系统响应是否与模型预测一致
fn postcondition(
  model : Model,
  command : Command,
  response : Response,
) -> @qs.Logic {
  // 计算执行后的预期模型
  let next_model = transition(model, command, response)

  // 必须有至少一个 quad（刚添加的）
  if next_model.quads.is_empty() {
    return @qs.Logic::bot()
  }

  let last_quad = next_model.quads[next_model.quads.length() - 1]

  match (command, response) {
    (ParseQuad(s, p, o, g), QuadParsed) => {
      let expected = make_quad(s, p, o, g)
      @qs.Logic::predicate(name="quad matches", value=last_quad == expected)
    }
    (ParseTriple(s, p, o), TripleParsed) => {
      let expected = make_quad(s, p, o, DefaultGraph)
      @qs.Logic::predicate(
        name="triple in default graph",
        value=last_quad == expected,
      )
    }
    (ParseLiteralQuad(s, p, v, lang, g), LiteralParsed) => {
      let expected_lit = LiteralRef::new_language_tagged_literal_unchecked(
        v, lang,
      )
      let expected = make_quad(s, p, TermRef::LiteralRef(expected_lit), g)
      @qs.Logic::predicate(
        name="literal quad matches",
        value=last_quad == expected,
      )
    }
    (ParseTypedLiteral(s, p, v, dt, g), TypedLiteralParsed) => {
      let data_value = dt.into_datatype(v)
      let expected_lit = LiteralRef::new_typed_literal(data_value, dt)
      let expected = make_quad(s, p, TermRef::LiteralRef(expected_lit), g)
      @qs.Logic::predicate(
        name="typed literal matches",
        value=last_quad == expected,
      )
    }
    (ParseBlankSubject(bn, p, o, g), BlankSubjectParsed) => {
      let expected = make_quad(NamedOrBlankNodeRef::BlankNodeRef(bn), p, o, g)
      @qs.Logic::predicate(
        name="blank subject matches",
        value=last_quad == expected,
      )
    }
    (ParseBlankObject(s, p, bn, g), BlankObjectParsed) => {
      let expected = make_quad(s, p, TermRef::BlankNodeRef(bn), g)
      @qs.Logic::predicate(
        name="blank object matches",
        value=last_quad == expected,
      )
    }

    // 不应到达：命令和响应类型不匹配
    _ => @qs.Logic::bot()
  }
}

///|
// ============================================================
// 8. Generator（命令生成器）
// ============================================================

///|
/// 6️⃣ generator
/// 意图：根据当前模型，随机生成下一个合法命令
/// N-Quads 每行独立，model 仅用于统计（无状态依赖）
fn generator(
  model : Model,
  size : Int,
  rng : @splitmix.RandomState,
) -> Command? {
  ignore(model) // N-Quads 无状态依赖
  ignore(size)

  let choice = rng.next_positive_int() % 10

  match choice {
    // 30%: 完整四元组
    0 | 1 | 2 =>
      Some(
        ParseQuad(
          gen_subject(rng),
          gen_predicate(rng),
          gen_object(rng),
          gen_graph(rng),
        ),
      )

    // 20%: 三元组（默认图）
    3 | 4 =>
      Some(ParseTriple(gen_subject(rng), gen_predicate(rng), gen_object(rng)))

    // 20%: 带语言标签的字面量
    5 | 6 =>
      Some(
        ParseLiteralQuad(
          gen_subject(rng),
          gen_predicate(rng),
          gen_literal_value(rng),
          gen_lang(rng),
          gen_graph(rng),
        ),
      )

    // 15%: 带数据类型的字面量
    7 =>
      Some(
        ParseTypedLiteral(
          gen_subject(rng),
          gen_predicate(rng),
          gen_literal_value(rng),
          gen_datatype(rng),
          gen_graph(rng),
        ),
      )

    // 10%: Blank Node subject
    8 =>
      Some(
        ParseBlankSubject(
          gen_bnode(rng),
          gen_predicate(rng),
          gen_object(rng),
          gen_graph(rng),
        ),
      )

    // 5%: Blank Node object
    _ =>
      Some(
        ParseBlankObject(
          gen_subject(rng),
          gen_predicate(rng),
          gen_bnode(rng),
          gen_graph(rng),
        ),
      )
  }
}

// ---- 生成器辅助函数 ----

///|
fn gen_predicate(rng : @splitmix.RandomState) -> NamedNodeRef {
  let hosts = [
    "http://example.org/", "http://xmlns.com/foaf/0.1/", "http://purl.org/dc/terms/",
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "http://schema.org/",
  ]
  let locals = [
    "s1", "s2", "p1", "p2", "o1", "o2", "type", "label", "name", "age",
  ]
  let host = hosts[rng.next_positive_int() % hosts.length()]
  let localx = locals[rng.next_positive_int() % locals.length()]
  { iri: host + localx }
}

///|
fn gen_bnode(rng : @splitmix.RandomState) -> BlankNodeRef {
  let ids = ["a", "b", "c", "x", "y", "z", "n1", "n2", "genid1", "genid2"]
  BlankNodeRef::new_unchecked(ids[rng.next_positive_int() % ids.length()])
}

///|
fn gen_lang(rng : @splitmix.RandomState) -> String {
  let langs = ["en", "fr", "de", "zh", "ja", "es", "ru"]
  langs[rng.next_positive_int() % langs.length()]
}

///|
fn gen_literal_value(rng : @splitmix.RandomState) -> String {
  let values = ["hello", "world", "42", "true", "2024-01-01", "test", "MoonBit"]
  values[rng.next_positive_int() % values.length()]
}

///|
fn gen_datatype(rng : @splitmix.RandomState) -> NamedNodeRef {
  let types = [
    "http://www.w3.org/2001/XMLSchema#integer", "http://www.w3.org/2001/XMLSchema#string",
    "http://www.w3.org/2001/XMLSchema#boolean", "http://www.w3.org/2001/XMLSchema#date",
  ]
  { iri: types[rng.next_positive_int() % types.length()] }
}

///|
fn gen_graph(rng : @splitmix.RandomState) -> GraphNameRef {
  if rng.next_positive_int() % 3 == 0 {
    DefaultGraph
  } else {
    NamedNodeRef(gen_predicate(rng))
  }
}

///|
fn gen_subject(rng : @splitmix.RandomState) -> NamedOrBlankNodeRef {
  if rng.next_positive_int() % 2 == 0 {
    NamedNodeRef(gen_predicate(rng))
  } else {
    BlankNodeRef(gen_bnode(rng))
  }
}

///|
fn gen_object(rng : @splitmix.RandomState) -> TermRef {
  match rng.next_positive_int() % 3 {
    0 => NamedNodeRef(gen_predicate(rng))
    1 => BlankNodeRef(gen_bnode(rng))
    _ => LiteralRef::new_simple_literal(gen_literal_value(rng)).as_term()
  }
}

///|
// ============================================================
// 9. Mock（符号响应模拟）
// ============================================================

///|
/// 7️⃣ mock
/// 意图：在生成阶段预测命令的符号响应（不执行真实系统）
fn mock(
  model : Model,
  command : Command,
  gen_sym : @qs.GenSym,
) -> (Response, @qs.GenSym) {
  ignore(model)

  let response = match command {
    ParseQuad(_, _, _, _) => QuadParsed
    ParseTriple(_, _, _) => TripleParsed
    ParseLiteralQuad(_, _, _, _, _) => LiteralParsed
    ParseTypedLiteral(_, _, _, _, _) => TypedLiteralParsed
    ParseBlankSubject(_, _, _, _) => BlankSubjectParsed
    ParseBlankObject(_, _, _, _) => BlankObjectParsed
  }
  (response, gen_sym)
}

///|
/// 7️⃣ response_vars
/// 意图：返回响应引入的新符号变量
/// N-Quads 不生成新引用，返回空
fn response_vars(response : Response) -> Array[@qs.Var] {
  []
}

///|
// ============================================================
// 10. Reify / Bind / Remap（N-Quads 无符号引用，直通）
// ============================================================

///|
/// 8️⃣ reify_command
/// 意图：将符号命令转为具体命令（替换符号变量为环境值）
/// N-Quads 命令无符号变量，直接返回
fn reify_command(
  command : Command,
  _environment : @qs.Environment[Unit],
) -> Result[Command, @qs.EnvError] {
  Ok(command)
}

///|
/// 9️⃣ bind_response
/// 意图：将具体响应绑定到环境（供后续命令引用）
/// N-Quads 无新变量，环境不变
fn bind_response(
  _symbolic : Response,
  _concrete : Response,
  environment : @qs.Environment[Unit],
) -> Result[@qs.Environment[Unit], @qs.BindError] {
  Ok(environment)
}

///|
/// 🔟 remap_command
/// 意图：收缩后重映射命令中的符号引用
/// N-Quads 无符号引用，直接返回
fn remap_command(command : Command, _scope : Map[@qs.Var, @qs.Var]) -> Command? {
  Some(command)
}

///|
// ============================================================
// 11. Shrinker（最小化失败用例）
// ============================================================

///|
/// 1️⃣1️⃣ shrinker
/// 意图：尝试生成更简单的命令变体
fn shrinker(_model : Model, command : Command) -> Array[Command] {
  match command {
    // 将命名图变为默认图（简化）
    ParseQuad(s, p, o, NamedNodeRef(_)) => [ParseQuad(s, p, o, DefaultGraph)]

    // 将完整四元组变为三元组（去掉 graph）
    ParseQuad(s, p, o, DefaultGraph) => [ParseTriple(s, p, o)]

    // 简化字面量值为空字符串
    ParseLiteralQuad(s, p, _value, lang, g) =>
      [ParseLiteralQuad(s, p, "", lang, g)]

    // 简化数据类型为通用类型
    ParseTypedLiteral(s, p, value, _dt, g) =>
      [
        ParseTypedLiteral(
          s,
          p,
          value,
          { iri: "http://www.w3.org/2001/XMLSchema#string" },
          g,
        ),
      ]

    // 将 Blank Node 替换为 IRI（如果可能）
    ParseBlankSubject(_bn, p, o, g) =>
      [ParseQuad(NamedNodeRef({ iri: "http://example.org/replaced" }), p, o, g)]
    _ => []
  }
}

///|
// ============================================================
// 12. Command Name（覆盖率标签）
// ============================================================

///|
/// 1️⃣2️⃣ command_name
/// 意图：返回命令名称（用于覆盖率统计和诊断）
fn command_name(command : Command) -> String {
  match command {
    ParseQuad(_, _, _, _) => "parse_quad"
    ParseTriple(_, _, _) => "parse_triple"
    ParseLiteralQuad(_, _, _, _, _) => "parse_literal"
    ParseTypedLiteral(_, _, _, _, _) => "parse_typed_literal"
    ParseBlankSubject(_, _, _, _) => "parse_blank_subject"
    ParseBlankObject(_, _, _, _) => "parse_blank_object"
  }
}

///|
// ============================================================
// 13. 组装 State Machine
// ============================================================

///|
/// 组装完整状态机规范
fn nquads_sm() -> @qs.StateMachine[
  Model, // MSym: 符号模型
  Model, // MCon: 具体模型
  Command, // CSym: 符号命令
  Command, // CCon: 具体命令
  Response, // RSym: 符号响应
  Response, // RCon: 具体响应
  Unit, // V:    变量类型（N-Quads 未使用）
  NQuadsSystem, // S:    被测系统
] {
  @qs.StateMachine::new(
    init_symbolic_model~,
    init_concrete_model~,
    init_system=() => init_system(),
    generator~,
    mock~,
    transition_symbolic=transition,
    transition_concrete=transition,
    precondition~,
    postcondition~,
    response_vars~,
    shrinker~,
    remap_command~,
    reify_command~,
    run_command=(command, system) => semantics(command, system),
    bind_response~,
    command_name~,
  )
}

///|
// ============================================================
// 14. 配置与测试执行
// ============================================================

///|
/// 测试配置
fn nquads_config(
  max_commands~ : Int,
  seed? : UInt64 = 42,
  cases? : Int = 100,
) -> @qs.RunConfig {
  {
    seed,
    cases,
    max_commands,
    size: max_commands,
    max_tries: 20,
    shrink: true,
    max_shrinks: 20,
    max_shrink_rounds: 10,
    required_labels: [],
    required_command_names: [],
  }
}

///|
/// 1️⃣3️⃣ check — 执行完整测试
/// 意图：生成 → 执行 → 校验 → 收缩
test "nquads random property test" {
  let result = @qs.check(
    nquads_sm(),
    config=nquads_config(max_commands=50, seed=12345, cases=200),
  )

  match result {
    Ok(report) =>
      println(
        "✓ Passed: \{report.cases_run} cases, \{report.commands_run} commands",
      )
    Err(failure) => {
      println("✗ Failed:")
      println(@qs.format_failure(failure))
      fail("N-Quads state machine test failed")
    }
  }
}

///|
/// 1️⃣4️⃣ assert_check — 断言版本
/// 意图：失败时直接 panic（适合 MoonBit 测试框架）
test "nquads assert check" {
  let report = @qs.assert_check(
    nquads_sm(),
    config=nquads_config(max_commands=30, seed=999, cases=50),
  )
  assert_true(report.commands_run > 0)
}

///|
/// 固定脚本测试（验证具体场景）
test "nquads specific scenario" {
  let commands : Array[Command] = [
    // 三元组到默认图
    ParseTriple(
      NamedNodeRef({ iri: "http://example.org/s1" }),
      { iri: "http://example.org/p1" },
      NamedNodeRef({ iri: "http://example.org/o1" }),
    ),
    // 四元组到命名图
    ParseQuad(
      NamedNodeRef({ iri: "http://example.org/s2" }),
      { iri: "http://example.org/p2" },
      LiteralRef::new_language_tagged_literal_unchecked("hello", "en").as_term(),
      NamedNodeRef({ iri: "http://example.org/graph1" }),
    ),
    // Blank Node subject
    ParseBlankSubject(
      BlankNodeRef::Named("b1"),
      { iri: "http://example.org/p3" },
      NamedNodeRef({ iri: "http://example.org/o3" }),
      DefaultGraph,
    ),
    // 带数据类型的字面量
    ParseTypedLiteral(
      NamedNodeRef({ iri: "http://example.org/s4" }),
      { iri: "http://example.org/age" },
      "25",
      { iri: "http://www.w3.org/2001/XMLSchema#integer" },
      NamedNodeRef({ iri: "http://example.org/graph2" }),
    ),
  ]

  // 手动验证模型状态
  let model = commands.fold(init=init_symbolic_model(), fn(model, cmd) {
    let resp = match cmd {
      ParseQuad(_, _, _, _) => QuadParsed
      ParseTriple(_, _, _) => TripleParsed
      ParseLiteralQuad(_, _, _, _, _) => LiteralParsed
      ParseTypedLiteral(_, _, _, _, _) => TypedLiteralParsed
      ParseBlankSubject(_, _, _, _) => BlankSubjectParsed
      ParseBlankObject(_, _, _, _) => BlankObjectParsed
    }
    transition(model, cmd, resp)
  })

  assert_eq(model.quads.length(), 4)
  assert_eq(model.quads[0].graph_name, DefaultGraph)
  assert_eq(
    model.quads[1].graph_name,
    GraphName::NamedNode(
      NamedNodeRef::new_unchecked("http://example.org/graph1").into_owned(),
    ),
  )
}

///|
/// 注入 bug 验证 shrink 能力
test "nquads shrink finds bug" {
  // 有 bug 的语义：ParseTriple 错误放入 NamedNodeRef
  let buggy_semantics = fn(
    command : Command,
    system : NQuadsSystem,
  ) -> Response {
    system.line_number += 1
    match command {
      ParseTriple(subject, predicate, object) => {
        let quad = make_quad(
          subject,
          predicate,
          object,
          NamedNodeRef({ iri: "http://buggy.graph/" }), // BUG!
        )
        system.quads.push(quad)
        TripleParsed
      }
      _ => semantics(command, system)
    }
  }

  let buggy_sm = @qs.StateMachine::new(
    init_symbolic_model~,
    init_concrete_model~,
    init_system=() => init_system(),
    generator~,
    mock~,
    transition_symbolic=transition,
    transition_concrete=transition,
    precondition~,
    postcondition~,
    response_vars~,
    shrinker~,
    remap_command~,
    reify_command~,
    run_command=(command, system) => buggy_semantics(command, system),
    bind_response~,
    command_name~,
  )

  let result = @qs.check(
    buggy_sm,
    config=nquads_config(max_commands=20, seed=999, cases=50),
  )

  match result {
    Ok(_) => fail("expected to find bug")
    Err(failure) => {
      println("Found bug (expected):")
      println(@qs.format_failure(failure))
    }
  }
}

///|
/// 注入 bug 验证 shrink 能力
test "nquads shrink finds bug 2" {
  // 有 bug 的语义：ParseTriple 错误放入 NamedNodeRef
  let buggy_semantics = fn(
    command : Command,
    system : NQuadsSystem,
  ) -> Response {
    system.line_number += 1
    match command {
      ParseTriple(subject, predicate, object) => {
        let quad = make_quad(
          subject,
          predicate,
          object,
          NamedNodeRef({ iri: "http://buggy.graph/" }), // BUG!
        )
        system.quads.push(quad)
        TripleParsed
      }
      _ => semantics(command, system)
    }
  }

  // 自定义生成器：只生成 ParseTriple，确保触发 bug
  let triple_only_generator = fn(
    model : Model,
    size : Int,
    rng : @splitmix.RandomState,
  ) -> Command? {
    ignore(model)
    ignore(size)
    ignore(rng)
    Some(
      ParseTriple(
        NamedNodeRef({ iri: "http://example.org/s" }),
        { iri: "http://example.org/p" },
        NamedNodeRef({ iri: "http://example.org/o" }),
      ),
    )
  }

  let buggy_sm = @qs.StateMachine::new(
    init_symbolic_model~,
    init_concrete_model~,
    init_system=() => init_system(), // 确保正确初始化
    generator=triple_only_generator, // 使用强制生成器
    mock~,
    transition_symbolic=transition,
    transition_concrete=transition,
    precondition~,
    postcondition~,
    response_vars~,
    shrinker~,
    remap_command~,
    reify_command~,
    run_command=(command, system) => buggy_semantics(command, system),
    bind_response~,
    command_name~,
  )

  let result = @qs.check(
    buggy_sm,
    config=nquads_config(max_commands=5, seed=999, cases=10), // 减少命令数，因为只需要一个就能触发
  )

  match result {
    Ok(_) => fail("expected to find bug")
    Err(failure) => {
      println("Found bug (expected):")
      println(@qs.format_failure(failure))
    }
  }
}
