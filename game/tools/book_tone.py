#!/usr/bin/env python3
"""1.6.0 B04（S1）：挑戰簿灰階——每組 22_lobby 的簿紙（左頁空白處）中位 L* 45～65、2% 分位（暗斑）、暗木框中位 L* 12～15。
簡化介面組（plain）照舊平塗亮紙，不比。缺圖或組數不足＝失敗。
用法：PYTHONPATH=../build/pylibnp python3 tools/book_tone.py <版面輸出夾> [--expect N]   最後一行 BOOK OK／BOOK FAIL"""
import os, sys
import numpy as np
from PIL import Image

def lstar(a):
    x = a.astype(float) / 255.0
    x = np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
    y = x @ np.array([0.2126, 0.7152, 0.0722])
    return np.where(y > 0.008856, 116.0 * np.cbrt(y) - 16.0, 903.3 * y)

out = sys.argv[1]
exp = int(sys.argv[sys.argv.index("--expect") + 1]) if "--expect" in sys.argv else 1
fails, n = [], 0
for c in sorted(os.listdir(out)):
    p = os.path.join(out, c, "22_lobby.png")
    if not os.path.isdir(os.path.join(out, c)):
        continue
    if not os.path.isfile(p):
        fails.append("%s 缺 22_lobby" % c); continue
    if "plain" in c:
        continue
    L = lstar(np.asarray(Image.open(p).convert("RGB")))
    paper = L[520:660, 100:640]
    med, p2 = float(np.median(paper)), float(np.percentile(paper, 2))
    frame = float(np.median(np.concatenate([L[30:60, 100:400].ravel(), L[200:600, 52:62].ravel()])))
    n += 1
    print("%s 簿紙 %.1f（2%% %.1f） 木框 %.1f" % (c, med, p2, frame))
    if not (45.0 <= med <= 65.0):
        fails.append("%s 簿紙 %.1f" % (c, med))
    if not (12.0 <= frame <= 15.0):
        fails.append("%s 木框 %.1f" % (c, frame))
if n < exp:
    fails.append("只量到 %d 組（要 %d）" % (n, exp))
print("BOOK OK（%d 組）" % n if not fails else "BOOK FAIL " + "；".join(fails))
sys.exit(1 if fails else 0)
