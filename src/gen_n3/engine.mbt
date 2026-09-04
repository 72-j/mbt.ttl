// ===== 用户补充：N3 主循环引擎骨架 =====
// 作用：在 step(ctx, event, actions) 上搭出输入消费、词法适应、Effect 解释、槽位重建的骨架。
// 约定：生成产物只包含可直接编译的最小驱动；解析语义与副作用执行由补充层补全。

///|
/// 词法源 trait：仅约束"逐 token 推进"的运行时接口（trig engine.mbt 同款）
/// 实现：N3LexerAdapter（lexer_adapter.mbt，包 @nquads.Lexermoon）
pub trait LexerSource {
  fn next(Self) -> N3Event? // 换行/注释已过滤；数据尾以 N3EOF 合法送达一次，其后 None=枯竭兜底
  fn pos(Self) -> Int // 当前词法位置（兜底错误定位用）
  fn byte_at(Self, Int) -> Byte // 数据直查（词内尾点裁决用）
}
// Step 4 表役时此处续：normalize_term_span / trim_trailing_dot（Lexermoon
// 吞边界口径的引擎层修正——Langtag/数值 token 零空格后随 `,`/`.` 时该字节
// 入 span 且标点事件丢失，词法自测 747 行故意钉此口径；trig 以 trim+synth_dot
// 兜底，N3 同款并扩 Comma/Semicolon 合成）。
