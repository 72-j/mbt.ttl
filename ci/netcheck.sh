#!/bin/sh
# ===== CI-6 元门（子仓版）：净检出复跑（2026-09-23 立，CI 役）=====
#
# 为什么需要它：**本地绿 ≠ 净检出绿**——实测两类红只在干净的树上出现：
#   ① 净检出洞（测试读未入库文件；子仓侧当前 0 条）；
#   ② 行尾差异：Windows（`core.autocrlf=true`）把文本件检出成 CRLF ⇒
#      `n3tests_suite_wbtest` 读 `parser_index.tsv` 后按 `\n` 切行，路径带上 `\r`
#      ⇒ `OSError: ...D-ref.n3\r`（本脚本 `crlf` 口径逐条复现该红）。
#
# 用法：ci/netcheck.sh [lf|crlf] [-- <moon test 附加参数>]
#   lf   = core.autocrlf=false ≈ Linux/macOS 检出（抓净检出洞）
#   crlf = core.autocrlf=true  ≈ Windows 检出（抓行尾敏感；CI static 作业跑的档）
set -eu

mode="${1:-crlf}"
shift || true
[ "${1:-}" = "--" ] && shift || true
case "$mode" in
  lf) ac=false ;;
  crlf) ac=true ;;
  *) echo "用法: $0 [lf|crlf] [-- <moon test 参数>]" >&2; exit 2 ;;
esac

root="$(git rev-parse --show-toplevel)"
cd "$root"
tmp="$(mktemp -d)"
echo "[CI-6] 子仓净检出复跑：口径=$mode（core.autocrlf=$ac）· 临时=$tmp"

git clone -q -c core.autocrlf="$ac" "$root" "$tmp/sub"
[ -d "$root/.mooncakes" ] && cp -r "$root/.mooncakes" "$tmp/sub/.mooncakes"

if [ "$ac" = "true" ]; then
  crlf_n="$(cd "$tmp/sub" && git ls-files | while IFS= read -r f; do grep -qU "$(printf '\r')" "$f" 2>/dev/null && echo x; done | wc -l)"
  echo "[CI-6] CRLF 检出（被转换的文本件数）: $crlf_n（0 = 行尾已归一）"
fi

( cd "$tmp/sub" && moon test "$@" ) || { echo "[CI-6] 子仓红 ✗"; exit 1; }
echo "[CI-6] 子仓净检出复跑全绿 ✓（口径=$mode）"
