#!/usr/bin/env python3
"""1.1.0 N3：色覺模擬接觸表。把截圖套 Machado 2009 的紅色盲／綠色盲／藍色盲矩陣（嚴重度 1.0），四欄並排（原圖＋三種），
用來看隊伍顏色、地形（擋路、慢、快）和地塊底色在色弱下分不分得開。另外算每張圖「隊伍藍、紅（或色盲模式藍、橘）」在三種模擬下的色差 ΔE（CIE76）。
用法：python3 tools/gen/cb_sim.py <輸出 png> <截圖1> [截圖2 …]"""
import sys, math
from PIL import Image
M = {"原圖": None,
     "紅色盲": (0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998),
     "綠色盲": (0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881),
     "藍色盲": (1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900)}
def lin(c): c /= 255.0; return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def gam(c): c = max(0.0, min(1.0, c)); return round(255 * (12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055))
def sim(rgb, m):
    r, g, b = (lin(v) for v in rgb)
    return (gam(m[0]*r+m[1]*g+m[2]*b), gam(m[3]*r+m[4]*g+m[5]*b), gam(m[6]*r+m[7]*g+m[8]*b))
def lab(rgb):
    r, g, b = (lin(v) for v in rgb)
    x = (0.4124*r+0.3576*g+0.1805*b)/0.95047; y = 0.2126*r+0.7152*g+0.0722*b; z = (0.0193*r+0.1192*g+0.9505*b)/1.08883
    f = lambda t: t ** (1/3) if t > 0.008856 else 7.787*t + 16/116
    return (116*f(y)-16, 500*(f(x)-f(y)), 200*(f(y)-f(z)))
def de(a, b):
    return math.dist(lab(a), lab(b))
def convert(im, m):
    if m is None:
        return im.copy()
    lut = {}
    out = Image.new("RGB", im.size)
    src, dst = im.load(), out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            p = src[x, y]
            q = lut.get(p)
            if q is None:
                q = lut[p] = sim(p, m)
            dst[x, y] = q
    return out
out, shots = sys.argv[1], sys.argv[2:]
W = 480
rows = []
for s in shots:
    im = Image.open(s).convert("RGB")
    im = im.resize((W, int(im.size[1] * W / im.size[0])))
    rows.append([convert(im, m) for m in M.values()])
H = sum(r[0].size[1] for r in rows)
sheet = Image.new("RGB", (W * len(M), H), (30, 30, 30))
y = 0
for r in rows:
    for i, im in enumerate(r):
        sheet.paste(im, (i * W, y))
    y += r[0].size[1]
sheet.save(out)
for name, pair in (("標準隊色 藍／紅", ((0x45, 0xac, 0xff), (0xd9, 0x3a, 0x44))), ("色盲模式 藍／橘", ((0x2f, 0x80, 0xff), (0xff, 0xb0, 0x00)))):
    vals = ["%s ΔE %.0f" % (k, de(*(pair if m is None else (sim(pair[0], m), sim(pair[1], m))))) for k, m in M.items()]
    print(name + "：" + "、".join(vals))
print("SHEET", out)
