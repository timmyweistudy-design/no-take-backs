#!/usr/bin/env python3
"""1.6.0 B06（方案 P1.3；Codex B06 r1 #5）：全站紙頁的實圖灰階量測。
舊版截圖裡的「亮紙」像素（L*>72、低彩度）＝紙面遮罩；量新版同位置的 L* 中位數。
B06 負責的頁（tools/screen_owner.py 歸屬）紙面佔畫面 ≥3% 的，中位數要在 35～72；其他批次的頁只列出。地形頁（雪地盤面不是紙）不算。
門檻 72 而不是方案的 65（偏差，B06 ledger）：貼圖紙有明暗起伏（約 ±7），墨字要 4.5:1 紙最暗處得 ≥L*53，中位數壓到 65 暗斑上的字就不夠；
方案的 35～65 仍由 tone_check 在三代表頁的紙面中段量。
文字對比不在這裡量：版面檢查逐頁逐組在真實截圖取樣（24 組 0 違規＝紙上字全部 ≥4.5:1）。
用法：PYTHONPATH=../build/pylibnp python3 tools/paper_tone.py <舊組合夾> <新組合夾>   最後一行 PAPER OK／PAPER FAIL"""
import os, sys, re, subprocess
import numpy as np
from PIL import Image

HI = 72.0
NEW_PAGES = {"v160_05g_note_pin"}   # 1.6.0 新畫面：舊版沒有對照（明列，不靜靜跳過）；紙面由新版的對比檢查管
TERRAIN = re.compile(r"^(5[0-6]_map_|82_place_terrain|87_battle_terrain|87b_quarry|87c_quarry|87d_boss|v120_07_editor_map)")

def lstar(a):
    a = a.astype(float) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    return np.where(y > 0.008856, 116 * np.cbrt(y) - 16, 903.3 * y)

def owners():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "..", "build", "tmp", "screen_owner.md")
    subprocess.run([sys.executable, os.path.join(here, "screen_owner.py"), out], check=True, stdout=subprocess.DEVNULL)
    own = {}
    for ln in open(out, encoding="utf-8"):
        m = re.match(r"\| `([^`]+)` \| [^|]* \| (\S+) \|", ln)
        if m:
            own[m.group(1)] = m.group(2)
    return own

TALL = 24   # 半尺寸下 24 列＝原圖 48px：按鈕、頁籤、吊牌是控制件不是紙面（最高約 40px），上下連續不到這麼高的亮紙不算

def tall(m, k):
    """只留「所在直欄連續 ≥k 列都是亮紙」的像素（直向侵蝕再補回）：濾掉按鈕這類矮條，紙卡、紙頁留下。"""
    h = m.shape[0]
    c = np.vstack([np.zeros((1, m.shape[1]), int), np.cumsum(m, axis=0)])
    start = np.zeros_like(m)
    win = (c[k:] - c[:-k]) == k          # 第 i 列起往下 k 列全亮
    start[:h - k + 1] = win
    c2 = np.vstack([np.zeros((1, m.shape[1]), int), np.cumsum(start, axis=0)])
    out = np.zeros_like(m)
    for i in range(h):                   # 被任何一個完整窗口蓋到的像素
        lo = max(0, i - k + 1)
        out[i] = (c2[i + 1] - c2[lo]) > 0
    return out

def main():
    old, new = sys.argv[1], sys.argv[2]
    own = owners()
    fails, rows = [], []
    # 預期清單（Codex B06 r2 #1）：B06 負責、不是地形頁的每一頁，新舊兩邊都要有圖、尺寸一樣；缺圖或量到 0 頁＝失敗
    expect = sorted(n for n, o in own.items() if o == "B06" and not TERRAIN.match(n))
    for n in expect:
        for d in (old, new):
            if not os.path.exists(os.path.join(d, n + ".png")) and not (d == old and n in NEW_PAGES):
                fails.append(f"{n} 缺圖（{'舊' if d == old else '新'}）")
    for f in sorted(os.listdir(new)):
        if not f.endswith(".png") or not os.path.exists(os.path.join(old, f)):
            continue
        ia, ib = Image.open(os.path.join(old, f)), Image.open(os.path.join(new, f))
        a = np.asarray(ia.convert("RGB"))[::2, ::2]
        b = np.asarray(ib.convert("RGB"))[::2, ::2]
        if ia.size != ib.size:   # 原圖尺寸先比（Codex B06 r3 #1：降採樣後 1280×800 與 1279×799 形狀一樣）
            if f[:-4] in expect:
                fails.append(f"{f[:-4]} 尺寸不同")
            continue
        La = lstar(a)
        ch = a.max(axis=2).astype(int) - a.min(axis=2).astype(int)
        m = tall((La > 72) & (ch < 60), TALL)
        frac = m.mean()
        if frac < 0.03:
            continue
        med = float(np.median(lstar(b)[m]))
        n = f[:-4]
        o = own.get(n, "?")
        if TERRAIN.match(n):
            continue   # 地形頁：亮的是雪地盤面
        bad = o == "B06" and not (35.0 <= med <= HI)
        rows.append((o, n, frac, float(np.median(La[m])), med, bad))
        if bad:
            fails.append(f"{n} 紙 L* {med:.1f}")
    for o, n, fr, ma, mb, bad in rows:
        print(f"{'✗' if bad else ' '} {o:4s} {n:34s} 紙 {fr*100:4.1f}%  L* {ma:5.1f} → {mb:5.1f}")
    b06 = [r for r in rows if r[0] == "B06"]
    if not b06:
        fails.append("B06 紙頁量到 0 頁")
    print(("PAPER OK" if not fails else "PAPER FAIL " + "、".join(fails)) + f"（B06 紙頁 {len(b06)} 頁，中位數 {np.median([r[4] for r in b06]) if b06 else 0:.1f}；量了 {len(rows)} 頁）")
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
