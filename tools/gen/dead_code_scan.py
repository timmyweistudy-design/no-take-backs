#!/usr/bin/env python3
"""1.1.0 A20：死碼「候選」清單（只列，不刪）。
找 game/ 下所有 .gd 定義的 func，在全部 .gd／.tscn／.cfg／.py／.sh 文字裡（扣掉定義那一行）找名字出現的次數。
名字出現在字串裡（call("名字")、get、set、connect、Callable）也算有用到。Godot 的引擎回呼（_ready、_draw…）與 test_ 開頭略過。
輸出 docs/review/v110/dead_code.md：名字、檔案:行號。每一筆要人工證明真的沒人用才刪（Codex v110p：文字搜尋會誤判）。"""
import re, os, collections
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
G = os.path.join(ROOT, "game")
ENGINE = {"_ready", "_process", "_physics_process", "_draw", "_input", "_unhandled_input", "_init", "_exit_tree", "_enter_tree", "_notification", "_gui_input", "_get_property_list", "_to_string"}
defs = []
texts = {}
for dp, dn, fn in os.walk(G):
    if "/.godot" in dp or dp.endswith(".godot"):
        continue
    for f in fn:
        if f.endswith((".gd", ".tscn", ".cfg", ".py", ".sh")):
            p = os.path.join(dp, f)
            t = open(p, encoding="utf-8", errors="ignore").read()
            texts[p] = t
            if f.endswith(".gd"):
                for i, line in enumerate(t.split("\n"), 1):
                    m = re.match(r"\s*(?:static\s+)?func\s+([A-Za-z_]\w*)", line)
                    if m:
                        defs.append((m.group(1), p, i))
alltext = "\n".join(texts.values())
counts = collections.Counter(re.findall(r"[A-Za-z_]\w*", alltext))
cand = []
for name, p, ln in defs:
    if name in ENGINE or name.startswith("test_"):
        continue
    ndefs = sum(1 for d in defs if d[0] == name)
    if counts[name] <= ndefs:   # 只有定義本身出現
        cand.append((name, os.path.relpath(p, ROOT), ln))
out = os.path.join(ROOT, "docs", "review", "v110", "dead_code.md")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    f.write("# 死碼候選（1.1.0 A20，自動掃描，**未刪**）\n\n每一筆要人工確認：動態呼叫（字串拼接的方法名）、編輯器／工具入口、測試替身都可能讓它看起來沒人用。\n\n| 函式 | 位置 |\n|---|---|\n")
    for name, p, ln in sorted(cand, key=lambda x: (x[1], x[2])):
        f.write(f"| `{name}` | `{p}:{ln}` |\n")
print(len(defs), "個函式；候選", len(cand), "→", out)
