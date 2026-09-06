// 白盒测试文件：只能访问同包内可访问接口；异步或文件资源测试放黑盒文件。
// ===== 词法适配层事件流钉死（probe_tmp_test.mbt 摸底后收口，全部实测口径）=====

///|
/// 事件流摘要（测试断言用）：逐事件紧凑标签拼接
fn n3_ev_tag(ev : N3Event) -> String {
  match ev {
    N3Event::N3Iri((o, l)) => "Iri(\{o},\{l})"
    N3Event::N3BlankNode((o, l)) => "Bnode(\{o},\{l})"
    N3Event::N3Literal((o, l), lang) =>
      match lang {
        Some((lo, ll)) => "Lit(\{o},\{l})@\{lo},\{ll}"
        None => "Lit(\{o},\{l})"
      }
    N3Event::N3PrefName((o, l)) => "Pref(\{o},\{l})"
    N3Event::N3TripleTerm((o, l)) => "TT(\{o},\{l})"
    N3Event::N3BracketTripleTerm((o, l)) => "BTT(\{o},\{l})"
    N3Event::N3KeywordA((o, l)) => "A(\{o},\{l})"
    N3Event::N3KeywordX((o, l)) => "KwX(\{o},\{l})"
    N3Event::N3Variable((o, l)) => "Var(\{o},\{l})"
    N3Event::N3Equals((o, l)) => "Eq(\{o},\{l})"
    N3Event::N3Is => "Is"
    N3Event::N3Of => "Of"
    N3Event::N3At => "@"
    N3Event::N3PrefixKw => "PrefixKw"
    N3Event::N3BaseKw => "BaseKw"
    N3Event::N3VersionKw => "VersionKw"
    N3Event::N3Tilde => "Tilde"
    N3Event::N3AnnotStart => "AnnotStart"
    N3Event::N3AnnotEnd => "AnnotEnd"
    N3Event::N3ForAllKw => "ForAllKw"
    N3Event::N3ForSomeKw => "ForSomeKw"
    N3Event::N3KeywordsKw => "KeywordsKw"
    N3Event::N3Comma => "Comma"
    N3Event::N3Semicolon => "Semi"
    N3Event::N3Dot => "Dot"
    N3Event::N3Lbrace((o, l)) => "Lbrace(\{o},\{l})"
    N3Event::N3Rbrace => "Rbrace"
    N3Event::N3Lbracket((o, l)) => "Lbracket(\{o},\{l})"
    N3Event::N3Rbracket => "Rbracket"
    N3Event::N3Lparen((o, l)) => "Lparen(\{o},\{l})"
    N3Event::N3Rparen => "Rparen"
    N3Event::N3Anon((o, l)) => "Anon(\{o},\{l})"
    N3Event::N3Bang((o, l)) => "Bang(\{o},\{l})"
    N3Event::N3Caret((o, l)) => "Caret(\{o},\{l})"
    N3Event::N3Implies((o, l)) => "Implies(\{o},\{l})"
    N3Event::N3ImpliedBy((o, l)) => "ImpliedBy(\{o},\{l})"
    N3Event::N3Unknown((o, l)) => "Unk(\{o},\{l})"
    N3Event::N3EOF => "EOF"
  }
}

///|
/// 排干事件流（EOF 收口；cap 64 防死循环）
fn n3_drain(input : String) -> String {
  let data = @utf8.encode(input).to_array()
  let adapter = N3LexerAdapter::new(data[:])
  let mut out = ""
  let mut n = 0
  while n < 64 {
    n = n + 1
    match adapter.next() {
      None => break
      Some(ev) => {
        if out.length() > 0 {
          out = out + " "
        }
        out = out + n3_ev_tag(ev)
        if ev is N3Event::N3EOF {
          break
        }
      }
    }
  }
  out
}

///|
test "变量 ?x：邻接合成 / 裸 ? 拒 / ??x 不吞词" {
  assert_eq(n3_drain("?x :p ?y ."), "Var(0,2) Pref(3,2) Var(6,2) Dot EOF")
  // 裸 ?（后随空白非邻接）→ Unknown 错误路径；peek 回存保 token 不丢
  assert_eq(n3_drain("? :p :o ."), "Unk(0,1) Pref(2,2) Pref(5,2) Dot EOF")
  // ??x：两枚独立 ?——首 ? peek 失配（次 token 是 ? 非 PrefName）落 Unknown，
  // 次 ? peek 到 x 但流已脏；全程无非法吞词（gen.md §4.2）
  assert_eq(
    n3_drain("??x :p :o ."),
    "Unk(0,1) Unk(1,1) Unk(2,1) Pref(4,2) Pref(7,2) Dot EOF",
  )
}

///|
test "路径 !/^ 与规则 =>/<=/= 事件流" {
  assert_eq(
    n3_drain(":a!:b :p :o ."),
    "Pref(0,2) Bang(2,1) Pref(3,2) Pref(6,2) Pref(9,2) Dot EOF",
  )
  assert_eq(
    n3_drain(":a^:b :p :o ."),
    "Pref(0,2) Caret(2,1) Pref(3,2) Pref(6,2) Pref(9,2) Dot EOF",
  )
  assert_eq(n3_drain(":a => :b ."), "Pref(0,2) Implies(3,2) Pref(6,2) Dot EOF")
  assert_eq(
    n3_drain(":a <= :b ."),
    "Pref(0,2) ImpliedBy(3,2) Pref(6,2) Dot EOF",
  )
  // `=` 役7 事件化载荷（Eq(o,l)）；倒装/等同语义钉见 engine_wbtest
  assert_eq(n3_drain(":a = :b ."), "Pref(0,2) Eq(3,1) Pref(5,2) Dot EOF")
  assert_eq(
    n3_drain("{ :a :b :c } => { :d :e :f } ."),
    "Lbrace(0,1) Pref(2,2) Pref(5,2) Pref(8,2) Rbrace Implies(13,2) Lbrace(16,1) Pref(18,2) Pref(21,2) Pref(24,2) Rbrace Dot EOF",
  )
}

///|
test "langtag 词法期拆分 + ^^dt 折文本 + 吞边界口径" {
  assert_eq(
    n3_drain(":s :p \"x\"@en ."),
    "Pref(0,2) Pref(3,2) Lit(6,6)@10,2 Dot EOF",
  )
  // ^^dt 折文本不拆（物化层拆口径）
  assert_eq(
    n3_drain(":s :p \"x\"^^:dt ."),
    "Pref(0,2) Pref(3,2) Lit(6,8) Dot EOF",
  )
  // 内容含 @ 不误拆（尾段须 langtag 字符且 @ 前收引号）
  assert_eq(n3_drain(":s :p \"a@b\" ."), "Pref(0,2) Pref(3,2) Lit(6,5) Dot EOF")
  // 多子标签：lang 恰覆盖 en-GB
  assert_eq(
    n3_drain(":s :p \"x\"@en-GB ."),
    "Pref(0,2) Pref(3,2) Lit(6,9)@10,5 Dot EOF",
  )
  // 单引号字面量 + lang
  assert_eq(
    n3_drain(":s :p 'x'@en ."),
    "Pref(0,2) Pref(3,2) Lit(6,6)@10,2 Dot EOF",
  )
  // 空串 + lang
  assert_eq(
    n3_drain(":s :p \"\"@en ."),
    "Pref(0,2) Pref(3,2) Lit(6,5)@9,2 Dot EOF",
  )
  // 三引号：degradation 口径——close 落内容引号嫌疑不拆，整段折文本（物化层权威）
  assert_eq(
    n3_drain(":s :p \"\"\"x\"\"\"@en ."),
    "Pref(0,2) Pref(3,2) Lit(6,10) Dot EOF",
  )
  // Lexermoon 吞边界口径（词法自测 747 故意钉）：零空格后随 ,/. 该字节入 span
  // 且标点事件丢失；收引号锚定使 lang 照拆，span 修剪+事件合成归引擎层
  // normalize_term_span（Step 4，trig trim_trailing_dot 同款）
  assert_eq(
    n3_drain(":s :p \"x\"@en, :o ."),
    "Pref(0,2) Pref(3,2) Lit(6,7)@10,2 Pref(14,2) Dot EOF",
  )
  assert_eq(
    n3_drain(":s :p \"x\"@en."),
    "Pref(0,2) Pref(3,2) Lit(6,7)@10,2 EOF",
  )
}

///|
test "[] Anon 合并 + ( ) 集合 + bnode/TT" {
  assert_eq(n3_drain("[] :p [] ."), "Anon(0,2) Pref(3,2) Anon(6,2) Dot EOF")
  assert_eq(
    n3_drain("(1 2) :p :o ."),
    "Lparen(0,1) Lit(1,1) Lit(3,1) Rparen Pref(6,2) Pref(9,2) Dot EOF",
  )
  assert_eq(n3_drain("_:b :p :o ."), "Bnode(0,3) Pref(4,2) Pref(7,2) Dot EOF")
  assert_eq(
    n3_drain("<<:a :b :c>> :p :o ."),
    "TT(0,12) Pref(13,2) Pref(16,2) Dot EOF",
  )
}

///|
test "@ 指令族：prefix/base 零空格拆分槽 + 量化/关键词" {
  assert_eq(
    n3_drain("@prefix : <http://e/> ."),
    "@ PrefixKw Pref(8,1) Iri(10,11) Dot EOF",
  )
  // 零空格直连冒号拆分槽：@prefix:<iri> → PrefixKw + 冒号 PrefName 先入后兑
  assert_eq(
    n3_drain("@prefix:<http://e/> ."),
    "@ PrefixKw Pref(7,1) Iri(8,11) Dot EOF",
  )
  assert_eq(n3_drain("@base <http://e/> ."), "@ BaseKw Iri(6,11) Dot EOF")
  assert_eq(n3_drain("@forAll ?x."), "@ ForAllKw Var(8,2) Dot EOF")
  assert_eq(n3_drain("@forSome ?x."), "@ ForSomeKw Var(9,2) Dot EOF")
  assert_eq(n3_drain("@keywords a."), "@ KeywordsKw A(10,1) Dot EOF")
}

///|
test "is/of 事件化（役6）+ 垃圾降 Unknown" {
  // 裸 is/of 正牌事件（bare 无 span 位）；倒装接表见 engine_wbtest 役6 钉
  assert_eq(
    n3_drain("?x is :p of ?y ."),
    "Var(0,2) Is Pref(6,2) Of Var(12,2) Dot EOF",
  )
  // 无冒号垃圾词降 Unknown（bad-prefix-05 口径）
  assert_eq(n3_drain(":x foo :y ."), "Pref(0,2) Unk(3,3) Pref(7,2) Dot EOF")
  // ~ = RDF 1.2 reifier 引导符（正牌事件；表接 TildeEnd 驻留族）
  assert_eq(n3_drain(":a ~ :b ."), "Pref(0,2) Tilde Pref(5,2) Dot EOF")
}

///|
test "turtle 核回归 + EOF 单次枯竭" {
  assert_eq(
    n3_drain(":s :p 1.5e3, true; :q \"l\"@en, :o."),
    "Pref(0,2) Pref(3,2) Lit(6,5) Comma Lit(13,4) Semi Pref(19,2) Lit(22,7)@26,2 Pref(30,2) Dot EOF",
  )
  // EOF 合法送达一次，其后 None=枯竭（drain 到 None 不再出 EOF）
  let data = @utf8.encode(":s :p :o .").to_array()
  let adapter = N3LexerAdapter::new(data[:])
  let mut eof_count = 0
  let mut n = 0
  while n < 64 {
    n = n + 1
    match adapter.next() {
      None => break
      Some(ev) => if ev is N3Event::N3EOF { eof_count = eof_count + 1 }
    }
  }
  assert_eq(eof_count, 1)
}

///|
test "役5: @keywords 指令事件流——Unk/A 混列 + 逗号续（adapter 不发 KeywordX）" {
  // 裸词 foo 非关键词 → 降 Unknown（span = 词本身）；KeywordX 只由引擎
  // 归位点台账命中合成，adapter 事件面恒三词源直出
  assert_eq(
    n3_drain("@keywords foo, a ."),
    "@ KeywordsKw Unk(10,3) Comma A(15,1) Dot EOF",
  )
}
