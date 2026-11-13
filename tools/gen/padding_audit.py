#!/usr/bin/env python3
"""1.4.0 方案盤點（使用者第 10 點「文字在格子裡上下左右要有空、不要太緊；圖示要在框框裡、上下留空」）：
讀 dev_main --geom-dump 寫的 geom.jsonl（字形框 g、所屬按鈕框 own、九宮格方塊 boxes、圖示框 icons、按鈕框 btns），量內距。
- 格子字：按鈕標籤（own）＋落在小方塊（寬 ≤ 420、高 ≤ 120）裡的單段字；量字形框到格子四邊的距離。
  太緊＝上或下 < max(4px, 格高×12%)，或左或右 < max(6px, 格寬×6%)（刻意靠左的列只看右、上、下）。
- 圖示：找包住圖示中心的最小按鈕／方塊；出框＝圖示框超出容器；太緊＝上或下 < max(3px, 容器高×10%)。
用法：python3 tools/gen/padding_audit.py <截圖夾> [輸出.md]"""
import json, sys, os

def inside_pt(p, b):
    return b[0] <= p[0] <= b[0] + b[2] and b[1] <= p[1] <= b[1] + b[3]

def margins(g, b):
    return (g[0] - b[0], (b[0] + b[2]) - (g[0] + g[2]), g[1] - b[1], (b[1] + b[3]) - (g[1] + g[3]))   # 左 右 上 下

def main():
    d = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else None
    rows_t, rows_i = [], []
    st = {"cells": 0, "tight": 0, "over": 0, "icons": 0, "icon_out": 0, "icon_tight": 0, "icon_free": 0}
    for line in open(os.path.join(d, "geom.jsonl"), encoding="utf-8"):
        j = json.loads(line)
        shot = j["shot"]
        boxes = [b for b in j.get("boxes", []) if b[2] <= 420 and b[3] <= 120]
        btns = [b for b in j.get("btns", []) if b[2] > 0]
        for t in j["texts"]:
            if t.get("field"):
                continue
            g = t["g"]
            cell = t.get("own")
            if not cell:
                c = (g[0] + g[2] / 2, g[1] + g[3] / 2)
                cand = [b for b in boxes if inside_pt(c, b)]
                if not cand:
                    continue
                cell = min(cand, key=lambda b: b[2] * b[3])
            l, r, tp, bt = margins(g, cell)
            st["cells"] += 1
            left_aligned = l <= 24 and r > cell[2] * 0.3
            need_v = max(4.0, cell[3] * 0.12)
            need_h = max(6.0, cell[2] * 0.06)
            bad = []
            if min(l, r, tp, bt) < -0.5:
                bad.append("出框")
                st["over"] += 1
            if tp < need_v or bt < need_v:
                bad.append("上下太緊")
            if (not left_aligned and l < need_h) or r < need_h:
                bad.append("左右太緊")
            if bad:
                st["tight"] += 1
                rows_t.append((shot, t["s"][:24].replace("\n", " "), "、".join(bad), l, r, tp, bt, cell[2], cell[3]))
        for ic in j.get("icons", []):
            r0 = ic["r"]
            st["icons"] += 1
            c = (r0[0] + r0[2] / 2, r0[1] + r0[3] / 2)
            cand = [b for b in btns + boxes if inside_pt(c, b) and b[2] * b[3] > r0[2] * r0[3] * 1.2]
            if not cand:
                st["icon_free"] += 1
                continue
            b = min(cand, key=lambda x: x[2] * x[3])
            l, r, tp, bt = margins(r0, b)
            bad = []
            if min(l, r, tp, bt) < -0.5:
                bad.append("出框")
                st["icon_out"] += 1
            elif min(tp, bt) < max(3.0, b[3] * 0.10):
                bad.append("上下太緊")
                st["icon_tight"] += 1
            if bad:
                rows_i.append((shot, ic["n"], "、".join(bad), l, r, tp, bt, b[2], b[3]))
    lines = ["# 內距盤點（%s）" % os.path.basename(os.path.normpath(d)), "",
             "格子字 %d 段：太緊或出框 %d 段（其中出框 %d）。圖示 %d 個（不在任何框裡 %d）：出框 %d、上下太緊 %d。" % (
                 st["cells"], st["tight"], st["over"], st["icons"], st["icon_free"], st["icon_out"], st["icon_tight"]), "",
             "## 格子字（左／右／上／下 px，格子寬×高）", "| 畫面 | 字 | 問題 | 左 | 右 | 上 | 下 | 格 |", "|---|---|---|---|---|---|---|---|"]
    rows_t.sort(key=lambda x: min(x[5], x[6]))
    for r in rows_t[:200]:
        lines.append("| %s | %s | %s | %.0f | %.0f | %.0f | %.0f | %.0f×%.0f |" % r)
    lines += ["", "## 圖示", "| 畫面 | 圖示 | 問題 | 左 | 右 | 上 | 下 | 容器 |", "|---|---|---|---|---|---|---|---|"]
    rows_i.sort(key=lambda x: min(x[5], x[6]))
    for r in rows_i[:200]:
        lines.append("| %s | %s | %s | %.0f | %.0f | %.0f | %.0f | %.0f×%.0f |" % r)
    txt = "\n".join(lines) + "\n"
    if out:
        open(out, "w", encoding="utf-8").write(txt)
    print(lines[2])

if __name__ == "__main__":
    main()
