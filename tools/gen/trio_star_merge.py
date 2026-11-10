#!/usr/bin/env python3
"""V1.6.1 A3：把 trio_star_forge.gd 各組的結果（每檔一行 JSON）併回 game/data/trio.json（sol3、必要時 s2／s3）。
用法（專案根目錄）：python3 tools/gen/trio_star_merge.py <結果檔…>"""
import json, sys
P = 'game/data/trio.json'
d = json.load(open(P, encoding='utf-8'))
by = {s['id']: s for s in d['sets']}
for fn in sys.argv[1:]:
    for ln in open(fn, encoding='utf-8'):
        ln = ln.strip()
        if not ln:
            continue
        r = json.loads(ln)
        s = by[r['id']]
        s['sol3'] = r['sol3']
        for k in ('s2', 's3'):
            s.pop(k, None)
            if r.get(k) is not None:
                s[k] = r[k]
        print(r['id'], 'stars', r['stars'], 'rem', r['rem'], 'spent', r['spent'], 'override' if r['stars'] < 3 else '')
json.dump(d, open(P, 'w', encoding='utf-8'), ensure_ascii=False, indent='\t')
