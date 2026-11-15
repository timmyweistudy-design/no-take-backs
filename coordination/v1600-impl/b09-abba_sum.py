# B09 ABBA 彙整（abba2.sh 的輸出）：python3 abba2_sum.py <b09 夾>
import json, os, sys
import statistics as st
def pct(a, p):
    a = sorted(a); return a[min(len(a) - 1, int(round(p / 100 * (len(a) - 1))))]
base = sys.argv[1] if len(sys.argv) > 1 else "."
for mode in ["blank", "scene"]:
    for side, nm in [("A", "即時烘"), ("B", "離線包")]:
        d = os.path.join(base, "abba2_" + mode)
        runs = [json.load(open(os.path.join(d, f))) for f in sorted(os.listdir(d)) if f.startswith(side + "_")]
        if not runs:
            continue
        cold = [r["cold"] for r in runs]
        warm = [w for r in runs for w in r["warm"]]
        miss = sum(int(r.get("misses", 0)) for r in runs)
        print(f"{mode} {side}（{nm}）程序 {len(runs)}、讀包失敗 {miss}｜冷 全部就緒 p50 {st.median([c['ms'] for c in cold]):.0f}／max {max(c['ms'] for c in cold)} ms、"
              f"最長幀（含開機頭兩幀）p50 {st.median([c['longest_frame_ms'] for c in cold]):.1f}／max {max(c['longest_frame_ms'] for c in cold):.1f}（頭兩幀 max {max(max(c['first2']) for c in cold):.1f}）｜"
              f"熱 {len(warm)} 次 最長幀 p50 {st.median([w['longest_frame_ms'] for w in warm]):.1f}／p95 {pct([w['longest_frame_ms'] for w in warm], 95):.1f}／max {max(w['longest_frame_ms'] for w in warm):.1f}、"
              f"重建 p50 {st.median([w['ms'] for w in warm]):.0f} ms｜暫存峰值 max {max([c['temp_peak_mib'] for c in cold] + [w['temp_peak_mib'] for w in warm]):.1f} MiB｜"
              f"貼圖峰值 max {max([c['tex_peak_mib'] for c in cold] + [w['tex_peak_mib'] for w in warm]):.1f}（重建時多 max {max(w['tex_peak_over_mib'] for w in warm):.1f}）MiB")
