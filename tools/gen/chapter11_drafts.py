#!/usr/bin/env python3
"""V1.1 D5：第 11 章「完美主義」10 關草稿。新目標只看戰後狀態（puzzles.gd outcome）：
  flawless＝獲勝且指定兵種一隻都不倒（goal_type）；margin＝獲勝且剩餘戰力 ≥ goal_rem%。
三星門檻、解由 game/tools/balance/puzzle_forge.gd 算；預算是 tools/gen/puzzle_tune.py 自動調過的值（w6、w8 放寬門檻）；
併入用 tools/gen/chapter11_merge.py（附加在 data/puzzles.json 的 extra 與 chapters 後面，不動前 10 章）。
用法：python3 tools/gen/chapter11_drafts.py <輸出.json>
"""
import json
import sys

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))
from puzzle_drafts import col, SW, SH, AR, CV, AS, PK, BM, MD, DR, BS, SP, SHP, MM, SL, GH, VD, HG, SK, CAT, GO  # noqa: E402

P = []


def pz(id_, zh, en, hzh, hen, enemy, allowed, budget, fixed=(), unit=None, **kw):
    d = {"id": id_, "ch": 11, "zh": zh, "en": en, "hint_zh": hzh, "hint_en": hen,
         "enemy": [list(e) for e in enemy], "fixed": [list(f) for f in fixed],
         "budget": budget, "allowed": list(allowed)}
    if unit is not None:
        d["unit"] = unit
    d.update(kw)
    P.append(d)


pz("w1", "醫者一個都不能倒", "Not One Medic",
   "弓箭手會瞄準後排。醫者要躲在盾牆正後方。", "Their archers aim at the back. Keep medics right behind the shields.",
   col(AR, 14, [2, 4, 6]) + col(SW, 10, [3, 5]), [SH, MD, SW], 18, fixed=[[MD, 2, 4]], unit=MD,
   goal="flawless", goal_type=MD)
pz("w2", "漂亮的勝利", "A Clean Win",
   "光是贏還不夠，要剩六成以上的戰力。", "Winning is not enough. Keep at least 60% of your power.",
   col(SW, 10, [2, 4, 6]) + col(AR, 13, [3, 5]), [SW, SH, AR], 37, goal="margin", goal_rem=60)
pz("w3", "護弓", "Guard the Bows",
   "騎兵會繞過來找弓箭手。長槍兵擋在側翼，弓箭手一隻都不能倒。", "Cavalry will flank for the archers. Pikes on the wings; lose no archer.",
   col(CV, 11, [0, 4, 8]) + col(SW, 10, [3, 5]), [AR, PK, SH], 30, fixed=[[AR, 1, 4]], unit=PK,
   goal="flawless", goal_type=AR)
pz("w4", "史萊姆濃湯", "Slime Soup",
   "史萊姆會分裂。先吸成一團再炸，要剩五成。", "Slimes split. Pull them together, then blow them up, and keep half your power.",
   col(SL, 10, [1, 3, 5, 7]) + [[AR, 14, 4]], [SHP, CAT, SH], 62, unit=CAT, goal="margin", goal_rem=50)
pz("w5", "火罐別碰", "Don't Touch the Pots",
   "刺客會潛行找投彈兵。長槍兵貼身保護，投彈兵一隻都不能倒。", "Assassins hunt the bombers. Keep pikes close; lose no bomber.",
   col(AS, 11, [2, 6]) + col(SH, 10, [3, 4, 5]), [BM, PK, SW], 25, fixed=[[BM, 1, 4]], unit=PK,
   goal="flawless", goal_type=BM)
pz("w6", "一波帶走", "One Sweep",
   "對面是一整排弓箭手。衝得夠快才能剩五成五以上。", "A full line of archers. Charge fast enough to keep 55%.",
   col(AR, 13, [1, 3, 5, 7]) + col(AR, 14, [2, 6]) + [[SH, 10, 4]], [CV, AS, SH], 46, goal="margin", goal_rem=55)
pz("w7", "鼓聲不停", "The Drum Keeps Beating",
   "幽靈專找支援兵。弓箭手先把幽靈射下來，鼓手不能倒。", "Ghosts go for supports. Shoot the ghosts first; the drummer must not fall.",
   col(GH, 11, [3, 5]) + col(SW, 10, [2, 4, 6]), [AR, SW, SH], 30, fixed=[[DR, 2, 4]], unit=AR,
   goal="flawless", goal_type=DR)
pz("w8", "精打細算", "Every Coin Counts",
   "只能帶四隻，還要剩兩成五。", "Only four units, and keep a quarter of your power.",
   col(SW, 10, [3, 5]) + col(SH, 10, [4]) + col(AR, 13, [2, 6]) + [[MD, 14, 4]],
   [GO, BS, CV, AR, BM, SH], 50, cap=4, goal="margin", goal_rem=25)
pz("w9", "時間守護者", "Keeper of Time",
   "骷髏法師會叫起倒下的兵。沙漏精靈要撐到最後。", "The necromancer raises the fallen. The hourglass sprite must survive.",
   [[SK, 15, 4]] + col(SW, 10, [2, 4, 6]) + col(SL, 11, [3, 5]), [GH, AR, SH, CV], 32, fixed=[[HG, 1, 4]], unit=GH,
   goal="flawless", goal_type=HG)
pz("w10", "完美主義", "Perfectionist",
   "什麼兵都能用。贏，而且要剩一半以上。", "Any unit. Win, and keep more than half.",
   col(SH, 10, [2, 4, 6]) + col(PK, 11, [1, 7]) + col(AR, 13, [3, 5]) + [[BM, 14, 4], [MD, 14, 2], [CAT, 11, 4]],
   list(range(20)), 62, goal="margin", goal_rem=50)

if __name__ == "__main__":
    ids = [p["id"] for p in P]
    assert len(ids) == len(set(ids)) == 10, len(ids)
    json.dump(P, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(P), "drafts")
