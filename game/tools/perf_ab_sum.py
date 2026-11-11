"""1.2.0 §14.8：彙整 perf_ab.sh 的 ABBA 結果。
每一輪（A B B A）算一個成對差 d＝mean(A)−mean(B)；用「各輪 d 的標準差」估計波動（不是把 A、B 混在一起算，
那樣會把版本差異當成雜訊；Codex cat01 #7）。結論：輪數 < 2 → 樣本不足；|平均 d| ≥ 2×標準誤 → 有差，否則雜訊內。"""
import json, sys, glob, os, re, statistics as st
out = sys.argv[1]
runs = []
for f in sorted(glob.glob(os.path.join(out, "run_*.json"))):
    m = re.search(r"run_(\d+)_([AB])\.json$", f)
    d = json.load(open(f, encoding="utf-8"))
    a = d["all"]
    runs.append({"i": int(m.group(1)), "side": m.group(2), "p50": a["draw_ms"]["p50"], "p95": a["draw_ms"]["p95"], "p99": a["draw_ms"]["p99"],
                 "gpu95": a["gpu_ms"]["p95"], "tex": d.get("tex_mem_mib", 0), "bake": d.get("atlas_sweep", {}).get("worst_bake_frame_ms", 0)})
if len(runs) % 4 != 0 or not runs:
    sys.exit(f"PERFAB FAIL：輸出數 {len(runs)} 不是 4 的倍數（有一次沒跑完）")
res = {}
for k in ["p50", "p95", "p99", "gpu95", "tex", "bake"]:
    ds = []
    for r in range(len(runs) // 4):
        grp = runs[r * 4:(r + 1) * 4]
        ds.append(st.mean(x[k] for x in grp if x["side"] == "A") - st.mean(x[k] for x in grp if x["side"] == "B"))
    md = st.mean(ds)
    if len(ds) < 2:
        verdict, sd = "樣本不足（至少 2 輪）", 0.0
    else:
        sd = st.stdev(ds)
        se = sd / len(ds) ** 0.5
        verdict = "雜訊內" if abs(md) < 2 * max(se, 1e-9) else ("A 較高" if md > 0 else "A 較低")
    res[k] = {"A": round(st.mean(x[k] for x in runs if x["side"] == "A"), 2), "B": round(st.mean(x[k] for x in runs if x["side"] == "B"), 2),
              "diff": round(md, 2), "round_sd": round(sd, 2), "rounds": len(ds), "verdict": verdict}
json.dump({"runs": runs, "summary": res}, open(os.path.join(out, "summary.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
for k, v in res.items():
    print(f"PERFAB {k}: A {v['A']} / B {v['B']}（每輪差平均 {v['diff']:+}、輪間標準差 {v['round_sd']}、{v['rounds']} 輪）{v['verdict']}")
