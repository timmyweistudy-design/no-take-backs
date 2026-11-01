#!/usr/bin/env python3
"""平衡工具 2.0 報表：合併 balance.sh 各分片的 JSONL，檢查紅線，寫 report.md 與 summary.json。
用法：balance_report.py <資料夾> [總秒數]
結束碼：0＝紅線全過；1＝有紅線失敗；2＝資料錯誤（零筆、數值摘要不一致）。
紅線（優化方案 M）：
  - 剋制五角形 10/10（matrix：剋的一方左右各打一次都要贏）
  - 碾壓局（勝方剩 >50%）< 20%
  - 戰鬥秒數中位數 35～75
  - 勝方剩餘戰力中位數 ≤ 30%
警示（列入調查，不算失敗）：
  - 先手或後手勝率 > 55%
  - 搜尋到保留池勝率 > 65% 的陣型
  - 鎖定時間比中位數 < 0.4（垃圾時間太長）
"""
import json, sys, glob, os, statistics as st

NAMES = ["劍士", "盾兵", "弓箭手", "騎兵", "刺客"]
BEATS = {0: [4, 1], 1: [3, 2], 2: [0, 4], 3: [2, 0], 4: [1, 3]}

def load(folder):
    rows = {}
    for f in sorted(glob.glob(os.path.join(folder, "*.jsonl"))):
        key = os.path.basename(f).rsplit("_", 1)[0]
        for line in open(f, encoding="utf-8"):
            line = line.strip()
            if line:
                rows.setdefault(key, []).append(json.loads(line))
    return rows

def pct(a, b):
    return 0 if b == 0 else round(100 * a / b)

def main():
    folder = sys.argv[1]
    secs = sys.argv[2] if len(sys.argv) > 2 else "?"
    rows = load(folder)
    total = sum(len(v) for v in rows.values())
    if total == 0:
        print("✗ 零筆結果"); sys.exit(2)
    digests = {r.get("digest") for v in rows.values() for r in v}
    if len(digests) != 1:
        print("✗ 數值摘要不一致：", digests); sys.exit(2)
    md = [f"# 平衡報表 2.0\n", f"- 數值摘要 `{digests.pop()}`、共 {total} 筆、耗時 {secs} 秒\n"]
    fails, warns, summary = [], [], {}

    if "matrix" in rows:
        m = {}
        for r in rows["matrix"]:
            m[(r["a"], r["b"])] = r
        ok = 0
        md.append("\n## ① 剋制矩陣（各 60 金；列兵種對行兵種：勝/平/負，括號＝勝方剩餘%）\n\n| | " + " | ".join(NAMES) + " |\n|" + "---|" * 6 + "\n")
        for a in range(5):
            cells = []
            for b in range(5):
                if a == b:
                    cells.append("—"); continue
                r1, r2 = m.get((a, b)), m.get((b, a))
                wins = (r1["res"] == 1) + (r2["res"] == -1)
                loss = (r1["res"] == -1) + (r2["res"] == 1)
                cells.append(f"{wins}/{2-wins-loss}/{loss} ({r1['rem']})")
            md.append(f"| {NAMES[a]} | " + " | ".join(cells) + " |\n")
        for a, bs in BEATS.items():
            for b in bs:
                r1, r2 = m[(a, b)], m[(b, a)]
                if r1["res"] == 1 and r2["res"] == -1:
                    ok += 1
        md.append(f"\n剋制成立 **{ok}/10**\n")
        summary["pentagon"] = ok
        if ok < 10:
            fails.append(f"剋制只成立 {ok}/10")

    if "league" in rows:
        L = rows["league"]
        dec = [r for r in L if r["res"] != 0]
        rem = [r["rem"] for r in dec]
        sec = [r["ticks"] / 20 for r in L]
        lock = [r["lock"] / 1000 for r in dec]
        lc = [r["lc"] for r in L]
        swing = [r["swing"] for r in dec]
        blow = pct(sum(1 for x in rem if x > 50), len(rem))
        close = pct(sum(1 for x in rem if x <= 30), len(rem))
        med_rem = st.median(rem) if rem else 0
        med_sec = st.median(sec)
        med_lock = st.median(lock) if lock else 0
        summary.update(league_games=len(L), median_rem=med_rem, blowout_pct=blow, close_pct=close, median_secs=med_sec,
                       median_lock=med_lock, lead_change_pct=pct(sum(1 for x in lc if x >= 1), len(lc)),
                       comeback_pct=pct(sum(1 for x in swing if x >= 15), len(swing)),
                       draw_pct=pct(len(L) - len(dec), len(L)), timeout_pct=pct(sum(1 for r in L if r["timeout"]), len(L)))
        md.append(f"\n## ② 陣型聯賽（訓練池 200 套 × 12 對手 × 交換左右 = {len(L)} 場）\n\n")
        md.append(f"| 指標 | 數值 | 目標 |\n|---|---|---|\n")
        md.append(f"| 勝方剩餘戰力中位數 | {med_rem}% | ≤30% |\n| 接近局（勝方剩 ≤30%） | {close}% | — |\n| 碾壓局（勝方剩 >50%） | {blow}% | <20% |\n")
        md.append(f"| 戰鬥秒數中位數 | {med_sec:.1f} | 35～75 |\n| 鎖定時間比中位數 | {med_lock:.2f} | ≥0.65 理想、<0.4 警示 |\n")
        md.append(f"| 有領先交換的場次 | {summary['lead_change_pct']}% | — |\n| 翻盤局（贏家曾落後 ≥15%） | {summary['comeback_pct']}% | — |\n")
        md.append(f"| 平手 | {summary['draw_pct']}% | — |\n| 時間到 | {summary['timeout_pct']}% | — |\n")
        if blow >= 20: fails.append(f"碾壓局 {blow}%")
        if not (35 <= med_sec <= 75): fails.append(f"秒數中位數 {med_sec:.1f}")
        if med_rem > 30: fails.append(f"勝方剩餘中位數 {med_rem}%")
        if med_lock < 0.4: warns.append(f"鎖定時間比中位數 {med_lock:.2f} < 0.4")
        # 兵種出場與勝率：依組成金額加權
        tw = [0.0] * 5; tg = [0.0] * 5
        for r in L:
            comp = r["comp"]; s = sum(comp) or 1
            for t in range(5):
                share = comp[t] / s
                tg[t] += share
                tw[t] += share * (1 if r["res"] == 1 else 0.5 if r["res"] == 0 else 0)
        md.append("\n兵種（依陣中金額比例加權）勝率：" + "、".join(f"{NAMES[t]} {pct(tw[t], tg[t])}%" for t in range(5)) + "\n")
        summary["type_winrate"] = [pct(tw[t], tg[t]) for t in range(5)]
        # 每套陣型勝率前 5
        per = {}
        for r in L:
            per.setdefault(r["a"], []).append(1 if r["res"] == 1 else 0.5 if r["res"] == 0 else 0)
        top = sorted(per.items(), key=lambda kv: -sum(kv[1]) / len(kv[1]))[:5]
        md.append("訓練池勝率前 5：" + "、".join(f"#{k} {pct(sum(v), len(v))}%" for k, v in top) + "\n")

    for key in sorted(k for k in rows if k.startswith("turns")):
        T = rows[key]
        dec = [r for r in T if r["first_won"] != 0]
        fw = pct(sum(1 for r in dec if r["first_won"] == 1), len(dec))
        ho = st.median([r["handoffs"] for r in T])
        sp = st.median([r["spent0"] + r["spent1"] for r in T]) / 2
        rule = T[0]["rule"]
        blue = pct(sum(1 for r in dec if (r["first"] == 0) == (r["first_won"] == 1)), len(dec))
        summary[f"{rule}_blue_win"] = blue
        summary[f"{rule}_first_win"] = fw
        summary[f"{rule}_handoffs"] = ho
        md.append(f"\n## ③ 先後手（{rule}，{len(T)} 場，雙方同一個會讀對方的 AI）\n先手勝率 **{fw}%**、藍方（左邊）勝率 {blue}%（不含平手 {len(T)-len(dec)} 場）；每局換人次數中位數 {ho}；每方平均花 {sp:.0f} 金\n")
        if fw > 55 or fw < 45:
            warns.append(f"{rule} 先手勝率 {fw}%（>55% 或 <45% 列入調查）")
        if blue > 55 or blue < 45:
            warns.append(f"{rule} 藍方（左邊）勝率 {blue}%：AI 或規則有左右偏差")

    if "search" in rows:
        S = sorted(rows["search"], key=lambda r: -r["fit_holdout"])
        best = S[0]
        summary["search_best_holdout"] = round(best["fit_holdout"] * 100)
        md.append(f"\n## ④ 萬用陣搜尋（{len(S)} 條爬山，各對 24 個保留陣演化，再對整個保留池 50 套驗證）\n")
        md.append("| 名次 | 保留池勝率 | 組成（劍/盾/弓/騎/刺 金額） | 代碼 |\n|---|---|---|---|\n")
        for i, r in enumerate(S[:5]):
            md.append(f"| {i+1} | {round(r['fit_holdout']*100)}% | {r['comp']} | `{r['code']}` |\n")
        md.append("\n「沒搜到」只代表在這個搜尋預算內沒找到，不等於證明不存在。\n")
        if best["fit_holdout"] > 0.65:
            warns.append(f"搜尋到保留池勝率 {round(best['fit_holdout']*100)}% 的陣型：要找至少兩種反制")

    if "counter" in rows:
        md.append("\n## ⑤ 離線反制庫\n| 原型 | 最佳反制勝率 | 代碼 |\n|---|---|---|\n")
        for r in sorted(rows["counter"], key=lambda r: r["template"]):
            md.append(f"| {r['name']} | {round(r['best_fit']*100)}% | `{r['code']}` |\n")

    md.append("\n## 紅線\n" + ("\n".join(f"- ✗ {x}" for x in fails) if fails else "- ✓ 全過") + "\n")
    md.append("\n## 警示（列入調查）\n" + ("\n".join(f"- ⚠ {x}" for x in warns) if warns else "- 無") + "\n")
    summary["fails"] = fails; summary["warns"] = warns
    open(os.path.join(folder, "report.md"), "w", encoding="utf-8").write("".join(md))
    json.dump(summary, open(os.path.join(folder, "summary.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("".join(md))
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
