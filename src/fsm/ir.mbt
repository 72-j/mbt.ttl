// ===== FSM IR Module =====
// 本模块定义了状态机中间表示（IR）的核心数据结构
// FsmIR 是整个系统的唯一事实来源

///|
pub struct FsmIR {
  version : Int
  events : Array[EventDef]
  states : Array[StateDef]
  transitions : Array[TransitionDef]
  // 语义索引：加速查找
  state_index : Map[String, Int] // 状态名 → ID (Int)
  event_index : Map[String, Int] // 事件名 → ID (Int)
}

///|
pub struct EventDef {
  id : Int
  name : String
  payload : Array[PayloadField] // 事件载荷字段（用于 codegen 生成带载荷的事件变体）
  metadata : Map[String, String]
}

///|
pub struct StateDef {
  id : Int
  name : String
  is_initial : Bool
  is_nestable : Bool
  parent : Int?
  exit_event : String?
  data_fields : Array[FieldDef]
  metadata : Map[String, String]
}

///|
pub struct FieldDef {
  name : String
  field_type : String
  default_value : String?
}

///|
pub struct TransitionDef {
  id : Int
  from_state : Int
  to_state : Int
  on_event : Int
  guard_def : GuardDef? // ✅ 改为 GuardDef
  action : String? // ✅ 改为 String（action 名称）
  metadata : Map[String, String]
}

///|
pub enum Severity {
  Error
  Warning
}

///|
pub struct Diag {
  rule : String
  severity : Severity
  message : String
  location : SourceLocation?
  suggestion : String?
}

///|
pub struct SourceLocation {
  filename : String
  line : Int
  column : Int
}

// ===== 构造函数 =====

///|
pub fn FsmIR::new() -> FsmIR {
  FsmIR::{
    version: 1,
    events: [],
    states: [],
    transitions: [],
    state_index: Map([]),
    event_index: Map([]),
  }
}

///|
pub fn FsmIR::add_event(
  self : FsmIR,
  name : String,
  payload? : Array[PayloadField] = [],
) -> (FsmIR, Int) {
  let id = self.events.length()
  let event = EventDef::{ id, name, payload, metadata: Map([]) }
  let events = self.events + [event]
  let event_index = self.event_index
  event_index.set(name, id)
  (FsmIR::{ ..self, events, event_index }, id)
}

///|
pub fn FsmIR::add_state(
  self : FsmIR,
  name : String,
  is_initial? : Bool = false,
  is_nestable? : Bool = false,
  exit_event? : String? = None,
  data_fields? : Array[FieldDef] = [],
) -> (FsmIR, Int) {
  let id = self.states.length()
  let state = StateDef::{
    id,
    name,
    is_initial,
    is_nestable,
    parent: None,
    exit_event,
    data_fields,
    metadata: Map([]),
  }
  let states = self.states + [state]
  let state_index = self.state_index
  state_index.set(name, id)
  (FsmIR::{ ..self, states, state_index }, id)
}

///|
pub fn FsmIR::add_transition(
  self : FsmIR,
  from_state : Int,
  to_state : Int,
  on_event : Int,
  guard_def? : GuardDef? = None,
  action? : String? = None,
) -> FsmIR {
  let id = self.transitions.length()
  let transition = TransitionDef::{
    id,
    from_state,
    to_state,
    on_event,
    guard_def,
    action,
    metadata: Map([]),
  }
  let transitions = self.transitions + [transition]
  FsmIR::{ ..self, transitions, }
}

///|
pub fn build_ir(
  states_meta : Array[StateMeta],
  events : Array[EventMeta],
  rules : Array[TransitionRule],
) -> FsmIR {
  let mut ir = FsmIR::new()

  // 添加事件并构建索引
  let event_ids = Map([])
  for event in events {
    let (new_ir, id) = ir.add_event(event.name, payload=event.payload)
    ir = new_ir
    event_ids.set(event.name, id)
  }

  // 添加状态并构建索引
  let state_ids = Map([])
  for meta in states_meta {
    let (new_ir, id) = ir.add_state(
      meta.name,
      is_initial=meta.is_initial,
      is_nestable=meta.is_nestable,
      exit_event=meta.exit_event,
    )
    ir = new_ir
    state_ids.set(meta.name, id)
  }

  // 添加转移
  for rule in rules {
    let from_id = state_ids.get(rule.from_state)
    let to_id = state_ids.get(rule.to_state)
    let on_id = event_ids.get(rule.on_event)

    match (from_id, to_id, on_id) {
      (Some(fid), Some(tid), Some(eid)) =>
        ir = ir.add_transition(
          fid,
          tid,
          eid,
          guard_def=rule.guard_def,
          action=rule.action,
        )
      _ => ()
    }
  }

  ir
}
