// n3gen 校验面：门清单（§5.13 役14 立，§5.14 役15 增 args 词表门）
// 自由文本禁引号/反斜杠（emit 行注直写不转义）/ 引用全解析 / (from,on) 唯一 /
// guard_def 白名单（ctx.* 表达式 或 裸字段名）/ assign 左值 ∈ 字段 /
// actions 按名升序（表源纪律）/ extras expr self. 门 / action_args 封闭词表

///|
/// 码点字典序比较（本工具链 String::compare 为长度优先序，不合名序门语义）
fn n3_str_cmp(a : String, b : String) -> Int {
  let n = if a.length() < b.length() {
    a.length()
  } else {
    b.length()
  }
  for i in 0..<n {
    let va = a[i].to_int()
    let vb = b[i].to_int()
    if va != vb {
      return va - vb
    }
  }
  a.length() - b.length()
}

///|
/// 自由文本门：emit 行注直写不转义，含 " 或 \ 的值污染生成注释——点名拒绝
fn n3_check_plain(s : String, where_ : String) -> Result[Unit, String] {
  for i in 0..<s.length() {
    let v = s[i].to_int()
    if v == 34 || v == 92 {
      return Err("\{where_}: 自由文本禁含引号/反斜杠（emit 行注直写不转义）")
    }
  }
  Ok(())
}

///|
/// effect 引用门：首标识符 ∈ effects 名（载荷变体/复合嵌套由 fsm codegen 把关）
fn n3_effect_head(eff : String) -> String {
  let mut n = 0
  for i in 0..<eff.length() {
    let v = eff[i].to_int()
    let is_alpha = v == 95 || (v >= 65 && v <= 90) || (v >= 97 && v <= 122)
    let is_digit = v >= 48 && v <= 57
    let ok = if n == 0 {
      is_alpha
    } else {
      is_alpha || is_digit
    }
    if ok {
      n = n + 1
    } else {
      break
    }
  }
  eff[:n].to_owned()
}


// ===== 主校验 =====

///|
pub fn n3gen_validate(
  base : N3BaseDef,
  trans : Array[N3TransDef],
) -> Result[Unit, String] {
  // meta：方言钉 n3（本编译器 v1 口径）
  let meta_ok = base.meta_name != "" && base.meta_dialect != "" && base.meta_prefix != "" && base.meta_trait != ""
  if meta_ok == false {
    return Err("[meta]: 必填键非空")
  }
  if base.meta_dialect != "n3" {
    return Err("[meta]: v1 只收 dialect = \"n3\"，见 \"\{base.meta_dialect}\"")
  }
  // enums：名唯一；variants 非空；自由文本门
  let seen_enum : Array[String] = []
  for e in base.enums {
    for s in seen_enum {
      if s == e.name {
        return Err("enums: 重名 \"\{e.name}\"")
      }
    }
    seen_enum.push(e.name)
    if e.variants.is_empty() {
      return Err("enums[\{e.name}]: variants 非空")
    }
    match e.doc {
      Some(d) =>
        match n3_check_plain(d, "enums[\{e.name}].doc") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
      None => ()
    }
  }
  // events：名唯一；payload 字段名唯一；类型自由文本门
  let seen_event : Array[String] = []
  for e in base.events {
    for s in seen_event {
      if s == e.name {
        return Err("events: 重名 \"\{e.name}\"")
      }
    }
    seen_event.push(e.name)
    let mut j = 0
    for f in e.payload {
      let mut k = 0
      for g in e.payload {
        if k < j && g.0 == f.0 {
          return Err("events[\{e.name}]: payload 重名 \"\{f.0}\"")
        }
        k = k + 1
      }
      match n3_check_plain(f.1, "events[\{e.name}].payload[\{f.0}].type") {
        Err(x) => return Err(x)
        Ok(_) => ()
      }
      j = j + 1
    }
  }

  // states：名唯一；is_initial 恰一
  let seen_state : Array[String] = []
  let mut n_initial = 0
  for s in base.states {
    for x in seen_state {
      if x == s.name {
        return Err("states: 重名 \"\{s.name}\"")
      }
    }
    seen_state.push(s.name)
    if s.is_initial {
      n_initial = n_initial + 1
    }
  }
  if n_initial != 1 {
    return Err("states: is_initial 恰一个，见 \{n_initial}")
  }
  // effects：名唯一；semantics 必填（interpret 分组依据）
  let seen_effect : Array[String] = []
  for e in base.effects {
    for s in seen_effect {
      if s == e.name {
        return Err("effects: 重名 \"\{e.name}\"")
      }
    }
    seen_effect.push(e.name)
    match e.semantics {
      Some(t) =>
        match n3_check_plain(t, "effects[\{e.name}].semantics") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
      None => return Err("effects[\{e.name}]: 缺 semantics")
    }
  }
  // context 字段名集合（fields ∪ frame_fields）：唯一性 + 引用底座
  let field_names : Array[String] = []
  for f in base.fields {
    for x in field_names {
      if x == f.name {
        return Err("context.fields: 重名 \"\{f.name}\"")
      }
    }
    field_names.push(f.name)
    match n3_check_plain(f.type_, "context.fields[\{f.name}].type") {
      Err(x) => return Err(x)
      Ok(_) => ()
    }
    match f.default {
      Some(d) =>
        match n3_check_plain(d, "context.fields[\{f.name}].default") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
      None => ()
    }
  }
  // frame_fields ⊆ fields（帧快照标记关系，非独立命名空间）：越界点名
  for fname in base.frame_fields {
    let mut ok = false
    for f in base.fields {
      if f.name == fname {
        ok = true
      }
    }
    if ok == false {
      return Err("context.frame_fields: \"\{fname}\" 不在 fields（子集标记关系）")
    }
  }
  // extras：名唯一；expr self. 门
  let seen_extra : Array[String] = []
  for x in base.extras {
    for y in seen_extra {
      if y == x.name {
        return Err("context.snapshot_extras: 重名 \"\{x.name}\"")
      }
    }
    seen_extra.push(x.name)
    if x.expr.has_prefix("self.") == false {
      return Err("snapshot_extras[\{x.name}]: expr 必须 self. 前缀，见 \"\{x.expr}\"")
    }
    match n3_check_plain(x.expr, "snapshot_extras[\{x.name}].expr") {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match x.reset {
      Some(r) =>
        match n3_check_plain(r, "snapshot_extras[\{x.name}].reset") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      None => ()
    }
    match x.comment {
      Some(c) =>
        match n3_check_plain(c, "snapshot_extras[\{x.name}].comment") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      None => ()
    }
  }

  // chains：resets ⊆ 字段集合；(enum,variant) 唯一；doc 门
  let seen_chain : Array[String] = []
  for c in base.chains {
    let key = "\{c.enum_name}.\{c.variant}"
    for s in seen_chain {
      if s == key {
        return Err("scope_chains: 重复 \"\{key}\"")
      }
    }
    seen_chain.push(key)
    for r in c.resets {
      let mut ok = false
      for f in field_names {
        if f == r {
          ok = true
        }
      }
      if ok == false {
        return Err("scope_chains[\{key}]: resets \"\{r}\" 不在字段集合")
      }
    }
    match c.doc {
      Some(d) =>
        match n3_check_plain(d, "scope_chains[\{key}].doc") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
      None => ()
    }
  }
  // actions：名唯一 + 按名升序（表源纪律）；comment 门
  let mut prev = ""
  for a in base.actions {
    if prev != "" && n3_str_cmp(prev, a.name) > 0 {
      return Err("actions: 须按名升序声明（\"\{prev}\" > \"\{a.name}\"）")
    }
    if prev == a.name {
      return Err("actions: 重名 \"\{a.name}\"")
    }
    prev = a.name
    match a.comment {
      Some(c) =>
        match n3_check_plain(c, "actions[\{a.name}].comment") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
      None => ()
    }
  }

  // transitions：引用全解析 + 逐行门
  for i, r in trans {
    let mut ok = false
    for s in seen_state {
      if s == r.from_state {
        ok = true
      }
    }
    if ok == false {
      return Err("transitions[\{i}]: from \"\{r.from_state}\" 不在 states")
    }
    ok = false
    for s in seen_state {
      if s == r.to_state {
        ok = true
      }
    }
    if ok == false {
      return Err("transitions[\{i}]: to \"\{r.to_state}\" 不在 states")
    }
    ok = false
    for s in seen_event {
      if s == r.on_event {
        ok = true
      }
    }
    if ok == false {
      return Err("transitions[\{i}]: on \"\{r.on_event}\" 不在 events")
    }
    match r.effect {
      Some(e) => {
        let head = n3_effect_head(e)
        ok = false
        for s in seen_effect {
          if s == head {
            ok = true
          }
        }
        if ok == false {
          return Err("transitions[\{i}]: effect 首 \"\{head}\" 不在 effects")
        }
        match n3_check_plain(e, "transitions[\{i}].effect") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
      }
      None => ()
    }

    // guard_def 白名单：ctx.* 表达式 或 裸字段名（真值读）
    match r.guard_def {
      Some(g) => {
        match n3_check_plain(g, "transitions[\{i}].guard_def") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
        if g.has_prefix("ctx.") == false {
          let mut is_field = false
          for f in field_names {
            if f == g {
              is_field = true
            }
          }
          if is_field == false {
            return Err(
              "transitions[\{i}]: guard_def 须 ctx.* 或字段名，见 \"\{g}\"",
            )
          }
        }
      }
      None => ()
    }
    // assign：左值 ∈ 字段集合（"字段=表达式"）
    match r.assign {
      Some(a) => {
        match n3_check_plain(a, "transitions[\{i}].assign") {
          Err(x) => return Err(x)
          Ok(_) => ()
        }
        let mut eq = -1
        for j in 0..<a.length() {
          if a[j].to_int() == 61 {
            eq = j
            break
          }
        }
        if eq <= 0 {
          return Err("transitions[\{i}]: assign 须 \"字段=表达式\"，见 \"\{a}\"")
        }
        let lhs = a[:eq].to_owned()
        let mut ok2 = false
        for f in field_names {
          if f == lhs {
            ok2 = true
          }
        }
        if ok2 == false {
          return Err("transitions[\{i}]: assign 左值 \"\{lhs}\" 不在字段集合")
        }
      }
      None => ()
    }
    for arg in r.action_args {
      match n3_check_plain(arg, "transitions[\{i}].action_args") {
        Err(x) => return Err(x)
        Ok(_) => ()
      }
    }
  }
  // (from,on) 唯一（C-02 v1 口径：n3 全表零守卫组，具名守卫组留 v2）
  let mut dup_at = -1
  for i in 0..<trans.length() {
    if dup_at == -1 {
      for j in 0..<i {
        let same = trans[j].from_state == trans[i].from_state && trans[j].on_event == trans[i].on_event
        if same {
          dup_at = i
          break
        }
      }
    }
  }
  if dup_at != -1 {
    return Err(
      "transitions[\{dup_at}]: (from,on) 重复（\{trans[dup_at].from_state} × \{trans[dup_at].on_event}）",
    )
  }
  // action_args 封闭词表门（emit 理解力=词表边界，出表即点名拒绝）
  match n3_check_args_vocab(base, trans) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(())
}

///|
/// action_args 封闭词表门：允许 none/true/false/payload/Some(payload)/
/// ctx.<字段>（须解析）/state:<状态>（须解析）/<Type>::<值>（形检）七形；
/// 生成器只做名字限定（§3 守卫转移定案口径），出词表的表达式属手写层
fn n3_check_args_vocab(
  base : N3BaseDef,
  trans : Array[N3TransDef],
) -> Result[Unit, String] {
  for i, t in trans {
    for j, a0 in t.action_args {
      let a = n3_expr_trim(a0)
      let ok = if a == "none" ||
        a == "true" ||
        a == "false" ||
        a == "payload" ||
        a == "Some(payload)" {
        true
      } else if a.has_prefix("ctx.") {
        match n3_find_field(base.fields, n3_expr_trim(a[4:a.length()].to_owned())) {
          Some(_) => true
          None => false
        }
      } else if a.has_prefix("state:") {
        let mut hit = false
        for s in base.states {
          if s.name == n3_expr_trim(a[6:a.length()].to_owned()) {
            hit = true
          }
        }
        hit
      } else if a.contains("::") {
        // <Type>::<值> 形检：恰一段 "::"，两侧非空（生成器不解析生成码命名空间）
        let seg = a.split("::").to_array()
        seg.length() == 2 && seg[0] != "" && seg[1] != ""
      } else {
        false
      }
      if not(ok) {
        return Err(
          "transitions[\{i}] action_args[\{j}]: \"\{a}\" 出封闭词表（允许 none/true/false/payload/Some(payload)/ctx.<字段>/state:<状态>/<Type>::<值>）",
        )
      }
    }
  }
  Ok(())
}
