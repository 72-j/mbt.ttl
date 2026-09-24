#!/bin/sh
# ===== 文档门（docs-check）：`guides/**` 的结构与可发现性（2026-09-24 立）=====
#
# 现代文档项目的四条底线，全部可机检（任一不满足即红）：
#   ① 每页**恰有一个 H1**（首个非空行是 `# `）；
#   ② 每页（索引页除外）**带导航行**（`> 指南：`）——保证任意页都能横跳回索引/同族；
#   ③ **相对 .md 链接零死链**（文档内互相引用必须可达）；
#   ④ 命名 **kebab-case**（`[a-z0-9][a-z0-9-]*.md`）——跨平台/URL 友好。
# 另附：每个非索引页必须被**其所在目录的 README**（或 guides/README.md）索引 ⇒ 防"孤岛页"。
set -u
cd "$(git rev-parse --show-toplevel)"
fail=0
bad() { echo "  ✗ $1"; fail=1; }
ok()  { echo "  ✓ $1"; }

n=0
for p in $(find guides -name '*.md' | sort); do
  n=$((n+1))
  # ① 恰一个 H1（**排除代码块**：语料/语法示例里的 `#` 注释不是标题）
  h1=$(awk '/^```/{f=!f; next} !f && /^# /{c++} END{print c+0}' "$p")
  [ "$h1" = "1" ] || bad "$p：H1 数 = $h1（应 1，已排除代码块）"
  # ④ 命名 kebab-case（README.md 是目录惯例名，豁免）
  b=$(basename "$p" .md)
  [ "$b" = "README" ] || printf '%s' "$b" | grep -qE '^[a-z0-9][a-z0-9-]*$' \
    || bad "$p：文件名非 kebab-case"
  # ② 导航行（索引页除外）
  [ "$p" = "guides/README.md" ] || grep -q '^> 指南：' "$p" || bad "$p：缺导航行（> 指南：）"
  # ③ 相对链接可达
  d=$(dirname "$p")
  for l in $(grep -oE '\]\([^)#]+\.md[^)]*\)' "$p" | sed 's/](//;s/)$//;s/#.*//'); do
    case "$l" in http*) continue ;; esac
    [ -e "$d/$l" ] || bad "$p → $l：死链"
  done
  # 孤岛页：非 README 必须被同目录 README 索引
  case "$(basename "$p")" in
    README.md) ;;
    *) grep -q "$(basename "$p")" "$d/README.md" 2>/dev/null || bad "$p：未被同目录 README 索引（孤岛页）" ;;
  esac
done

if [ "$fail" = "0" ]; then ok "guides/** 结构门通过（$n 页：H1 · 导航 · 零死链 · kebab-case · 无孤岛）"
else exit 1; fi
