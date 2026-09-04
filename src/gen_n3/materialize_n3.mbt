// ===== 用户补充：IR -> QuadSpan 物化层骨架 =====
// 作用：将 `engine.mbt` 产生的 `PendingQuad` 解释成可冻结输出的 `QuadSpan`。
// 约定：物化器仅执行已有槽位数据的展开与校验，不额外退出 FSM 状态机。
