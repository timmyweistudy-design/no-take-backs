#!/usr/bin/env python3
"""V1.2 B3：介面材質貼圖（程式生成、本作原創、零授權成本）。只用 Pillow。
輸出（九宮格用，都是灰階或中性色，遊戲裡用 modulate 染成原本的底色，配色不變）：
  wood.png    木紋方塊：圓角 8、上緣亮斜角、下緣暗斜角、細木紋（灰階 → 用底色染）
  paper.png   羊皮紙：纖維、斑點、邊緣微焦（本身就是紙色，不再染）
  groove.png  凹槽：內陰影（灰階 → 用底色染）
  frame.png   面板外框：深木框＋四角銅釘（直接用，不染）
  vignette.png 暈影：中心透明、四周暗（戰場與標題用）
用法：python3 tools/gen/gen_ui_tex.py <輸出資料夾>（預設 game/art/ui）
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "game", "art", "ui")
os.makedirs(OUT, exist_ok=True)
R = random.Random(20261107)


def noise(w, h, scale_x, scale_y, sigma=64):
    """拉長的雜訊：先生成小張雜訊再放大（木紋＝橫向拉長）。"""
    n = Image.effect_noise((max(1, w // scale_x), max(1, h // scale_y)), sigma)
    return n.resize((w, h), Image.BICUBIC)


def rounded_mask(w, h, rad):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), rad, fill=255)
    return m


def bevel(w, h, rad, top=46, bottom=56):
    """上亮下暗的斜角：用逐列漸層（128＝不變），圓角由遮罩處理，四角不會缺。"""
    b = Image.new("L", (w, h), 128)
    px = b.load()
    for y in range(h):
        if y < 3:
            v = 128 + int(top * (1 - y / 3))
        elif y >= h - 4:
            v = 128 - int(bottom * ((y - (h - 4)) / 3))
        else:
            v = 128 + int(10 * (0.5 - y / h))   # 上半略亮、下半略暗的柔和明暗
        for x in range(w):
            px[x, y] = v
    return b

def apply_shift(base, shift):
    """base（L）加上 shift（128＝0）。"""
    return ImageChops.add(ImageChops.subtract(base, Image.new("L", base.size, 128)), shift, 1.0, -128).point(lambda v: max(0, min(255, v)))


def wood(w=64, h=64, rad=8):
    g = noise(w, h, 16, 1, 40).filter(ImageFilter.GaussianBlur(0.8))
    g = g.point(lambda v: int(200 + (v - 128) * 0.22))          # 很淡的木紋：底色 ~200
    # 幾條較深的木紋線
    d = ImageDraw.Draw(g)
    for k in range(5):
        y = R.randint(6, h - 6)
        amp = R.uniform(0.5, 2.0)
        pts = [(x, y + amp * math.sin(x / R.uniform(6, 12) + k)) for x in range(0, w, 2)]
        d.line(pts, fill=184, width=1)
    g = g.filter(ImageFilter.GaussianBlur(0.4))
    g = ImageChops.add(g, bevel(w, h, rad), 1.0, -128)
    img = Image.merge("LA", (g, rounded_mask(w, h, rad)))
    return img.convert("RGBA")


def groove(w=48, h=48, rad=6):
    g = Image.new("L", (w, h), 200)
    sh = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(sh)
    for i in range(6):
        d.rounded_rectangle((i, i, w - 1 - i, h - 1 - i), max(1, rad - i), outline=int(70 - i * 11))
    sh = sh.filter(ImageFilter.GaussianBlur(1.2))
    g = ImageChops.subtract(g, sh)
    g = ImageChops.add(g, noise(w, h, 2, 2, 20).point(lambda v: int((v - 128) * 0.15 + 128)), 1.0, -128)
    img = Image.merge("LA", (g, rounded_mask(w, h, rad)))
    return img.convert("RGBA")


def paper(w=128, h=128, rad=6):
    base = Image.new("RGB", (w, h), (236, 218, 182))
    fib = noise(w, h, 3, 1, 60).point(lambda v: int((v - 128) * 0.28 + 128))
    blot = noise(w, h, 24, 24, 80).filter(ImageFilter.GaussianBlur(4)).point(lambda v: int((v - 128) * 0.25 + 128))
    tone = ImageChops.add(fib, blot, 1.0, -128)
    r, g, b = base.split()
    r = ImageChops.add(r, tone, 1.0, -128)
    g = ImageChops.add(g, tone, 1.0, -128)
    b = ImageChops.add(b, tone, 1.0, -132)
    img = Image.merge("RGB", (r, g, b))
    # 邊緣微焦
    edge = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(edge)
    for i in range(10):
        d.rounded_rectangle((i, i, w - 1 - i, h - 1 - i), rad, outline=int(90 * (1 - i / 10)))
    edge = edge.filter(ImageFilter.GaussianBlur(2))
    burn = Image.new("RGB", (w, h), (120, 80, 40))
    img = Image.composite(burn, img, edge.point(lambda v: int(v * 0.55)))
    out = img.convert("RGBA")
    out.putalpha(rounded_mask(w, h, rad))
    return out


def frame(w=96, h=96, border=14, rad=12):
    """面板外框：深木框（內部透明），四角銅釘。"""
    wd = wood(w, h, rad)
    col = Image.new("RGBA", (w, h), (92, 64, 42, 255))
    img = ImageChops.multiply(col, wd)
    img.putalpha(rounded_mask(w, h, rad))
    hole = Image.new("L", (w, h), 255)
    ImageDraw.Draw(hole).rounded_rectangle((border, border, w - 1 - border, h - 1 - border), 6, fill=0)
    a = ImageChops.multiply(img.getchannel("A"), hole)
    img.putalpha(a)
    d = ImageDraw.Draw(img)
    # 內緣暗線（框和內容之間的陰影）
    d.rounded_rectangle((border - 1, border - 1, w - border, h - border), 7, outline=(26, 16, 10, 200), width=2)
    for cx, cy in [(border // 2 + 1, border // 2 + 1), (w - border // 2 - 2, border // 2 + 1), (border // 2 + 1, h - border // 2 - 2), (w - border // 2 - 2, h - border // 2 - 2)]:
        d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(141, 98, 52, 255), outline=(40, 24, 12, 255))
        d.ellipse((cx - 2, cy - 2, cx, cy), fill=(239, 214, 160, 255))
    return img


def vignette(w=256, h=160):
    m = Image.new("L", (w, h), 0)
    px = m.load()
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2) / (w / 2)
            dy = (y - h / 2) / (h / 2)
            dd = math.sqrt(dx * dx * 0.9 + dy * dy * 1.1)
            px[x, y] = int(max(0.0, min(1.0, (dd - 0.55) / 0.6)) ** 1.6 * 200)
    img = Image.new("RGBA", (w, h), (20, 11, 6, 0))
    img.putalpha(m.filter(ImageFilter.GaussianBlur(3)))
    return img


for name, im in [("wood", wood()), ("groove", groove()), ("paper", paper()), ("frame", frame()), ("vignette", vignette())]:
    p = os.path.join(OUT, name + ".png")
    im.save(p)
    print(name, im.size, os.path.getsize(p), "B")
