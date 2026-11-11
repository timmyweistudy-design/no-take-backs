"""1.2.0 §14.8：彙整 perf_ab.sh 的 ABBA 結果：成對差、標準差、結論（差 < 2 倍標準差＝雜訊內）。"""
import json, sys, glob, os, statistics as st
out = sys.argv[1]
rows = []
for f in sorted(glob.glob(os.path.join(out, "run_*.json"))):
    d = json.load(open(f, encoding="utf-8"))
    a = d["all"]
    rows.append({"side": f.rsplit("_", 1)[1][0], "p50": a["draw_ms"]["p50"], "p95": a["draw_ms"]["p95"], "p99": a["draw_ms"]["p99"],
                 "gpu95": a["gpu_ms"]["p95"], "tex": d.get("tex_mem_mib", 0), "bake": d.get("atlas_sweep", {}).get("worst_bake_frame_ms", 0)})
res = {}
for k in ["p50", "p95", "p99", "gpu95", "tex", "bake"]:
    va = [r[k] for r in rows if r["side"] == "A"]
    vb = [r[k] for r in rows if r["side"] == "B"]
    pairs = [x - y for x, y in zip(va, vb)]
    sd = st.pstdev(va + vb) if len(va + vb) > 1 else 0.0
    mean = st.mean(pairs) if pairs else 0.0
    res[k] = {"A": round(st.mean(va), 2), "B": round(st.mean(vb), 2), "diff": round(mean, 2), "sd": round(sd, 2),
              "verdict": "雜訊內" if abs(mean) < 2 * max(sd, 0.01) else ("A 較高" if mean > 0 else "A 較低")}
json.dump({"runs": rows, "summary": res}, open(os.path.join(out, "summary.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
for k, v in res.items():
    print(f"PERFAB {k}: A {v['A']} / B {v['B']}（差 {v['diff']:+}，標準差 {v['sd']}）{v['verdict']}")
