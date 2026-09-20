// ===== 示例冒烟（役 A 结构性裁决）：demo 管线直调，2026-09-20 =====
// examples 包此前 0 测试宿主；提取 `demo_all` 后 wbtest 直调同链
// （解析 → 物化 → 序列化打印全链点亮；main 只留进程入口 2 行）。

///|
async test "wb·示例冒烟：n3 六 case 全链" {
  demo_all()
}
