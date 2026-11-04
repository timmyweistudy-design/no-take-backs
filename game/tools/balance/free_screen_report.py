#!/usr/bin/env python3
"""第六輪 §6.3：彙整 tools/balance/free_screen.sh 的全因子篩選結果。
用法：python3 tools/balance/free_screen_report.py docs/balance-runs/v6-screen > 報表.md
每個組合：核心剋制 6 條（X 方得分平均、95% 區間，以排法種子為群集）、聯賽的碾壓／接近／翻盤／時間到／秒數中位數。
定值原則（方案 §6.3）：核心 6 條區間下界都 >50% 的組合裡，選碾壓局最低、平均秒數 30～75 秒的；沒有組合過關＝退回 1.0 格＋6 格。"""
import json, glob, os, sys, math, statistics as st

CORE = ["長槍兵 > 騎兵", "投彈兵 > 盾兵牆", "騎兵 > 投彈兵", "弓箭手 > 投彈兵", "刺客 > 醫者", "弓箭手 > 狂戰士"]
CFGS = ["grid", "1000_6000", "1000_7000", "1000_7500", "800_6000", "800_7000", "800_7500", "600_6000", "600_7000", "600_7500"]

def mean_ci(xs):
    n = len(xs)
    if n == 0:
        return 0, 0, 0
    m = sum(xs) / n
    if n < 2:
        return m, m, m
    sd = math.sqrt(sum((x - m) ** 2 for x in xs) / (n - 1))
    h = 1.96 * sd / math.sqrt(n)
    return m, m - h, m + h

def wilson(k, n, z=1.96):
    if n == 0:
        return 0, 0
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return 100 * (c - h), 100 * (c + h)

def rows(d, kind):
    out = []
    for f in glob.glob(os.path.join(d, kind + "_*.jsonl")):
        for l in open(f, encoding="utf-8"):
            l = l.strip()
            if l:
                try:
                    out.append(json.loads(l))
                except ValueError:
                    pass   # 還在寫的那一行
    return out

def main():
    root = sys.argv[1]
    res = {}
    md = ["| 組合 | " + " | ".join(CORE) + " | 過關 | 碾壓局 | 接近局 | 翻盤 | 時間到 | 秒數中位數 |", "|" + "---|" * (len(CORE) + 7)]
    for cfg in CFGS:
        d = os.path.join(root, cfg)
        C, L = rows(d, "core"), rows(d, "league")
        if len(C) < 240 or len(L) < 4800:
            continue
        cells, lows = [], []
        for ri in range(len(CORE)):
            m, lo, hi = mean_ci([(r["s0"] + r["s1"]) / 2 for r in C if r["r"] == ri])
            cells.append(f"{100*m:.0f}%（{100*lo:.0f}～{100*hi:.0f}）")
            lows.append(lo)
        dec = [r for r in L if r["res"] != 0]
        rem = [r["rem"] for r in dec]
        blow = sum(1 for x in rem if x > 50)
        close = sum(1 for x in rem if x <= 30)
        cb = sum(1 for r in dec if r["swing"] >= 15)
        to = sum(1 for r in L if r["timeout"])
        secs = st.median([r["ticks"] / 20.0 for r in L])
        ok = all(x > 0.5 for x in lows)
        b_lo, b_hi = wilson(blow, len(rem))
        res[cfg] = dict(ok=ok, blow=100 * blow / max(1, len(rem)), blow_ci=[round(b_lo, 1), round(b_hi, 1)], close=100 * close / max(1, len(rem)),
                        comeback=100 * cb / max(1, len(dec)), timeout=100 * to / len(L), secs=secs, core_low=[round(x, 3) for x in lows])
        md.append(f"| {cfg} | " + " | ".join(cells) + f" | {'✓' if ok else '✗'} | {res[cfg]['blow']:.1f}%（{b_lo:.1f}～{b_hi:.1f}） | {res[cfg]['close']:.1f}% | {res[cfg]['comeback']:.1f}% | {res[cfg]['timeout']:.1f}% | {secs:.1f} |")
    cand = [c for c in res if c != "grid" and res[c]["ok"] and 30 <= res[c]["secs"] <= 75]
    pick = min(cand, key=lambda c: res[c]["blow"]) if cand else "1000_6000"
    print("\n".join(md))
    print()
    print(f"選定：**{pick}**" + ("" if cand else "（沒有組合過關，退回 1.0 格＋6 格）") + f"；候選 {cand}")
    print("JSON " + json.dumps({"pick": pick, "candidates": cand, "res": res}, ensure_ascii=False))

main()
