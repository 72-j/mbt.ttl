// n3gen 解析面：@toml 白名单解析（§5.3 未知段/未知键逐段拒绝，禁静默忽略）
// 助手移植 src/gen_md/gen/compiler.mbt（mdlex 试点同款门）

// ===== TOML 读取助手（mdlex 同款） =====

///|
fn n3_get_string(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> String? {
  match table.get(key) {
    Some(TomlString(s)) => Some(s)
    _ => None
  }
}

///|
fn n3_get_bool(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> Bool? {
  match table.get(key) {
    Some(TomlBoolean(b)) => Some(b)
    _ => None
  }
}

///|
fn n3_get_table(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> Map[String, @toml.TomlValue]? {
  match table.get(key) {
    Some(TomlTable(t)) => Some(t)
    _ => None
  }
}

///|
fn n3_get_tables(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> Array[Map[String, @toml.TomlValue]]? {
  match table.get(key) {
    Some(TomlArray(arr)) => {
      let out : Array[Map[String, @toml.TomlValue]] = []
      for v in arr {
        match v {
          TomlTable(t) => out.push(t)
          _ => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn n3_get_string_array(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> Array[String]? {
  match table.get(key) {
    Some(TomlArray(arr)) => {
      let out : Array[String] = []
      for v in arr {
        match v {
          TomlString(s) => out.push(s)
          _ => return None
        }
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn n3_get_payloads(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> Result[Array[(String, String)], String] {
  match table.get(key) {
    None => Ok([])
    Some(TomlArray(arr)) => {
      let out : Array[(String, String)] = []
      for i, v in arr {
        match v {
          TomlTable(pt) =>
            match (n3_get_string(pt, "name"), n3_get_string(pt, "type")) {
              (Some(n), Some(t)) => out.push((n, t))
              _ =>
                return Err(
                  "payload[\{i}] 缺 name/type（\{n3_inline_pt(pt)}）",
                )
            }
          _ => return Err("\{key} 必须是行内表数组")
        }
      }
      Ok(out)
    }
    Some(_) => Err("\{key} 必须是行内表数组")
  }
}

///|
fn n3_inline_pt(pt : Map[String, @toml.TomlValue]) -> String {
  let name = n3_get_string(pt, "name").unwrap_or("?")
  let typ = n3_get_string(pt, "type").unwrap_or("?")
  "\{name}:\{typ}"
}

///|
/// §5.3 未知键逐段拒绝（试点未收编键点名报错，禁止静默忽略）
fn n3_check_keys(
  table : Map[String, @toml.TomlValue],
  allowed : Array[String],
  where_ : String,
) -> Result[Unit, String] {
  for k, _ in table {
    let mut ok = false
    for a in allowed {
      if a == k {
        ok = true
      }
    }
    if ok == false {
      return Err("\{where_}: 未知键 \"\{k}\"（§5.3 禁止静默忽略）")
    }
  }
  Ok(())
}


// ===== base 段解析 =====

///|
pub fn n3gen_parse_base(content : String) -> Result[N3BaseDef, String] {
  let label = "n3_base.toml"
  let toml_val = try @toml.parse(content) catch {
    err => return Err("\{label}: TOML parse error: \{err}")
  } noraise {
    v => v
  }
  let table = match toml_val {
    TomlTable(t) => t
    _ => return Err("\{label}: 根必须是表")
  }
  // §5.3：未知顶层段拒绝（transitions 属 n3_trans.toml，base 不收）
  for k, _ in table {
    let mut ok = false
    for a in [
      "meta", "dialect", "events", "states", "effects", "scope_chains",
      "actions", "context",
    ] {
      if a == k {
        ok = true
      }
    }
    if ok == false {
      return Err("\{label}: 未知顶层段 \"\{k}\"（§5.3）")
    }
  }
  // [meta] 六键全必填非空
  let mt = match n3_get_table(table, "meta") {
    Some(t) => t
    None => return Err("\{label}: 缺 [meta]")
  }
  match n3_check_keys(
      mt,
      [
        "name", "dialect", "version", "prefix", "trait_name", "style",
      ],
      "[meta]",
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let meta_name = match n3_get_string(mt, "name") {
    Some(s) => s
    None => return Err("[meta]: 缺 name")
  }
  if meta_name == "" {
    return Err("[meta]: name 非空")
  }
  let meta_dialect = match n3_get_string(mt, "dialect") {
    Some(s) => s
    None => return Err("[meta]: 缺 dialect")
  }
  if meta_dialect == "" {
    return Err("[meta]: dialect 非空")
  }
  let meta_version = match n3_get_string(mt, "version") {
    Some(s) => s
    None => return Err("[meta]: 缺 version")
  }
  let meta_prefix = match n3_get_string(mt, "prefix") {
    Some(s) => s
    None => return Err("[meta]: 缺 prefix")
  }
  let meta_trait = match n3_get_string(mt, "trait_name") {
    Some(s) => s
    None => return Err("[meta]: 缺 trait_name")
  }
  let meta_style = match n3_get_string(mt, "style") {
    Some(s) => s
    None => return Err("[meta]: 缺 style")
  }

  // [dialect.<meta_dialect>]：capabilities + enums；dialect 表只许一个方言键
  let dt_root = match n3_get_table(table, "dialect") {
    Some(t) => t
    None => return Err("\{label}: 缺 [dialect.\{meta_dialect}]")
  }
  for k, _ in dt_root {
    if k != meta_dialect {
      return Err("\{label}: [dialect] 只允许方言键 \"\{meta_dialect}\"，见 \"\{k}\"")
    }
  }
  let dt = match n3_get_table(dt_root, meta_dialect) {
    Some(t) => t
    None => return Err("\{label}: 缺 [dialect.\{meta_dialect}]")
  }
  match n3_check_keys(dt, ["capabilities", "enums"], "[dialect]") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let capabilities : Array[String] = match n3_get_string_array(dt, "capabilities") {
    Some(a) => a
    None => []
  }
  let enums : Array[N3EnumDef] = []
  match n3_get_tables(dt, "enums") {
    Some(tables) =>
      for i, et in tables {
        match n3_check_keys(et, ["name", "doc", "variants", "emit"], "enums[\{i}]") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let ename = match n3_get_string(et, "name") {
          Some(s) => s
          None => return Err("enums[\{i}]: 缺 name")
        }
        let doc = n3_get_string(et, "doc")
        let variants = match n3_get_string_array(et, "variants") {
          Some(v) => v
          None => return Err("enums[\{i}]: 缺 variants")
        }
        let emit = match n3_get_bool(et, "emit") {
          Some(b) => b
          None => true
        }
        enums.push({ name: ename, doc, variants, emit })
      }
    None => ()
  }

  // [[events]] / [[states]] / [[effects]] / [[scope_chains]] / [[actions]]
  let events : Array[N3EventDef] = []
  match n3_get_tables(table, "events") {
    Some(tables) =>
      for i, et in tables {
        match n3_check_keys(et, ["name", "payload"], "events[\{i}]") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let ename = match n3_get_string(et, "name") {
          Some(s) => s
          None => return Err("events[\{i}]: 缺 name")
        }
        let payload = match n3_get_payloads(et, "payload") {
          Ok(p) => p
          Err(e) => return Err(e)
        }
        events.push({ name: ename, payload })
      }
    None => ()
  }

  let states : Array[N3StateDef] = []
  match n3_get_tables(table, "states") {
    Some(tables) =>
      for i, st in tables {
        match n3_check_keys(st, ["name", "is_initial"], "states[\{i}]") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let sname = match n3_get_string(st, "name") {
          Some(s) => s
          None => return Err("states[\{i}]: 缺 name")
        }
        let init = match n3_get_bool(st, "is_initial") {
          Some(b) => b
          None => false
        }
        states.push({ name: sname, is_initial: init })
      }
    None => ()
  }
  let effects : Array[N3EffectDef] = []
  match n3_get_tables(table, "effects") {
    Some(tables) =>
      for i, ef in tables {
        match n3_check_keys(ef, ["name", "semantics", "payload"], "effects[\{i}]") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let ename = match n3_get_string(ef, "name") {
          Some(s) => s
          None => return Err("effects[\{i}]: 缺 name")
        }
        let semantics = n3_get_string(ef, "semantics")
        let payload = match n3_get_payloads(ef, "payload") {
          Ok(p) => p
          Err(e) => return Err(e)
        }
        effects.push({ name: ename, semantics, payload })
      }
    None => ()
  }

  let chains : Array[N3ChainDef] = []
  match n3_get_tables(table, "scope_chains") {
    Some(tables) =>
      for i, ch in tables {
        match n3_check_keys(ch, ["enum", "variant", "resets", "doc"], "scope_chains[\{i}]") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let enum_name = match n3_get_string(ch, "enum") {
          Some(s) => s
          None => return Err("scope_chains[\{i}]: 缺 enum")
        }
        let variant = match n3_get_string(ch, "variant") {
          Some(s) => s
          None => return Err("scope_chains[\{i}]: 缺 variant")
        }
        let resets = match n3_get_string_array(ch, "resets") {
          Some(r) => r
          None => return Err("scope_chains[\{i}]: 缺 resets")
        }
        let doc = n3_get_string(ch, "doc")
        chains.push({ enum_name, variant, resets, doc })
      }
    None => ()
  }
  let actions : Array[N3TraitAction] = []
  match n3_get_tables(table, "actions") {
    Some(tables) =>
      for i, ac in tables {
        match n3_check_keys(ac, ["name", "params", "comment"], "actions[\{i}]") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let aname = match n3_get_string(ac, "name") {
          Some(s) => s
          None => return Err("actions[\{i}]: 缺 name")
        }
        let params = match n3_get_string_array(ac, "params") {
          Some(p) => p
          None => return Err("actions[\{i}]: 缺 params")
        }
        let comment = n3_get_string(ac, "comment")
        actions.push({ name: aname, params, comment })
      }
    None => ()
  }

  // [context]：frame_fields + fields + snapshot_extras
  let ct = match n3_get_table(table, "context") {
    Some(t) => t
    None => return Err("\{label}: 缺 [context]")
  }
  match n3_check_keys(ct, ["frame_fields", "fields", "snapshot_extras"], "[context]") {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let frame_fields : Array[String] = match n3_get_string_array(ct, "frame_fields") {
    Some(a) => a
    None => []
  }
  let fields : Array[N3FieldDef] = []
  match n3_get_tables(ct, "fields") {
    Some(tables) =>
      for i, ft in tables {
        match n3_check_keys(ft, ["name", "type", "default"], "context.fields[\{i}]") {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let fname = match n3_get_string(ft, "name") {
          Some(s) => s
          None => return Err("context.fields[\{i}]: 缺 name")
        }
        let ftype = match n3_get_string(ft, "type") {
          Some(s) => s
          None => return Err("context.fields[\{i}]: 缺 type")
        }
        let dflt = n3_get_string(ft, "default")
        fields.push({ name: fname, type_: ftype, default: dflt })
      }
    None => ()
  }
  let extras : Array[N3ExtraDef] = []
  match n3_get_tables(ct, "snapshot_extras") {
    Some(tables) =>
      for i, xt in tables {
        match n3_check_keys(
            xt,
            ["name", "type", "expr", "reset", "comment"],
            "context.snapshot_extras[\{i}]",
          ) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
        let xname = match n3_get_string(xt, "name") {
          Some(s) => s
          None => return Err("context.snapshot_extras[\{i}]: 缺 name")
        }
        let xtype = match n3_get_string(xt, "type") {
          Some(s) => s
          None => return Err("context.snapshot_extras[\{i}]: 缺 type")
        }
        let xexpr = match n3_get_string(xt, "expr") {
          Some(s) => s
          None => return Err("context.snapshot_extras[\{i}]: 缺 expr")
        }
        let reset = n3_get_string(xt, "reset")
        let comment = n3_get_string(xt, "comment")
        extras.push({ name: xname, type_: xtype, expr: xexpr, reset, comment })
      }
    None => ()
  }
  Ok({
    meta_name,
    meta_dialect,
    meta_version,
    meta_prefix,
    meta_trait,
    meta_style,
    capabilities,
    enums,
    events,
    states,
    effects,
    chains,
    actions,
    frame_fields,
    fields,
    extras,
  })
}


// ===== 转移段解析 =====

///|
pub fn n3gen_parse_trans(content : String) -> Result[Array[N3TransDef], String] {
  let label = "n3_trans.toml"
  let toml_val = try @toml.parse(content) catch {
    err => return Err("\{label}: TOML parse error: \{err}")
  } noraise {
    v => v
  }
  let table = match toml_val {
    TomlTable(t) => t
    _ => return Err("\{label}: 根必须是表")
  }
  for k, _ in table {
    if k != "transitions" {
      return Err("\{label}: 未知顶层段 \"\{k}\"（§5.3；只收 transitions）")
    }
  }
  let rows = match n3_get_tables(table, "transitions") {
    Some(t) => t
    None => return Err("\{label}: 缺 [[transitions]]")
  }
  let out : Array[N3TransDef] = []
  for i, r in rows {
    match n3_check_keys(
        r,
        [
          "from", "on", "to", "action", "guard_def", "effect", "assign",
          "action_args", "requires",
        ],
        "transitions[\{i}]",
      ) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    let from_state = match n3_get_string(r, "from") {
      Some(s) => s
      None => return Err("transitions[\{i}]: 缺 from")
    }
    let on_event = match n3_get_string(r, "on") {
      Some(s) => s
      None => return Err("transitions[\{i}]: 缺 on")
    }
    let to_state = match n3_get_string(r, "to") {
      Some(s) => s
      None => return Err("transitions[\{i}]: 缺 to")
    }
    let action = n3_get_string(r, "action")
    let guard_def = n3_get_string(r, "guard_def")
    let effect = n3_get_string(r, "effect")
    let assign = n3_get_string(r, "assign")
    let action_args : Array[String] = match n3_get_string_array(r, "action_args") {
      Some(a) => a
      None => []
    }
    let requires : Array[String] = match n3_get_string_array(r, "requires") {
      Some(a) => a
      None => []
    }
    out.push({
      from_state,
      on_event,
      to_state,
      action,
      guard_def,
      effect,
      assign,
      action_args,
      requires,
    })
  }
  Ok(out)
}
