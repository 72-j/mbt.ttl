// n3gen 数据结构：声明面词表模型（声明序 = IR 段序）
// 门与口径：ADR §5.13 役14 v1（base+trans 两文件、guard_def 内联直落、§5.3 白名单）

///|
/// 方言段枚举（[[dialect.n3.enums]]）
pub(all) struct N3EnumDef {
  name : String
  doc : String?
  variants : Array[String]
  emit : Bool // 缺省 true；显式只允许 emit = false
}

///|
pub(all) struct N3EventDef {
  name : String
  payload : Array[(String, String)]
}

///|
pub(all) struct N3StateDef {
  name : String
  is_initial : Bool
}

///|
pub(all) struct N3EffectDef {
  name : String
  semantics : String?
  payload : Array[(String, String)]
}

///|
pub(all) struct N3ChainDef {
  enum_name : String
  variant : String
  resets : Array[String]
  doc : String?
}

///|
pub(all) struct N3TraitAction {
  name : String
  params : Array[String]
  comment : String?
}

///|
pub(all) struct N3FieldDef {
  name : String
  type_ : String
  default : String?
}

///|
pub(all) struct N3ExtraDef {
  name : String
  type_ : String
  expr : String
  reset : String?
  comment : String?
}

///|
/// base 段全量（meta + dialect + 词表 + context；transitions 独立文件）
pub(all) struct N3BaseDef {
  meta_name : String
  meta_dialect : String
  meta_version : String
  meta_prefix : String
  meta_trait : String
  meta_style : String
  capabilities : Array[String]
  enums : Array[N3EnumDef]
  events : Array[N3EventDef]
  states : Array[N3StateDef]
  effects : Array[N3EffectDef]
  chains : Array[N3ChainDef]
  actions : Array[N3TraitAction]
  frame_fields : Array[String]
  fields : Array[N3FieldDef]
  extras : Array[N3ExtraDef]
}

///|
/// 转移行（扁平形；声明序 = 发射序）
pub(all) struct N3TransDef {
  from_state : String
  on_event : String
  to_state : String
  action : String?
  guard_def : String?
  effect : String?
  assign : String?
  action_args : Array[String]
  requires : Array[String]
}
