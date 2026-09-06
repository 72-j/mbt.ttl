# rdf-tests

本目录只存放 N3/Turtle 相关套件输入、suite runner 说明和回归预期说明。

## 目录定位

| 目录 | 是什么 | 裁决来源 | runner |
|---|---|---|---|
| `rdf-turtle/` | W3C rdf11 turtle 官方套件 | 文件名含 `-bad` = 负例 | `../rdf_suite_wbtest.mbt`（已钉 316/316） |
| `rdf12/rdf-turtle/syntax/` | W3C rdf12 turtle 官方套件 | 同上 | 同上（已钉 75/75） |
| `N3Tests/` | **W3C N3 官方套件（parser 子集）——N3 准绳** | `N3Tests/manifest-parser.ttl`（191 正语法 / 24 负语法 / 15 eval，230 项） | `../n3tests_suite_wbtest.mbt`（首扫打印未钉） |
| `examples/` | w3c/N3 仓库 examples/ 的 cwm 推理例程（13 件）——**冒烟料，非裁决源** | 无 manifest；预期见下文 | `../examples_wbtest.mbt`（打印未钉） |

**以 N3Tests 为准**：官方 manifest 驱动、正/负语法分类，与 turtle 套件 runner 的
good/bad 契约同构。examples 与 N3Tests 内容几乎零重叠（仅 time.n3 同名），
examples 保留作嵌套规则/内建谓词风格的冒烟覆盖。

## N3Tests 入库裁剪

全量在 `/home/thy/moonttl/bak/N3/tests/N3Tests`（36MB，含 28MB 机器生成证明料）。
包内只拷 manifest-parser 引用文件（`parser_index.tsv` 逐项记账：`kind<TAB>path`），
唯一超 100KB 的 `cwm_other/rdfcore-tests.n3` 以 `skip` 行排除（机器聚合料，
parser 裁决价值零）。净重 1.1MB / 227 个唯一 .n3。

## N3Tests 扫描成绩（2026-09-06，役10 后基线）

229 项（1 skip）：**负例 22 通过 / 2 漏收；正+eval 205 项 = 67 全净 + 108 仅物化错
（公式物化延后桶，解析零错）+ 30 解析失败**。役10 词位扩展前基线为
58 / 68 / 79（首扫 2026-09-06，役8 后）。

解析失败 30 文件按根因分桶（= 役候补清单，按体量排序；多面叠加文件按
首要阻挡归类）：

| 桶 | 根因 | 文件 | 件数 |
|---|---|---|---|
| 役6 尾 is/of | `is ... of` 在公式/嵌套内（役6 只开了顶层谓词位） | cwm_includes/{concat,conclusion,list-in}、cwm_list/append、cwm_list/last、cwm_other/dec-div、cwm_string/endsWith | 7 |
| D 量词 | `@forAll` / `@forSome`（词表有事件、表上无行，无行兜底错） | cwm_includes/{quantifiers,quantifiers_limited}、cwm_syntax/{qvars3,this-quantifiers-ref,this-rules-ref}、cwm_other/{classes,underbarscope}、cwm_unify/unify2 | 8 |
| B 路径主语位 | 顶层主位路径 `:albert!fam:mother fam:sister :x .` 无入口行（役3 尾巴） | cwm_syntax/{path1,path2}、cwm_reason/poor-urop、cwm_includes/xsd、cwm_math/math-test | 5 |
| C 新语法 token | `<-` 倒装谓词、iriPropertyList（空格分隔属性表 + `id` 键） | new_syntax/inverted_properties、iriPropertyList/*（5 件） | 6 |
| `has` 谓词关键词 | `verb ::= 'has' expression`（役6 `is..of` 的对称口，token 有行无表） | cwm_other/schema-rules | 1 |
| 空语句面 | 无宾语句 `?x .` / `<o>.` 直收——ExpectObject / FormulaExpectObject / ExpectSubject 空语句行未落（防负例回归，需钉负例对照） | cwm_other/{log-filter,smush-query} | 2 |
| A 尾 `[` 谓词位 | Lbracket 谓词入口未开（役10 同教义一行役：ta_args open_bnode_prop 谓词位） | cwm_other/anon-prop | 1 |
| E 负例漏收 | `@prefix foo:bar <>` qname 作前缀名应拒；`@keywords this` 后 `this` 主语应拒 | qname-as-prefix-in-decl、neg-thisadoc | 2（漏收，非解析失败） |
| F 公式物化 | 解析全过、物化层 `{` 无臂（已知延后桶，非解析失败） | equals1、formula-*、nested、sep-term 等 | 108 |

另有两档套件豁免见 `../rdf_suite_wbtest.mbt`：`n3_suite_n3_legal` 全净反转
10 文件（役6 extras-05 + 役7 extras-02/struct-02 + 役10 七文件：官方
bad-preds-*/neg-*-predicate 翻案 TestN3PositiveSyntax）、
`n3_suite_n3_legal_mat_deferred` 解析豁免 2 文件（bad-kw-04 主语字面量——
@nquads.Subject 无 literal 变体；extras-09 `=>` 谓词——规则谓词 pk 延后桶）。

## examples/ 回归预期（冒烟，随役推进升级）

役10 后（2026-09-06）：**13/13 解析零错**；全部物化错 = 桶 F（公式/规则物化
延后）。`time.n3` 已随役10 字面量主语行翻面。

## 钉纪律

首扫打印分桶 → 缺口逐役修 → 桶清零后钉闭包（turtle 套件同路径：failed==0 且
passed+failed==全量）。当前两 runner 均为打印态，钉住前不得改动裁决口径。
