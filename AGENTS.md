# MoonBit 项目开发指南

你是这个 MoonBit 项目的 AI 编程助手，请使用中文回复。

## 项目结构

- MoonBit 包按目录组织，每个目录包含一个 `moon.pkg` 文件，列出其依赖项。
- 每个包包含源文件和两类测试文件：
  - 黑盒测试：文件名以 `_test.mbt` 结尾
  - 白盒测试：文件名以 `_wbtest.mbt` 结尾
- 根目录下有 `moon.mod.json` 文件，包含模块元数据。

## 编码规范

- MoonBit 代码采用块（block）风格组织，每个块用 `///|` 分隔。块之间的顺序不重要。在进行某些重构时，可以独立地逐个处理块。
- 尽量将弃用的代码块放在每个目录的 `deprecated.mbt` 文件中。
- **注释分层**（2026-09-24 立；现代做法在注释上的体现**不是**"把黑话翻译成大白话"，而是**分层**）：
  ① **领域语义**（说做什么/为什么）——用大白话，**保留并补强**；
  ② **施工账**（役/钉/口径/裁定等）——**压成一行 + 指向入库卷**（`adr.md` / `spec.md` / `const.md` / `perf-review.txt`）；
     ⚠️ **前提**：被压的决策必须在入库卷里有记录 —— **没有就先补 ADR，再压注释**，否则压注释 = 删证据链；
  ③ **证据锚点**——只留必需的，**尽量用符号名**（ADR 号/函数名）替行号；写**全形** `X.mbt:NNN`（禁 `:NNN` 缩写），
     改锚点须同笔重生成本表 `.anchors/expected.tsv`（`ci/anchor-check.sh` 管）；
  ④ **历史**（沿革细节/旧役号）——删除或压进 ②。
  现行形态常见"② 太厚、① 偏薄" ⇒ 收窄方向 = **② 压一行，空间让给 ①**。

## 语言陷阱（2026-09-25 实测收录，jsonld_gen TOML 绑定器役；除标注外均编译器/运行期当场可复现）

- **无 `?` 错误传播**：Rust 式 `expr?` 后缀是解析错误（旧语法已弃）。`Result` 提前返回写显式
  `match ... { Ok(v) => v; Err(msg) => return Err(msg) }`。
- **`guard` 无 else 失败即 abort**：`guard cond`（不带 else）条件不成立时直接 panic（SIGABRT），
  是断言语义，**不是**循环过滤器。循环内"不满足就跳过"写 `if !cond { continue }`；
  要显式出路用 `guard cond else { ... }`（else 分支必须 return/raise/continue）。
- **泛型函数定义是 `fn[T] name(...)`**，不是 `fn name[T](...)`——后者解析错误
  （`unexpected 'fn f[T]', you may expect 'fn[T] f'`）。
- **`String::replace` 需标签参数**：`s.replace(old="a", new="b")`；位置传参报
  [4080]/[4086]（`old~`/`new~` 未提供）。
- **模式位不收单元字面量**：`Ok(())` 是解析错误（`unexpected token ')'`）；不关心载荷写 `Ok(_)`。
- **`String` 不自动升 `String?`**：形参是 `String?` 时须显式传 `Some(s)`，否则 [4014]
  （`has type String, wanted String?`）。
- **保留字族再证实（[0035]/[3002]）**：`local` 作参数名、`method` 作模式变量即
  [0035]；`type` 作字段名解析红——替代名 `local_context` / `handler_method` / `datatype`
- **模式位与 `is` 表达式位不收 struct 更新字面量**：`is Ok(T::{...})` 与 match 臂
  `T::{...} =>` 均解析红（[3002]/[4029]）——先绑定值再逐字段断言
- **`Array::make(n, init)` 对可变元素是同一引用填满所有槽**（运行期坑，编译器不报）：
  `Array::make(n, [])` 的 n 个槽共享同一个数组，push 一处全处可见；要独立槽用
  `for _ in 0..<n { arr.push([]) }` 逐个建。

## 工具使用指南

- 使用 `moon fmt` 格式化代码。
- 使用 `moon ide` 提供项目导航辅助，如跳转到定义（peek-def）、大纲（outline）和查找引用（find-references）。
- 使用 `moon info` 更新包的接口文件。每个包都有一个自动生成的接口文件 `.mbti`，它是该包的简要形式化描述。如果 `.mbti` 没有变化，说明你的修改对外部包用户不可见，通常是安全的重构。
- **提交前最后一步**：运行 `moon info && moon fmt` 更新接口并格式化代码。检查 `.mbti` 文件的 diff，确认修改符合预期。
- 运行 `moon test` 检查测试是否通过。MoonBit 支持快照测试；当输出变化时，运行 `moon test --update` 来刷新快照。
- 对于稳定或几乎不会变化的结果，优先使用 `assert_eq` 或 `assert_true(pattern is Pattern(...))` 进行断言测试。使用快照测试记录当前行为。对于确定性强的、明确定义的结果（如科学计算），优先使用断言测试。
- 使用 `moon coverage analyze > uncovered.log` 查看测试未覆盖的代码部分。

---

## 英文原文参考（保留技术术语）

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

### Project Structure

- MoonBit packages are organized per directory; each directory contains a `moon.pkg` file listing its dependencies. Each package has its files and blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in `_wbtest.mbt`).
- In the toplevel directory, there is a `moon.mod.json` file listing module metadata.

### Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`, the order of each block is irrelevant. In some refactorings, you can process block by block independently.
- Try to keep deprecated blocks in file called `deprecated.mbt` in each directory.

### Tooling

- `moon fmt` is used to format your code properly.
- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and `find-references`.
- `moon info` is used to update the generated interface of the package, each package has a generated interface file `.mbti`, it is a brief formal description of the package. If nothing in `.mbti` changes, this means your change does not bring the visible changes to the external package users, it is typically a safe refactoring.
- In the last step, run `moon info && moon fmt` to update the interface and format the code. Check the diffs of `.mbti` file to see if the changes are expected.
- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when changes affect outputs, run `moon test --update` to refresh snapshots.
- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that are stable or very unlikely to change. Use snapshot tests to record current behavior. For solid, well-defined results (e.g. scientific computations), prefer assertion tests.
- You can use `moon coverage analyze > uncovered.log` to see which parts of your code are not covered by tests.
