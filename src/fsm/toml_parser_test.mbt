///|
async test "toml_parser" {
  // basic key-value pairs example
  let toml = @fs.read_file("./src/fsm/test.toml").text()

  debug_inspect(
    @toml.parse(toml),
    content=(
      #|TomlTable(
      #|  {
      #|    "version": TomlInteger(1),
      #|    "events": TomlTable(
      #|      {
      #|        "start": TomlArray([]),
      #|        "stop": TomlArray([]),
      #|        "pause": TomlArray([]),
      #|        "resume": TomlArray([]),
      #|      },
      #|    ),
      #|    "states": TomlTable(
      #|      {
      #|        "idle": TomlTable({ "is_initial": TomlBoolean(true) }),
      #|        "running": TomlTable({}),
      #|        "paused": TomlTable({}),
      #|      },
      #|    ),
      #|    "transitions": TomlArray(
      #|      [
      #|        TomlTable(
      #|          {
      #|            "from": TomlString("idle"),
      #|            "to": TomlString("running"),
      #|            "on": TomlString("start"),
      #|          },
      #|        ),
      #|        TomlTable(
      #|          {
      #|            "from": TomlString("running"),
      #|            "to": TomlString("idle"),
      #|            "on": TomlString("stop"),
      #|          },
      #|        ),
      #|        TomlTable(
      #|          {
      #|            "from": TomlString("running"),
      #|            "to": TomlString("paused"),
      #|            "on": TomlString("pause"),
      #|          },
      #|        ),
      #|        TomlTable(
      #|          {
      #|            "from": TomlString("paused"),
      #|            "to": TomlString("running"),
      #|            "on": TomlString("resume"),
      #|          },
      #|        ),
      #|      ],
      #|    ),
      #|  },
      #|)
    ),
  )
}

///|
test "parse_raw supports [[events]] and [[states]] array format" {
  let toml_content =
    #|[[events]]
    #|name = "Iri"
    #|[[events]]
    #|name = "BlankNode"
    #|
    #|[[states]]
    #|name = "ExpectSubject"
    #|is_initial = true
    #|[[states]]
    #|name = "Complete"
    #|
    #|[[transitions]]
    #|from = "ExpectSubject"
    #|to = "Complete"
    #|on = "Iri"
    #|action = "emit"
  let (_meta, states_meta, events, rules, _effects, _ctx) = parse_raw(
    toml_content,
  ).unwrap()
  assert_eq(events.length(), 2)
  let names = events.map(fn(e) { e.name })
  assert_true(names.contains("Iri"))
  assert_true(names.contains("BlankNode"))
  assert_eq(states_meta.length(), 2)
  assert_true(states_meta[0].is_initial)
  assert_false(states_meta[1].is_initial)
  assert_eq(rules.length(), 1)
  assert_eq(rules[0].from_state, "ExpectSubject")
  assert_eq(rules[0].on_event, "Iri")
  assert_eq(rules[0].to_state, "Complete")
}

///|
async test "parse_raw on real test_nquads.toml (array-of-tables format)" {
  let toml_content = @fs.read_file("./src/fsm/test_nquads.toml").text()
  let (meta, states_meta, events, rules, _effects, _ctx) = parse_raw(
    toml_content,
  ).unwrap()
  println(
    "events=\{events.length()} states=\{states_meta.length()} transitions=\{rules.length()}",
  )
  assert_true(events.length() > 0)
  assert_true(states_meta.length() > 0)
  assert_true(rules.length() > 0)
  // [meta]：显式 prefix 与 trait_name
  assert_eq(meta.name, "nquads_parser")
  assert_eq(meta.prefix, "NQuads")
  assert_eq(meta.trait_or_default(), "NQuadsActions")
  let validation = validate(states_meta, events.map(fn(e) { e.name }), rules, [])
  assert_true(validation.is_ok())
}

///|
test "parse_raw reads [meta] and derives prefix from name" {
  // prefix 未声明：借用 name 剔除特殊字符派生 PascalCase 前缀
  let toml_content =
    #|[meta]
    #|name = "turtle-parser v2"
    #|
    #|[[events]]
    #|name = "Iri"
    #|
    #|[[states]]
    #|name = "Start"
    #|is_initial = true
  let (meta, _states, _events, _rules, _effects, _ctx) = parse_raw(toml_content).unwrap()
  assert_eq(meta.name, "turtle-parser v2")
  assert_eq(meta.prefix, "TurtleParserV2")
  assert_eq(meta.trait_or_default(), "TurtleParserV2Actions")
  assert_eq(meta.effect_or_default(), "Continue")

  // prefix 显式声明：同样剔除特殊字符（"nquads-parser" -> "NquadsParser"）
  let declared = parse_raw("[meta]\nname = \"x\"\nprefix = \"nquads-parser\"").unwrap()
  let (declared_meta, _, _, _, _, _) = declared
  assert_eq(declared_meta.prefix, "NquadsParser")

  // 无 [meta]：空前缀（生成代码不加命名空间），trait 兜底 "Actions"
  let bare = parse_raw("[[events]]\nname = \"Iri\"").unwrap()
  let (bare_meta, _, _, _, _, _) = bare
  assert_eq(bare_meta.prefix, "")
  assert_eq(bare_meta.trait_or_default(), "Actions")
}
