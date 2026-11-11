#!/usr/bin/env bash
# 1.2.0 §14.1：同一個 commit 上稽核「選測（有快取）」是否等於「全量（無快取）」。
# 先跑有快取的 check.py（快取命中的步驟會被視為通過），再無快取全量重跑；逐步比對通過與否、測試數、FINGERPRINT。
# 有任何一步「快取說通過、實跑失敗」或測試數不同 → 失敗，列出該步（代表依賴表漏了東西，要補進 check.py 的依賴規則）。
# 用法（在 game/ 下）：GODOT=<exe> tools/audit_selection.sh <輸出資料夾>
set -u
OUT=$(realpath -m "${1:-../build/tmp/audit}")
rm -rf "$OUT"; mkdir -p "$OUT"
python3 tools/check.py --out "$OUT/cached" </dev/null > "$OUT/cached.txt" 2>&1
python3 tools/check.py --no-cache --out "$OUT/full" </dev/null > "$OUT/full.txt" 2>&1
python3 - "$OUT" <<'PY'
import json, re, sys, os
out = sys.argv[1]
def load(side):
    d = json.load(open(os.path.join(out, side, "summary.json"), encoding="utf-8"))
    res = {}
    for s in d["steps"]:
        lg = os.path.join(out, side, s["name"] + ".log")
        txt = open(lg, encoding="utf-8", errors="ignore").read() if os.path.isfile(lg) else ""
        m = re.search(r"^—— (\d+) 通過 / (\d+) 失敗", txt, re.M)
        res[s["name"]] = {"ok": s["ok"], "cached": s.get("cached", False), "tests": m.group(1) if m else None}
    return res, d.get("fingerprint", "")
c, fc = load("cached"); f, ff = load("full")
bad = []
for n, v in f.items():
    if n not in c:
        bad.append(f"{n}：有快取那次沒有這一步")
        continue
    if c[n]["ok"] != v["ok"]:
        bad.append(f"{n}：有快取 {'過' if c[n]['ok'] else '失敗'}／全量 {'過' if v['ok'] else '失敗'}（快取命中＝{c[n]['cached']}）")
    elif c[n]["tests"] != v["tests"]:
        bad.append(f"{n}：測試數 {c[n]['tests']} vs {v['tests']}")
if fc != ff:
    bad.append(f"FINGERPRINT 不同：{fc} vs {ff}")
json.dump({"bad": bad}, open(os.path.join(out, "audit.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("AUDIT OK：選測與全量一致" if not bad else "AUDIT FAIL：" + "；".join(bad[:10]))
sys.exit(1 if bad else 0)
PY
