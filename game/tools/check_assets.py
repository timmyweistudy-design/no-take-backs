#!/usr/bin/env python3
"""素材登記檢查（優化方案 R）：game/ 底下每個圖片／聲音／字型檔都要在 THIRD_PARTY_LICENSES.md 有對應的來源。
結束碼 0＝全部登記；1＝有沒登記的檔案。"""
import os, sys, fnmatch
root = os.path.join(os.path.dirname(__file__), "..")
rules = [  # (路徑樣式, 登記項目)
    ("art/cainos/*.png", "Cainos"),
    ("audio/k_*.wav", "Kenney"),
    ("audio/*.ogg", "OpenGameArt"),   # V1.2：CC0 錄音（tools/gen/import_audio.py）
    ("audio/*.wav", "本作程式合成"),
    ("fonts/NTBRounded-*.otf", "源泉圓體"),
    ("fonts/NTBLatin-*.ttf", "Fredoka"),
    ("fonts/ThenKhung-*.ttf", "UoqMunThenKhung"),
    ("icon.svg", "本作程式繪製"),
    ("art/ui/*.png", "本作程式繪製"),   # V1.2：tools/gen/gen_ui_tex.py 生成
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
print("未登記：", bad if bad else "無")
sys.exit(1 if bad else 0)
