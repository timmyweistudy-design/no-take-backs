#!/usr/bin/env python3
"""V1.4 #4：把第 12 章鍛造結果附加進 game/data/puzzles.json（不動前 10 章）。
用法：python3 tools/gen/chapter11_merge.py <草稿.json> <final_*.txt ...>
- 沒找到解、什麼都不放就過的關略過（照 puzzle_merge.py 的規則）。
- 章內依隨機擺法過關率由高到低（簡單在前）。重跑會先拿掉舊的第 12 章再放。
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game/data/puzzles.json"
CH12 = {"zh": "軍令連鎖", "en": "Command Chains",
        "story_zh": "將軍給了你一整套軍令：冰封、隕石、護盾、戰吼。單獨用都普通，排對順序才是殺著。",
        "story_en": "The general hands you a full set of orders: freeze, meteor, shield, war cry. Alone they are ordinary; in the right order they decide the battle."}


def main():
    drafts = json.load(open(sys.argv[1], encoding="utf-8"))
    res = {}
    for f in sys.argv[2:]:
        for line in open(f, encoding="utf-8", errors="ignore"):
            if line.startswith("FORGE "):
                r = json.loads(line[6:])
                res[r["id"]] = r
    data = json.load(open(DATA, encoding="utf-8"))
    extra = [p for p in data["extra"] if int(p.get("ch", 0)) != 12]
    add, skipped = [], []
    for d0 in drafts:
        d = dict(d0)
        r = res.get(d["id"])
        if r is None or "best" not in r:
            skipped.append((d["id"], "沒有找到解" if r else "沒有結果"))
            continue
        if r["metrics"].get("empty_ok"):
            skipped.append((d["id"], "什麼都不放就過"))
            continue
        d["star2"] = max(1, min(r["star2"], 99))
        d["star3"] = r["star3"]
        d["solutions"] = r["solutions"]
        d["best"] = r["best"]
        if "sol_plans" in r:
            d["sol_plans"] = r["sol_plans"]
        d["_m"] = {k: r["metrics"][k] for k in ("rand_pct", "kinds", "tol", "ticks") if k in r["metrics"]}
        add.append(d)
    add.sort(key=lambda d: -d["_m"].get("rand_pct", 0))
    data["extra"] = extra + add
    chs = data["chapters"][:11]
    data["chapters"] = chs + [CH12]
    json.dump(data, open(DATA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("第 12 章併入", len(add), "關")
    for i, why in skipped:
        print("略過", i, why)


if __name__ == "__main__":
    main()
