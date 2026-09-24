#!/bin/sh
# ===== 锚点漂移门（anchor drift gate）— B 案（注释分层）的安全基础（2026-09-24 立）=====
#
# 背景：仓内文档/注释用 `X.mbt:NNN` 指代码行（实测 **490 处**）。注释分层/压行会**移动行号** ⇒
# 锚点会无声失准。本门把"锚点是否仍指向原处"从**人肉**变成**门判**。
#
# 口径（诚实声明）：
#   · **解析口径**：① 锚点写**全形**（`X.mbt:NNN`）且 basename 唯一 ⇒ 直接解析；
#     ② 锚点写**方言限定形**（`gen_n3v2/actions.mbt:NNN` 等**带路径**）⇒ 按**路径后缀唯一匹配**解析；
#     ③ 裸 basename 而仓内多份、又未限定 ⇒ **跳过并计数**（这类须先"方言限定化"才可校）。
#   · 期望 = **目标行首 60 字**（首次运行 bootstrap 写入 `.anchors/expected.tsv`；dot 目录 ⇒ **不进发布包**）；
#   · 校验 = ① 引用处**仍写着该锚点**（引用被删/被改也必须同笔重生成本表，否则表会留下幽灵行）；
#             ② 目标行仍以期望片段开头；③ 锚点一律写全形 `X.mbt:NNN`（**禁 `:NNN` 缩写**，缩写在门视野外）。
#     不符即红（漂移/越界/目标不可读/引用消失都算）。
#   · 上游锚点在**主仓**（`bangto/world/jargon-map.spec.md`，69 处）不在本门视野 ⇒ 动那些锚点时须
#     在主仓侧同笔核对（本门只管子仓可见面）。
set -u
cd "$(git rev-parse --show-toplevel)"
mkdir -p .anchors
python3 - <<'PY'
import re,os,subprocess,collections,sys
TSV='.anchors/expected.tsv'
pat=re.compile(r'((?:[A-Za-z0-9_.-]+/)*[A-Za-z_][A-Za-z0-9_]*\.mbt):([0-9]+)')
mbts=subprocess.run(['git','ls-files','*.mbt'],capture_output=True,text=True).stdout.split()
by=collections.defaultdict(list)
for f in mbts: by[os.path.basename(f)].append(f)
docs=subprocess.run(['git','ls-files','*.md','*.txt'],capture_output=True,text=True).stdout.split()
rows=[]; skipped=0
for d in docs:
    if d.startswith('.anchors/'): continue
    try: lines=open(d,encoding='utf-8').read().split('\n')
    except Exception: continue
    for i,l in enumerate(lines):
        for m in pat.finditer(l):
            name,num=m.group(1),int(m.group(2))
            if '/' in name:
                cands=[f for f in mbts if f==name or f.endswith('/'+name)]
            else:
                cands=by.get(name,[])
            if len(cands)!=1: skipped+=1; continue
            rows.append((d,i+1,name,num,cands[0]))
if not os.path.exists(TSV):
    with open(TSV,'w',encoding='utf-8') as w:
        w.write('# 锚点期望快照（生成物：首次由 ci/anchor-check.sh bootstrap；改锚点须同笔重生成）\n')
        w.write('# 列：referrer<TAB>anchor<TAB>target<TAB>line<TAB>expected_prefix(60)\n')
        for d,ln,base,num,tgt in rows:
            try: tl=open(tgt,encoding='utf-8').read().split('\n')
            except Exception: continue
            if 1<=num<=len(tl):
                exp=tl[num-1].strip()[:60]
                w.write(f'{d}\t{base}:{num}\t{tgt}\t{num}\t{exp}\n')
    print(f'锚点门：**bootstrap** 写入 {TSV}（锚点总 {len(rows)} · 跳过 basename 不唯一 {skipped}）')
    raise SystemExit(0)
bad=[]; checked=0
for line in open(TSV,encoding='utf-8'):
    if line.startswith('#') or not line.strip(): continue
    parts=line.rstrip('\n').split('\t')
    if len(parts)<5: continue
    referrer,anchor,tgt,num,exp=parts[0],parts[1],parts[2],int(parts[3]),parts[4]
    try: tl=open(tgt,encoding='utf-8').read().split('\n')
    except Exception: bad.append(f'{referrer} {anchor} → 目标不可读'); continue
    try: rt=open(referrer,encoding='utf-8').read()
    except Exception: rt=''
    if anchor not in rt:
        bad.append(f'{referrer}：锚点 {anchor} 已不在引用处（同笔重生成本表或改回全形写法）'); continue
    if num<1 or num>len(tl): bad.append(f'{referrer} {anchor} → 越界（{tgt} 现 {len(tl)} 行）'); continue
    got=tl[num-1].strip()[:60]
    checked+=1
    if got!=exp: bad.append(f'{referrer} {anchor} → 漂移：期望 {exp!r} 实得 {got!r}')
print(f'锚点门：校 {checked} 条（跳过 basename 不唯一 {skipped}）· 失败 {len(bad)}')
for b in bad[:12]: print('  ✗',b)
if bad: raise SystemExit(1)
PY
