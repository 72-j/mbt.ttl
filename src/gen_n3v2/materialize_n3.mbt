// ===== 用户部分：N3 物化器（表下游：span 四元组 → 可序列化 QuadEmit） =====
// 复用 @nquads 的 QuadEmit/Subject/Object/GraphName 模型与 Serializer 输出口；
// view 保真路线（trig materialize_trig.mbt 同构：物化只搬运 + 标注）。
// 深验单遍口径同 trig：校验经 gate_iri/gate_bnode/gate_tt/gate_literal 四门在
// materialize_quad 词项构造点就地执行，不做第二遍扫描。
// N3 特有（与 trig 的差异，均有据可查）：
//   - 集合 = 单一 BNode（ADR-003a）：`( ... )` 的身份 = `(` 自身 span →
//     fresh_bnode `_:genid{off}`；无链节点（trig 的长度编码序号 genid{n}k 分支
//     退役）。空集合 `( )` = pop 层 nil 标记 Span(open.0, 0) → 物化层合成
//     rdf:nil 词表 IRI（长度 0 臂，s/o 两槽同）。
//   - pk 臂（RDFFirst/RDFRest 合成谓词）保留为 ADR-003b 显式链预留位：N3 引擎
//     pk 恒 Normal，当前死臂；QuadSpan.pk 文档钉死的 003b 落点。
//   - iri_version 槽不参与物化（ADR-003b 显式链账本版本，接表后作回扫上界）。
//   - 图名臂保留为防御位：N3 无图块语法，quad.g 恒 None（表无图事件）。
// 不变量（trig 同宪法）：
//   - QuadEmit 的 view 或指原 data（未改写项，零拷贝）或指 arena（展开项）
//   - arena append-only：旧段内容永不改写，早先取出的 view 内容始终有效
//   - emits 生命周期 = 物化器生命周期

///|
/// N3 物化器：持数据视图 + 前缀账本 + @base 声明链 + 展开缓冲
///
/// prefixes 账本生命周期约定（trig 同款）：调用方在 parse_all 返回后传入
/// ctx.prefixes；物化期间保持只读，物化器借用不持有、不复制账本。
pub struct N3Materializer {
  data : ArrayView[Byte]
  prefixes : Array[(Span, Span)] // (name, iri) 声明账本（与 ctx.prefixes 同账本）
  bases : Array[Span] // @base 声明链（与 ctx.bases 同账本，append-only）
  base_fallback : String? // 外部 base（套件 runner 注入 test-URI 口径；doc @base 优先）
  scalar_only_escapes : Bool // RDF 1.2 方言开关：字面量 \u/\U 代理全禁（1.1 成对合法）
  mut fallback_parsed : @nquads.Iri? // 外部 fallback base 解析 memo（成功才记）
  base_memo : Map[Int, @nquads.Iri] // base_version → 折叠后的生效 base（链前缀稳定，append-only）
  mut deep_validate : Bool // 深验融合开关（materialize_all 参数落位，materialize_quad 单入口读）
  fresh_ids : Map[Span, Span] // fresh 节点 memo：开括号全 span → arena 内 `_:genid<N>` span
  arena : Array[Byte] // 展开字节缓冲（PrefName/'a'/数值/布尔/^^PrefName/相对 IRI 落这里）
}

///|
/// 构造：prefixes 传引擎 ctx.prefixes 的引用（同一账本，后声明覆盖先声明）。
/// bases 传 ctx.bases。每条 quad 的生效 base 由其 base_version 折叠链得出（中途换 base
/// 不污染历史 quad）；base_fallback 供无 @base 覆盖段
pub fn N3Materializer::new(
  data : ArrayView[Byte],
  prefixes : Array[(Span, Span)],
  bases? : Array[Span] = [],
  base_fallback? : String? = None,
  scalar_only_escapes? : Bool = false,
) -> N3Materializer {
  {
    data,
    prefixes,
    bases,
    base_fallback,
    scalar_only_escapes,
    fallback_parsed: None,
    base_memo: Map([]),
    deep_validate: true,
    fresh_ids: Map([]),
    arena: [],
  }
}

///|
/// arena 写入辅助：字节 / 视图 / ASCII 串
fn N3Materializer::push_byte(self : N3Materializer, b : Byte) -> Unit {
  self.arena.push(b)
}

///|
fn N3Materializer::push_view(
  self : N3Materializer,
  view : ArrayView[Byte],
) -> Unit {
  // blit 批量拷贝（自动扩容目标数组）：替代逐字节 push 的容量/越界逐次检查
  view.blit_to(self.arena, dst_offset=self.arena.length())
}

///|
fn N3Materializer::push_str(self : N3Materializer, s : String) -> Unit {
  for i in 0..<s.length() {
    self.arena.push(s[i].to_byte())
  }
}

///|
/// 词表 IRI 写入："<" + vocab iri + ">"（复用 @nquads vocab 的 NamedNodeRef）
fn N3Materializer::push_vocab(
  self : N3Materializer,
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
/// 前缀名一次解析（trig 同款 API）：语法面校验折叠在此——条件性跳过轻验后由
/// 本层兜住 bad-pname 族。返回 Some((声明 IRI span, 冒号位))；
/// Ok(None) = 未声明（保真兜底口径）；Err = 语法面非法。
/// arena append-only 不可回滚：校验必须先于写 arena。
fn N3Materializer::resolve_prefname(
  self : N3Materializer,
  span : Span,
  prefix_version : Int,
) -> Result[(Span, Int)?, ParseError] {
  let (off, len) = span
  let mut colon = -1
  for i in 0..<len {
    if self.data[off + i] == b':' {
      colon = i
      break
    }
  }
  if colon < 0 {
    // 役5 裸词（@keywords listed / `a` 失格降名）：无冒号名按空前缀展开
    //（DefaultPrefixIRI = `:word` 同径）；默认前缀未声明仍走 Ok(None) 拒
    colon = 0
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
  // 账本查找（单次；从尾向前扫 = 后声明覆盖先声明；上界 prefix_version = 发射时点账本长
  //——per-quad 快照：重声明前的 quad 只见老声明，中途改写不污染历史）。
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
fn N3Materializer::write_prefname_iri(
  self : N3Materializer,
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
  // local 部分：PN_LOCAL_ESC 解码（\X → X；百分号 %HH 保真——百分号序列按
  // 原样三字符进 IRI，不展开）。colon 位有冒号字符则本地部从 colon+1 起，
  // 否则 = 役5 无冒号裸词（colon 归零哨兵），整词即本地部
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
/// 相对展开收口（subm-01 口径）：相对前缀声明 IRI 展开后仍是相对 IRI，与
/// 词项位相对 IRI 同径——按 base 解析改写；绝对展开零改写直通
fn N3Materializer::expand_prefname(
  self : N3Materializer,
  span : Span,
  prefix_version : Int,
  base_version : Int,
) -> Result[Span?, ParseError] {
  match self.resolve_prefname(span, prefix_version) {
    Err(e) => Err(e)
    Ok(None) => {
      // 役17 隐式空前缀绑定（原始 N3 Team Submission §Namespaces 口径）：
      // "The empty prefix "" is by default, bound to "#" -- the local
      // namespace of the file. The parser behaves as though there were a
      // @prefix : <#> just before the file." 账本 miss 且词位首字符即 `:`
      // （空前缀:本地部；役5 无冒号裸词的 colon==0 哨兵不在此列）→ `#` +
      // 本地部按相对 IRI 走 base 解析（iri_term 相对路同构）。显式 `@prefix
      // :` 命中账本先行返回，天然覆盖隐式——次序即 "just before the file"。
      // （现行 N3 CG 规范已删此预绑定；本引擎随套件/cwm 传统，分歧记 spec）
      let (off, len) = span
      if len > 0 && self.data[off] == b':' {
        let base_iri = match self.quad_base(base_version) {
          Ok(b) => b
          Err(e) => return Err(e)
        }
        if base_iri.scheme.length() == 0 {
          return Err(ParseError::ValidationErr("@base must be absolute"))
        }
        // 相对 IRI `#` + 本地部（PN_LOCAL_ESC 解码同 write_prefname_iri；
        // 字节拼装不过 char——多字节 UTF-8 本地名免双重编码）
        let tmp : Array[Byte] = []
        tmp.push(b'#')
        let mut i = off + 1
        let stop = off + len
        while i < stop {
          let c = self.data[i]
          if c == b'\\' && i + 1 < stop {
            tmp.push(self.data[i + 1])
            i = i + 2
          } else {
            tmp.push(c)
            i = i + 1
          }
        }
        match base_iri.resolve(Bytes::from_array(tmp)[:]) {
          Ok(resolved) => {
            let start = self.arena.length()
            self.push_byte(b'<')
            self.push_str(resolved.into_string())
            self.push_byte(b'>')
            Ok(Some((start, self.arena.length() - start)))
          }
          Err(e) =>
            Err(ParseError::ValidationErr("IRI resolution failed: \{e}"))
        }
      } else {
        Ok(None)
      }
    }
    Ok(Some((iri, colon))) => {
      let raw = self.write_prefname_iri(span, colon, iri)
      let view = slice_span(self.arena[:], raw)
      if view_has_scheme(view[1:view.length() - 1]) {
        Ok(Some(raw))
      } else {
        // 相对展开：按该 quad 的生效 base（base_version 折叠链 → fallback）解析
        let base_iri = match self.quad_base(base_version) {
          Ok(b) => b
          Err(e) => return Err(e)
        }
        match
          base_iri.resolve(Bytes::from_array(view[1:view.length() - 1])[:]) {
          Ok(resolved) => {
            let start = self.arena.length()
            self.push_byte(b'<')
            self.push_str(resolved.into_string())
            self.push_byte(b'>')
            Ok(Some((start, self.arena.length() - start)))
          }
          Err(e) =>
            Err(ParseError::ValidationErr("IRI resolution failed: \{e}"))
        }
      }
    }
  }
}

///|
/// IRI 词项取值（"相对 IRI 解析在物化层"定案的落点）：
///   绝对 IRI → 原 data 零拷贝保真
///   相对 IRI + 有 base → resolve 展开（含 dot-segment 移除）进 arena
///   相对 IRI + 无 base → 报错（base-bad 桶口径；改写不受 deep_validate 门控）
/// base 自身必须绝对（有 scheme），否则按无 base 论
fn N3Materializer::iri_term(
  self : N3Materializer,
  span : Span,
  base_version : Int,
) -> Result[ArrayView[Byte], ParseError] {
  let view = slice_span(self.data, span)
  let len = view.length()
  // <> 包裹守卫（轻验职责的落物化层收口）：包裹残缺不得落相对路径剥壳，
  // 否则 `<s>.` 的尾点残段会被 base 修复成合法 IRI。`<>` 放行剥壳走相对路径
  if len < 2 || view[0] != b'<' || view[len - 1] != b'>' {
    return Err(ParseError::ValidationErr("IRI must be wrapped in <>"))
  }
  // 绝对性路由：scheme 嗅探替代整段 @nquads.parse（深验在槽位由 check_iri_view 融合执行）
  if view_has_scheme(view[1:len - 1]) {
    return Ok(view) // 绝对：零拷贝保真
  }
  // 相对：按该 quad 的生效 base（base_version 折叠链 → fallback）解析
  let base_iri = match self.quad_base(base_version) {
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
/// 外部 fallback base 解析（lazy 单次 memo，成功才记——坏 fallback 逐词项重报）
fn N3Materializer::fallback_base(
  self : N3Materializer,
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
/// per-quad base：按 base_version 折叠 base 链（bases[0..base_version]）——绝对 @base 重置
/// 累计值，相对 @base 对累计值（链空落 fallback）按 RFC 3986 5.2 合并。链
/// append-only → 前缀稳定，base_version 为键 memo。Err = 链上有坏声明（不 memo）；
/// Ok(None) = 该 quad 无生效 @base（调用方落 fallback_base 口径）
fn N3Materializer::base_at(
  self : N3Materializer,
  base_version : Int,
) -> Result[@nquads.Iri?, ParseError] {
  if base_version == 0 {
    return Ok(None)
  }
  match self.base_memo.get(base_version) {
    Some(b) => return Ok(Some(b))
    None => ()
  }
  let mut acc : @nquads.Iri? = None
  for i in 0..<base_version {
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
              return Err(
                ParseError::ValidationErr("IRI resolution failed: \{e}"),
              )
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
      self.base_memo[base_version] = b
      Ok(Some(b))
    }
    None => Ok(None)
  }
}

///|
/// 该 quad 的生效 base（base_version 链折叠 → fallback）；两者皆无则 Err——相对词项
/// 无处解析。结果恒绝对
fn N3Materializer::quad_base(
  self : N3Materializer,
  base_version : Int,
) -> Result[@nquads.Iri, ParseError] {
  let b = match self.base_at(base_version) {
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
fn N3Materializer::expand_number(self : N3Materializer, span : Span) -> Span {
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
fn N3Materializer::expand_boolean(self : N3Materializer, span : Span) -> Span {
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
/// 公式体闭括号位置：`{` 偏移 → 配对 `}` 之后一字节的绝对偏移。
/// 括号配对跳过字面量（含转义/三引号，借 literal_body_end）/ IRI `<…>` /
/// 注释 `#…\n` / 规则算子 `<=`（防被 IRI 臂误吞越过闭括号）——公式体内可含
/// 完整 N3 语句面。失配返回 Err（引擎只出 `{` token span，配对由物化层全权
/// 裁决；ADR-002 公式不透明，整段原文持有不做内部深验）
fn formula_body_end(
  data : ArrayView[Byte],
  open : Int,
) -> Result[Int, ParseError] {
  let mut depth = 0
  let mut i = open
  while i < data.length() {
    let b = data[i]
    if b == b'"' || b == b'\'' {
      i = literal_body_end(data, (i, data.length() - i))
      continue
    }
    if b == b'<' {
      // `<=` / `<-` 皆 2 字节操作符先行裁决，否则被下方 IRI 扫描误吞——
      // `{ :x <-:y :z }` 公式体实测（inverted_properties.n3）
      if i + 1 < data.length() && (data[i + 1] == b'=' || data[i + 1] == b'-') {
        i = i + 2
        continue
      }
      i = i + 1
      while i < data.length() && data[i] != b'>' {
        i = i + 1
      }
      i = i + 1
      continue
    }
    if b == b'#' {
      while i < data.length() && data[i] != b'\n' {
        i = i + 1
      }
      continue
    }
    if b == b'{' {
      depth = depth + 1
      i = i + 1
      continue
    }
    if b == b'}' {
      depth = depth - 1
      i = i + 1
      if depth == 0 {
        return Ok(i)
      }
      continue
    }
    i = i + 1
  }
  Err(ParseError::ValidationErr("Unbalanced formula braces"))
}

///|
/// 字面量物化：引号体 + 后缀（@lang / ^^dt）。
///   - 无后缀 / @lang / ^^<IRI> → span 原样零拷贝（字节保真）
///   - ^^PrefName → 引号体原样 + ^^<展开 IRI>（arena 改写）
///   - 三引号长串 → 原样回写（规范化转正在深验阶段）
/// Result 化：^^PrefName 语法面非法在此拒绝；未声明前缀零拷贝保真兜底——
/// 槽位深验对最终 view 拒（dt 非 <IRI> 形即拒）
fn N3Materializer::materialize_literal(
  self : N3Materializer,
  span : Span,
  prefix_version : Int,
) -> Result[ArrayView[Byte], ParseError] {
  let (off, len) = span
  let body_end = literal_body_end(self.data, span)
  if body_end + 2 < off + len &&
    self.data[body_end] == b'^' &&
    self.data[body_end + 1] == b'^' &&
    self.data[body_end + 2] != b'<' {
    let dt_span : Span = (body_end + 2, off + len - (body_end + 2))
    match self.resolve_prefname(dt_span, prefix_version) {
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
pub fn N3Materializer::materialize_quad(
  self : N3Materializer,
  quad : QuadSpan,
) -> Result[@nquads.QuadEmit, ParseError] {
  // 役23 R-06：nil 标记验形门（零长 span = 空集合 rdf:nil in-band 标记，
  // 唯一构造点 pop_bnode_prop——offset 恒指 `(` 开括号原文位；offset 处
  // 非 `(` 的事故零长 span 报错，不再静默变 rdf:nil。边缘：data[0]=='('
  // 且事故 span=(0,0) 会误认——真根除需 out-of-band 载体，API 改不取）
  if quad.s.1 == 0 && self.data[quad.s.0] != b'(' {
    return Err(
      ParseError::ValidationErr(
        "Zero-length subject span is not a valid nil marker",
      ),
    )
  }
  if quad.o.1 == 0 && self.data[quad.o.0] != b'(' {
    return Err(
      ParseError::ValidationErr(
        "Zero-length object span is not a valid nil marker",
      ),
    )
  }
  // 主语位：Iri / BNode / fresh 结构 / PrefName（TT 壳臂为防御位：N3 表无
  // 主语位壳行）。融合深验在词项构造点就地执行
  let subject : @nquads.Subject = if quad.subj_shell {
    // 役8 注解壳主语：s = 锚三元组连续原文 span，物化层合成 <<原文>> TT 壳
    //（分量在主 quad 组装点各自过验；整段原样回写同 TT 黑盒口径）
    let start = self.arena.length()
    self.push_byte(b'<')
    self.push_byte(b'<')
    for i in quad.s.0..<(quad.s.0 + quad.s.1) {
      self.arena.push(self.data[i])
    }
    self.push_byte(b'>')
    self.push_byte(b'>')
    @nquads.Subject::TripleTerm(
      slice_span(self.arena[:], (start, self.arena.length() - start)),
    )
  } else if quad.s.1 == 0 {
    // rdf:nil 标记（Span(open.0, 0)，长度 0 = 无字节词项）：合成词表 IRI，
    // 可信免深验（ADR-003a 空集合主位）
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_nil)
    @nquads.Subject::Iri(
      slice_span(self.arena[:], (start, self.arena.length() - start)),
    )
  } else {
    let c0 = self.data[quad.s.0]
    if c0 == b'<' {
      if quad.s.1 >= 4 && self.data[quad.s.0 + 1] == b'<' {
        // 防御位：N3 表无主语位壳行；Step 5 接表后承接
        let v = slice_span(self.data, quad.s)
        match self.gate_tt(v) {
          Ok(v) => @nquads.Subject::TripleTerm(v)
          Err(e) => return Err(e)
        }
      } else {
        match self.iri_term(quad.s, quad.base_version) {
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
    } else if c0 == b'?' {
      // 变量 `?x`（ADR-004：只记身份）：语法面收紧后整段原文持有——
      // 不展开、不前缀解析、不绑定，名与位置即全部语义
      let v = slice_span(self.data, quad.s)
      match self.gate_variable(v) {
        Ok(v) => @nquads.Subject::Variable(v)
        Err(e) => return Err(e)
      }
    } else if c0 == b'[' || c0 == b'(' || c0 == b'!' || c0 == b'^' {
      // fresh 结构节点：`[]` fresh / 集合单一 BNode（ADR-003a：`(` 自身
      // span 即身份）；`!`/`^` 路径中间节点（役3：操作符 span 即身份）。
      // 开括号 offset memo `_:genid<N>`，可信构造免深验
      @nquads.Subject::BNode(self.fresh_bnode(quad.s))
    } else if c0 == b'"' || c0 == b'\'' {
      // N3 役10：verb ::= expression，主语位字面量合法——同宾语位口径
      //（物化 + 深验就地执行）
      match self.materialize_literal(quad.s, quad.prefix_version) {
        Ok(v) =>
          match self.gate_literal(v) {
            Ok(v) => @nquads.Subject::Literal(v)
            Err(e) => return Err(e)
          }
        Err(e) => return Err(e)
      }
    } else if c0 == b'{' {
      // N3 ADR-002：GraphTerm 公式主语——不透明不断言为真，整段原文持有
      //（引擎只出 `{` token span，物化层扫描配对 `}` 补全整段；免深验）
      match formula_body_end(self.data, quad.s.0) {
        Ok(end) => @nquads.Subject::Formula(self.data[quad.s.0:end])
        Err(e) => return Err(e)
      }
    } else if (
        c0 == b'+' || c0 == b'-' || c0 == b'.' || (c0 >= b'0' && c0 <= b'9')
      ) &&
      is_numeric_span(self.data, quad.s.0, quad.s.1) {
      // 数值主语：词形全验后展开为可信构造，免深验（同宾语位口径）
      let nspan = self.expand_number(quad.s)
      @nquads.Subject::Literal(slice_span(self.arena[:], nspan))
    } else if quad.s.1 == 4 && self.bool_at(quad.s, "true") {
      let bspan = self.expand_boolean(quad.s)
      @nquads.Subject::Literal(slice_span(self.arena[:], bspan)) // 静态词可信，免深验
    } else if quad.s.1 == 5 && self.bool_at(quad.s, "false") {
      let bspan = self.expand_boolean(quad.s)
      @nquads.Subject::Literal(slice_span(self.arena[:], bspan)) // 静态词可信，免深验
    } else {
      match
        self.expand_prefname(quad.s, quad.prefix_version, quad.base_version) {
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
  // 谓词位：pk 出账判定（'a' 缩写 KwA → rdf:type；役5 起活性裁定在引擎——
  // 失效的 a 是 PrefName 裸名，字节嗅探已退役）；全 IRI 零拷贝；其余 PrefName 展开。
  // RDFFirst/RDFRest 合成谓词臂 = ADR-003b 显式链预留位（N3 当前死臂）
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
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_type)
    let pspan = (start, self.arena.length() - start)
    slice_span(self.arena[:], pspan) // 词表构造可信，免深验
  } else if quad.pk is PredKind::SameAs {
    // `=` 等同谓词（役7）：owl:sameAs（词表构造可信，免深验）
    let start = self.arena.length()
    self.push_vocab(@nquads.owl_sameas)
    let pspan = (start, self.arena.length() - start)
    slice_span(self.arena[:], pspan)
  } else if self.data[quad.p.0] == b'"' ||
    self.data[quad.p.0] == b'?' ||
    self.data[quad.p.0] == b'[' ||
    self.data[quad.p.0] == b'{' ||
    self.data[quad.p.0] == b'=' {
    // 役10 词位扩展：非词项谓词原文保真直出——字面量/变量谓词按原文重发
    // （cwm 口径）；`[`/`{` 谓词只持全 token span，保真以 token 为界。
    // 役17 增 `=`：规则蕴含 `=>`（N3Implies，全 token span）原文保真直出；
    // 裸 `=` 走上方 SameAs 臂（owl:sameAs 展开），不落此臂
    slice_span(self.data, quad.p)
  } else if quad.p.1 == 2 &&
    self.data[quad.p.0] == b'<' &&
    self.data[quad.p.0 + 1] == b'=' {
    // 役17：规则反向蕴含 `<=`（log:impliedBy）原文保真直出——必须先于
    // `<` IRI 臂裁决，否则被 iri_term 误吞
    slice_span(self.data, quad.p)
  } else if self.data[quad.p.0] == b'<' {
    match self.iri_term(quad.p, quad.base_version) {
      Ok(v) =>
        match self.gate_iri(v) {
          Ok(v) => v
          Err(e) => return Err(e)
        }
      Err(e) => return Err(e)
    }
  } else {
    match self.expand_prefname(quad.p, quad.prefix_version, quad.base_version) {
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
    // rdf:nil 标记（空集合宾位，ADR-003a）：合成词表 IRI，可信免深验
    let start = self.arena.length()
    self.push_vocab(@nquads.rdf_nil)
    @nquads.Object::Iri(
      slice_span(self.arena[:], (start, self.arena.length() - start)),
    )
  } else {
    let c0 = self.data[quad.o.0]
    let is_num = (
        c0 == b'+' || c0 == b'-' || c0 == b'.' || (c0 >= b'0' && c0 <= b'9')
      ) &&
      is_numeric_span(self.data, quad.o.0, quad.o.1)
    if c0 == b'<' {
      if quad.o.1 > 1 && self.data[quad.o.0 + 1] == b'<' {
        // 引用三元组壳（N3 宾位合法）：整段原文持有，字节保真；壳内 term-kind
        // 深验就地执行
        let v = slice_span(self.data, quad.o)
        match self.gate_tt(v) {
          Ok(v) => @nquads.Object::TripleTerm(v)
          Err(e) => return Err(e)
        }
      } else {
        match self.iri_term(quad.o, quad.base_version) {
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
    } else if c0 == b'?' {
      // 变量 `?x`（ADR-004：只记身份）：语法面收紧后整段原文持有——
      // 不展开、不前缀解析、不绑定，名与位置即全部语义
      let v = slice_span(self.data, quad.o)
      match self.gate_variable(v) {
        Ok(v) => @nquads.Object::Variable(v)
        Err(e) => return Err(e)
      }
    } else if c0 == b'[' || c0 == b'(' || c0 == b'!' || c0 == b'^' {
      // fresh 结构节点：`[]` fresh / 集合单一 BNode / 路径中间节点（役3 同身份）
      @nquads.Object::BNode(self.fresh_bnode(quad.o))
    } else if c0 == b'"' || c0 == b'\'' {
      match self.materialize_literal(quad.o, quad.prefix_version) {
        Ok(v) =>
          match self.gate_literal(v) {
            Ok(v) => @nquads.Object::Literal(v)
            Err(e) => return Err(e)
          }
        Err(e) => return Err(e)
      }
    } else if is_num {
      // 数值族：词形已由 is_numeric_span 全验，展开为可信构造，免深验
      // 注意：先展开、后取 arena 视图——内联写会因实参求值序先建旧视图，
      // 展开追加后越界被 slice_span 钳成空视图
      let nspan = self.expand_number(quad.o)
      @nquads.Object::Literal(slice_span(self.arena[:], nspan))
    } else if quad.o.1 == 4 && self.bool_at(quad.o, "true") {
      let bspan = self.expand_boolean(quad.o)
      @nquads.Object::Literal(slice_span(self.arena[:], bspan)) // 静态词可信，免深验
    } else if quad.o.1 == 5 && self.bool_at(quad.o, "false") {
      let bspan = self.expand_boolean(quad.o)
      @nquads.Object::Literal(slice_span(self.arena[:], bspan)) // 静态词可信，免深验
    } else if c0 == b'{' {
      // N3 ADR-002：公式宾语——不透明 GraphTerm，整段原文持有（引擎只出
      // `{` token span，物化层扫描配对 `}` 补全；免深验）
      match formula_body_end(self.data, quad.o.0) {
        Ok(end) => @nquads.Object::Formula(self.data[quad.o.0:end])
        Err(e) => return Err(e)
      }
    } else {
      match
        self.expand_prefname(quad.o, quad.prefix_version, quad.base_version) {
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
  // 图名位：防御位（N3 无图块语法，quad.g 恒 None；表无图事件）
  let graph : @nquads.GraphName = match quad.g {
    None => @nquads.GraphName::None
    Some(g) => {
      let c0 = self.data[g.0]
      if c0 == b'<' {
        match self.iri_term(g, quad.base_version) {
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
        // 防御位照接（trig 同款：表保证图名位不产 fresh）
        @nquads.GraphName::BNode(self.fresh_bnode(g))
      } else {
        match self.expand_prefname(g, quad.prefix_version, quad.base_version) {
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
fn N3Materializer::bool_at(
  self : N3Materializer,
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
/// deep_validate（默认开）：物化后逐 quad 深验，不合格项不进 results——
/// 流到序列化层的 emit 全部合法
pub fn N3Materializer::materialize_all(
  self : N3Materializer,
  quads : Array[QuadSpan],
  deep_validate? : Bool = true,
) -> (Array[@nquads.QuadEmit], Array[ParseError]) {
  self.deep_validate = deep_validate
  let results : Array[@nquads.QuadEmit] = []
  let errors : Array[ParseError] = []
  // 役20 声明名验形门（组装后账本 validate，nquads validate_helper 同层）：
  // 声明名必须以 `:` 收尾——`@prefix foo:bar <>.` 的 qname 形即拒。
  // 零 quad 文件也报（qname-as-prefix-in-decl 负例口径：merrs 通道点火）。
  let mut k = 0
  while k < self.prefixes.length() {
    let (nspan, _ispan) = self.prefixes[k]
    if nspan.1 == 0 || self.data[nspan.0 + nspan.1 - 1] != b':' {
      errors.push(
        ParseError::ValidationErr("Prefix declaration name must end with ':'"),
      )
    }
    k = k + 1
  }
  for quad in quads {
    match self.materialize_quad(quad) {
      Ok(q) => results.push(q)
      Err(e) => errors.push(e)
    }
  }
  (results, errors)
}

// ============================================================
// 深度验证（物化层深验门，trig 同款单遍口径；语义深验复用 @nquads 模块不写新轮子）
//   - IRI：scheme 嗅探 + @nquads.validate_iri_body
//   - @lang：@nquads.LanguageTag::parse（全量 RFC 5646；RDF 1.2 方向后缀
//     --ltr/--rtl 小写精确拆出后验基础标签）
//   - ^^dt：banned datatype（rdf:langString / rdf:dirLangString 禁显式）
//   - BNode：@nquads.validate_bnode
//   - Literal 体：@nquads.scan_string_body / validate_escapes_unicode
// ============================================================

///|
/// 深验 IRI 词项（`<...>` 形态 view）
fn check_iri_view(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let len = view.length()
  if len < 3 || view[0] != b'<' || view[len - 1] != b'>' {
    return Err(ParseError::ValidationErr("IRI must be wrapped in <>"))
  }
  // 绝对性：相对 IRI 已由 iri_term 按 base 改写，无 scheme 即拒（防御臂）
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
/// 深验变量词项（ADR-004：只记身份——语法面收紧在此）：`?` + varname，
/// varname 字符集 [A-Za-z0-9_]、首字符不许数字（N3 VARNAME 口径；词法
/// PrefName 合成已保证 `?` 后零空格邻接，此处只收词形）。变量不进谓词位
///（表无行 + 验证层显式拒），不展开不绑定。
fn check_variable_view(view : ArrayView[Byte]) -> Result[Unit, ParseError] {
  let n = view.length()
  if n < 2 {
    return Err(ParseError::ValidationErr("Variable must have a name"))
  }
  if view[1] >= b'0' && view[1] <= b'9' {
    return Err(
      ParseError::ValidationErr("Variable name must not start with a digit"),
    )
  }
  for i in 1..<n {
    let c = view[i]
    let ok = (c >= b'a' && c <= b'z') ||
      (c >= b'A' && c <= b'Z') ||
      (c >= b'0' && c <= b'9') ||
      c == b'_'
    if !ok {
      return Err(ParseError::ValidationErr("Invalid variable name character"))
    }
  }
  Ok(())
}

///|
/// 深验融合门（deep_validate 开时校验，关时直通；成功原样返还 view）
fn N3Materializer::gate_iri(
  self : N3Materializer,
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
fn N3Materializer::gate_bnode(
  self : N3Materializer,
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
/// 变量门（ADR-004：只记身份——语法面收紧在此）：`?` + varname，varname
/// 字符集 [A-Za-z0-9_]、首字符不许数字（N3 VARNAME 口径；词法 PrefName
/// 合成已保证 `?` 后零空格邻接，跨度由词法钉住，此处只收词形）。变量
/// 不进谓词位（表无行 + 验证层显式拒），不展开不绑定。
fn N3Materializer::gate_variable(
  self : N3Materializer,
  view : ArrayView[Byte],
) -> Result[ArrayView[Byte], ParseError] {
  if self.deep_validate {
    match check_variable_view(view) {
      Ok(_) => Ok(view)
      Err(e) => Err(e)
    }
  } else {
    Ok(view)
  }
}

///|
fn N3Materializer::gate_tt(
  self : N3Materializer,
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
fn N3Materializer::gate_literal(
  self : N3Materializer,
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
  // 引号体：转义序列合法性 + 闭引号定位（bad-esc / bad-string 桶）。
  // 贪左返回首个 quote_run 连续引号；三引号串闭定界向右扩到连跑尽头
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
  // W3C bad-string-06/07 口径：闭壳连跑被右扩且紧跟 @lang / ^^dt 后缀 → 非法；
  // 无后缀时扩并合法
  if close > close0 && close + quote_run < len {
    return Err(ParseError::ValidationErr("Malformed literal suffix"))
  }
  // \u/\U 孤代理；scalar_only（RDF 1.2 方言开关）：代理一律拒，成对也不收；
  // 1.1 宽容口径成对合法
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
    // langtag 全量 RFC 5646；RDF 1.2 方向后缀（小写精确）拆出后验基础标签
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
/// 深验引用三元组壳（term-kind 核验）：结构（项数=3、壳配对）parse 层已验；
/// 这里核验三个槽位的词项种类——主语拒字面量族；谓词只许 IRI/PrefName 形；
/// 宾语全种类合法。壳内 PrefName/相对 IRI 保持原文（壳整段保真不改写）
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

///|
/// fresh 结构节点身份（ADR-003a 简化版）：memo 出 `_:genid{offset}`。
/// 与 trig 的差异：无集合链序号分支（单一 BNode 无链节点，`(` 与 `[` 同型——
/// span 长度恒为开括号 token 长）。W3C 套件比对是图同构——标签只需文档内一致，
/// 且与用户 `_:x` 空间天然隔离
fn N3Materializer::fresh_bnode(
  self : N3Materializer,
  span : Span,
) -> ArrayView[Byte] {
  // 键 = 全 span (offset, length)
  match self.fresh_ids.get(span) {
    Some(memo) => return slice_span(self.arena[:], memo)
    None => ()
  }
  let start = self.arena.length()
  self.push_byte(b'_')
  self.push_byte(b':')
  self.push_str("genid\{span.0}")
  let memo = (start, self.arena.length() - start)
  self.fresh_ids[span] = memo
  slice_span(self.arena[:], memo)
}
