#!/bin/sh
# ===== 锚点漂移门（anchor drift gate）— B 案（注释分层）的安全基础（2026-09-24 立）=====
#
# 背景：仓内文档/注释用 `X.mbt:NNN` 指代码行（实测 **490 处**）。注释分层/压行会**移动行号** ⇒
# 锚点会无声失准。本门把"锚点是否仍指向原处"从**人肉**变成**门判**。
#
# 口径（诚实声明）：
#   · **解析口径**：① 锚点写**全形**（`X.mbt:NNN`）且 basename 唯一 ⇒ 直接解析；
#     ② 锚点写**方言限定形**（`gen_n3v2/actions.mbt:NNN` 等**带路径**）⇒ 按**路径后缀唯一匹配**解析；
#     ③ **相对锚（2026-09-25 役5 新增能力）**：同一行里紧跟全形锚之后的 `:NNN` 继承该锚的目标文件
#        （`gen_trig/engine.mbt:227` / `:240` / `:314` 这种表行写法自此**可校**）；
#     ④ 裸 basename 而仓内多份、又未限定 ⇒ **跳过并计数**（这类须先"方言限定化"才可校）。
#   · **扫描面（2026-09-25 役5 起）**：`*.md` / `*.txt` / **`*.mbt`**（注释里的锚点同权；
#     代价：注释锚会随再生/格式化漂动，红了即说明该处该重钉或改符号名）。
#   · 期望 = **目标行首 60 字**（首次运行 bootstrap 写入 `.anchors/expected.tsv`；dot 目录 ⇒ **不进发布包**）；
#   · 校验 = ① 引用处**仍写着该锚点**（引用被删/被改也必须同笔重生成本表，否则表会留下幽灵行）；
#             ② 目标行仍以期望片段开头（相对锚的"引用处"检查退化为"该数仍在引用文件里"，见 ③）。
#     不符即红（漂移/越界/目标不可读/引用消失都算）。
#   · ⚠ **已知债（2026-09-25 役5 首跑照出）**：扩面后新增 **59 行**里有 **32 行当下即指错**
#     （trig/nquads/n3v2 三卷的 `:NNN` 相对锚表整片漂，例：`gen_nquads/ctx.md` 表行指到 `}`）。
#     这批**未在本笔修**（属重钉笔）⇒ 快照现状 = "冻结在错行上"：门只能保它们**不再继续漂**，
#     并不主张它们是对的。**重钉清单**在 `todo.md` §AP.41（役6），修完同笔重生本表。
#   · 上游锚点在**主仓**（`bangto/world/jargon-map.spec.md`，69 处）不在本门视野 ⇒ 动那些锚点时须
#     在主仓侧同笔核对（本门只管子仓可见面）。
#   · ⚠ **bootstrap 盲区（2026-09-24 役3 实证）**：首跑只照"文档写的行号"取**当时那行**做期望 ⇒
#     **既存漂移会被冻结成期望**（门绿但锚点早已指错）。故 bootstrap 前须**先人工正锚一次**；
#     役3 已按此正过 `actions.mbt` 族（6 处：`spec.md` `:529/:719/:976`、`ctx.md` `:370/:1115`、`adr.md` `:929`）。
set -u
cd "$(git rev-parse --show-toplevel)"
mkdir -p .anchors
python3 - <<'PY'
import re,os,subprocess,collections,sys
TSV='.anchors/expected.tsv'
pat=re.compile(r'((?:[A-Za-z0-9_.-]+/)*[A-Za-z_][A-Za-z0-9_]*\.mbt):([0-9]+)')
rel=re.compile(r':([0-9]+)(?:-([0-9]+))?')
mbts=subprocess.run(['git','ls-files','*.mbt'],capture_output=True,text=True).stdout.split()
by=collections.defaultdict(list)
for f in mbts: by[os.path.basename(f)].append(f)
docs=subprocess.run(['git','ls-files','*.md','*.txt','*.mbt'],capture_output=True,text=True).stdout.split()
rows=[]; skipped=0
for d in docs:
    if d.startswith('.anchors/'): continue
    try: lines=open(d,encoding='utf-8').read().split('\n')
    except Exception: continue
    for i,l in enumerate(lines):
        ms=list(pat.finditer(l))
        for j,m in enumerate(ms):
            name,num=m.group(1),int(m.group(2))
            if '/' in name:
                cands=[f for f in mbts if f==name or f.endswith('/'+name)]
            else:
                cands=by.get(name,[])
            if len(cands)!=1: skipped+=1; continue
            rows.append((d,i+1,name,num,cands[0],False))
            # 相对锚：同一行里紧跟**最后一个**全形锚之后的 `:NNN` / `:NNN-NNN` 继承其目标文件
            if j==len(ms)-1:
                for rm in rel.finditer(l[m.end():]):
                    rows.append((d,i+1,name,int(rm.group(1)),cands[0],True))
if not os.path.exists(TSV):
    with open(TSV,'w',encoding='utf-8') as w:
        w.write('# 锚点期望快照（生成物：首次由 ci/anchor-check.sh bootstrap；改锚点须同笔重生成）\n')
        w.write('# 列：referrer<TAB>anchor<TAB>target<TAB>line<TAB>expected_prefix(60)\n')
        for d,ln,base,num,tgt,is_rel in rows:
            try: tl=open(tgt,encoding='utf-8').read().split('\n')
            except Exception: continue
            if 1<=num<=len(tl):
                exp=tl[num-1].strip()[:60]
                # 相对锚在引用处只写 `:NNN`（记其原形，自检才查得到）
                anchor=(':'+str(num)) if is_rel else (base+':'+str(num))
                w.write(f'{d}\t{anchor}\t{tgt}\t{num}\t{exp}\n')
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
