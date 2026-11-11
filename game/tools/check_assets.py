#!/usr/bin/env python3
"""素材登記檢查（優化方案 R）：game/ 底下每個圖片／聲音／字型檔都要在 THIRD_PARTY_LICENSES.md 有對應的來源。
結束碼 0＝全部登記；1＝有沒登記的檔案。"""
import os, sys, fnmatch
root = os.path.join(os.path.dirname(__file__), "..")
rules = [  # (路徑樣式, 登記項目)
    ("art/cainos/*.png", "Cainos"),
    ("audio/k_*.wav", "Kenney"),
    ("audio/*.ogg", "opengameart.org"),   # V1.2：CC0 錄音（tools/gen/import_audio.py），逐條登記
    ("audio/*.wav", "本作程式合成"),
    ("fonts/NTBRounded-*.otf", "源泉圓體"),
    ("fonts/NTBRoundedJP-*.otf", "GenSenRounded2 JP"),   # V1.4 #17
    ("fonts/NTBRoundedSC-*.otf", "Resource Han Rounded CN"),
    ("fonts/NTBLatin-*.ttf", "Fredoka"),
    ("fonts/ThenKhung-*.ttf", "UoqMunThenKhung"),
    ("fonts/NTBSans-*.otf", "Noto Sans CJK"),   # 1.2.0 §3.2 工藝風字型
    ("fonts/NTBSansSC-*.otf", "Noto Sans CJK"),
    ("fonts/NTBSansJP-*.otf", "Noto Sans CJK"),
    ("fonts/NTBSansLatin-*.ttf", "Source Sans 3"),
    ("fonts/NTBTitle-*.ttf", "LXGW WenKai"),
    ("icon.svg", "本作程式繪製"),
    ("art/ui/*.png", "本作程式繪製"),   # V1.2：tools/gen/gen_ui_tex.py 生成
    ("art/mat/tile_*.png", "ambientCG"),   # 1.2.0 §2：CC0 原稿調色（tools/gen/materials.py）
    ("art/mat/nine_*.png", "ambientCG"),
    ("art/mat/ink_*.png", "本作程式繪製"),
    ("art/mat/wax_*.png", "本作程式繪製"),
]
reg = open(os.path.join(root, "..", "THIRD_PARTY_LICENSES.md"), encoding="utf-8").read()
bad = []
for dp, dn, fn in os.walk(root):
    if ".godot" in dp:
        continue
    for f in fn:
        if not f.lower().endswith((".png", ".wav", ".ogg", ".otf", ".ttf", ".svg", ".jpg")):
            continue
        rel = os.path.relpath(os.path.join(dp, f), root).replace("\\", "/")
        hit = [n for p, n in rules if fnmatch.fnmatch(rel, p)]
        if not hit or not all(n.split("（")[0] in reg or n in ("本作程式合成", "本作程式繪製") for n in hit):
            bad.append(rel)
# 1.2.0 §2.1 素材契約：art/mat/manifest.json 每一筆都要在、尺寸對、9 宮格有邊界、透明留邊 ≥2px、總量在預算內
import json
from PIL import Image
man_p = os.path.join(root, "art/mat/manifest.json")
# 預算範圍：只算 art/mat（1.2.0 元件庫材質）；角色圖集、地圖烘焙另有效能模式量測（Codex cat02 #6）
if os.path.isdir(os.path.join(root, "art/mat")) and not os.path.isfile(man_p):
    bad.append("art/mat 有檔案但沒有 manifest.json（素材契約不能略過）")
if os.path.isfile(man_p):
    man = json.load(open(man_p, encoding="utf-8"))
    total = 0
    on_disk = {f for f in os.listdir(os.path.join(root, "art/mat")) if f.endswith(".png")}
    for f, it in man["items"].items():
        fp = os.path.join(root, "art/mat", f)
        if not os.path.isfile(fp):
            bad.append(f"manifest 有、檔案沒有：{f}"); continue
        im = Image.open(fp)
        if list(im.size) != list(it["size"]):
            bad.append(f"{f} 尺寸 {im.size} ≠ manifest {it['size']}")
        for req in ["use", "kind", "size", "source", "load"]:
            if req not in it:
                bad.append(f"{f} manifest 缺欄位 {req}")
        if it["kind"] == "nine":
            mg = it.get("margin", [])
            if len(mg) != 4 or not all(isinstance(m, int) and m > 0 for m in mg):
                bad.append(f"{f} 9 宮格四邊界要是 4 個正整數")
            elif mg[0] + mg[2] >= im.size[0] or mg[1] + mg[3] >= im.size[1]:
                bad.append(f"{f} 9 宮格邊界加起來超過尺寸")
            a = im.convert("RGBA").getchannel("A")
            w, h = im.size
            edge = [a.getpixel((x, y)) for x in range(w) for y in (0, 1, h - 2, h - 1)] + [a.getpixel((x, y)) for y in range(h) for x in (0, 1, w - 2, w - 1)]
            if max(edge) > 0:
                bad.append(f"{f} 最外 2px 不是全透明（會滲色）")
        if not it.get("source"):
            bad.append(f"{f} 沒寫來源")
        total += im.size[0] * im.size[1] * 4
    extra = on_disk - set(man["items"])
    if extra:
        bad.append(f"art/mat 有沒登記在 manifest 的檔：{sorted(extra)}")
    if total > 64 * 1024 * 1024:
        bad.append(f"介面材質解壓後 {total // 1048576} MiB 超過預算 64 MiB")
print("未登記：", bad if bad else "無")
sys.exit(1 if bad else 0)
