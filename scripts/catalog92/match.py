import json
from existing_map import MAP
F=json.load(open('sr.json'))['foods']
def find(q):
    for alt in q.split('|'):
        alt=alt.strip().lower()
        exact=[k for k,v in F.items() if v['d'].lower()==alt]
        if exact: return exact[0]
        toks=[t.strip() for t in alt.split(',') if t.strip()]
        c=[(len(v['d']),k) for k,v in F.items() if all(t in v['d'].lower() for t in toks)]
        if c: return min(c)[1]
    return None
