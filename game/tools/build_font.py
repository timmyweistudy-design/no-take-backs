#!/usr/bin/env python3
"""字型子集化（優化方案 I）：只留遊戲用得到的字，Noto Sans TC 從 5.7 MB 縮到幾百 KB。
改了任何中文文案（strings.csv、puzzles.json、credits.txt、程式裡的字）都要重跑。
用法：python3 tools/build_font.py <Noto 原檔資料夾>
"""
import sys, os, glob, re
from fontTools import subset

src = sys.argv[1]
root = os.path.join(os.path.dirname(__file__), "..")
chars = set()
for pat in ["data/*.csv", "data/*.json", "data/*.txt", "scripts/**/*.gd"]:
    for f in glob.glob(os.path.join(root, pat), recursive=True):
        chars.update(open(f, encoding="utf-8").read())
chars.update(chr(c) for c in range(0x20, 0x7F))
chars.update("★☆✓✗✦●◆■□｜・…×％（）：，。！？「」、")
text = "".join(sorted(c for c in chars if c.isprintable()))
os.makedirs(os.path.join(root, "fonts"), exist_ok=True)
for w in ["Regular", "Bold"]:
    out = os.path.join(root, "fonts", f"NotoSansTC-{w}-sub.otf")
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    sub = subset.Subsetter(opts)
    font = subset.load_font(os.path.join(src, f"NotoSansTC-{w}.otf"), opts)
    sub.populate(text=text)
    sub.subset(font)
    subset.save_font(font, out, opts)
    print(w, len(text), "字", os.path.getsize(out) // 1024, "KB")

# 第五輪：標題字 UoqMunThenKhung（SIL OFL 1.1，取自 timmy-project）。只用在 ≥22px 的粗體標題；
# 同一份字集子集化，原字型沒有的字由思源黑體 Bold 補（ui_base 設定 fallbacks），並印出缺字數。
from fontTools.ttLib import TTFont
tk_src = os.path.join(src, "ThenKhung-Regular.ttf")
if os.path.exists(tk_src):
    out = os.path.join(root, "fonts", "ThenKhung-sub.ttf")
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    sub = subset.Subsetter(opts)
    font = subset.load_font(tk_src, opts)
    cmap = font.getBestCmap()
    missing = [c for c in text if ord(c) not in cmap and not c.isspace()]
    sub.populate(text=text)
    sub.subset(font)
    subset.save_font(font, out, opts)
    got = TTFont(out).getBestCmap()
    lost = [c for c in text if ord(c) in cmap and ord(c) not in got]
    if lost:
        sys.exit("標題字子集漏字：" + "".join(lost[:40]))
    open(os.path.join(root, "fonts", "ThenKhung-missing.txt"), "w", encoding="utf-8").write("".join(missing))
    print("ThenKhung", len(text) - len(missing), "字（原字型沒有 %d 字，由思源黑體補）" % len(missing), os.path.getsize(out) // 1024, "KB")
else:
    print("（沒有 ThenKhung-Regular.ttf，略過標題字）")
