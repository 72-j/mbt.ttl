// ===== FSM TOML Parser =====
// 本模块将 TOML 格式的状态机描述文件转换为 FsmIR

///|
pub fn parse_toml(content : String) -> Result[FsmIR, String] {
  let toml = try @toml.parse(content) catch {
    err => return Err("TOML parse error: \{err}")
  } noraise {
    v => v
  }

  match toml {
    TomlTable(table) => parse_table(table)
    _ => Err("Root must be a table")
  }
}

///|
fn parse_table(table : Map[String, @toml.TomlValue]) -> Result[FsmIR, String] {
  let mut ir = FsmIR::new()

  // 解析 version
  let version = match table.get("version") {
    Some(TomlInteger(v)) => v
    Some(v) => return Err("version must be integer, got: \{v.type_name()}")
    None => 1
  }
  let version = Int64::to_int(version)
  ir = FsmIR::{ ..ir, version, }

  // 解析 events (支持 [events] 表格式 或 [[events]] 数组格式)
  match table.get("events") {
    Some(TomlTable(events_table)) => {
      // [events] 格式：{ "Iri": {}, "BlankNode": {} }
      let (new_ir, _) = parse_events_from_table(ir, events_table)
      ir = new_ir
    }
    Some(TomlArray(events_array)) => {
      // [[events]] 格式：[{ name = "Iri" }, { name = "BlankNode" }]
      let (new_ir, _) = parse_events_from_array(ir, events_array)
      ir = new_ir
    }
    Some(v) =>
      return Err("events must be a table or array, got: \{v.type_name()}")
    None => ()
  }

  // 解析 states (支持 [states] 表格式 或 [[states]] 数组格式)
  match table.get("states") {
    Some(TomlTable(states_table)) => {
      let (new_ir, _) = parse_states_from_table(ir, states_table)
      ir = new_ir
    }
    Some(TomlArray(states_array)) => {
      let (new_ir, _) = parse_states_from_array(ir, states_array)
      ir = new_ir
    }
    Some(v) =>
      return Err("states must be a table or array, got: \{v.type_name()}")
    None => ()
  }

  // 解析 transitions
  match table.get("transitions") {
    Some(TomlArray(trans_array)) => {
      let new_ir = parse_transitions(ir, trans_array)
      ir = new_ir
    }
    Some(v) => return Err("transitions must be an array, got: \{v.type_name()}")
    None => ()
  }

  Ok(ir)
}

///|
fn parse_events_from_table(
  ir : FsmIR,
  table : Map[String, @toml.TomlValue],
) -> (FsmIR, Map[String, Int]) {
  let mut new_ir = ir
  let event_ids = Map([])

  for name, _ in table {
    let (updated_ir, id) = new_ir.add_event(name)
    new_ir = updated_ir
    event_ids.set(name, id)
  }

  (new_ir, event_ids)
}

///|
/// 从 [[events]] 数组格式解析事件
fn parse_events_from_array(
  ir : FsmIR,
  array : Array[@toml.TomlValue],
) -> (FsmIR, Map[String, Int]) {
  let mut new_ir = ir
  let event_ids = Map([])

  for item in array {
    match item {
      TomlTable(event_table) =>
        match event_table.get("name") {
          Some(TomlString(name)) => {
            let (updated_ir, id) = new_ir.add_event(name)
            new_ir = updated_ir
            event_ids.set(name, id)
          }
          _ => ()
        }
      _ => ()
    }
  }

  (new_ir, event_ids)
}

///|
fn parse_states_from_table(
  ir : FsmIR,
  table : Map[String, @toml.TomlValue],
) -> (FsmIR, Map[String, Int]) {
  let mut new_ir = ir
  let state_ids = Map([])

  for name, value in table {
    let is_initial = match value {
      TomlTable(state_table) =>
        match state_table.get("is_initial") {
          Some(TomlBoolean(v)) => v
          _ => false
        }
      _ => false
    }

    let (updated_ir, id) = new_ir.add_state(name, is_initial~)
    new_ir = updated_ir
    state_ids.set(name, id)
  }

  (new_ir, state_ids)
}

///|
/// 从 [[states]] 数组格式解析状态
fn parse_states_from_array(
  ir : FsmIR,
  array : Array[@toml.TomlValue],
) -> (FsmIR, Map[String, Int]) {
  let mut new_ir = ir
  let state_ids = Map([])

  for item in array {
    match item {
      TomlTable(state_table) =>
        match state_table.get("name") {
          Some(TomlString(name)) => {
            let is_initial = match state_table.get("is_initial") {
              Some(TomlBoolean(v)) => v
              _ => false
            }
            let (updated_ir, id) = new_ir.add_state(name, is_initial~)
            new_ir = updated_ir
            state_ids.set(name, id)
          }
          _ => ()
        }
      _ => ()
    }
  }

  (new_ir, state_ids)
}

///|
fn parse_transitions(ir : FsmIR, array : Array[@toml.TomlValue]) -> FsmIR {
  let mut new_ir = ir
  let state_ids = build_state_name_to_id_map(ir)
  let event_ids = build_event_name_to_id_map(ir)

  for value in array {
    match value {
      TomlTable(t) => {
        let from = get_string(t, "from").unwrap()
        let to = get_string(t, "to").unwrap()
        let on = get_string(t, "on").unwrap()

        let from_id = state_ids.get(from)
        let to_id = state_ids.get(to)
        let on_id = event_ids.get(on)

        match (from_id, to_id, on_id) {
          (Some(fid), Some(tid), Some(eid)) =>
            new_ir = new_ir.add_transition(fid, tid, eid)
          _ => ()
        }
      }
      _ => ()
    }
  }

  new_ir
}

///|
fn build_state_name_to_id_map(ir : FsmIR) -> Map[String, Int] {
  let map = Map([])
  for state in ir.states {
    map.set(state.name, state.id)
  }
  map
}

///|
fn build_event_name_to_id_map(ir : FsmIR) -> Map[String, Int] {
  let map = Map([])
  for event in ir.events {
    map.set(event.name, event.id)
  }
  map
}

///|
fn get_string(table : Map[String, @toml.TomlValue], key : String) -> String? {
  match table.get(key) {
    Some(TomlString(s)) => Some(s)
    _ => None
  }
}

// ===== Parse TOML to Intermediate Structure =====

///|
pub fn parse_raw(
  content : String,
) -> Result[
  (
    MetaDef,
    Array[StateMeta],
    Array[EventMeta],
    Array[TransitionRule],
    Array[EffectDef],
    ContextDef,
  ),
  String,
] {
  let toml = try @toml.parse(content) catch {
    err => return Err("TOML parse error: \{err}")
  } noraise {
    v => v
  }

  match toml {
    TomlTable(table) => parse_table_to_raw(table)
    _ => Err("Root must be a table")
  }
}

///|
/// 解析 [meta]：name / version / description / trait_name / default_effect / prefix。
/// prefix 未声明（或为空）时借用 name 派生：剔除特殊字符并转 PascalCase
fn parse_meta(table : Map[String, @toml.TomlValue]) -> MetaDef {
  match table.get("meta") {
    Some(TomlTable(meta_table)) => {
      let name = get_optional_string(meta_table, "name").unwrap_or("")
      let prefix = match get_optional_string(meta_table, "prefix") {
        Some(p) if p != "" => sanitize_to_pascal(p)
        _ => sanitize_to_pascal(name)
      }
      MetaDef::{
        name,
        version: get_optional_string(meta_table, "version").unwrap_or("0.1.0"),
        description: get_optional_string(meta_table, "description"),
        trait_name: get_optional_string(meta_table, "trait_name"),
        default_effect: get_optional_string(meta_table, "default_effect"),
        prefix,
        terminal_states: get_string_array(meta_table, "terminal_states"),
      }
    }
    _ =>
      // 无 [meta]：空前缀（生成代码不加命名空间，保持旧行为）
      MetaDef::{
        name: "",
        version: "0.1.0",
        description: None,
        trait_name: None,
        default_effect: None,
        prefix: "",
        terminal_states: [],
      }
  }
}

///|
/// 解析 [[events]] 中的 payload 字段：payload = [{ name = "iri", type = "Span" }]
fn parse_payload(
  event_table : Map[String, @toml.TomlValue],
) -> Array[PayloadField] {
  let payload = []
  match event_table.get("payload") {
    Some(TomlArray(fields)) =>
      for field in fields {
        match field {
          TomlTable(field_table) =>
            match
              (get_string(field_table, "name"), get_string(field_table, "type")) {
              (Some(name), Some(type_)) =>
                payload.push(PayloadField::{ name, type_ })
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  payload
}

///|
///|
fn parse_table_to_raw(
  table : Map[String, @toml.TomlValue],
) -> Result[
  (
    MetaDef,
    Array[StateMeta],
    Array[EventMeta],
    Array[TransitionRule],
    Array[EffectDef],
    ContextDef,
  ),
  String,
] {
  // 解析 [meta]：prefix 未声明时从 name 派生（剔除特殊字符转 PascalCase）
  let meta = parse_meta(table)

  // 解析 events (支持 [events] 表格式 或 [[events]] 数组格式)
  let events = match table.get("events") {
    Some(TomlTable(events_table)) => {
      let event_list = []
      for name, _ in events_table {
        // [events] 表格式不携带 payload
        event_list.push(EventMeta::{ name, payload: [] })
      }
      event_list
    }
    Some(TomlArray(events_array)) => {
      let event_list = []
      for item in events_array {
        match item {
          TomlTable(event_table) =>
            match event_table.get("name") {
              Some(TomlString(name)) => {
                let payload = parse_payload(event_table)
                event_list.push(EventMeta::{ name, payload })
              }
              _ => ()
            }
          _ => ()
        }
      }
      event_list
    }
    Some(v) =>
      return Err("events must be a table or array, got: \{v.type_name()}")
    None => []
  }

  // 解析 states (支持 [states] 表格式 或 [[states]] 数组格式)
  let states_meta = match table.get("states") {
    Some(TomlTable(states_table)) => {
      let state_list = []
      for name, value in states_table {
        let is_initial = match value {
          TomlTable(state_table) =>
            match state_table.get("is_initial") {
              Some(TomlBoolean(v)) => v
              _ => false
            }
          _ => false
        }
        state_list.push(StateMeta::{
          name,
          is_initial,
          is_nestable: false,
          exit_event: None,
        })
      }
      state_list
    }
    Some(TomlArray(states_array)) => {
      let state_list = []
      for item in states_array {
        match item {
          TomlTable(state_table) =>
            match state_table.get("name") {
              Some(TomlString(name)) => {
                let is_initial = match state_table.get("is_initial") {
                  Some(TomlBoolean(v)) => v
                  _ => false
                }
                state_list.push(StateMeta::{
                  name,
                  is_initial,
                  is_nestable: false,
                  exit_event: None,
                })
              }
              _ => ()
            }
          _ => ()
        }
      }
      state_list
    }
    Some(v) =>
      return Err("states must be a table or array, got: \{v.type_name()}")
    None => []
  }

  // 解析 transitions
  let rules = match table.get("transitions") {
    Some(TomlArray(trans_array)) => {
      let rule_list = []
      for value in trans_array {
        match value {
          TomlTable(t) =>
            // 使用模式匹配获取必需字段，允许返回错误
            match
              (get_string(t, "from"), get_string(t, "to"), get_string(t, "on")) {
              (Some(from), Some(to), Some(on)) => {
                let action = get_optional_string(t, "action")
                let guard_def = get_optional_string(t, "guard_def")
                let action = action
                let guard_def = match guard_def {
                  Some(g) if g != "" =>
                    Some(GuardDef::{ name: "guard", expression: Some(g) })
                  _ => None
                }
                rule_list.push(TransitionRule::{
                  from_state: from,
                  on_event: on,
                  to_state: to,
                  action,
                  guard_def,
                })
              }
              (from, to, on) => {
                // 构建详细的错误信息
                let missing = []
                if from.is_none() {
                  missing.push("from")
                }
                if to.is_none() {
                  missing.push("to")
                }
                if on.is_none() {
                  missing.push("on")
                }
                return Err("transition missing required fields: missing.join")
              }
            }
          _ => return Err("transition must be a table")
        }
      }
      rule_list
    }
    Some(v) => return Err("transitions must be an array, got: \{v.type_name()}")
    None => []
  }

  // 解析 [[effects]]：副作用意图定义（纯数据变体，可带 payload）
  let effects = match table.get("effects") {
    Some(TomlArray(effects_array)) => {
      let effect_list = []
      for item in effects_array {
        match item {
          TomlTable(effect_table) =>
            match effect_table.get("name") {
              Some(TomlString(name)) => {
                let payload = parse_payload(effect_table)
                let doc = get_optional_string(effect_table, "doc")
                effect_list.push(EffectDef::{ name, payload, doc })
              }
              _ => ()
            }
          _ => ()
        }
      }
      effect_list
    }
    Some(v) => return Err("effects must be an array, got: \{v.type_name()}")
    None => []
  }

  // 解析 [context]：Context 定义（struct_name + fields 数组，或 [[context]] 简写）
  let context = match table.get("context") {
    Some(TomlTable(ctx_table)) => {
      let struct_name = get_optional_string(ctx_table, "struct_name").unwrap_or(
        "",
      )
      let fields = match ctx_table.get("fields") {
        Some(TomlArray(fields_array)) => {
          // [context.fields]：[{ name = "subject", type = "Span?", default = "..." }]
          let field_list = []
          for item in fields_array {
            match item {
              TomlTable(field_table) =>
                match get_string(field_table, "name") {
                  Some(name) => {
                    let type_ = get_string(field_table, "type").unwrap_or(
                      "String",
                    )
                    let default = get_optional_string(field_table, "default")
                    field_list.push(ContextField::{ name, type_, default })
                  }
                  _ => ()
                }
              _ => ()
            }
          }
          field_list
        }
        Some(_) => return Err("context.fields must be an array")
        None => {
          // 无 fields：每个 key 视为 字段名 → 类型 的简写
          let field_list = []
          for name, value in ctx_table {
            if name == "struct_name" {
              continue
            }
            match value {
              TomlString(type_) =>
                field_list.push(ContextField::{ name, type_, default: None })
              _ => ()
            }
          }
          field_list
        }
      }
      ContextDef::{ struct_name, fields }
    }
    Some(TomlArray(ctx_array)) => {
      // [[context]] 数组简写：[{ name = "subject", type = "Span?" }]
      let field_list = []
      for item in ctx_array {
        match item {
          TomlTable(field_table) =>
            match get_string(field_table, "name") {
              Some(name) => {
                let type_ = get_string(field_table, "type").unwrap_or("String")
                let default = get_optional_string(field_table, "default")
                field_list.push(ContextField::{ name, type_, default })
              }
              _ => ()
            }
          _ => ()
        }
      }
      ContextDef::{ struct_name: "", fields: field_list }
    }
    Some(v) =>
      return Err("context must be a table or array, got: \{v.type_name()}")
    None => ContextDef::{ struct_name: "", fields: [] }
  }

  Ok((meta, states_meta, events, rules, effects, context))
}

///|
fn get_optional_string(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> String? {
  match table.get(key) {
    Some(TomlString(s)) => Some(s)
    _ => None
  }
}

///|
/// 读取字符串数组键（如 terminal_states = ["Complete"]）；缺省或类型不符返回 []
fn get_string_array(
  table : Map[String, @toml.TomlValue],
  key : String,
) -> Array[String] {
  match table.get(key) {
    Some(TomlArray(items)) => {
      let arr = []
      for item in items {
        match item {
          TomlString(s) => arr.push(s)
          _ => ()
        }
      }
      arr
    }
    _ => []
  }
}
