#!/usr/bin/env python3
"""第十三輪：把 trial_forge 的 TFORGE 輸出寫成 game/data/trials.json（索引 10～29）。

python3 tools/gen/trial_merge.py <tf_*.txt...>
沒找到解的關印出來、不寫入（測試會抓到缺關）。
"""
import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "game/data/trials.json"
KEYS = ("i", "zh", "en", "tag_zh", "tag_en", "pool0", "budget", "depth", "type_cap", "cmd", "enemy", "rem", "spend", "best")


def main():
    res = {}
    for f in sys.argv[1:]:
        for line in open(f, encoding="utf-8", errors="ignore"):
            if line.startswith("TFORGE "):
                r = json.loads(line[7:])
                res[int(r["i"])] = r
    out, bad = [], []
    for i in sorted(res):
        r = res[i]
        if r["found"] == 0:
            bad.append(i)
            continue
        sp = r["spec"]
        d = {k: sp[k] for k in KEYS if k in sp}
        for k in ("i", "budget", "depth", "type_cap", "cmd", "rem", "spend"):
            if k in d:
                d[k] = int(d[k])
        d["enemy"] = [[int(v) for v in u] for u in d["enemy"]]
        d["best"] = [[int(v) for v in u] for u in d["best"]]
        out.append(d)
    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("寫入", len(out), "關", "缺", bad)


if __name__ == "__main__":
    main()
