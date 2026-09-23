// ===== 词法适配层：NQuadsEvent → TrigEvent 逐事件机械分类 =====
// 复用 @nquads.Lexermoon 的无脑扫；TriG 需要的结构字符/关键词由本层按
// 单 token 判别合成事件（无跨 token 状态——语法决策全部留给转移表；
// 唯一例外：@ 风格指令名零空格直连冒号的拆分槽 pending，见 next 内注）。
// 分类面（TOML 化面，生成器将来按 spec 的 lexer.dialect 段生成）：
//   Unknown 按形态: 数值整段一词（可带符号）-> TrigLiteral；
//                   双字节 {| |} -> Annot*；=> <= -> Implies/ImpliedBy（N3 预埋）；
//                   单字节 { } [ ] ( ) @ ~ ! ^ -> 结构/路径事件（! ^ 为 N3 预埋）；
//                   其余 Unknown（表外垃圾）
//   注：Unknown span 经 Lexermoon.last_unknown 单槽旁路保留（P2 刀 a)：生成
//       契约 NQuadsUnknown 为常量构造子，span 出词点落槽、Unknown 事件后即读
//       ——表外报错定位与 `@keywords` 台账登记共用同一 span 面（役35 35-B0
//       语义不变）；分类降级点一律原样上抛本 token 的 span。
//   PrefName 按 span 内容: "a" -> TrigKeywordA；"true"/"false"（小写精确）-> TrigLiteral；
//                          "graph"/"GRAPH" -> TrigGraphKw；
//                          "prefix"/"PREFIX" -> TrigPrefixKw；
//                          "base"/"BASE" -> TrigBaseKw；
//                          @邻接精确拼写 "forAll"/"forSome"/"keywords" -> *Kw（N3 预埋）
//   其余 1:1 直映射。EOF 过滤归 LexerSource 协议。

///|
pub(all) struct TrigLexerAdapter {
  inner : Lexermoon
  data : ArrayView[Byte]
  mut eof_seen : Bool // TrigEOF 只合法送达一次；其后 None=枯竭兜底
  mut pending : TrigEvent? // @ 风格指令名零空格直连冒号拆分的冒号半边（单槽，先兑现）
  mut anon_swallow : Bool // TrigAnon 合并后待吞的 `]`（数据面窥定，next 顶兑现）
}

///|
/// 构造：与 Lexermoon::new 同 view 口径
pub fn TrigLexerAdapter::new(view : ArrayView[Byte]) -> TrigLexerAdapter {
  {
    inner: Lexermoon::new(view),
    data: view,
    eof_seen: false,
    pending: None,
    anon_swallow: false,
  }
}

///|
/// NQuadsEvent -> TrigEvent：单事件机械分类（无语法判断）。P2 刀 a) 起
/// Lexermoon 直产事件，Unknown 的 span 经 last_unknown 单槽即读
fn token_to_trig_event(lexer : TrigLexerAdapter, ev : NQuadsEvent) -> TrigEvent {
  let data = lexer.data
  match ev {
    NQuadsEvent::NQuadsIri(span) => TrigEvent::TrigIri(span)
    NQuadsEvent::NQuadsBlankNode(span) => TrigEvent::TrigBlankNode(span)
    NQuadsEvent::NQuadsLiteral(span) => TrigEvent::TrigLiteral(span)
    NQuadsEvent::NQuadsTripleTerm(span) =>
      // 括号壳 <<( 分流（兼容口径：N-Triples 1.2 形态只开宾语位，表裁决）；
      // `<<(` 无空格形态同命中（basic-03 `<<(:s` 口径）
      if span.1 >= 3 && data[span.0 + 2] == b'(' {
        TrigEvent::TrigBracketTripleTerm(span)
      } else {
        TrigEvent::TrigTripleTerm(span)
      }
    NQuadsEvent::NQuadsDot => TrigEvent::TrigDot
    NQuadsEvent::NQuadsComma => TrigEvent::TrigComma
    NQuadsEvent::NQuadsSemicolon => TrigEvent::TrigSemicolon
    NQuadsEvent::NQuadsUnknown =>
      classify_structural(data, lexer.inner.last_unknown_span())
    NQuadsEvent::NQuadsPrefName(span) => classify_prefname(data, span)
    NQuadsEvent::NQuadsEOF => TrigEvent::TrigEOF // LexerSource 协议在此过滤为 None
  }
}

///|
/// Unknown 分类：数值字面量整段一词（可带符号，词法扫描保证形态）→ TrigLiteral
///（span 口径：物化层展开 typed literal）；单字节结构字符 { } [ ] ( ) @ 各自成事件；
/// 其余保持 Unknown（表外垃圾）
fn classify_structural(data : ArrayView[Byte], span : Span) -> TrigEvent {
  if @nquads.is_numeric_span(data, span.0, span.1) {
    return TrigEvent::TrigLiteral(span)
  }
  if span.1 == 2 {
    // RDF 1.2 注解定界符（词法整词出，此处按双字节分类）
    if data[span.0] == b'{' && data[span.0 + 1] == b'|' {
      TrigEvent::TrigAnnotStart
    } else if data[span.0] == b'|' && data[span.0 + 1] == b'}' {
      TrigEvent::TrigAnnotEnd
    } else if data[span.0] == b'=' && data[span.0 + 1] == b'>' {
      // N3 预埋：=> 蕴含（词法整词出，表未接走兜底）
      TrigEvent::TrigImplies
    } else if data[span.0] == b'<' && data[span.0 + 1] == b'=' {
      // N3 预埋：<= 被蕴含
      TrigEvent::TrigImpliedBy
    } else {
      TrigEvent::TrigUnknown(span)
    }
  } else if span.1 == 1 {
    let c = data[span.0]
    if c == b'{' {
      TrigEvent::TrigLbrace
    } else if c == b'}' {
      TrigEvent::TrigRbrace
    } else if c == b'[' {
      // 载荷 = 开括号 token 自身 span：fresh bnode 身份（★3；offset 全文档唯一）
      TrigEvent::TrigLbracket(span)
    } else if c == b']' {
      TrigEvent::TrigRbracket
    } else if c == b'(' {
      // 同 Lbracket 口径（集合链节点身份，阶段3 接表）
      TrigEvent::TrigLparen(span)
    } else if c == b')' {
      TrigEvent::TrigRparen
    } else if c == b'@' {
      TrigEvent::TrigAt
    } else if c == b'~' {
      // RDF 1.2 reifier 引导符（~ 后随可选标签，标签位由表裁决）
      TrigEvent::TrigTilde
    } else if c == b'!' {
      // N3 预埋：! 前向路径引导符（表未接走兜底）
      TrigEvent::TrigBang
    } else if c == b'^' {
      // N3 预埋：^ 反向路径引导符
      TrigEvent::TrigCaret
    } else {
      TrigEvent::TrigUnknown(span)
    }
  } else {
    TrigEvent::TrigUnknown(span)
  }
}

///|
/// PrefName 内容分类：'a' 缩写 / 指令关键词（大小写不敏感）/ 普通前缀名。
/// 只对完整 span 内容精确判别："a:x"、"prefix:" 这类不会误分类。
fn classify_prefname(data : ArrayView[Byte], span : Span) -> TrigEvent {
  let (off, len) = span
  if len == 1 && data[off] == b'a' {
    TrigEvent::TrigKeywordA(span)
  } else if @nquads.is_boolean_word(data, off, len) {
    // 布尔字面量（小写精确；物化层展开 xsd:boolean）——役29 R-15 共享判定
    TrigEvent::TrigLiteral(span)
  } else if len == 5 && eq_ignore_case(data, off, b"graph") {
    // SPARQL 风格 GRAPH 关键字（大小写不敏感；裸词 "graph" 本就非法，无误分类面）
    // @ 风格（'@' 紧邻）指令名须小写精确，降级 Unknown → 转移表外报错
    if at_style_kw(data, off) && !eq_lower(data, off, b"graph") {
      TrigEvent::TrigUnknown(span)
    } else {
      TrigEvent::TrigGraphKw
    }
  } else if len == 7 && eq_ignore_case(data, off, b"version") {
    // RDF 1.2 VERSION 指令关键词（大小写不敏感；全局保留词，与 graph 同取舍）
    // @ 风格（'@' 紧邻）指令名须小写精确，降级 Unknown → 转移表外报错
    if at_style_kw(data, off) && !eq_lower(data, off, b"version") {
      TrigEvent::TrigUnknown(span)
    } else {
      TrigEvent::TrigVersionKw
    }
  } else if len == 6 && eq_ignore_case(data, off, b"prefix") {
    // @ 风格（'@' 紧邻）指令名须小写精确：@Prefix 非法（bad-base-02 同族），
    // 降级 Unknown → 转移表外报错；SPARQL 风格裸词才大小写不敏感
    if at_style_kw(data, off) && !eq_lower(data, off, b"prefix") {
      TrigEvent::TrigUnknown(span)
    } else {
      TrigEvent::TrigPrefixKw
    }
  } else if len == 4 && eq_ignore_case(data, off, b"base") {
    // @ 风格（'@' 紧邻）指令名须小写精确：@BASE 非法（bad-base-02 口径），
    // 降级 Unknown → 转移表外报错；SPARQL 风格裸词才大小写不敏感
    if at_style_kw(data, off) && !eq_lower(data, off, b"base") {
      TrigEvent::TrigUnknown(span)
    } else {
      TrigEvent::TrigBaseKw
    }
  } else if len == 6 && at_style_kw(data, off) && eq_lower(data, off, b"forAll") {
    // N3 预埋：@forAll 量化指令（@ 邻接 + 精确拼写，大小写敏感；
    // 表未接走兜底）。@ 风格与 SPARQL 风格取舍同 prefix/graph 口径
    TrigEvent::TrigForAllKw
  } else if len == 7 &&
    at_style_kw(data, off) &&
    eq_lower(data, off, b"forSome") {
    // N3 预埋：@forSome
    TrigEvent::TrigForSomeKw
  } else if len == 8 &&
    at_style_kw(data, off) &&
    eq_lower(data, off, b"keywords") {
    // N3 预埋：@keywords 关键词声明指令
    TrigEvent::TrigKeywordsKw
  } else {
    // 无冒号 PrefName 全域非法：term 位 PNAME_NS 必带冒号、声明名须尾冒号
    //（bad-prefix-05 口径）；关键词/'a'/布尔已先行分流，此处降级 Unknown 表外报错
    let mut has_colon = false
    for i in 0..<len {
      if data[off + i] == b':' {
        has_colon = true
        break
      }
    }
    if has_colon {
      TrigEvent::TrigPrefName(span)
    } else {
      TrigEvent::TrigUnknown(span)
    }
  }
}

///|
/// LexerSource 实现：逐 token 分类；TrigEOF 合法送达一次，其后 None=枯竭
pub impl LexerSource for TrigLexerAdapter with fn next(self : TrigLexerAdapter) -> TrigEvent? {
  // 拆分槽先兑现：`@prefix:` 的冒号半边（声明名 PrefName）排在关键词事件之后
  match self.pending {
    Some(ev) => {
      self.pending = None
      return Some(ev)
    }
    None => ()
  }
  // [] ANON 吞槽兑现：TrigAnon 发出时已按数据面窥定 `]` 位，此处吃掉 scanner
  // 必然扫出的那枚 `]` token（offset 校验，失配 = 词法脏走 Unknown）
  if self.anon_swallow {
    self.anon_swallow = false
    match self.inner.next() {
      Some(NQuadsEvent::NQuadsUnknown) => {
        let s2 = self.inner.last_unknown_span()
        if s2.1 == 1 && self.data[s2.0] == b']' {
          ()
        } else {
          return Some(TrigEvent::TrigUnknown(s2))
        }
      }
      _ => return Some(TrigEvent::TrigUnknown((0, 0)))
    }
  }
  match self.inner.next() {
    None => None
    Some(ev) =>
      if ev is NQuadsEvent::NQuadsEOF {
        if self.eof_seen {
          None
        } else {
          self.eof_seen = true
          Some(TrigEvent::TrigEOF)
        }
      } else {
        // [] ANON 合并（kw-graph-07 口径）：`[]` 在语法上是 ANON 产生式
        //（空 bnode 终结符），不是开括号。`[` 后按数据面跳空白窥 `]`：
        // 命中 → 单事件 TrigAnon（span 贯通 `]`，fresh 身份 = `[` offset，
        // 物化层 memo genid 口径不变）；未命中 → 普通 Lbracket 走 Bnp 区域。
        // 窥探只跳空白不跳注释——`[ # c \n ]` 不合并（ANON 产生式不容注释，
        // 词法口径从严）；跨 token 决策仍零语法味：ANON 是词法产生式
        if ev is NQuadsEvent::NQuadsUnknown {
          // Unknown span 单槽即读：`[` 单字节形态才进 ANON 合并决策
          let bs = self.inner.last_unknown_span()
          if bs.1 == 1 && self.data[bs.0] == b'[' {
            let boff = bs.0
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
              return Some(TrigEvent::TrigAnon((boff, j + 1 - boff)))
            }
          }
        }
        // ★ @ 风格指令名零空格直连冒号拆分（minimal-whitespace-01 口径）：
        //   `@prefix:<iri>` 词法整词扫出 `prefix:`（冒号是名字字符），关键词臂
        //   只认 6 字节整词 → 落普通 PrefName 表外报错。此处按 @ 邻接位拆成
        //   关键词事件 + 冒号 PrefName（声明名 token，槽位 pending 先入后兑）。
        //   仅精确 "kw:" 形拆分——"kw:foo" 带本地部非法（prefixID 只收 PNAME_NS
        //   无 local），不拆、落普通 PrefName 表外报错；term 位 `prefix:x` 无
        //   @ 邻接永不命中（合法 pname 不受扰）
        if ev is NQuadsEvent::NQuadsPrefName((off, len)) && at_style_kw(self.data, off) {
          let colon_at = if len == 7 &&
            eq_lower(self.data, off, b"prefix") &&
            self.data[off + 6] == b':' {
            6
          } else if len == 5 &&
            eq_lower(self.data, off, b"base") &&
            self.data[off + 4] == b':' {
            4
          } else if len == 8 &&
            eq_lower(self.data, off, b"version") &&
            self.data[off + 7] == b':' {
            7
          } else {
            -1
          }
          if colon_at > 0 {
            self.pending = Some(TrigEvent::TrigPrefName((off + colon_at, 1)))
            return Some(
              match colon_at {
                6 => TrigEvent::TrigPrefixKw
                4 => TrigEvent::TrigBaseKw
                _ => TrigEvent::TrigVersionKw
              },
            )
          }
        }
        Some(token_to_trig_event(self, ev))
      }
  }
}

///|
// W18（2026-09-21，工具链 0.1.20260920 起 `implicit_impl_as_method` 弃用）：trait 方法显式提升。
// 注：`next` 在 TrigLexerAdapter 上另有私有方法（诊断原文已提示），此处显式提升与私有方法并存。
pub extend TrigLexerAdapter with LexerSource::{next, byte_at, pos}

///|
pub impl LexerSource for TrigLexerAdapter with fn pos(self : TrigLexerAdapter) -> Int {
  self.inner.current_pos()
}

///|
pub impl LexerSource for TrigLexerAdapter with fn byte_at(
  self : TrigLexerAdapter,
  offset : Int,
) -> Byte {
  self.data[offset]
}
