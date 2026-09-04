// ===== 人工维护面占位 =====
// 类型桩清单由 CLI 维护（首跑 bootstrap）；本包真实类型定义在 type.mbt
// （Span = (Int, Int) 别名 / TermType / QuadSpan）。此占位文件存在即让
// CLI 的 types.mbt 桩守卫持续跳过，防桩声明与真实定义重名冲突。
