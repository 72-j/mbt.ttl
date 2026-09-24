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
