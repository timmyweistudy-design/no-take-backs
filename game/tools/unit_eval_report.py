#!/usr/bin/env python3
"""新兵種驗收報表（第四輪方案 §2.6、§3.4，含 2026-11-02 修訂）。用法：unit_eval_report.py <資料夾>

資料核對（任何一項不合 → exit 2）：
  ・實驗契約：manifest.contract 的規則版本、數值摘要、對手池身分；每一列都要和契約一致
  ・每個模式的完整鍵集合、兵種、分數只能是 0／0.5／1、開放數、跳過的陣型（編號 0～199、最多 10 套）
  ・替換實驗同一個 (陣型, 第幾個對手) 的四種陣型（原陣、補法 a／b／c）必須是同一個對手
  ・覆蓋曲線：實際支援兵數要等於要求數
門檻（事先寫死）：
  core   每條核心關係：X 方得分的 95% 區間下界 > 50%（以排法種子為群集）
  repl   新兵三種補法的 Δ（原陣型 − 替換陣型）點估計，都要落在「同一次執行、同一個對手池」裡
         劍士／騎兵／刺客三者 Δ 的 [最小 − 3, 最大 + 3] 之內（相對校準：新兵的替換效果在經典兵種的範圍內；
         盾兵是已知強勢、不列入）。區間是雙向群集（陣型 × 對手），只供參考
  replshield  狂戰士對盾兵為主的對手，「換成等價劍士」的 Δ 95% 下界 > 0
  cover  支援兵 k＝1～4 隻收益遞減（每多一隻的增量不比上一隻大超過 3 個百分點）、Δ(4) ≤ +15；
         另外依實際覆蓋分組，任何一組（≥30 個陣型×對手）k＝1 的 Δ 不超過 +15
結束碼：0 全過；1 有門檻沒過；2 資料錯誤。
"""
import re, json, sys, glob, os, math

# 第七輪 R3：名稱只有一個來源，不再手抄（balance_report 曾把鼓手、狂戰士對調）
_UD = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "core", "unit_defs.gd"), encoding="utf-8").read()
NAMES = re.findall(r'"([^"]+)"', re.search(r'const NAMES := \[(.*?)\]', _UD).group(1))
CORE = ["長槍兵 > 騎兵", "投彈兵 > 盾兵牆", "騎兵 > 投彈兵", "弓箭手 > 投彈兵", "刺客 > 醫者", "弓箭手 > 狂戰士"]
CLASSIC_BAND = [0, 3, 4]
LEGAL = (0.0, 0.5, 1.0)

def die(msg):
    print("✗ " + msg); sys.exit(2)

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

def twoway_ci(cells):
    """雙向群集（陣型 × 對手）的平均與 95% 區間（Cameron–Gelbach–Miller）。cells＝[(陣型, 對手, 值)]。"""
    n = len(cells)
    if n == 0:
        die("沒有任何配對可以計算")
    m = sum(c[2] for c in cells) / n
    def v_by(key):
        g = {}
        for c in cells:
            g[key(c)] = g.get(key(c), 0.0) + (c[2] - m)
        return sum(x * x for x in g.values()) / (n * n)
    var = v_by(lambda c: c[0]) + v_by(lambda c: c[1]) - v_by(lambda c: (c[0], c[1]))
    h = 1.96 * math.sqrt(max(var, 0.0))
    return m, m - h, m + h

def check_rows(m, mode, got, man):
    c = man["contract"]
    unit = int(m.split(":")[1]) if ":" in m else None
    bad = []
    for r in got:
        if r.get("mode") != mode:
            bad.append(f"模式不符 {r.get('mode')}")
        if r.get("rules") != c["rules"] or r.get("digest") != c["digest"]:
            bad.append(f"規則或數值摘要和契約不同（{r.get('rules')}/{r.get('digest')}）")
        if "code" in c and r.get("src") != c["code"]:
            bad.append(f"程式身分和契約不同（{r.get('src')} ≠ {c['code']}）")
        if r.get("free", "") != c.get("free", ""):
            bad.append(f"部署規則和契約不同（{r.get('free', '格子')} ≠ {c.get('free') or '格子'}）")   # 第六輪
        if unit is not None and r.get("unit") != unit:
            bad.append(f"兵種不符 {r.get('unit')}")
        if mode != "core" and r.get("nt") != man["ntypes"]:
            bad.append(f"開放數 {r.get('nt')} ≠ {man['ntypes']}")
        if "skip" in r:
            if mode not in ("repl", "replshield") or not (0 <= int(r.get("i", -1)) < 200):
                bad.append(f"不合法的跳過列 {r}")
            continue
        if r.get("s0") not in LEGAL or r.get("s1") not in LEGAL:
            bad.append(f"分數不合法 {r.get('s0')}/{r.get('s1')}")
        if mode != "core":
            want_pool = c["pool_shield"] if mode == "replshield" else c["pool_val"]
            if r.get("pool") != want_pool:
                bad.append(f"對手池身分不符（{r.get('pool')} ≠ {want_pool}）")
    if mode in ("repl", "replshield"):
        skips = {r["i"] for r in got if "skip" in r}
        if len(skips) > 10:
            bad.append(f"跳過的陣型太多（{len(skips)}）")
        data = [r for r in got if "skip" not in r]
        want = {(i, k, pol) for i in range(200) if i not in skips for k in range(6) for pol in ("orig", "a", "b", "c")}
        have = [(r["i"], r["k"], r["pol"]) for r in data]
        if len(set(have)) != len(have):
            bad.append("有重複的列")
        if set(have) != want:
            bad.append(f"鍵集合不對（少 {len(want - set(have))}、多 {len(set(have) - want)}）")
        badf = [r for r in data if r.get("opp") != (r["i"] * 7 + r["k"] * 31) % 200]
        if badf:
            bad.append(f"有 {len(badf)} 列對手編號不符公式")
        opp = {}
        for r in data:
            opp.setdefault((r["i"], r["k"]), set()).add(r.get("opp"))
        mixed = [k for k, v in opp.items() if len(v) != 1 or None in v]
        if mixed:
            bad.append(f"有 {len(mixed)} 組的四種陣型對手不同")
    elif mode == "cover":
        want = {(i, kk, k) for i in range(120) for kk in range(5) for k in range(4)}
        have = [(r["i"], r["kk"], r["k"]) for r in got]
        if len(set(have)) != len(have) or set(have) != want:
            bad.append("鍵集合不對或有重複")
        wrong = [r for r in got if r.get("have") != r.get("kk")]
        if wrong:
            bad.append(f"有 {len(wrong)} 列實際支援兵數 ≠ 要求")
        # 對手配對（Codex 第 3 輪 #3）：對手要照公式、同一套陣型的 4 個對手互不相同
        badopp = [r for r in got if r.get("opp") != (r["i"] * 11 + r["k"] * 37) % 200]
        if badopp:
            bad.append(f"有 {len(badopp)} 列對手編號不符公式")
        per_i = {}
        for r in got:
            per_i.setdefault(r["i"], set()).add(r.get("opp"))
        if any(len(v) != 4 for v in per_i.values()):
            bad.append("有陣型的 4 個對手不是互不相同")
    elif mode == "core":
        have = [(r["r"], r["seed"]) for r in got]
        if len(set(have)) != len(have) or set(have) != {(ri, sd) for ri in range(len(CORE)) for sd in range(40)}:
            bad.append("鍵集合不對或有重複")
    if bad:
        die(f"{m} 資料錯誤：" + "；".join(sorted(set(bad))[:6]))

def repl_deltas(got):
    cell = {}
    for r in got:
        if "skip" in r:
            continue
        cell.setdefault((r["i"], r["opp"], r["k"]), {})[r["pol"]] = (r["s0"] + r["s1"]) / 2
    out = {}
    for pol in ("a", "b", "c"):
        out[pol] = twoway_ci([(k[0], k[1], v["orig"] - v[pol]) for k, v in cell.items()])
    return out, len({k[0] for k in cell})

def main():
    folder = sys.argv[1]
    man = json.load(open(os.path.join(folder, "manifest.json"), encoding="utf-8"))
    if "contract" not in man:
        die("manifest 沒有實驗契約")
    rows = {}
    for f in sorted(glob.glob(os.path.join(folder, "*.jsonl"))):
        key = os.path.basename(f).rsplit("_", 1)[0]
        for line in open(f, encoding="utf-8"):
            if line.strip():
                rows.setdefault(key, []).append(json.loads(line))
    c = man["contract"]
    md = [f"# 新兵種驗收報表\n\n- 規則 {c['rules']}、數值摘要 `{c['digest']}`、開放兵種 {man['ntypes']}、程式 `{man['commit']}`\n"
          f"- 對手池：驗證池 `{c['pool_val']}`、盾牆池 `{c['pool_shield']}`\n"]
    fails = []
    deltas = {}
    for m in man["modes"]:
        got = rows.get(m.replace(":", "_", 1), [])
        if not got:
            die(f"{m} 沒有資料")
        check_rows(m, m.split(":")[0], got, man)
        if m.startswith("repl:"):
            deltas[int(m.split(":")[1])] = repl_deltas(got)
    # 經典範圍：同一次執行、同一個對手池
    band = None
    if all(u in deltas for u in CLASSIC_BAND):
        band = {}
        for pol in ("a", "b", "c"):
            vals = [deltas[u][0][pol][0] for u in CLASSIC_BAND]
            band[pol] = (min(vals) - 0.03, max(vals) + 0.03)
        md.append("\n## 經典兵種範圍（同一個對手池）\n\n| 兵種 | 補法 a | 補法 b | 補法 c |\n|---|---|---|---|\n")
        for u in CLASSIC_BAND:
            d = deltas[u][0]
            md.append(f"| {NAMES[u]} | {d['a'][0]*100:+.1f} | {d['b'][0]*100:+.1f} | {d['c'][0]*100:+.1f} |\n")
        md.append("範圍（最小−3～最大+3）：" + "、".join(f"{k} {v[0]*100:+.1f}～{v[1]*100:+.1f}" for k, v in sorted(band.items())) + "\n")
    for m in man["modes"]:
        mode = m.split(":")[0]
        got = rows[m.replace(":", "_", 1)]
        if mode == "core":
            md.append("\n## 核心剋制關係（X 為主＋同樣的劍弓填充，對 Y 為主；40 種排法 × 交換左右）\n\n| 關係 | X 得分 | 95% 區間 | 判定 |\n|---|---|---|---|\n")
            for ri, name in enumerate(CORE):
                mm, lo, hi = mean_ci([(r["s0"] + r["s1"]) / 2 for r in got if r["r"] == ri])
                okk = lo > 0.5
                if not okk:
                    fails.append(f"核心關係「{name}」不成立（下界 {lo*100:.0f}%）")
                md.append(f"| {name} | {mm*100:.0f}% | {lo*100:.0f}～{hi*100:.0f}% | {'✓' if okk else '✗'} |\n")
        elif mode == "repl":
            u = int(m.split(":")[1])
            d, nform = deltas[u]
            is_band = u in CLASSIC_BAND
            md.append(f"\n## 替換實驗：{NAMES[u]}{'（經典範圍基準）' if is_band else ''}（{nform} 套陣型 × 6 個對手 × 交換左右；Δ＝原陣型 − 替換）\n\n"
                      "| 補法 | Δ（百分點） | 雙向群集 95% 區間 | 經典範圍 | 判定 |\n|---|---|---|---|---|\n")
            for pol, label in (("a", "補成陣中最多的舊兵種"), ("b", "全補劍士"), ("c", "全補弓箭手")):
                mm, lo, hi = d[pol]
                if is_band:
                    md.append(f"| {label} | {mm*100:+.1f} | {lo*100:+.1f}～{hi*100:+.1f} | — | 基準 |\n")
                    continue
                if band is None:
                    die("沒有同一次執行的經典範圍（要一起跑 repl:0 repl:3 repl:4）")
                blo, bhi = band[pol]
                okk = blo <= mm <= bhi
                if not okk:
                    fails.append(f"{NAMES[u]} 替換實驗（{label}）Δ {mm*100:+.1f} 不在經典範圍 {blo*100:+.1f}～{bhi*100:+.1f}")
                md.append(f"| {label} | {mm*100:+.1f} | {lo*100:+.1f}～{hi*100:+.1f} | {blo*100:+.1f}～{bhi*100:+.1f} | {'✓' if okk else '✗'} |\n")
        elif mode == "replshield":
            u = int(m.split(":")[1])
            d, nform = repl_deltas(got)
            mm, lo, hi = d["b"]
            okk = lo > 0
            if not okk:
                fails.append(f"{NAMES[u]} 對盾牆池 vs 等價劍士 Δ {mm*100:+.1f}（下界 {lo*100:+.1f}）")
            md.append(f"\n## 混編驗收：{NAMES[u]} 對盾兵為主的對手（{nform} 套）\n\n換成等價劍士 Δ {mm*100:+.1f}（雙向群集 95% 區間 {lo*100:+.1f}～{hi*100:+.1f}）{'✓' if okk else '✗'}；"
                      f"換成陣中最多的舊兵 Δ {d['a'][0]*100:+.1f}、換成弓箭手 Δ {d['c'][0]*100:+.1f}\n")
        elif mode == "cover":
            u = int(m.split(":")[1])
            cell = {}
            for r in got:
                cell.setdefault((r["i"], r["opp"]), {})[r["kk"]] = r
            md.append(f"\n## 支援兵覆蓋曲線：{NAMES[u]}（120 套沒有支援兵的陣型，從後排換成 k 隻）\n\n| k | Δ（百分點） | 雙向群集 95% 區間 | 平均實際覆蓋 |\n|---|---|---|---|\n")
            dk = [0.0]
            for kk in range(1, 5):
                cells = [(k[0], k[1], (v[kk]["s0"] + v[kk]["s1"]) / 2 - (v[0]["s0"] + v[0]["s1"]) / 2) for k, v in cell.items()]
                mm, lo, hi = twoway_ci(cells)
                cov = sum(v[kk]["cov"] for v in cell.values()) / len(cell)
                dk.append(mm)
                md.append(f"| {kk} | {mm*100:+.1f} | {lo*100:+.1f}～{hi*100:+.1f} | {cov:.1f} |\n")
            dim = all((dk[k + 1] - dk[k]) <= (dk[k] - dk[k - 1]) + 0.03 for k in range(1, 4))
            if not dim:
                fails.append(f"{NAMES[u]} 收益沒有遞減：{[round(x*100,1) for x in dk]}")
            if dk[4] > 0.15:
                fails.append(f"{NAMES[u]} 帶 4 隻 Δ {dk[4]*100:+.1f} 超過 +15")
            # 依實際覆蓋分組（k＝1）：高覆蓋不能失控
            edges = [(0, 2), (2, 4), (4, 6), (6, 99)]
            md.append(f"\n收益遞減：{'✓' if dim else '✗'}；Δ(4) ≤ +15：{'✓' if dk[4] <= 0.15 else '✗'}\n\n依實際覆蓋分組（k＝1）：")
            parts = []
            for lo_e, hi_e in edges:
                cells = [(k[0], k[1], (v[1]["s0"] + v[1]["s1"]) / 2 - (v[0]["s0"] + v[0]["s1"]) / 2) for k, v in cell.items() if lo_e <= v[1]["cov"] < hi_e]
                if len(cells) < 30:
                    parts.append(f"{lo_e}～{hi_e if hi_e < 99 else '∞'}：{len(cells)} 組（太少不判）")
                    continue
                mm = sum(x[2] for x in cells) / len(cells)
                parts.append(f"{lo_e}～{hi_e if hi_e < 99 else '∞'}：{len(cells)} 組 Δ {mm*100:+.1f}")
                if mm > 0.15:
                    fails.append(f"{NAMES[u]} 覆蓋 {lo_e}～{hi_e} 時 Δ {mm*100:+.1f} 超過 +15")
            md.append("、".join(parts) + "\n")
    md.append("\n## 結論\n\n" + ("全部門檻通過 ✓\n" if not fails else "".join(f"- ✗ {f}\n" for f in fails)))
    open(os.path.join(folder, "report.md"), "w", encoding="utf-8").write("".join(md))
    print("".join(md))
    sys.exit(1 if fails else 0)

main()
