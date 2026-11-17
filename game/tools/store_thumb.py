#!/usr/bin/env python3
"""1.6.0 B19（P8.3；K2 自動部分）商店圖縮圖辨識：把商店截圖縮到 Steam 小圖寬（462px）後量
① 藍、紅兩隊隊色像素各占多少（都要 ≥0.4%＝縮小後還看得到兩邊的兵）；② 兩隊平均色的 ΔE（CIE76，≥40＝顏色分得開）；
③ 畫面平均亮度（≥55＝沒被遮罩壓暗）。真人「縮圖辨識」（K2 人工）另外做，這裡只是自動門檻。
用法：PYTHONPATH=build/pylibnp python3 game/tools/store_thumb.py <資料夾>；印 STORETHUMB OK／FAIL。"""
import sys, os, glob
import numpy as np
from PIL import Image

def lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

bad = 0
files = sorted(glob.glob(os.path.join(sys.argv[1], "store_*.png")))
for p in files:
    im = Image.open(p).convert("RGB")
    im = im.crop((40, 75, 1240, 690))   # 只看戰場區：上面的戰力條、下面的兵種盤／開戰鈕／時間軸都是介面色，不算兵（Codex B19 r1）
    im = im.resize((462, int(im.height * 462 / im.width)), Image.LANCZOS)
    a = np.asarray(im).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    blue = (b > r + 40) & (b > g + 10) & (b > 120)
    red = (r > g + 60) & (r > b + 40) & (r > 140)
    pb, pr = blue.mean() * 100, red.mean() * 100
    de = float(np.linalg.norm(lab(a[blue].mean(0)) - lab(a[red].mean(0)))) if blue.any() and red.any() else 0.0
    lum = a.mean()
    place = "place" in os.path.basename(p)   # 擺陣畫面看不到紅軍（對方地盤遮著）：只要求藍軍看得到；量到的紅多半是藍兵身上的紅配件
    ok = pb >= 0.4 and (place or (pr >= 0.4 and de >= 40)) and lum >= 55
    bad += 0 if ok else 1
    print("%-24s 藍 %.2f%%  紅 %.2f%%  ΔE %.0f  亮度 %.0f  %s" % (os.path.basename(p), pb, pr, de, lum, "OK" if ok else "FAIL"))
print("STORETHUMB %s（%d 張、不合格 %d）" % ("OK" if files and bad == 0 else "FAIL", len(files), bad))
sys.exit(0 if files and bad == 0 else 1)
