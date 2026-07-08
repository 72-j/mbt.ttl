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