#!/usr/bin/env python3
"""V1.0.0 角色：剪影辨識報告。輸入 dev_main --sil= 的截圖，輸出灰階表與「輪廓最像」的兵種配對。
做法：每格從背景（50% 灰）分出前景遮罩，裁到外框、縮成 32×32，兩兩算 IoU（重疊／聯集）；IoU 越高越難只靠剪影分辨。
另算灰階內部對比（前景亮度標準差）：越低越像一團色塊。用 50% 那兩排（實戰大小）。
用法：python3 tools/gen/sil_report.py <sil.png> <輸出資料夾>"""
import sys, os, json, itertools
from PIL import Image, ImageOps, ImageStat
NAMES = ["劍士", "盾兵", "弓箭手", "騎兵", "刺客", "長槍兵", "投彈兵", "醫者", "鼓手", "狂戰士", "孢子菇", "爆爆羊", "寶箱怪", "史萊姆", "幽靈", "巫毒娃娃", "沙漏精靈", "骷髏法師", "吸塵貓", "小石魔", "小史萊姆", "骷髏"]
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
im = Image.open(src).convert("RGB")
gray = ImageOps.grayscale(im)
gray.save(os.path.join(out, "sil_gray.png"))
masks, contrast = [], []
for t in range(22):
    col, row = t % 11, t // 11
    x = 58 + col * 116
    y = 560 + row * 110
    box = (x - 56, y - 70, x + 56, y + 20)
    c = im.crop(box)
    m = Image.new("L", c.size, 0)
    px, mp = c.load(), m.load()
    for i in range(c.size[0]):
        for j in range(c.size[1]):
            r, g, b = px[i, j]
            if abs(r - 128) + abs(g - 128) + abs(b - 128) > 30:
                mp[i, j] = 255
    bb = m.getbbox()
    m2 = m.crop(bb).resize((32, 32))
    masks.append([v > 127 for v in m2.getdata()])
    st = ImageStat.Stat(gray.crop(box), mask=m)
    contrast.append(round(st.stddev[0], 1))
pairs = []
for a, b in itertools.combinations(range(22), 2):
    inter = sum(1 for p, q in zip(masks[a], masks[b]) if p and q)
    uni = sum(1 for p, q in zip(masks[a], masks[b]) if p or q)
    pairs.append((round(inter / max(1, uni), 3), a, b))
pairs.sort(reverse=True)
score = {}
for iou, a, b in pairs[:12]:
    score[a] = score.get(a, 0) + iou
    score[b] = score.get(b, 0) + iou
worst = sorted(score, key=lambda k: -score[k])[:5]
rep = {"top_pairs": [[iou, NAMES[a], NAMES[b]] for iou, a, b in pairs[:12]], "worst5": [NAMES[k] for k in worst], "worst5_ids": worst,
       "low_contrast": sorted([[contrast[t], NAMES[t]] for t in range(22)])[:5]}
json.dump(rep, open(os.path.join(out, "sil_report.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(json.dumps(rep, ensure_ascii=False))
