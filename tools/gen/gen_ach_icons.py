#!/usr/bin/env python3
"""V1.0.0 V2：Steam 成就圖示 37 張（256×256 PNG，零預算、程式繪製）。
木印徽章底（木紋圓章＋類別色銅框）＋向量符號；文字只用數字（四語共用）。未解鎖的灰階版由 Steamworks 後台自動產生。
用法：python3 tools/gen/gen_ach_icons.py [輸出資料夾]（預設 docs/release/achievements/）
另外輸出 sheet_256.png（原尺寸總表）與 sheet_64.png（64px 縮圖，驗小尺寸辨識）。
ID 清單要和 game/scripts/game/steam.gd 的 ACHIEVEMENTS 一致（腳本會檢查）。"""
import math, os, re, sys, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "release", "achievements")
F_NUM = os.path.join(ROOT, "game", "fonts", "NTBLatin-B-sub.ttf")
S = 256
SS = 4   # 超取樣
INK = (40, 24, 12)
CREAM = (255, 240, 205)

# 類別：征戰（勝負）、兵法（戰術事件）、收藏（殘局、試煉、圖鑑）、遊戲間（派對、每週、新玩法）
CAT = {"war": (178, 58, 40), "tac": (44, 104, 168), "col": (52, 128, 72), "room": (120, 72, 160)}

# ID → (類別, 符號, 數字文字)
ICONS = {
    "FIRST_WIN": ("war", "flag", ""), "LONE_HERO": ("tac", "one", ""), "COMEBACK": ("war", "up", ""),
    "CLOSE_CALL": ("war", "hourglass", ""), "NO_TAKEBACKS": ("tac", "stone", ""), "HARD_WIN": ("war", "crown", ""),
    "SWEEP": ("war", "num", "2:0"), "TUTORIAL": ("col", "book", ""), "PUZZLE_ALL": ("col", "puzzle", ""),
    "PUZZLE_3STAR": ("col", "stars3", ""), "GAUNTLET": ("war", "num", "7"), "FRENZY_WIN": ("war", "flame", ""),
    "ALL_TYPES": ("tac", "five", ""), "CHARGE_5": ("tac", "chevrons", ""), "BACKSTAB_3": ("tac", "dagger", ""),
    "CUSTOM_LOWGOLD": ("tac", "coin", ""), "CUSTOM_UNDERDOG": ("tac", "smallbig", ""), "CUSTOM_BIG": ("tac", "crowd", ""),
    "FANTASY_WIN": ("war", "slime", ""), "BOOM_5": ("tac", "boom", ""), "RAISE_3": ("tac", "skull", ""),
    "PUZZLE_100": ("col", "num", "100"), "PUZZLE_ALL3": ("col", "star", ""), "TRIAL_ALL3": ("col", "trophy", ""),
    "GHOST_ALL": ("room", "ghost", ""), "WEEKLY_WIN": ("room", "box", ""), "WAVE_3": ("room", "waves", ""),
    "REVENGE": ("war", "broken", ""), "PAINTER": ("col", "brush", ""), "SHARP_EYE": ("room", "eye", ""),
    "SEALED_DONE": ("room", "seal", ""), "RUSH_10": ("room", "clock", ""), "TRIO_STAR3": ("room", "tri", ""),
    "RIFT_WIN": ("room", "rift", ""), "WORKBENCH": ("col", "pen", ""), "MASTER_5": ("col", "medal", ""),
    "COOP_CLEAR": ("room", "relay", ""),
}

def ids_in_game():
    t = open(os.path.join(ROOT, "game", "scripts", "game", "steam.gd"), encoding="utf-8").read()
    blk = t[t.index("const ACHIEVEMENTS"):t.index("}", t.index("const ACHIEVEMENTS"))]
    return re.findall(r'"([A-Z0-9_]+)":\s*\[', blk)

def P(x, y):
    return (x * SS, y * SS)

def poly(d, pts, fill):
    d.polygon([P(x, y) for x, y in pts], fill=fill)

def circ(d, cx, cy, r, fill=None, outline=None, w=0):
    d.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fill, outline=outline, width=w * SS)

def line(d, pts, w, fill):
    d.line([P(x, y) for x, y in pts], fill=fill, width=int(w * SS), joint="curve")

def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def base(cat):
    img = Image.new("RGBA", (S * SS, S * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = CAT[cat]
    cx = cy = 128
    circ(d, cx, cy + 4, 120, fill=(0, 0, 0, 90))                     # 影子
    circ(d, cx, cy, 120, fill=tuple(int(c * 0.55) for c in col))      # 銅框暗面
    circ(d, cx, cy, 114, fill=col)                                    # 類別色框
    circ(d, cx, cy, 100, fill=(150, 98, 52))                          # 木面
    rnd = random.Random(cat)
    for i in range(14):                                               # 年輪（手作木紋）
        r = 8 + i * 6.6 + rnd.uniform(-1.5, 1.5)
        circ(d, cx + rnd.uniform(-3, 3), cy + rnd.uniform(-3, 3), r, outline=(128, 80, 40), w=2)
    circ(d, cx, cy, 100, outline=(96, 58, 26), w=4)
    for a in range(0, 360, 45):                                       # 銅釘
        x = cx + 107 * math.cos(math.radians(a + 22.5))
        y = cy + 107 * math.sin(math.radians(a + 22.5))
        circ(d, x, y, 4.2, fill=(245, 214, 140))
    return img, d

def sym(d, kind, txt):
    c, k = CREAM, INK
    cx = cy = 128
    if kind == "flag":
        line(d, [(98, 182), (98, 70)], 9, c); poly(d, [(102, 72), (170, 90), (102, 116)], c)
    elif kind == "one":
        circ(d, cx, 92, 20, fill=c); poly(d, [(100, 186), (156, 186), (148, 120), (108, 120)], c)
    elif kind == "up":
        poly(d, [(cx, 66), (178, 122), (148, 122), (148, 184), (108, 184), (108, 122), (78, 122)], c)
    elif kind == "hourglass":
        poly(d, [(86, 70), (170, 70), (cx, 128)], c); poly(d, [(86, 186), (170, 186), (cx, 128)], c)
        line(d, [(80, 68), (176, 68)], 8, c); line(d, [(80, 188), (176, 188)], 8, c)
    elif kind == "stone":
        circ(d, cx - 4, cy + 6, 46, fill=(20, 16, 14)); circ(d, cx - 18, cy - 10, 12, fill=(110, 100, 92))
        circ(d, cx + 30, cy - 30, 22, fill=c)
    elif kind == "crown":
        poly(d, [(76, 176), (180, 176), (184, 98), (152, 132), (cx, 84), (104, 132), (72, 98)], c)
        for x in (72, 128, 184):
            circ(d, x, 92 if x != 128 else 80, 9, fill=c)
    elif kind == "num":
        size = {1: 120, 2: 96, 3: 82}.get(len(txt), 72)
        f = ImageFont.truetype(F_NUM, size * SS)
        bb = d.textbbox((0, 0), txt, font=f)
        x = cx * SS - (bb[2] + bb[0]) / 2
        y = cy * SS - (bb[3] + bb[1]) / 2
        d.text((x, y + 6 * SS), txt, font=f, fill=(0, 0, 0, 120))
        d.text((x, y), txt, font=f, fill=c, stroke_width=4 * SS, stroke_fill=k)
    elif kind == "book":
        poly(d, [(cx, 96), (70, 80), (70, 172), (cx, 186)], c); poly(d, [(cx, 96), (186, 80), (186, 172), (cx, 186)], (235, 220, 185))
        line(d, [(cx, 96), (cx, 186)], 5, k)
    elif kind == "puzzle":
        poly(d, [(80, 96), (176, 96), (176, 180), (80, 180)], c); circ(d, cx, 92, 18, fill=c); circ(d, 180, 138, 18, fill=c)
        circ(d, 80, 138, 16, fill=(150, 98, 52))
    elif kind == "stars3":
        for (x, y, r) in ((86, 140, 30), (cx, 104, 38), (170, 140, 30)):
            poly(d, star_pts(x, y, r, r * 0.45), c)
    elif kind == "star":
        poly(d, star_pts(cx, 132, 70, 30), c)
    elif kind == "flame":
        poly(d, [(cx, 62), (172, 130), (160, 176), (cx, 192), (96, 176), (84, 130), (108, 110), (114, 140)], (255, 168, 72))
        poly(d, [(cx, 116), (150, 156), (cx, 184), (106, 156)], c)
    elif kind == "five":
        for i in range(5):
            a = math.radians(-90 + i * 72)
            circ(d, cx + 48 * math.cos(a), cy + 4 + 48 * math.sin(a), 17, fill=c)
    elif kind == "chevrons":
        for i in range(3):
            x = 78 + i * 34
            poly(d, [(x, 76), (x + 30, 76), (x + 70, 128), (x + 30, 180), (x, 180), (x + 40, 128)], c)
    elif kind == "dagger":
        poly(d, [(cx, 58), (146, 140), (110, 140)], c); poly(d, [(92, 140), (164, 140), (164, 152), (92, 152)], c)
        poly(d, [(120, 152), (136, 152), (136, 192), (120, 192)], c)
    elif kind == "coin":
        circ(d, cx, cy, 52, fill=(245, 196, 72)); circ(d, cx, cy, 52, outline=k, w=5)
        line(d, [(cx, 100), (cx, 156)], 10, k)
    elif kind == "smallbig":
        circ(d, 92, 150, 22, fill=c); circ(d, 160, 118, 44, fill=(225, 205, 170)); circ(d, 160, 118, 44, outline=k, w=4)
    elif kind == "crowd":
        for r_ in range(3):
            for i in range(4):
                circ(d, 80 + i * 32 + (r_ % 2) * 14, 92 + r_ * 34, 13, fill=c)
    elif kind == "slime":
        poly(d, [(72, 176), (184, 176), (176, 140), (150, 100), (cx, 86), (106, 100), (80, 140)], (110, 210, 120))
        circ(d, 108, 136, 9, fill=k); circ(d, 148, 136, 9, fill=k)
    elif kind == "boom":
        poly(d, star_pts(cx, cy, 78, 40, 9), (255, 176, 64)); circ(d, cx, cy, 34, fill=c)
    elif kind == "skull":
        circ(d, cx, 116, 48, fill=c); poly(d, [(100, 150), (156, 150), (148, 182), (108, 182)], c)
        circ(d, 110, 116, 13, fill=k); circ(d, 146, 116, 13, fill=k)
    elif kind == "trophy":
        poly(d, [(84, 74), (172, 74), (162, 128), (cx, 148), (94, 128)], (245, 200, 80))
        poly(d, [(118, 148), (138, 148), (138, 172), (118, 172)], (245, 200, 80)); poly(d, [(96, 172), (160, 172), (160, 188), (96, 188)], c)
    elif kind == "ghost":
        poly(d, [(80, 190), (80, 112), (cx, 64), (176, 112), (176, 190), (152, 172), (cx, 190), (104, 172)], c)
        circ(d, 110, 122, 10, fill=k); circ(d, 146, 122, 10, fill=k)
    elif kind == "box":
        poly(d, [(76, 104), (180, 104), (180, 182), (76, 182)], c); poly(d, [(70, 84), (186, 84), (186, 104), (70, 104)], (235, 220, 185))
        line(d, [(cx, 84), (cx, 182)], 6, k)
    elif kind == "waves":
        for i in range(3):
            y = 92 + i * 34
            line(d, [(72 + x, y + 10 * math.sin(x / 14)) for x in range(0, 113, 4)], 9, c)
    elif kind == "broken":
        poly(d, [(84, 176), (120, 140), (126, 146), (90, 182)], c); poly(d, [(132, 128), (176, 80), (182, 86), (138, 134)], c)
        line(d, [(118, 132), (132, 140)], 4, (255, 168, 72))
    elif kind == "brush":
        poly(d, [(156, 64), (176, 84), (116, 150), (104, 138)], (200, 150, 90)); poly(d, [(104, 138), (116, 150), (86, 190), (70, 176)], (200, 60, 50))
    elif kind == "eye":
        poly(d, [(64, 128), (cx, 82), (192, 128), (cx, 174)], c); circ(d, cx, cy, 26, fill=(44, 104, 168)); circ(d, cx, cy, 12, fill=k)
    elif kind == "seal":
        circ(d, cx, cy, 56, fill=(176, 36, 36)); circ(d, cx, cy, 40, outline=(230, 120, 110), w=4)
        poly(d, star_pts(cx, cy, 24, 11), (230, 120, 110))
    elif kind == "clock":
        circ(d, cx, cy, 56, fill=c); circ(d, cx, cy, 56, outline=k, w=5)
        line(d, [(cx, cy), (cx, 92)], 8, k); line(d, [(cx, cy), (156, 140)], 8, k)
    elif kind == "tri":
        for (x, y) in ((cx, 90), (92, 156), (164, 156)):
            poly(d, [(x - 24, y + 18), (x + 24, y + 18), (x, y - 22)], c)
    elif kind == "rift":
        poly(d, [(140, 60), (104, 124), (136, 124), (110, 196), (166, 110), (134, 110), (160, 60)], (200, 170, 255))
    elif kind == "pen":
        poly(d, [(168, 68), (188, 88), (110, 166), (90, 146)], c); poly(d, [(90, 146), (110, 166), (76, 182)], (245, 196, 72))
    elif kind == "medal":
        poly(d, [(100, 64), (124, 64), (140, 116), (116, 116)], (200, 60, 50)); poly(d, [(156, 64), (132, 64), (116, 116), (140, 116)], (44, 104, 168))
        circ(d, cx, 148, 38, fill=(245, 200, 80)); poly(d, star_pts(cx, 150, 22, 10), (180, 120, 30))
    elif kind == "relay":
        poly(d, [(70, 110), (150, 110), (150, 92), (186, 124), (150, 156), (150, 138), (70, 138)], c)
        poly(d, [(186, 160), (106, 160), (106, 178), (70, 146 + 32), (106, 214), (106, 196), (186, 196)], (225, 205, 170))
    else:
        raise SystemExit("沒有這個符號：" + kind)

def main():
    ids = ids_in_game()
    missing = [i for i in ids if i not in ICONS]
    extra = [i for i in ICONS if i not in ids]
    if missing or extra:
        raise SystemExit("成就 ID 和 steam.gd 不一致：少 %s 多 %s" % (missing, extra))
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for aid in ids:
        cat, kind, txt = ICONS[aid]
        img, d = base(cat)
        sym(d, kind, txt)
        img = img.resize((S, S), Image.LANCZOS)
        img.save(os.path.join(OUT, aid + ".png"))
        tiles.append(img)
    cols = 8
    rows = math.ceil(len(tiles) / cols)
    for sz, name in ((256, "sheet_256.png"), (64, "sheet_64.png")):
        sheet = Image.new("RGB", (cols * (sz + 8) + 8, rows * (sz + 8) + 8), (34, 30, 28))
        for i, t in enumerate(tiles):
            sheet.paste(t.resize((sz, sz), Image.LANCZOS), (8 + (i % cols) * (sz + 8), 8 + (i // cols) * (sz + 8)), t.resize((sz, sz), Image.LANCZOS))
        sheet.save(os.path.join(OUT, name))
    print("ACH ICONS %d → %s" % (len(tiles), OUT))

main()
