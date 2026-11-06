#!/usr/bin/env python3
"""第十三輪：自動調殘局預算（粗跑 → 找不到解就加錢、太簡單就減錢 → 只重跑有改的）。

python3 tools/gen/puzzle_tune.py <草稿.json> <粗跑輸出資料夾> <回合數>
- 找不到解：預算 ×1.25（至少 +4）。
- 隨機擺法過關率 > 45%：預算 ×0.85（至少 -2）。
- 其他不動。每回合把草稿寫回、只跑要重算的關，結果累積在資料夾的 tune_<回合>_<分片>.txt。
需要 GODOT 環境變數；在 build/cg/game 快照上跑（不碰 game/）。
"""
import glob
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAP = ROOT / "build/cg/game"


def latest(folder):
    res = {}
    files = sorted(glob.glob(str(Path(folder) / "probe_*.txt"))) + sorted(glob.glob(str(Path(folder) / "tune_*.txt")))
    files.sort(key=os.path.getmtime)
    for f in files:
        for line in open(f, encoding="utf-8", errors="ignore"):
            if line.startswith("FORGE "):
                r = json.loads(line[6:])
                res[r["id"]] = r
    return res


def main():
    draft_path, folder, rounds = sys.argv[1], sys.argv[2], int(sys.argv[3])
    godot = os.environ["GODOT"]
    for rnd in range(rounds):
        drafts = json.load(open(draft_path, encoding="utf-8"))
        res = latest(folder)
        redo = []
        for d in drafts:
            r = res.get(d["id"])
            if r is None:
                continue
            m = r["metrics"]
            if m.get("empty_ok"):
                d["budget"] = max(4, int(d["budget"] * 0.7))
                redo.append(d)
            elif "best" not in r:
                d["budget"] = max(d["budget"] + 4, int(d["budget"] * 1.25))
                redo.append(d)
            elif m.get("rand_pct", 0) > 45:
                d["budget"] = min(d["budget"] - 2, int(d["budget"] * 0.85))
                redo.append(d)
        json.dump(drafts, open(draft_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("回合", rnd, "重算", [(d["id"], d["budget"]) for d in redo], flush=True)
        if not redo:
            break
        sub = Path(folder) / f"redo_{rnd}.json"
        json.dump(redo, open(sub, "w", encoding="utf-8"), ensure_ascii=False)
        n = min(14, len(redo))
        procs = []
        for i in range(n):
            out = open(Path(folder) / f"tune_{rnd}_{i}.txt", "w", encoding="utf-8")
            rel = os.path.relpath(sub, SNAP).replace(os.sep, "/")   # Windows 版 Godot 吃相對路徑
            procs.append(subprocess.Popen([godot, "--headless", "--path", ".", "--script", "res://tools/balance/puzzle_forge.gd", "--",
                                           f"--in={rel}", "--iters=400", "--seeds=1", f"--shard={i}", f"--shards={n}"],
                                          cwd=str(SNAP), stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT))
        for p in procs:
            p.wait()


if __name__ == "__main__":
    main()
