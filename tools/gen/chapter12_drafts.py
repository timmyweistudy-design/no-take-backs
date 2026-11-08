#!/usr/bin/env python3
"""V1.4 #4 軍令連鎖：第 12 章 10 關草稿。每關給 2～3 種軍令（cmd.skills），三星解要排出連鎖。
三星門檻、標準解由 game/tools/balance/puzzle_forge.gd 算，再用 tools/gen/chapter12_merge.py 併進 data/puzzles.json。
用法：python3 tools/gen/chapter12_drafts.py <輸出.json>
"""
import json
import sys

SW, SH, AR, CV, AS, PK, BM, MD, DR, BS = range(10)
SP, SHP, MM, SL, GH, VD, HG, SK, CAT, GO = range(10, 20)
AEGIS, WAR, HEAL, METEOR, FREEZE = range(5)


def col(t, c, rows):
    return [[t, c, r] for r in rows]


P = []


def pz(id_, zh, en, hzh, hen, enemy, allowed, budget, cmd, fixed=(), **kw):
    d = {"id": id_, "ch": 12, "zh": zh, "en": en, "hint_zh": hzh, "hint_en": hen,
         "enemy": [list(e) for e in enemy], "fixed": [list(f) for f in fixed],
         "budget": budget, "allowed": list(allowed), "cmd": cmd}
    d.update(kw)
    P.append(d)


pz("c1", "凍住再砸", "Freeze, Then Drop",
   "騎兵擠成一團衝過來。先冰封讓他們停住，再一顆隕石砸下去。", "The riders bunch up as they charge. Freeze them, then drop the meteor.",
   col(CV, 10, [2, 3, 4, 5, 6]) + col(AR, 14, [3, 5]), [SW, SH, AR], 20, {"skills": [FREEZE, METEOR], "uses": 1})
pz("c2", "頂住再衝", "Hold, Then Charge",
   "狂戰士第一波很兇。護盾頂住那一波，再用戰吼反推回去。", "The berserkers hit hard at first. Shield the first wave, then war-cry back.",
   col(BS, 10, [2, 4, 6]) + col(AR, 13, [3, 5]), [SW, SH, AR], 22, {"skills": [AEGIS, WAR], "uses": 1})
pz("c3", "趁凍出擊", "Strike While Frozen",
   "對方的長槍陣很硬。凍住它，趁它動不了的時候戰吼衝進去。", "Their pike wall is tough. Freeze it and war-cry in while it can't move.",
   col(PK, 10, [1, 3, 5, 7]) + col(AR, 13, [2, 6]), [SW, CV, AR], 22, {"skills": [FREEZE, WAR], "uses": 1})
pz("c4", "衝完補血", "Charge, Then Mend",
   "戰吼打得快也傷得快。衝完那一波立刻治療。", "A war cry trades fast. Heal right after the clash.",
   col(SW, 10, [2, 3, 4, 5, 6]) + col(AR, 14, [3, 5]), [SW, SH, AR], 24, {"skills": [WAR, HEAL], "uses": 1})
pz("c5", "擋下再還手", "Block, Then Return Fire",
   "對方會在開場後丟隕石。先開護盾擋下，再還他一顆。", "They drop a meteor early. Shield it, then answer with your own.",
   col(SW, 10, [2, 4, 6]) + col(AR, 13, [1, 3, 5, 7]), [SW, SH, AR], 22, {"skills": [AEGIS, METEOR], "uses": 1, "enemy": [[160, METEOR]]})
pz("c6", "兩次冰封", "Double Freeze",
   "敵人分兩波上來。冰封可以用兩次，配隕石砸第二波。", "They come in two waves. Two freezes, and a meteor for the second wave.",
   col(SW, 10, [2, 4, 6]) + col(CV, 13, [1, 3, 5, 7]), [SW, SH, PK], 20, {"skills": [FREEZE, METEOR], "uses": 2, "cd": 200})
pz("c7", "三道軍令", "Three Orders",
   "護盾、戰吼、治療各一次。排出順序：先頂住、再衝、最後補。", "Shield, war cry, heal, one each. Hold, push, then mend.",
   col(BS, 10, [3, 5]) + col(SW, 10, [2, 4, 6]) + col(AR, 14, [3, 5]), [SW, SH, AR, MD], 26, {"skills": [AEGIS, WAR, HEAL], "uses": 1})
pz("c8", "等他吼完", "Outlast the Roar",
   "對方先戰吼、再開護盾。等護盾過了，凍住它再戰吼。", "They roar, then shield. When the shield fades, freeze and roar back.",
   col(SW, 10, [2, 3, 4, 5, 6]) + col(AR, 13, [2, 6]), [SW, AR, SH], 24, {"skills": [FREEZE, WAR], "uses": 1, "enemy": [[100, WAR], [220, AEGIS]]})
pz("c9", "吸、凍、砸", "Pull, Freeze, Drop",
   "貓把敵人吸成一團，冰封讓他們散不開，隕石一次收掉。", "The cat pulls them together, freeze holds them, the meteor finishes it.",
   [[SW, 10, 0], [SW, 10, 8], [AR, 13, 1], [AR, 13, 7], [SW, 11, 3], [SW, 11, 5], [AR, 14, 4]], [CAT, SH, SW], 20,
   {"skills": [FREEZE, METEOR], "uses": 1})
pz("c10", "宗師軍令", "Grandmaster's Orders",
   "對方會丟隕石。護盾、冰封、隕石各一次，誰先誰後由你決定。", "They will drop a meteor. Shield, freeze and meteor once each; you decide the order.",
   col(CV, 10, [2, 4, 6]) + col(SW, 11, [3, 5]) + col(AR, 14, [2, 4, 6]), [SW, SH, PK, AR], 28,
   {"skills": [AEGIS, FREEZE, METEOR], "uses": 1, "enemy": [[180, METEOR]]})

if __name__ == "__main__":
    json.dump(P, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(P), "關")
