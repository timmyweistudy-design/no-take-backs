#!/usr/bin/env python3
"""1.2.0 §2 材質管線：CC0 原稿（ambientCG）→ 調色到色票 → 平鋪 → 9 宮格（不規則毛邊）→ game/art/mat/*.png ＋ manifest.json。
墨（乾刷、暈染、飛白）、蠟封、紙毛邊遮罩用固定種子程序產生（可重現）。
用法（專案根目錄）：PYTHONPATH=build/pylibnp python3 tools/gen/materials.py
原稿放 build/dl/ambientcg/<id>/<id>_1K-JPG_Color.jpg（tools/gen/materials.py --fetch 會下載）；原稿不進專案，只進授權清單。
"""
import io, json, os, sys, zipfile, urllib.request
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "build/dl/ambientcg")
OUT = os.environ.get("NTB_MAT_OUT", os.path.join(ROOT, "game/art/mat"))
RNG = np.random.default_rng(20261111)

# 用途 → (ambientCG 原稿, 目標平均色, 對比倍率, 輸出邊長)
TILES = {
    "paper1": ("Paper001", "#F5EFE6", 0.9, 512),   # 1 級新紙：設定、未讀教學
    "paper2": ("Paper001", "#E8D8C3", 1.0, 512),   # 2 級熟紙：大廳、圖鑑、戰報
    "paper3": ("Paper006", "#C7A77B", 1.1, 512),   # 3 級陳紙：殘局帖、棋譜、老戰報
    "kraft":  ("Paper006", "#D8C49D", 1.0, 512),   # 牛皮紙
    "walnut": ("Wood066",  "#533927", 1.0, 512),   # 桌面胡桃
    "walnut_d": ("Wood051", "#3A281C", 1.0, 512),  # 桌緣深胡桃
    "beech":  ("Wood092",  "#E5BD88", 0.9, 256),   # 木牌山毛櫸
    "oak":    ("Wood094",  "#9C683E", 1.0, 256),   # 老橡（棋盤拼花深色）
    "linen":  ("Fabric036", "#ECE5D8", 1.0, 256),  # 原胚布
    "indigo": ("Fabric036", "#354B5E", 1.2, 256),  # 靛藍布
    "madder": ("Fabric036", "#8C3B30", 1.2, 256),  # 茜紅布
}
LICENSE = "ambientCG（https://ambientcg.com）CC0 1.0：{ids}"


def fetch(ids):
    for i in ids:
        d = os.path.join(SRC, i)
        os.makedirs(d, exist_ok=True)
        if any(f.endswith("_Color.jpg") for f in os.listdir(d)):
            continue
        req = urllib.request.Request(f"https://ambientcg.com/get?file={i}_1K-JPG.zip", headers={"User-Agent": "asset-fetch/1.0"})
        z = zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(req, timeout=120).read()))
        for n in z.namelist():
            if n.endswith("_Color.jpg"):
                open(os.path.join(d, n), "wb").write(z.read(n))


def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)


def recolor(img, target, contrast):
    """保留明暗紋理、把平均色移到目標色：亮度偏差 × 對比倍率加回目標色（每通道），再夾到 0～255。"""
    a = np.asarray(img.convert("RGB"), dtype=np.float64)
    lum = a @ np.array([0.2126, 0.7152, 0.0722])
    dev = (lum - lum.mean()) * contrast
    out = hex_rgb(target)[None, None, :] + dev[..., None] * (0.55 + hex_rgb(target)[None, None, :] / 255.0 * 0.45)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def noise(w, h, scale, octaves=4):
    """固定種子的值噪聲（多層），0～1。"""
    acc = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(2, int(scale / (2 ** o)))
        g = RNG.random((h // s + 2, w // s + 2))
        acc += amp * np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((w + 2 * s, h + 2 * s), Image.BICUBIC), dtype=np.float64)[:h, :w] / 255.0
        tot += amp
        amp *= 0.5
    return acc / tot


def deckle(w, h, edge=10, rough=4.0):
    """不規則毛邊遮罩（紙卡、木牌、布標共用的邊）：邊緣 edge px 內用噪聲決定透明，最外 2px 一定透明（防滲色）。"""
    n = noise(w, h, 6)
    y, x = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y)).astype(np.float64)
    a = np.clip((d - 2 - n * rough) / max(1.0, edge - 2 - rough) , 0, 1)
    return (a * 255).astype(np.uint8)


def nine(tile_img, w, h, edge, shadow=True):
    """把平鋪貼圖裁成 w×h、套毛邊遮罩，回傳 RGBA。"""
    t = tile_img.resize((max(w, tile_img.width), max(h, tile_img.height))).crop((0, 0, w, h)).convert("RGBA")
    m = Image.fromarray(deckle(w, h, edge))
    t.putalpha(m)
    return t


def ink_strokes():
    """墨的三種筆觸遮罩（白＝墨）：乾刷（橫向纖維斷續）、暈染（柔邊團塊）、飛白（中段破白）。各 256×64。"""
    out = {}
    w, h = 256, 64
    y, x = np.mgrid[0:h, 0:w]
    body = np.exp(-((y - h / 2) / (h * 0.28)) ** 2)
    fib = noise(w, h, 3, 2)
    out["ink_dry"] = np.clip(body * (fib > 0.42) * 1.2, 0, 1)
    out["ink_wash"] = np.clip(body * (0.6 + 0.4 * noise(w, h, 16)), 0, 1) ** 1.4
    gap = np.clip(1 - np.exp(-((x - w * 0.55) / (w * 0.12)) ** 2) * (noise(w, h, 4) > 0.5), 0, 1)
    out["ink_fly"] = np.clip(body * gap * (fib > 0.3), 0, 1)
    return {k: Image.fromarray((v * 255).astype(np.uint8), "L") for k, v in out.items()}


def wax(color, size=96):
    """蠟封：不規則圓＋壓印凹環＋高光；color＝紅蠟／金蠟。"""
    n = noise(size, size, 8)
    y, x = np.mgrid[0:size, 0:size]
    c = size / 2
    r = np.hypot(x - c, y - c) / (size * 0.42) + (n - 0.5) * 0.18
    a = np.clip((1 - r) * 8, 0, 1)
    base = hex_rgb(color)
    ring = np.exp(-((r - 0.62) / 0.06) ** 2) * 0.35
    hl = np.clip(1 - np.hypot(x - c * 0.7, y - c * 0.7) / (size * 0.3), 0, 1) * 0.25
    rgb = base[None, None, :] * (1 - ring[..., None]) + 255 * hl[..., None] * 0.6
    img = np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def main():
    if "--fetch" in sys.argv:
        fetch(sorted({v[0] for v in TILES.values()}))
    os.makedirs(OUT, exist_ok=True)
    man = {"version": 1, "license": LICENSE.format(ids=", ".join(sorted({v[0] for v in TILES.values()}))), "items": {}}
    tiles = {}
    for name, (src, color, con, size) in TILES.items():
        f = os.path.join(SRC, src, f"{src}_1K-JPG_Color.jpg")
        if not os.path.isfile(f):
            sys.exit(f"缺原稿 {f}（先跑 --fetch）")
        img = recolor(Image.open(f).resize((size, size), Image.LANCZOS), color, con)
        img.save(os.path.join(OUT, f"tile_{name}.png"), optimize=True)
        tiles[name] = img
        man["items"][f"tile_{name}.png"] = {"use": name, "kind": "tile", "repeat": True, "size": [size, size], "source": src, "load": "boot"}
    # 9 宮格元件底（不規則毛邊、2px 透明留邊）：紙卡三級、木牌、布標三色
    for name, src, w, h, edge in [("card1", "paper1", 256, 192, 12), ("card2", "paper2", 256, 192, 12), ("card3", "paper3", 256, 192, 14),
                                  ("plaque", "beech", 192, 64, 6), ("tab_indigo", "indigo", 128, 48, 5), ("tab_madder", "madder", 128, 48, 5),
                                  ("tab_linen", "linen", 128, 48, 5)]:
        img = nine(tiles[src], w, h, edge)
        img.save(os.path.join(OUT, f"nine_{name}.png"), optimize=True)
        man["items"][f"nine_{name}.png"] = {"use": name, "kind": "nine", "margin": [edge + 8] * 4, "pad": 2, "size": [w, h], "source": TILES[src][0], "load": "boot"}
    for k, img in ink_strokes().items():
        img.save(os.path.join(OUT, f"{k}.png"), optimize=True)
        man["items"][f"{k}.png"] = {"use": k, "kind": "mask", "size": list(img.size), "source": "程序產生（固定種子 20261111）", "load": "boot"}
    for k, col in [("wax_red", "#9B281B"), ("wax_gold", "#B8862B"), ("wax_brown", "#6B3A1F")]:
        img = wax(col)
        img.save(os.path.join(OUT, f"{k}.png"), optimize=True)
        man["items"][f"{k}.png"] = {"use": k, "kind": "sprite", "size": list(img.size), "source": "程序產生（固定種子 20261111）", "load": "boot"}
    json.dump(man, open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in man["items"])
    print(f"MATERIALS {len(man['items'])} 張、檔案 {total // 1024} KiB → {OUT}")


if __name__ == "__main__":
    main()
