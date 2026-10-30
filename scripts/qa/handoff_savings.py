#!/usr/bin/env python3
# Token Kuzatuv QA: ko'chirish tejashi — har ko'chirilgan sessiya eski sessiya oxiri bilan solishtiriladi (sessiya yozuvlaridan).
#   python3 -I scripts/qa/handoff_savings.py
import json,glob,os,re,statistics as st
root=os.path.expanduser('~/.claude/projects')
def load(f):
    calls={};first=None;tools=[]
    with open(f) as fh:
        for line in fh:
            try:d=json.loads(line)
            except:continue
            m=d.get('message') or {}
            if d.get('type')=='user' and first is None and not d.get('isMeta'):
                c=m.get('content')
                if isinstance(c,str): first=(c,d.get('timestamp'))
                elif isinstance(c,list):
                    t=' '.join(x.get('text','') for x in c if isinstance(x,dict) and x.get('type')=='text')
                    if t: first=(t,d.get('timestamp'))
            if d.get('type')=='assistant' and m.get('usage') and not d.get('isSidechain'):
                u=m['usage'];mid=m.get('id') or d.get('uuid')
                calls[mid]=(d.get('timestamp'),u.get('input_tokens',0),u.get('cache_read_input_tokens',0),u.get('cache_creation_input_tokens',0),u.get('output_tokens',0))
            if d.get('type')=='assistant':
                for x in (m.get('content') or []):
                    if isinstance(x,dict) and x.get('type')=='tool_use': tools.append(json.dumps(x.get('input',{})))
    cl=sorted(calls.values(),key=lambda c:c[0] or '')
    return first,cl,tools
files={os.path.basename(f)[:-6]:f for f in glob.glob(root+'/*/*.jsonl')}
rows=[];reread=0;continued_old=0;missing=0
for sid,f in files.items():
    first,cl,tools=load(f)
    if not first or not (first[0].startswith('↪ ') or first[0].startswith('Token Kuzatuv:')): continue
    olds=re.findall(r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl',first[0])
    olds=[o for o in olds if o in files and o!=sid]
    if not olds or len(cl)<3: missing+=1;continue
    _,ocl,_=load(files[olds[0]])
    t0=first[1] or ''
    before=[c for c in ocl if (c[0] or '')<t0]
    after_old=[c for c in ocl if (c[0] or '')>t0]
    if len(before)<5: missing+=1;continue
    if len(after_old)>3: continued_old+=1
    if any(olds[0] in t for t in tools): reread+=1
    ctx=lambda c:c[1]+c[2]+c[3]
    wt=lambda c:c[1]+0.1*c[2]+1.25*c[3]
    old_end=st.median(ctx(c) for c in before[-5:])
    new=[ctx(c) for c in cl]
    # counterfactual: old session continues, each call reads old_end from cache (+ same new work)
    cf_raw=sum(old_end+ (n-new[0]) for n in new)  # old context + growth seen in new session
    act_raw=sum(new)
    cf_w=sum(0.1*(old_end+(n-new[0])) for n in new)+sum(c[1]+1.25*c[3] for c in cl)
    act_w=sum(wt(c) for c in cl)
    rows.append(dict(sid=sid,old_end=old_end,new_start=st.median(new[:3]),calls=len(cl),cf_raw=cf_raw,act_raw=act_raw,cf_w=cf_w,act_w=act_w,overhead=1.25*cl[0][3]))
print('juftlar:',len(rows),' bog\'lab bo\'lmadi:',missing,' eski sessiyada davom etilgan:',continued_old,' yangi sessiya eski yozuvni o\'qigan:',reread)
if rows:
    tot=lambda k:sum(r[k] for r in rows)
    print('oxirgi kontekst (median): eski %.0fK -> yangi %.0fK'%(st.median(r['old_end'] for r in rows)/1e3, st.median(r['new_start'] for r in rows)/1e3))
    print('jami chaqiruvlar yangi sessiyalarda:',tot('calls'))
    print('o\'qilgan token: ko\'chirilmasa %.1fM, haqiqatda %.1fM, tejash %.0f%%'%(tot('cf_raw')/1e6,tot('act_raw')/1e6,100*(1-tot('act_raw')/tot('cf_raw'))))
    print('narx ekvivalenti (kesh og\'irligi): ko\'chirilmasa %.2fM, haqiqatda %.2fM, tejash %.0f%%'%(tot('cf_w')/1e6,tot('act_w')/1e6,100*(1-tot('act_w')/tot('cf_w'))))
    neg=[r for r in rows if r['act_w']>r['cf_w']]
    print('zarar bergan ko\'chirishlar (narx bo\'yicha):',len(neg), [ (r['sid'][:8],r['calls']) for r in neg][:8])
    print('ko\'chirish narxi (1-chaqiruv kesh yozish) median: %.0fK'%(st.median(r['overhead'] for r in rows)/1e3))
