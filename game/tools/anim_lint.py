#!/usr/bin/env python3
"""角色動畫檢查（V9 P2）：讀 anim_sheet.gd 產的 frames.png。
- 部件分離：每格的連通塊；孢子菇攻擊的孢子粒、沙漏流沙、星星屬於刻意（ALLOW）。
- 超框：有不透明碰到格子邊界。
另外輸出 walk.png（待機＋走路＋拖行＋暈眩）、atk.png（兩組攻擊）接觸表。
用法：python3 tools/anim_lint.py <資料夾>
"""
import sys
from collections import deque
from PIL import Image

NAMES = "劍士 盾兵 弓箭手 騎兵 刺客 長槍兵 投彈兵 醫者 鼓手 狂戰士 孢子菇 爆爆羊 寶箱怪 史萊姆 幽靈 巫毒娃娃 沙漏精靈 骷髏法師 吸塵貓 小石魔 小史萊姆 骷髏".split()
C, S, BG, W = 192, 2, (0x7d, 0x9a, 0x58), 8
ALLOW = {("孢子菇", "atk"), ("爆爆羊", "*"), ("沙漏精靈", "*")}   # 孢子粒、火星、流沙是刻意分開的


def comps(px, x0, y0, c):
    m = [[sum(abs(a - b) for a, b in zip(px[x0 + x, y0 + y], BG)) > 40 for x in range(c)] for y in range(c)]
    seen = [[False] * c for _ in range(c)]
    out, edge = [], False
    for y in range(c):
        for x in range(c):
            if m[y][x] and not seen[y][x]:
                if x in (0, c - 1) or y in (0, c - 1):
                    edge = True
                q, n = deque([(y, x)]), 0
                seen[y][x] = True
                while q:
                    a, b = q.popleft()
                    n += 1
                    for da in (-1, 0, 1):
                        for db in (-1, 0, 1):
                            e, f = a + da, b + db
                            if 0 <= e < c and 0 <= f < c and m[e][f] and not seen[e][f]:
                                seen[e][f] = True
                                q.append((e, f))
                if n >= 3:
                    out.append(n)
    return sorted(out, reverse=True), edge


def main():
    d = sys.argv[1]
    im = Image.open(d + "/frames.png").convert("RGB")
    per = im.width // C
    small = im.resize((im.width // S, im.height // S), Image.NEAREST)
    px, c, bad = small.load(), C // S, []
    for t, nm in enumerate(NAMES):
        for f in range(per):
            kind = "atk" if f >= 2 + W + 2 else "move"
            cs, edge = comps(px, f * c, t * c, c)
            if edge:
                bad.append(f"{nm} 第{f}格超框")
            if len(cs) > 1 and (nm, kind) not in ALLOW and (nm, "*") not in ALLOW:
                bad.append(f"{nm} 第{f}格分離 {cs[1:]}")

    def sheet(cols, name, rows=range(len(NAMES)), s=0.42, crop=(14, 30, 178, 186)):
        w, h = crop[2] - crop[0], crop[3] - crop[1]
        o = Image.new("RGB", (int(len(cols) * w * s), int(len(rows) * h * s)), BG)
        for j, r in enumerate(rows):
            for i, cc in enumerate(cols):
                t = im.crop((cc * C + crop[0], r * C + crop[1], cc * C + crop[2], r * C + crop[3])).resize((int(w * s), int(h * s)), Image.LANCZOS)
                o.paste(t, (int(i * w * s), int(j * h * s)))
        o.save(f"{d}/{name}.png")

    sheet(list(range(0, 2 + W + 2)), "walk")
    sheet(list(range(2 + W + 2, per, 2)), "atk")
    print(f"ANIMLINT {len(NAMES)} 種 × {per} 格、問題 {len(bad)}" + ("：" + "；".join(bad[:12]) if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
