// ===== 用户部分：TriG 物化器（表下游：span 四元组 → 可序列化 QuadEmit） =====
// 复用 @nquads 的 QuadEmit/Subject/Object/GraphName 模型与 Serializer 输出口；
// view 保真路线（与 nquads materialize_quad 同构：物化只搬运 + 标注）。
// 深验定案（2026-09-02"轻嗅探 + 按需深验"单遍化）：深验不再是 materialize_all
// 之后的第二遍扫描（旧 deep_validate_quad），而是按词项种类融进 materialize_quad
// 的路由点——每个 view 只在物化时验一次：
//   - IRI：scheme 嗅探绝对性（iri.mbt parse_scheme 同文法）+ validate_iri_body，
//     不再整段 @nquads.parse（旧口径 iri_term 判绝对性 + deep_check_iri 各 parse
//     一次 = 每 IRI 双整解，实测物化层瓶颈第一名）
//   - Literal：deep_check_literal（转义/langtag/banned datatype）在最终 view 上
//     验一次；数值/布尔展开为可信构造（is_numeric_span 词形 + 静态词表 IRI），跳过
//   - BNode：validate_bnode；TT 壳：deep_check_tt（项数+槽位种类）
//   - PrefName 展开：语法面校验（validate_prefname 同口径）折叠进 resolve_prefname，
//     账本查找单次——条件性跳过轻验（lenient parse）后，bad-pname 族由本层兜住
// 条件性跳过轻验配套：全链路入口（套件 runner / mat_chain）parse 传 lenient=true，
// 轻验只剩 parse-only 入口（trig_parser）承担；深验开关 deep_validate=false 时
// 所有融合校验全跳（纯改写照旧）。iri_term 的 <> 包裹守卫是轻验职责的落物化层
// 收口：包裹残缺不得落相对路径剥壳（否则 `<s>.` 被 base 修复成合法 IRI）。
// 错误全部进 materialize_all 的 errors 数组（逐 quad 收集，与 parse_all 同构）。
// trig 特有（nquads 语法没有，物化必须改写的项，落 arena 缓冲）：
//   - PrefName → 全 IRI（prefixes 账本 span 口径展开，含图名位）
//   - 谓词位 'a' 缩写 → rdf:type
//   - 数值（integer/decimal/double 三型）与 true/false → 带引号 typed literal
//   - "x"^^PrefName datatype → "x"^^<展开 IRI>（^^<IRI> 原样保真）
// 不变量：
//   - QuadEmit 的 view 或指原 data（未改写项，零拷贝）或指 arena（展开项）
//   - arena append-only：旧段内容永不改写，早先取出的 view 内容始终有效
//     （扩容换底层时旧数组不动，各 view 指向各自快照，序列化只读无碍）
//   - emits 生命周期 = 物化器生命周期（data 与 arena 都由物化器持有/借用）

///|
/// TriG 物化器：持数据视图 + 前缀账本 + @base 声明链 + 展开缓冲
///
/// prefixes 账本生命周期约定（2026-09-02 收口）：调用方在 parse_all 返回后传入
/// ctx.prefixes；物化期间保持只读，物化器借用不持有、不复制账本。
pub struct TrigMaterializer {
  data : ArrayView[Byte]
  prefixes : Array[(Span, Span)] // (name, iri) 声明账本（与 ctx.prefixes 同账本）
  bases : Array[Span] // ★1 @base 声明链（与 ctx.bases 同账本，append-only）
  base_fallback : String? // 外部 base（套件 runner 注入 test-URI 口径；doc @base 优先）
  scalar_only_escapes : Bool // RDF 1.2 方言开关：字面量 \u/\U 代理全禁（1.1 成对合法）
  mut fallback_parsed : @nquads.Iri? // 外部 fallback base 解析 memo（成功才记）
  base_memo : Map[Int, @nquads.Iri] // bver → 折叠后的生效 base（链前缀稳定，append-only）
  mut deep_validate : Bool // 深验融合开关（materialize_all 参数落位，materialize_quad 单入口读）
  fresh_ids : Map[Span, Span] // ★3 fresh 节点 memo：开括号全 span → arena 内 `_:genid<N>` span（链节点同 offset 不同长度，键含长度）
  arena : Array[Byte] // 展开字节缓冲（PrefName/'a'/数值/布尔/^^PrefName/相对 IRI 落这里）
}

///|
/// 构造：prefixes 传引擎 ctx.prefixes 的引用（同一账本，后声明覆盖先声明），
/// 生命周期由调用方保证：parse_all 返回之后传入、物化期间保持只读、借用不持有。
/// bases 传 ctx.bases（★1 base 链，同一账本）。物化器不再吃单槽 base——每条
/// quad 的生效 base 由其 bver 折叠链得出（中途换 base 不污染历史 quad）；
/// base_fallback 供无 @base 覆盖段（套件正例按 test-URI 解析相对 IRI）
pub fn TrigMaterializer::new(
  data : ArrayView[Byte],
  prefixes : Array[(Span, Span)],
  bases? : Array[Span] = [],
  base_fallback? : String? = None,
  scalar_only_escapes? : Bool = false,
) -> TrigMaterializer {
  {
    data,
    prefixes,
    bases,
    base_fallback,
    scalar_only_escapes,
    fallback_parsed: None,
    base_memo: Map::new(),
    deep_validate: true,
    fresh_ids: Map::new(),
    arena: [],
  }
}

///|
/// arena 写入辅助：字节 / 视图 / ASCII 串
fn TrigMaterializer::push_byte(self : TrigMaterializer, b : Byte) -> Unit {
  self.arena.push(b)
}

///|
fn TrigMaterializer::push_view(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> Unit {
  // blit 批量拷贝（自动扩容目标数组）：替代逐字节 push 的容量/越界逐次检查
  view.blit_to(self.arena, dst_offset=self.arena.length())
}

///|
fn TrigMaterializer::push_str(self : TrigMaterializer, s : String) -> Unit {
  for i in 0..<s.length() {
    self.arena.push(s[i].to_byte())
  }
}

///|
/// 词表 IRI 写入："<" + vocab iri + ">"（复用 @nquads vocab 的 NamedNodeRef）
fn TrigMaterializer::push_vocab(
  self : TrigMaterializer,
  nn : @nquads.NamedNodeRef,
) -> Unit {
  self.push_byte(b'<')
  for i in 0..<nn.iri.length() {
    self.arena.push(nn.iri[i].to_byte())
  }
  self.push_byte(b'>')
}

///|
/// PN_LOCAL_ESC 字符集（parser_slice validate_prefname 同口径，跨层双份：
/// 轻验层与展开层各一份，展开层这份在条件性跳过轻验时兜底 bad-pname 族）
fn is_pn_local_esc(e : Byte) -> Bool {
  e == b'_' ||
  e == b'~' ||
  e == b'.' ||
  e == b'-' ||
  e == b'!' ||
  e == b'$' ||
  e == b'&' ||
  e == b'\'' ||
  e == b'(' ||
  e == b')' ||
  e == b'*' ||
  e == b'+' ||
  e == b',' ||
  e == b';' ||
  e == b'=' ||
  e == b'/' ||
  e == b'?' ||
  e == b'#' ||
  e == b'@' ||
  e == b'%'
}

///|
/// scheme 嗅探（iri.mbt parse_scheme 同文法：is_scheme_char+ 后紧跟 ':'；
/// 本解析器口径数字可开头——嗅探必须与 @nquads.parse 路由等价，防分歧）
fn is_scheme_byte(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') ||
  (b >= b'A' && b <= b'Z') ||
  (b >= b'a' && b <= b'z') ||
  b == b'+' ||
  b == b'-' ||
  b == b'.'
}

///|
/// 对剥壳 IRI body（不含 <>）嗅探 scheme
fn view_has_scheme(view : ArrayView[Byte]) -> Bool {
  let len = view.length()
  let mut i = 0
  while i < len && is_scheme_byte(view[i]) {
    i = i + 1
  }
  i > 0 && i < len && view[i] == b':'
}

///|
/// 前缀名一次解析（2026-09-02 API 重构定案，消除"探测+展开"双账本查找）：
/// 语法面校验（validate_prefname 同口径）折叠在此——条件性跳过轻验后由本层
/// 兜住 bad-pname 族（前缀尾点/本地首字符/转义字符集，bad-pname-03 等桶）。
/// 返回 Some((声明 IRI span, 冒号位))；Ok(None) = 未声明（保真兜底口径）；
/// Err = 语法面非法。arena append-only 不可回滚：校验必须先于写 arena。
fn TrigMaterializer::resolve_prefname(
  self : TrigMaterializer,
  span : Span,
  pver : Int,
) -> Result[(Span, Int)?,  ParseError] {
  let (off, len) = span
  let mut colon = -1
  for i in 0..<len {
    if self.data[off + i] == b':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    return Ok(None) // 裸词：表外口径，保真兜底
  }
  // 前缀部尾点（PN_PREFIX 无尾点；bad-missing-ns-dot-end 口径）
  if colon > 0 && self.data[off + colon - 1] == b'.' {
    return Err(ParseError::ValidationErr("Prefix must not end with '.'"))
  }
  // 本地部首字符（PN_LOCAL 首字符集；bad-ln-dash-start 口径）
  if colon + 1 < len {
    let f = self.data[off + colon + 1]
    if f == b'.' || f == b'-' {
      return Err(
        ParseError::ValidationErr("Local name must not start with '.' or '-'"),
      )
    }
  }
  // 本地部 \X 转义字符集（bad-pname-03 口径：\u 非法）
  let mut i = colon + 1
  while i < len {
    let c = self.data[off + i]
    if c == b'\\' {
      if i + 1 >= len {
        return Err(ParseError::ValidationErr("Dangling escape"))
      }
      if !is_pn_local_esc(self.data[off + i + 1]) {
        return Err(ParseError::ValidationErr("Invalid PN_LOCAL_ESC escape"))
      }
      i = i + 2
    } else {
      i = i + 1
    }
  }
  // 账本查找（单次；从尾向前扫 = 后声明覆盖先声明；上界 pver = 发射时点账本长
  //——★1 per-quad 快照：重声明前的 quad 只见老声明，中途改写不污染历史）。
  // 声明 token 自带尾冒号（"ex:" / 空前缀 ":"），归一化剥掉再比；空前缀展开
  // IRI = DefaultPrefixIRI
  let plen = self.prefixes.length()
  let mut j = (if pver < plen { pver } else { plen }) - 1
  while j >= 0 {
    let (name, iri) = self.prefixes[j]
    let dn_len = if name.1 > 0 && self.data[name.0 + name.1 - 1] == b':' {
      name.1 - 1
    } else {
      name.1
    }
    if dn_len == colon {
      let mut same = true
      for k in 0..<colon {
        if self.data[off + k] != self.data[name.0 + k] {
          same = false
          break
        }
      }
      if same {
        return Ok(Some((iri, colon)))
      }
    }
    j = j - 1
  }
  Ok(None)
}

///|
/// 展开写入：`<` + 声明 IRI body + local（PN_LOCAL_ESC 解码，%HH 保真）+ `>`
/// 写进 arena，返回 arena 段 span。仅承接 resolve_prefname 的命中结果。
fn TrigMaterializer::write_prefname_iri(
  self : TrigMaterializer,
  span : Span,
  colon : Int,
  iri : Span,
) -> Span {
  let (off, len) = span
  let start = self.arena.length()
  self.push_byte(b'<')
  // 声明 IRI body：剥 <>（词法保证 <...> 形态，防御性再剥一次越界安全）
  if iri.1 >= 2 {
    self.push_view(self.data[iri.0 + 1:iri.0 + iri.1 - 1])
  }
  // local 部分：PN_LOCAL_ESC 解码（\X → X；百分号 %HH 保真——词法加宽批次定案：
  // 百分号序列按原样三字符进 IRI，不展开）
  let mut i = off + colon + 1
  let stop = off + len
  while i < stop {
    let c = self.data[i]
    if c == b'\\' && i + 1 < stop {
      self.arena.push(self.data[i + 1])
      i = i + 2
    } else {
      self.arena.push(c)
      i = i + 1
    }
  }
  self.push_byte(b'>')
  (start, self.arena.length() - start)
}

///|
/// PrefName 展开唯一入口（槽位口径）：语法校验+查找+解码一次完成。
/// Ok(None) = 未声明前缀（槽位按错误报）；Err = 语法面非法。
/// 相对展开收口（subm-01 口径）：相对前缀声明 IRI（`@prefix : <#>`）展开后
/// 仍是相对 IRI（`<#x>`），与词项位相对 IRI 同径——按 base 解析改写；
/// 绝对展开零改写直通（主路径零拷贝口径不变）
fn TrigMaterializer::expand_prefname(
  self : TrigMaterializer,
  span : Span,
  pver : Int,
  bver : Int,
) -> Result[Span?, ParseError] {
  match self.resolve_prefname(span, pver) {
    Err(e) => Err(e)
    Ok(None) => Ok(None)
    Ok(Some((iri, colon))) => {
      let raw = self.write_prefname_iri(span, colon, iri)
      let view = slice_span(self.arena[:], raw)
      if view_has_scheme(view[1:view.length() - 1]) {
        Ok(Some(raw))
      } else {
        // 相对展开：按该 quad 的生效 base（bver 折叠链 → fallback）解析
        let base_iri = match self.quad_base(bver) {
          Ok(b) => b
          Err(e) => return Err(e)
        }
        match base_iri.resolve(Bytes::from_array(view[1:view.length() - 1])[:]) {
          Ok(resolved) => {
            let start = self.arena.length()
            self.push_byte(b'<')
            self.push_str(resolved.into_string())
            self.push_byte(b'>')
            Ok(Some((start, self.arena.length() - start)))
          }
          Err(e) => Err(ParseError::ValidationErr("IRI resolution failed: \{e}"))
        }
      }
    }
  }
}

/// IRI 词项取值（"相对 IRI 解析在物化层"定案的落点）：
///   绝对 IRI → 原 data 零拷贝保真
///   相对 IRI + 有 base → iri.mbt resolve 展开（含 dot-segment 移除）进 arena
///   相对 IRI + 无 base → 报错（base-bad 桶口径；改写不受 deep_validate 门控——
///     这是物化语义而非验证，开关关也执行）
/// base 自身必须绝对（有 scheme），否则按无 base 论
fn TrigMaterializer::iri_term(
  self : TrigMaterializer,
  span : Span,
  bver : Int,
) -> Result[ArrayView[Byte], ParseError] {
  let view = slice_span(self.data, span)
  let len = view.length()
  // <> 包裹守卫（轻验职责的落物化层收口，条件性跳过轻验后由本层兜住）：
  // 包裹残缺不得落相对路径剥壳，否则 `<s>.` 的尾点残段会被 base 修复成合法 IRI。
  // `<>`（len==2 同文档引用）放行剥壳走相对路径
  if len < 2 || view[0] != b'<' || view[len - 1] != b'>' {
    return Err(ParseError::ValidationErr("IRI must be wrapped in <>"))
  }
  // 绝对性路由：scheme 嗅探（parse_scheme 同文法）替代整段 @nquads.parse
  //（旧口径每 IRI 双整解的瓶颈点；深验在槽位由 check_iri_view 融合执行）
  if view_has_scheme(view[1:len - 1]) {
    return Ok(view) // 绝对：零拷贝保真
  }
  // 相对：按该 quad 的生效 base（bver 折叠链 → fallback）解析
  let base_iri = match self.quad_base(bver) {
    Ok(b) => b
    Err(e) => return Err(e)
  }
  if base_iri.scheme.length() == 0 {
    return Err(ParseError::ValidationErr("@base must be absolute"))
  }
  match base_iri.resolve(Bytes::from_array(view[1:len - 1])[:]) {
    Ok(resolved) => {
      let start = self.arena.length()
      self.push_byte(b'<')
      self.push_str(resolved.into_string())
      self.push_byte(b'>')
      Ok(slice_span(self.arena[:], (start, self.arena.length() - start)))
    }
    Err(e) => Err(ParseError::ValidationErr("IRI resolution failed: \{e}"))
  }
}

///|
/// 外部 fallback base 解析（lazy 单次 memo，成功才记——坏 fallback 逐词项重报，
/// 与旧口径一致）
fn TrigMaterializer::fallback_base(
  self : TrigMaterializer,
) -> Result[@nquads.Iri?, ParseError] {
  match self.fallback_parsed {
    Some(b) => return Ok(Some(b))
    None => ()
  }
  match self.base_fallback {
    Some(s) =>
      match @nquads.parse(@utf8.encode(s)[:]) {
        Ok(bi) => {
          self.fallback_parsed = Some(bi)
          Ok(Some(bi))
        }
        Err(e) => Err(ParseError::ValidationErr("Bad fallback base: \{e}"))
      }
    None => Ok(None)
  }
}

///|
/// ★1 per-quad base：按 bver 折叠 base 链（bases[0..bver]）——绝对 @base 重置
/// 累计值，相对 @base 对累计值（链空落 fallback）按 RFC 3986 5.2 合并（Turtle 1.1
/// 口径：@base 自身按在 scope base 解析，subm-27 链式依赖此语义）。链 append-only
/// → 前缀稳定，bver 为键 memo。Err = 链上有坏声明（不 memo，逐 quad 重报）；
/// Ok(None) = 该 quad 无生效 @base（bver=0，调用方落 fallback_base 口径）
fn TrigMaterializer::base_at(
  self : TrigMaterializer,
  bver : Int,
) -> Result[@nquads.Iri?, ParseError] {
  if bver == 0 {
    return Ok(None)
  }
  match self.base_memo.get(bver) {
    Some(b) => return Ok(Some(b))
    None => ()
  }
  let mut acc : @nquads.Iri? = None
  for i in 0..<bver {
    let sp = self.bases[i]
    let view = slice_span(self.data, sp)
    let blen = view.length()
    if blen < 3 || view[0] != b'<' || view[blen - 1] != b'>' {
      return Err(ParseError::ValidationErr("Bad @base IRI"))
    }
    let body = view[1:blen - 1]
    if view_has_scheme(body) {
      match @nquads.parse(Bytes::from_array(body)[:]) {
        Ok(bi) => acc = Some(bi)
        Err(e) => return Err(ParseError::ValidationErr("Bad @base IRI: \{e}"))
      }
    } else {
      let prev = match acc {
        Some(a) => Some(a)
        None =>
          match self.fallback_base() {
            Ok(b) => b
            Err(e) => return Err(e)
          }
      }
      match prev {
        Some(a) =>
          match a.resolve(Bytes::from_array(body)[:]) {
            Ok(r) => acc = Some(r)
            Err(e) =>
              return Err(ParseError::ValidationErr("IRI resolution failed: \{e}"))
          }
        None =>
          return Err(
            ParseError::ValidationErr("Relative @base with no in-scope base"),
          )
      }
    }
  }
  match acc {
    Some(b) => {
      self.base_memo[bver] = b
      Ok(Some(b))
    }
    None => Ok(None)
  }
}

///|
/// 该 quad 的生效 base（bver 链折叠 → fallback）；两者皆无则 Err——相对词项
/// 无处解析。结果恒绝对（链项经 scheme 嗅探 + parse，fallback 解析自带 scheme）
fn TrigMaterializer::quad_base(
  self : TrigMaterializer,
  bver : Int,
) -> Result[@nquads.Iri, ParseError] {
  let b = match self.base_at(bver) {
    Ok(b) => b
    Err(e) => return Err(e)
  }
  match b {
    Some(b) => Ok(b)
    None =>
      match self.fallback_base() {
        Ok(Some(b)) => Ok(b)
        Ok(None) =>
          Err(ParseError::ValidationErr("Relative IRI with no in-scope @base"))
        Err(e) => Err(e)
      }
  }
}

///|
/// 数值 span 的 datatype 裁决（原文保真，归一化在 eval 阶段）：
/// 含 e/E → double；含 . → decimal；否则 integer
fn TrigMaterializer::expand_number(
  self : TrigMaterializer,
  span : Span,
) -> Span {
  let view = slice_span(self.data, span)
  let mut has_dot = false
  let mut has_exp = false
  for b in view {
    if b == b'.' {
      has_dot = true
    } else if b == b'e' || b == b'E' {
      has_exp = true
    }
  }
  let dt = if has_exp {
    @nquads.rdf_double
  } else if has_dot {
    @nquads.rdf_decimal
  } else {
    @nquads.rdf_integer
  }
  // "数值原文"^^<datatype>
  let start = self.arena.length()
  self.push_byte(b'"')
  self.push_view(view)
  self.push_byte(b'"')
  self.push_str("^^")
  self.push_vocab(dt)
  (start, self.arena.length() - start)
}

///|
/// true/false → "true"^^<xsd:boolean>
fn TrigMaterializer::expand_boolean(
  self : TrigMaterializer,
  span : Span,
) -> Span {
  let view = slice_span(self.data, span)
  let start = self.arena.length()
  self.push_byte(b'"')
  self.push_view(view)
  self.push_byte(b'"')
  self.push_str("^^")
  self.push_vocab(@nquads.rdf_boolean)
  (start, self.arena.length() - start)
}

///|
/// 字面量闭引号位置：返回引号体结束（闭引号后一字节）的偏移。
/// 三引号/单引号配对、反斜杠转义感知；找不到返回 span 末尾（防御，词法已配对）
fn literal_body_end(data : ArrayView[Byte], span : Span) -> Int {
  let (off, len) = span
  let q = data[off]
  if off + 2 < off + len && data[off + 1] == q && data[off + 2] == q {
    // 三引号长串：扫配对 """
    let mut i = off + 3
    while i + 2 < off + len {
      if data[i] == q && data[i + 1] == q && data[i + 2] == q {
        return i + 3
      }
      if data[i] == b'\\' {
        i = i + 2
      } else {
        i = i + 1
      }
    }
    return off + len // 防御路径也须返回绝对偏移（off>0 时 len 是错位）
  }
  // 单引号串
  let mut i = off + 1
  while i < off + len {
    if data[i] == b'\\' {
      i = i + 2
      continue
    }
    if data[i] == q {
      return i + 1
    }
    i = i + 1
  }
  off + len // 同上：绝对偏移
}

///|
/// 字面量物化：引号体 + 后缀（@lang / ^^dt）。
///   - 无后缀 / @lang / ^^<IRI> → span 原样零拷贝（N-Quads 同构，字节保真）
///   - ^^PrefName → 引号体原样 + ^^<展开 IRI>（arena 改写）
///   - 三引号长串 → 原样回写（N-Quads 1.1 无此语法，规范化转正在深验阶段）
/// Result 化（2026-09-02 单遍口径）：^^PrefName 语法面非法在此拒绝（条件性
/// 跳过轻验后流到这里）；未声明前缀零拷贝保真兜底——槽位深验 deep_check_literal
/// 对最终 view 拒（dt 非 <IRI> 形即拒），与旧深验口径一致
fn TrigMaterializer::materialize_literal(
  self : TrigMaterializer,
  span : Span,
  pver : Int,
) -> Result[ArrayView[Byte], ParseError] {
  let (off, len) = span
  let body_end = literal_body_end(self.data, span)
  if body_end + 2 < off + len &&
    self.data[body_end] == b'^' &&
    self.data[body_end + 1] == b'^' &&
    self.data[body_end + 2] != b'<' {
    let dt_span : Span = (body_end + 2, off + len - (body_end + 2))
    match self.resolve_prefname(dt_span, pver) {
      Err(e) => Err(e)
      Ok(None) => Ok(slice_span(self.data, span)) // 未声明：保真兜底，槽位深验拒
      Ok(Some((iri, colon))) => {
        let start = self.arena.length()
        self.push_view(self.data[off:body_end])
        self.push_byte(b'^')
        self.push_byte(b'^')
        let _ = self.write_prefname_iri(dt_span, colon, iri) // 展开追加 arena 尾
        Ok(slice_span(self.arena[:], (start, self.arena.length() - start)))
      }
    }
  } else {
    Ok(slice_span(self.data, span)) // 保真路径：原 data 零拷贝
  }
}

///|
/// 物化单个 quad：span 四元组 → QuadEmit（PrefName 展开等改写项落 arena）
pub fn TrigMaterializer::materialize_quad(
  self : TrigMaterializer,
  quad : QuadSpan,
) -> Result[@nquads.QuadEmit, ParseError] {
  // 主语位：Iri / BNode / TT 壳 / PrefName。融合深验（deep_validate 门）在词项
  // 构造点就地执行：Iri→check_iri_view / BNode→validate_bnode / TT 壳→deep_check_tt
  // （独立成句的壳已在组装层拆成普通槽位，此臂承接"壳+后续链"形态）
  let subject : @nquads.Subject = if quad.s.1 == 0 {
    // rdf:nil 标记（Span(open.0, 0)，长度 0 = 无字节词项）：合成词表 IRI，可信免深验
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_nil)
    @nquads.Subject::Iri(slice_span(self.arena[:], (start, self.arena.length() - start)))
  } else {
    let c0 = self.data[quad.s.0]
    if c0 == b'<' {
      if quad.s.1 >= 4 && self.data[quad.s.0 + 1] == b'<' {
        // RDF 1.2 引用三元组壳做主语：整段原文持有，字节保真（同宾语位口径）
        let v = slice_span(self.data, quad.s)
        match self.gate_tt(v) {
          Ok(v) => @nquads.Subject::TripleTerm(v)
          Err(e) => return Err(e)
        }
      } else {
        match self.iri_term(quad.s, quad.bver) {
          Ok(v) =>
            match self.gate_iri(v) {
              Ok(v) => @nquads.Subject::Iri(v)
              Err(e) => return Err(e)
            }
          Err(e) => return Err(e)
        }
      }
    } else if c0 == b'_' {
      let v = slice_span(self.data, quad.s)
      match self.gate_bnode(v) {
        Ok(v) => @nquads.Subject::BNode(v)
        Err(e) => return Err(e)
      }
    } else if c0 == b'[' || c0 == b'(' {
      // ★3 fresh 结构节点：开括号 offset memo `_:genid<N>`，可信构造免深验
      @nquads.Subject::BNode(self.fresh_bnode(quad.s))
    } else {
      match self.expand_prefname(quad.s, quad.pver, quad.bver) {
        Ok(Some(expanded)) =>
          match self.gate_iri(slice_span(self.arena[:], expanded)) {
            Ok(v) => @nquads.Subject::Iri(v)
            Err(e) => return Err(e)
          }
        Ok(None) =>
          return Err(ParseError::ValidationErr("Subject has undeclared prefix"))
        Err(e) => return Err(e)
      }
    }
  }
  // 谓词位：'a' 缩写 → rdf:type；全 IRI 零拷贝；其余 PrefName 展开（谓词只许这三类）
  let predicate : ArrayView[Byte] = if quad.pk is PredKind::RDFFirst {
    // 集合链合成谓词 rdf:first（词表构造可信，免深验）
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_first)
    slice_span(self.arena[:], (start, self.arena.length() - start))
  } else if quad.pk is PredKind::RDFRest {
    // 集合链合成谓词 rdf:rest
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_rest)
    slice_span(self.arena[:], (start, self.arena.length() - start))
  } else if quad.p.1 == 1 &&
    self.data[quad.p.0] == b'a' {
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_type)
    let pspan = (start, self.arena.length() - start)
    slice_span(self.arena[:], pspan) // 词表构造可信，免深验
  } else if self.data[quad.p.0] == b'<' {
    match self.iri_term(quad.p, quad.bver) {
      Ok(v) =>
        match self.gate_iri(v) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      Err(e) => return Err(e)
    }
  } else {
    match self.expand_prefname(quad.p, quad.pver, quad.bver) {
      Ok(Some(expanded)) =>
        match self.gate_iri(slice_span(self.arena[:], expanded)) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      Ok(None) =>
        return Err(ParseError::ValidationErr("Predicate has undeclared prefix"))
      Err(e) => return Err(e)
    }
  }
  // 宾语位：Iri / BNode / Literal（保真或 ^^ 展开）/ 数值 / 布尔 / PrefName / TT。
  // 数值分支用 is_numeric_span 全词形裁决：lenient 放行的"数字开头非数值串"
  // 不得被 expand_number 静默吞成 typed literal，落 PrefName 臂报错
  let object : @nquads.Object = if quad.o.1 == 0 {
    // rdf:nil 标记（空集合宾位）：合成词表 IRI，可信免深验
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_nil)
    @nquads.Object::Iri(slice_span(self.arena[:], (start, self.arena.length() - start)))
  } else {
    let c0 = self.data[quad.o.0]
    let is_num = (
        c0 == b'+' || c0 == b'-' || c0 == b'.' || (c0 >= b'0' && c0 <= b'9')
      ) &&
      is_numeric_span(self.data, quad.o.0, quad.o.1)
    if c0 == b'<' {
      if quad.o.1 > 1 && self.data[quad.o.0 + 1] == b'<' {
        // 引用三元组壳：整段原文持有，字节保真；壳内 term-kind 深验就地执行
        let v = slice_span(self.data, quad.o)
        match self.gate_tt(v) {
          Ok(v) => @nquads.Object::TripleTerm(v)
          Err(e) => return Err(e)
        }
      } else {
        match self.iri_term(quad.o, quad.bver) {
          Ok(v) =>
            match self.gate_iri(v) {
              Ok(v) => @nquads.Object::Iri(v)
              Err(e) => return Err(e)
            }
          Err(e) => return Err(e)
        }
      }
    } else if c0 == b'_' {
      let v = slice_span(self.data, quad.o)
      match self.gate_bnode(v) {
        Ok(v) => @nquads.Object::BNode(v)
        Err(e) => return Err(e)
      }
    } else if c0 == b'[' || c0 == b'(' {
      // ★3 fresh 结构节点：开括号 offset memo `_:genid<N>`，可信构造免深验
      @nquads.Object::BNode(self.fresh_bnode(quad.o))
    } else if c0 == b'"' || c0 == b'\'' {
      match self.materialize_literal(quad.o, quad.pver) {
        Ok(v) =>
          match self.gate_literal(v) {
            Ok(v) => @nquads.Object::Literal(v)
            Err(e) => return Err(e)
          }
        Err(e) => return Err(e)
      }
    } else if is_num {
      // 数值族：词形已由 is_numeric_span 全验，展开为可信构造，免深验
      // 注意：先展开、后取 arena 视图——内联写 slice_span(self.arena[:], self.expand_…)
      // 会因实参求值序先建旧视图，展开追加后越界被 slice_span 钳成空视图
      let nspan = self.expand_number(quad.o)
      @nquads.Object::Literal(slice_span(self.arena[:], nspan))
    } else if quad.o.1 == 4 && self.bool_at(quad.o, "true") {
      let bspan = self.expand_boolean(quad.o)
      @nquads.Object::Literal(slice_span(self.arena[:], bspan)) // 静态词可信，免深验
    } else if quad.o.1 == 5 && self.bool_at(quad.o, "false") {
      let bspan = self.expand_boolean(quad.o)
      @nquads.Object::Literal(slice_span(self.arena[:], bspan)) // 静态词可信，免深验
    } else {
      match self.expand_prefname(quad.o, quad.pver, quad.bver) {
        Ok(Some(expanded)) =>
          match self.gate_iri(slice_span(self.arena[:], expanded)) {
            Ok(v) => @nquads.Object::Iri(v)
            Err(e) => return Err(e)
          }
        Ok(None) =>
          return Err(ParseError::ValidationErr("Object has undeclared prefix"))
        Err(e) => return Err(e)
      }
    }
  }
  // 图名位：Iri / BNode / PrefName 展开（TriG 图名可为前缀名）
  let graph : @nquads.GraphName = match quad.g {
    None => @nquads.GraphName::None
    Some(g) => {
      let c0 = self.data[g.0]
      if c0 == b'<' {
        match self.iri_term(g, quad.bver) {
          Ok(v) =>
            match self.gate_iri(v) {
              Ok(v) => @nquads.GraphName::Iri(v)
              Err(e) => return Err(e)
            }
          Err(e) => return Err(e)
        }
      } else if c0 == b'_' {
        let v = slice_span(self.data, g)
        match self.gate_bnode(v) {
          Ok(v) => @nquads.GraphName::BNode(v)
          Err(e) => return Err(e)
        }
      } else if c0 == b'[' || c0 == b'(' {
        // ★3 fresh 结构节点（图名位不可为 fresh——表保证图名位只有 Iri/PrefName/
        // BlankNode 三事件；防御位照接）
        @nquads.GraphName::BNode(self.fresh_bnode(g))
      } else {
        match self.expand_prefname(g, quad.pver, quad.bver) {
          Ok(Some(expanded)) =>
            match self.gate_iri(slice_span(self.arena[:], expanded)) {
              Ok(v) => @nquads.GraphName::Iri(v)
              Err(e) => return Err(e)
            }
          Ok(None) =>
            return Err(
              ParseError::ValidationErr("Graph name has undeclared prefix"),
            )
          Err(e) => return Err(e)
        }
      }
    }
  }
  Ok({ subject, predicate, object, graph, })
}

///|
/// 布尔词比对（span 原字节 vs ASCII 串，零分配）
fn TrigMaterializer::bool_at(
  self : TrigMaterializer,
  span : Span,
  word : String,
) -> Bool {
  if span.1 != word.length() {
    return false
  }
  for i in 0..<word.length() {
    if self.data[span.0 + i] != word[i].to_byte() {
      return false
    }
  }
  true
}

///|
/// 批量物化：逐条搬运，错误逐条收集（与 parse_all 同口径）。
/// deep_validate（默认开）：物化后逐 quad 深验（iri.mbt / langtag.mbt /
/// literal.mbt 口径），不合格项不进 results——流到序列化层的 emit 全部合法
pub fn TrigMaterializer::materialize_all(
  self : TrigMaterializer,
  quads : Array[QuadSpan],
  deep_validate? : Bool = true,
) -> (Array[@nquads.QuadEmit], Array[ParseError]) {
  self.deep_validate = deep_validate
  let results : Array[@nquads.QuadEmit] = []
  let errors : Array[ParseError] = []
  for quad in quads {
    match self.materialize_quad(quad) {
      Ok(q) => results.push(q)
      Err(e) => errors.push(e)
    }
  }
  (results, errors)
}

// ============================================================
// 深度验证（物化层深验门，"表层面无法拒，是物化层职责"定案的落点）
// ------------------------------------------------------------
// 2026-09-02 单遍口径：校验器不再整批后扫，而是经 gate_iri/gate_bnode/gate_tt/
// gate_literal 四门在 materialize_quad 词项构造点就地执行（本文档区只留校验器本体）。
// 语义深验复用模块（不写新轮子）：
//   - IRI 绝对性：scheme 嗅探（iri.mbt parse_scheme 同文法）+ validate_iri_body。
//     相对 IRI 已由 iri_term 在物化层按 @base resolve 改写（改写不受 deep_validate
//     门控），无 scheme 即拒（防御）
//   - @nquads.LanguageTag::parse（langtag.mbt）：@lang 全量 RFC 5646（字节版
//     词法挡不住的 extlang 超限等在此拦下）；RDF 1.2 方向后缀 --ltr/--rtl
//     （小写精确）拆出后验基础标签
//   - literal.mbt 强类型口径：^^<IRI> datatype 分类——rdf:langString /
//     rdf:dirLangString 禁显式使用（is_banned_langstring_iri），xsd:string
//     只验不改（序列化保字节保真）
// 字节级沿用 nquads validate_helper 的 pub 跨包原语（doc 注释即为此定）：
//   scan_string_body（转义序列 + 闭引号）/ validate_escapes_unicode（scalar_only：代理全禁）/
//   validate_bnode / validate_iri_body（禁字符 + UCHAR）
// 三引号长串：接受（原样回写；规范化为单引号转义仍待后续，不在此拒）
// ============================================================

///|
/// 深验 IRI 词项（`<...>` 形态 view）
fn check_iri_view(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let len = view.length()
  if len < 3 || view[0] != b'<' || view[len - 1] != b'>' {
    return Err(ParseError::ValidationErr("IRI must be wrapped in <>"))
  }
  // 绝对性：scheme 嗅探（iri.mbt parse_scheme 同文法）替代整段 @nquads.parse。
  // 相对 IRI 已由 iri_term 按 base 改写，无 scheme 即拒（防御臂）
  if !view_has_scheme(view[1:len - 1]) {
    return Err(ParseError::ValidationErr("Relative IRI not allowed"))
  }
  // 禁字符 / UCHAR 转义（内容区 [1, len-1)，闭 '>' 由约定排除）
  match @nquads.validate_iri_body(view, 0, 1, len) {
    Ok(_) => ()
    Err(e) => return Err(ParseError::ValidationErr("Bad IRI: \{e}"))
  }
  Ok(())
}

///|
/// 深验 bnode 词项（view 口径，融合单遍）
fn check_bnode_view(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  match @nquads.validate_bnode(view, 0) {
    Ok(_) => ()
    Err(e) => return Err(ParseError::ValidationErr("Bad blank node: \{e}"))
  }
  Ok(())
}

///|
/// 深验融合门（deep_validate 开时校验，关时直通；成功原样返还 view）
fn TrigMaterializer::gate_iri(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> Result[ArrayView[Byte], ParseError] {
  if self.deep_validate {
    match check_iri_view(view) {
      Ok(_) => Ok(view)
      Err(e) => Err(e)
    }
  } else {
    Ok(view)
  }
}

///|
fn TrigMaterializer::gate_bnode(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> Result[ArrayView[Byte], ParseError] {
  if self.deep_validate {
    match check_bnode_view(view) {
      Ok(_) => Ok(view)
      Err(e) => Err(e)
    }
  } else {
    Ok(view)
  }
}

///|
fn TrigMaterializer::gate_tt(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> Result[ArrayView[Byte], ParseError] {
  if self.deep_validate {
    match deep_check_tt(view) {
      Ok(_) => Ok(view)
      Err(e) => Err(e)
    }
  } else {
    Ok(view)
  }
}

///|
fn TrigMaterializer::gate_literal(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> Result[ArrayView[Byte], ParseError] {
  if self.deep_validate {
    match deep_check_literal(view, self.scalar_only_escapes) {
      Ok(_) => Ok(view)
      Err(e) => Err(e)
    }
  } else {
    Ok(view)
  }
}

///|
/// 深验字面量词项（引号体 + 可选 @lang / ^^dt 后缀）
fn deep_check_literal(
  view : ArrayView[Byte],
  scalar_only : Bool,
) -> Result[Unit, ParseError] {
  let len = view.length()
  if len < 2 {
    return Err(ParseError::ValidationErr("Literal too short"))
  }
  let q = view[0]
  if q != b'"' && q != b'\'' {
    return Err(ParseError::ValidationErr("Literal must start with a quote"))
  }
  let quote_run = if len >= 3 && view[1] == q && view[2] == q { 3 } else { 1 }
  // 引号体：转义序列合法性 + 闭引号定位（bad-esc / bad-string 桶）
  // scan_string_body 贪左返回首个 quote_run 连续引号；三引号串体内紧邻闭定界的
  // 未转义内容引号（`""""` = 内容 `"` + 闭 `"""`，LITERAL_LONG2 口径）使连跑
  // 长于 quote_run——闭定界向右扩到连跑尽头，取"末尾 quote_run 个"
  let close0 = match @nquads.scan_string_body(view, 0, quote_run, quote_run) {
    Ok(pos) => pos
    Err(e) => return Err(ParseError::ValidationErr("Bad literal body: \{e}"))
  }
  let mut close = close0
  if quote_run == 3 {
    while close + 3 < len && view[close + 3] == q {
      close = close + 1
    }
  }
  // W3C bad-string-06/07 口径：闭壳连跑被右扩（连跑长于 quote_run = `""""` 悬空
  // 引号歧义按内容引号吞并）且紧跟 @lang / ^^dt 后缀 → 非法——官方按贪左闭壳，
  // 悬空引号破坏后续语法（`"""abc""""@en` 负例）。无后缀时扩并合法
  //（turtle LITERAL_LONG2 `"""test-\\""""` 正例：扩过后恰无后缀）
  if close > close0 && close + quote_run < len {
    return Err(ParseError::ValidationErr("Malformed literal suffix"))
  }
  // \u/\U 孤代理（surrogate 桶）
  // scalar_only（RDF 1.2 方言开关）：代理一律拒，成对也不收（surrogate-pair-bad
  // 口径）；1.1 宽容口径成对合法（test-38 正例 \ud801\udc69 编 SMP），按装配层注入
  match
    @nquads.validate_escapes_unicode(view, 0, quote_run, close, scalar_only~) {
    Ok(_) => ()
    Err(e) => return Err(ParseError::ValidationErr("Bad literal escape: \{e}"))
  }
  let at = close + quote_run
  if at >= len {
    return Ok(()) // 无后缀：simple literal
  }
  if view[at] == b'@' {
    // langtag.mbt 全量 RFC 5646；RDF 1.2 方向后缀（小写精确）拆出后验基础标签
    let tag_str = @utf8.decode_lossy(Bytes::from_array(view[at + 1:len]))
    let base_tag = if tag_str.has_suffix("--ltr") || tag_str.has_suffix("--rtl") {
      tag_str[:tag_str.length() - 5]
    } else {
      tag_str[:]
    }
    match @nquads.LanguageTag::parse(base_tag) {
      Ok(_) => ()
      Err(e) => return Err(ParseError::ValidationErr("Bad language tag: \{e}"))
    }
    return Ok(())
  }
  if view[at] == b'^' && at + 1 < len && view[at + 1] == b'^' {
    let dt = view[at + 2:len]
    if dt.length() > 1 && dt[0] == b'<' {
      // banned datatype（rdf:langString / rdf:dirLangString 不可显式使用）
      if @nquads.is_banned_langstring_iri(dt) {
        return Err(
          ParseError::ValidationErr(
            "rdf:langString / rdf:dirLangString must not be used as explicit datatype",
          ),
        )
      }
      check_iri_view(dt)
    } else {
      // ^^PrefName 泄漏兜底（组装层应已展开或拒绝）
      Err(ParseError::ValidationErr("Literal datatype must be an IRI"))
    }
  } else {
    Err(ParseError::ValidationErr("Malformed literal suffix"))
  }
}

///|
/// 布尔词零分配比对（span 原字节 vs ASCII 串）
fn tt_bool_word(v : ArrayView[Byte], word : String) -> Bool {
  if v.length() != word.length() {
    return false
  }
  for i in 0..<word.length() {
    if v[i] != word[i].to_byte() {
      return false
    }
  }
  true
}

///|
/// 深验引用三元组壳（term-kind 核验，nt-ttl12-bad-syntax / trig12-syntax-bad-02
/// 桶口径）：结构（项数=3、壳配对）parse 层已验；这里核验三个槽位的词项种类
///   主语：Iri / BNode / 嵌套 TT / PrefName——字面量·数值·布尔不可作主语
///   谓词：Iri / PrefName（'a' 缩写属 verb 糖，壳内 rt 产生式不适用；其余全拒）
///   宾语：全种类合法（含嵌套 TT / 字面量 / 数值 / 布尔），无需拒项
/// 壳内 PrefName/相对 IRI 保持原文（壳整段保真不改写，深验只按首字节分类）
fn deep_check_tt(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let len = view.length()
  if len < 5 ||
    view[0] != b'<' ||
    view[1] != b'<' ||
    view[len - 1] != b'>' ||
    view[len - 2] != b'>' {
    return Err(ParseError::ValidationErr("Malformed triple-term shell"))
  }
  let terms = triple_term_inner_terms(view, (0, len))
  if terms.length() != 3 {
    return Err(
      ParseError::ValidationErr("Triple term must have exactly 3 terms"),
    )
  }
  // 主语位：字面量族（引号 / 数值首字节 / true/false）拒绝；嵌套壳递归
  let s = slice_span(view, terms[0])
  if s.length() > 0 {
    let c0 = s[0]
    if c0 == b'"' ||
      c0 == b'\'' ||
      c0 == b'.' ||
      c0 == b'+' ||
      c0 == b'-' ||
      (c0 >= b'0' && c0 <= b'9') ||
      tt_bool_word(s, "true") ||
      tt_bool_word(s, "false") {
      return Err(
        ParseError::ValidationErr("Triple term subject must not be a literal"),
      )
    }
  }
  if s.length() >= 2 && s[0] == b'<' && s[1] == b'<' {
    match deep_check_tt(s) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  // 谓词位：IRI 直过；嵌套壳 / bnode（_: 也含冒号，须显式排除）拒；其余须 PrefName 形
  let p = slice_span(view, terms[1])
  let p_ok = if p.length() >= 2 && p[0] == b'<' && p[1] == b'<' {
    false
  } else if p.length() > 0 && p[0] == b'<' {
    true
  } else if p.length() >= 2 && p[0] == b'_' && p[1] == b':' {
    false
  } else {
    let mut has_colon = false
    for b in p {
      if b == b':' {
        has_colon = true
        break
      }
    }
    has_colon
  }
  if !p_ok {
    return Err(
      ParseError::ValidationErr("Triple term predicate must be an IRI"),
    )
  }
  // 宾语位：全种类合法，仅嵌套壳递归
  let o = slice_span(view, terms[2])
  if o.length() >= 2 && o[0] == b'<' && o[1] == b'<' {
    match deep_check_tt(o) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  Ok(())
}

// ===== 物化器测试辅助（包内私有；inline test 直接可见） =====

///|
fn mat_bytes(input : String) -> Array[Byte] {
  @utf8.encode(input).to_array()
}

///|
/// view → String（与序列化器同口径：decode_lossy，严禁逐字节 to_char 拼多字节）
fn mat_vs(v : ArrayView[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(v))
}

///|
/// 全链路：解析 → 物化。data 由本函数持有（view 生命周期 = 调用方作用域）
fn mat_chain(input : String) -> (Array[@nquads.QuadEmit], Array[ParseError]) {
  let data = mat_bytes(input)
  let engine = TrigEngine::from_bytes(data)
  let sec = data[:]
  let slice = TrigSliceParser::new(engine, sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  if errors.length() > 0 {
    return ([], errors)
  }
  let mat = TrigMaterializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  mat.materialize_all(quads)
}

///|
let mat_empty : Array[Byte] = []

///|
/// 枚举载荷抽取（断言用）：变体不符返回空视图，断言自然爆
fn mat_subj(e : @nquads.QuadEmit) -> ArrayView[Byte] {
  match e.subject {
    Iri(v) => v
    BNode(v) => v
    PrefName(v) => v
    _ => mat_empty[:]
  }
}

///|
fn mat_obj(e : @nquads.QuadEmit) -> ArrayView[Byte] {
  match e.object {
    Iri(v) => v
    BNode(v) => v
    Literal(v) => v
    TripleTerm(v) => v
    PrefName(v) => v
  }
}

///|
fn mat_graph(e : @nquads.QuadEmit) -> ArrayView[Byte] {
  match e.graph {
    Iri(v) => v
    BNode(v) => v
    None => mat_empty[:]
  }
}

///|
/// 判定图名位是否为默认图（None 变体）
fn mat_has_graph(e : @nquads.QuadEmit) -> Bool {
  match e.graph {
    None => false
    _ => true
  }
}

///|
test "物化: PrefName/DefaultPrefixIRI/图名 均展开为全 IRI" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\n@prefix : <http://dft/> .\nex:s ex:p ex:o .\n:s2 :p2 :o2 .\nex:g { ex:s3 ex:p3 ex:o3 . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  // quad1：ex:s ex:p ex:o（默认图）
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://example/s>")
  assert_eq(mat_vs(emits[0].predicate), "<http://example/p>")
  assert_eq(mat_vs(mat_obj(emits[0])), "<http://example/o>")
  assert_false(mat_has_graph(emits[0]))
  // quad2：DefaultPrefixIRI 展开 :s2 :p2 :o2
  assert_eq(mat_vs(mat_subj(emits[1])), "<http://dft/s2>")
  assert_eq(mat_vs(emits[1].predicate), "<http://dft/p2>")
  // quad3：图块区图名 ex:g 展开
  assert_eq(mat_vs(mat_graph(emits[2])), "<http://example/g>")
  assert_eq(mat_vs(mat_subj(emits[2])), "<http://example/s3>")
}

///|
test "物化: 'a' 缩写 → rdf:type，数值三型与布尔 → typed literal" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s a ex:C .\nex:n ex:i 42 ; ex:d 1.5 ; ex:x 1.0e3 ; ex:b true, false .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 6)
  // ex:s a ex:C → 谓词 = rdf:type
  assert_eq(
    mat_vs(emits[0].predicate),
    "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>",
  )
  // 数值三型 + 布尔（第 2..6 条，pred/obj 成对）
  let expect : Array[(String, String)] = [
    ("<http://example/i>", "\"42\"^^<http://www.w3.org/2001/XMLSchema#integer>"),
    (
      "<http://example/d>", "\"1.5\"^^<http://www.w3.org/2001/XMLSchema#decimal>",
    ),
    (
      "<http://example/x>", "\"1.0e3\"^^<http://www.w3.org/2001/XMLSchema#double>",
    ),
    (
      "<http://example/b>", "\"true\"^^<http://www.w3.org/2001/XMLSchema#boolean>",
    ),
    (
      "<http://example/b>", "\"false\"^^<http://www.w3.org/2001/XMLSchema#boolean>",
    ),
  ]
  for i in 0..<expect.length() {
    let (p, o) = expect[i]
    assert_eq(mat_vs(emits[i + 1].predicate), p)
    assert_eq(mat_vs(mat_obj(emits[i + 1])), o)
  }
}

///|
test "物化: 字面量后缀 —— @lang 保真 / ^^PrefName 展开 / ^^<IRI> 保真" {
  let (emits, errors) = mat_chain(
    "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n@prefix ex: <http://example/> .\nex:s ex:p \"lit\"@en-US .\nex:s ex:p \"x\"^^xsd:int .\nex:s ex:p \"y\"^^<http://d.example/dt> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 3)
  assert_eq(mat_vs(mat_obj(emits[0])), "\"lit\"@en-US")
  assert_eq(
    mat_vs(mat_obj(emits[1])),
    "\"x\"^^<http://www.w3.org/2001/XMLSchema#int>",
  )
  assert_eq(mat_vs(mat_obj(emits[2])), "\"y\"^^<http://d.example/dt>")
}

///|
test "物化: 引用三元组壳整段保真 + bnode 图名零拷贝" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\nex:s ex:p << <http://a> <http://b> <http://c> >> .\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_obj(emits[0])), "<< <http://a> <http://b> <http://c> >>")
}

///|
test "物化: bnode 图名块" {
  let (emits, errors) = mat_chain(
    "@prefix ex: <http://example/> .\n_:b { ex:s2 ex:p2 ex:o2 . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 1)
  assert_eq(mat_vs(mat_graph(emits[0])), "_:b")
}

///|
test "物化: 全链路 → nquads Serializer(format=Quad) 输出" {
  let data = mat_bytes(
    "@prefix ex: <http://example/> .\nex:s ex:p ex:o .\nex:s ex:i 42 .\n",
  )
  let engine = TrigEngine::from_bytes(data)
  let sec = data[:]
  let slice = TrigSliceParser::new(engine, sec, lenient=true)
  let (quads, errors) = slice.parse_all()
  assert_eq(errors.length(), 0)
  let mat = TrigMaterializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
  )
  let (emits, merrs) = mat.materialize_all(quads)
  assert_eq(merrs.length(), 0)
  let ser = @nquads.Serializer::new(format=@nquads.SerializeFormat::Quad)
  match ser.serialize_all(emits) {
    Ok(out) =>
      assert_eq(
        out, "<http://example/s> <http://example/p> <http://example/o> .\n<http://example/s> <http://example/i> \"42\"^^<http://www.w3.org/2001/XMLSchema#integer> .\n",
      )
    Err(e) => {
      debug("serialize error: \{e}")
      assert_false(true)
    }
  }
}

///|
/// 分层链路：(emits, 深验错误, 解析错误)——pin 深验层：parse 层零错、深验层报错
fn mat_chain_deep(
  input : String,
  deep : Bool,
  scalar_only? : Bool = false,
) -> (Array[@nquads.QuadEmit], Array[ParseError], Array[ParseError]) {
  let data = mat_bytes(input)
  let engine = TrigEngine::from_bytes(data)
  let sec = data[:]
  let slice = TrigSliceParser::new(engine, sec, lenient=true)
  let (quads, perrs) = slice.parse_all()
  if perrs.length() > 0 {
    return ([], [], perrs)
  }
  let mat = TrigMaterializer::new(
    sec,
    slice.engine.ctx.prefixes,
    bases=slice.engine.ctx.bases,
    scalar_only_escapes=scalar_only,
  )
  let (emits, merrs) = mat.materialize_all(quads, deep_validate=deep)
  (emits, merrs, [])
}

///|
test "深验: 默认开——langtag/相对IRI/banned datatype/孤代理 全部进 errors" {
  // 1) langtag.mbt 拦字节版词法放行的标签（extlang 超限）
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@ab-abc-abc-abc-abc .\n", true,
  )
  assert_eq(p1.length(), 0) // 表层面（字节版）放行
  assert_eq(e1.length(), 0) // 不流到序列化
  assert_eq(m1.length(), 1)
  // 2) 相对 IRI 无 base：物化层 iri_term 直接拒（改写不受开关门控，base-bad 桶口径）
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <relative/path> .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(e2.length(), 0)
  assert_eq(m2.length(), 1)
  // 3) banned datatype：rdf:langString 禁显式使用
  let (e3, m3, p3) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#langString> .\n",
    true,
  )
  assert_eq(p3.length(), 0)
  assert_eq(e3.length(), 0)
  assert_eq(m3.length(), 1)
  // 4) 孤代理转义（surrogate 桶）
  let (e4, m4, p4) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"a\\uDC00b\" .\n", true,
  )
  assert_eq(p4.length(), 0)
  assert_eq(e4.length(), 0)
  assert_eq(m4.length(), 1)
}

///|
test "@base: 相对 IRI 四位改写（路径合并 / 同文档引用 / dot-segment / 图名位）" {
  let (emits, errors) = mat_chain(
    "@base <http://ex.org/a/b> .\n@prefix ex: <http://example/> .\n<rel> <p> <#frag> .\n<g> { ex:s ex:p <../c> . }\n",
  )
  assert_eq(errors.length(), 0)
  assert_eq(emits.length(), 2)
  // 主语位 <rel>：路径合并 /a/b + rel → /a/rel（RFC 3986 5.2.2）
  assert_eq(mat_vs(mat_subj(emits[0])), "<http://ex.org/a/rel>")
  // 谓词位 <p> → /a/p
  assert_eq(mat_vs(emits[0].predicate), "<http://ex.org/a/p>")
  // 宾语位 <#frag>：同文档引用 → 继承 base 路径 /a/b + #frag
  assert_eq(mat_vs(mat_obj(emits[0])), "<http://ex.org/a/b#frag>")
  // 图名位 <g> → /a/g
  assert_eq(mat_vs(mat_graph(emits[1])), "<http://ex.org/a/g>")
  // <../c>：合并 /a/../c → dot-segment 移除 → /c（宾语位）
  assert_eq(mat_vs(mat_obj(emits[1])), "<http://ex.org/c>")
  // PrefName 词项不受 base 影响（零拷贝展开口径不变）
  assert_eq(mat_vs(mat_subj(emits[1])), "<http://example/s>")
}

///|
test "@base: 无 base 相对 IRI 物化层直接拒（开关关也拒——改写非验证）" {
  // 开关开：错误来自 materialize_quad 的改写路径（深验门未及）
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <rel> .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 开关关：仍拒——iri_term 是物化语义，不受 deep_validate 门控
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <rel> .\n", false,
  )
  assert_eq(p2.length(), 0)
  assert_eq(e2.length(), 0)
  assert_eq(m2.length(), 1)
}

///|
test "@base: 绝对 base 必要 + 相对 base 拒绝" {
  // 相对 @base 自身（无 scheme）→ 按无 base 论，报错
  let (e1, m1, p1) = mat_chain_deep(
    "@base <relbase> .\n<rel> <p> <o> .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 绝对词项不受 base 影响：零拷贝原样
  let (e2, m2, p2) = mat_chain_deep(
    "@base <http://ex.org/a/b> .\n<http://abs.org/x> <http://abs.org/p> <http://abs.org/o> .\n",
    true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
  assert_eq(mat_vs(mat_subj(e2[0])), "<http://abs.org/x>")
}

///|
test "深验: TT 壳内 term-kind —— 数字主语拒 / 字面量谓词拒 / 合法形态保真" {
  // 1) 数字主语（trig12-syntax-bad-02 同款：三项齐全，仅深验门可拦）
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <<3 ex:b ex:c >> .\n", true,
  )
  assert_eq(p1.length(), 0) // parse 层三项齐全放行
  assert_eq(e1.length(), 0) // 不流到序列化
  assert_eq(m1.length(), 1) // 深验门拦下
  // 2) 字面量作谓词
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << ex:a \"lit\" ex:c >> .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(e2.length(), 0)
  assert_eq(m2.length(), 1)
  // 3) bnode 作谓词
  let (e3, m3, p3) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << ex:a _:b ex:c >> .\n", true,
  )
  assert_eq(p3.length(), 0)
  assert_eq(e3.length(), 0)
  assert_eq(m3.length(), 1)
  // 4) 合法形态：壳内字面量宾语 + 布尔谓词位外的全部种类放行，壳整段保真
  let (e4, m4, p4) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << ex:a ex:b \"lit\" >> .\n", true,
  )
  assert_eq(p4.length(), 0)
  assert_eq(m4.length(), 0)
  assert_eq(e4.length(), 1)
  assert_eq(mat_vs(mat_obj(e4[0])), "<< ex:a ex:b \"lit\" >>")
  // 5) 嵌套壳：合法递归放行 / 内层数字谓词递归拒
  let (e5, m5, p5) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << << ex:a ex:b ex:c >> ex:p2 ex:o2 >> .\n",
    true,
  )
  assert_eq(p5.length(), 0)
  assert_eq(m5.length(), 0)
  assert_eq(e5.length(), 1)
  let (e6, m6, p6) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p << << ex:a 3 ex:c >> ex:p2 ex:o2 >> .\n",
    true,
  )
  assert_eq(p6.length(), 0)
  assert_eq(e6.length(), 0)
  assert_eq(m6.length(), 1)
}

///|
test "深验: deep_validate=false 穿透 + 方向后缀合法放行 / 大写方向拒" {
  // 开关关：同一输入直通
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@ab-abc-abc-abc-abc .\n", false,
  )
  assert_eq(p1.length(), 0)
  assert_eq(m1.length(), 0)
  assert_eq(e1.length(), 1)
  // RDF 1.2 方向后缀：拆 --rtl 后基础标签合法 → 放行
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@ar--rtl .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
  // 方向后缀大写非法（小写精确）
  let (e3, m3, p3) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"x\"@en--LTR .\n", true,
  )
  assert_eq(p3.length(), 0)
  assert_eq(e3.length(), 0)
  assert_eq(m3.length(), 1)
}

///|
test "词法加宽: PN_LOCAL_ESC 解码 / 百分号保真 / 内部点与尾点回退 / 多字节" {
  let pre = "@prefix : <http://www.w3.org/2013/TurtleTests/> .\n"
  // 1) 转义族整段解码（pname-esc-01 同款）：\X → X 进 IRI
  let (e1, m1, p1) = mat_chain_deep(pre + ":s :p :\\~\\.\\-\\! .\n", true)
  assert_eq(p1.length(), 0)
  assert_eq(m1.length(), 0)
  assert_eq(e1.length(), 1)
  assert_eq(mat_vs(mat_obj(e1[0])), "<http://www.w3.org/2013/TurtleTests/~.-!>")
  // 2) 百分号对保真（%25 起始 / %3E 中部，syntax-prefix-04/09 同款）
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix : <http://a.example/>.\n:%25 <http://a.example/p> :a%3Eb .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
  assert_eq(mat_vs(mat_subj(e2[0])), "<http://a.example/%25>")
  assert_eq(mat_vs(mat_obj(e2[0])), "<http://a.example/a%3Eb>")
  // 3) 内部点 + 尾点回退（ln-dots 同款）：:o..2. → local "o..2" + 语句点
  let (e3, m3, p3) = mat_chain_deep(pre + ":s..2 :p..2 :o..2.\n", true)
  assert_eq(p3.length(), 0)
  assert_eq(m3.length(), 0)
  assert_eq(e3.length(), 1)
  assert_eq(
    mat_vs(mat_subj(e3[0])),
    "<http://www.w3.org/2013/TurtleTests/s..2>",
  )
  assert_eq(mat_vs(mat_obj(e3[0])), "<http://www.w3.org/2013/TurtleTests/o..2>")
  // 4) 前缀名含内部点（ns-dots 同款）
  let (e4, m4, p4) = mat_chain_deep(
    "@prefix e.g: <http://www.w3.org/2013/TurtleTests/> .\ne.g:s e.g:p e.g:o .\n",
    true,
  )
  assert_eq(p4.length(), 0)
  assert_eq(m4.length(), 0)
  assert_eq(e4.length(), 1)
  assert_eq(mat_vs(mat_subj(e4[0])), "<http://www.w3.org/2013/TurtleTests/s>")
  // 5) 多字节非首字符扩展（non_leading_extras 同款）+ 数字首 local
  let (e5, m5, p5) = mat_chain_deep(
    "@prefix p: <http://a.example/>.\np:a·̀ͯ‿.⁀ <http://a.example/p> p:3.s .\n",
    true,
  )
  assert_eq(p5.length(), 0)
  assert_eq(m5.length(), 0)
  assert_eq(e5.length(), 1)
  assert_eq(mat_vs(mat_subj(e5[0])), "<http://a.example/a·̀ͯ‿.⁀>")
  assert_eq(mat_vs(mat_obj(e5[0])), "<http://a.example/3.s>")
}

///|
test "深验: 长串扩跑+后缀拒（bad-string-06）/ 无后缀扩并放行（LITERAL_LONG2）" {
  // 扩跑且紧跟 @lang 后缀 → 深验拒
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"\"\"abc\"\"\"\"@en .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 同形态无后缀：贪右闭壳扩并恰无后缀 → 放行（turtle LITERAL_LONG2 14B 正例口径）
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p \"\"\"test-\\\"\"\"\" .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
}

///|
test "深验: IRI 转义解码码点——代理/禁字符拒（good escape, bad character）" {
  // \uDC00 代理码点
  let (e1, m1, p1) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <http://example/\\uDC00> .\n", true,
  )
  assert_eq(p1.length(), 0)
  assert_eq(m1.length(), 1)
  // \u0022 解码为 `"`（IRI 禁字符）
  let (e2, m2, p2) = mat_chain_deep(
    "@prefix ex: <http://example/> .\nex:s ex:p <http://example/\\u0022> .\n", true,
  )
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 1)
}

///|
test "深验: scalar_only 方言开关——1.2 成对代理拒 / 1.1 成对合法（test-38 口径）" {
  let lit = "@prefix ex: <http://example/> .\nex:s ex:p \"\\uD83C\\uDCA1\" .\n"
  // 开关开（RDF 1.2）：成对代理也拒——每个 UCHAR 须独立为标量值
  let (e1, m1, p1) = mat_chain_deep(lit, true, scalar_only=true)
  assert_eq(p1.length(), 0)
  assert_eq(e1.length(), 0)
  assert_eq(m1.length(), 1)
  // 开关关（1.1 宽容）：成对合法放行（孤代理仍拒）
  let (e2, m2, p2) = mat_chain_deep(lit, true)
  assert_eq(p2.length(), 0)
  assert_eq(m2.length(), 0)
  assert_eq(e2.length(), 1)
}

///|
/// ★3 fresh 结构节点展开：`[`/`(` 开括号 token 的 offset 即 fresh 身份，
/// memo 出 `_:genid{offset}`（arena 只写一次，同 offset 零重写；可信构造免深验）。
/// W3C 套件比对是图同构——标签只需文档内一致，且与用户 `_:x` 空间天然隔离
fn TrigMaterializer::fresh_bnode(
  self : TrigMaterializer,
  span : Span,
) -> ArrayView[Byte] {
  // 键 = 全 span (offset, length)：集合链节点共享 `(` 的 offset，只按 offset 键会互撞
  match self.fresh_ids.get(span) {
    Some(memo) => return slice_span(self.arena[:], memo)
    None => ()
  }
  let start = self.arena.length()
  self.push_byte(b'_')
  self.push_byte(b':')
  if slice_span(self.data, span).length() > 0 && self.data[span.0] == b'(' {
    // 集合链节点：长度承载序号（span.1 = k+1），标签 `_:genid{off}n{k}`
    self.push_str("genid\{span.0}n\{span.1 - 1}")
  } else {
    // `[]` fresh bnode：标签 `_:genid{off}`
    self.push_str("genid\{span.0}")
  }
  let memo = (start, self.arena.length() - start)
  self.fresh_ids[span] = memo
  slice_span(self.arena[:], memo)
}
