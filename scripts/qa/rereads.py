#!/usr/bin/env python3
# Token Kuzatuv QA: ko'chirilgan sessiyalar eski suhbatni qayerda va nima uchun qayta o'qigan (xulosada nima yetishmagan).
#   python3 -I scripts/qa/rereads.py
import json,glob,os,re
root=os.path.expanduser('~/.claude/projects')
files={os.path.basename(f)[:-6]:f for f in glob.glob(root+'/*/*.jsonl')}
def text(c):
    if isinstance(c,str): return c
    if isinstance(c,list): return ' '.join(x.get('text','') for x in c if isinstance(x,dict) and x.get('type')=='text')
    return ''
n=0
for sid,f in sorted(files.items()):
    ev=[]
    for line in open(f):
        try:d=json.loads(line)
        except:continue
        if d.get('isSidechain'):continue
        m=d.get('message') or {}
        if d.get('type')=='user' and not d.get('isMeta'):
            t=text(m.get('content'))
            if t: ev.append(('U',t))
        if d.get('type')=='assistant':
            for x in m.get('content') or []:
                if isinstance(x,dict) and x.get('type')=='tool_use': ev.append(('T',x.get('name'),x.get('input',{})))
    if not ev or ev[0][0]!='U' or not (ev[0][1].startswith('↪ ') or ev[0][1].startswith('Token Kuzatuv:')): continue
    olds=[o for o in re.findall(r'([0-9a-f-]{36})\.jsonl',ev[0][1]) if o!=sid]
    if not olds: continue
    hits=[];uidx=0;lastU=''
    for e in ev:
        if e[0]=='U': uidx+=1; lastU=e[1]; continue
        s=json.dumps(e[2],ensure_ascii=False)
        if any(o in s for o in olds):
            hits.append((uidx,e[1],s[:230],lastU[:160].replace('\n',' ')))
    if hits:
        n+=1
        print(f"### {sid[:8]}  so'rovlar={sum(1 for e in ev if e[0]=='U')}  qayta_o'qish={len(hits)}")
        for h in hits[:4]: print(f"  #{h[0]} {h[1]}: {h[2]}\n     USER: {h[3]}")
print('JAMI sessiya:',n)
