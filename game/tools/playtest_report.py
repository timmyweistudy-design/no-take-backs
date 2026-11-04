#!/usr/bin/env python3
"""彙整試玩紀錄（第七輪 S7）：python3 tools/playtest_report.py <jsonl 檔或資料夾>…
一局算一次（session＋game 去重；對戰一行、評分一行不重複算）。舊格式（沒有 session）每個 battle 行算一局。"""
import glob, json, os, statistics as st, sys
files = []
for a in sys.argv[1:]:
    files += glob.glob(os.path.join(a, "**", "*playtest_log.jsonl"), recursive=True) if os.path.isdir(a) else [a]
games, rates, calls, old = {}, {}, [], 0
for f in files:
    for line in open(f, encoding="utf-8"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if "session" not in d:
            if d.get("event", "battle") == "battle":
                old += 1
            continue
        k = (d["session"], d.get("game", 0))
        if d.get("event") == "rating":
            rates[k] = d.get("rating", 0)
        else:
            games.setdefault(k, d)
            if d.get("call_tick", -1) >= 0 and d.get("ticks"):
                calls.append(d["call_tick"] / d["ticks"])
n = len(games)
print(f"檔案 {len(files)}、局數 {n}（舊格式 {old} 局不含規則，不列入）")
if n:
    by = {}
    for d in games.values():
        by[d.get("mode", "?")] = by.get(d.get("mode", "?"), 0) + 1
    print("模式：", by)
    print("平均長度（秒）：%.1f" % (st.mean(d.get("ticks", 0) for d in games.values()) / 20))
if rates:
    print("激烈度評分：平均 %.2f（%d 筆）" % (st.mean(rates.values()), len(rates)))
if calls:
    print("「我知道誰會贏了」在一局的多少比例按下：中位數 %.0f%%（%d 筆）" % (st.median(calls) * 100, len(calls)))
