///|
pub(all) enum RdfState {
  NQuadsState(NQuadsState)
} derive(Eq, Hash)

///|
pub impl Show for RdfState with fn output(self : RdfState, logger : &Logger) -> Unit {
  match self {
    RdfState::NQuadsState(s) => logger.write(s)
  }
}

///|
pub(all) enum RdfFeature {
  RelativeIri
  Numbers
  Prefixes
  Variables
  NonAsciiIri
  StringEscapes
  LangTags
  LongStrings // ★ 新增
  PunctuationList // ★ 逗号和分号
}

///|
fn allows_feature(mode : RdfLexerMode, feature : RdfFeature) -> Bool {
  match feature {
    RdfFeature::RelativeIri => mode != RdfLexerMode::NTriples
    RdfFeature::Numbers => mode != RdfLexerMode::NTriples
    RdfFeature::Prefixes =>
      mode == RdfLexerMode::Turtle || mode == RdfLexerMode::N3
    RdfFeature::Variables => mode == RdfLexerMode::N3
    RdfFeature::NonAsciiIri =>
      mode == RdfLexerMode::Turtle || mode == RdfLexerMode::N3
    RdfFeature::StringEscapes => true
    RdfFeature::LangTags => mode != RdfLexerMode::NTriples
    RdfFeature::LongStrings => mode != RdfLexerMode::NTriples //  NTriples 不允许
    RdfFeature::PunctuationList => mode != RdfLexerMode::NTriples // 
  }
}

///|
pub impl StateWrapper for RdfState with fn as_state_enum(self) -> RdfState {
  self
}

///|
pub(all) enum RdfLexerMode {
  NTriples
  Turtle
  N3
} derive(Eq)

///|
pub(all) struct RdfLexer {
  mode : RdfLexerMode
  lenient : Bool
  debug_logger : &DebugLogger
}

///|
pub fn RdfLexer::default() -> RdfLexer {
  RdfLexer::RdfLexer(RdfLexerMode::NTriples, true, [])
}

///|
pub fn RdfLexer::RdfLexer(
  mode : RdfLexerMode,
  lenient : Bool,
  _data_buffer : ArrayView[Byte],
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> RdfLexer {
  { mode, lenient, debug_logger }
}

///|
/// 字符分类
pub(all) enum CharClass {
  Other
  Space
  Newline
  LAngle // <
  RAngle // >
  Colon // :
  Semicolon // ;
  Period // .
  Comma // ,
  LParen // (
  RParen // )
  LBracket // [
  RBracket // ]
  LBrace // {
  RBrace // }
  Quote // "
  TripleQuote
  At // @
  QuestionMark // ?
  Plus // +
  Minus // -
  Underscore // _
  Percent // %
  Hash // #
  Slash // /
  Backslash // \\
  Star // *
  Eq // =
  Less // <
  Greater // >
  Caret // ^
  Pipe // |
  Tilde // ~
  Exclamation // !
  Dollar // $
  Ampersand // &
  Apostrophe // '
  // TripleApostrophe // '''
  // 多字符标点
  LtLt // <<
  GtGt // >>
  CaretCaret // ^^
  LBracePipe // {|
  PipeRBrace // |}
  LtLtLParen // <<(
  RParenGtGt // )>>
  LtMinus // <-
  EqGt // =>
  LtEq // <=
  LtLtRParen // <<(
  ColonColon // ::
  ColonSlash // :/ (用于 IRI scheme)
  Digit
  LowerU
  UpperU
} derive(Debug, Eq, Hash)

///|
pub impl Show for CharClass with fn output(self : CharClass, logger : &Logger) -> Unit {
  match self {
    CharClass::Other => logger.write("Other")
    CharClass::Space => logger.write("Space")
    CharClass::Newline => logger.write("Newline")
    CharClass::LAngle => logger.write("LAngle")
    CharClass::RAngle => logger.write("RAngle")
    CharClass::Colon => logger.write("Colon")
    CharClass::Semicolon => logger.write("Semicolon")
    CharClass::Period => logger.write("Period")
    CharClass::Comma => logger.write("Comma")
    CharClass::LParen => logger.write("LParen")
    CharClass::RParen => logger.write("RParen")
    CharClass::LBracket => logger.write("LBracket")
    CharClass::RBracket => logger.write("RBracket")
    CharClass::LBrace => logger.write("LBrace")
    CharClass::RBrace => logger.write("RBrace")
    CharClass::Quote => logger.write("Quote")
    CharClass::TripleQuote => logger.write("TripleQuote")
    CharClass::At => logger.write("At")
    CharClass::QuestionMark => logger.write("QuestionMark")
    CharClass::Plus => logger.write("Plus")
    CharClass::Minus => logger.write("Minus")
    CharClass::Underscore => logger.write("Underscore")
    CharClass::Percent => logger.write("Percent")
    CharClass::Hash => logger.write("Hash")
    CharClass::Slash => logger.write("Slash")
    CharClass::Backslash => logger.write("Backslash")
    CharClass::Star => logger.write("Star")
    CharClass::Eq => logger.write("Eq")
    CharClass::Less => logger.write("Less")
    CharClass::Greater => logger.write("Greater")
    CharClass::Caret => logger.write("Caret")
    CharClass::Pipe => logger.write("Pipe")
    CharClass::Tilde => logger.write("Tilde")
    CharClass::Exclamation => logger.write("Exclamation")
    CharClass::Dollar => logger.write("Dollar")
    CharClass::Ampersand => logger.write("Ampersand")
    CharClass::Apostrophe => logger.write("Apostrophe")
    // CharClass::TripleApostrophe => logger.write("TripleApostrophe")
    CharClass::LtLt => logger.write("LtLt")
    CharClass::GtGt => logger.write("GtGt")
    CharClass::LtMinus => logger.write("LtMinus")
    CharClass::EqGt => logger.write("EqGt")
    CharClass::LtLtLParen => logger.write("LtLtLParen")
    CharClass::LtLtRParen => logger.write("LtLtRParen")
    CharClass::CaretCaret => logger.write("CaretCaret")
    CharClass::LBracePipe => logger.write("LBracePipe")
    CharClass::ColonColon => logger.write("ColonColon")
    CharClass::ColonSlash => logger.write("ColonSlash")
    CharClass::PipeRBrace => logger.write("PipeRBrace")
    CharClass::RParenGtGt => logger.write("RParenGtGt")
    CharClass::LtEq => logger.write("LtEq")
    CharClass::Digit => logger.write("Digit")
    CharClass::LowerU => logger.write("LowerU")
    CharClass::UpperU => logger.write("UpperU")
  }
}

///|
/// 词法分析器状态
pub(all) enum LexStateMachine {
  Start
  // ----- IRI -----
  InIri
  InEsc // \u 或 \U 转义
  InStringEscHex4
  InStringEscHex8
  // ----- Blank Node -----
  InBlank
  InBlankLabel
  // ----- String -----
  InString // "..."
  InStringEsc // \" 转义
  InLongStringEsc // 长字符串转义
  InLongStringQuote // 三引字符串 """... """
  InLongStringQuoteContent // """...""" 内部
  InLongStringQuoteEnd // 匹配结束引号 
  InLongStringSingleQuote // 三单引号 '''...'''
  InLongStringSingleQuoteContent
  InLongStringSingleQuoteEnd
  // ----- Number -----
  InNumber
  InInteger // 整数
  InDecimal // 小数
  InDecimalStart // . 开始
  InDouble // 科学计数法
  InExponent
  // ----- Lang Tag -----
  InLangTag
  InLangTagExt // @lang-ext
  // ----- Variable (N3) -----
  InVariable
  // ----- Pname -----
  InPnamePrefix
  InPnameLocalStart
  InPnameLocal
  // ----- Keyword -----
  InKeyword
  // ----- Punctuation -----
  InPunct
  // ----- Skip -----
  // SkipWhitespace
  SkipLineComment
  SkipBlockComment(Int) // 嵌套层级
  // ----- Error -----
  Error
  // ----- Done -----
  Done
} derive(Debug, Eq, Hash)

///|
pub impl Show for LexStateMachine with fn output(
  self : LexStateMachine,
  logger : &Logger,
) -> Unit {
  match self {
    LexStateMachine::Start => logger.write("Start")
    LexStateMachine::InIri => logger.write("InIri")
    LexStateMachine::InEsc => logger.write("InEsc")
    LexStateMachine::InStringEscHex4 => logger.write("InStringEscHex4")
    LexStateMachine::InStringEscHex8 => logger.write("InStringEscHex8")
    LexStateMachine::InBlank => logger.write("InBlank")
    LexStateMachine::InBlankLabel => logger.write("InBlankLabel")
    LexStateMachine::InString => logger.write("InString")
    LexStateMachine::InStringEsc => logger.write("InStringEsc")
    LexStateMachine::InLongStringQuoteContent =>
      logger.write("InLongStringQuoteContent")
    LexStateMachine::InLongStringQuoteEnd =>
      logger.write("InLongStringQuoteEnd")
    LexStateMachine::InLongStringEsc => logger.write("InLongStringEsc")
    LexStateMachine::InLongStringQuote => logger.write("InLongStringQuote")
    LexStateMachine::InLongStringSingleQuote =>
      logger.write("InLongStringSingleQuote")
    LexStateMachine::InLongStringSingleQuoteContent =>
      logger.write("InLongStringSingleQuoteContent")
    LexStateMachine::InLongStringSingleQuoteEnd =>
      logger.write("InLongStringSingleQuoteEnd")
    LexStateMachine::InNumber => logger.write("InNumber")
    LexStateMachine::InInteger => logger.write("InInteger")
    LexStateMachine::InDecimal => logger.write("InDecimal")
    LexStateMachine::InDecimalStart => logger.write("InDecimalStart")
    LexStateMachine::InDouble => logger.write("InDouble")
    LexStateMachine::InExponent => logger.write("InExponent")
    LexStateMachine::InLangTag => logger.write("InLangTag")
    LexStateMachine::InLangTagExt => logger.write("InLangTagExt")
    LexStateMachine::InVariable => logger.write("InVariable")
    LexStateMachine::InPnamePrefix => logger.write("InPnamePrefix")
    LexStateMachine::InPnameLocalStart => logger.write("InPnameLocalStart")
    LexStateMachine::InPnameLocal => logger.write("InPnameLocal")
    LexStateMachine::InKeyword => logger.write("InKeyword")
    LexStateMachine::InPunct => logger.write("InPunct")
    // LexStateMachine::SkipWhitespace => logger.write("SkipWhitespace")
    LexStateMachine::SkipBlockComment(n) =>
      logger.write("SkipBlockComment \{n}")
    LexStateMachine::Error => logger.write("Error")
    LexStateMachine::Done => logger.write("Done")
    LexStateMachine::SkipLineComment => logger.write("SkipLineComment")
  }
}

///|
/// 词法动作
pub(all) enum LexAction {
  Continue // 继续消费
  Skip // 跳过字符
  EmitToken // 输出当前 token
  EmitTokenWithDirection(BaseDirection?) // 新增：带方向的 Emit
  // PushState(LexStateMachine) // 入栈状态
  // PopState // 出栈状态
  SetState(LexStateMachine) // 设置状态
  StartCapture // 开始捕获
  // StartNestedCapture
  // StartLongStringCapture
  // InLongStringSingleQuoteCapture
  // InLongStringSingleQuoteEndCapture
  AppendCapture // 追加到捕获
  // InLongStringQuoteCapture
  // InLongStringQuoteEndCapture
  // CheckDirectionSuffix // 新增：检查 -bidi 后缀
  EndCapture // 结束捕获
  EndLongStringCapture
  EmitError(String) // 输出错误
  Done // 完成
} derive(Debug, Eq, Hash)

///|
pub impl Show for LexAction with fn output(self : LexAction, logger : &Logger) -> Unit {
  match self {
    LexAction::Continue => logger.write("Continue")
    LexAction::Skip => logger.write("Skip")
    LexAction::EmitToken => logger.write("EmitToken")
    LexAction::EmitTokenWithDirection(dir) =>
      logger.write("EmitTokenWithDirection \{@debug.to_string(dir)}")
    // LexAction::PushState(state) => logger.write("PushState \{state}")
    // LexAction::PopState => logger.write("PopState")
    LexAction::SetState(state) => logger.write("SetState \{state}")
    LexAction::StartCapture => logger.write("StartCapture")
    // LexAction::StartNestedCapture => logger.write("StartNestedCapture")
    // LexAction::StartLongStringCapture => logger.write("StartLongStringCapture")
    // LexAction::InLongStringSingleQuoteContent =>
    //   logger.write("InLongStringSingleQuoteContent")
    // LexAction::InLongStringSingleQuoteCapture =>
    //   logger.write("InLongStringSingleQuoteCapture")
    // LexAction::InLongStringQuoteEndCapture =>
    //   logger.write("InLongStringQuoteEndCapture")
    // LexAction::InLongStringSingleQuoteEndCapture =>
    //   logger.write("InLongStringSingleQuoteEndCapture")
    //  LexAction::InLongStringQuoteCapture =>
    //   logger.write("InLongStringQuoteCapture") 
    LexAction::AppendCapture => logger.write("AppendCapture")
    LexAction::EndCapture => logger.write("EndCapture")
    LexAction::EndLongStringCapture => logger.write("EndLongStringCapture")
    LexAction::EmitError(msg) => logger.write("EmitError \{msg}")
    LexAction::Done => logger.write("Done")
  }
}

///|
/// 转换规则
pub(all) struct Transition {
  from : LexStateMachine
  char_class : CharClass
  to : LexStateMachine
  action : LexAction
  priority : Int // ★ 新增：优先级
} derive(Debug, Eq, Hash)

///|
pub impl Show for Transition with fn output(self : Transition, logger : &Logger) -> Unit {
  logger.write("Transition: ")
  self.from.output(logger)
  logger.write(" -> ")
  self.to.output(logger)
  logger.write(" char_class: ")
  self.char_class.output(logger)
  logger.write("action: ")
  self.action.output(logger)
}

///|
pub fn Transition::Transition(
  from : LexStateMachine,
  char_class : CharClass,
  to : LexStateMachine,
  action : LexAction,
  priority? : Int,
) -> Transition {
  { from, char_class, to, action, priority: priority.unwrap_or(0) }
}

///|
/// 状态转移表
pub let initialize_transitions : FixedArray[Transition] = [
  // ============================================================
  // Start 状态 - 词法分析入口
  // ============================================================

  // ----- 空白和注释 -----

  // 空格 -> 跳过空白状态
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::Skip, // ★ 不发射 token，只跳过
  ),

  // 换行 -> 发射 LineJump
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Newline,
    LexStateMachine::Start,
    LexAction::Skip,
  ),

  // # 注释开始
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Hash,
    LexStateMachine::SkipLineComment,
    LexAction::Continue,
  ),

  // ----- Token 开始 -----

  // IRI 开始: <
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::LAngle,
    LexStateMachine::InIri,
    LexAction::StartCapture,
  ),

  // Start → _ → InBlank
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Underscore,
    LexStateMachine::InBlank,
    LexAction::StartCapture,
  ),
  // Blank Node 开始: _: 或 :
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Underscore,
    LexStateMachine::InBlankLabel,
    LexAction::StartCapture,
  ),

  // 双引号字符串开始: "
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Quote,
    LexStateMachine::InString,
    LexAction::StartCapture,
  ),

  // 单引号字符串开始: '
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Apostrophe,
    LexStateMachine::InString,
    LexAction::StartCapture,
  ),

  // 三双引号长字符串: """ 
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Quote,
    LexStateMachine::InLongStringQuoteContent,
    LexAction::StartCapture,
  ),

  // 三单引号长字符串: ''' 
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Apostrophe,
    LexStateMachine::InLongStringSingleQuoteContent,
    LexAction::StartCapture,
  ),

  // Lang Tag 开始: @
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::At,
    LexStateMachine::InLangTag,
    LexAction::StartCapture,
  ),

  // 数字开始: +/-
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Plus,
    LexStateMachine::InInteger,
    LexAction::StartCapture,
  ),
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Minus,
    LexStateMachine::InInteger,
    LexAction::StartCapture,
  ),

  // 句号（单独）
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Period,
    LexStateMachine::Start,
    LexAction::EmitToken,
    priority=50,
  ),

  // 多字符标点: ^^
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Caret,
    LexStateMachine::InPunct,
    LexAction::StartCapture,
  ),

  // 其他字符作为关键字开始
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Other,
    LexStateMachine::InKeyword,
    LexAction::StartCapture,
  ),

  // ============================================================
  // IRI 状态
  // ============================================================

  // IRI 内普通字符
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Other,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),

  // IRI 内特殊字符
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Colon,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Slash,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // IRI 内转义开始
  // Transition::Transition(
  //   LexStateMachine::InIri,
  //   CharClass::Backslash,
  //   LexStateMachine::InEsc,
  //   LexAction::AppendCapture,
  // ),
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Period,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Hash,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::QuestionMark,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Percent,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),

  // InIri 转义开始
  // Transition::Transition(
  //   LexStateMachine::InIri,
  //   CharClass::Backslash,
  //   LexStateMachine::InEsc,
  //   LexAction::AppendCapture,
  // ),

  // InEsc - 检测 u 或 U
  // Transition::Transition(
  //   LexStateMachine::InEsc,
  //   CharClass::LowerU,
  //   LexStateMachine::InEscHex4,
  //   LexAction::AppendCapture,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InEsc,
  //   CharClass::UpperU,
  //   LexStateMachine::InEscHex8Start,
  //   LexAction::AppendCapture,
  // ),

  // IRI 结束: >
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::RAngle,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // IRI 错误：未编码空格
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Space,
    LexStateMachine::Error,
    LexAction::EmitError("Invalid IRI: space should be encoded as %20"),
    priority=80,
  ),

  // 非法：\ 后面不是 u/U
  Transition::Transition(
    LexStateMachine::InEsc,
    CharClass::Other,
    LexStateMachine::Error,
    LexAction::EmitError("Invalid IRI escape: expected \\u or \\U"),
  ),
  // ============================================================
  // 字符串状态
  // ============================================================

  // 字符串内普通字符
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Other,
    LexStateMachine::InString,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Colon,
    LexStateMachine::InString,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Space,
    LexStateMachine::InString,
    LexAction::AppendCapture, // 空格保留在字符串中
  ),
  // Transition::Transition(
  //   LexStateMachine::InString,
  //   CharClass::Period,
  //   LexStateMachine::InString,
  //   LexAction::AppendCapture,
  // ),

  // 字符串结束: "
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Quote,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // 字符串转义开始: \
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Backslash,
    LexStateMachine::InStringEsc,
    LexAction::AppendCapture,
  ),

  // 字符串错误：单引号不能结束
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Apostrophe,
    LexStateMachine::Error,
    LexAction::EmitError("Invalid string terminator: ' instead of \""),
  ),

  // 字符串错误：未闭合（空白结束）
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Space,
    LexStateMachine::Error,
    LexAction::EmitError("Unclosed string"),
  ),
  // 字符串错误：未编码空格
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Space,
    LexStateMachine::Error,
    LexAction::EmitError("Unclosed string"),
  ),

  // ============================================================
  // 字符串转义状态
  // ============================================================

  // 转义字符处理
  // Transition::Transition(
  //   LexStateMachine::InStringEsc,
  //   CharClass::Backslash,
  //   LexStateMachine::InStringEsc,
  //   LexAction::AppendCapture,
  //   priority=100,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InStringEsc,
  //   CharClass::Other,
  //   LexStateMachine::InStringEsc,
  //   LexAction::AppendCapture,
  // ), // u/U
  // Transition::Transition(
  //   LexStateMachine::InStringEsc,
  //   CharClass::Digit,
  //   LexStateMachine::InStringEsc,
  //   LexAction::AppendCapture,
  // ), // 十六进制
  Transition::Transition(
    LexStateMachine::InStringEsc,
    CharClass::Quote,
    LexStateMachine::Start,
    LexAction::EmitToken,
    priority=100,
  ),

  // InStringEsc - 处理转义字符
  Transition::Transition(
    LexStateMachine::InStringEsc,
    CharClass::LowerU,
    LexStateMachine::InStringEscHex4,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InStringEsc,
    CharClass::UpperU,
    LexStateMachine::InStringEscHex8,
    LexAction::AppendCapture,
  ),

  // 转义其他字符（如 \" \\ \n）
  Transition::Transition(
    LexStateMachine::InStringEsc,
    CharClass::Other,
    LexStateMachine::InString,
    LexAction::AppendCapture,
  ),

  // \u + 4位十六进制
  Transition::Transition(
    LexStateMachine::InStringEscHex4,
    CharClass::Digit,
    LexStateMachine::InStringEscHex4,
    LexAction::AppendCapture,
  ),

  // 4位十六进制完成
  Transition::Transition(
    LexStateMachine::InStringEscHex4,
    CharClass::Other,
    LexStateMachine::InString,
    LexAction::AppendCapture,
    priority=-1, // 通配符回退
  ),

  // \U + 8位十六进制
  Transition::Transition(
    LexStateMachine::InStringEscHex8,
    CharClass::Digit,
    LexStateMachine::InStringEscHex8,
    LexAction::AppendCapture,
  ),

  // 8位十六进制完成
  Transition::Transition(
    LexStateMachine::InStringEscHex8,
    CharClass::Other,
    LexStateMachine::InString,
    LexAction::AppendCapture,
  ),

  // ============================================================
  // 三双引号长字符串状态
  // ============================================================

  // 开始引号匹配: 递减匹配 3 个 "
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuote,
  //   CharClass::Quote,
  //   LexStateMachine::InLongStringQuote,
  //   LexAction::InLongStringQuoteCapture,
  //   priority=90,
  // ),

  // 完成，进入内容
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuote,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  // ),

  // 空格 -> 进入内容状态
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuote,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  //   priority=90,
  // ),
  // 内容状态
  Transition::Transition(
    LexStateMachine::InLongStringQuoteContent,
    CharClass::Other,
    LexStateMachine::InLongStringQuoteContent,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InLongStringQuoteContent,
    CharClass::Space,
    LexStateMachine::InLongStringQuoteContent,
    LexAction::AppendCapture,
  ),
  // 遇到 """ 结束
  Transition::Transition(
    LexStateMachine::InLongStringQuoteContent,
    CharClass::Quote,
    LexStateMachine::Start,
    LexAction::EndLongStringCapture,
  ),

  // InLongStringQuoteContent 中遇到 '''
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::StartNestedCapture,
  //   priority=90,
  // ),

  // // 其他字符继续
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::AppendCapture,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::AppendCapture,
  // ),

  // 遇到 """ 结束
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Quote,
  //   LexStateMachine::Start,
  //   LexAction::EndLongStringCapture,
  // ),

  // 遇到 """ 开始结束
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Quote,
  //   LexStateMachine::InLongStringQuoteEnd,
  //   LexAction::Continue,
  // ),

  // 内容状态：等待结束引号
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Quote,
  //   LexStateMachine::InLongStringQuoteEnd,
  //   LexAction::InLongStringQuoteEndCapture,
  //   priority=100,
  // ),

  // 遇到 ''' 开始嵌套
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuoteContent, // 直接进入嵌套
  //   LexAction::InLongStringSingleQuoteCapture,
  // ),

  // 其他字符
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::AppendCapture,
  // ),

  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  // ),

  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Quote,
  //   LexStateMachine::InLongStringQuoteEnd,
  //   LexAction::InLongStringQuoteEndCapture,
  //   priority=100,
  // ),
  // // 结束引号匹配
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteEnd,
  //   CharClass::Quote,
  //   LexStateMachine::InLongStringQuoteEnd,
  //   LexAction::InLongStringQuoteEndCapture,
  //   priority=100,
  // ),

  // 结束完成，发射
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteEnd,
  //   CharClass::Other,
  //   LexStateMachine::Start,
  //   LexAction::EndCapture,
  // ),

  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteEnd,
  //   CharClass::Period,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  //   priority=50,
  // ),

  // 空格继续（确保存在）
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  //   priority=50,
  // ),

  // 空格不改变状态，继续等待引号
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteEnd,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  //   // priority=50,
  // ),

  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteContent,
  //   CharClass::Period,
  //   LexStateMachine::Start,
  //   LexAction::EmitToken,
  // ),

  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteEnd,
  //   CharClass::Period,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  //   // priority=50,
  // ),
  // 结束引号后遇到内容 -> 继续等待
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteEnd,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::Continue,
  // ),
  // 引号未闭合就结束 -> 错误
  // Transition::Transition(
  //   LexStateMachine::InLongStringQuoteEnd,
  //   CharClass::Period,
  //   LexStateMachine::Error,
  //   LexAction::EmitError("Unclosed long string: missing quotes"),
  //   priority=100,
  // ),

  // ============================================================
  // 三单引号长字符串状态 (N3)
  // ============================================================

  // 开始引号匹配: 匹配 3 个 '
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuote,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuote,
  //   LexAction::InLongStringSingleQuoteCapture,
  //   priority=90,
  // ),

  // Start → ' → InLongStringSingleQuote
  // Transition::Transition(
  //   LexStateMachine::Start,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuote,
  //   LexAction::StartCapture,
  // ),

  // Start → 直接进入内容状态
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Apostrophe,
    LexStateMachine::InLongStringSingleQuoteContent,
    LexAction::StartCapture,
  ),

  // 内容状态
  Transition::Transition(
    LexStateMachine::InLongStringSingleQuoteContent,
    CharClass::Other,
    LexStateMachine::InLongStringSingleQuoteContent,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InLongStringSingleQuoteContent,
    CharClass::Space,
    LexStateMachine::InLongStringSingleQuoteContent,
    LexAction::AppendCapture,
  ),

  // 遇到 ''' 结束
  Transition::Transition(
    LexStateMachine::InLongStringSingleQuoteContent,
    CharClass::Apostrophe,
    LexStateMachine::Start,
    LexAction::EndLongStringCapture,
  ),

  // // InLongStringSingleQuoteContent 中遇到 """
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Quote,
  //   LexStateMachine::InLongStringQuoteContent,
  //   LexAction::StartNestedCapture,
  // ),

  // // 其他字符继续
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::AppendCapture,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::AppendCapture,
  // ),

  // InLongStringSingleQuote - 递减匹配 '''
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuote,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuote,
  //   LexAction::InLongStringSingleQuoteCapture,
  // ),

  // 开始引号结束后，进入内容状态
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuote,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  // ),

  // 遇到 ''' 开始结束
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   LexAction::Continue,
  // ),

  // 遇到 """ 开始嵌套
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Quote,
  //   LexStateMachine::InLongStringQuoteContent, // 直接进入嵌套
  //   LexAction::InLongStringQuoteCapture,
  // ),

  // 其他字符
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::AppendCapture,
  // ),

  // 空格 -> 进入内容状态
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuote,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  //   priority=90,
  // ),
  // 内容状态：等待结束引号
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   LexAction::InLongStringSingleQuoteEndCapture,
  //   priority=100,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   LexAction::InLongStringSingleQuoteEndCapture,
  //   priority=100,
  // ),

  // 结束引号匹配
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   CharClass::Apostrophe,
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   LexAction::InLongStringSingleQuoteEndCapture,
  //   priority=100,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   CharClass::Other,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  //   priority=50,
  // ),

  //  空格继续（确保存在）
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  //   priority=50,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   CharClass::Space,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  //   priority=50,
  // ),
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Period,
  //   LexStateMachine::Start,
  //   LexAction::EmitToken,
  //   // priority=50,
  // ),

  // 结束完成，发射
  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   CharClass::Other,
  //   LexStateMachine::Start,
  //   LexAction::EndCapture,
  // ),

  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteEnd,
  //   CharClass::Period,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  //   // priority=50,
  // ),

  // Transition::Transition(
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   CharClass::Period,
  //   LexStateMachine::InLongStringSingleQuoteContent,
  //   LexAction::Continue,
  //   priority=50,
  // ),

  // ============================================================
  // Blank Node 状态
  // ============================================================

  Transition::Transition(
    LexStateMachine::InBlank,
    CharClass::Colon,
    LexStateMachine::InBlankLabel,
    LexAction::Continue,
  ),
  // InBlank → 其他 → 报错（_ 后面必须是 :）
  // Transition::Transition(
  //   LexStateMachine::InBlank,
  //   CharClass::Other,
  //   LexStateMachine::Start,
  //   LexAction::Continue,
  // ),
  Transition::Transition(
    LexStateMachine::InBlank,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EndCapture,
  ),
  // Transition::Transition(
  //   LexStateMachine::InBlank,
  //   CharClass::Other,
  //   LexStateMachine::InBlankLabel,
  //   LexAction::AppendCapture,
  // ),
  Transition::Transition(
    LexStateMachine::InBlankLabel,
    CharClass::Other,
    LexStateMachine::InBlankLabel,
    LexAction::EndCapture,
  ),
  // InBlankLabel 贪婪消费
  Transition::Transition(
    LexStateMachine::InBlankLabel,
    CharClass::Colon,
    LexStateMachine::InBlankLabel,
    LexAction::AppendCapture, // ★ 贪婪消费冒号
  ),
  Transition::Transition(
    LexStateMachine::InBlankLabel,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EndCapture,
  ),
  Transition::Transition(
    LexStateMachine::InBlankLabel,
    CharClass::Period,
    LexStateMachine::Start,
    LexAction::EndCapture,
  ),

  // ============================================================
  // Lang Tag 状态
  // ============================================================

  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Other,
    LexStateMachine::InLangTag,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),
  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Newline,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),
  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Period,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // ============================================================
  // Keyword 状态
  // ============================================================

  Transition::Transition(
    LexStateMachine::InKeyword,
    CharClass::Other,
    LexStateMachine::InKeyword,
    LexAction::AppendCapture,
  ),
  Transition::Transition(
    LexStateMachine::InKeyword,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // ============================================================
  // 标点和 Pname 状态
  // ============================================================

  // ^^ 标点
  Transition::Transition(
    LexStateMachine::InPunct,
    CharClass::Caret,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // Pname 前缀
  Transition::Transition(
    LexStateMachine::InPnamePrefix,
    CharClass::Other,
    LexStateMachine::InPnamePrefix,
    LexAction::AppendCapture,
  ),
  // 前缀结束，遇到 :
  Transition::Transition(
    LexStateMachine::InPnamePrefix,
    CharClass::Colon,
    LexStateMachine::InPnameLocalStart,
    LexAction::AppendCapture,
  ),

  // Pname 本地部分
  Transition::Transition(
    LexStateMachine::InPnameLocalStart,
    CharClass::Other,
    LexStateMachine::InPnameLocal,
    LexAction::AppendCapture,
  ),
  // 局部名继续
  Transition::Transition(
    LexStateMachine::InPnameLocal,
    CharClass::Other,
    LexStateMachine::InPnameLocal,
    LexAction::AppendCapture,
  ),
  // 结束
  Transition::Transition(
    LexStateMachine::InPnameLocal,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // ============================================================
  // 跳过状态
  // ============================================================

  // 跳过空白
  // Transition::Transition(
  //   LexStateMachine::SkipWhitespace,
  //   CharClass::Space,
  //   LexStateMachine::SkipWhitespace,
  //   LexAction::Skip,
  // ),
  // Transition::Transition(
  //   LexStateMachine::SkipWhitespace,
  //   CharClass::Newline,
  //   LexStateMachine::SkipWhitespace,
  //   LexAction::Skip,
  // ),
  // Transition::Transition(
  //   LexStateMachine::SkipWhitespace,
  //   CharClass::Other,
  //   LexStateMachine::Start,
  //   LexAction::Continue,
  // ),
  // SkipWhitespace + _ → 直接开始，不经过 Start
  //

  // SkipWhitespace + : → 直接开始
  // Transition::Transition(
  //   LexStateMachine::SkipWhitespace,
  //   CharClass::Colon,
  //   LexStateMachine::InBlankLabel,
  //   LexAction::StartCapture,
  //   priority=50,
  // ),

  // 跳过行注释
  Transition::Transition(
    LexStateMachine::SkipLineComment,
    CharClass::Newline,
    LexStateMachine::Start,
    LexAction::Skip,
  ),
  Transition::Transition(
    LexStateMachine::SkipLineComment,
    CharClass::Other,
    LexStateMachine::SkipLineComment,
    LexAction::Skip,
  ),
]

///|
/// 256 字节的字符分类表
pub let initialize_char_class_table : FixedArray[CharClass] = {
  let table = FixedArray::make(256, CharClass::Other)

  // 空格类
  table[b' '.to_int()] = CharClass::Space
  table[b'\t'.to_int()] = CharClass::Space
  table[b'\r'.to_int()] = CharClass::Space

  // 换行
  table[b'\n'.to_int()] = CharClass::Newline

  // 标点符号
  table[b'<'.to_int()] = CharClass::LAngle
  table[b'>'.to_int()] = CharClass::RAngle
  table[b':'.to_int()] = CharClass::Colon
  table[b';'.to_int()] = CharClass::Semicolon
  table[b'.'.to_int()] = CharClass::Period
  table[b','.to_int()] = CharClass::Comma
  table[b'('.to_int()] = CharClass::LParen
  table[b')'.to_int()] = CharClass::RParen
  table[b'['.to_int()] = CharClass::LBracket
  table[b']'.to_int()] = CharClass::RBracket
  table[b'{'.to_int()] = CharClass::LBrace
  table[b'}'.to_int()] = CharClass::RBrace
  table[b'@'.to_int()] = CharClass::At
  table[b'?'.to_int()] = CharClass::QuestionMark
  table[b'+'.to_int()] = CharClass::Plus
  table[b'-'.to_int()] = CharClass::Other
  table[b'_'.to_int()] = CharClass::Underscore
  table[b'%'.to_int()] = CharClass::Percent
  table[b'#'.to_int()] = CharClass::Hash
  table[b'/'.to_int()] = CharClass::Slash
  table[b'\\'.to_int()] = CharClass::Backslash
  table[b'*'.to_int()] = CharClass::Star
  table[b'='.to_int()] = CharClass::Eq
  table[b'^'.to_int()] = CharClass::Caret
  table[b'|'.to_int()] = CharClass::Pipe
  table[b'~'.to_int()] = CharClass::Tilde
  table[b'!'.to_int()] = CharClass::Exclamation
  table[b'$'.to_int()] = CharClass::Dollar
  table[b'&'.to_int()] = CharClass::Ampersand
  table[b'\''.to_int()] = CharClass::Apostrophe // 单引号 '
  table[b'"'.to_int()] = CharClass::Quote // 双引号 "

  // 多字符标点（单字符部分）
  // 注意：多字符标点需要在状态机中特殊处理
  // 这里只分类首字符

  table
}

///|
// fn init {
let transitions_by_state : @hashmap.HashMap[LexStateMachine, Array[Transition]] = {
  let map : @hashmap.HashMap[LexStateMachine, Array[Transition]] = HashMap(
    [],
    capacity=64,
  )
  for t in initialize_transitions {
    match map.get(t.from) {
      Some(arr) => arr.push(t)
      None => map.set(t.from, [t])
    }
  }
  map
}
// }

///|
/// 快速字符分类 - O(1)
pub fn classify_byte(b : Byte) -> CharClass {
  if b.to_int() < 256 {
    initialize_char_class_table[b.to_int()]
  } else {
    CharClass::Other
  }
}

// 编译时常量表

///|
// pub let char_class_table : FixedArray[CharClass] = {
//   let t = initialize_char_class_table()
//   t
// }

///|
/// 追踪长字符串引号匹配状态
pub(all) enum EscapeQuote {
  None // 正常内容状态
  // 开始阶段
  StartDouble(Int) // """
  StartSingle(Int) // '''

  // 内容阶段
  Content

  // 嵌套阶段
  NestDouble(Int) // 嵌套 """
  NestSingle(Int) // 嵌套 '''

  // 结束阶段
  EndDouble(Int) // 结束 """
  EndSingle(Int) // 结束 '''
} derive(Debug, Eq, Hash)

///|
pub impl Show for EscapeQuote with fn output(
  self : EscapeQuote,
  logger : &Logger,
) -> Unit {
  match self {
    EscapeQuote::None => logger.write("EscapeQuote::None")
    EscapeQuote::StartDouble(n) => {
      logger.write("EscapeQuote::StartDouble(")
      logger.write(n)
      logger.write(")")
    }
    EscapeQuote::StartSingle(n) => {
      logger.write("EscapeQuote::StartSingle(")
      logger.write(n)
      logger.write(")")
    }
    EscapeQuote::Content => logger.write("EscapeQuote::Content")
    EscapeQuote::NestDouble(n) => {
      logger.write("EscapeQuote::NestDouble(")
      logger.write(n)
      logger.write(")")
    }
    EscapeQuote::NestSingle(n) => {
      logger.write("EscapeQuote::NestSingle(")
      logger.write(n)
      logger.write(")")
    }
    EscapeQuote::EndDouble(n) => {
      logger.write("EscapeQuote::EndDouble(")
      logger.write(n)
      logger.write(")")
    }
    EscapeQuote::EndSingle(n) => {
      logger.write("EscapeQuote::EndSingle(")
      logger.write(n)
      logger.write(")")
    }
  }
}

///|
pub fn EscapeQuote::default() -> EscapeQuote {
  EscapeQuote::None
}

///|
/// ===== 状态机上下文 =====
pub(all) struct LexContext {
  data_buffer : ArrayView[Byte]
  mut position : Int
  mut state : LexStateMachine
  mut capture_start : Int
  mut capture_current : Int
  state_stack : Array[LexStateMachine]
  is_ending : Bool
  mut captured : String?
  mut escape_quote : EscapeQuote
  mut has_error : Bool
  mut error_message : String?
  mut prev_char : Byte?
}

///|
pub impl Show for LexContext with fn output(self : LexContext, logger : &Logger) -> Unit {
  logger.write("LexContext::")
  logger.write("{ ")
  logger.write("position: ")
  logger.write(self.position)
  logger.write(", ")
  logger.write("state: ")
  logger.write(self.state)
  logger.write(", ")
  logger.write("capture_start: ")
  logger.write(self.capture_start)
  logger.write(", ")
  logger.write("capture_current: ")
  logger.write(self.capture_current)
  logger.write(", ")
  // logger.write("state_stack: ")
  // logger.write(self.state_stack)
  // logger.write(", ")
  logger.write("captured: ")
  logger.write(@debug.to_string(self.captured))
  logger.write(", ")
  // logger.write("lookahead_buffer: ")
  // logger.write(self.lookahead_buffer)
  // logger.write(", ")
  // logger.write("lookahead_pos: ")
  // logger.write(self.lookahead_pos)
  // logger.write(", ")
  // logger.write("emit_state: ")
  // logger.write(self.emit_state)
  logger.write(", ")
  logger.write("escape_quote: ")
  logger.write(self.escape_quote)
  logger.write("}")
}

///|
pub fn LexContext::default() -> LexContext {
  {
    data_buffer: [],
    position: 0,
    state: LexStateMachine::Start,
    capture_start: 0,
    capture_current: 0,
    state_stack: [],
    is_ending: false, // 是否结束,
    captured: None,
    escape_quote: EscapeQuote::default(),
    has_error: false,
    error_message: None,
    prev_char: None,
  }
}

///|
pub fn LexContext::new(
  data_buffer : ArrayView[Byte],
  is_ending? : Bool = false,
) -> LexContext {
  {
    data_buffer,
    position: 0,
    state: LexStateMachine::Start,
    capture_start: 0,
    capture_current: 0,
    state_stack: [],
    is_ending,
    captured: None,
    escape_quote: EscapeQuote::default(),
    has_error: false,
    error_message: None,
    prev_char: None,
  }
}

///|
pub fn LexContext::current_char(self : LexContext) -> Byte? {
  if self.position < self.data_buffer.length() {
    Some(self.data_buffer[self.position])
  } else {
    None
  }
}

///|
pub fn LexContext::peek_char(self : LexContext) -> Byte? {
  if self.position + 1 < self.data_buffer.length() {
    Some(self.data_buffer[self.position + 1])
  } else {
    None
  }
}

///|
pub fn LexContext::advance(self : LexContext) -> Unit {
  self.prev_char = self.data_buffer.get(self.position)
  self.position += 1
}

///|
// pub fn LexContext::get_capture(self : LexContext) -> String {
//   let s = StringBuilder::new()
//   for i in self.capture_start..<self.capture_current {
//     s.write_char(self.data_buffer[i].to_int().unsafe_to_char())
//     // s = s + self.data_buffer[i].to_int().unsafe_to_char().to_string().to_string()
//   }
//   s.to_string()
// }
pub fn LexContext::get_capture(self : LexContext) -> String {
  let result = StringBuilder::new()
  let mut i = self.capture_start

  while i < self.capture_current {
    let remaining = self.data_buffer[i:]

    // ★ 组合子检测
    if match_seq(remaining, [b'\\', b'u', b'0', b'0', b'2', b'0']) {
      result.write_char(' ') // 空格
      i += 6
    } else if match_seq(remaining, [b'\\', b'n']) {
      result.write_char('\n')
      i += 2
    } else if match_seq(remaining, [b'\\', b't']) {
      result.write_char('\t')
      i += 2
    } else if match_seq(remaining, [b'\\', b'r']) {
      result.write_char('\r')
      i += 2
      // } else if match_seq(remaining, [b'\\', b'\\']) {
      //   result.write_char('\\')
      //   i += 2
    } else if match_seq(remaining, [b'\\', b'"']) {
      result.write_char('"')
      i += 2
    } else {
      // 普通字符
      result.write_char(self.data_buffer[i].to_int().unsafe_to_char())
      i += 1
    }
  }

  result.to_string()
}

// 组合子：检测模式

///|
fn match_seq(bs : ArrayView[Byte], pattern : Array[Byte]) -> Bool {
  if bs.length() < pattern.length() {
    return false
  }
  for i in 0..<pattern.length() {
    if bs[i] != pattern[i] {
      return false
    }
  }
  true
}

///|
/// 是否为 ASCII 字母 (a-z, A-Z)
fn Byte::is_ascii_alpha(b : Byte) -> Bool {
  (b >= b'a' && b <= b'z') || (b >= b'A' && b <= b'Z')
}

///|
/// 是否为 ASCII 数字 (0-9)
fn Byte::is_ascii_digit(b : Byte) -> Bool {
  b >= b'0' && b <= b'9'
}

///|
/// 是否为 ASCII 字母或数字
fn Byte::is_ascii_alnum(b : Byte) -> Bool {
  b.is_ascii_alpha() || b.is_ascii_digit()
}

///|
/// IRI 有效字符
fn Byte::is_iri_char(b : Byte) -> Bool {
  if b.is_ascii_alnum() {
    return true
  }
  match b {
    b':'
    | b'/'
    | b'.'
    | b'-'
    | b'_'
    | b'~'
    | b'@'
    | b'$'
    | b'&'
    | b'='
    | b'+'
    | b'!'
    | b'*'
    | b'\''
    | b'('
    | b')'
    | b','
    | b'#'
    | b'%'
    | b'?' => true
    _ => false
  }
}

///|
/// Blank Node 标签有效字符
fn Byte::is_blank_label_char(b : Byte) -> Bool {
  b.is_ascii_alnum() || b == b'-' || b == b'_'
}

///|
/// 空白字符
// fn Byte::is_whitespace(b : Byte) -> Bool {
//   b == b' ' || b == b'\t' || b == b'\r' || b == b'\n'
// }

///|
/// ===== 查找转换 =====
pub fn RdfLexer::find_transition(
  self : RdfLexer,
  ctx : LexContext,
  char_class : CharClass,
) -> Transition? {
  self.debug_logger.info(
    "find_transition: ctx.state=\{ctx.state}, char_class=\{char_class}",
  )
  match transitions_by_state.get(ctx.state) {
    Some(transitions) => {
      let mut best : Transition? = None
      let mut best_priority = -1

      for t in transitions {
        if t.char_class == char_class {
          // 选择优先级最高的
          if t.priority > best_priority {
            best = Some(t)
            best_priority = t.priority
          }
        }
      }

      match best {
        Some(t) => {
          self.debug_logger.info("found: to=\{t.to}, action=\{t.action}")
          Some(t)
        }
        None => {
          // ★ 通配符回退：精确匹配失败，尝试匹配 Other
          let mut wildcard : Transition? = None
          let mut best_priority = -1
          for t in transitions {
            if t.char_class == CharClass::Other && t.priority > best_priority {
              wildcard = Some(t)
              best_priority = t.priority
            }
          }
          match wildcard {
            Some(t) => {
              self.debug_logger.info("fallback to Other: to=\{t.to}")
              Some(t)
            }
            None => {
              self.debug_logger.info("NOT FOUND TRANSITION")
              None
            }
          }
        }
      }
    }
    None => {
      self.debug_logger.info("NO TRANSITIONS FOR STATE: \{ctx.state}")
      None
    }
  }
}

///|
/// ===== 状态机执行器 =====
pub fn RdfLexer::execute_action(
  self : RdfLexer,
  action : LexAction,
  ctx : LexContext,
  current : Byte,
  _data_buffer : ArrayView[Byte],
) -> (LexAction, LexContext) {
  self.debug_logger.info(
    "@@ execute_action: action=\{action}, state=\{ctx.state}, position=\{ctx.position}",
  )
  match action {
    // ============================================================
    // EmitToken - 发射 token
    // ============================================================
    LexAction::EmitToken => {
      ctx.capture_current = ctx.position + 1
      let s = ctx.get_capture()
      self.debug_logger.info("@@@EmitToken: s=\{s}")
      // ★ 状态检查
      match ctx.state {
        // 普通字符串检查
        LexStateMachine::InString | LexStateMachine::InStringEsc => {
          // let has_start_quote = s.length() > 0 && s[0] == '"'
          // let has_end_quote = s.length() > 0 && s[s.length() - 1] == '"'

          // if !(has_start_quote && has_end_quote) || ctx.has_error {
          if ctx.has_error {
            self.debug_logger.info("ERROR: Unclosed string: '\{s}'")
            ctx.advance()
            ctx.has_error = true
            return (LexAction::EmitError("Unclosed string"), ctx)
          }

          ctx.captured = Some(s)
          // ctx.emit_state = Some(ctx.state)
          ctx.advance()
          (LexAction::EmitToken, ctx)
        }

        // 长字符串检查
        // LexStateMachine::InLongStringQuoteEnd
        LexStateMachine::InLongStringQuoteContent
        // | LexStateMachine::InLongStringSingleQuoteEnd
        | LexStateMachine::InLongStringSingleQuoteContent => {
          // let s = s.trim_end(chars=".")
          // let s = s.replace(old="\"", new="").replace(old="'", new="").trim()
          // self.debug_logger.info("LONG STRING: '\{s}'")
          ctx.captured = Some(s)
          // ctx.emit_state = Some(ctx.state)
          ctx.advance()
          (LexAction::EmitToken, ctx)
        }
        LexStateMachine::InIri => {
          let s = if s.length() >= 2 && s[0] == '<' && s[s.length() - 1] == '>' {
            s[1:s.length() - 1]
          } else {
            s
          }
          ctx.captured = Some(s.to_owned())
          // ctx.emit_state = Some(ctx.state)
          ctx.advance()
          (LexAction::EmitToken, ctx)
        }
        _ => {
          ctx.captured = Some(s)
          // ctx.emit_state = Some(ctx.state)
          ctx.advance()
          (LexAction::EmitToken, ctx)
        } // 其他状态正常发射
      }
    }

    // ============================================================
    // StartCapture - 开始捕获
    // ============================================================

    LexAction::StartCapture => {
      let pos = ctx.position
      ctx.capture_start = pos
      ctx.capture_current = pos + 1

      // 前瞻检测
      let next1 = ctx.data_buffer.get(ctx.position)
      let next2 = ctx.data_buffer.get(ctx.position + 1)

      // 检测三引号
      let is_triple_quote = next1 == Some(b'"') && next2 == Some(b'"')
      let is_triple_apostrophe = next1 == Some(b'\'') && next2 == Some(b'\'')
      // 双引号（非三引号）
      let is_normal_double_quote = current == b'"' && !is_triple_quote
      let is_normal_single_quote = current == b'\'' && !is_triple_apostrophe // ★ 新增
      match current {
        // ========== 字符串 ==========
        _ if is_normal_double_quote => {
          // 普通双引号字符串 "..."
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InString
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info("StartCapture: Normal string, state=InString")
        }
        _ if is_normal_single_quote => {
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InString
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info(
            "StartCapture: Normal Single string, state=InString",
          )
        }
        _ if is_triple_quote => {
          // 三引号长字符串：NTriples 不允许
          if !allows_feature(self.mode, RdfFeature::LongStrings) {
            ctx.has_error = true
            ctx.error_message = Some(
              "Long strings (triple quotes) not allowed in N-Triples",
            )
            return (LexAction::EmitError("Long strings not allowed"), ctx)
          }

          // """ 长字符串：预消费所有三个引号
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InLongStringQuoteContent
          ctx.has_error = false
          ctx.advance() // 消费第1个 "
          ctx.advance() // 消费第2个 "
          ctx.advance() // 消费第3个 "
          ctx.escape_quote = EscapeQuote::Content // 标记为内容状态
          ctx.capture_start = ctx.position
          ctx.capture_current = ctx.position

          self.debug_logger.info(
            "StartCapture: Triple quote, state=InLongStringQuoteContent",
          )
        }
        _ if is_triple_apostrophe => {
          // 三单引号长字符串：NTriples 不允许
          if !allows_feature(self.mode, RdfFeature::LongStrings) {
            ctx.has_error = true
            ctx.error_message = Some(
              "Long strings (triple quotes) not allowed in N-Triples",
            )
            return (LexAction::EmitError("Long strings not allowed"), ctx)
          }
          // ''' 长字符串
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InLongStringSingleQuoteContent
          ctx.has_error = false
          ctx.advance()
          ctx.advance()
          ctx.advance()
          ctx.escape_quote = EscapeQuote::Content
          ctx.capture_start = ctx.position
          ctx.capture_current = ctx.position

          self.debug_logger.info(
            "StartCapture: Triple apostrophe, state=InLongStringSingleQuoteContent",
          )
        }

        // ========== IRI ==========
        b'<' => {
          // 前瞻检测绝对 IRI
          let p = ctx.position + 1
          let is_http = ctx.data_buffer.get(p) == Some(b'h') &&
            ctx.data_buffer.get(p + 1) == Some(b't') &&
            ctx.data_buffer.get(p + 2) == Some(b't') &&
            ctx.data_buffer.get(p + 3) == Some(b'p')

          let is_urn = ctx.data_buffer.get(p) == Some(b'u') &&
            ctx.data_buffer.get(p + 1) == Some(b'r') &&
            ctx.data_buffer.get(p + 2) == Some(b'n')

          if !is_http && !is_urn {
            ctx.has_error = true
            return (LexAction::EmitError("Relative IRI not allowed"), ctx)
          }

          ctx.state = LexStateMachine::InIri
          ctx.advance()
        }
        // ========== Blank Node ==========

        b'_' => {
          // ★ 前置检查
          let next1 = ctx.data_buffer.get(ctx.position + 1)
          if next1 != Some(b':') {
            ctx.has_error = true
            ctx.error_message = Some(
              "Invalid blank node: _ must be followed by :",
            )
            return (
              LexAction::EmitError(
                "Invalid blank node: _ must be followed by :",
              ),
              ctx,
            )
          }

          ctx.state = LexStateMachine::InBlankLabel
          ctx.escape_quote = EscapeQuote::None
          ctx.has_error = false
          ctx.capture_start = ctx.position
          ctx.capture_current = ctx.position + 1
          ctx.advance() // 消费 :
          debug("StartCapture: Blank node, state=InBlank")
        }
        b':' =>
          match ctx.prev_char {
            // 字母数字 : → PrefixedName
            Some(c) if c.is_ascii_alnum() =>
              ctx.state = LexStateMachine::InPnamePrefix
            // 其他情况（_、空白、开头）→ Blank Node
            _ => ctx.state = LexStateMachine::InBlankLabel
          }
        // ========== Lang Tag ==========
        b'@' => {
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InLangTag
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info(
            "StartCapture: Lang tag start, state=InLangTag",
          )
        }

        // ========== 数字 ==========
        b'+' | b'-' | _ if current.to_char().is_ascii_digit() => {

          // N-Triples 不允许数字
          if !allows_feature(self.mode, RdfFeature::Numbers) {
            ctx.has_error = true
            ctx.error_message = Some("Numbers not allowed in N-Triples")
            self.debug_logger.info("Error: Numbers not allowed in N-Triples")
            return (LexAction::EmitError("Numbers not allowed"), ctx)
          }

          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InInteger
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info("StartCapture: Number start, state=InInteger")
        }

        // ========== 标点符号 ==========
        // b':'
        // |
        b';' | b',' | b'.' | b'(' | b')' | b'[' | b']' | b'{' | b'}' | b'*' => {
          // ★ N-Triples 不允许逗号和分号
          if !allows_feature(self.mode, RdfFeature::PunctuationList) &&
            (current == b',' || current == b';') {
            ctx.has_error = true
            ctx.error_message = Some("Punctuation not allowed")
            return (LexAction::EmitError("Punctuation not allowed"), ctx)
          }

          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::Start
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info("StartCapture: Punctuation")
          return (LexAction::EmitToken, ctx)
        }

        // ========== 类型修饰符 ==========
        b'^' => {
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InPunct
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info("StartCapture: Punct start, state=InPunct")
        }

        // ========== 注释 ==========
        b'#' => {
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::SkipLineComment
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info(
            "StartCapture: Comment start, state=SkipLineComment",
          )
        }
        b'\\' => {
          // 需要在下一字符判断是否是 u/U
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InEsc
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info("StartCapture: IRI escape start, state=InEsc")
        }
        // ========== 默认：关键字/标识符 ==========
        _ => {
          ctx.escape_quote = EscapeQuote::None
          ctx.state = LexStateMachine::InKeyword
          ctx.has_error = false
          ctx.advance()
          self.debug_logger.info("StartCapture: Keyword start, state=InKeyword")
        }
      }

      (LexAction::Continue, ctx)
    }

    // ============================================================
    // AppendCapture - 追加到捕获
    // ============================================================

    LexAction::AppendCapture => {
      ctx.advance()
      ctx.capture_current = ctx.position

      match ctx.state {

        // ========== 普通字符串 ==========
        LexStateMachine::InString =>
          while ctx.position < ctx.data_buffer.length() {
            let b = ctx.data_buffer.get(ctx.position)
            match b {
              // 转义字符，跳过下一个
              Some(b'\\') => ctx.advance()
              // if ctx.position < ctx.data_buffer.length() {
              //   ctx.advance() // 跳过转义目标
              // }
              // 结束引号，停止
              Some(b'"') => break
              // 其他字符，消费
              Some(_c) => ctx.advance()
              _ => break
            }
          }

        // ========== IRI ==========
        LexStateMachine::InIri =>
          while ctx.position < ctx.data_buffer.length() {
            let b = ctx.data_buffer.get(ctx.position)
            match b {
              // 有效 IRI 字符
              Some(c) if c.is_iri_char() => {
                ctx.advance()
                ctx.capture_current = ctx.position
              }

              // ★ 转义字符：报错
              Some(b'\\') => {
                ctx.has_error = true
                ctx.error_message = Some(
                  "Invalid IRI: escape sequences not allowed",
                )
                break
              }

              // IRI 结束
              Some(b'>') => break

              // 其他字符，停止
              _ => break
            }
          }
        _ => ()
      }

      (LexAction::Continue, ctx)
    }
    // ============================================================
    // Continue - 继续（不发射）
    // ============================================================
    LexAction::Continue => {
      ctx.advance()
      if ctx.capture_start == 0 {
        ctx.capture_start = ctx.position
        ctx.capture_current = ctx.position
      }
      ctx.capture_current = ctx.position
      (LexAction::Continue, ctx)
    }

    // ============================================================
    // Skip - 跳过（不追加）
    // ============================================================
    LexAction::Skip => {
      ctx.advance()
      ctx.capture_start = ctx.position
      ctx.capture_current = ctx.position
      (LexAction::Skip, ctx)
    }
    LexAction::EndLongStringCapture => {
      let quote_char = match ctx.state {
        LexStateMachine::InLongStringQuoteContent => b'"'
        LexStateMachine::InLongStringSingleQuoteContent => b'\'' // ★ 三单引号
        _ => b'\''
      }

      let start_pos = ctx.position

      // 检查是否是三引号
      if ctx.data_buffer.get(start_pos) == Some(quote_char) &&
        ctx.data_buffer.get(start_pos + 1) == Some(quote_char) &&
        ctx.data_buffer.get(start_pos + 2) == Some(quote_char) {
        // 找到三引号
        ctx.position = start_pos + 3
        let s = ctx.get_capture()
        ctx.captured = Some(s)
        return (LexAction::EmitToken, ctx)
      }

      // 没找到
      if ctx.is_ending || ctx.position >= ctx.data_buffer.length() {
        ctx.has_error = true
        return (LexAction::EmitError("Unclosed long string"), ctx)
      }

      ctx.advance()
      (LexAction::Continue, ctx)
    }

    // ============================================================
    // EmitError - 发射错误
    // ============================================================
    LexAction::EmitError(msg) => {
      self.debug_logger.info("EmitError: \{msg}")
      ctx.has_error = true
      ctx.error_message = Some(msg)
      ctx.advance()
      (LexAction::EmitError(msg), ctx)
    }
    LexAction::EndCapture => {
      // ★ 贪婪消费剩余有效字符
      match ctx.state {
        LexStateMachine::InBlankLabel =>
          while ctx.position < ctx.data_buffer.length() {
            let b = ctx.data_buffer.get(ctx.position)
            match b {
              // ★ 不消费冒号！
              Some(b':') => break // 遇到冒号停止
              Some(c) if c.is_blank_label_char() => {
                ctx.advance()
                ctx.capture_current = ctx.position
              }
              _ => break
            }
          }
        LexStateMachine::InIri =>
          while ctx.position < ctx.data_buffer.length() {
            let b = ctx.data_buffer.get(ctx.position)
            match b {
              Some(c) if c.is_iri_char() => {
                ctx.advance()
                ctx.capture_current = ctx.position
              }
              Some(b'\\') => {
                ctx.has_error = true
                ctx.error_message = Some(
                  "Invalid IRI: escape sequences not allowed",
                )
                break
              }
              // Some(b'\\') => {
              //   let next1 = ctx.data_buffer.get(ctx.position)
              //   match next1 {
              //     Some(b'u') | Some(b'U') => ctx.advance()
              //     _ => break
              //   }
              // }
              _ => break
            }
          }
        _ => ()
      }

      let s = ctx.get_capture()

      // ★ Blank Node 格式检查
      if ctx.state == LexStateMachine::InBlankLabel ||
        ctx.state == LexStateMachine::InBlank {
        // 必须以 _ 或 : 开头
        if s.is_empty() ||
          (s[0] != b'_'.to_uint16() && s[0] != b':'.to_uint16()) {
          ctx.has_error = true
          return (
            LexAction::EmitError(
              "Invalid blank node label: must start with _ or :",
            ),
            ctx,
          )
        }

        // 检查冒号：只能有一个，且不能在开头后连续
        if s.contains("::") {
          ctx.has_error = true
          return (LexAction::EmitError("Invalid blank node: double colon"), ctx)
        }

        let colon_count = s.iter().filter(c => c == b':'.to_char()).count()
        if colon_count > 1 {
          ctx.has_error = true
          return (
            LexAction::EmitError("Invalid blank node: too many colons"),
            ctx,
          )
        }
      }

      ctx.captured = Some(s)
      self.debug_logger.info("EndCapture: content='\{s}'")
      (LexAction::EmitToken, ctx)
    }
    // ============================================================
    // 其他 action
    // ============================================================
    _ => {
      ctx.advance()
      (action, ctx)
    }
  }
}

///|
/// 创建 Token（包含完整的 LangTag）
pub fn make_token(
  ctx : LexContext,
  content : String,
) -> Result[N3Token, String] {
  let (state, has_error) = (ctx.state, ctx.has_error)
  debug("make_token: state=\{state}, content=\{content}")
  match state {
    LexStateMachine::InIri =>
      if has_error {
        return Err("Invalid IRI")
      } else {
        Ok(N3Token::Iri(content))
      }
    // let iri = content.trim(chars="<>")     
    // if iri.contains(" ") {
    //   Err("Invalid IRI: unencoded space at \{content}")
    // } else if !iri.contains("/") {
    //   return Err(
    //     "Invalid IRI: <\{content}> (N-Triples requires absolute IRI)",
    //   )
    // } else {
    //   Ok(N3Token::Iri(iri.to_owned()))
    // }
    LexStateMachine::InBlankLabel => Ok(N3Token::BlankNodeLabel(content))
    // LexStateMachine::InBlank => Ok(N3Token::BlankNodeLabel(content))
    LexStateMachine::InString | LexStateMachine::InStringEsc =>
      // let has_start_quote = content.length() > 0 && content[0] == '"'
      // let has_end_quote = content.length() > 0 &&
      //   content[content.length() - 1] == '"'

      // if !(has_start_quote && has_end_quote) {
      //   return Err("Unclosed string")
      // }

      // let s = content.trim_start(chars="\"").trim_end(chars="\"")
      // debug("make_token -> String: \{content}")
      Ok(N3Token::String(content))
    LexStateMachine::InLongStringQuoteContent
    | LexStateMachine::InLongStringSingleQuoteContent =>
      // let quote_count = {
      //   let mut count = 0
      //   for c in content {
      //     if c == '"' || c == '\'' {
      //       count += 1
      //     }
      //   }
      //   count
      // }

      // debug("  quote_count=\{quote_count}, escape_quote=\{ctx.escape_quote}")

      // ★ 更严格的检查
      // if ctx.escape_count > 1 {
      //   return Err(
      //     "Unclosed long string: missing \{ctx.escape_count} quotes (got \{quote_count})",
      //   )
      // }

      // if quote_count < 6 {
      //   return Err(
      //     "Unclosed long string: expected 6 quotes, got \{quote_count}",
      //   )
      // }
      // let s = content.trim_end() // ★ 去掉尾部空格
      Ok(N3Token::LongString(content))
    LexStateMachine::InLangTag => {
      // 直接使用 content，-bidi 决定方向
      let direction = if content.has_suffix("-bidi") {
        Some(BaseDirection::Rtl)
      } else {
        None
      }
      Ok(N3Token::LangTag(language=content, direction~))
    }
    LexStateMachine::InVariable => Ok(N3Token::Variable(content))
    LexStateMachine::InKeyword =>
      // let has_start_quote = content.length() > 0 && content[0] == '"'
      // let has_end_quote = content.length() > 0 &&
      //   content[content.length() - 1] == '"'

      // if !(has_start_quote && has_end_quote) {
      //   return Err("Unclosed string")
      // }

      // if content == "." {
      //   Ok(N3Token::Punctuation(".")) // 单独 "." 是标点
      // } else {
      Ok(N3Token::PlainKeyword(content))
    // }
    LexStateMachine::InInteger => Ok(N3Token::Integer(content))
    LexStateMachine::InDecimal => Ok(N3Token::Decimal(content))
    LexStateMachine::InDouble => Ok(N3Token::Double(content))
    LexStateMachine::InPunct =>
      if content == "^^" {
        Ok(N3Token::Punctuation("^^"))
      } else {
        Ok(N3Token::Punctuation(content))
      }
    LexStateMachine::InPnamePrefix | LexStateMachine::InPnameLocal =>
      match content.find(":") {
        Some(idx) => {
          let prefix = content.sub(start=0, end=idx).to_owned()
          let localx = content
            .sub(start=idx + 1, end=content.length())
            .to_owned()
          Ok(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri=false),
          )
        }
        None => Ok(N3Token::PlainKeyword(content))
      }
    LexStateMachine::InLongStringQuoteEnd
    | LexStateMachine::InLongStringSingleQuoteEnd =>
      Ok(N3Token::LongString(content))
    LexStateMachine::Start => {
      let s = match ctx.prev_char {
        Some(b',') => ","
        Some(b';') => ";"
        Some(b'.') => "."
        Some(b'(') => "("
        Some(b')') => ")"
        Some(b'[') => "["
        Some(b']') => "]"
        Some(b'{') => "{"
        Some(b'}') => "}"
        _ => ctx.get_capture()
      }

      match s {
        "," | ";" | "." | "(" | ")" | "[" | "]" | "{" | "}" | ":" =>
          Ok(N3Token::Punctuation(s))

        // 关键字
        "a" => Ok(N3Token::PlainKeyword("a"))
        // _ if content.starts_with("<") && content.ends_with(">") =>
        //   Ok(N3Token::Iri(content))
        // _ if content.starts_with("_:") || content.starts_with(":") =>
        //   Ok(N3Token::BlankNodeLabel(content))
        _ => Ok(N3Token::PlainKeyword(content))
      }
    }
    _ => {
      debug("make_token -> PlainKeyword: '\{content}'")
      Ok(N3Token::PlainKeyword(content))
    }
  }
}

///|
/// 单步执行状态机
/// 返回 (action, pos)，如果无法继续则返回 None
fn RdfLexer::step(
  self : RdfLexer,
  ctx : LexContext,
  data_buffer : ArrayView[Byte],
) -> (LexAction, LexContext)? {
  let current = match ctx.data_buffer.get(ctx.position) {
    Some(b) => b
    None => return None
  }

  let char_class = classify_byte(current)

  let t = self.find_transition(ctx, char_class)
  self.debug_logger.info(
    "step: pos=\{ctx.position}, char='\{current.to_int().unsafe_to_char().to_string()}', char_class=\{char_class}, state=\{ctx.state} ctx=\{ctx}",
  )

  match t {
    Some(transition) => {
      let (action, new_ctx) = self.execute_action(
        transition.action,
        ctx,
        current,
        data_buffer,
      )

      // 根据 action 类型决定返回值
      let final_ctx = match action {
        LexAction::EmitToken | LexAction::EmitError(_) => new_ctx
        _ =>
          // 状态变化时更新
          if new_ctx.state != ctx.state {
            { ..new_ctx, state: transition.to }
          } else {
            new_ctx
          }
      }
      Some((action, final_ctx))
    }
    None => None
  }
}

///|
/// 跳过空白字符，返回跳过的数量
pub fn[RL] Lexer::skip_whitespace(self : Lexer[RL]) -> Int {
  let mut count = 0
  while self.position.buffer_offset + count < self.data.length() {
    let b = self.data[self.position.buffer_offset + count]
    match b {
      b' ' | b'\t' | b'\r' => count += 1
      _ => break
    }
  }
  count
}

///|
/// 跳过空白和注释
pub fn[RL] Lexer::skip_whitespaces_and_comments(self : Lexer[RL]) -> Bool {
  let mut skipped = 0

  for ;; {
    if self.position.buffer_offset + skipped >= self.data.length() {
      // 没有更多数据
      break
    }

    let b = self.data[self.position.buffer_offset + skipped]

    // 空白字符
    if b == b' ' || b == b'\t' || b == b'\r' || b == b'\n' {
      skipped += 1
      // 注释（# 开头）
    } else if b == b'#' {
      skipped += 1
      // 跳过注释直到行尾
      for ;; {
        if self.position.buffer_offset + skipped >= self.data.length() {
          break
        }
        if self.data[self.position.buffer_offset + skipped] == b'\n' {
          break
        }
        skipped += 1
      }
      // 非空白字符，结束
    } else {
      break
    }
  }

  // 更新位置
  if skipped > 0 {
    self.position.buffer_offset += skipped
    self.position.global_offset += skipped

    // 统计换行
    let view = self.data[self.position.buffer_offset - skipped:self.position.buffer_offset]
    for b in view {
      if b == b'\n' {
        self.position.global_line += 1
      }
    }
  }

  skipped > 0
}

///|
/// ===== TokenRecognizer 实现 =====
pub impl TokenRecognizer for RdfLexer with fn recognize_next_token(
  self : RdfLexer,
  data_buffer : ArrayView[Byte],
  is_ending : Bool,
  _options : LexerOptions?,
  location_pos : SourcePos,
) -> (Int, Result[LocatedToken, TokenRecognizerError])? {
  // let iri = IriR::default()

  // let base_iri_opt = match options {
  //   Some(options) =>
  //     match options.base_iri {
  //       Some(irir) => {
  //         let irir = irir.into_string()
  //         if self.lenient {
  //           // 宽松模式：使用 unchecked 解析，即使格式不完美也尝试使用
  //           Some(iri.parse_unchecked(irir))
  //         } else {
  //           // 严格模式：必须通过标准解析验证
  //           match iri.parse(irir) {
  //             Ok(parsed_iri) => Some(parsed_iri)
  //             Err(_) => None
  //           }
  //         }
  //       }
  //       None => None
  //     }
  //   None => None
  // }
  // let options = LexerOptions::default(base_iri_opt)
  let mut ctx = LexContext::new(data_buffer, is_ending~)

  for ;; {
    self.debug_logger.info("step: pos=\{ctx.position}, state=\{ctx.state}")

    match self.step(ctx, data_buffer) {
      Some((action, new_ctx)) => {
        ctx = new_ctx // ★ 更新 ctx

        match action {
          LexAction::EmitToken => {
            // let state = ctx.emit_state.unwrap_or(ctx.state) // ★ 使用 emit_state
            let token = make_token(ctx, ctx.captured.unwrap_or(""))
            match token {
              Ok(token) => {
                self.debug_logger.info("  -> Emit: \{token}")
                let range = Range::Range(
                  location_pos.offset,
                  location_pos.offset + ctx.position,
                )
                return Some((ctx.position, Ok(LocatedToken(token, range))))
              }
              Err(err) => {
                let range = Range::Range(
                  location_pos.offset,
                  location_pos.offset + ctx.position + 1,
                )
                return Some(
                  (
                    ctx.position,
                    Err(
                      TokenRecognizerError::InvalidToken(
                        err, data_buffer, range,
                      ),
                    ),
                  ),
                )
              }
            }
          }
          LexAction::EmitError(err) => {
            let range = Range::Range(
              location_pos.offset,
              location_pos.offset + ctx.position + 1,
            )
            return Some(
              (
                ctx.position,
                Err(TokenRecognizerError::InvalidToken(err, data_buffer, range)),
              ),
            )
          }
          _ => continue
        }
      }
      None => {
        // ★ 无转换，检查是否到达 buffer 末尾

        // 未闭合的 token 检测
        let unclosed_states = [
          LexStateMachine::InString,
          LexStateMachine::InLongStringQuote,
          LexStateMachine::InLongStringSingleQuote,
          LexStateMachine::InIri,
          LexStateMachine::InBlankLabel,
        ]

        let is_unclosed = unclosed_states.iter().any(s => ctx.state == s)

        if ctx.position >= data_buffer.length() || is_ending {
          // 到达 buffer 末尾或文件结束
          if is_unclosed {
            // 未闭合的 token，报错
            let pos = ctx.position
            let range = Range::Range(
              location_pos.offset,
              location_pos.offset + pos,
            )
            debug(
              "Unclosed token: state=\{ctx.state}, content=\{ctx.get_capture()}",
            )
            return Some(
              (
                pos,
                Err(
                  TokenRecognizerError::InvalidToken(
                    "Unclosed token:", data_buffer, range,
                  ),
                ),
              ),
            )
          }
          // 正常结束
          return None
        }

        // 还有剩余数据但无转换，尝试恢复
        if ctx.capture_current > ctx.capture_start {
          let token = make_token(ctx, ctx.get_capture())
          match token {
            Ok(token) => {
              let pos = ctx.position
              let range = Range::Range(
                location_pos.offset,
                location_pos.offset + pos,
              )
              return Some((ctx.capture_current, Ok(LocatedToken(token, range))))
            }
            Err(err) => {
              let range = Range::Range(
                location_pos.offset,
                location_pos.offset + ctx.position + 1,
              )
              return Some(
                (
                  ctx.position + 1,
                  Err(
                    TokenRecognizerError::InvalidToken(err, data_buffer, range),
                  ),
                ),
              )
            }
          }
        }

        let range = Range::Range(
          location_pos.offset,
          location_pos.offset + ctx.position + 1,
        )
        return Some(
          (
            ctx.position + 1,
            Err(
              TokenRecognizerError::InvalidToken(
                "Something Err", data_buffer, range,
              ),
            ),
          ),
        )
      }
    }
  }
}
