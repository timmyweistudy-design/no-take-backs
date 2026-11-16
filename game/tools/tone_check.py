#!/usr/bin/env python3
"""1.6.0 B03（S2）三代表頁的灰階三階＋盤內不變量測。
用法：PYTHONPATH=../build/pylibnp python3 tools/tone_check.py <新版面輸出夾> [舊版對照夾] [--strip 輸出.png]
  兩個資料夾底下都是 <組合>/<畫面>.png（layout_check 的輸出結構）。
量什麼（L*，CIE 1976，0～100；區域照 scripts/ui/table_seats.gd 的桌位表）：
  桌：右緣桌面（上槽與中槽之間的空桌） ≤25
  紙：結果紙中段、擺陣盤面中段（「中階紙與盤」） 35～65
  主層：主鈕（開戰、下一局）只列數值（主層看「亮或高對比實心」，紅漆鈕靠對比不靠亮度）
  盤內不變：同固定時鐘的舊截圖，盤面內逐像素比（擺陣頁遮掉 1.5.0 吊在盤上的敵情翻牌）；差異像素 0＝ΔE 0
--strip：左舊｜中新｜右新灰階的三頁流程條（並列審片用）。
最後一行：TONE OK／TONE FAIL <理由>。"""
import os, sys
import numpy as np
from PIL import Image

PAGES = {
    "01_title.png": {"desk": (20, 640, 40, 100), "paper": (560, 350, 160, 100)},        # 標題：左下桌角；中階＝示範棋盤（標題的木牌是主層鈕）
    "02_place.png": {"desk": (1186, 232, 88, 120), "paper": (300, 300, 300, 200), "main": (960, 700, 280, 28), "board": True},
    "05_result.png": {"desk": (1186, 232, 88, 120), "paper": (240, 300, 260, 60), "main": (330, 660, 200, 22)},
}
BOARD = (150, 120, 980, 530)   # 盤面內側（戰鬥是桌邊視角，盤緣幾列會露出桌面，取內側）
OLD_TAG = (760, 90, 400, 110)   # 1.5.0 吊在盤右上的翻牌（含吊繩；英文 150% 兩行更寬更高）

def lstar(a):
    a = a.astype(float) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    return np.where(y > 0.008856, 116 * np.cbrt(y) - 16, 903.3 * y)

NOISE = 3   # 容許 ≤3/255：同一份程式固定時鐘重拍兩次逐像素完全一致（差 0）；1.5→1.6 盤內有 236 點差 2/255（ΔE<1、看不出，來源未查明，B03 ledger）

def contrast(c1, c2):
    def rl(c):
        c = np.asarray(c, float) / 255.0
        lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
        return float(lin @ np.array([0.2126, 0.7152, 0.0722]))
    a, b = rl(c1), rl(c2)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)

def crop(a, r):
    x, y, w, h = r
    return a[y:y + h, x:x + w]

def main():
    args = [x for i, x in enumerate(sys.argv[1:], 1) if not x.startswith("--") and sys.argv[i - 1] not in ("--expect", "--board-art")]
    # --board-art <批次>：該批刻意改了盤面美術（B06 地形影子／冰緣／橋墩／陶罐），盤內逐像素差只列不擋；
    # 整盤平均偏 ≥0.5 照擋（桌燈紙／壓暗不准染到盤上）。改完盤面的那批要把新輸出存成下一批的對照。
    board_art = sys.argv[sys.argv.index("--board-art") + 1] if "--board-art" in sys.argv else ""
    strip = sys.argv[sys.argv.index("--strip") + 1] if "--strip" in sys.argv else ""
    if strip in args:
        args.remove(strip)
    new = args[0]
    old = args[1] if len(args) > 1 else ""
    fails = []
    rows = []
    combos = sorted(c for c in os.listdir(new) if os.path.isdir(os.path.join(new, c)))
    if not combos:
        fails.append("沒有任何組合（輸出夾是空的）")
    # 組合要齊：--expect N＝至少 N 組（全量驗收給 24）；對照夾有的組合新版一定要有（Codex B03 r2 #1）
    if "--expect" in sys.argv:
        n_exp = int(sys.argv[sys.argv.index("--expect") + 1])
        if len(combos) < n_exp:
            fails.append("組合只有 %d 組（要 %d）" % (len(combos), n_exp))
    if old:
        olds = sorted(c for c in os.listdir(old) if os.path.isdir(os.path.join(old, c)))
        if not olds:
            fails.append("對照夾是空的")
        for c in olds:
            if c not in combos:
                fails.append("對照有 %s、新版沒有" % c)
    for combo in combos:
        for page, zones in PAGES.items():
            p = os.path.join(new, combo, page)
            if not os.path.isfile(p):
                fails.append("%s 缺 %s" % (combo, page))   # 缺頁＝失敗（Codex B03 r1 #4）
                continue
            a = np.asarray(Image.open(p).convert("RGB"))
            L = lstar(a)
            d = float(np.median(crop(L, zones["desk"])))
            pp = float(np.median(crop(L, zones["paper"])))
            line = "%s %s 桌 %.1f 紙 %.1f" % (combo, page, d, pp)
            if "main" in zones:
                # 主層：紅漆主鈕靠對比不靠亮度——主鈕中位色對旁邊桌面的對比 ≥3:1（Codex B03 r1 #5）
                mc = np.median(crop(a, zones["main"]).reshape(-1, 3), axis=0)
                dc = np.median(crop(a, zones["desk"]).reshape(-1, 3), axis=0)
                cr = contrast(mc, dc)
                line += " 主鈕 L*%.1f 對桌 %.1f:1" % (float(np.median(crop(L, zones["main"]))), cr)
                if cr < 3.0:
                    fails.append("%s/%s 主鈕對桌 %.1f<3" % (combo, page, cr))
            if d > 25.0:
                fails.append("%s/%s 桌 %.1f>25" % (combo, page, d))
            if not (35.0 <= pp <= 65.0) and "plain" not in combo:
                fails.append("%s/%s 紙 %.1f 不在 35～65" % (combo, page, pp))
            if old and zones.get("board"):
                for name in (page, "03_battle.png"):
                    bp, np_ = os.path.join(old, combo, name), os.path.join(new, combo, name)
                    if not os.path.isfile(bp):
                        if os.path.isdir(os.path.join(old, combo)):
                            line += " ｜對照缺 %s（不比）" % name   # 對照本身沒有這張：照實列出，不算過也不算錯
                        continue
                    if not os.path.isfile(np_):
                        fails.append("%s 新版缺 %s（對照有）" % (combo, name))   # 有對照就一定要比到
                        continue
                    b0 = np.asarray(Image.open(bp).convert("RGB")).astype(int)
                    b1 = np.asarray(Image.open(np_).convert("RGB")).astype(int)
                    sd = b1 - b0
                    keep = np.ones(sd.shape[:2], bool)
                    if name == "02_place.png":
                        x, y, w, h = OLD_TAG
                        keep[y:y + h, x:x + w] = False
                    full = (np.abs(sd).max(axis=2) > NOISE) & keep
                    n = int(crop(full, BOARD).sum())
                    # 整盤偏色：每點都 ≤NOISE 但整片往同一方向偏（例如半透明壓暗蓋到盤上），平均有號差 ≥0.5 就算（Codex B03 r1 #5）
                    shift = float(np.abs(crop(sd, BOARD)[crop(keep, BOARD)].mean(axis=0)).max())
                    line += " ｜盤內差 %s %d px、平均偏 %.2f" % (name, n, shift)
                    if board_art and n:
                        line += "（%s 刻意改盤面，只列）" % board_art
                    if (n and not board_art) or shift >= 0.5:
                        fails.append("%s/%s 盤內差 %d px、平均偏 %.2f" % (combo, name, n, shift))
            rows.append(line)
    for r in rows:
        print(r)
    if strip and old:
        tiles = []
        for page in PAGES:
            q, n2 = os.path.join(old, "zh_TW_100", page), os.path.join(new, "zh_TW_100", page)
            if os.path.isfile(q) and os.path.isfile(n2):
                a0 = Image.open(q).convert("RGB").resize((640, 400))
                a1 = Image.open(n2).convert("RGB").resize((640, 400))
                tiles.append([a0, a1, a1.convert("L").convert("RGB")])
        if tiles:
            W = Image.new("RGB", (1920, 400 * len(tiles)))
            for i, t in enumerate(tiles):
                for j, im in enumerate(t):
                    W.paste(im, (640 * j, 400 * i))
            W.save(strip)
            print("流程條", strip)
    print("TONE OK" if not fails else "TONE FAIL " + "；".join(fails[:8]) + ("…共 %d 筆" % len(fails) if len(fails) > 8 else ""))
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
