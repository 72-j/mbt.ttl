#!/bin/sh
# ===== 发版预检（release pre-flight）— 子仓 0.3.0（2026-09-24 立，发版准备役）=====
#
# 用途：把 `release-checklist.md` 的「发版日会用到的事实」收成**一条命令**——
#   发版日只需：`sh ci/release-check.sh` ⇒ 全 PASS 后按 §发版日序 执行 `moon publish`。
#
# 判据纪律（与 `const.md` §6.5 / 清单红线同）：
#   · 数字必须与**入库复核表**逐字节一致（红线 #4 可对外复现）——本脚本用"重生成 + 比对"，不眼睛看；
#   · 退出码**不是**发布判据（moon 0.1.20260920 的 `publish --dry-run` 在服务器 202 后仍 exit≠0）；
#     发布成功判据 = dry-run 输出含 "Dry run completed successfully" / 真发布 = 注册表回查新版本在册；
#   · 任一 FAIL 即 exit 1（"缺一不发"）。
#
# 覆盖：版本三处一致 · check --deny-warn · fmt 零 offender · `.mbti` 漂移 ·
#       面一/面三 复现一致 · 覆盖率棘轮 ≥ 基线 · 可达账缺口 0 · 双档测试（wasm/native）·
#       `moon publish --dry-run` 服务器验收文本 · 注册表槽位（当前版本 vs 上架最新版）。
set -u
cd "$(git rev-parse --show-toplevel)"
fail=0
ok()   { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=1; }
chk()  { if [ "$1" = "0" ]; then ok "$2"; else bad "$2"; fi; }

echo "== 1. 版本三处一致（moon.mod = CHANGELOG = README 指向）=="
ver="$(sed -nE 's/^version *= *"([^"]+)".*/\1/p' moon.mod | head -1)"
echo "  version = $ver"
[ -n "$ver" ] && grep -q "^## $ver" CHANGELOG.md
chk $? "CHANGELOG 有 '## $ver' 段"
grep -q "CHANGELOG" README.md
chk $? "README 版本沿革指向 CHANGELOG"

echo "== 2. 静态门 =="
moon check --deny-warn >/dev/null 2>&1
chk $? "moon check --deny-warn"
n="$(moon fmt --warn 2>&1 | sed -n 's/^File not formatted: //p' | wc -l | tr -d ' ')"
[ "$n" = "0" ]
chk $? "moon fmt --warn 零 offender（实得 $n）"
moon info >/dev/null 2>&1
[ -z "$(git status --porcelain -- '*.mbti')" ]
chk $? ".mbti 无漂移"

echo "== 3. 复核面复现（重生成 ≡ 入库，逐字节）=="
g1="$(mktemp)"; { for d in n3v2 nquads trig; do echo "[$d]"; moon test src/gen_$d 2>&1 | grep -oE '=== [^"]+ ===' | sed 's/^=== //;s/ ===$//' | sort -u; done; } > "$g1"
ref1="$(mktemp)"; grep -v '^#' suite-review.txt | sed '/^$/d' > "$ref1"
diff -q "$ref1" "$g1" >/dev/null
chk $? "面一 suite-review.txt 可复现"

moon clean >/dev/null 2>&1; moon coverage clean >/dev/null 2>&1; moon test --enable-coverage >/dev/null 2>&1
sum="$(moon coverage report -f summary | tail -n 1)"
g3="$(mktemp)"; { echo "[行覆盖]"; printf '%s\n' "$sum"; echo "[可达命令名覆盖]"; moon test 2>&1 | grep -o '可达覆盖账 [a-z0-9]*[^：]*：分母 [0-9]* / 分子 [0-9]* / 缺口 [0-9]* / 不可达 [0-9]*' | sort -u; } > "$g3"
ref3="$(mktemp)"; grep -v '^#' coverage-review.txt | sed '/^$/d' > "$ref3"
diff -q "$ref3" "$g3" >/dev/null
chk $? "面三 coverage-review.txt 可复现（$sum）"

echo "== 4. 棘轮与可达账 =="
cov="$(printf '%s' "$sum" | sed -nE 's/^Total: ([0-9]+)\/([0-9]+)$/\1 \2/p')"
cur=$(( $(echo "$cov" | awk '{print $1}') * 1000 / $(echo "$cov" | awk '{print $2}') ))
base="$(sed -nE 's/^covered_permille *= *([0-9]+).*/\1/p' coverage-baseline.txt | head -1)"
[ "$cur" -ge "$base" ]
chk $? "覆盖率棘轮 ${cur}‰ ≥ 基线 ${base}‰"
# 多字节字面量交给 grep（与上面捕获可达行同款口径；sed 的 `.*缺口` 在 dash/locale 下不稳）
miss="$(grep -o '缺口 [0-9]*' "$g3" | grep -o '[0-9]*' | sort -u | tr '\n' ' ')"
[ "$(grep -o '缺口 [0-9]*' "$g3" | grep -o '[0-9]*' | sort -u | tr -d '\n ')" = "0" ]
chk $? "三方言可达账缺口全 0（实得：$miss）"

echo "== 5. 双档测试（wasm / native）=="
w="$(moon test 2>&1 | tail -1)"; nv="$(moon test --target native 2>&1 | tail -1)"
printf '%s' "$w" | grep -q "failed: 0"; chk $? "wasm：$w"
printf '%s' "$nv" | grep -q "failed: 0"; chk $? "native：$nv"

echo "== 6. 发布路径（服务器验收 / 注册表槽位）=="
out="$(moon publish --dry-run 2>&1 || true)"
printf '%s\n' "$out" | grep -q "Dry run completed successfully"
chk $? "dry-run 服务器验收（认文本不认退出码）"
slot="$(curl -s -m 20 "https://mooncakes.io/api/v0/search?kw=moonttl" 2>/dev/null | grep -o '"version":"[^"]*"' | head -3 | tr '\n' ' ')"
[ -n "$slot" ] && ok "注册表查询可达：$slot" || bad "注册表查询不可达（网络/代理？）"

echo "== 7. 语料完整性（.rdf-tests 未被无声改动）=="
# 合规：一旦改了上游原件内容，W3C Test Suite License 分支下的"性能声明"权利即失效 ⇒ 用哈希锚住。
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c .rdf-tests/SHA256SUMS --quiet >/dev/null 2>&1
  chk $? "SHA256SUMS 校核通过（$(wc -l < .rdf-tests/SHA256SUMS) 件；改动须同笔重生成清单并在 NOTICE 声明）"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 -c .rdf-tests/SHA256SUMS >/dev/null 2>&1
  chk $? "SHA256SUMS 校核通过（shasum 回退；$(wc -l < .rdf-tests/SHA256SUMS) 件）"
else
  bad "无 sha256sum/shasum 可用 ⇒ 语料完整性未校核"
fi

echo "== 8. 文档门（guides/** 结构：H1 / 导航 / 零死链 / 命名 / 无孤岛）=="
sh ci/docs-check.sh >/dev/null 2>&1
chk $? "sh ci/docs-check.sh（详见其输出）"

echo "== 9. 锚点漂移门（文档/注释里的 *.mbt:NNN 是否仍指向原处）=="
sh ci/anchor-check.sh >/dev/null 2>&1
chk $? "sh ci/anchor-check.sh（改锚点须同笔重生成本表）"

echo
if [ "$fail" = "0" ]; then
  echo "== 发版预检全绿 ✓ 按 release-checklist.md §发版日序 执行 =="
else
  echo "== 有 FAIL：缺一不发（见上：✗ 行）=="; exit 1
fi
