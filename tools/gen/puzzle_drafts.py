#!/usr/bin/env python3
"""第十三輪殘局草稿（第 2、4～10 章新增的 75 關）。

這裡只寫題目：敵陣、我方固定兵、可用兵種、預算、目標。三星門檻、標準解、三星解由
game/tools/balance/puzzle_forge.gd 算出來，再由 tools/gen/puzzle_merge.py 併進 data/puzzles.json。

兵種：0劍士 1盾兵 2弓箭手 3騎兵 4刺客 5長槍兵 6投彈兵 7醫者 8鼓手 9狂戰士
      10孢子菇 11爆爆羊 12寶箱怪 13史萊姆 14幽靈 15巫毒娃娃 16沙漏精靈 17骷髏法師 18吸塵貓 19小石魔
格子：我方欄 0～5（5 是前排），敵方欄 10～15（10 是前排），列 0～8。
技能：0全員護盾 1戰吼 2治癒之雨 3隕石 4冰封。tick：每秒 20。
用法：python3 tools/gen/puzzle_drafts.py <輸出.json>
"""
import json
import sys

SW, SH, AR, CV, AS, PK, BM, MD, DR, BS = range(10)
SP, SHP, MM, SL, GH, VD, HG, SK, CAT, GO = range(10, 20)
AEGIS, WAR, HEAL, METEOR, FREEZE = range(5)


def col(t, c, rows):
    return [[t, c, r] for r in rows]


P = []


def pz(id_, ch, zh, en, hzh, hen, enemy, allowed, budget, fixed=(), unit=None, **kw):
    d = {"id": id_, "ch": ch, "zh": zh, "en": en, "hint_zh": hzh, "hint_en": hen,
         "enemy": [list(e) for e in enemy], "fixed": [list(f) for f in fixed],
         "budget": budget, "allowed": list(allowed)}
    if unit is not None:
        d["unit"] = unit
    d.update(kw)
    P.append(d)


# ── 第 2 章 王國新兵：每關一個概念，簡單 ──
pz("k1", 2, "盾後放箭", "Arrows Behind Shields",
   "盾兵站前面，弓箭手躲在後面慢慢射。", "Shields in front, archers behind them.",
   col(SW, 10, [2, 3, 4, 5, 6]) + [[BS, 11, 4]], [SH, AR], 24, unit=AR)
pz("k2", 2, "鼓聲", "Drumbeat",
   "鼓手站在人群中間，身邊的劍士都會打得更快。", "Put the drummer in the middle of your swordsmen.",
   col(SW, 10, [2, 3, 5, 6]) + col(AR, 14, [3, 5]), [DR, SW], 21, unit=DR)
pz("k3", 2, "撐住前線", "Hold the Line",
   "盾兵擋箭，醫者在後面補血，撐到對方的劍士先倒。", "Shields soak the arrows; a medic behind keeps them standing.",
   col(AR, 14, [1, 3, 5, 7]) + col(SW, 10, [3, 5]), [MD, SH], 22, unit=MD)
pz("k4", 2, "先拔醫者", "Medics First",
   "盾牆後面的醫者一直在補血。刺客會潛行過去。", "Medics behind the wall keep healing. Assassins slip past.",
   col(SH, 10, [2, 3, 4, 5, 6]) + col(MD, 13, [3, 5]), [AS, SW], 21, unit=AS)
pz("k5", 2, "一罐清場", "One Pot Clears It",
   "敵人擠成一團。投彈兵從後面丟火罐，盾兵擋住前面。", "They are packed tight. Bombers lob from the back; shields hold the front.",
   col(SH, 10, [3, 4, 5]) + col(MD, 11, [3, 5]) + [[SW, 11, 4]], [BM, SH], 18, unit=BM)

# ── 第 4 章 跨界連鎖 I：兩種兵的化學反應 ──
pz("x1", 4, "吸塵羊鍋", "Vacuum Stew",
   "敵人散得很開，羊一次炸不到幾隻。先讓貓把他們吸成一團。", "They are spread out. Let the cat pull them together first.",
   col(AR, 14, [0, 2, 4, 6, 8]) + col(SW, 10, [1, 4, 7]), [CAT, SHP], 20, fixed=[[SH, 5, 4]], unit=CAT)
pz("x2", 4, "破陣連鎖", "Breach Chain",
   "盾牆擋得住箭，可是被狂戰士打過的盾兵就擋不住了。", "A shield wall stops arrows, unless a berserker has breached it.",
   col(SH, 10, [1, 2, 3, 4, 5, 6, 7]) + col(AR, 14, [2, 4, 6]), [BS, AR], 26, unit=BS)
pz("x3", 4, "骨堆再起", "Rise Again",
   "前排會倒，但倒下的還能被骷髏法師叫起來再擋一波。", "Your front will fall, and a skeleton mage can raise them again.",
   col(BS, 10, [2, 4, 6]) + col(CV, 12, [0, 8]), [SK, SW], 18, fixed=col(SW, 5, [3, 5]), unit=SK)
pz("x4", 4, "借刀殺羊", "Borrowed Blast",
   "敵方的爆爆羊在半路被打死，會連自己人一起炸。", "Enemy sheep killed on the way explode on their own side.",
   col(SHP, 10, [3, 4, 5]) + col(AR, 11, [3, 4, 5]) + col(AR, 12, [3, 5]), [AR, SH], 20, unit=AR)
pz("x5", 4, "破陣斷槍", "Break the Pikes",
   "長槍兵讓騎兵的衝鋒白費。先讓狂戰士打亂他們，騎兵再衝。", "Pikes stop the charge. Let a berserker breach them first.",
   col(PK, 10, [2, 3, 4, 5, 6]) + col(AR, 13, [2, 4, 6]), [BS, CV], 30, unit=BS)
pz("x6", 4, "毒走廊", "Poison Corridor",
   "敵人一定會走過中間。把孢子菇種在路上，讓弓箭手慢慢射。", "They must cross the middle. Plant sporecaps on the road.",
   col(SW, 10, [1, 2, 3, 4, 5, 6, 7]) + col(BS, 11, [3, 5]), [SP, SH], 20, fixed=col(AR, 0, [3, 5]), unit=SP)
pz("x7", 4, "啞火", "Misfire",
   "投彈兵近身就丟不了火罐。幽靈會穿過盾牆貼上去。", "Bombers can't lob at point blank. Ghosts drift through the wall.",
   col(SH, 10, [2, 3, 4, 5, 6]) + col(BM, 13, [1, 3, 5, 7]), [GH, SW], 24, unit=GH)
pz("x8", 4, "誘餌寶箱", "Bait Chest",
   "寶箱怪等人上門咬一大口。放在敵人一定會經過的空地。", "The mimic bites whoever walks by. Put it where they must pass.",
   col(AS, 12, [1, 4, 7]) + col(BM, 14, [3, 5]) + col(SW, 10, [3, 5]), [MM, SW], 20, unit=MM)
pz("x9", 4, "綁定替死", "Shared Pain",
   "巫毒娃娃綁住對面的狂戰士，它打得越痛自己越痛。", "The voodoo doll binds a berserker: the harder it hits, the more it hurts itself.",
   col(BS, 10, [2, 4, 6]) + [[DR, 12, 4]], [VD, SH], 20, unit=VD)
pz("x10", 4, "打不完的前排", "Endless Front",
   "刺客一刀一隻。史萊姆打倒了會分裂，刺客砍不完。", "Assassins kill one at a time. Slimes split when they fall.",
   col(AS, 11, [1, 3, 5, 7]) + col(SW, 10, [2, 6]), [SL, AR], 20, unit=SL)

# ── 第 5 章 跨界連鎖 II：3～4 種兵、敵陣混搭 ──
pz("y1", 5, "斷腿陣", "Hamstring",
   "騎兵衝得又快又痛。碎石會讓他們變慢，長槍兵專門擋騎兵。", "Rubble slows the riders; pikes stop them.",
   col(CV, 10, [0, 4, 8]) + col(CV, 11, [2, 6]) + col(AR, 14, [3, 5]), [GO, AS, PK], 30, unit=GO)
pz("y2", 5, "時停打斷", "Time Out",
   "狂戰士一起衝上來時，前排快倒的瞬間，沙漏精靈會讓時間停下來。", "When your front is about to break, the hourglass sprite stops time.",
   col(BS, 10, [2, 3, 5, 6]) + [[DR, 11, 4], [MD, 13, 4]], [HG, SH, AR], 28, unit=HG)
pz("y3", 5, "吸塵炸彈營", "Bomb Camp",
   "火罐要打擠成一團的敵人。貓會幫你把他們擠在一起。", "Pots love a crowd. The cat makes one.",
   [[SW, 10, 0], [SW, 10, 8], [AR, 13, 1], [AR, 13, 7], [SW, 11, 3], [SW, 11, 5], [AR, 14, 4], [BS, 12, 4]],
   [CAT, BM, SH], 28, unit=CAT)
pz("y4", 5, "雙層破盾", "Double Breach",
   "前面是盾，後面是長槍，再後面還有醫者。一層一層拆。", "Shields, then pikes, then medics. Peel them one layer at a time.",
   col(SH, 10, [2, 3, 4, 5, 6]) + col(PK, 11, [3, 5]) + col(MD, 13, [2, 6]), [BS, BM, SW], 30, unit=BS)
pz("y5", 5, "幽靈刺殺", "Ghost Raid",
   "弓箭手躲在盾牆後面。幽靈不必走正門。", "Archers hide behind the wall. Ghosts don't use the front door.",
   col(SH, 10, [1, 2, 3, 4, 5, 6, 7]) + col(AR, 14, [1, 3, 5, 7]) + [[MD, 15, 4]], [GH, AS, SH], 30, unit=GH)
pz("y6", 5, "毒圈嘲諷", "Taunt Trap",
   "盾兵會把近戰的敵人吸過來打它。讓它站在毒圈裡。", "Shields draw melee foes to them. Stand them inside the spores.",
   col(SW, 10, [0, 2, 4, 6, 8]) + col(BS, 11, [3, 5]) + col(CV, 12, [1, 7]), [SP, SH, AR], 30, unit=SP)
pz("y7", 5, "不倒軍", "The Undying",
   "前排一直倒，又一直站起來、一直分裂。拖久了就是你的。", "Your front keeps falling, splitting and getting back up. Drag it out.",
   col(AR, 14, [1, 3, 5, 7]) + col(SW, 10, [2, 4, 6]) + [[BM, 15, 4]], [SK, SL, MD], 30, unit=SK)
pz("y8", 5, "順風車", "Free Ride",
   "敵方的貓會把你的兵吸過去，包括你的爆爆羊。", "Their cats pull your units in, sheep included.",
   col(CAT, 10, [2, 6]) + col(SH, 11, [3, 4, 5]) + col(AR, 13, [2, 4, 6]), [SHP, AR], 22, unit=SHP)
pz("y9", 5, "鼓舞突擊", "Rally Charge",
   "鼓手讓身邊的人打得更快。衝鋒的時候也要有人敲鼓。", "Drums speed up everyone nearby, even a charge.",
   col(AR, 13, [0, 2, 4, 6, 8]) + col(SH, 10, [3, 5]), [DR, CV, BS], 30, unit=DR)
pz("y10", 5, "大雜燴", "Melting Pot",
   "什麼都有的敵陣，你也什麼都能帶。找出最划算的組合。", "They brought everything, and so can you. Find the best mix.",
   col(SH, 10, [3, 5]) + col(SW, 10, [2, 6]) + col(AR, 14, [2, 6]) + [[BM, 15, 4], [MD, 13, 4]] + col(CV, 12, [0, 8]),
   [SW, SH, AR, CV, SP, SHP, CAT, GO], 36)

# ── 第 6 章 護送・死守・斬首 ──
pz("g1", 6, "護送醫者", "Escort the Medic",
   "刺客只想找醫者。醫者倒了就算輸。", "The assassins want the medic. If it falls, you fail.",
   col(AS, 12, [1, 3, 5, 7]), [SW, SH], 20, fixed=[[MD, 2, 4]], goal="protect", goal_unit=[2, 4])
pz("g2", 6, "鼓手不能倒", "Keep the Drum",
   "騎兵會從兩側繞過來找鼓手。", "The riders will swing round the flanks for your drummer.",
   col(CV, 10, [0, 8]) + col(SW, 10, [3, 5]), [PK, SH, AR], 22, fixed=[[DR, 3, 4]], goal="protect", goal_unit=[3, 4])
pz("g3", 6, "守住沙漏", "Guard the Hourglass",
   "幽靈會穿過前排去找沙漏精靈。", "Ghosts drift through the front line for your sprite.",
   col(GH, 11, [2, 4, 6]), [SW, SH, AR], 18, fixed=[[HG, 2, 4]] + col(SH, 5, [3, 5]), goal="protect", goal_unit=[2, 4])
pz("g4", 6, "撐住", "Hold Out",
   "打不贏沒關係，撐到時間到就好。", "You don't need to win. Just still be standing when time runs out.",
   col(SW, 10, [1, 2, 3, 4, 5, 6, 7]) + col(AR, 13, [2, 4, 6]) + [[BS, 11, 4]], [SH, MD, SL], 20,
   goal="survive", goal_ticks=300)
pz("g5", 6, "狂潮", "The Frenzy",
   "狂戰士一波衝上來。撐住，等他們自己累。", "A berserker wave. Weather it.",
   col(BS, 10, [2, 3, 4, 5, 6]) + [[DR, 12, 4]], [SH, PK, VD, SL], 22, goal="survive", goal_ticks=400)
pz("g6", 6, "羊群過境", "Stampede",
   "滿滿的爆爆羊衝過來。別讓牠們一次炸光你。", "A flock of boom sheep. Don't let them blow up everything at once.",
   col(SHP, 10, [0, 2, 4, 6, 8]) + col(SHP, 11, [1, 4, 7]) + col(AR, 14, [3, 5]), [AR, MM, SH], 18,
   goal="survive", goal_ticks=240)
pz("g7", 6, "斬首：投彈兵", "Take Out the Bomber",
   "把最後面的投彈兵打倒，而且要打贏。", "Defeat the bomber at the very back, and win.",
   col(SH, 10, [2, 3, 4, 5, 6]) + col(SW, 11, [3, 5]) + [[BM, 15, 4]], [AS, CV, SW], 24, goal="kill", goal_unit=[15, 4])
pz("g8", 6, "斬首：骷髏法師", "Take Out the Necromancer",
   "骷髏法師一直把倒下的叫起來。先打倒它。", "The skeleton mage keeps raising the fallen. Take it down.",
   [[SK, 15, 4]] + col(SW, 10, [2, 4, 6]) + col(SL, 11, [3, 5]), [GH, AR, CV], 26, goal="kill", goal_unit=[15, 4])
pz("g9", 6, "斬首：鼓手", "Silence the Drum",
   "長槍兵後面的鼓手讓大家都打得很快。", "The drummer behind the pikes makes everyone faster.",
   [[DR, 13, 4]] + col(PK, 10, [2, 3, 4, 5, 6]) + col(AR, 12, [2, 6]), [CV, BS, AR], 26, goal="kill", goal_unit=[13, 4])
pz("g10", 6, "亂軍中的醫者", "Medic in the Melee",
   "幽靈、刺客、火罐都會找你的醫者。", "Ghosts, assassins and pots all want your medic.",
   col(GH, 11, [2, 6]) + col(AS, 12, [3, 5]) + [[BM, 14, 4]], [SW, MM, SH, CAT], 24,
   fixed=[[MD, 1, 4]], goal="protect", goal_unit=[1, 4])

# ── 第 7 章 地利（地圖 1 雙橋河谷 2 林間小徑 3 冰湖雪原 4 熔岩裂谷 5 古道峽谷）──
pz("d1", 7, "守橋", "Hold the Bridges",
   "河上只有兩座橋，敵人一定會從橋上過來。", "Only two bridges cross the river. They must come over them.",
   col(SW, 10, [1, 2, 5, 6]) + col(BS, 11, [1, 6]) + col(AR, 13, [3, 5]), [SP, AR, SH], 24, map=1, unit=SP)
pz("d2", 7, "過橋", "Cross the River",
   "對方守在橋口。兩座橋要一起攻。", "They guard both bridgeheads. Hit both at once.",
   col(SH, 10, [1, 2, 5, 6]) + col(AR, 13, [1, 6]) + col(BM, 14, [4]), [CV, AR, BS, GH], 30, map=1)
pz("d3", 7, "林間伏擊", "Forest Ambush",
   "樹林把路切成幾段，泥地會讓人變慢。", "Trees split the path; mud slows everyone.",
   col(SW, 10, [0, 4, 8]) + col(CV, 11, [1, 7]) + col(AR, 14, [3, 5]), [PK, MM, AR], 26, map=2)
pz("d4", 7, "穿林幽靈", "Through the Trees",
   "樹擋得住人，擋不住幽靈。", "Trees stop soldiers, not ghosts.",
   col(SH, 10, [3, 4, 5]) + col(AR, 14, [1, 4, 7]) + col(BM, 13, [2, 6]), [GH, SW, SH], 26, map=2, unit=GH)
pz("d5", 7, "冰上衝鋒", "Charge on Ice",
   "冰面會加速，衝鋒的人跑得更快。", "The ice speeds you up, charges included.",
   col(AR, 13, [2, 4, 6]) + col(SH, 10, [3, 5]) + [[MD, 14, 4]], [CV, SW, AR], 26, map=3, unit=CV)
pz("d6", 7, "雪地陷阱", "Snow Trap",
   "上下兩條雪地會讓人變慢。讓敵人陷在裡面。", "The snow bands slow everyone down. Keep them stuck there.",
   col(SW, 10, [0, 1, 7, 8]) + col(BS, 11, [4]) + col(AR, 14, [0, 8]), [AR, BM, SP, SH], 24, map=3)
pz("d7", 7, "熔岩隘口", "Lava Pass",
   "熔岩塊把中間堵住，只能從上下繞。", "The lava rock blocks the middle; go round.",
   col(SH, 10, [3, 4, 5]) + col(SW, 11, [0, 8]) + col(AR, 14, [2, 6]), [CV, AS, AR, SW], 28, map=4)
pz("d8", 7, "火山口", "Crater",
   "熔岩旁邊很慢。對面的投彈兵最喜歡你站在那裡。", "It's slow around the crater, right where their bombers want you.",
   col(BM, 14, [2, 4, 6]) + col(SH, 10, [2, 6]) + col(SW, 10, [4]), [GH, CV, SH, AR], 28, map=4)
pz("d9", 7, "峽谷三路", "Three Lanes",
   "兩道石牆把峽谷分成三條路。中間那條最慢。", "Two rock walls split the canyon into three lanes; the middle one is slow.",
   col(SW, 10, [0, 4, 8]) + col(AR, 13, [1, 7]) + col(BS, 11, [4]), [PK, AR, CV, SH], 26, map=5)
pz("d10", 7, "峽谷快道", "Fast Lanes",
   "上下兩條是快道。誰先繞到後面誰贏。", "The outer lanes are fast. Whoever gets behind first wins.",
   col(CV, 11, [0, 8]) + col(SH, 10, [3, 5]) + col(AR, 14, [3, 4, 5]), [CV, PK, AS, AR], 28, map=5)

# ── 第 8 章 限制與借力 ──
pz("l1", 8, "四人小隊", "Squad of Four",
   "錢很多，但只能放四隻。", "Plenty of gold, but only four units.",
   col(SW, 10, [2, 3, 4, 5, 6]) + col(AR, 14, [3, 5]), [SW, SH, AR, CV, BS], 30, cap=3)
pz("l2", 8, "兩個就夠", "Two Is Enough",
   "只能放兩隻。挑最能打的。", "Only two. Pick the strongest.",
   col(SW, 10, [3, 5]) + col(AR, 13, [2, 6]), [GO, CV, BS, SW], 16, cap=2)
pz("l3", 8, "魔物四人組", "Monster Four",
   "只能放四隻魔物。", "Four monsters, no more.",
   col(SH, 10, [2, 4, 6]) + col(AR, 13, [3, 5]) + [[MD, 14, 4]], [SP, SHP, MM, SL, GH, VD, CAT, GO], 30, cap=4)
pz("l4", 8, "精兵", "Elite Few",
   "敵人比你多很多。三隻就要打贏。", "They outnumber you. Win with three.",
   col(SW, 10, [1, 3, 5, 7]) + col(AR, 13, [2, 4, 6]) + [[BS, 11, 4]], [GO, CV, BM, MD, DR], 24, cap=3)
pz("b1", 8, "敵羊當炸彈", "Their Sheep, Our Bomb",
   "敵方的羊擠在他們自己的醫者旁邊。半路射死牠。", "Their sheep stand by their own medics. Shoot them early.",
   col(SHP, 11, [2, 4, 6]) + col(MD, 12, [3, 5]) + col(SH, 10, [3, 5]), [AR, SH, SW], 20, unit=AR)
pz("b2", 8, "送上門", "Special Delivery",
   "敵方的貓會把你的兵吸過去。讓它吸到寶箱怪。", "Their cats pull your units in. Let them pull a mimic.",
   col(CAT, 10, [1, 4, 7]) + col(AR, 13, [2, 6]) + [[BM, 14, 4]], [MM, SW, SH], 20, unit=MM)
pz("b3", 8, "繞過盾牆", "Around the Wall",
   "對方的盾兵會吸引你的近戰。讓遠程從旁邊打。", "Their shields draw your melee in. Hit them from the side with range.",
   col(SH, 10, [1, 3, 5, 7]) + col(BM, 13, [2, 6]) + [[MD, 14, 4]], [AR, BM, AS, SW], 24)
pz("b4", 8, "反綁", "Bind Back",
   "對方有巫毒娃娃。別讓你最強的兵被綁住。", "They have voodoo dolls. Don't let your heavy hitter get bound.",
   col(VD, 10, [3, 5]) + col(BS, 10, [2, 6]) + col(AR, 13, [3, 5]), [BS, AR, SH, CV], 24)
pz("m1", 8, "鏡中對決", "Mirror Match",
   "對方的陣型和預算跟你一樣。擺法決定勝負。", "Same troops, same gold. Placement decides it.",
   col(SH, 10, [3, 5]) + col(AR, 13, [2, 4, 6]) + [[CV, 11, 0], [BS, 11, 8]], [SH, AR, CV, BS], 33)
pz("m2", 8, "鏡中魔物", "Monster Mirror",
   "一樣的魔物、一樣的錢。", "Same monsters, same gold.",
   [[SL, 10, 3], [SL, 10, 5], [CAT, 11, 4], [SHP, 12, 2], [SHP, 12, 6], [GH, 13, 4], [SK, 14, 4]], [SL, CAT, SHP, GH, SK], 37)

# ── 第 9 章 時序：戰前設定技能在第幾秒放 ──
pz("s1", 9, "盾在雨前", "Shield Before Rain",
   "對方會丟隕石砸你最密的地方。在落下前開護盾。", "They will drop a meteor on your densest spot. Shield before it lands.",
   col(SW, 10, [2, 4, 6]) + col(AR, 13, [3, 5]), [SW, AR, SH], 22, cmd={"skill": AEGIS, "uses": 1, "enemy": [[200, METEOR]]})
pz("s2", 9, "最後一口氣", "Second Wind",
   "治療只有一次。等大家都受傷了再放。", "One heal. Wait until everyone is hurt.",
   col(AR, 14, [1, 3, 5, 7]) + col(SW, 10, [2, 6]) + [[BS, 11, 4]], [SW, SH], 20, cmd={"skill": HEAL, "uses": 1})
pz("s3", 9, "凍住衝鋒", "Freeze the Charge",
   "騎兵衝過來的那一刻，讓他們停住。", "Freeze the riders right as they charge in.",
   col(CV, 10, [1, 3, 5, 7]) + col(AR, 14, [3, 5]), [PK, AR, SW], 20, cmd={"skill": FREEZE, "uses": 1})
pz("s4", 9, "戰吼", "War Cry",
   "戰吼讓大家打得更快，但只有一下子。挑兩邊撞在一起的時候。", "War cry is short. Use it when the lines clash.",
   col(SW, 10, [2, 3, 4, 5, 6]) + col(AR, 13, [3, 5]) + [[MD, 14, 4]], [SW, BS, SH], 26, cmd={"skill": WAR, "uses": 1})
pz("s5", 9, "吸過來再砸", "Pull, Then Drop",
   "貓把敵人吸成一團之後，隕石一次砸好幾隻。", "Once the cat bunches them up, one meteor hits many.",
   [[SW, 10, 0], [SW, 10, 8], [AR, 13, 1], [AR, 13, 7], [SW, 11, 3], [SW, 11, 5], [AR, 14, 4]], [CAT, SH, SW], 18,
   cmd={"skill": METEOR, "uses": 1})
pz("s6", 9, "擋住戰吼", "Weather the Roar",
   "對方會在衝上來時放戰吼。用護盾擋住那一波。", "They roar as they hit you. Shield up for that wave.",
   col(BS, 10, [2, 4, 6]) + col(SW, 10, [3, 5]), [SH, AR, SW], 22, cmd={"skill": AEGIS, "uses": 1, "enemy": [[120, WAR]]})
pz("s7", 9, "兩次治療", "Two Heals",
   "可以治療兩次，冷卻很長。兩次都要用在刀口上。", "Two heals with a long cooldown. Make both count.",
   col(AR, 13, [0, 2, 4, 6, 8]) + col(SW, 10, [3, 5]), [SH, SW, AR], 22, cmd={"skill": HEAL, "uses": 2, "cd": 200})
pz("s8", 9, "冰封對冰封", "Freeze Duel",
   "對方會先凍住你。等它解凍後，換你凍他們。", "They freeze you first. Once it thaws, freeze them back.",
   col(SW, 10, [2, 4, 6]) + col(BS, 11, [3, 5]) + [[AR, 14, 4]], [SW, AR, SH], 24,
   cmd={"skill": FREEZE, "uses": 1, "enemy": [[100, FREEZE]]})
pz("s9", 9, "隕石對羊群", "Meteor vs Flock",
   "羊群衝過來前，一顆隕石可以先炸掉一大半。", "One meteor can wipe out the flock before it arrives.",
   col(SHP, 10, [0, 2, 4, 6, 8]) + col(SHP, 11, [2, 4, 6]) + col(AR, 14, [3, 5]), [AR, SH, SW], 18,
   cmd={"skill": METEOR, "uses": 1})
pz("s10", 9, "後發制人", "Counterpunch",
   "對方的護盾一過，就是你的戰吼。", "When their shield fades, it's your war cry.",
   col(SW, 10, [2, 3, 4, 5, 6]) + col(AR, 13, [2, 6]), [SW, AR, BS], 26, cmd={"skill": WAR, "uses": 1, "enemy": [[100, AEGIS]]})

# ── 第 10 章 宗師 ──
pz("z1", 10, "百家爭鳴", "Hundred Schools",
   "王國軍全部可用，對面也一樣。", "All kingdom units, on both sides.",
   col(SH, 10, [2, 4, 6]) + col(PK, 11, [3, 5]) + col(AR, 13, [1, 4, 7]) + [[BM, 14, 4], [MD, 14, 2], [DR, 12, 4], [CV, 11, 0], [AS, 12, 8]],
   [SW, SH, AR, CV, AS, PK, BM, MD, DR, BS], 50)
pz("z2", 10, "魔物大軍", "Monster Horde",
   "魔物對魔物。", "Monsters against monsters.",
   col(SL, 10, [2, 4, 6]) + col(GH, 11, [3, 5]) + [[SK, 14, 4], [CAT, 11, 4], [GO, 10, 8], [VD, 12, 0], [SP, 12, 4]],
   [SP, SHP, MM, SL, GH, VD, HG, SK, CAT, GO], 50)
pz("z3", 10, "最後的護送", "Last Escort",
   "保護醫者，對手什麼都有。", "Protect the medic against everything.",
   col(GH, 11, [1, 7]) + col(AS, 12, [3, 5]) + col(CV, 10, [0, 8]) + [[BM, 14, 4], [SW, 10, 4]],
   [SW, SH, AR, PK, MM, CAT, GO], 34, fixed=[[MD, 1, 4]], goal="protect", goal_unit=[1, 4])
pz("z4", 10, "最長的二十秒", "The Longest Twenty",
   "大軍壓境。撐住。", "A huge army. Hold.",
   col(BS, 10, [1, 3, 5, 7]) + col(SW, 10, [2, 4, 6]) + col(AR, 13, [1, 4, 7]) + [[DR, 12, 4], [BM, 14, 4]],
   [SH, PK, MD, SL, VD, HG, SK], 30, goal="survive", goal_ticks=400)
pz("z5", 10, "王之首級", "The King's Head",
   "最後面的骷髏法師就是頭目。", "The skeleton mage at the back is the boss.",
   [[SK, 15, 4], [MD, 14, 3], [MD, 14, 5]] + col(SH, 10, [1, 2, 3, 4, 5, 6, 7]) + col(PK, 11, [3, 5]),
   [GH, AS, CV, BS, AR, BM], 36, goal="kill", goal_unit=[15, 4])
pz("z6", 10, "雙橋決戰", "Battle of the Bridges",
   "兩座橋，兩支軍隊，什麼兵都能用。", "Two bridges, two armies, any unit.",
   col(SH, 10, [1, 2, 6]) + col(AR, 13, [1, 5, 7]) + col(CV, 11, [2, 6]) + [[MD, 14, 4], [BM, 15, 2]],
   [SW, SH, AR, CV, AS, PK, BM, SP, GH, CAT], 40, map=1)
pz("z7", 10, "以少勝多", "Few Against Many",
   "只能帶五隻，對手有十隻。", "Five units against ten.",
   col(SW, 10, [1, 3, 5, 7]) + col(AR, 13, [2, 4, 6]) + col(SH, 11, [3, 5]) + [[MD, 14, 4]],
   [GO, CV, BS, BM, DR, MD, SK, SL], 30, cap=3)
pz("z8", 10, "隕石時刻", "Meteor Hour",
   "一顆隕石，一支貓隊。", "One meteor and a cat squad.",
   [[SW, 10, 0], [SW, 10, 8], [BS, 11, 2], [BS, 11, 6], [AR, 13, 1], [AR, 13, 7], [AR, 14, 4], [MD, 15, 4], [SH, 10, 4]],
   [CAT, SH, AR, SW, SHP], 30, cmd={"skill": METEOR, "uses": 1})
pz("z9", 10, "峽谷宗師", "Canyon Master",
   "三條路、混搭敵軍。", "Three lanes, a mixed foe.",
   col(CV, 11, [0, 8]) + col(SH, 10, [3, 5]) + col(GH, 12, [4]) + col(AR, 14, [1, 4, 7]) + [[BM, 15, 4]],
   [PK, AR, CV, SH, MM, SP, GO, GH], 36, map=5)
pz("z10", 10, "落子無悔", "No Take-Backs",
   "最後一關。所有兵都能用，想清楚再放。", "The last one. Every unit is yours. Think before you place.",
   col(SH, 10, [2, 4, 6]) + col(BS, 10, [3, 5]) + col(PK, 11, [1, 7]) + col(AR, 13, [2, 6]) + [[BM, 14, 4], [MD, 14, 1], [DR, 12, 4], [SK, 15, 7], [CAT, 11, 4]],
   list(range(20)), 50)

if __name__ == "__main__":
    ids = [p["id"] for p in P]
    assert len(ids) == len(set(ids)) == 75, len(ids)
    json.dump(P, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(P), "drafts")
