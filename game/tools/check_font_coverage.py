#!/usr/bin/env python3
"""字型涵蓋檢查（第五輪 §5.3）：遊戲會顯示的字（strings.csv、puzzles.json、codex.json、credits.txt、程式裡的字）
都要在介面字型（V1.2 起源泉圓體）子集裡；不然那幾個字會靜靜 fallback 成系統字型（循徑拾光踩過的坑）。缺字 exit 1。
標題字 ThenKhung 原字型本來就沒有的字由介面字型 Bold 補，不算缺字。"""
import os, glob, re, sys
from fontTools.ttLib import TTFont
root = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen"))
import fontchars
need = sorted(c for c in fontchars.base_text(root, False) if not c.isspace())
bad = []
for w in ["R", "B"]:   # V1.2：介面中文字型＝源泉圓體（NTB Rounded）
    cmap = TTFont(os.path.join(root, "fonts", f"NTBRounded-{w}-sub.otf")).getBestCmap()
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
# V1.4 #17：簡中、日文：自己的字型＋繁中字型（後備）合起來要涵蓋
for tag, col in [("SC", "zh_CN"), ("JP", "ja")]:
    for w in ["R", "B"]:
        fp = os.path.join(root, "fonts", f"NTBRounded{tag}-{w}-sub.otf")
        if not os.path.exists(fp):
            bad.append(f"少了 {os.path.basename(fp)}")
            continue
        cm = set(TTFont(fp).getBestCmap()) | set(TTFont(os.path.join(root, "fonts", f"NTBRounded-{w}-sub.otf")).getBestCmap())
        miss = [c for c in fontchars.lang_text(root, col, False) if not c.isspace() and ord(c) not in cm]
        if miss:
            bad.append(f"{col} {w} 缺 {len(miss)} 字：{''.join(miss[:40])}")
# 1.2.0（Codex cat02 #5）：工藝字型的後備鏈（語言字型 → 繁中 Sans → 經典圓體）＋英數 Sans Latin 合起來要涵蓋；標題 NTB Title 缺的字由正文 Bold 補
def _cm(name):
    fp = os.path.join(root, "fonts", name)
    return set(TTFont(fp).getBestCmap()) if os.path.exists(fp) else None
for w in ["R", "B"]:
    lat = _cm(f"NTBSansLatin-{w}-sub.ttf")
    base = _cm(f"NTBSans-{w}-sub.otf")
    rnd = _cm(f"NTBRounded-{w}-sub.otf") or set()
    if lat is None or base is None:
        bad.append(f"少了工藝字型 {w}")
        continue
    for tag, col in [("", None), ("SC", "zh_CN"), ("JP", "ja")]:
        own = _cm(f"NTBSans{tag}-{w}-sub.otf") if tag else set()
        if own is None:
            bad.append(f"少了 NTBSans{tag}-{w}")
            continue
        cm = own | base | rnd | lat
        chars = need if col is None else [c for c in fontchars.lang_text(root, col, False) if not c.isspace()]
        miss = [c for c in chars if ord(c) not in cm]
        if miss:
            bad.append(f"工藝 {col or 'zh_TW/en'} {w} 缺 {len(miss)} 字：{''.join(miss[:40])}")
print("FONTCOVER", "OK" if not bad else "；".join(bad), f"（{len(need)} 字）")
sys.exit(1 if bad else 0)
