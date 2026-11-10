#!/usr/bin/env python3
"""V1.0.0：加或改介面字串（四語）。用法：python3 tools/gen/addstr.py <strings.json>，內容 [{"k","zh","en","ja"}...]。
寫進 game/data/strings.csv（新鍵附加、舊鍵覆寫，簡中先放繁中，跑 l10n_build 會轉）與 build/tmp/v140/l10n/batch_v100.json、ja_v100.json，
並把舊譯稿裡同一個鍵拿掉（不然 l10n_build 依檔名排序，舊譯會蓋過新原文的翻譯）。之後跑 l10n_build、重建字型。"""
import csv, json, sys, os
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV=ROOT+'/game/data/strings.csv'
L10N=ROOT+'/build/tmp/v140/l10n'
items=json.load(open(sys.argv[1],encoding='utf-8'))
rows=list(csv.reader(open(CSV,encoding='utf-8',newline='')))
idx={r[0]:i for i,r in enumerate(rows) if r}
for it in items:
    row=[it['k'],it['zh'],it['en'],it['zh'],it['ja']]
    if it['k'] in idx: rows[idx[it['k']]]=row
    else: rows.append(row); idx[it['k']]=len(rows)-1
with open(CSV,'w',encoding='utf-8',newline='') as f:
    csv.writer(f,lineterminator='\n').writerows(rows)
bp=L10N+'/batch_v100.json'; jp=L10N+'/ja_v100.json'
b=json.load(open(bp,encoding='utf-8')) if os.path.exists(bp) else []
j=json.load(open(jp,encoding='utf-8')) if os.path.exists(jp) else {}
bi={e['id']:e for e in b}
for it in items:
    bi['s:'+it['k']]={'id':'s:'+it['k'],'zh':it['zh'],'en':it['en']}
    j['s:'+it['k']]=it['ja']
json.dump(list(bi.values()),open(bp,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
json.dump(j,open(jp,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print('ok',len(items))
# 舊譯稿裡同一個鍵（原文改過）要拿掉，不然 l10n_build 依檔名排序會讓舊的蓋過 v100
import glob
for f in sorted(glob.glob(L10N+'/batch_*.json'))+sorted(glob.glob(L10N+'/ja_*.json')):
    if f.endswith('_v100.json') or 'review' in f: continue
    d=json.load(open(f,encoding='utf-8'))
    ids={'s:'+it['k'] for it in items}
    if isinstance(d,list):
        nd=[e for e in d if e['id'] not in ids]
        if len(nd)!=len(d): json.dump(nd,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
    else:
        if any(k in d for k in ids):
            for k in ids: d.pop(k,None)
            json.dump(d,open(f,'w',encoding='utf-8'),ensure_ascii=False,indent=1)
