#!/usr/bin/env python3
"""彙整試玩紀錄（第七輪 S7；1.1.0 E1 加讀回報 json）：python3 tools/playtest_report.py <jsonl／json 檔或資料夾>…
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

# ── 1.1.0 E1：「回報問題」產生的 report_*.json（或貼回來的剪貼簿文字存成 .json）──
# 讀 {"feedback": {...}}：漏斗（第一次開遊戲後幾分鐘到各步驟）、最後離開的畫面、回報分類、第一次開戰秒數、語言與字級。
# 同一人可能回報多次：用 (os, boots 的第一次開遊戲時間) 去重，留最新那份。資料沒有的欄位標「未知」，不推論。
reps = []
for a in sys.argv[1:]:
    cand = glob.glob(os.path.join(a, "**", "*.json"), recursive=True) if os.path.isdir(a) else ([a] if a.endswith(".json") else [])
    for f in cand:
        try:
            d = json.load(open(f, encoding="utf-8"))
        except (ValueError, OSError):
            continue
        if isinstance(d, dict) and isinstance(d.get("feedback"), dict):
            reps.append((os.path.getmtime(f), d["feedback"]))
if reps:
    uniq = {}
    for t, fb in sorted(reps, key=lambda x: x[0]):
        fun = {s.get("step"): s.get("min") for s in fb.get("funnel", []) if isinstance(s, dict)}
        key = (fb.get("os"), fb.get("first_boot", fun.get("boot")), fb.get("app"))
        uniq[key] = fb   # 後來的覆蓋前面的
    fbs = list(uniq.values())
    n = len(fbs)
    print(f"\n回報 {len(reps)} 份、去重後 {n} 人")
    steps = ["tutorial_open", "tutorial_done", "first_battle", "first_win", "first_loss", "puzzle_open", "puzzle_clear",
             "gauntlet_open", "daily_open", "playroom_open", "codex_open", "settings_open"]
    print("新手漏斗（到達人數／分鐘中位數）：")
    for s in steps:
        mins = [x.get("min") for fb in fbs for x in fb.get("funnel", []) if isinstance(x, dict) and x.get("step") == s]
        mins = [m for m in mins if isinstance(m, (int, float))]
        med = ("%.0f 分" % st.median(mins)) if mins else "—"
        print(f"  {s:<15} {len(mins)}/{n}  {med}")
    secs = [fb.get("first_battle_sec") for fb in fbs if isinstance(fb.get("first_battle_sec"), (int, float))]
    print("開遊戲到第一次開戰：" + (("中位數 %.0f 秒（%d 人，同一次開遊戲內量的）" % (st.median(secs), len(secs))) if secs else "未知（舊版回報沒有這欄）"))
    last = {}
    for fb in fbs:
        last[fb.get("last_screen") or "未知"] = last.get(fb.get("last_screen") or "未知", 0) + 1
    print("最後離開的畫面：", dict(sorted(last.items(), key=lambda x: -x[1])))
    cats = {}
    for fb in fbs:
        cats[fb.get("cat") or "未分類"] = cats.get(fb.get("cat") or "未分類", 0) + 1
    print("回報分類：", cats)
    notes = [fb.get("note") for fb in fbs if fb.get("note")]
    for i, t in enumerate(notes[:20]):
        print(f"  描述 {i + 1}：{str(t)[:120]}")
    lang = {}
    for fb in fbs:
        k = "%s／%s%%" % (fb.get("lang", "?"), fb.get("text_scale", "?"))
        lang[k] = lang.get(k, 0) + 1
    print("語言／字級：", lang)
