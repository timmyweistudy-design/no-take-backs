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
    # 完整性（Codex N1-r1 #6）：每個模式的筆數要對、不能有重複鍵；依鍵排序
    man_path = os.path.join(folder, "manifest.json")
    if not os.path.exists(man_path):
        print("✗ 沒有 manifest.json，無法確認資料完整"); sys.exit(2)
    man = json.load(open(man_path))
    if not isinstance(man.get("modes"), list) or not man["modes"] or not isinstance(man.get("shards"), int) or man["shards"] <= 0:
        print("✗ manifest.json 不合法"); sys.exit(2)
    shards = man["shards"]
    errs = [r for v in rows.values() for r in v if "error" in r]
    if errs:
        print(f"✗ 有 {len(errs)} 筆執行錯誤（例：{errs[0]}）"); sys.exit(2)
    expect = {"matrix": 20, "league": 200 * 12 * 2, "search": shards, "counter": 6, "countersearch": shards}
    keyset = {
        "matrix": {(a, b) for a in range(5) for b in range(5) if a != b},
        "league": {(a, k, s) for a in range(200) for k in range(12) for s in range(2)},
        "search": {(s,) for s in range(shards)},
        "counter": {(t,) for t in range(6)},
        "countersearch": {(s,) for s in range(shards)},
    }
    keyf = {"matrix": ("a", "b"), "league": ("a", "k", "side"), "search": ("shard",), "counter": ("template",),
            "countersearch": ("shard",)}
    for m in man["modes"]:
        key = m.replace(":", "_")
        got = rows.get(key, [])
        base = m.split(":")[0]
        exp = 400 if base == "turns" else expect.get(base)
        want = {(g,) for g in range(400)} if base == "turns" else keyset.get(base)
        kf = ("game",) if base == "turns" else keyf.get(base, ())
        keys = [tuple(r.get(k) for k in kf) for r in got]
        if exp is not None and len(got) != exp:
            print(f"✗ {m} 筆數 {len(got)}，預期 {exp}"); sys.exit(2)
        if len(set(keys)) != len(keys):
            print(f"✗ {m} 有重複的場次"); sys.exit(2)
        if want is not None and set(keys) != want:
            print(f"✗ {m} 場次鍵集合不對（少 {len(want - set(keys))}、多 {len(set(keys) - want)}）"); sys.exit(2)
        rows[key] = [r for _, r in sorted(zip(keys, got), key=lambda kv: kv[0])]
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
        if blow >= 20: warns.append(f"全池碾壓局 {blow}%（全池含亂擺陣型，只當參考）")
        if not (35 <= med_sec <= 75): fails.append(f"秒數中位數 {med_sec:.1f}")
        if med_rem > 30: warns.append(f"全池勝方剩餘中位數 {med_rem}%（只當參考）")
        if med_lock < 0.4: warns.append(f"鎖定時間比中位數 {med_lock:.2f} < 0.4")
        # 競技池（優化方案 B2、§14 Codex）：只看「聯賽勝率前 50% 的陣型」彼此對打，排除明顯亂擺的陣型
        per_wr = {}
        for r in L:
            per_wr.setdefault(r["a"], []).append(1 if r["res"] == 1 else 0.5 if r["res"] == 0 else 0)
        ranked = sorted(per_wr, key=lambda k: -sum(per_wr[k]) / len(per_wr[k]))
        top = set(ranked[: len(ranked) // 2])
        C = [r for r in L if r["a"] in top and r["b"] in top]
        cdec = [r for r in C if r["res"] != 0]
        if cdec:
            crem = [r["rem"] for r in cdec]
            c_blow = pct(sum(1 for x in crem if x > 50), len(crem))
            c_med = st.median(crem)
            c_lock = st.median([r["lock"] / 1000 for r in cdec])
            c_lc = pct(sum(1 for r in C if r["lc"] >= 1), len(C))
            c_cb = pct(sum(1 for r in cdec if r["swing"] >= 15), len(cdec))
            c_sec = st.median([r["ticks"] / 20 for r in C])
            summary.update(comp_games=len(C), comp_median_rem=c_med, comp_blowout_pct=c_blow, comp_median_lock=c_lock,
                           comp_lead_change_pct=c_lc, comp_comeback_pct=c_cb, comp_median_secs=c_sec)
            md.append(f"\n**競技池**（聯賽勝率前 50% 的陣型彼此對打，{len(C)} 場）：勝方剩餘中位數 {c_med}%、碾壓 {c_blow}%、秒數中位數 {c_sec:.1f}、"
                      f"鎖定時間比 {c_lock:.2f}、有領先交換 {c_lc}%、翻盤局 {c_cb}%\n")
            if c_blow >= 20: fails.append(f"競技池碾壓局 {c_blow}%")
            if c_med > 30: fails.append(f"競技池勝方剩餘中位數 {c_med}%")
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

    if "countersearch" in rows:
        CS = [r for r in rows["countersearch"] if "fit" in r]
        good = {}
        for r in CS:
            if r["fit"] >= 0.6:
                good[tuple(1 if x > 0 else 0 for x in r["comp"])] = r
        summary["counters_found"] = len(good)
        md.append(f"\n## ④-2 反制搜尋（針對搜尋第一名，{len(CS)} 條爬山）\n能贏它 ≥60% 的反制陣：**{len(good)}** 類（依用到的兵種分類）\n")
        for r in sorted(CS, key=lambda r: -r["fit"])[:3]:
            md.append(f"- {round(r['fit']*100)}%　組成 {r['comp']}　`{r['code']}`\n")
        if len(good) >= 2:
            warns = [w for w in warns if not w.startswith("搜尋到保留池勝率")]
            md.append("→ 至少兩類反制存在，不算萬用陣（剋制循環成立）。\n")
        else:
            warns.append("找不到兩類能穩定反制搜尋第一名的陣型：疑似萬用陣")

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
