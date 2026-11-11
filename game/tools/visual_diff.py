"""1.2.0 §14.6：視覺回歸。比較兩次版面截圖輸出（layout_check.sh 的資料夾），逐畫面算像素差比例與 SSIM，
把變最多的前 N 張拼成接觸表（左舊、中新、右差異熱圖）給人看；新畫面（舊的沒有）與消失的畫面另外列。

用法（專案根目錄）：
  PYTHONPATH=build/pylibnp python3 game/tools/visual_diff.py <舊資料夾> <新資料夾> <輸出資料夾> [--top 24] [--combos zh_TW_100,en_150]

防漏（方案 §14.6）：只排序、不遮罩；文字、焦點、警示照樣算進差異；版面幾何與對比檢查另外照跑；
新畫面與變動前 N 名要人簽核（簽核寫在 coordination/<批次>/visual-signoff.md）。
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image, ImageDraw

W = 320  # 比較用的縮圖寬（1280→320）：SSIM 對小位移不敏感，像素差另外用原圖算


def load_gray(path, w=None):
    im = Image.open(path).convert("RGB")
    if w:
        im = im.resize((w, int(im.height * w / im.width)), Image.BILINEAR)
    a = np.asarray(im, dtype=np.float64)
    return a, 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def ssim(x, y, win=8):
    """區塊 SSIM（不重疊 8×8 視窗的平均）；純 numpy。"""
    h, w = min(x.shape[0], y.shape[0]) // win * win, min(x.shape[1], y.shape[1]) // win * win
    x, y = x[:h, :w], y[:h, :w]
    xb = x.reshape(h // win, win, w // win, win).transpose(0, 2, 1, 3).reshape(-1, win * win)
    yb = y.reshape(h // win, win, w // win, win).transpose(0, 2, 1, 3).reshape(-1, win * win)
    mx, my = xb.mean(1), yb.mean(1)
    vx, vy = xb.var(1), yb.var(1)
    cov = ((xb - mx[:, None]) * (yb - my[:, None])).mean(1)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    s = ((2 * mx * my + c1) * (2 * cov + c2)) / ((mx * mx + my * my + c1) * (vx + vy + c2))
    return float(s.mean())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("old"); ap.add_argument("new"); ap.add_argument("out")
    ap.add_argument("--top", type=int, default=24)
    ap.add_argument("--combos", default="")
    ap.add_argument("--thresh", type=int, default=8, help="像素差門檻（0～255，任一通道）")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    combos = [c for c in a.combos.split(",") if c] or sorted(d for d in os.listdir(a.new) if os.path.isdir(os.path.join(a.new, d)))
    rows, added, removed = [], [], []
    for c in combos:
        od, nd = os.path.join(a.old, c), os.path.join(a.new, c)
        on = {f for f in os.listdir(od) if f.endswith(".png")} if os.path.isdir(od) else set()
        nn = {f for f in os.listdir(nd) if f.endswith(".png")} if os.path.isdir(nd) else set()
        added += [f"{c}/{f}" for f in sorted(nn - on)]
        removed += [f"{c}/{f}" for f in sorted(on - nn)]
        for f in sorted(on & nn):
            ra, ga = load_gray(os.path.join(od, f))
            rb, gb = load_gray(os.path.join(nd, f))
            if ra.shape != rb.shape:
                rows.append({"shot": f"{c}/{f}", "diff_pct": 100.0, "ssim": 0.0, "note": "尺寸不同"})
                continue
            diff = np.abs(ra - rb).max(axis=2) > a.thresh
            _, sa = load_gray(os.path.join(od, f), W)
            _, sb = load_gray(os.path.join(nd, f), W)
            rows.append({"shot": f"{c}/{f}", "diff_pct": round(float(diff.mean()) * 100, 3), "ssim": round(ssim(sa, sb), 4)})
    rows.sort(key=lambda r: (r["ssim"], -r["diff_pct"]))
    changed = [r for r in rows if r["diff_pct"] > 0]
    json.dump({"compared": len(rows), "changed": len(changed), "added": added, "removed": removed, "rows": rows},
              open(os.path.join(a.out, "diff.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    top = changed[: a.top]
    if top:
        cw, ch = 320, 200
        sheet = Image.new("RGB", (cw * 3, (ch + 16) * len(top)), (24, 20, 18))
        d = ImageDraw.Draw(sheet)
        for i, r in enumerate(top):
            c, f = r["shot"].split("/", 1)
            o = Image.open(os.path.join(a.old, c, f)).convert("RGB")
            n = Image.open(os.path.join(a.new, c, f)).convert("RGB")
            hm = Image.fromarray((np.clip(np.abs(np.asarray(o, dtype=np.int16) - np.asarray(n, dtype=np.int16)).max(axis=2) * 4, 0, 255)).astype(np.uint8)).convert("RGB")
            y = i * (ch + 16)
            for k, im in enumerate([o, n, hm]):
                sheet.paste(im.resize((cw, ch)), (k * cw, y + 16))
            d.text((4, y + 2), f"{r['shot']}  diff {r['diff_pct']}%  SSIM {r['ssim']}  (old | new | heat)", fill=(255, 220, 120))
        sheet.save(os.path.join(a.out, "diff_sheet.png"))
    print(f"VISDIFF 比較 {len(rows)} 張、有變動 {len(changed)}、新增 {len(added)}、消失 {len(removed)}"
          + (f"｜最低 SSIM {rows[0]['ssim']}（{rows[0]['shot']}）" if rows else ""))


if __name__ == "__main__":
    sys.exit(main())
