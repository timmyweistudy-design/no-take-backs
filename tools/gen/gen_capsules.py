#!/usr/bin/env python3
"""V1.2 G：Steam 商店圖（零預算）。全部用遊戲自己的截圖、字型、木紋程式合成，不用 AI 生圖。
用法：python3 tools/gen/gen_capsules.py <截圖資料夾（layout_check 的 zh_TW_100）> [輸出資料夾]
輸出：header 920x430、small 462x174、main 1232x706、vertical 748x896、library_capsule 600x900、
library_hero 3840x1240（不放字）、library_logo 1280x720（透明底）、page_bg 1438x810，另外複製商店截圖。"""
import os, sys, shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
G = os.path.join(ROOT, "game")
SHOTS = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs", "release", "capsules")
os.makedirs(OUT, exist_ok=True)
F_TITLE = os.path.join(G, "fonts", "ThenKhung-sub.ttf")
F_LATIN = os.path.join(G, "fonts", "NTBLatin-B-sub.ttf")
INK = (36, 21, 11)
CREAM = (255, 246, 224)

def shot(name):
    return Image.open(os.path.join(SHOTS, name + ".png")).convert("RGB")

def field_crop():
    """標題畫面的示範戰場：兩軍對峙、沒有飄字與介面（Antigravity impl4：底圖不能有戰鬥 UI 字）。"""
    im = shot("01_title")
    return im.crop((535, 195, 1265, 555))

def cover(im, w, h, blur=0.0, dark=0.0):
    r = max(w / im.width, h / im.height)
    im = im.resize((int(im.width * r + 1), int(im.height * r + 1)), Image.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    im = im.crop((x, y, x + w, y + h))
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    im = ImageEnhance.Color(im).enhance(1.08)
    if dark > 0:
        im = Image.blend(im, Image.new("RGB", im.size, (20, 12, 6)), dark)
    return im

def vignette(im, strength=0.55):
    """用遊戲自己的暈影貼圖（art/ui/vignette.png，四周黑、中間透明）。"""
    v = Image.open(os.path.join(G, "art", "ui", "vignette.png")).convert("RGBA").resize(im.size, Image.LANCZOS)
    a = v.getchannel("A").point(lambda x: int(min(255, x * strength * 1.6)))
    dark = Image.new("RGB", im.size, (12, 7, 4))
    return Image.composite(dark, im.convert("RGB"), a)

def wood_plate(w, h):
    tile = Image.open(os.path.join(G, "art", "ui", "wood.png")).convert("RGB")
    plate = Image.new("RGB", (w, h))
    for y in range(0, h, tile.height):
        for x in range(0, w, tile.width):
            plate.paste(tile, (x, y))
    r, g, b = plate.split()
    plate = Image.merge("RGB", (r.point(lambda v: int(v * 0.95)), g.point(lambda v: int(v * 0.66)), b.point(lambda v: int(v * 0.42))))
    d = ImageDraw.Draw(plate)
    bw = max(3, h // 22)
    d.rectangle((0, 0, w - 1, h - 1), outline=(28, 16, 9), width=bw)
    d.line((bw, bw + 1, w - bw, bw + 1), fill=(214, 168, 110), width=max(1, bw // 2))
    for cx, cy in ((bw * 3, bw * 3), (w - bw * 3, bw * 3), (bw * 3, h - bw * 3), (w - bw * 3, h - bw * 3)):
        rr = max(3, bw)
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(181, 120, 54), outline=(60, 34, 14))
    return plate

def text_outlined(d, xy, s, font, fill, outline, ow, anchor="mm", shadow=True):
    x, y = xy
    if shadow:
        d.text((x, y + ow * 0.9), s, font=font, fill=(20, 11, 6), anchor=anchor, stroke_width=ow, stroke_fill=(20, 11, 6))
    d.text((x, y), s, font=font, fill=fill, anchor=anchor, stroke_width=ow, stroke_fill=outline)

def logo(w, h, transparent=False, subtitle=True):
    """木牌＋「落子無悔」＋ NO TAKE-BACKS。回傳 RGBA。subtitle=False：小膠囊用，木牌填滿（縮到 120×45 副標也看不見）。"""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pw, ph = (int(w * 0.86), int(h * 0.62)) if subtitle else (int(w * 0.96), int(h * 0.9))
    px, py = (w - pw) // 2, (int(h * 0.08) if subtitle else (h - ph) // 2)
    plate = wood_plate(pw, ph).convert("RGBA")
    sh = Image.new("RGBA", (pw, ph), (0, 0, 0, 150)).filter(ImageFilter.GaussianBlur(4))
    im.alpha_composite(sh, (px + max(2, w // 120), py + max(3, h // 60)))
    im.alpha_composite(plate, (px, py))
    d = ImageDraw.Draw(im)
    fs = int(ph * 0.66)
    f = ImageFont.truetype(F_TITLE, fs)
    while d.textlength("落子無悔", font=f) > pw * 0.86 and fs > 10:
        fs -= 2
        f = ImageFont.truetype(F_TITLE, fs)
    text_outlined(d, (w // 2, py + ph // 2 + fs * 0.02), "落子無悔", f, (255, 214, 120), INK, max(2, fs // 14))
    if subtitle:
        fl = ImageFont.truetype(F_LATIN, max(10, int(h * 0.15)))
        text_outlined(d, (w // 2, py + ph + int(h * 0.15)), "NO TAKE-BACKS", fl, CREAM, INK, max(2, int(h * 0.15) // 9))
    return im

def capsule(w, h, logo_frac=0.78, blur=0.0, dark=0.08, src=None, ax=0.5, subtitle=True):
    bg = cover(src or field_crop(), w, h, blur=blur, dark=dark)
    bg = vignette(bg).convert("RGBA")
    ratio = 0.42 if subtitle else 0.36
    lw = int(min(w * logo_frac, h * 0.94 / ratio))   # 木牌不能比圖高
    lh = int(lw * ratio)
    lg = logo(lw, lh, subtitle=subtitle)
    bg.alpha_composite(lg, (int((w - lw) * ax), (h - lh) // 2))   # ax：木牌水平位置（0 左、0.5 中）
    return bg.convert("RGB")

def vertical(w, h):
    melee = shot("01_title").crop((760, 190, 1080, 560))   # 兩軍交界那一塊（直式只放得下中間）
    bg = cover(melee, w, h, blur=0.0, dark=0.1)
    bg = vignette(bg).convert("RGBA")
    lw = int(w * 0.9)
    lh = int(lw * 0.42)
    bg.alpha_composite(logo(lw, lh), ((w - lw) // 2, int(h * 0.08)))
    return bg.convert("RGB")

out = {
    "header_capsule_920x430.png": capsule(920, 430, logo_frac=0.56, ax=0.06),   # 木牌靠左，右邊露出兩軍交界
    "small_capsule_462x174.png": capsule(462, 174, logo_frac=0.98, dark=0.25, subtitle=False),   # 標誌幾乎填滿（Steamworks 規範），縮到 120×45 仍可讀
    "main_capsule_1232x706.png": capsule(1232, 706, logo_frac=0.5, ax=0.06),
    "vertical_capsule_748x896.png": vertical(748, 896),
    "library_capsule_600x900.png": vertical(600, 900),
    "library_hero_3840x1240.png": vignette(cover(field_crop(), 3840, 1240, blur=3.0, dark=0.05), 0.4),
    "page_background_1438x810.png": vignette(cover(field_crop(), 1438, 810, blur=6.0, dark=0.45), 0.7),
}
for n, im in out.items():
    im.save(os.path.join(OUT, n))
lg = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
lg.alpha_composite(logo(1280, 540), (0, 90))
lg.save(os.path.join(OUT, "library_logo_1280x720.png"))
# 商店截圖（1280x800 實機畫面）
sd = os.path.join(OUT, "screenshots")
os.makedirs(sd, exist_ok=True)
for n in ["01_title", "02_place", "03_battle", "05_result", "10_codex", "22_lobby", "52_map_ice_battle", "35_fantasy_battle"]:
    p = os.path.join(SHOTS, n + ".png")
    if os.path.exists(p):
        shutil.copy(p, os.path.join(sd, n + ".png"))
# 可讀性檢查用：小膠囊縮成 Steam 最小顯示尺寸
Image.open(os.path.join(OUT, "small_capsule_462x174.png")).resize((120, 45), Image.LANCZOS).save(os.path.join(ROOT, "build", "tmp", "small_120x45_preview.png"))
print("寫入", OUT, len(os.listdir(OUT)), "項")
