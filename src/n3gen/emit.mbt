// n3gen emit 面：声明面词表 → MoonBit 骨架直产（v2 表即文件，ADR-GEN-N3 §5.14 役15）
// 发射权威 = src/ttl/src/gen_n3/n3.mbt（G-MBT byte 对拍钉死）；推导逻辑端口 =
// src/fsm/codegen*.mbt（n3 特化：N3 前缀/mutable 契约/debug 关）。
// 时间戳改显式 ts 参数——测试钉同一 ts ⇒ 产物含 Generated-at 行全字节稳定（强幂等）。

///|
/// PascalCase 化（事件/状态名 → 变体名尾段；首字母已大写则原样）
fn n3_pascal(name : String) -> String {
  if name.length() > 0 {
    let first = name[0]
    if first >= 65 && first <= 90 {
      return name
    }
    let upper = (first - 32).to_char()
    return "\{upper}" + name[1:name.length()].to_owned()
  }
  name
}

///|
/// 生成类型保留名改写（整词，分隔符原样）：State→N3State 等；已限定名不动
fn n3_rw_type(t : String) -> String {
  let reserved = [
    "State", "Event", "Effect", "Context", "PendingQuad", "ActionError",
    "EffectError", "EffectOutcome", "EffectHandler", "LoopPolicy",
  ]
  let buf = StringBuilder::new()
  let mut word = ""
  for i in 0..<t.length() {
    let v = t[i].to_int()
    let is_alnum = (v >= 97 && v <= 122) || (v >= 65 && v <= 90) || (v >= 48 && v <= 57)
    if is_alnum {
      word = word + t[i].to_int().to_char().unwrap().to_string()
    } else {
      if word != "" && reserved.contains(word) {
        buf.write("N3")
      }
      buf.write(word)
      word = ""
      buf.write_char(t[i].to_int().to_char().unwrap())
    }
  }
  if word != "" && reserved.contains(word) {
    buf.write("N3")
  }
  buf.write(word)
  buf.to_string()
}

///|
/// Context 字段默认值：显式 default > `?` 尾 → None > 基础类型字面量
fn n3_field_default(t : String, d : String?) -> String {
  match d {
    Some(s) => s
    None => {
      let n = t.length()
      if n > 0 && t[n - 1] == '?' {
        return "None"
      }
      if t == "Int" {
        return "0"
      }
      if t == "Double" {
        return "0.0"
      }
      if t == "Bool" {
        return "false"
      }
      if t == "String" {
        return "\"\""
      }
      "None // TODO: 该类型无默认值，请手工补"
    }
  }
}

///|
/// 事件载荷类型签名：0→None；1→T；n→(A, B)
fn n3_event_payload_type(payload : Array[(String, String)]) -> String? {
  match payload.length() {
    0 => None
    1 => Some(payload[0].1)
    _ => {
      let types = payload.map(fn(f) { f.1 })
      Some("(\{types.join(", ")})")
    }
  }
}

///|
/// 多字段事件行内引用名：只消费首字段（N3Literal 双载荷口径）
fn n3_payload_arg_name(payload : Array[(String, String)]) -> String {
  if payload.length() > 1 {
    "payload0"
  } else {
    "payload"
  }
}

///|
/// 事件模式尾（忽略位）："" / "(_)" / "(_, _)"
fn n3_event_ignore_tail(payload : Array[(String, String)]) -> String {
  let n = payload.length()
  if n == 0 {
    ""
  } else {
    "(\{Array::make(n, "_").join(", ")})"
  }
}

///|
/// 事件模式尾（绑定位）："" / "(payload)" / "(payload0, _, …)"
fn n3_event_bind_tail(payload : Array[(String, String)]) -> String {
  match payload.length() {
    0 => ""
    1 => "(payload)"
    n => {
      let names = Array::makei(n, fn(i) { if i == 0 { "payload0" } else { "_" } })
      "(\{names.join(", ")})"
    }
  }
}

///|
/// 表达式两端空白剥除（词表 ASCII，码元口径）
fn n3_expr_trim(t : String) -> String {
  let is_ws = fn(v : Int) { v == 32 || v == 9 || v == 10 || v == 13 }
  let mut s = 0
  let mut e = t.length() - 1
  while s <= e && is_ws(t[s].to_int()) {
    s = s + 1
  }
  while e >= s && is_ws(t[e].to_int()) {
    e = e - 1
  }
  let buf = StringBuilder::new()
  for i in s..=e {
    buf.write_char(t[i].to_int().to_char().unwrap())
  }
  buf.to_string()
}

///|
/// 顶层逗号切分（括号感知，深度计数）
fn n3_split_top_level(text : String, sep : String) -> Array[String] {
  let parts : Array[String] = []
  let mut depth = 0
  let mut cur = StringBuilder::new()
  for i in 0..<text.length() {
    let ch = text[i].to_int().to_char().unwrap().to_string()
    if ch == "(" || ch == "[" {
      depth = depth + 1
      cur.write(ch)
    } else if ch == ")" || ch == "]" {
      depth = depth - 1
      cur.write(ch)
    } else if ch == sep && depth == 0 {
      parts.push(cur.to_string())
      cur = StringBuilder::new()
    } else {
      cur.write(ch)
    }
  }
  parts.push(cur.to_string())
  parts
}

///|
/// fmt 行宽折叠的 Ok(Sequence([...])) 语句（>80 才折叠；单行形恒等价）
fn n3_ok_stmt(eff : String, ind : String) -> String {
  let one = "\{ind}Ok(\{eff})"
  if one.length() > 80 && eff.has_prefix("N3Effect::Sequence([") && eff.has_suffix("])") {
    let inner = eff[20 : eff.length() - 2].to_owned()
    let mut out = "\{ind}Ok(\n\{ind}  N3Effect::Sequence([\n"
    for e in n3_split_top_level(inner, ",") {
      out = out + "\{ind}    \{n3_expr_trim(e)},\n"
    }
    out = out + "\{ind}  ]),\n\{ind})"
    out
  } else {
    one
  }
}

///|
/// 结构化解析 "Name(payload)"：(名头, 最外层括号段?)；裸名 → (text, None)
fn n3_parse_head(text : String) -> (String, String?) {
  let mut depth = 0
  let mut open_at = -1
  let mut close_at = -1
  for i in 0..<text.length() {
    let v = text[i].to_int()
    if v == 40 && depth == 0 && open_at < 0 {
      open_at = i
      depth = 1
    } else if v == 40 {
      depth = depth + 1
    } else if v == 41 {
      depth = depth - 1
      if depth == 0 && close_at < 0 {
        close_at = i
      }
    }
  }
  if open_at < 0 || close_at < 0 || close_at != text.length() - 1 {
    (text, None)
  } else {
    let s0 = open_at + 1
    (text[:open_at].to_owned(), Some(text[s0:close_at].to_owned()))
  }
}

///|
/// 绑定表达式翻译（封闭词表，args/assign/guard 共用；生成器只做名字限定）
fn n3_binding_expr(fields : Array[N3FieldDef], text : String) -> String {
  let t = n3_expr_trim(text)
  if t == "" {
    return t
  }
  if t == "none" {
    return "None"
  }
  if t.has_prefix("ctx.") {
    return t
  }
  if t.has_prefix("state:") {
    return "N3" + n3_pascal(t[6:t.length()].to_owned())
  }
  if t.contains("::") {
    return t
  }
  if t.has_prefix("Some(") && t.has_suffix(")") {
    let inner = t[5:t.length() - 1].to_owned()
    return "Some(\{n3_binding_expr(fields, inner)})"
  }
  if not(t.has_prefix("payload")) &&
    t != "event" &&
    t != "true" &&
    t != "false" &&
    t.contains(".") == false {
    // 裸标识符（字段名）：ctx 限定
    return "ctx.\{t}"
  }
  t
}

///|
/// 无 action 行的默认副作用意图：semantics == "continue" 的变体优先
fn n3_default_effect(base : N3BaseDef) -> String {
  for e in base.effects {
    match e.semantics {
      Some(t) => if t == "continue" { return e.name }
      None => ()
    }
  }
  "Continue"
}

///|
/// 转移行效果意图表达式：Name(payload) 结构化解析；集合载荷递归；
/// 载荷变体按效果声明类型限定
fn n3_effect_expr(base : N3BaseDef, text : String) -> String {
  let text = n3_expr_trim(text)
  let (name, payload_text) = n3_parse_head(text)
  let mut def : N3EffectDef? = None
  for e in base.effects {
    if e.name == name {
      def = Some(e)
      break
    }
  }
  match def {
    None => return "N3Effect::\{n3_default_effect(base)}"
    Some(d) => {
      let payload_t = if d.payload.length() > 0 { d.payload[0].1 } else { "" }
      match payload_text {
        None =>
          if payload_t == "" {
            "N3Effect::\{name}"
          } else if payload_t.has_prefix("Array[") {
            "N3Effect::\{name}([])"
          } else {
            "N3Effect::\{name}() // TODO(P0): effect 载荷需人工确认"
          }
        Some(pt) => {
          let pt = n3_expr_trim(pt)
          if pt.has_prefix("[") {
            let inner = pt[1:pt.length() - 1].to_owned()
            let elems = n3_split_top_level(inner, ",")
            let parts = elems.map(fn(s) { n3_effect_expr(base, s) })
            "N3Effect::\{name}([\{parts.join(", ")}])"
          } else if payload_t == "" {
            "N3Effect::\{name}(\{pt})"
          } else {
            "N3Effect::\{name}(\{n3_rw_type(payload_t)}::\{pt})"
          }
        }
      }
    }
  }
}

///|
/// 行侧写赋值语句（"字段=表达式" → "ctx.<字段> = <翻译后右值>"）
fn n3_assign_stmt(fields : Array[N3FieldDef], text : String) -> String {
  let mut eq_at = -1
  for i in 0..<text.length() {
    if text[i].to_int() == 61 {
      eq_at = i
      break
    }
  }
  if eq_at < 0 {
    return "// TODO(P0): assign 缺 '='（应为 \"字段=表达式\"）: \{text}"
  }
  let field = n3_binding_expr(fields, text[:eq_at].to_owned())
  let value = n3_binding_expr(fields, text[eq_at + 1:text.length()].to_owned())
  "\{field} = \{value}"
}

///|
/// 段拼装：非空段以空行相接，尾补换行（每段自身不带尾换行）
fn n3_join(parts : Array[String]) -> String {
  let kept : Array[String] = []
  for p in parts {
    if p != "" {
      kept.push(p)
    }
  }
  kept.join("\n\n") + "\n"
}

///|
/// 头横幅（ts 显式注入——强幂等口径）
fn n3_emit_banner(ts : String) -> String {
  "// ========================================\n// Generated by FSM Code Generator\n// Module: n3_fsm_gen\n// Generated at: \{ts}\n// DO NOT EDIT MANUALLY\n// ========================================"
}

///|
/// 方言段枚举（emit = true 才发射；变体裸名 + derive(Eq)）
fn n3_emit_enums(base : N3BaseDef) -> String {
  let parts : Array[String] = []
  for e in base.enums {
    if not(e.emit) {
      continue
    }
    let buf = StringBuilder::new()
    buf.write("// 生成器自动推导\n\n///|\n")
    match e.doc {
      Some(doc) => buf.write("/// \{doc}\n")
      None => ()
    }
    buf.write("pub(all) enum \{e.name} {\n")
    for j in 0..<e.variants.length() {
      buf.write("  \{e.variants[j]}")
      if j < e.variants.length() - 1 {
        buf.write("\n")
      }
    }
    buf.write("\n} derive(Eq)")
    parts.push(buf.to_string())
  }
  parts.join("\n\n")
}

///|
/// 事件枚举（变体名 N3+Pascal；载荷 → 变体参数）
fn n3_emit_events(base : N3BaseDef) -> String {
  let buf = StringBuilder::new()
  buf.write("///|\npub(all) enum N3Event {\n")
  for i in 0..<base.events.length() {
    let e = base.events[i]
    buf.write("  N3\{n3_pascal(e.name)}")
    // 多载荷签名 event_payload_type 已自带括号形 "(A, B)"，不得再包一层
    if e.payload.length() == 1 {
      buf.write("(\{n3_rw_type(e.payload[0].1)})")
    } else if e.payload.length() > 1 {
      let types = e.payload.map(fn(f) { n3_rw_type(f.1) })
      buf.write("(\{types.join(", ")})")
    }
    if i < base.events.length() - 1 {
      buf.write("\n")
    }
  }
  buf.write("\n}")
  buf.to_string()
}

///|
/// 状态枚举（53 变体裸列）
fn n3_emit_states(base : N3BaseDef) -> String {
  let buf = StringBuilder::new()
  buf.write("///|\npub(all) enum N3State {\n")
  for i in 0..<base.states.length() {
    buf.write("  N3\{n3_pascal(base.states[i].name)}")
    if i < base.states.length() - 1 {
      buf.write("\n")
    }
  }
  buf.write("\n}")
  buf.to_string()
}

///|
/// 收拾粒度枚举：变体 = scope_chains 声明序；行注释 = "清 X；保留 Y（doc）"
/// 保留集 = [context] 字段声明序 ∩ 链族 resets 并集 − 本变体 resets
fn n3_emit_scope(base : N3BaseDef) -> String {
  if base.chains.is_empty() {
    return ""
  }
  let union : Array[String] = []
  for c in base.chains {
    for f in c.resets {
      if not(union.contains(f)) {
        union.push(f)
      }
    }
  }
  let scope_fields : Array[String] = []
  for f in base.fields {
    if union.contains(f.name) {
      scope_fields.push(f.name)
    }
  }
  let buf = StringBuilder::new()
  buf.write("///|\n/// 重置粒度：每个变体显式列出\"清谁\"，未列字段一律保留（防错误重置）。\n/// 粒度不回头写 state —— state 由转移表的 to= 负责，两者正交。\npub(all) enum ResetScope {\n")
  for i in 0..<base.chains.length() {
    let c = base.chains[i]
    let keep : Array[String] = []
    for f in scope_fields {
      if not(c.resets.contains(f)) {
        keep.push(f)
      }
    }
    let mut line = "  \{c.variant} // 清 \{c.resets.join("/")}"
    if not(keep.is_empty()) {
      line = line + "；保留 \{keep.join("/")}"
    }
    match c.doc {
      Some(doc) => line = line + "（\{doc}）"
      None => ()
    }
    buf.write(line)
    if i < base.chains.length() - 1 {
      buf.write("\n")
    }
  }
  buf.write("\n} derive(Debug)")
  buf.to_string()
}

///|
/// Effect 枚举（载荷类型经保留名改写：State → N3State）
fn n3_emit_effects(base : N3BaseDef) -> String {
  let buf = StringBuilder::new()
  buf.write("///|\n/// Effect 枚举：状态机可能产生的副作用（纯数据）\npub(all) enum N3Effect {\n")
  for i in 0..<base.effects.length() {
    let e = base.effects[i]
    buf.write("  \{e.name}")
    match e.payload.length() {
      0 => ()
      1 => buf.write("(\{n3_rw_type(e.payload[0].1)})")
      _ => {
        let types = e.payload.map(fn(f) { n3_rw_type(f.1) })
        buf.write("(\{types.join(", ")})")
      }
    }
    if i < base.effects.length() - 1 {
      buf.write("\n")
    }
  }
  buf.write("\n}")
  buf.to_string()
}

///|
/// Context 面：struct + ::new + reset(scope) + PendingQuad + has_pending +
/// snapshot + LoopPolicy（emit_fields = 可空字段 ∩ 链族 resets 并集）
fn n3_emit_context(base : N3BaseDef) -> String {
  let fields = base.fields
  let extras = base.extras
  // emit 载荷声明的收拾粒度类型（semantics == "emit" 的首个载荷类型）
  let mut scope_decl = ""
  for e in base.effects {
    match e.semantics {
      Some(t) =>
        if t == "emit" && e.payload.length() == 1 {
          scope_decl = e.payload[0].1
          break
        }
      None => ()
    }
  }
  let chains : Array[N3ChainDef] = []
  for c in base.chains {
    if c.enum_name == scope_decl {
      chains.push(c)
    }
  }
  let mut chains_usable = not(chains.is_empty())
  for c in chains {
    for f in c.resets {
      let mut ok = false
      for fd in fields {
        if fd.name == f {
          ok = true
        }
      }
      if not(ok) {
        chains_usable = false
      }
    }
  }
  let buf = StringBuilder::new()
  // —— struct ——
  buf.write("///|\n/// FSM 运行时上下文：ctx 提供状态（state）与业务数据（其余字段）\npub(all) struct N3Context {\n  mut state : N3State\n")
  for f in fields {
    buf.write("  mut \{f.name} : \{n3_rw_type(f.type_)}\n")
  }
  buf.write("}\n\n")
  // —— ::new ——
  let mut initial = ""
  for s in base.states {
    if s.is_initial {
      initial = "N3\{n3_pascal(s.name)}"
      break
    }
  }
  if initial == "" && not(base.states.is_empty()) {
    initial = "N3\{n3_pascal(base.states[0].name)}"
  }
  if initial != "" {
    buf.write("///|\n/// 状态机初始上下文\npub fn N3Context::new() -> N3Context {\n  {\n")
    buf.write("    state: \{initial},\n")
    for f in fields {
      buf.write("    \{f.name}: \{n3_field_default(f.type_, f.default)},\n")
    }
    buf.write("  }\n}\n\n")
  }
  // —— reset(scope)：链驱动清槽（粒度不碰 state）——
  if chains_usable {
    buf.write("///|\n/// 原地重置：按 scope 清槽位，未列字段一律保留（粒度语义见 \{n3_rw_type(scope_decl)}）\npub fn N3Context::reset(self : N3Context, scope : \{n3_rw_type(scope_decl)}) -> Unit {\n  match scope {\n")
    for c in chains {
      // fmt 形：单语句臂不落花括号
      let stmts : Array[String] = []
      for f in c.resets {
        let mut fd : N3FieldDef? = None
        for x in fields {
          if x.name == f {
            fd = Some(x)
          }
        }
        match fd {
          Some(d) => stmts.push("self.\{f} = \{n3_field_default(d.type_, d.default)}")
          None => ()
        }
      }
      if stmts.length() == 1 {
        buf.write("    \{n3_rw_type(scope_decl)}::\{c.variant} => \{stmts[0]}\n")
      } else {
        buf.write("    \{n3_rw_type(scope_decl)}::\{c.variant} => {\n")
        for s in stmts {
          buf.write("      \{s}\n")
        }
        buf.write("    }\n")
      }
    }
    buf.write("  }\n}\n\n")
  }
  // —— 发射边界快照面：字段 = 可空字段 ∩ 链族 resets 并集 ——
  let emit_fields : Array[N3FieldDef] = []
  for f in fields {
    let n = f.type_.length()
    if n > 0 && f.type_[n - 1] == '?' {
      for c in chains {
        if c.resets.contains(f.name) {
          emit_fields.push(f)
          break
        }
      }
    }
  }
  if scope_decl != "" && not(emit_fields.is_empty()) {
    buf.write("///|\n/// 发射边界快照类型：发射槽位 span（offset,length）原样上抛，未切片。\n/// 主循环模板的返回载荷；组装与缺槽检测在切片组装层（用户区）。\n/// 字段只收链 resets 点名的发射槽——簿记槽位（prefix_name/base 族）不入快照。\npub(all) struct N3PendingQuad {\n")
    for f in emit_fields {
      buf.write("  \{n3_snap_name(f.name)} : \{n3_rw_type(f.type_)}\n")
    }
    for x in extras {
      buf.write("  \{x.name} : \{n3_rw_type(x.type_)}")
      match x.comment {
        Some(c) => buf.write(" // \{c}")
        None => ()
      }
      buf.write("\n")
    }
    buf.write("} derive(Eq)\n\n")
    buf.write("///|\n/// 发射槽位脏净判定：任一发射槽非空即有待发射残留（loop 的 EOF 收尾判据）\npub fn N3Context::has_pending(self : N3Context) -> Bool {\n")
    for i in 0..<emit_fields.length() {
      buf.write("  self.\{emit_fields[i].name} is Some(_)")
      if i < emit_fields.length() - 1 {
        buf.write(" ||")
      }
      buf.write("\n")
    }
    buf.write("}\n\n")
    buf.write("///|\n/// 发射槽位快照：ctx → 发射边界载荷（loop 模板发射点调用，字段映射随 ctx 生成）\npub fn N3Context::snapshot(self : N3Context) -> N3PendingQuad {\n")
    for x in extras {
      match x.reset {
        Some(r) => {
          buf.write("  let \{x.name} = \{x.expr}\n")
          buf.write("  \{x.expr} = \{r}\n")
        }
        None => ()
      }
    }
    buf.write("  {\n")
    for f in emit_fields {
      buf.write("    \{n3_snap_name(f.name)}: self.\{f.name},\n")
    }
    for x in extras {
      match x.reset {
        Some(_) => buf.write("    \{x.name},\n")
        None => buf.write("    \{x.name}: \{x.expr},\n")
      }
    }
    buf.write("  }\n}\n\n")
  }
  // —— LoopPolicy 模板 ——
  buf.write("///|\n/// 第三条业务面：LoopPolicy —— 主循环模板的领域钩子（生成契约，Engine 提供实现）。\n/// 循环骨架是固定模板（engine：入口/终止 → step 步进 → Effect 分发 → 错误降级），\n/// 领域知识（入口重置/行恢复/EOF 判脏/失败映射）全部收敛到本 trait。\npub trait N3LoopPolicy {\n  fn begin_record(Self) -> Unit\n  fn recover(Self, Span) -> Unit\n  fn finish_at_end(Self) -> Result[N3PendingQuad, ParseError]?\n  fn on_business_failed(Self, String) -> ParseError\n}")
  buf.to_string()
}

///|
/// 槽位 → 快照字段缩写（发射边界机器词表）
fn n3_snap_name(name : String) -> String {
  if name == "subject" {
    return "subj"
  }
  if name == "predicate" {
    return "pred"
  }
  if name == "object" {
    return "obj"
  }
  name
}

///|
/// 错误枚举（引擎错误 + 业务错误）
fn n3_emit_error_enum() -> String {
  "///|\n/// Action 执行或状态转移阶段的错误\npub(all) enum N3ActionError {\n  UnexpectedEvent(N3State, N3Event) // 状态机引擎抛出：当前状态未定义该事件的转移\n  BusinessFailed(String) // 用户业务逻辑抛出：Action 执行失败（如解析格式错误）\n}"
}

///|
/// 事件名 → 定义（线性查）
fn n3_find_event(base : N3BaseDef, name : String) -> N3EventDef? {
  for e in base.events {
    if e.name == name {
      return Some(e)
    }
  }
  None
}

///|
/// 字段名 → 定义（线性查）
fn n3_find_field(fields : Array[N3FieldDef], name : String) -> N3FieldDef? {
  for f in fields {
    if f.name == name {
      return Some(f)
    }
  }
  None
}

///|
/// WholeEvent 内部哨兵（值标识符禁大写开头；跨 fn 共享走顶层 fn）
fn n3_whole_mark() -> String {
  "\u{0}whole"
}

///|
/// action 参数形态（触发事件载荷逐位统一，只看首字段）
fn n3_action_param_type(
  base : N3BaseDef,
  trans : Array[N3TransDef],
  action : String,
) -> String {
  let mut param : String? = None
  for t in trans {
    match t.action {
      Some(a) =>
        if a == action {
          match n3_find_event(base, t.on_event) {
            Some(ev) => {
              let candidate = if ev.payload.is_empty() {
                ""
              } else {
                ev.payload[0].1
              }
              param = match param {
                None => Some(candidate)
                Some(p) =>
                  if p == candidate {
                    Some(p)
                  } else {
                    return n3_whole_mark()
                  }
                _ => return n3_whole_mark()
              }
            }
            None => ()
          }
        }
      None => ()
    }
  }
  match param {
    Some(p) => p
    None => ""
  }
}

///|
/// action_args 数据面签名推导：全部行声明 args 且等长时逐位统一类型；
/// 任一位无约束或候选冲突 → None（回退形态推导）
fn n3_action_args_param_types(
  base : N3BaseDef,
  trans : Array[N3TransDef],
  action : String,
) -> Array[String]? {
  let rows : Array[N3TransDef] = []
  for t in trans {
    match t.action {
      Some(a) => if a == action { rows.push(t) }
      None => ()
    }
  }
  if rows.is_empty() {
    return None
  }
  let n = rows[0].action_args.length()
  if n == 0 {
    return None
  }
  for t in rows {
    if t.action_args.length() != n {
      return None
    }
  }
  let unified : Array[String?] = Array::make(n, None)
  for t in rows {
    let payload_t : String? = match n3_find_event(base, t.on_event) {
      Some(ev) =>
        if ev.payload.is_empty() {
          None
        } else {
          Some(ev.payload[0].1)
        }
      None => None
    }
    for i in 0..<n {
      let a = n3_expr_trim(t.action_args[i])
      let candidate : String? = if a == "none" {
        None
      } else if a == "true" || a == "false" {
        Some("Bool")
      } else if a == "payload" {
        payload_t
      } else if a.has_prefix("Some(") && a.has_suffix(")") {
        match payload_t {
          Some(p) => Some("\{p}?")
          None => None
        }
      } else if a.has_prefix("ctx.") {
        let fname = n3_expr_trim(a[4:a.length()].to_owned())
        match n3_find_field(base.fields, fname) {
          Some(f) => Some(f.type_)
          None => None
        }
      } else if a.has_prefix("state:") {
        Some("State")
      } else if a.contains("::") {
        Some(a.split("::").to_array()[0].to_string())
      } else {
        None
      }
      match (unified[i], candidate) {
        (_, None) => ()
        (None, Some(c)) => unified[i] = Some(c)
        (Some(u), Some(c)) =>
          if u != c {
            return None
          }
        _ => ()
      }
    }
  }
  let out : Array[String] = []
  for x in unified {
    match x {
      Some(t) => out.push(t)
      None => return None
    }
  }
  Some(out)
}

///|
/// 签名行折叠（moon fmt 行宽口径：>80 在 `-> Result[` 后断，参数逐行缩进 4 + 尾逗号）
fn n3_fold_sig(name : String, params : String) -> String {
  let one_line = "  fn \{name}\{params} -> Result[N3Effect, N3ActionError]"
  if one_line.length() > 80 {
    return "  fn \{name}\{params} -> Result[\n    N3Effect,\n    N3ActionError,\n  ]"
  }
  one_line
}

///|
/// Actions trait：表驱动 action（触发序收集）+ 声明面直调 action（[[actions]] 追加）
fn n3_emit_actions_trait(base : N3BaseDef, trans : Array[N3TransDef]) -> String {
  let names : Array[String] = []
  for t in trans {
    match t.action {
      Some(a) => if not(names.contains(a)) { names.push(a) }
      None => ()
    }
  }
  let buf = StringBuilder::new()
  buf.write("///|\n/// Actions trait：actions 提供逻辑，Self 携带运行时数据\n/// 每个方法：(ctx, 事件载荷) → 副作用意图或错误（ctx 为原地写，state 由 step 管理）\npub trait N3Actions {\n")
  for name in names {
    let params = match n3_action_args_param_types(base, trans, name) {
      Some(ts) => {
        let rw = ts.map(fn(t) { n3_rw_type(t) })
        "(Self, N3Context, \{rw.join(", ")})"
      }
      None => {
        let p = n3_action_param_type(base, trans, name)
        if p == n3_whole_mark() {
          "(Self, N3Context, N3Event)"
        } else if p == "" {
          "(Self, N3Context)"
        } else {
          "(Self, N3Context, \{n3_rw_type(p)})"
        }
      }
    }
    buf.write(n3_fold_sig(name, params))
    buf.write("\n")
  }
  for da in base.actions {
    if names.contains(da.name) {
      continue
    }
    let params = if da.params.is_empty() {
      "(Self, N3Context)"
    } else {
      let rw = da.params.map(fn(t) { n3_rw_type(t) })
      "(Self, N3Context, \{rw.join(", ")})"
    }
    buf.write(n3_fold_sig(da.name, params))
    buf.write("\n")
  }
  buf.write("}")
  buf.to_string()
}

///|
/// step 驱动函数：match (state, event) 逐行发臂（mutable 契约：
/// 状态写入 → 行侧写 → action 尾调；effect 行不发 action；守卫行 if/else 包裹）
fn n3_emit_step(base : N3BaseDef, trans : Array[N3TransDef]) -> String {
  let fields = base.fields
  let buf = StringBuilder::new()
  buf.write("///|\n/// FSM Driver（mutable）：接收事件，原地推进 ctx，返回副作用意图或错误\n/// ctx 提供状态（mut，state 由本函数独占写入），event 提供数据，actions 提供逻辑\npub fn[A : N3Actions] step(\n  ctx : N3Context,\n  event : N3Event,\n  actions : A,\n) -> Result[N3Effect, N3ActionError] {\n  match (ctx.state, event) {\n")
  for t in trans {
    let from_name = "N3\{n3_pascal(t.from_state)}"
    let to_name = "N3\{n3_pascal(t.to_state)}"
    let ev = match n3_find_event(base, t.on_event) {
      Some(e) => e
      None => { let _ = buf; abort("unreachable: validate 已钉 on ∈ events") }
    }
    let event_name = "N3\{n3_pascal(ev.name)}"
    // 行修饰面
    let guard_text : String? = match t.guard_def {
      Some(g) => Some(n3_binding_expr(fields, g))
      None => None
    }
    let assign_line : String? = match t.assign {
      Some(s) => Some(n3_assign_stmt(fields, s))
      None => None
    }
    // 效果意图行：发射臂契约（无 action；载荷忽略模式）
    match t.effect {
      Some(eff) => {
        let expr = n3_effect_expr(base, eff)
        let pattern = "(\{from_name}, \{event_name}\{n3_event_ignore_tail(ev.payload)})"
        match guard_text {
          Some(g) => {
            buf.write("    \{pattern} =>\n      if \{g} {\n        ctx.state = \{to_name}\n")
            match assign_line {
              Some(l) => buf.write("        \{l}\n")
              None => ()
            }
            buf.write("\{n3_ok_stmt(expr, "        ")}\n      } else {\n        Err(N3ActionError::UnexpectedEvent(ctx.state, event))\n      }\n")
          }
          None => {
            buf.write("    \{pattern} => {\n      ctx.state = \{to_name}\n")
            match assign_line {
              Some(l) => buf.write("      \{l}\n")
              None => ()
            }
            buf.write("\{n3_ok_stmt(expr, "      ")}\n    }\n")
          }
        }
        continue
      }
      None => ()
    }
    let has_payload = n3_event_payload_type(ev.payload) is Some(_)
    // 行尾是否解构绑定 payload：args 显式引用，或无 args 且参数形态为 Payload
    let mut uses_payload = false
    for s in t.action_args {
      if s == "payload" || s.has_prefix("Some(") {
        uses_payload = true
      }
    }
    if not(uses_payload) && t.action_args.is_empty() {
      match t.action {
        Some(a) =>
          if n3_action_param_type(base, trans, a) != "" &&
            n3_action_param_type(base, trans, a) != n3_whole_mark() {
            uses_payload = true
          }
        None => ()
      }
    }
    match t.action {
      Some(action) => {
        let arg = if not(t.action_args.is_empty()) {
          let parts : Array[String] = []
          for s in t.action_args {
            let s2 = if s == "payload" {
              n3_payload_arg_name(ev.payload)
            } else {
              s
            }
            parts.push(n3_binding_expr(fields, s2))
          }
          parts.join(", ")
        } else {
          let p = n3_action_param_type(base, trans, action)
          if p != n3_whole_mark() && p != "" && has_payload {
            n3_payload_arg_name(ev.payload)
          } else if p == n3_whole_mark() && has_payload {
            "event"
          } else {
            ""
          }
        }
        let call = if arg == "" {
          "actions.\{action}(ctx)"
        } else {
          let one = "actions.\{action}(ctx, \{arg})"
          if one.length() + 6 > 80 {
            // fmt 行宽折叠：ctx 头参 + 其余参数逐行 + 尾逗号（args 无嵌套逗号，直切安全）
            let mut folded = "actions.\{action}(\n        ctx,\n"
            for a in n3_split_top_level(arg, ",") {
              folded = folded + "        \{n3_expr_trim(a)},\n"
            }
            folded = folded + "      )"
            folded
          } else {
            one
          }
        }
        let pattern = if has_payload && uses_payload {
          "(\{from_name}, \{event_name}\{n3_event_bind_tail(ev.payload)})"
        } else if has_payload {
          "(\{from_name}, \{event_name}\{n3_event_ignore_tail(ev.payload)})"
        } else {
          "(\{from_name}, \{event_name})"
        }
        match guard_text {
          Some(g) => {
            buf.write("    \{pattern} =>\n      if \{g} {\n        ctx.state = \{to_name}\n")
            match assign_line {
              Some(l) => buf.write("        \{l}\n")
              None => ()
            }
            buf.write("        \{call}\n      } else {\n        Err(N3ActionError::UnexpectedEvent(ctx.state, event))\n      }\n")
          }
          None => {
            buf.write("    \{pattern} => {\n      ctx.state = \{to_name}\n")
            match assign_line {
              Some(l) => buf.write("      \{l}\n")
              None => ()
            }
            buf.write("      \{call}\n    }\n")
          }
        }
      }
      None => {
        let pattern = "(\{from_name}, \{event_name}\{n3_event_ignore_tail(ev.payload)})"
        let default_effect = "N3Effect::\{n3_default_effect(base)}"
        match guard_text {
          Some(g) => {
            buf.write("    \{pattern} =>\n      if \{g} {\n        ctx.state = \{to_name}\n")
            match assign_line {
              Some(l) => buf.write("        \{l}\n")
              None => ()
            }
            buf.write("\{n3_ok_stmt(default_effect, "        ")}\n      } else {\n        Err(N3ActionError::UnexpectedEvent(ctx.state, event))\n      }\n")
          }
          None => {
            buf.write("    \{pattern} => {\n      ctx.state = \{to_name}\n")
            match assign_line {
              Some(l) => buf.write("      \{l}\n")
              None => ()
            }
            buf.write("\{n3_ok_stmt(default_effect, "      ")}\n    }\n")
          }
        }
      }
    }
  }
  buf.write("    (_, _) => Err(N3ActionError::UnexpectedEvent(ctx.state, event))\n  }\n}")
  buf.to_string()
}

///|
/// 第二层套装（EffectError + EffectHandler trait + handle_*/outcome/hook/
/// apply_scope/interpret/dispatch 全套默认 impl）——n3 词表语义门恒命中，
/// 固化 verbatim（fsm codegen 语义门模板的 n3 特化定格；变更随对拍显式翻新）
fn n3_emit_handler_suite() -> String {
  $|///|
$|/// 副作用执行阶段的错误（第二层）
$|pub(all) enum N3EffectError {
$|  SinkFailed(String) // 下游写入失败（可恢复）
$|  Fatal(String) // 致命错误，需要终止状态机
$|}
$|
$|///|
$|/// 第二层 EffectHandler：真正的 match effect 发生在 step 外部
$|/// handle_* 模板方法默认 Ok(())；dispatch 默认解构意图并分发
$|/// 用户 impl 覆盖需要的 handle_*，通常无需覆盖 dispatch
$|pub trait N3EffectHandler {
$|  fn handle_continue(Self) -> Result[Unit, N3EffectError] = _
$|  fn handle_emit_quad(Self, ResetScope) -> Result[Unit, N3EffectError] = _
$|  fn handle_reset(Self, ResetScope) -> Result[Unit, N3EffectError] = _
$|  fn handle_done(Self) -> Result[Unit, N3EffectError] = _
$|  fn handle_sequence(Self, Array[N3Effect]) -> Result[Unit, N3EffectError] = _
$|  fn handle_pop_bnp(Self) -> Result[Unit, N3EffectError] = _
$|  fn handle_open_slot(Self, Span, SlotType, N3State) -> Result[
$|    Unit,
$|    N3EffectError,
$|  ] = _
$|  // —— 用户补充面：组装机械（业务落点，必须实现）——
$|  fn snapshot(Self, ctx : N3Context) -> N3PendingQuad
$|  fn apply_scope(Self, ctx : N3Context, scope : ResetScope) -> Unit = _
$|  fn on_exit_graph(Self) -> Unit = _
$|  fn on_pop_bnp(Self, ctx : N3Context) -> Unit = _
$|  fn on_open_slot(
$|    Self,
$|    ctx : N3Context,
$|    span : Span,
$|    typ : SlotType,
$|    ret_state : N3State,
$|  ) -> Unit = _
$|  // —— 模板面：interpret 默认实现（TrigEngine::next 解释序同源抽取）——
$|  fn interpret(Self, ctx : N3Context, effect : N3Effect) -> N3EffectOutcome = _
$|  fn dispatch(Self, effect : N3Effect) -> Result[Unit, N3EffectError] = _
$|}
$|
$|///|
$|/// handle_continue 模板默认：无操作
$|impl N3EffectHandler with fn handle_continue(_self) {
$|  Ok(())
$|}
$|
$|///|
$|/// handle_emit_quad 模板默认：无操作
$|impl N3EffectHandler with fn handle_emit_quad(_self, _scope) {
$|  Ok(())
$|}
$|
$|///|
$|/// handle_reset 模板默认：无操作
$|impl N3EffectHandler with fn handle_reset(_self, _scope) {
$|  Ok(())
$|}
$|
$|///|
$|/// handle_done 模板默认：无操作
$|impl N3EffectHandler with fn handle_done(_self) {
$|  Ok(())
$|}
$|
$|///|
$|/// handle_sequence 模板默认：无操作
$|impl N3EffectHandler with fn handle_sequence(_self, _effects) {
$|  Ok(())
$|}
$|
$|///|
$|/// handle_pop_bnp 模板默认：无操作
$|impl N3EffectHandler with fn handle_pop_bnp(_self) {
$|  Ok(())
$|}
$|
$|///|
$|/// handle_open_slot 模板默认：无操作
$|impl N3EffectHandler with fn handle_open_slot(_self, _span, _typ, _ret_state) {
$|  Ok(())
$|}
$|
$|///|
$|/// 单个效果的解释结果（loop 级控制流意图）
$|pub(all) enum N3EffectOutcome {
$|  KeepGoing // 无产出，继续循环
$|  YieldQuad(N3PendingQuad) // 上抛一个组装好的 pending quad
$|  Stop // 终止循环
$|}
$|
$|///|
$|/// on_exit_graph 模板默认：Sequence 内嵌退图（无帧机械时无操作）
$|impl N3EffectHandler with fn on_exit_graph(_self) {
$|  ()
$|}
$|
$|///|
$|/// on_pop_bnp 模板默认：Sequence 内嵌钩子（无帧机械时无操作）
$|impl N3EffectHandler with fn on_pop_bnp(_self, _ctx) {
$|  ()
$|}
$|
$|///|
$|/// on_open_slot 模板默认：Sequence 内嵌钩子（无帧机械时无操作）
$|impl N3EffectHandler with fn on_open_slot(_self, _ctx, _span, _typ, _ret_state) {
$|  ()
$|}
$|
$|///|
$|/// apply_scope 模板默认：[[scope_chains]] 展开的收拾链
$|/// （逐字段清槽，粒度不碰 state——state 由转移表 to= 负责）
$|impl N3EffectHandler with fn apply_scope(_self, ctx, scope) {
$|  match scope {
$|    ResetScope::Object => ctx.object = None
$|    ResetScope::PredObj => {
$|      ctx.predicate = None
$|      ctx.object = None
$|    }
$|    ResetScope::SPO => {
$|      ctx.subject = None
$|      ctx.predicate = None
$|      ctx.object = None
$|    }
$|    ResetScope::All => {
$|      ctx.subject = None
$|      ctx.predicate = None
$|      ctx.object = None
$|      ctx.graph = None
$|    }
$|  }
$|}
$|
$|///|
$|/// interpret 模板默认：TrigEngine::next 解释序的同源抽取。
$|/// 臂按语义分组发射；用户补充 snapshot / apply_scope 后即得完整解释器
$|impl N3EffectHandler with fn interpret(self, ctx, effect) {
$|  match effect {
$|    N3Effect::Continue => KeepGoing
$|    N3Effect::PopBnp | N3Effect::OpenSlot(_, _, _) => KeepGoing
$|    N3Effect::Reset(scope) => {
$|      self.apply_scope(ctx, scope)
$|      KeepGoing
$|    }
$|    N3Effect::EmitQuad(scope) => {
$|      let pending = self.snapshot(ctx)
$|      self.apply_scope(ctx, scope)
$|      YieldQuad(pending)
$|    }
$|    N3Effect::Sequence(effects) => {
$|      // 意图串列：顺序解释；emit 组装暂存后继续执行余下意图
$|      let mut pending : N3PendingQuad? = None
$|      for sub in effects {
$|        match sub {
$|          N3Effect::EmitQuad(scope) => {
$|            pending = Some(self.snapshot(ctx))
$|            self.apply_scope(ctx, scope)
$|          }
$|          N3Effect::Reset(scope) => self.apply_scope(ctx, scope)
$|          N3Effect::PopBnp => self.on_pop_bnp(ctx)
$|          N3Effect::OpenSlot(span, typ, ret_state) =>
$|            self.on_open_slot(ctx, span, typ, ret_state)
$|          N3Effect::Done => break
$|          _ => ()
$|        }
$|      }
$|      match pending {
$|        Some(q) => YieldQuad(q)
$|        None => KeepGoing
$|      }
$|    }
$|    N3Effect::Done => Stop
$|  }
$|}
$|
$|///|
$|/// dispatch 模板默认：match effect 并分发到 handle_*
$|impl N3EffectHandler with fn dispatch(self, effect) {
$|  match effect {
$|    Continue => self.handle_continue()
$|    EmitQuad(scope) => self.handle_emit_quad(scope)
$|    Reset(scope) => self.handle_reset(scope)
$|    Done => self.handle_done()
$|    Sequence(effects) => self.handle_sequence(effects)
$|    PopBnp => self.handle_pop_bnp()
$|    OpenSlot(span, typ, ret_state) =>
$|      self.handle_open_slot(span, typ, ret_state)
$|  }
$|}
}

///|
/// v2 主入口：声明面词表 → MoonBit 骨架直产（fmt 后形；段序 = fsm generate 组装序）
pub fn n3gen_emit_mbt(
  base : N3BaseDef,
  trans : Array[N3TransDef],
  ts : String,
) -> String {
  n3_join([
    n3_emit_banner(ts),
    n3_emit_enums(base),
    n3_emit_events(base),
    n3_emit_states(base),
    n3_emit_scope(base),
    n3_emit_effects(base),
    n3_emit_context(base),
    n3_emit_error_enum(),
    n3_emit_actions_trait(base, trans),
    n3_emit_step(base, trans),
    n3_emit_handler_suite(),
  ])
}

///|
/// v2 编译入口：parse → validate（含 action_args 封闭词表门）→ emit
/// 产物 = n3.mbt 全文；fsm cmd 自 n3 管线除役（§5.14 步6）
pub fn n3gen_build(
  base_src : String,
  trans_src : String,
  ts : String,
) -> Result[String, String] {
  let base = match n3gen_parse_base(base_src) {
    Ok(b) => b
    Err(e) => return Err(e)
  }
  let trans = match n3gen_parse_trans(trans_src) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  match n3gen_validate(base, trans) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(n3gen_emit_mbt(base, trans, ts))
}
