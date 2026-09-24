# `.rdf-tests/` — 一致性套件语料（**不出发布包**）

**这里是什么**：三个方言各自消费的 W3C / N3Tests 语料副本（nquads / n3v2 / trig 各一份，**不合并**——
各套件的收录子集不同）。

**为什么放在 dot 顶层目录**：`moon publish` 的打包面 = **git 跟踪的文件 ∧ 一切 dot 路径被排除**
（实证：打包 zip 内 dot 条目 = 0，`.github/` `.githooks/` 均不在包内；`moon publish --help` 无 include/exclude 旗标）。
迁到 dot 顶层后：**仓库里仍然自足**（套件照跑），**发布包瘦身 −90%**（迁移前 33.6 MB → 约 3.3 MB，
语料本身就是其中 30.3 MB）。

**谁读它**（改路径时只改这几处）：

- `src/gen_nquads/rdf_suite_wbtest.mbt`
- `src/gen_n3v2/rdf_suite_wbtest.mbt` · `examples_wbtest.mbt` · `n3tests_suite_wbtest.mbt`
- `src/gen_trig/rdf_suite_wbtest.mbt`

**边界（必读）**：本目录**不是**发布物；消费者装到 `thy1016/moonttl` 时拿不到语料 ⇒
包内自带的套件测试**本就不能在包内跑**（迁移前也一样：它们读的是仓库相对路径）。套件一律在**仓库**里跑。

**沿革**：2026-09-24 发版准备役从 `src/gen_{nquads,n3v2,trig}/rdf-tests/` 迁入；
`.gitattributes` 的 7 条"上游原样 CRLF 冻结"同步改到新路径（冻结语义不变）。

## Modifications & attribution（合规要点，2026-09-24）

- **未修改原件**：上游原始测试文件**逐字节未改**——本轮迁移只换路径，并加目录级 `* -text` 冻结 EOL
  （防 Windows 检出转换）；`SHA256SUMS` 对 **2414 件**语料做完整性锚。
- **新增派生件（非上游）**：`nquads/all_combined.nq`、`nquads/all_combined_nt.nt`（把官方单件**脚本拼接**
  成单文件，供"整合-vs-循环"对拍）；`SHA256SUMS` 亦覆盖它们 ⇒ 任何改动都会被校核抓到。
- **收录为子集**：本目录是**部分收录**（例：N3Tests 的 `rdfcore-tests.n3` 以 skip 行排除、
  `bad_prefix2` 依 `rdft:Rejected` 略过）——详见 `n3v2/adr.md` 与各 `rdf_suite_wbtest.mbt` 表头。
- **版权**：语料版权归 **W3C 及其贡献者**（各子树 `LICENSE`/`README` 与本声明并存；顶层指路页见 `LICENSE.md`）。
- **无背书**：W3C 名称与商标**不得**用于本项目的广告或宣传；各套件通过计数是**自测结果**，非 W3C 认证。
- **许可分流**：上游 **dual license**（W3C Test Suite License / W3C 3-clause BSD，二选一）；
  本目录语料**不适用**本项目根 `LICENSE` 的 Apache-2.0。
- **为什么在 dot 目录**：留仓库（套件照跑）但**不进发布包**（`moon publish` 打包面 = git 跟踪 ∧ 排除 dot 路径；
  实证：打包 zip 内 dot 条目 0、本目录条目 0）。⇒ 发布包不必随带语料许可证；若将来把语料放回包内，须随包带 `LICENSE`。
- **完整性校核（门）**：`sh ci/release-check.sh` 内含 `sha256sum -c .rdf-tests/SHA256SUMS`
  （macOS 回退 `shasum -a 256 -c`）⇒ **无声改语料即红**。
