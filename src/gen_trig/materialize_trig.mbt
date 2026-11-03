// ===== 装配层补充（Assembly）：TriG 物化器（表下游：span 四元组 → 可序列化 QuadEmit） =====
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
  rdf12 : Bool // **语法版本开关**（对齐 nquads 口径）：true = RDF 1.2（方向后缀 `--ltr/--rtl` 放行；转义代理全禁），false = 1.1 严格契约（方向后缀拒；转义成对合法）
  mut fallback_parsed : @nquads.Iri? // 外部 fallback base 解析 memo（成功才记）
  base_memo : Map[Int32, @nquads.Iri] // base_version → 折叠后的生效 base（链前缀稳定，append-only）
  mut deep_validate : Bool // 深验融合开关（materialize_all 参数落位，materialize_quad 单入口读）
  fresh_ids : Map[Span, Span] // ★3 fresh 节点 memo：开括号全 span → arena 内 `_:genid<N>` span（链节点同 offset 不同长度，键含长度）
  arena : Array[Byte] // 展开字节缓冲（PrefName/'a'/数值/布尔/^^PrefName/相对 IRI 落这里）
}

///|
/// 构造：prefixes 传引擎 ctx.prefixes 的引用（同一账本，后声明覆盖先声明），
/// 生命周期由调用方保证：parse_all 返回之后传入、物化期间保持只读、借用不持有。
/// bases 传 ctx.bases（★1 base 链，同一账本）。物化器不再吃单槽 base——每条
/// quad 的生效 base 由其 base_version 折叠链得出（中途换 base 不污染历史 quad）；
/// base_fallback 供无 @base 覆盖段（套件正例按 test-URI 解析相对 IRI）
pub fn TrigMaterializer::new(
  data : ArrayView[Byte],
  prefixes : Array[(Span, Span)],
  bases~ : Array[Span] = [],
  base_fallback~ : String? = None,
  rdf12~ : Bool = true,
) -> TrigMaterializer {
  {
    data,
    prefixes,
    bases,
    base_fallback,
    rdf12,
    fallback_parsed: None,
    base_memo: Map([]),
    deep_validate: true,
    fresh_ids: Map([]),
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
/// 前缀名一次解析（2026-09-02 API 重构定案，消除"探测+展开"双账本查找）：
/// 语法面校验（validate_prefname 同口径）折叠在此——条件性跳过轻验后由本层
/// 兜住 bad-pname 族（前缀尾点/本地首字符/转义字符集，bad-pname-03 等桶）。
/// 返回 Some((声明 IRI span, 冒号位))；Ok(None) = 未声明（保真兜底口径）；
/// Err = 语法面非法。arena append-only 不可回滚：校验必须先于写 arena。
fn TrigMaterializer::resolve_prefname(
  self : TrigMaterializer,
  span : Span,
  prefix_version : Int32,
) -> (Span, Int32)? raise ParseError {
  let (off, len) = span
  let mut colon = -1
  for i in 0..<len {
    if self.data[off + i] == b':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    // 役35 **35-B1**（R-T13/C-T13，照 n3v2 `resolve_prefname` 同源）：**无冒号裸名按
    // 空前缀展开**（n3 `DefaultPrefixIRI` 径）——listed 词与 `a` 失格降名都在此出账。
    // 默认（空）前缀**未声明**时下方账本查找落空 ⇒ 仍 `Ok(None)`（槽位错误面口径不变）。
    colon = 0
  }
  // 前缀部尾点（PN_PREFIX 无尾点；bad-missing-ns-dot-end 口径）
  if colon > 0 && self.data[off + colon - 1] == b'.' {
    raise ParseError::ValidationErr("Prefix must not end with '.'")
  }
  // 本地部首字符（PN_LOCAL 首字符集；bad-ln-dash-start 口径）
  if colon + 1 < len {
    let f = self.data[off + colon + 1]
    if f == b'.' || f == b'-' {
      raise ParseError::ValidationErr(
        "Local name must not start with '.' or '-'",
      )
    }
  }
  // 本地部 \X 转义字符集（bad-pname-03 口径：\u 非法）
  let mut i = colon + 1
  while i < len {
    let c = self.data[off + i]
    if c == b'\\' {
      if i + 1 >= len {
        raise ParseError::ValidationErr("Dangling escape")
      }
      if !is_pn_local_esc(self.data[off + i + 1]) {
        raise ParseError::ValidationErr("Invalid PN_LOCAL_ESC escape")
      }
      i = i + 2
    } else {
      i = i + 1
    }
  }
  // 账本查找（单次；从尾向前扫 = 后声明覆盖先声明；上界 prefix_version = 发射时点账本长
  //——★1 per-quad 快照：重声明前的 quad 只见老声明，中途改写不污染历史）。
  // 声明 token 自带尾冒号（"ex:" / 空前缀 ":"），归一化剥掉再比；空前缀展开
  // IRI = DefaultPrefixIRI
  let plen = self.prefixes.length()
  let mut j = (if prefix_version < plen { prefix_version } else { plen }) - 1
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
        return Some((iri, colon))
      }
    }
    j = j - 1
  }
  None
}

///|
/// 展开写入：`<` + 声明 IRI body + local（PN_LOCAL_ESC 解码，%HH 保真）+ `>`
/// 写进 arena，返回 arena 段 span。仅承接 resolve_prefname 的命中结果。
fn TrigMaterializer::write_prefname_iri(
  self : TrigMaterializer,
  span : Span,
  colon : Int32,
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
  // 百分号序列按原样三字符进 IRI，不展开）。colon 位有冒号字符则本地部从 colon+1 起，
  // 否则 = 35-B1 无冒号裸词（colon 归零哨兵），**整词即本地部**（n3v2 逐字同源）
  let mut i = if off + colon < off + len && self.data[off + colon] == b':' {
    off + colon + 1
  } else {
    off + colon
  }
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
  prefix_version : Int32,
  base_version : Int32,
) -> Span? raise ParseError {
  match self.resolve_prefname(span, prefix_version) {
    None => None
    Some((iri, colon)) => {
      let raw = self.write_prefname_iri(span, colon, iri)
      let view = slice_span(self.arena[:], raw)
      if view_has_scheme(view[1:view.length() - 1]) {
        Some(raw)
      } else {
        // 相对展开：按该 quad 的生效 base（base_version 折叠链 → fallback）解析
        let base_iri = self.quad_base(base_version)
        let resolved = base_iri.resolve(
          Bytes::from_array(view[1:view.length() - 1])[:],
        )
        let start = self.arena.length()
        self.push_byte(b'<')
        self.push_str(resolved.into_string())
        self.push_byte(b'>')
        Some((start, self.arena.length() - start))
      }
    }
  }
}

///|
/// IRI 词项取值（"相对 IRI 解析在物化层"定案的落点）：
///   绝对 IRI → 原 data 零拷贝保真
///   相对 IRI + 有 base → iri.mbt resolve 展开（含 dot-segment 移除）进 arena
///   相对 IRI + 无 base → 报错（base-bad 桶口径；改写不受 deep_validate 门控——
///     这是物化语义而非验证，开关关也执行）
/// base 自身必须绝对（有 scheme），否则按无 base 论
fn TrigMaterializer::iri_term(
  self : TrigMaterializer,
  span : Span,
  base_version : Int32,
) -> ArrayView[Byte] raise ParseError {
  let view = slice_span(self.data, span)
  let len = view.length()
  // <> 包裹守卫（轻验职责的落物化层收口，条件性跳过轻验后由本层兜住）：
  // 包裹残缺不得落相对路径剥壳，否则 `<s>.` 的尾点残段会被 base 修复成合法 IRI。
  // `<>`（len==2 同文档引用）放行剥壳走相对路径
  if len < 2 || view[0] != b'<' || view[len - 1] != b'>' {
    raise ParseError::ValidationErr("IRI must be wrapped in <>")
  }
  // 绝对性路由：scheme 嗅探（parse_scheme 同文法）替代整段 @nquads.parse
  //（旧口径每 IRI 双整解的瓶颈点；深验在槽位由 check_iri_view 融合执行）
  if view_has_scheme(view[1:len - 1]) {
    return view // 绝对：零拷贝保真
  }
  // 相对：按该 quad 的生效 base（base_version 折叠链 → fallback）解析
  let base_iri = self.quad_base(base_version)
  if base_iri.scheme.length() == 0 {
    raise ParseError::ValidationErr("@base must be absolute")
  }
  let resolved = base_iri.resolve(Bytes::from_array(view[1:len - 1])[:])
  let start = self.arena.length()
  self.push_byte(b'<')
  self.push_str(resolved.into_string())
  self.push_byte(b'>')
  slice_span(self.arena[:], (start, self.arena.length() - start))
}

///|
/// 外部 fallback base 解析（lazy 单次 memo，成功才记——坏 fallback 逐词项重报，
/// 与旧口径一致）
fn TrigMaterializer::fallback_base(self : TrigMaterializer) -> @nquads.Iri? {
  match self.fallback_parsed {
    Some(b) => return Some(b)
    None => ()
  }
  match self.base_fallback {
    Some(s) => {
      let bi = @nquads.parse(@utf8.encode(s)[:])
      self.fallback_parsed = Some(bi)
      Some(bi)
    }
    None => None
  }
}

///|
/// ★1 per-quad base：按 base_version 折叠 base 链（bases[0..base_version]）——绝对 @base 重置
/// 累计值，相对 @base 对累计值（链空落 fallback）按 RFC 3986 5.2 合并（Turtle 1.1
/// 口径：@base 自身按在 scope base 解析，subm-27 链式依赖此语义）。链 append-only
/// → 前缀稳定，base_version 为键 memo。Err = 链上有坏声明（不 memo，逐 quad 重报）；
/// Ok(None) = 该 quad 无生效 @base（base_version=0，调用方落 fallback_base 口径）
fn TrigMaterializer::base_at(
  self : TrigMaterializer,
  base_version : Int32,
) -> @nquads.Iri? raise ParseError {
  if base_version == 0 {
    return None
  }
  match self.base_memo.get(base_version) {
    Some(b) => return Some(b)
    None => ()
  }
  let mut acc : @nquads.Iri? = None
  for i in 0..<base_version {
    let sp = self.bases[i]
    let view = slice_span(self.data, sp)
    let blen = view.length()
    if blen < 3 || view[0] != b'<' || view[blen - 1] != b'>' {
      raise ParseError::ValidationErr("Bad @base IRI")
    }
    let body = view[1:blen - 1]
    if view_has_scheme(body) {
      let bi = @nquads.parse(Bytes::from_array(body)[:])
      acc = Some(bi)
    } else {
      let prev = match acc {
        Some(a) => Some(a)
        None => self.fallback_base()
      }
      match prev {
        Some(a) => {
          let r = a.resolve(Bytes::from_array(body)[:])
          acc = Some(r)
        }
        None =>
          raise ParseError::ValidationErr(
            "Relative @base with no in-scope base",
          )
      }
    }
  }
  match acc {
    Some(b) => {
      self.base_memo[base_version] = b
      Some(b)
    }
    None => None
  }
}

///|
/// 该 quad 的生效 base（base_version 链折叠 → fallback）；两者皆无则 Err——相对词项
/// 无处解析。结果恒绝对（链项经 scheme 嗅探 + parse，fallback 解析自带 scheme）
fn TrigMaterializer::quad_base(
  self : TrigMaterializer,
  base_version : Int32,
) -> @nquads.Iri raise ParseError {
  let b = self.base_at(base_version)
  let fb = match b {
    Some(b) => Some(b)
    None => self.fallback_base()
  }
  match fb {
    Some(b) => b
    None =>
      raise ParseError::ValidationErr("Relative IRI with no in-scope @base")
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
  prefix_version : Int32,
) -> ArrayView[Byte] raise ParseError {
  let (off, len) = span
  let body_end = literal_body_end(self.data, span)
  if body_end + 2 < off + len &&
    self.data[body_end] == b'^' &&
    self.data[body_end + 1] == b'^' &&
    self.data[body_end + 2] != b'<' {
    let dt_span : Span = (body_end + 2, off + len - (body_end + 2))
    match self.resolve_prefname(dt_span, prefix_version) {
      None => slice_span(self.data, span) // 未声明：保真兜底，槽位深验拒
      Some((iri, colon)) => {
        let start = self.arena.length()
        self.push_view(self.data[off:body_end])
        self.push_byte(b'^')
        self.push_byte(b'^')
        let _ = self.write_prefname_iri(dt_span, colon, iri) // 展开追加 arena 尾
        slice_span(self.arena[:], (start, self.arena.length() - start))
      }
    }
  } else {
    slice_span(self.data, span) // 保真路径：原 data 零拷贝
  }
}

///|
/// 物化单个 quad：span 四元组 → QuadEmit 行数组（U3a 官方律：壳语句追加
/// reifies 行）。主语位三臂：
///   · subj_shell（注解壳行）→ R = fresh_bnode(锚 span memo，同锚多行同 R)，
///     主语换 R + 追加 (R, rdf:reifies, tt(展开三成分))；
///   · 裸壳 `<< s p o [~ r] >>` 词项 → R = 显式 reifier 展开-or-fresh(壳 span memo)，
///     主语换 R + 追加 reifies 行（官方判：bare 壳不自断言）；
///   · 括号壳 `<<( s p o )>>` 词项 → 剥壳展开重编（词项本尊，无 reifies 行）。
pub fn TrigMaterializer::materialize_quad(
  self : TrigMaterializer,
  quad : QuadSpan,
) -> Array[@nquads.QuadEmit] raise ParseError {
  // 追加 reifies 行的挂账（R kind, R view, tt view）——图名位物化后统一造行
  let shell_rows : Array[(@nquads.TermKind, ArrayView[Byte], ArrayView[Byte])] = []
  // 主语位：Iri / BNode / TT 壳 / PrefName。融合深验（deep_validate 门）在词项
  // 构造点就地执行：Iri→check_iri_view / BNode→validate_bnode / TT 壳→deep_check_tt
  // （独立成句的壳已在组装层拆成普通槽位，此臂承接"壳+后续链"形态）。
  // P3 平化：kind+view 直挂，链臂就地赋值（mut + 虚初值——MoonBit 无延后初始化；
  // 各臂必赋值，避免元组装箱）
  let mut s_kind : @nquads.TermKind = @nquads.TermKind::Iri
  let mut s_view : ArrayView[Byte] = self.data[0:0]
  if quad.subj_shell {
    // U3a 官方律：注解壳行 = R + reifies 行（锚行由锚 quad 自身断言，只断言一次）
    let (c1, c2, c3, reif) = self.scan_shell_parts(
      quad.s.0,
      quad.s.0 + quad.s.1,
    )
    let _ = reif // 注解壳行不带 reifier（~ 链 = U3b 组装层接）
    let r_view = self.fresh_bnode(quad.s) // 锚 span 全键 memo：同锚多注解行同 R
    let tt_view = self.compose_shell_tt(
      c1,
      c2,
      c3,
      quad.prefix_version,
      quad.base_version,
    )
    shell_rows.push((@nquads.TermKind::BNode, r_view, tt_view))
    s_kind = @nquads.TermKind::BNode
    s_view = r_view
  } else if self.is_shell_span(quad.s) {
    // 裸壳/括号壳做主语（rt 族：s span = 全壳文本，~ 内嵌）
    let paren = self.data[quad.s.0 + 2] == b'('
    if paren {
      let (c1, c2, c3, _) = self.scan_shell_parts(
        quad.s.0 + 3,
        quad.s.0 + quad.s.1 - 3,
      )
      s_kind = @nquads.TermKind::TripleTerm
      s_view = self.compose_shell_tt(
        c1,
        c2,
        c3,
        quad.prefix_version,
        quad.base_version,
      )
    } else {
      let (r_kind, r_view, tt_view) = self.shell_reifier_flow(
        quad.s,
        quad.prefix_version,
        quad.base_version,
      )
      shell_rows.push((r_kind, r_view, tt_view))
      s_kind = r_kind
      s_view = r_view
    }
  } else if quad.s.1 == 0 {
    // rdf:nil 标记（Span(open.0, 0)，长度 0 = 无字节词项）：合成词表 IRI，可信免深验
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_nil)
    s_kind = @nquads.TermKind::Iri
    s_view = slice_span(self.arena[:], (start, self.arena.length() - start))
  } else {
    let c0 = self.data[quad.s.0]
    if c0 == b'<' {
      if quad.s.1 >= 4 && self.data[quad.s.0 + 1] == b'<' {
        // RDF 1.2 引用三元组壳做主语：整段原文持有，字节保真（同宾语位面）
        let v = slice_span(self.data, quad.s)
        let v = self.gate_tt(v)
        s_kind = @nquads.TermKind::TripleTerm
        s_view = v
      } else {
        let v = self.iri_term(quad.s, quad.base_version)
        let v = self.gate_iri(v)
        s_kind = @nquads.TermKind::Iri
        s_view = v
      }
    } else if c0 == b'_' {
      let v = slice_span(self.data, quad.s)
      let v = self.gate_bnode(v)
      s_kind = @nquads.TermKind::BNode
      s_view = v
    } else if c0 == b'[' || c0 == b'(' {
      // ★3 fresh 结构节点：开括号 offset memo `_:genid<N>`，可信构造免深验
      s_kind = @nquads.TermKind::BNode
      s_view = self.fresh_bnode(quad.s)
    } else {
      let hit = self.expand_prefname(
        quad.s,
        quad.prefix_version,
        quad.base_version,
      )
      match hit {
        Some(expanded) => {
          let v = self.gate_iri(slice_span(self.arena[:], expanded))
          s_kind = @nquads.TermKind::Iri
          s_view = v
        }
        None => raise ParseError::ValidationErr("Subject has undeclared prefix")
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
  } else if quad.pk is PredKind::KwA {
    // 役35 A1（R-T13/C-T13）：**判据载体 = `pk`**（原先按载荷文本 `p.1==1 && data=='a'` 判，
    // 属"决策漂在物化层"——(Ⅱ) 形态）。**语义决策与判据同层**：谓词位 `a` 是否仍为
    // turtle `rdf:type` 简写，由引擎在**表管谓词态**下记入 `pk`（`KwA` = 保留）；
    // N3 档 `@keywords` 已受理后引擎把事件改写为 `PrefName` 且不置 `KwA` ⇒ 走下方 PrefName 展开。
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_type)
    let pspan = (start, self.arena.length() - start)
    slice_span(self.arena[:], pspan) // 词表构造可信，免深验
  } else if self.data[quad.p.0] == b'<' {
    let v = self.iri_term(quad.p, quad.base_version)
    self.gate_iri(v)
  } else {
    let hit = self.expand_prefname(
      quad.p,
      quad.prefix_version,
      quad.base_version,
    )
    match hit {
      Some(expanded) => self.gate_iri(slice_span(self.arena[:], expanded))
      None => raise ParseError::ValidationErr("Predicate has undeclared prefix")
    }
  }
  // 宾语位：Iri / BNode / Literal（保真或 ^^ 展开）/ 数值 / 布尔 / PrefName / TT。
  // 数值分支用 is_numeric_span 全词形裁决：lenient 放行的"数字开头非数值串"
  // 不得被 expand_number 静默吞成 typed literal，落 PrefName 臂报错。
  // P3 平化：同主语链，mut + 虚初值就地赋值
  let mut o_kind : @nquads.TermKind = @nquads.TermKind::Iri
  let mut o_view : ArrayView[Byte] = self.data[0:0]
  if quad.o.1 == 0 {
    // rdf:nil 标记（空集合宾位）：合成词表 IRI，可信免深验
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_nil)
    o_kind = @nquads.TermKind::Iri
    o_view = slice_span(self.arena[:], (start, self.arena.length() - start))
  } else {
    let c0 = self.data[quad.o.0]
    let is_num = (
        c0 == b'+' || c0 == b'-' || c0 == b'.' || (c0 >= b'0' && c0 <= b'9')
      ) &&
      @nquads.is_numeric_span(self.data, quad.o.0, quad.o.1)
    if self.is_shell_span(quad.o) {
      // U3a 官方律：壳做宾语——裸壳 = R(显式-or-fresh) + reifies 行（rt-08 判）；
      // 括号壳 = 剥壳展开重编（词项本尊，tt-01 判）
      if self.data[quad.o.0 + 2] == b'(' {
        let (c1, c2, c3, _) = self.scan_shell_parts(
          quad.o.0 + 3,
          quad.o.0 + quad.o.1 - 3,
        )
        o_kind = @nquads.TermKind::TripleTerm
        o_view = self.compose_shell_tt(
          c1,
          c2,
          c3,
          quad.prefix_version,
          quad.base_version,
        )
      } else {
        let (r_kind, r_view, tt_view) = self.shell_reifier_flow(
          quad.o,
          quad.prefix_version,
          quad.base_version,
        )
        shell_rows.push((r_kind, r_view, tt_view))
        o_kind = r_kind
        o_view = r_view
      }
    } else if c0 == b'<' {
      let v = self.iri_term(quad.o, quad.base_version)
      let v = self.gate_iri(v)
      o_kind = @nquads.TermKind::Iri
      o_view = v
    } else if c0 == b'_' {
      let v = slice_span(self.data, quad.o)
      let v = self.gate_bnode(v)
      o_kind = @nquads.TermKind::BNode
      o_view = v
    } else if c0 == b'[' || c0 == b'(' {
      // ★3 fresh 结构节点：开括号 offset memo `_:genid<N>`，可信构造免深验
      o_kind = @nquads.TermKind::BNode
      o_view = self.fresh_bnode(quad.o)
    } else if c0 == b'"' || c0 == b'\'' {
      let v = self.materialize_literal(quad.o, quad.prefix_version)
      let v = self.gate_literal(v)
      o_kind = @nquads.TermKind::Literal
      o_view = v
    } else if is_num {
      // 数值族：词形已由 is_numeric_span 全验，展开为可信构造，免深验
      // 注意：先展开、后取 arena 视图——内联写 slice_span(self.arena[:], self.expand_…)
      // 会因实参求值序先建旧视图，展开追加后越界被 slice_span 钳成空视图
      let nspan = self.expand_number(quad.o)
      o_kind = @nquads.TermKind::Literal
      o_view = slice_span(self.arena[:], nspan)
    } else if @nquads.is_boolean_word(self.data, quad.o.0, quad.o.1) {
      let bspan = self.expand_boolean(quad.o)
      o_kind = @nquads.TermKind::Literal
      o_view = slice_span(self.arena[:], bspan) // 静态词可信，免深验
    } else {
      let hit = self.expand_prefname(
        quad.o,
        quad.prefix_version,
        quad.base_version,
      )
      match hit {
        Some(expanded) => {
          let v = self.gate_iri(slice_span(self.arena[:], expanded))
          o_kind = @nquads.TermKind::Iri
          o_view = v
        }
        None => raise ParseError::ValidationErr("Object has undeclared prefix")
      }
    }
  }
  // 图名位：Iri / BNode / PrefName 展开（TriG 图名可为前缀名）
  let mut g_kind : @nquads.TermKind = @nquads.TermKind::DefaultGraph
  let mut g_view : ArrayView[Byte] = self.data[0:0]
  if quad.g is Some(g) {
    let c0 = self.data[g.0]
    if c0 == b'<' {
      let v = self.iri_term(g, quad.base_version)
      let v = self.gate_iri(v)
      g_kind = @nquads.TermKind::Iri
      g_view = v
    } else if c0 == b'_' {
      let v = slice_span(self.data, g)
      let v = self.gate_bnode(v)
      g_kind = @nquads.TermKind::BNode
      g_view = v
    } else if c0 == b'[' || c0 == b'(' {
      // ★3 fresh 结构节点（图名位不可为 fresh——表保证图名位只有 Iri/PrefName/
      // BlankNode 三事件；防御位照接）
      g_kind = @nquads.TermKind::BNode
      g_view = self.fresh_bnode(g)
    } else {
      let hit = self.expand_prefname(g, quad.prefix_version, quad.base_version)
      match hit {
        Some(expanded) => {
          let v = self.gate_iri(slice_span(self.arena[:], expanded))
          g_kind = @nquads.TermKind::Iri
          g_view = v
        }
        None =>
          raise ParseError::ValidationErr("Graph name has undeclared prefix")
      }
    }
  }
  let main : @nquads.QuadEmit = {
    s_kind,
    s_view,
    predicate,
    o_kind,
    o_view,
    g_kind,
    g_view,
  }
  let rows : Array[@nquads.QuadEmit] = [main]
  for row in shell_rows {
    let (r_kind, r_view, tt_view) = row
    let start = self.arena.length()
    self.push_text("<http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies>")
    let reifies_pred = slice_span(
      self.arena[:],
      (start, self.arena.length() - start),
    )
    rows.push({
      s_kind: r_kind,
      s_view: r_view,
      predicate: reifies_pred,
      o_kind: @nquads.TermKind::TripleTerm,
      o_view: tt_view,
      g_kind,
      g_view,
    })
  }
  rows
}

// ============================================================
// U3a 剥壳展开件（官方 reifier 律基建）
// ------------------------------------------------------------
// 壳文本（裸 `<< s p o [~ r] >>` / 括号 `<<( s p o )>>` / 注解锚 `s p o`）
// 字节级重扫：空白容忍、引号体整对跳过（转义感知）、嵌套壳深度计、
// `~` 为 reifier 引导（其后可选一词项至尾；空 ~ = fresh）。
// 成分物化走既有展开臂（iri_term / expand_prefname / gate_*），复合重编
// `<<( v1 v2 v3 )>>` 落 arena（展开形——sparql T62 同课：复合文本须携展开词项）。
// ============================================================

///|
/// 壳 span 判形（`<<` 起始，裸/括号皆算；注解锚行走 subj_shell 旗不经此）
fn TrigMaterializer::is_shell_span(self : TrigMaterializer, sp : Span) -> Bool {
  sp.1 >= 4 && self.data[sp.0] == b'<' && self.data[sp.0 + 1] == b'<'
}

///|
fn TrigMaterializer::is_shell_blank(self : TrigMaterializer, b : Byte) -> Bool {
  let _ = self
  b == b' ' || b == b'\t' || b == b'\r' || b == b'\n'
}

///|
fn TrigMaterializer::shell_skip_blank(
  self : TrigMaterializer,
  at : Int32,
  end : Int32,
) -> Int32 {
  let mut i = at
  while i < end && self.is_shell_blank(self.data[i]) {
    i += 1
  }
  i
}

///|
/// ASCII 文本推入 arena（词表串/壳符）
fn TrigMaterializer::push_text(self : TrigMaterializer, text : String) -> Unit {
  let len = text.length()
  let mut i = 0
  while i < len {
    self.arena.push(text[i].to_byte())
    i += 1
  }
}

///|
/// 壳内单词项扫描：返回 (span, 下一索引)。嵌套壳深度计（引号体跳过），
/// 字面量转义感知 + 可跨白后缀，其余词项扫到空白/`~`/尾
fn TrigMaterializer::shell_term_span(
  self : TrigMaterializer,
  at : Int32,
  end : Int32,
) -> (Span, Int32) raise ParseError {
  if at >= end {
    raise ParseError::ValidationErr("shell: missing component")
  }
  let c0 = self.data[at]
  if c0 == b'<' && at + 1 < end && self.data[at + 1] == b'<' {
    let mut depth = 1
    let mut i = if at + 2 < end && self.data[at + 2] == b'(' {
      at + 3
    } else {
      at + 2
    }
    while i < end && depth > 0 {
      let u = self.data[i]
      if u == b'"' || u == b'\'' {
        let q = u
        i += 1
        while i < end {
          let w = self.data[i]
          if w == b'\\' {
            i += 2
            continue
          }
          i += 1
          if w == q {
            break
          }
        }
        continue
      }
      if u == b'<' && i + 1 < end && self.data[i + 1] == b'<' {
        depth += 1
        i += if i + 2 < end && self.data[i + 2] == b'(' { 3 } else { 2 }
        continue
      }
      if u == b')' &&
        i + 2 < end &&
        self.data[i + 1] == b'>' &&
        self.data[i + 2] == b'>' {
        depth -= 1
        i += 3
        continue
      }
      if u == b'>' && i + 1 < end && self.data[i + 1] == b'>' {
        depth -= 1
        i += 2
        continue
      }
      i += 1
    }
    if depth != 0 {
      raise ParseError::ValidationErr("shell: unbalanced nested shell")
    }
    return ((at, i - at), i)
  }
  if c0 == b'"' || c0 == b'\'' {
    let q = c0
    let mut i = at + 1
    let mut closed = false
    while i < end {
      let w = self.data[i]
      if w == b'\\' {
        i += 2
        continue
      }
      i += 1
      if w == q {
        closed = true
        break
      }
    }
    if !closed {
      raise ParseError::ValidationErr("shell: unterminated literal")
    }
    let mut k = self.shell_skip_blank(i, end)
    if k < end && self.data[k] == b'@' {
      k += 1
      while k < end &&
            !self.is_shell_blank(self.data[k]) &&
            self.data[k] != b'<' &&
            self.data[k] != b'>' {
        k += 1
      }
      i = k
    } else if k < end &&
      self.data[k] == b'^' &&
      k + 1 < end &&
      self.data[k + 1] == b'^' {
      k += 2
      while k < end && self.data[k] != b'>' {
        k += 1
      }
      if k < end {
        k += 1
      }
      i = k
    }
    return ((at, i - at), i)
  }
  if c0 == b'<' {
    // IRIREF：扫到首个 `>`（紧邻形 `<a><b>` 靠 > 自界定，nt-ttl12-syntax-2 官判）
    let mut i = at + 1
    while i < end && self.data[i] != b'>' {
      i += 1
    }
    if i >= end {
      raise ParseError::ValidationErr("shell: unterminated iri")
    }
    return ((at, i + 1 - at), i + 1)
  }
  let mut i = at + 1
  while i < end {
    let u = self.data[i]
    if u == b'~' || u == b'<' || u == b'>' || self.is_shell_blank(u) {
      break
    }
    i += 1
  }
  ((at, i - at), i)
}

///|
/// 壳内三成分 + 可选 reifier 扫描（start/end = 已剥壳的内体绝对区间）
fn TrigMaterializer::scan_shell_parts(
  self : TrigMaterializer,
  start : Int32,
  end : Int32,
) -> (Span, Span, Span, Span?) raise ParseError {
  // 尾语句点剥除（词法尾并律：`...)>>.` 的 `.` 并入词尾——nt-ttl12-syntax-2/3 官判）
  let mut end = end
  while end > start &&
        (
          self.data[end - 1] == b'.' ||
          self.data[end - 1] == b',' ||
          self.data[end - 1] == b';'
        ) {
    end -= 1
  }
  let mut i = self.shell_skip_blank(start, end)
  let c1 = self.shell_term_span(i, end)
  i = self.shell_skip_blank(c1.1, end)
  let c2 = self.shell_term_span(i, end)
  i = self.shell_skip_blank(c2.1, end)
  let c3 = self.shell_term_span(i, end)
  i = self.shell_skip_blank(c3.1, end)
  let mut reif : Span? = None
  if i < end && self.data[i] == b'~' {
    let k = self.shell_skip_blank(i + 1, end)
    if k < end {
      let r = self.shell_term_span(k, end)
      reif = Some(r.0)
      i = self.shell_skip_blank(r.1, end)
    } else {
      i = end
    }
  }
  if i != end {
    raise ParseError::ValidationErr("shell: trailing content")
  }
  (c1.0, c2.0, c3.0, reif)
}

///|
/// 壳成分物化视图（slot 纪律：0=主语 1=谓语 2=宾语——官方 tt 词项类律，
/// trig12-syntax-bad-02/03 官判：数字主语拒、匿名节点 `[]`/`()` 恒拒、
/// 谓语位仅 IRI；expand_prefname 对无冒号 span 走默认前缀语义，数字面
/// 不得直喂——先槽位裁决再展开）
fn TrigMaterializer::shell_term_view(
  self : TrigMaterializer,
  sp : Span,
  pv : Int32,
  bv : Int32,
  slot : Int32,
) -> (@nquads.TermKind, ArrayView[Byte]) raise ParseError {
  let c0 = self.data[sp.0]
  // `(` 集合壳内恒拒（bad-06 官判）；`[` 匿名谓语位拒（bad-03 官判）、
  // 主/宾位合法 = fresh bnode（bnode-03 官判）
  if c0 == b'(' {
    raise ParseError::ValidationErr(
      "shell: collection not allowed in triple term",
    )
  }
  if c0 == b'[' {
    if slot == 1 {
      raise ParseError::ValidationErr(
        "shell: anonymous node not allowed in predicate slot",
      )
    }
    return (@nquads.TermKind::BNode, self.fresh_bnode(sp))
  }
  // 数值 / 布尔面（仅宾语槽）：展开为 Literal
  let is_num = (
      c0 == b'+' || c0 == b'-' || c0 == b'.' || (c0 >= b'0' && c0 <= b'9')
    ) &&
    @nquads.is_numeric_span(self.data, sp.0, sp.1)
  let is_bool = @nquads.is_boolean_word(self.data, sp.0, sp.1)
  if slot != 2 && (is_num || is_bool || c0 == b'"' || c0 == b'\'') {
    raise ParseError::ValidationErr(
      "shell: literal/numeric component only allowed in object slot",
    )
  }
  if c0 == b'<' &&
    sp.1 >= 4 &&
    self.data[sp.0 + 1] == b'<' &&
    self.data[sp.0 + 2] == b'(' {
    let (c1, c2, c3, _) = self.scan_shell_parts(sp.0 + 3, sp.0 + sp.1 - 3)
    (@nquads.TermKind::TripleTerm, self.compose_shell_tt(c1, c2, c3, pv, bv))
  } else if c0 == b'<' && sp.1 >= 4 && self.data[sp.0 + 1] == b'<' {
    // 嵌套裸壳：同一剥壳展开重编（递归深验 + 展开形；官方 R 化留 U3b 嵌套位）
    let (c1, c2, c3, _) = self.scan_shell_parts(sp.0 + 2, sp.0 + sp.1 - 2)
    (@nquads.TermKind::TripleTerm, self.compose_shell_tt(c1, c2, c3, pv, bv))
  } else if c0 == b'<' {
    let v = self.iri_term(sp, bv)
    (@nquads.TermKind::Iri, self.gate_iri(v))
  } else if c0 == b'_' {
    (@nquads.TermKind::BNode, self.gate_bnode(slice_span(self.data, sp)))
  } else if c0 == b'"' || c0 == b'\'' {
    (@nquads.TermKind::Literal, slice_span(self.data, sp))
  } else if is_num {
    let nspan = self.expand_number(sp)
    (@nquads.TermKind::Literal, slice_span(self.arena[:], nspan))
  } else if is_bool {
    let bspan = self.expand_boolean(sp)
    (@nquads.TermKind::Literal, slice_span(self.arena[:], bspan))
  } else {
    let hit = self.expand_prefname(sp, pv, bv)
    match hit {
      Some(expanded) =>
        (
          @nquads.TermKind::Iri,
          self.gate_iri(slice_span(self.arena[:], expanded)),
        )
      None =>
        raise ParseError::ValidationErr(
          "shell: component has undeclared prefix",
        )
    }
  }
}

///|
/// 复合重编：`<<( v1 v2 v3 )>>`（展开形落 arena；谓语成分须 IRI）
fn TrigMaterializer::compose_shell_tt(
  self : TrigMaterializer,
  c1 : Span,
  c2 : Span,
  c3 : Span,
  pv : Int32,
  bv : Int32,
) -> ArrayView[Byte] raise ParseError {
  let (_, v1) = self.shell_term_view(c1, pv, bv, 0)
  let (k2, v2) = self.shell_term_view(c2, pv, bv, 1)
  if !(k2 is @nquads.TermKind::Iri) {
    raise ParseError::ValidationErr("shell: predicate component must be an IRI")
  }
  let (_, v3) = self.shell_term_view(c3, pv, bv, 2)
  let start = self.arena.length()
  self.push_text("<<( ")
  self.push_view(v1)
  self.push_byte(b' ')
  self.push_view(v2)
  self.push_byte(b' ')
  self.push_view(v3)
  self.push_text(" )>>")
  slice_span(self.arena[:], (start, self.arena.length() - start))
}

///|
/// 裸壳 reifier 流：剥 `<< >>` → 三成分 + reifier（显式展开 / 空 = fresh 壳 span memo）
/// → (R kind, R view, tt view)
fn TrigMaterializer::shell_reifier_flow(
  self : TrigMaterializer,
  sp : Span,
  pv : Int32,
  bv : Int32,
) -> (@nquads.TermKind, ArrayView[Byte], ArrayView[Byte]) raise ParseError {
  let (c1, c2, c3, reif) = self.scan_shell_parts(sp.0 + 2, sp.0 + sp.1 - 2)
  let (r_kind, r_view) = match reif {
    Some(rs) => {
      // reifier 位 = 主语位纪律（Iri/BNode，拒字面量/数值/布尔；前缀名
      // `:id` 形合法——inside-03 官判，且 reifier 可复用为主语）
      let (k, v) = self.shell_term_view(rs, pv, bv, 0)
      if k is @nquads.TermKind::Literal {
        raise ParseError::ValidationErr("shell: reifier cannot be a literal")
      }
      (k, v)
    }
    None => (@nquads.TermKind::BNode, self.fresh_bnode(sp))
  }
  let tt_view = self.compose_shell_tt(c1, c2, c3, pv, bv)
  (r_kind, r_view, tt_view)
}

///|
/// 批量物化：逐条搬运，错误逐条收集（与 parse_all 同口径）。
/// deep_validate（默认开）：物化后逐 quad 深验（iri.mbt / langtag.mbt /
/// literal.mbt 口径），不合格项不进 results——流到序列化层的 emit 全部合法
pub fn TrigMaterializer::materialize_all(
  self : TrigMaterializer,
  quads : Array[QuadSpan],
  deep_validate~ : Bool = true,
  mode~ : @nquads.ValidateMode = @nquads.ValidateMode::Deep,
) -> (Array[@nquads.QuadEmit], Array[ParseError]) {
  self.deep_validate = deep_validate && !mode.is_light() // B2 档位：Light 关深验面
  let results : Array[@nquads.QuadEmit] = []
  let errors : Array[ParseError] = []
  for quad in quads {
    try {
      let rows = self.materialize_quad(quad)
      for q in rows {
        results.push(q)
      }
    } catch {
      e => errors.push(e)
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
/// 深验融合门（deep_validate 开时校验，关时直通；成功原样返还 view）
fn TrigMaterializer::gate_iri(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> ArrayView[Byte] raise ParseError {
  if self.deep_validate {
    check_iri_view(view)
    view
  } else {
    view
  }
}

///|
fn TrigMaterializer::gate_bnode(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> ArrayView[Byte] raise ParseError {
  if self.deep_validate {
    check_bnode_view(view)
    view
  } else {
    view
  }
}

///|
fn TrigMaterializer::gate_tt(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> ArrayView[Byte] raise ParseError {
  if self.deep_validate {
    deep_check_tt(view)
    view
  } else {
    view
  }
}

///|
fn TrigMaterializer::gate_literal(
  self : TrigMaterializer,
  view : ArrayView[Byte],
) -> ArrayView[Byte] raise ParseError {
  if self.deep_validate {
    deep_check_literal(view, self.rdf12)
    view
  } else {
    view
  }
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
