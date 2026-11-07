#!/usr/bin/env python3
"""字型子集化（優化方案 I）：只留遊戲用得到的字。V1.2 起介面字型＝源泉圓體 TW（中文）＋Fredoka（英數）；標題 ThenKhung。
改了任何中文文案（strings.csv、puzzles.json、credits.txt、程式裡的字）都要重跑。
用法：python3 tools/gen/build_font.py <原檔資料夾>（要有 GenSenRounded2TW-R/B.otf、Fredoka.ttf、ThenKhung-Regular.ttf）
"""
import sys, os, glob, re
from fontTools import subset

src = sys.argv[1]
root = os.path.join(os.path.dirname(__file__), "..", "..")
chars = set()
for pat in ["data/*.csv", "data/*.json", "data/*.txt", "scripts/**/*.gd"]:
    for f in glob.glob(os.path.join(root, pat), recursive=True):
        txt = open(f, encoding="utf-8").read()
        # V9：程式碼只算字串常值，註解的字不必進字型
        chars.update("".join(re.findall(r'"(?:[^"\\\n]|\\.)*"', txt)) if f.endswith(".gd") else txt)
chars.update(chr(c) for c in range(0x20, 0x7F))
chars.update("★☆✓✗✦●◆■□｜・…×％（）：，。！？「」、")
text = "".join(sorted(c for c in chars if c.isprintable()))
os.makedirs(os.path.join(root, "fonts"), exist_ok=True)
# V1.2 A1：介面字型換成「Fredoka（英數，主字型）＋源泉圓體 TW（中文，後備）」。都是 SIL OFL 1.1。
# 子集化屬於修改，內部名稱改成 NTB Rounded／NTB Latin（源泉的保留名稱是 'Source'，Fredoka 沒有保留名稱，仍一併改名）。
# Fredoka 沒有等寬數字（tnum），這裡把 0～9 的字寬統一成最寬的那個並把字形置中：金幣、秒數跳動時不會左右晃。
from fontTools.ttLib import TTFont as _TT

def _rename(font, family, style):
    for rec in font["name"].names:
        if rec.nameID in (1, 16):
            rec.string = family
        elif rec.nameID == 4:
            rec.string = f"{family} {style}"
        elif rec.nameID == 6:
            rec.string = f"{family.replace(' ', '')}-{style}"
        elif rec.nameID in (2, 17):
            rec.string = style

for w, src_name in [("R", "GenSenRounded2TW-R.otf"), ("B", "GenSenRounded2TW-B.otf")]:
    gs = os.path.join(src, src_name)
    if not os.path.exists(gs):
        print("（沒有", src_name, "，略過）")
        continue
    out = os.path.join(root, "fonts", f"NTBRounded-{w}-sub.otf")
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    sub = subset.Subsetter(opts)
    font = subset.load_font(gs, opts)
    sub.populate(text=text)
    sub.subset(font)
    _rename(font, "NTB Rounded", "Bold" if w == "B" else "Regular")
    subset.save_font(font, out, opts)
    print("NTBRounded", w, os.path.getsize(out) // 1024, "KB")

fr = os.path.join(src, "Fredoka.ttf")
if os.path.exists(fr):
    from fontTools.varLib import instancer
    latin = "".join(chr(c) for c in range(0x20, 0x7F)) + "×÷±%‰°•·…–—‘’“”"
    for w, wght in [("M", 500), ("B", 650)]:
        vf = _TT(fr)
        st = instancer.instantiateVariableFont(vf, {"wght": wght, "wdth": 100})
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        sub = subset.Subsetter(opts)
        sub.populate(text=latin)
        sub.subset(st)
        cmap = st.getBestCmap()
        hm = st["hmtx"]
        glyf = st["glyf"]
        digits = [cmap[ord(c)] for c in "0123456789"]
        tw = max(hm[g][0] for g in digits)
        for g in digits:
            adv, lsb = hm[g]
            dx = (tw - adv) // 2
            gl = glyf[g]
            if gl.isComposite():
                for comp in gl.components:
                    comp.x += dx
            elif gl.numberOfContours > 0:
                gl.coordinates.translate((dx, 0))
            gl.recalcBounds(glyf)
            hm[g] = (tw, gl.xMin if hasattr(gl, "xMin") else lsb + dx)
        _rename(st, "NTB Latin", "Bold" if w == "B" else "Medium")
        out = os.path.join(root, "fonts", f"NTBLatin-{w}-sub.ttf")
        st.save(out)
        print("NTBLatin", w, "數字等寬", tw, os.path.getsize(out) // 1024, "KB")

# 第五輪：標題字 UoqMunThenKhung（SIL OFL 1.1，取自 timmy-project）。只用在 ≥22px 的粗體標題；
# 同一份字集子集化，原字型沒有的字由介面字型 Bold 補（ui_base 設定 fallbacks），並印出缺字數。
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
    print("ThenKhung", len(text) - len(missing), "字（原字型沒有 %d 字，由介面字型補）" % len(missing), os.path.getsize(out) // 1024, "KB")
else:
    print("（沒有 ThenKhung-Regular.ttf，略過標題字）")
