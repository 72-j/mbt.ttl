///|
pub(all) enum RdfState {
  NQuadsState(NQuadsState)
} derive(Eq, Hash)

///|
pub impl Show for RdfState with fn to_string(self) -> String {
  match self {
    RdfState::NQuadsState(s) => s.to_string()
  }
}

///|
pub impl StateWrapper for RdfState with fn as_state_enum(self) -> RdfState {
  self
}

///|
pub(all) enum RdfLexerMode {
  NTriples
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
  }
}

///|
/// 词法分析器状态
pub(all) enum LexStateMachine {
  Start
  // ----- IRI -----
  InIri
  // InIriEsc // \u 或 \U 转义
  // InIriEscU
  // InIriEscHex8
  // ----- Blank Node -----
  InBlank
  InBlankLabel
  // ----- String -----
  InString // "..."
  InStringEsc // \" 转义
  InLongStringStart // 检测 """
  InLongString // """...""" 内部
  InLongStringEsc // 长字符串转义
  InLongStringQuote(Int) // 已匹配 n 个引号 (n=1,2)
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
  SkipWhitespace
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
    // LexStateMachine::InIriEsc => logger.write("InIriEsc")
    LexStateMachine::InBlank => logger.write("InBlank")
    LexStateMachine::InBlankLabel => logger.write("InBlankLabel")
    LexStateMachine::InString => logger.write("InString")
    LexStateMachine::InStringEsc => logger.write("InStringEsc")
    LexStateMachine::InLongStringStart => logger.write("InLongStringStart")
    LexStateMachine::InLongString => logger.write("InLongString")
    LexStateMachine::InLongStringEsc => logger.write("InLongStringEsc")
    LexStateMachine::InLongStringQuote(n) =>
      logger.write("InLongStringQuote \{n}")
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
    LexStateMachine::SkipWhitespace => logger.write("SkipWhitespace")
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
  PushState(LexStateMachine) // 入栈状态
  PopState // 出栈状态
  SetState(LexStateMachine) // 设置状态
  StartCapture // 开始捕获
  AppendCapture // 追加到捕获
  // CheckDirectionSuffix // 新增：检查 -bidi 后缀
  EndCapture // 结束捕获
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
    LexAction::PushState(state) => logger.write("PushState \{state}")
    LexAction::PopState => logger.write("PopState")
    LexAction::SetState(state) => logger.write("SetState \{state}")
    LexAction::StartCapture => logger.write("StartCapture")
    LexAction::AppendCapture => logger.write("AppendCapture")
    LexAction::EndCapture => logger.write("EndCapture")
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
) -> Transition {
  { from, char_class, to, action }
}

///|
/// 状态转移表
pub let initialize_transitions : Array[Transition] = [
  // ========== Start 状态 ==========

  // 冒号（用于 scheme）
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Colon,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // InIriEsc 进入对应转义状态
  // Transition::Transition(
  //   LexStateMachine::InIriEsc,
  //   CharClass::Other, // u 或 U
  //   LexStateMachine::InIriEscU, // 需要根据字符判断
  //   LexAction::AppendCapture,
  // ),

  // 转换表只需要一个规则
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Backslash,
    LexStateMachine::InIri,
    LexAction::AppendCapture, // 通用处理
  ),
  // 斜杠
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Slash,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // 点号（允许在 IRI 中）
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Period,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // 问号（query string）
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::QuestionMark,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // # (fragment)
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Hash,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // 百分号（percent encoding）
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Percent,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // 空白跳过
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Space,
    LexStateMachine::SkipWhitespace,
    LexAction::Continue,
  ),
  // 换行跳过
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Newline,
    LexStateMachine::SkipWhitespace,
    LexAction::EmitToken,
  ),
  // 注释跳过
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Hash,
    LexStateMachine::SkipLineComment,
    LexAction::Continue,
  ),
  // IRI 开始
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::LAngle,
    LexStateMachine::InIri,
    LexAction::StartCapture,
  ),
  // Blank 节点开始
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Underscore,
    LexStateMachine::InBlank,
    LexAction::StartCapture,
  ),
  // 字符串开始
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Quote,
    LexStateMachine::InString,
    LexAction::StartCapture,
  ),
  // 单引号字符串 (N3)
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Apostrophe,
    LexStateMachine::InString,
    LexAction::StartCapture,
  ),
  // Lang Tag 开始
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::At,
    LexStateMachine::InLangTag,
    LexAction::StartCapture,
  ),
  // 变量开始 (N3)
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::QuestionMark,
    LexStateMachine::InVariable,
    LexAction::StartCapture,
  ),
  // 数字开始
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

  // 标点符号
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Period,
    LexStateMachine::InPunct,
    LexAction::EmitToken,
  ),
  // 其他字符作为 keyword
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Other,
    LexStateMachine::InKeyword,
    LexAction::StartCapture,
  ),
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Other, // 数字 0-9
    LexStateMachine::InInteger,
    LexAction::StartCapture,
  ),
  // ========== InIri 状态 ==========
  // IRI 内普通字符
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::Other,
    LexStateMachine::InIri,
    LexAction::AppendCapture,
  ),
  // IRI 结束
  Transition::Transition(
    LexStateMachine::InIri,
    CharClass::RAngle,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),
  // IRI 内转义
  // Transition::Transition(
  //   LexStateMachine::InIri,
  //   CharClass::Backslash,
  //   LexStateMachine::InIriEsc,
  //   LexAction::AppendCapture,
  // ),

  // ========== InString 状态 ==========
  // 字符串内普通字符
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Other,
    LexStateMachine::InString,
    LexAction::AppendCapture,
  ),
  // 字符串结束
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Quote,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),
  // 字符串转义
  Transition::Transition(
    LexStateMachine::InString,
    CharClass::Backslash,
    LexStateMachine::InStringEsc,
    LexAction::AppendCapture,
  ),

  // ========== SkipWhitespace 状态 ==========
  Transition::Transition(
    LexStateMachine::SkipWhitespace,
    CharClass::Space,
    LexStateMachine::SkipWhitespace,
    LexAction::Skip,
  ),
  Transition::Transition(
    LexStateMachine::SkipWhitespace,
    CharClass::Newline,
    LexStateMachine::SkipWhitespace,
    LexAction::Skip,
  ),
  Transition::Transition(
    LexStateMachine::SkipWhitespace,
    CharClass::Other,
    LexStateMachine::Start,
    LexAction::Continue,
  ),

  // ========== SkipLineComment 状态 ==========
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

  // ========== InBlank 状态 ==========
  Transition::Transition(
    LexStateMachine::InBlank,
    CharClass::Colon,
    LexStateMachine::InBlankLabel,
    LexAction::Continue,
  ),

  // ========== InBlankLabel 状态 ==========
  Transition::Transition(
    LexStateMachine::InBlankLabel,
    CharClass::Other,
    LexStateMachine::InBlankLabel,
    LexAction::AppendCapture,
  ),

  // ========== InLangTag 状态 ==========
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::At,
    LexStateMachine::InLangTag,
    LexAction::StartCapture,
  ),
  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Other,
    LexStateMachine::InLangTag,
    LexAction::AppendCapture,
  ),
  // // 结束 - 检查方向后缀
  // Transition::Transition(
  //   LexStateMachine::InLangTag,
  //   CharClass::Space,
  //   LexStateMachine::Start,
  //   LexAction::CheckDirectionSuffix,
  // ),
  // Lang Tag 结束（非字母数字）
  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // 其他结束条件
  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Newline,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),
  Transition::Transition(
    LexStateMachine::InLangTag,
    CharClass::Period, // 句号结束
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),
  // ========== InKeyword 状态 ==========
  Transition::Transition(
    LexStateMachine::InKeyword,
    CharClass::Other,
    LexStateMachine::InKeyword,
    LexAction::AppendCapture,
  ),
  // Keyword 结束
  Transition::Transition(
    LexStateMachine::InKeyword,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),
  // ========== Pname 前缀 ==========
  // a-z 开始的前缀
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Other, // 假设 a-z 在这里
    LexStateMachine::InPnamePrefix,
    LexAction::StartCapture,
  ),
  // 前缀内字符
  Transition::Transition(
    LexStateMachine::InPnamePrefix,
    CharClass::Other,
    LexStateMachine::InPnamePrefix,
    LexAction::AppendCapture,
  ),
  // 遇到冒号
  Transition::Transition(
    LexStateMachine::InPnamePrefix,
    CharClass::Colon,
    LexStateMachine::InPnameLocalStart,
    LexAction::AppendCapture,
  ),

  // ========== Pname 本地部分 ==========
  // 本地部分开始（冒号后的字符）
  Transition::Transition(
    LexStateMachine::InPnameLocalStart,
    CharClass::Other,
    LexStateMachine::InPnameLocal,
    LexAction::AppendCapture,
  ),
  // 本地部分继续
  Transition::Transition(
    LexStateMachine::InPnameLocal,
    CharClass::Other,
    LexStateMachine::InPnameLocal,
    LexAction::AppendCapture,
  ),
  // 本地部分结束（空白）
  Transition::Transition(
    LexStateMachine::InPnameLocal,
    CharClass::Space,
    LexStateMachine::Start,
    LexAction::EmitToken,
  ),

  // ========== 特殊 Pname 前缀（关键字）==========
  // a, b, g, l, s, t 等关键字作为前缀名
  Transition::Transition(
    LexStateMachine::Start,
    CharClass::Other, // 'a' 等
    LexStateMachine::InPnamePrefix,
    LexAction::StartCapture,
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
  table[b'-'.to_int()] = CharClass::Minus
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
  // 前瞻缓冲区
  mut lookahead_buffer : Array[Byte] // 存储前瞻的字节
  mut lookahead_pos : Int // 前瞻中的当前位置
  mut emit_state : LexStateMachine? // ★ 新增}
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
    lookahead_buffer: [],
    lookahead_pos: 0,
    emit_state: None,
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
  self.position += 1
}

///|
pub fn LexContext::get_capture(self : LexContext) -> String {
  let mut s = ""
  for i in self.capture_start..<self.capture_current {
    s = s + self.data_buffer[i].to_int().unsafe_to_char().to_string()
  }
  s
}

///|
/// 填充前瞻缓冲区
fn fill_lookahead(ctx : LexContext, count : Int) -> Bool {
  let start = ctx.position
  let end = Int::min(start + count, ctx.data_buffer.length())

  ctx.lookahead_buffer = []
  for i in start..<end {
    match ctx.data_buffer.get(i) {
      Some(b) => ctx.lookahead_buffer.push(b)
      None => break
    }
  }
  ctx.lookahead_pos = 0

  ctx.lookahead_buffer.length() >= count
}

///|
/// 获取前瞻字节
fn peek_lookahead(ctx : LexContext, offset : Int) -> Byte? {
  ctx.lookahead_buffer.get(ctx.lookahead_pos + offset)
}

///|
/// 消费前瞻字节
fn consume_lookahead(ctx : LexContext) -> Byte? {
  match ctx.lookahead_buffer.get(ctx.lookahead_pos) {
    Some(b) => {
      ctx.lookahead_pos += 1
      ctx.position += 1
      Some(b)
    }
    None => None
  }
}

///|
/// 返回转义序列的长度（4 或 8），或 None
fn peek_hex_length(ctx : LexContext) -> Int? {
  let pos = ctx.position

  // 检查是否有足够字符 (\u + 4 hex 或 \U + 8 hex)
  let prefix = match ctx.data_buffer.get(pos) {
    Some(b) => b
    None => return None
  }

  if prefix == b'u' {
    // \u 需要 4 个十六进制
    let mut count = 0
    for i in 1..<5 {
      match ctx.data_buffer.get(pos + i) {
        Some(b) if b.is_ascii_hexdigit() => count += 1
        _ => break
      }
    }
    if count == 4 {
      Some(4)
    } else {
      None
    }
  } else if prefix == b'U' {
    // \U 需要 8 个十六进制
    let mut count = 0
    for i in 1..<9 {
      match ctx.data_buffer.get(pos + i) {
        Some(b) if b.is_ascii_hexdigit() => count += 1
        _ => break
      }
    }
    if count == 8 {
      Some(8)
    } else {
      None
    }
  } else {
    None
  }
}

///|
/// 检查转义序列是否有效，返回需要消费的字节数
fn check_escape(ctx : LexContext) -> Int? {
  let remaining = ctx.data_buffer.length() - ctx.position

  match ctx.data_buffer.get(ctx.position) {
    Some(b'u') if remaining >= 5 => {
      // 检查 4 个十六进制
      for i in 1..<5 {
        if !ctx.data_buffer[ctx.position + i].is_ascii_hexdigit() {
          return None
        }
      }
      Some(5) // \\u + 4 hex
    }
    Some(b'U') if remaining >= 9 => {
      // 检查 8 个十六进制
      for i in 1..<9 {
        if !ctx.data_buffer[ctx.position + i].is_ascii_hexdigit() {
          return None
        }
      }
      Some(9) // \\U + 8 hex
    }
    _ => None
  }
}

///|
/// 消费转义序列
fn consume_escape(ctx : LexContext) -> LexAction {
  match check_escape(ctx) {
    Some(count) => {
      ctx.position += count
      ctx.capture_current = ctx.position
      LexAction::Continue
    }
    None => LexAction::EmitError("Invalid escape sequence")
  }
}

///|
/// 检查字节是否为十六进制
fn Byte::is_ascii_hexdigit(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') ||
  (b >= b'a' && b <= b'f') ||
  (b >= b'A' && b <= b'F')
}

///|
/// ===== 查找转换 =====
pub fn RdfLexer::find_transition(
  _self : RdfLexer,
  state : LexStateMachine,
  char_class : CharClass,
) -> Transition? {
  match transitions_by_state.get(state) {
    Some(transitions) => {
      for t in transitions {
        if t.char_class == char_class {
          return Some(t)
        }
      }
      None
    }
    None => None
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
  match action {
    LexAction::Continue => {
      ctx.advance()
      let pos = ctx.position
      self.debug_logger.info("Continue: pos=\{pos}")
      (LexAction::Continue, ctx)
    }
    LexAction::Skip => {
      ctx.advance()
      let pos = ctx.position
      self.debug_logger.info("Skip: pos=\{pos}")
      (LexAction::Continue, ctx)
    }
    LexAction::StartCapture => {
      let pos = ctx.position
      self.debug_logger.info(
        "StartCapture: pos=\{pos}, capture_start will be=\{pos}",
      )

      ctx.capture_start = pos
      ctx.capture_current = pos
      ctx.advance()

      self.debug_logger.info(
        "After: pos=\{pos}, capture_start=\{ctx.capture_start}",
      )
      (LexAction::Continue, ctx)
    }
    LexAction::AppendCapture => {
      ctx.advance()
      ctx.capture_current = ctx.position

      // 处理转义
      if ctx.state == LexStateMachine::InIri && current == b'\\' {
        match consume_escape(ctx) {
          LexAction::Continue => ()
          e => return (e, ctx)
        }
      }

      (LexAction::Continue, ctx)
    }
    LexAction::EndCapture => {
      let pos = ctx.position

      ctx.capture_current = pos
      self.debug_logger.info(
        "EndCapture: capture_current=\{ctx.capture_current}",
      )
      (LexAction::Continue, ctx)
    }
    LexAction::EmitToken => {
      ctx.capture_current = ctx.position + 1
      let s = ctx.get_capture()
      ctx.captured = Some(s)
      ctx.emit_state = Some(ctx.state) // ★ 保存 emit 前的状态
      ctx.advance()
      self.debug_logger.info("EmitToken: pos=\{ctx.position}, Captured='\{s}'")
      self.debug_logger.info("EmitToken: state before advance: \{ctx.state}") // 添加调试
      self.debug_logger.info("EmitToken: content: '\{s}'")

      (LexAction::EmitToken, ctx)
    }
    LexAction::EmitTokenWithDirection(dir) => {
      ctx.advance()
      let pos = ctx.position
      self.debug_logger.info(
        "EmitTokenWithDirection: pos=\{pos}, dir=\{@debug.to_string(dir)}",
      )
      (LexAction::EmitTokenWithDirection(dir), ctx)
    }
    LexAction::PushState(s) => {
      ctx.state_stack.push(ctx.state)
      ctx.state = s
      ctx.advance()
      let pos = ctx.position

      self.debug_logger.info("PushState: new state=\{s}, pos=\{pos}")
      (LexAction::Continue, ctx)
    }
    LexAction::PopState => {
      let old_state = ctx.state
      match ctx.state_stack.pop() {
        Some(s) => ctx.state = s
        None => ()
      }

      self.debug_logger.info("PopState: \{old_state} -> \{ctx.state}")
      (LexAction::Continue, ctx)
    }
    LexAction::SetState(s) => {
      ctx.state = s
      ctx.advance()
      let pos = ctx.position

      self.debug_logger.info("SetState: new state=\{s}, pos=\{pos}")
      (LexAction::Continue, ctx)
    }
    LexAction::EmitError(msg) => {
      self.debug_logger.info("EmitError: \{msg}")

      (LexAction::EmitError(msg), ctx)
    }
    LexAction::Done => {
      self.debug_logger.info("Done")

      (LexAction::Done, ctx)
    }
  }
}

///|
/// 创建 Token（包含完整的 LangTag）
pub fn make_token(state : LexStateMachine, content : String) -> N3Token {
  match state {
    LexStateMachine::InIri => N3Token::Iri(content)
    LexStateMachine::InBlankLabel => N3Token::BlankNodeLabel(content)
    LexStateMachine::InBlank => N3Token::BlankNodeLabel(content)
    LexStateMachine::InString => N3Token::String(content)
    LexStateMachine::InLongString => N3Token::LongString(content)
    LexStateMachine::InLangTag => {
      // 直接使用 content，-bidi 决定方向
      let direction = if content.has_suffix("-bidi") {
        Some(BaseDirection::Rtl)
      } else {
        None
      }
      N3Token::LangTag(language=content, direction~)
    }
    LexStateMachine::InVariable => N3Token::Variable(content)
    LexStateMachine::InKeyword => N3Token::PlainKeyword(content)
    LexStateMachine::InInteger => N3Token::Integer(content)
    LexStateMachine::InDecimal => N3Token::Decimal(content)
    LexStateMachine::InDouble => N3Token::Double(content)
    LexStateMachine::InPunct => N3Token::Punctuation(content)
    LexStateMachine::InPnamePrefix | LexStateMachine::InPnameLocal =>
      match content.find(":") {
        Some(idx) => {
          let prefix = content.sub(start=0, end=idx).to_owned()
          let localx = content
            .sub(start=idx + 1, end=content.length())
            .to_owned()
          N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri=false)
        }
        None => N3Token::PlainKeyword(content)
      }
    _ => N3Token::PlainKeyword(content)
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
  // 1. 获取当前字符
  let current = match ctx.data_buffer.get(ctx.position) {
    Some(b) => b
    None => return None
  }
  // debug("  current: \{@utf8.decode_lossy([current])}")

  // 2. 字符分类
  let char_class = classify_byte(current)

  // 3. 查找转换
  let t = self.find_transition(ctx.state, char_class)

  match t {
    Some(transition) => {
      // 4. 执行动作
      let (action, new_ctx) = self.execute_action(
        transition.action,
        ctx,
        current,
        data_buffer,
      )

      // 5. 更新状态（如果需要）
      let final_ctx = if transition.to != new_ctx.state {
        { ..new_ctx, state: transition.to }
      } else {
        new_ctx
      }

      Some((action, final_ctx))
    }
    None => None
  }
}

///|
/// 执行状态机直到输出 Token
pub fn RdfLexer::run_state_machine(
  self : RdfLexer,
  data_buffer : ArrayView[Byte],
  is_ending : Bool,
  location_pos : SourcePos,
) -> (Int, Result[LocatedToken, TokenRecognizerError])? {
  let mut ctx = LexContext::new(data_buffer, is_ending~)

  for ;; {
    self.debug_logger.info("step: pos=\{ctx.position}, state=\{ctx.state}")

    match self.step(ctx, data_buffer) {
      Some((action, new_ctx)) => {
        ctx = new_ctx // ★ 更新 ctx

        match action {
          LexAction::EmitToken => {
            let state = ctx.emit_state.unwrap_or(ctx.state) // ★ 使用 emit_state
            let token = make_token(state, ctx.captured.unwrap_or(""))
            self.debug_logger.info("  -> Emit: \{token}")
            let range = Range::Range(
              location_pos.offset,
              location_pos.offset + ctx.position,
            )
            return Some((ctx.position, Ok(LocatedToken(token, range))))
          }
          LexAction::EmitError(_msg) => {
            let range = Range::Range(
              location_pos.offset,
              location_pos.offset + ctx.position,
            )
            return Some(
              (
                ctx.position,
                Err(TokenRecognizerError::InvalidToken(data_buffer, range)),
              ),
            )
          }
          _ => continue
        }
      }
      None => {
        // 无转换，尝试恢复
        if ctx.capture_current > ctx.capture_start {
          let token = make_token(ctx.state, ctx.get_capture())
          let pos = ctx.position
          let range = Range::Range(
            location_pos.offset,
            location_pos.offset + pos,
          )
          return Some((ctx.capture_current, Ok(LocatedToken(token, range))))
        }
        let pos = ctx.position

        let range = Range::Range(
          location_pos.offset,
          location_pos.offset + pos + 1,
        )

        return Some(
          (
            ctx.position + 1,
            Err(TokenRecognizerError::InvalidToken(data_buffer, range)),
          ),
        )
      }
    }
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
  self.run_state_machine(data_buffer, is_ending, location_pos)
}
