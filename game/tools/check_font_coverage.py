#!/usr/bin/env python3
"""字型涵蓋檢查（第五輪 §5.3）：遊戲會顯示的字（strings.csv、puzzles.json、codex.json、credits.txt、程式裡的字）
都要在思源黑體子集裡；不然那幾個字會靜靜 fallback 成系統字型（循徑拾光踩過的坑）。缺字 exit 1。
標題字 ThenKhung 原字型本來就沒有的字由思源黑體 Bold 補，不算缺字。"""
import os, glob, sys
from fontTools.ttLib import TTFont
root = os.path.join(os.path.dirname(__file__), "..")
chars = set()
for pat in ["data/*.csv", "data/*.json", "data/*.txt", "scripts/**/*.gd"]:
    for f in glob.glob(os.path.join(root, pat), recursive=True):
        chars.update(open(f, encoding="utf-8").read())
need = sorted(c for c in chars if c.isprintable() and not c.isspace() and ord(c) >= 0x20)
bad = []
for w in ["Regular", "Bold"]:
    cmap = TTFont(os.path.join(root, "fonts", f"NotoSansTC-{w}-sub.otf")).getBestCmap()
    miss = [c for c in need if ord(c) not in cmap]
    if miss:
        bad.append(f"{w} 缺 {len(miss)} 字：{''.join(miss[:40])}")
# 標題字：子集裡沒有的字，必須是原字型本來就沒有的（build_font.py 寫在 ThenKhung-missing.txt），否則就是漏子集化
tk = os.path.join(root, "fonts", "ThenKhung-sub.ttf")
if os.path.exists(tk):
    tcm = TTFont(tk).getBestCmap()
    allowed = set(open(os.path.join(root, "fonts", "ThenKhung-missing.txt"), encoding="utf-8").read()) if os.path.exists(os.path.join(root, "fonts", "ThenKhung-missing.txt")) else set()
    miss = [c for c in need if ord(c) not in tcm and c not in allowed]
    if miss:
        bad.append(f"標題字缺 {len(miss)} 字（不是原字型沒有的）：{''.join(miss[:40])}")
print("FONTCOVER", "OK" if not bad else "；".join(bad), f"（{len(need)} 字）")
sys.exit(1 if bad else 0)
