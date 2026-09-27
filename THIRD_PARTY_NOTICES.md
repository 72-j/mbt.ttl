# 第三方声明（Third-Party Notices）

本文件集中列出本仓**测试数据/派生断言**的第三方来源与许可，供发布包读者与合规审查使用。
本仓自身代码与文档的许可见 `LICENSE`（Apache-2.0）。

| # | 来源 | 用法 | 许可 | 我们如何遵守 |
|---|---|---|---|---|
| 1 | **W3C rdf-tests**（`w3c/rdf-tests`，commit `f172950b7c8b42a7d2618a7905bba521847249b1`） | `.rdf-tests/` 下**原样副本**（2439 件，`SHA256SUMS` 锁版）+ 抽取式 conformance 断言 | **W3C Test Suite License + W3C 3-clause BSD** | **不改动测试文件**（逐字节副本 + 校验和锁版）；README 已声明；仅用于测试 |
| 2 | **Apache Jena**（`jena-langtag`） | `src/gen_nquads/langtag_conformance_wbtest.mbt` 抽取的 canonicalization / bad 电池 | **Apache-2.0**（SPDX: `Apache-2.0`） | 保留版权与许可声明（见该件头注）；仅抽取**测试断言**，不引入其代码 |
| 3 | **Oxigraph**（`oxsdatatypes`：`float.rs` 等） | `src/gen_trig/literal_conformance_wbtest.mbt` 的**字面量/datatype 测试形态与边界** | **MIT OR Apache-2.0**（双许可；实证 = 本地副本 `LICENSE-MIT` + `LICENSE-APACHE` 双件 + `Cargo.toml` 声明，2026-09-27） | 仅作**测试形态参考**（不复制实现代码）；出处与许可写在该件头注 |

**维护条件**：新增任何"抽取自第三方测试/数据"的件，**必须同笔**在本表登记（来源 + 许可 + 遵守方式）+ 在源件头注写 `来源 + SPDX`。
**重评估**：若某源的许可条目变更（如 Oxigraph 由双许可改单许可），同步本表与源件头注。
