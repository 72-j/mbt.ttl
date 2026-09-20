// ===== 示例/bench 冒烟（役 A 结构性裁决）：demo 管线直调，2026-09-20 =====
// examples/bench 包此前 0 测试宿主；提取冒烟入口后 wbtest 直调同链
// （main 只留进程态（argv/env）与文件 I/O 边界，本体进测试宿主）。

///|
async test "wb·示例冒烟：nquads 全链（写→读→解析→物化→序列化）" {
  demo_all()
}
