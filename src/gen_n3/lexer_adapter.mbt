// ===== 词法适配层：Token → N3Event 逐 token 机械分类 =====
// 克隆 trig lexer_adapter 骨架（同构函数族），N3 增量三件：
//   ?x 变量 peek-merge：`?` 后零空格邻接无冒号 PrefName 合成 N3Variable
//     （gen.md §4.2：裸 ? 语法错误、??x 不非法吞词——merge 只认邻接；
//     peek 失配的 token 转事件入 pending 槽先入后兑，不丢 token）；
//   langtag 词法期拆分：Literal token span 整段含 @lang（探针实测 Lit(6,6)
//     覆盖 "x"@en）。以收引号锚定后嗅 @langtag——Lexermoon 吞边界口径下
//     span 可能胖一字（零空格后随 ,/. 被吞），收引号锚定不受扰；拆不出
//     （三引号含 lone-quote、内容 @、裸 @）退化为整段折文本，物化层权威拆分；
//     ^^dt 折文本不拆（物化层拆口径，与集合解耦）；
//   [] ANON peek-merge（trig 战役①同款）。
// 分类面：数值整段一词 → N3Literal；双字节 => <= → Implies/ImpliedBy；
//   单字节 { } [ ] ( ) @ = ! ^ → 结构/路径事件（N3 无 ~/{| |}/graph/version，
//   落 Unknown）；@forAll/@forSome/@keywords @ 邻接精确拼写 → *Kw（N3 正牌）；
//   @prefix/@base 零空格直连冒号拆分槽；'a' → KeywordA；true/false → Literal；
//   裸 is/of → 正牌事件 Is/Of（役6 事件化：倒装接表；未接位置无行 = 干净拒）；
//   其余无冒号词降 Unknown（bad-prefix-05 口径）。
// 跨 token 决策仍零语法味：ANON/变量都是词法产生式，语法决策全留转移表。

///|
pub(all) struct N3LexerAdapter {
  inner : Lexermoon
  data : ArrayView[Byte]
  mut eof_seen : Bool // N3EOF 只合法送达一次；其后 None=枯竭兜底
  mut pending : N3Event? // @ 指令冒号半边 / ? 变量 peek 失配回存事件（单槽，先入后兑）
  mut anon_swallow : Bool // N3Anon 合并后待吞的 `]`
}

///|
/// 构造：与 Lexermoon::new 同 view 口径
pub fn N3LexerAdapter::new(view : ArrayView[Byte]) -> N3LexerAdapter {
  {
    inner: Lexermoon::new(view),
    data: view,
    eof_seen: false,
    pending: None,
    anon_swallow: false,
  }
}

///|
/// Token -> N3Event：单 token 机械分类（无语法判断）
fn token_to_n3_event(data : ArrayView[Byte], token : Token) -> N3Event {
  match token {
    Token::Iri(span) => N3Event::N3Iri(span)
    Token::BlankNode(span) => N3Event::N3BlankNode(span)
    Token::Literal(span) =>
      // 双载荷拆分：语言标签子 span 词法期出（恰覆盖子标签，不含 @）；
      // ^^dt 折文本不拆（物化层拆口径）
      N3Event::N3Literal(span, split_langtag(data, span))
    Token::TripleTerm(span) =>
      // 括号壳 <<( 分流（兼容口径同 trig：N-Triples 1.2 形态只开宾语位，表裁决）
      if span.1 >= 3 && data[span.0 + 2] == b'(' {
        N3Event::N3BracketTripleTerm(span)
      } else {
        N3Event::N3TripleTerm(span)
      }
    Token::Dot(_) => N3Event::N3Dot
    Token::Comma(_) => N3Event::N3Comma
    Token::Semicolon(_) => N3Event::N3Semicolon
    Token::Unknown(span) => classify_structural(data, span)
    Token::PrefName(span) => classify_prefname(data, span)
    Token::EOF(_) => N3Event::N3EOF // LexerSource 协议在此过滤为 None
  }
}

///|
/// Unknown 分类：数值字面量整段一词（可带符号，词法扫描保证形态）→ N3Literal
///（span 口径：物化层展开 typed literal）；双字节 => <= → 蕴含事件；
/// 单字节结构字符 { } [ ] ( ) @ = ! ^ 各自成事件；其余保持 Unknown（表外垃圾）
fn classify_structural(data : ArrayView[Byte], span : Span) -> N3Event {
  if is_numeric_span(data, span.0, span.1) {
    return N3Event::N3Literal(span, None)
  }
  if span.1 == 2 {
    // RDF 1.2 annotation delimiters (lexer emits them as one two-byte token)
    if data[span.0] == b'{' && data[span.0 + 1] == b'|' {
      N3Event::N3AnnotStart
    } else if data[span.0] == b'|' && data[span.0 + 1] == b'}' {
      N3Event::N3AnnotEnd
    } else if data[span.0] == b'=' && data[span.0 + 1] == b'>' {
      // 载荷 = 操作符 token span（役4：规则谓词身份）
      N3Event::N3Implies(span)
    } else if data[span.0] == b'<' && data[span.0 + 1] == b'=' {
      N3Event::N3ImpliedBy(span)
    } else {
      N3Event::N3Unknown(span)
    }
  } else if span.1 == 1 {
    let c = data[span.0]
    if c == b'{' {
      // 同 Lbracket 口径（公式身份；ADR-002 不透明图项身份 = { span）
      N3Event::N3Lbrace(span)
    } else if c == b'}' {
      N3Event::N3Rbrace
    } else if c == b'[' {
      // 载荷 = 开括号 token 自身 span：fresh bnode 身份（offset 全文档唯一）
      N3Event::N3Lbracket(span)
    } else if c == b']' {
      N3Event::N3Rbracket
    } else if c == b'(' {
      // 同 Lbracket 口径（集合语法身份；ADR-003a 单一 BNode）
      N3Event::N3Lparen(span)
    } else if c == b')' {
      N3Event::N3Rparen
    } else if c == b'@' {
      N3Event::N3At
    } else if c == b'=' {
      // N3 `=`：owl:sameAs 语法糖标识（ADR-005）；载荷化 = token 自身 span
      //（役7 接表：= 占谓词槽，语义身份在 pk=SameAs，操作符族同教义）
      N3Event::N3Equals(span)
    } else if c == b'!' {
      // N3 前向路径引导符（ADR-006，役3 接表）；载荷化 = token 自身 span
      // ——路径中间节点 fresh 身份（开括号族同教义）
      N3Event::N3Bang(span)
    } else if c == b'~' {
      // RDF 1.2 reifier introducer (~ label / ~ annotation combo)
      N3Event::N3Tilde
    } else if c == b'^' {
      // N3 反向路径引导符（载荷化同 Bang：操作符 span = 中间节点身份）
      N3Event::N3Caret(span)
    } else {
      N3Event::N3Unknown(span)
    }
  } else {
    N3Event::N3Unknown(span)
  }
}

///|
/// 数值形态复核（词法整段扫描口径：[+-]?([0-9]+('.'[0-9]*)? | '.'[0-9]+)([eE][+-]?[0-9]+)?）：
/// 首字节 数字/+/−/.，至少一个数字，其余仅 . e E + -
fn is_numeric_span(data : ArrayView[Byte], off : Int, len : Int) -> Bool {
  let c0 = data[off]
  if !(c0 == b'+' || c0 == b'-' || c0 == b'.' || (c0 >= b'0' && c0 <= b'9')) {
    return false
  }
  let mut has_digit = false
  for i in 0..<len {
    let c = data[off + i]
    if c >= b'0' && c <= b'9' {
      has_digit = true
    } else if !(c == b'.' || c == b'e' || c == b'E' || c == b'+' || c == b'-') {
      return false
    }
  }
  has_digit
}

///|
/// PrefName 内容分类：'a' 缩写 / 指令关键词 / N3 量化指令 / 裸 is·of（役6 事件化）/ 普通前缀名。
/// 只对完整 span 内容精确判别："a:x"、"prefix:" 这类不会误分类。
fn classify_prefname(data : ArrayView[Byte], span : Span) -> N3Event {
  let (off, len) = span
  if len == 1 && data[off] == b'a' {
    N3Event::N3KeywordA(span)
  } else if len == 4 && eq_lower(data, off, b"true") {
    // 布尔字面量（小写精确；物化层展开 xsd:boolean）
    N3Event::N3Literal(span, None)
  } else if len == 5 && eq_lower(data, off, b"false") {
    N3Event::N3Literal(span, None)
  } else if len == 7 && eq_ignore_case(data, off, b"version") {
    // RDF 1.2 VERSION directive keyword (case-insensitive; global reserved word,
    // same trade-off as graph). @-style ('@' adjacent) must be lowercase exact,
    // demote Unknown -> table-edge reject; SPARQL-style bare word is case-insensitive
    // @version 在 RDF 1.2 文法（@ 风格带点收尾，与 @prefix 同取舍）：
    // '@' 邻接须小写精确（@Version 非法，bad-base-02 同族）降级 Unknown
    if at_style_kw(data, off) && !eq_lower(data, off, b"version") {
      N3Event::N3Unknown(span)
    } else {
      N3Event::N3VersionKw
    }
  } else if len == 6 && eq_ignore_case(data, off, b"prefix") {
    // @ 风格（'@' 紧邻）指令名须小写精确：@Prefix 非法（bad-base-02 同族），
    // 降级 Unknown → 转移表外报错；SPARQL 风格裸词大小写不敏感，表裁决收口
    if at_style_kw(data, off) && !eq_lower(data, off, b"prefix") {
      N3Event::N3Unknown(span)
    } else {
      N3Event::N3PrefixKw
    }
  } else if len == 4 && eq_ignore_case(data, off, b"base") {
    if at_style_kw(data, off) && !eq_lower(data, off, b"base") {
      N3Event::N3Unknown(span)
    } else {
      N3Event::N3BaseKw
    }
  } else if len == 6 && at_style_kw(data, off) && eq_lower(data, off, b"forAll") {
    // @forAll：N3 量化指令（@ 邻接 + 精确拼写，大小写敏感）——N3 正牌事件
    N3Event::N3ForAllKw
  } else if len == 7 &&
    at_style_kw(data, off) &&
    eq_lower(data, off, b"forSome") {
    N3Event::N3ForSomeKw
  } else if len == 8 &&
    at_style_kw(data, off) &&
    eq_lower(data, off, b"keywords") {
    // @keywords：关键词声明指令（@keywords 声明后裸词皆名——词法仍机械出
    // KeywordA，声明语义归表/action，役5 已接表：ExpectKeywordsList 台账）
    N3Event::N3KeywordsKw
  } else if len == 2 &&
    (eq_lower(data, off, b"is") || eq_lower(data, off, b"of")) {
    // 裸 is/of（N3 `?x is :p of ?y` 集合等价倒装 ≡ `Y P X`）：役6 事件化——
    // 正牌事件入表（顶层四动词位接倒装行）；未接位置（bnp/公式/注解）无行 =
    // UnexpectedEvent 干净拒。此前保 PrefName 被谓词行误收编：is 成谓词、
    // 整句随 of 无行静默吞（零 quad 零报错）
    if eq_lower(data, off, b"is") {
      N3Event::N3Is
    } else {
      N3Event::N3Of
    }
  } else if len == 3 && eq_lower(data, off, b"has") {
    // 裸 `has`（N3 `X has P` 谓词引导词，役11）：is/of 同款事件化——cwm 词法
    // 保留，六动词位 self-loop 行接表（下个事件在本态收动词，罩/框包含不破）；
    // 其余位置无行 = 干净拒
    N3Event::N3Has
    // 无冒号 PrefName 全域非法：term 位 PNAME_NS 必带冒号（bad-prefix-05 口径）；
    // 关键词/'a'/布尔/is·of 已先行分流，此处降级 Unknown 表外报错
  } else if span_has_colon(data, off, len) {
    N3Event::N3PrefName(span)
  } else {
    N3Event::N3Unknown(span)
  }
}

///|
/// langtag 词法期拆分（N3Literal 双载荷，N3 比 trig 提前一层）：
/// 收引号锚定（单引号形态扫转义直落；三引号形态含 lone-quote 内容时退化为
/// 不拆——整段折文本，物化层权威拆分不受扰）后嗅 `@langtag`；lang 子 span
/// 恰覆盖子标签（不含 @）；`^^dt` 折文本不拆；Lexermoon 吞边界口径下 span
/// 可能胖一字（零空格后随 ,/. 被吞），收引号锚定不受扰。
fn split_langtag(data : ArrayView[Byte], span : Span) -> Span? {
  let (off, len) = span
  let end = off + len
  if len < 5 {
    return None // 最短带 lang 形如 "x"@e（5 字节）
  }
  let q = data[off]
  if q != b'"' && q != b'\'' {
    return None // 数值/布尔（Unknown→Literal 口径）无 lang 位
  }
  let mut close = -1
  let mut i = off + 1
  while i < end {
    let c = data[i]
    if c == b'\\' {
      i = i + 2
      continue
    }
    if c == q {
      close = i
      break
    }
    i = i + 1
  }
  if close < 0 || close + 1 >= end {
    return None
  }
  // 三引号嫌疑：close 后仍引号 → 此 close 可能是内容 lone-quote 或三连开壳
  // 尾——二者都不拆（保真折文本；三连尾情形 close+1 是 @ 的形不存在于本口径，
  // 物化层权威拆分兜底）
  if close + 2 < end && data[close + 1] == q && data[close + 2] == q {
    return None
  }
  if data[close + 1] != b'@' {
    return None
  }
  let lstart = close + 2
  let mut j = lstart
  while j < end && is_langtag_byte(data[j]) {
    j = j + 1
  }
  if j > lstart {
    Some((lstart, j - lstart))
  } else {
    None // 裸 @（无子标签）：折文本，物化层报
  }
}

///|
fn is_langtag_byte(c : Byte) -> Bool {
  (c >= b'a' && c <= b'z') ||
  (c >= b'A' && c <= b'Z') ||
  (c >= b'0' && c <= b'9') ||
  c == b'-'
}

///|
/// span 内是否含冒号（变量名禁冒号：?x:y 非 N3 变量形态）
fn span_has_colon(data : ArrayView[Byte], off : Int, len : Int) -> Bool {
  for i in 0..<len {
    if data[off + i] == b':' {
      return true
    }
  }
  false
}

///|
/// @ 风格指令嗅探：keyword token 前一字节是否 '@'（向后窥一字节，零跨 token 状态）
fn at_style_kw(data : ArrayView[Byte], off : Int) -> Bool {
  off > 0 && data[off - 1] == b'@'
}

///|
/// 精确小写比对（@ 风格指令名口径：@prefix/@base/@forAll 小写精确）
fn eq_lower(data : ArrayView[Byte], off : Int, kw : Bytes) -> Bool {
  for i in 0..<kw.length() {
    if data[off + i] != kw[i] {
      return false
    }
  }
  true
}

///|
/// 大小写不敏感字节比较（零分配；kw 为 ASCII 字节字面量）
fn eq_ignore_case(data : ArrayView[Byte], off : Int, kw : Bytes) -> Bool {
  let n = kw.length()
  for i in 0..<n {
    let c = data[off + i]
    let k = kw[i]
    let c1 = if c >= b'A' && c <= b'Z' { c + 32 } else { c }
    let k1 = if k >= b'A' && k <= b'Z' { k + 32 } else { k }
    if c1 != k1 {
      return false
    }
  }
  true
}

///|
/// LexerSource 实现：逐 token 分类；N3EOF 合法送达一次，其后 None=枯竭
pub impl LexerSource for N3LexerAdapter with fn next(self : N3LexerAdapter) -> N3Event? {
  // 拆分/回存槽先兑现：@ 指令冒号半边、? 变量 peek 失配回存事件
  match self.pending {
    Some(ev) => {
      self.pending = None
      return Some(ev)
    }
    None => ()
  }
  // [] ANON 吞槽兑现：N3Anon 发出时已按数据面窥定 `]` 位，此处吃掉 scanner
  // 必然扫出的那枚 `]` token（offset 校验，失配 = 词法脏走 Unknown）
  if self.anon_swallow {
    self.anon_swallow = false
    match self.inner.next() {
      Some(Token::Unknown((o2, l2))) if l2 == 1 && self.data[o2] == b']' => ()
      _ => return Some(N3Event::N3Unknown((self.pos(), 0)))
    }
  }
  match self.inner.next() {
    None => None
    Some(token) =>
      if token is Token::EOF(_) {
        if self.eof_seen {
          None
        } else {
          self.eof_seen = true
          Some(N3Event::N3EOF)
        }
      } else {
        // [] ANON 合并（`[]` 在语法上是 ANON 产生式，不是开括号）：`[` 后按
        // 数据面跳空白窥 `]`（只跳空白不跳注释——ANON 产生式不容注释，从严）；
        // 命中 → 单事件 N3Anon（span 贯通 `]`，fresh 身份 = `[` offset）
        if token is Token::Unknown((boff, blen)) &&
          blen == 1 &&
          self.data[boff] == b'[' {
          let mut j = boff + 1
          while j < self.data.length() &&
                (
                  self.data[j] == b' ' ||
                  self.data[j] == b'\t' ||
                  self.data[j] == b'\r' ||
                  self.data[j] == b'\n'
                ) {
            j = j + 1
          }
          if j < self.data.length() && self.data[j] == b']' {
            self.anon_swallow = true
            return Some(N3Event::N3Anon((boff, j + 1 - boff)))
          }
        }
        // ?x 变量 peek-merge（gen.md §4.2）：`?` 后零空格邻接无冒号 PrefName
        // 合成 N3Variable（span 贯通变量名）。peek 失配（裸 ? / ??x / ? 后带
        // 空格 / ?x:y 形）不吞词：peek 到的 token 转事件入 pending 槽，`?`
        // 自身落 N3Unknown 走错误路径——语法决策仍留给表
        if token is Token::Unknown((qoff, qlen)) &&
          qlen == 1 &&
          self.data[qoff] == b'?' {
          match self.inner.next() {
            Some(Token::PrefName((poff, plen))) =>
              if poff == qoff + 1 && !span_has_colon(self.data, poff, plen) {
                return Some(N3Event::N3Variable((qoff, poff + plen - qoff)))
              } else {
                self.pending = Some(
                  token_to_n3_event(self.data, Token::PrefName((poff, plen))),
                )
              }
            Some(t2) => self.pending = Some(token_to_n3_event(self.data, t2))
            None => ()
          }
          return Some(N3Event::N3Unknown((qoff, qlen)))
        }
        // ★ @ 风格指令名零空格直连冒号拆分（minimal-whitespace 口径同 trig）：
        //   `@prefix:<iri>` 词法整词扫出 `prefix:`（冒号是名字字符），关键词臂
        //   只认 6 字节整词 → 落普通 PrefName。此处按 @ 邻接位拆成关键词事件 +
        //   冒号 PrefName（声明名 token，槽位 pending 先入后兑）。仅精确 "kw:"
        //   形拆分——"kw:foo" 带本地部非法（prefixID 只收 PNAME_NS），不拆
        if token is Token::PrefName((off, len)) && at_style_kw(self.data, off) {
          let colon_at = if len == 7 &&
            eq_lower(self.data, off, b"prefix") &&
            self.data[off + 6] == b':' {
            6
          } else if len == 5 &&
            eq_lower(self.data, off, b"base") &&
            self.data[off + 4] == b':' {
            4
          } else {
            -1
          }
          if colon_at > 0 {
            self.pending = Some(N3Event::N3PrefName((off + colon_at, 1)))
            return Some(
              match colon_at {
                6 => N3Event::N3PrefixKw
                _ => N3Event::N3BaseKw
              },
            )
          }
        }
        Some(token_to_n3_event(self.data, token))
      }
  }
}

///|
pub impl LexerSource for N3LexerAdapter with fn pos(self : N3LexerAdapter) -> Int {
  self.inner.current_pos()
}

///|
pub impl LexerSource for N3LexerAdapter with fn byte_at(
  self : N3LexerAdapter,
  offset : Int,
) -> Byte {
  self.data[offset]
}
