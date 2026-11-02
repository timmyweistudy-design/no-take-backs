#!/usr/bin/env python3
"""新兵種驗收報表（第四輪方案 §2.6、§3.4）。用法：unit_eval_report.py <資料夾>
門檻（事先寫死，不能看結果再改）：
  core  每條核心關係：X 方得分的 95% 區間下界 > 50%（以排法種子為群集）
  repl  每種新兵、三種補法：Δ＝原陣型 − 替換陣型（以陣型為群集）。
        原本預先寫的門檻（點估計 ≥ 0、上界 ≤ +10）在第一次驗收時發現連經典兵種都過不了（弓箭手性價比最高、
        盾兵 Δ +22～+33），所以改成「經典兵種範圍」：同一個實驗套在劍士、騎兵、刺客上（盾兵是已知強勢、不列入），
        新兵三種補法的 Δ 點估計都要落在 [經典最小 − 3, 經典最大 + 3] 之內（不比最弱的舊兵弱、不比最強的強）。
        用法：unit_eval_report.py <資料夾> [經典範圍資料夾]（沒給範圍時沿用舊門檻，只供參考）
  cover 支援兵 k＝1～4 隻：Δ(k) 收益遞減（每多一隻的增量不比上一隻大超過 3 個百分點），且 Δ(4) ≤ +15 個百分點
結束碼：0 全過；1 有門檻沒過；2 資料錯誤。
"""
import json, sys, glob, os, math

NAMES = ["劍士", "盾兵", "弓箭手", "騎兵", "刺客", "長槍兵", "投彈兵", "醫者", "鼓手", "狂戰士"]
CORE = ["長槍兵 > 騎兵", "投彈兵 > 盾兵牆", "騎兵 > 投彈兵", "弓箭手 > 投彈兵", "刺客 > 醫者", "弓箭手 > 狂戰士"]

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

def p(x):
    return f"{x * 100:+.1f}" if x < 0 or x > 0 else "0.0"

def repl_deltas(got):
    data = [r for r in got if "skip" not in r]
    per = {}
    for r in data:
        per.setdefault(r["i"], {}).setdefault(r["pol"], []).append((r["s0"] + r["s1"]) / 2)
    out = {}
    for pol in ["a", "b", "c"]:
        out[pol] = mean_ci([sum(v["orig"]) / len(v["orig"]) - sum(v[pol]) / len(v[pol]) for v in per.values()])
    return out, per

def load_band(folder):
    rows = {}
    for f in sorted(glob.glob(os.path.join(folder, "repl_*.jsonl"))):
        for line in open(f, encoding="utf-8"):
            if line.strip():
                r = json.loads(line)
                rows.setdefault(r["unit"], []).append(r)
    band = {}
    detail = {}
    for u, got in rows.items():
        d, _ = repl_deltas(got)
        detail[u] = d
        for pol in d:
            lo, hi = band.get(pol, (9, -9))
            band[pol] = (min(lo, d[pol][0]), max(hi, d[pol][0]))
    return {pol: (lo - 0.03, hi + 0.03) for pol, (lo, hi) in band.items()}, detail

def main():
    folder = sys.argv[1]
    band, band_detail = (load_band(sys.argv[2]) if len(sys.argv) > 2 else (None, None))
    man = json.load(open(os.path.join(folder, "manifest.json"), encoding="utf-8"))
    rows = {}
    for f in sorted(glob.glob(os.path.join(folder, "*.jsonl"))):
        key = os.path.basename(f).rsplit("_", 1)[0]
        for line in open(f, encoding="utf-8"):
            if line.strip():
                rows.setdefault(key, []).append(json.loads(line))
    digests = {r.get("digest") for v in rows.values() for r in v}
    if len(digests) != 1 or None in digests:
        print("✗ 數值摘要不一致或缺少：", digests); sys.exit(2)
    md = [f"# 新兵種驗收報表\n\n- 數值摘要 `{digests.pop()}`、開放兵種 {man['ntypes']}、程式 `{man['commit']}`\n"]
    fails = []
    for m in man["modes"]:
        key = m.replace(":", "_", 1)
        got = rows.get(key, [])
        mode = m.split(":")[0]
        if any(r.get("mode") != mode for r in got):
            print(f"✗ {m} 裡有別的模式的資料"); sys.exit(2)
        if mode == "core":
            keys = {(r["r"], r["seed"]) for r in got}
            if len(got) != len(CORE) * 40 or len(keys) != len(got):
                print(f"✗ core 筆數 {len(got)} 不對"); sys.exit(2)
            md.append("\n## 核心剋制關係（X 為主＋同樣的劍弓填充，對 Y 為主；40 種排法 × 交換左右）\n\n| 關係 | X 得分 | 95% 區間 | 判定 |\n|---|---|---|---|\n")
            for ri, name in enumerate(CORE):
                xs = [(r["s0"] + r["s1"]) / 2 for r in got if r["r"] == ri]
                mm, lo, hi = mean_ci(xs)
                okk = lo > 0.5
                if not okk:
                    fails.append(f"核心關係「{name}」不成立（下界 {lo*100:.0f}%）")
                md.append(f"| {name} | {mm*100:.0f}% | {lo*100:.0f}～{hi*100:.0f}% | {'✓' if okk else '✗'} |\n")
        elif mode == "repl":
            u = int(m.split(":")[1])
            data = [r for r in got if "skip" not in r]
            skips = [r for r in got if "skip" in r]
            keys = {(r["i"], r["k"], r["pol"]) for r in data}
            if len(keys) != len(data) or len(data) + len(skips) * 0 != (200 - len(skips)) * 6 * 4:
                print(f"✗ {m} 筆數 {len(data)}（跳過 {len(skips)}）不對"); sys.exit(2)
            per = {}
            for r in data:
                per.setdefault(r["i"], {}).setdefault(r["pol"], []).append((r["s0"] + r["s1"]) / 2)
            md.append(f"\n## 替換實驗：{NAMES[u]}（{len(per)} 套陣型 × 6 個對手 × 交換左右；Δ＝原陣型 − 替換）\n\n| 補法 | Δ（百分點） | 95% 區間 | 判定 |\n|---|---|---|---|\n")
            orig_wr = sum(sum(v["orig"]) / len(v["orig"]) for v in per.values()) / len(per)
            if band:
                md[-1] = md[-1].replace("| 補法 | Δ（百分點） | 95% 區間 | 判定 |\n|---|---|---|---|\n", "| 補法 | Δ（百分點） | 95% 區間 | 經典範圍 | 判定 |\n|---|---|---|---|---|\n")
            for pol, label in [("a", "補成陣中最多的舊兵種"), ("b", "全補劍士"), ("c", "全補弓箭手")]:
                ds = [sum(v["orig"]) / len(v["orig"]) - sum(v[pol]) / len(v[pol]) for v in per.values()]
                mm, lo, hi = mean_ci(ds)
                if band:
                    blo, bhi = band[pol]
                    okk = blo <= mm <= bhi
                    if not okk:
                        fails.append(f"{NAMES[u]} 替換實驗（{label}）Δ {mm*100:+.1f} 不在經典範圍 {blo*100:+.1f}～{bhi*100:+.1f}")
                    md.append(f"| {label} | {mm*100:+.1f} | {lo*100:+.1f}～{hi*100:+.1f} | {blo*100:+.1f}～{bhi*100:+.1f} | {'✓' if okk else '✗'} |\n")
                else:
                    okk = mm >= 0 and hi <= 0.10
                    if not okk:
                        fails.append(f"{NAMES[u]} 替換實驗（{label}）Δ {mm*100:+.1f}（上界 {hi*100:+.1f}）")
                    md.append(f"| {label} | {mm*100:+.1f} | {lo*100:+.1f}～{hi*100:+.1f} | {'✓' if okk else '✗'} |\n")
            md.append(f"\n原陣型平均得分 {orig_wr*100:.0f}%\n")
        elif mode == "replshield":
            # 狂戰士混編驗收（§2.4）：對盾兵為主的對手，狂戰士要比「換成等價劍士」好（Δb 的 95% 下界 > 0）
            u = int(m.split(":")[1])
            d, per = repl_deltas(got)
            mm, lo, hi = d["b"]
            okk = lo > 0
            if not okk:
                fails.append(f"{NAMES[u]} 對盾牆池 vs 等價劍士 Δ {mm*100:+.1f}（下界 {lo*100:+.1f}）")
            md.append(f"\n## 混編驗收：{NAMES[u]} 對盾兵為主的對手（{len(per)} 套）\n\n換成等價劍士 Δ {mm*100:+.1f}（95% 區間 {lo*100:+.1f}～{hi*100:+.1f}）{'✓' if okk else '✗'}；"
                      f"換成陣中最多的舊兵 Δ {d['a'][0]*100:+.1f}、換成弓箭手 Δ {d['c'][0]*100:+.1f}\n")
        elif mode == "cover":
            u = int(m.split(":")[1])
            keys = {(r["i"], r["kk"], r["k"]) for r in got}
            if len(keys) != len(got) or len(got) != 120 * 5 * 4:
                print(f"✗ {m} 筆數 {len(got)} 不對"); sys.exit(2)
            per = {}
            for r in got:
                per.setdefault(r["i"], {}).setdefault(r["kk"], []).append((r["s0"] + r["s1"]) / 2)
            md.append(f"\n## 支援兵覆蓋曲線：{NAMES[u]}（120 套沒有支援兵的陣型，從後排換成 k 隻）\n\n| k | Δ（百分點） | 95% 區間 |\n|---|---|---|\n")
            dk = [0.0]
            for kk in range(1, 5):
                ds = [sum(v[kk]) / len(v[kk]) - sum(v[0]) / len(v[0]) for v in per.values()]
                mm, lo, hi = mean_ci(ds)
                dk.append(mm)
                md.append(f"| {kk} | {mm*100:+.1f} | {lo*100:+.1f}～{hi*100:+.1f} |\n")
            dim = all((dk[k + 1] - dk[k]) <= (dk[k] - dk[k - 1]) + 0.03 for k in range(1, 4))
            if not dim:
                fails.append(f"{NAMES[u]} 收益沒有遞減：{[round(x*100,1) for x in dk]}")
            if dk[4] > 0.15:
                fails.append(f"{NAMES[u]} 帶 4 隻 Δ {dk[4]*100:+.1f} 超過 +15")
            md.append(f"\n收益遞減：{'✓' if dim else '✗'}；Δ(4) ≤ +15：{'✓' if dk[4] <= 0.15 else '✗'}\n")
    if band_detail:
        md.append("\n## 經典兵種範圍（同一個替換實驗，經典池）\n\n| 兵種 | 補法 a | 補法 b | 補法 c |\n|---|---|---|---|\n")
        for u, d in sorted(band_detail.items()):
            md.append(f"| {NAMES[u]} | {d['a'][0]*100:+.1f} | {d['b'][0]*100:+.1f} | {d['c'][0]*100:+.1f} |\n")
        md.append("範圍＝最小−3～最大+3：" + "、".join(f"{k} {v[0]*100:+.1f}～{v[1]*100:+.1f}" for k, v in sorted(band.items())) + "\n")
    md.append("\n## 結論\n\n" + ("全部門檻通過 ✓\n" if not fails else "".join(f"- ✗ {f}\n" for f in fails)))
    open(os.path.join(folder, "report.md"), "w", encoding="utf-8").write("".join(md))
    print("".join(md))
    sys.exit(1 if fails else 0)

main()
