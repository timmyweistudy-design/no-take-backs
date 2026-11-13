#!/usr/bin/env python3
"""1.3.0 方案盤點（使用者第 10 點「文字在格子裡面要置中對齊」）：讀 dev_main --geom-dump 寫的 geom.jsonl，
量每段「在格子裡」的字和格子中心的偏移。
- 按鈕標籤：字形框中心 vs 按鈕框中心（水平、垂直）。
- 方塊裡的字（九宮格方塊、沒有按鈕的格子）：只看單行、整段落在一個方塊內、而且方塊不大（寬 ≤ 420、高 ≤ 120，像格子不像面板）。
門檻：水平偏移 > max(3px, 4% 格寬) 或垂直偏移 > max(3px, 12% 格高) 算不置中。刻意靠左的列（字從格子左邊 ≤ 24px 開始、而且右邊留很多）另外標「靠左」，不算錯，列給人看。
用法：python3 tools/gen/center_audit.py <截圖夾> [輸出.md]"""
import json, sys, os

def inside(g, b, pad=2):
    return g[0] >= b[0] - pad and g[1] >= b[1] - pad and g[0] + g[2] <= b[0] + b[2] + pad and g[1] + g[3] <= b[1] + b[3] + pad

def off(g, b):
    return (g[0] + g[2] / 2) - (b[0] + b[2] / 2), (g[1] + g[3] / 2) - (b[1] + b[3] / 2)

def main():
    d = sys.argv[1]
    rows = []
    stats = {"btn": 0, "btn_bad": 0, "box": 0, "box_bad": 0, "box_left": 0}
    for line in open(os.path.join(d, "geom.jsonl"), encoding="utf-8"):
        j = json.loads(line)
        # 同一個框裡有兩段以上的字＝卡片（標題＋星、頭像＋價錢），排版本來就不是置中；只量「一格一段字」
        def key(r): return tuple(round(v) for v in r)
        cnt = {}
        for t in j["texts"]:
            if t.get("field"):
                continue
            if t.get("own"):
                cnt[key(t["own"])] = cnt.get(key(t["own"]), 0) + 1
            else:
                for b in j["boxes"]:
                    if inside(t["g"], b):
                        cnt[key(b)] = cnt.get(key(b), 0) + 1
        for t in j["texts"]:
            if t.get("field"):
                continue
            g = t["g"]
            if t.get("own"):
                b = t["own"]
                kind = "btn"
            else:
                cand = [b for b in j["boxes"] if inside(g, b) and b[2] <= 420 and b[3] <= 120]
                if not cand:
                    continue
                b = min(cand, key=lambda r: r[2] * r[3])
                kind = "box"
            if cnt.get(key(b), 0) > 1:
                stats["card"] = stats.get("card", 0) + 1
                continue
            stats[kind] += 1
            dx, dy = off(g, b)
            tx = max(3.0, b[2] * 0.04)
            ty = max(3.0, b[3] * 0.12)
            left = kind == "box" and g[0] - b[0] <= 24 and (b[0] + b[2]) - (g[0] + g[2]) > 40
            if left:
                stats["box_left"] += 1
                rows.append((j["shot"], kind + "/靠左", t["s"], dx, dy, b))
                continue
            if abs(dx) > tx or abs(dy) > ty:
                stats[kind + "_bad"] += 1
                rows.append((j["shot"], kind, t["s"], dx, dy, b))
    out = ["# 格子內文字置中盤點：" + d, "",
           "按鈕標籤 %d 段、不置中 %d；方塊內單行字 %d 段、不置中 %d、刻意靠左 %d；卡片（一框多段字，不量）%d 段" % (stats["btn"], stats["btn_bad"], stats["box"], stats["box_bad"], stats["box_left"], stats.get("card", 0)), "",
           "| 畫面 | 類型 | 字 | 水平偏移 | 垂直偏移 | 格子 [x,y,w,h] |", "|---|---|---|---|---|---|"]
    for r in sorted(rows, key=lambda r: (r[1].endswith("靠左"), -abs(r[3]) - abs(r[4]))):
        out.append("| %s | %s | %s | %+.1f | %+.1f | %s |" % (r[0], r[1], r[2].replace("|", "／")[:28], r[3], r[4], [round(v) for v in r[5]]))
    txt = "\n".join(out) + "\n"
    if len(sys.argv) > 2:
        open(sys.argv[2], "w", encoding="utf-8").write(txt)
    print(out[2])

if __name__ == "__main__":
    main()
