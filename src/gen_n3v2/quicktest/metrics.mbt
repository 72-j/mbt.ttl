// ========================================
// Metrics — 枚举件 + 全臂冒烟门（**手维护层**；对齐 trig quicktest 的 metrics.mbt 角色）
// ========================================
// 定位（src/ttl/todo.md §C 役 14 的第一步可跑件）：先给「全状态 / 全命令」枚举与全臂冒烟，
// 覆盖率门（路径驱动）/结构钉子/引擎侧普查按 trig P4.3 形态在其上继续搭。
// 纪律：枚举是**手工维护**的数据面——IR（n3_fsm.toml）变了这里必须同笔改，数字门会替你把关。

///|
/// 全部状态（源 [[states]]，53 个）
fn all_states() -> Array[ModelState] {
  [
    ExpectSubject,
    ExpectPredicate,
    ExpectObject,
    ExpectDotOrGraph,
    ExpectDirectiveKind,
    ExpectPrefixName,
    ExpectPrefixIri,
    ExpectBaseIri,
    ExpectVersionLiteral,
    ExpectDirectiveEnd,
    ExpectKeywordsList,
    ExpectVerbOrEnd,
    ExpectVerbOrDot,
    ExpectVerbRequired,
    ExpectTildeEnd,
    AnnotExpectVerb,
    AnnotExpectVerbTail,
    AnnotExpectObject,
    AnnotExpectEnd,
    BnpExpectPredicate,
    BnpExpectObject,
    BnpAfterObject,
    ListExpectElemOrEnd,
    ListAfterElem,
    FormulaExpectSubject,
    FormulaExpectPredicate,
    FormulaExpectObject,
    FormulaAfterObject,
    PathExpectVerb,
    PathAfterStep,
    FormulaPathExpectVerb,
    FormulaPathAfterStep,
    ExpectIsProp,
    ExpectIsOf,
    BnpExpectIsProp,
    BnpExpectIsOf,
    FormulaExpectIsProp,
    FormulaExpectIsOf,
    QuantExpectVar,
    QuantExpectVarOrDot,
    FormulaDirectiveKind,
    FormulaQuantExpectVar,
    FormulaQuantExpectVarOrDot,
    SubjTrailExpectVerb,
    SubjTrailAfterStep,
    SubjTrailVerbDone,
    SubjTrailExpectVerbFormula,
    SubjTrailAfterStepFormula,
    SubjTrailVerbDoneFormula,
    ListPathExpectVerb,
    ListPathAfterStep,
    ObjTrailExpectVerb,
    ObjTrailAfterStep,
  ]
}

///|
/// 全部命令（源 weights 表 39 个事件；`@qcs.Ref` 统一取 `Concrete(id = 1)`）
fn all_commands() -> Array[Command] {
  let reference : @qcs.Ref[RefId] = Concrete({ id: 1, })
  [
    Iri(reference),
    BlankNode(reference),
    Literal(reference),
    PrefName(reference),
    TripleTerm(reference),
    BracketTripleTerm(reference),
    KeywordA(reference),
    Variable(reference),
    KeywordX(reference),
    Equals(reference),
    Is,
    Of,
    Has,
    At,
    PrefixKw,
    BaseKw,
    VersionKw,
    Tilde,
    AnnotStart,
    AnnotEnd,
    ForAllKw,
    ForSomeKw,
    KeywordsKw,
    Comma,
    Semicolon,
    Dot,
    Lbrace(reference),
    Rbrace,
    Lbracket(reference),
    Rbracket,
    Lparen(reference),
    Rparen,
    Anon(reference),
    Bang(reference),
    Caret(reference),
    Implies(reference),
    ImpliedBy(reference),
    Unknown(reference),
    EOF,
  ]
}

///|
/// 空槽模型（只定状态）：普查 / 冒烟的统一起点
fn blank_model(state : ModelState) -> Model {
  { ..model_empty(), state, }
}

///|
/// **全臂冒烟门**：53 状态 × 39 命令，每对都跑一次 `model_execute`。
/// 判据两条：
///   ① 对数守恒（53 × 39 = 2067）——防枚举漏项；
///   ② 合法对 = **376**（= `valid.mbt` 真行数 = 在库臂数）——结构钉子：臂表漂了这里就红。
/// 本门只证"每条臂都能执行一次"（覆盖率用途），**不**替代随机门/锚点门的语义对拍。
test "n3v2 全臂冒烟：53×39 全对 + 合法对 376（臂表结构钉）" {
  let mut pairs = 0
  let mut legal = 0
  for state in all_states() {
    for command in all_commands() {
      let model = blank_model(state)
      let _ = model_execute(model, command)
      pairs = pairs + 1
      if valid(model, command) {
        legal = legal + 1
      }
    }
  }
  assert_eq(pairs, 53 * 39)
  assert_eq(legal, 376)
}

///|
/// **权重表钉子**：39 名逐条等值 + 表外名回落 1。
/// 权重决定随机门的分布（属判据面）⇒ 改表即红，必须与
/// `src/quick_machine/quick_machine_n3.toml` 的 `[business.weights]` 同笔说明。
test "n3v2 权重表逐名等值（39 名全量 + 默认档）" {
  let expected : Array[(String, Int)] = [
    ("At", 1),
    ("Is", 0),
    ("Of", 0),
    ("Dot", 3),
    ("EOF", 0),
    ("Has", 0),
    ("Iri", 3),
    ("Anon", 0),
    ("Bang", 0),
    ("Caret", 0),
    ("Comma", 1),
    ("Tilde", 1),
    ("BaseKw", 1),
    ("Equals", 1),
    ("Lbrace", 0),
    ("Lparen", 0),
    ("Rbrace", 0),
    ("Rparen", 0),
    ("Implies", 0),
    ("Literal", 3),
    ("Unknown", 0),
    ("AnnotEnd", 0),
    ("ForAllKw", 0),
    ("KeywordA", 0),
    ("KeywordX", 0),
    ("Lbracket", 0),
    ("PrefName", 2),
    ("PrefixKw", 1),
    ("Rbracket", 0),
    ("Variable", 0),
    ("BlankNode", 2),
    ("ForSomeKw", 0),
    ("ImpliedBy", 0),
    ("Semicolon", 1),
    ("VersionKw", 0),
    ("AnnotStart", 0),
    ("KeywordsKw", 0),
    ("TripleTerm", 0),
    ("BracketTripleTerm", 0),
  ]
  // 权重表全量 = 命令枚举全量（两条清单漂了就红）
  assert_eq(expected.length(), 39)
  assert_eq(all_commands().length(), expected.length())
  for case in expected {
    let (name, weight) = case
    assert_eq(command_weight(name), weight)
  }
  // 顺带钉住"枚举名 ⊆ 权重表名"（名字拼错/漏项即红）
  let declared = expected.map(fn(pair) { pair.0 })
  for command in all_commands() {
    assert_true(declared.contains(command_name(command)))
  }
  assert_eq(command_weight("NotDeclared"), 1)
}
