#!/usr/bin/env python3
"""第四輪全局指標（方案 §3.4）：碾壓局、翻盤局、時間到比例、戰鬥秒數（平均與中位數）、snake5 先手勝率。
和第三輪 S6（docs/balance-runs/s6-base、s6-turns-l2fix）比。用法：v4_global.py <v4 資料夾> [封存池資料夾]
門檻：碾壓局 ≤18%；翻盤局 4%～12%；時間到比例比 S6 增加 ≤5 個百分點；平均與中位秒數都 ≤75；snake5 三種 AI 強度先手勝率 45%～55%。"""
import json, glob, os, sys, statistics as st

def load(folder, prefix):
    rows = []
    for f in sorted(glob.glob(os.path.join(folder, prefix + "_*.jsonl"))):
        for l in open(f, encoding="utf-8"):
            if l.strip():
                rows.append(json.loads(l))
    return rows

def metrics(rows):
    dec = [r for r in rows if r["res"] != 0]
    rem = [r["rem"] for r in dec]
    secs = [r["ticks"] / 20 for r in rows]
    return {"n": len(rows), "blowout": 100 * sum(1 for x in rem if x > 50) / max(1, len(rem)),
            "comeback": 100 * sum(1 for r in dec if r["swing"] >= 15) / max(1, len(dec)),
            "timeout": 100 * sum(1 for r in rows if r.get("timeout")) / max(1, len(rows)),
            "mean_s": st.mean(secs) if secs else 0, "median_s": st.median(secs) if secs else 0}

def first_rate(rows):
    # turns 模式：first＝先手隊，winner；平手算半
    w = sum(1.0 if r["first_won"] == 1 else (0.5 if r["first_won"] == 0 else 0.0) for r in rows)
    return 100 * w / max(1, len(rows))

v4 = sys.argv[1]
base = os.path.join(os.path.dirname(v4.rstrip("/")), "s6-base")
out = []
fails = []
s6 = metrics(load(base, "league"))
for name in ["league", "valleague"]:
    m = metrics(load(v4, name))
    out.append(f"| {name} | {m['n']} | {m['blowout']:.1f}% | {m['comeback']:.1f}% | {m['timeout']:.1f}% | {m['mean_s']:.1f} | {m['median_s']:.1f} |")
    if m["blowout"] > 18: fails.append(f"{name} 碾壓局 {m['blowout']:.1f}%")
    if not (4 <= m["comeback"] <= 12): fails.append(f"{name} 翻盤局 {m['comeback']:.1f}%")
    if m["timeout"] - s6["timeout"] > 5: fails.append(f"{name} 時間到 {m['timeout']:.1f}%（S6 {s6['timeout']:.1f}%）")
    if m["mean_s"] > 75 or m["median_s"] > 75: fails.append(f"{name} 秒數 {m['mean_s']:.1f}/{m['median_s']:.1f}")
if len(sys.argv) > 2:
    m = metrics(load(sys.argv[2], "sealleague"))
    out.append(f"| 封存終驗池 | {m['n']} | {m['blowout']:.1f}% | {m['comeback']:.1f}% | {m['timeout']:.1f}% | {m['mean_s']:.1f} | {m['median_s']:.1f} |")
    if m["blowout"] > 18: fails.append(f"封存池碾壓局 {m['blowout']:.1f}%")
    if not (4 <= m["comeback"] <= 12): fails.append(f"封存池翻盤局 {m['comeback']:.1f}%")
out.insert(0, f"| S6 經典（參考） | {s6['n']} | {s6['blowout']:.1f}% | {s6['comeback']:.1f}% | {s6['timeout']:.1f}% | {s6['mean_s']:.1f} | {s6['median_s']:.1f} |")
print("| 池 | 場數 | 碾壓局 | 翻盤局 | 時間到 | 平均秒 | 中位秒 |\n|---|---|---|---|---|---|---|")
print("\n".join(out))
for lv in [0, 1, 2]:
    rows = load(v4, f"turns_snake5@{lv}")
    if rows:
        fr = first_rate(rows)
        print(f"snake5 AI 強度 {lv}：先手勝率 {fr:.1f}%（{len(rows)} 場）")
        if not (45 <= fr <= 55): fails.append(f"snake5@{lv} 先手 {fr:.1f}%")
print("\n結論：" + ("全局指標全過 ✓" if not fails else "；".join("✗ " + f for f in fails)))
sys.exit(1 if fails else 0)
