#!/usr/bin/env python3
"""V1.5.2 看圖找錯用的接觸表：把版面檢查的截圖拼成一張，每格畫畫面中線（x=640）與水平參考線，標組名與畫面名。
用法：python3 tools/layout_sheet.py <版面輸出夾> <輸出.png> [--shots 59b_nemeses,lobby*] [--combos zh_TW_100,en_150] [--cols 4] [--w 480]
可給兩個輸出夾（--before 舊夾）做修前／修後並排。"""
import argparse, fnmatch, glob, os, sys
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("out")
ap.add_argument("--shots", default="*"); ap.add_argument("--combos", default="*")
ap.add_argument("--cols", type=int, default=4); ap.add_argument("--w", type=int, default=480)
ap.add_argument("--before", default="")
ap.add_argument("--commit", default="")
a = ap.parse_args()
pats = a.shots.split(","); cpats = a.combos.split(",")
cells = []
for d in sorted(glob.glob(os.path.join(a.src, "*"))):
    if not os.path.isdir(d): continue
    combo = os.path.basename(d)
    if not any(fnmatch.fnmatch(combo, p) for p in cpats): continue
    for f in sorted(glob.glob(os.path.join(d, "*.png"))):
        n = os.path.basename(f)
        if any(fnmatch.fnmatch(n, p) or fnmatch.fnmatch(n[:-4], p) for p in pats):
            pair = [f]
            if a.before:
                b = os.path.join(a.before, combo, n)
                pair = [b if os.path.exists(b) else None, f]
            cells.append((combo, n, pair))
if not cells: print("SHEET 沒有符合的截圖"); sys.exit(1)
W = a.w; H = W * 800 // 1280; lab = 18
per = 2 if a.before else 1
cols = max(1, a.cols // per) * per
n = len(cells) * per
rows = (n + cols - 1) // cols
sheet = Image.new("RGB", (cols * W, rows * (H + lab) + 24), (30, 30, 30))
dr = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/mnt/c/Windows/Fonts/msjh.ttc", 13)
except Exception:
    font = ImageFont.load_default()
dr.text((4, 4), "中線＝x640（紅）、y400（藍）  %s" % a.commit, fill=(255, 255, 255), font=font)
k = 0
for combo, name, pair in cells:
    for j, f in enumerate(pair):
        x = (k % cols) * W; y = 24 + (k // cols) * (H + lab)
        tag = ("修前 " if a.before and j == 0 else ("修後 " if a.before else "")) + combo + " " + name
        dr.text((x + 3, y + 1), tag[:60], fill=(255, 230, 150), font=font)
        if f:
            im = Image.open(f).convert("RGB").resize((W, H))
            g = ImageDraw.Draw(im)
            g.line([(W // 2, 0), (W // 2, H)], fill=(255, 40, 40), width=1)
            g.line([(0, H // 2), (W, H // 2)], fill=(60, 120, 255), width=1)
            sheet.paste(im, (x, y + lab))
        k += 1
sheet.save(a.out)
print("SHEET %d 格 → %s" % (n, a.out))
