#!/usr/bin/env python3
"""V1.5.2 排版違規全表：彙整版面輸出夾裡每組 layout.jsonl 的排版規則（R1…R10、G）違規、警告與宣告例外。
用法：python3 tools/layout_table.py <版面輸出夾> [--md 輸出.md]"""
import json, glob, os, sys, collections
src = sys.argv[1]; md = sys.argv[sys.argv.index("--md") + 1] if "--md" in sys.argv else ""
fails = collections.defaultdict(set); warns = collections.defaultdict(set); ex = {}
for f in sorted(glob.glob(os.path.join(src, "*", "layout.jsonl"))):
    combo = os.path.basename(os.path.dirname(f))
    for line in open(f, encoding="utf-8"):
        d = json.loads(line)
        for v in d["violations"]:
            if str(v.get("type", "")).startswith("排版"):
                fails[(v["type"], d["shot"], v.get("s", "")[:70])].add(combo)
        for v in d.get("geo_warn", []):
            warns[(v["type"], d["shot"], v.get("s", "")[:70])].add(combo)
        for e in d.get("geo_exempt", []):
            ex[(e["rule"], d["shot"])] = e["why"]
out = ["# 排版違規全表（%s）" % src, "", "失敗 %d 條、警告 %d 條、宣告例外 %d 條" % (len(fails), len(warns), len(ex)), ""]
for title, tb in (("失敗", fails), ("警告", warns)):
    out.append("## " + title)
    for (t, shot, s), cs in sorted(tb.items()):
        out.append("- %s %s：%s（%d 組：%s）" % (t, shot, s, len(cs), ",".join(sorted(cs))[:120]))
    out.append("")
out.append("## 宣告例外")
for (r, shot), why in sorted(ex.items()):
    out.append("- %s %s：%s" % (r, shot, why))
txt = "\n".join(out)
if md: open(md, "w", encoding="utf-8").write(txt + "\n")
print("TABLE 失敗 %d、警告 %d、例外 %d" % (len(fails), len(warns), len(ex)))
