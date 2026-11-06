#!/usr/bin/env python3
"""第十三輪主題試煉第 11～30 關的規格（敵陣卡池、規則變形、名稱）。
game/tools/balance/trial_forge.gd 依這份用固定種子生成敵陣並凍結、找三星解、訂門檻，結果再寫成 game/data/trials.json。
用法：python3 tools/gen/trial_specs.py <輸出.json>
"""
import json
import sys

SW, SH, AR, CV, AS, PK, BM, MD, DR, BS = range(10)
SP, SHP, MM, SL, GH, VD, HG, SK, CAT, GO = range(10, 20)
FANT = list(range(10, 20))
ALL = list(range(20))
AEGIS, WAR, HEAL, METEOR, FREEZE = range(5)

T = []


def tr(i, zh, en, tag_zh, tag_en, enemy_pool, **kw):
    d = {"i": i, "zh": zh, "en": en, "tag_zh": tag_zh, "tag_en": tag_en, "enemy_pool": enemy_pool}
    d.update(kw)
    T.append(d)


# 限定卡池
tr(10, "魔物限定", "Monsters Only", "只能帶魔物", "Monsters only", ALL, pool0=FANT)
tr(11, "沒有肉盾", "No Tanks", "不准帶肉盾", "No tanks", ALL, pool0=[SW, AR, CV, AS, MD, DR, BS, SHP, GH, CAT])   # 一邊最多 10 種（Codex v13-r2 #1）
tr(12, "奇兵突襲", "Ambush Party", "奇襲兵加劍士", "Raiders + swords", ALL, pool0=[SP, SHP, MM, SW])
tr(13, "近身肉搏", "Close Quarters", "不准帶遠程", "No ranged", ALL, pool0=[SW, SH, CV, AS, PK, BS, MM, SL, GH, GO])
# 單主題頭目
tr(14, "羊群奔騰", "Stampede", "頭目：爆爆羊", "Boss: boom sheep", [SHP, SH, AR], boss=SHP, boss_min=8)   # 頭目兵種至少幾隻（Antigravity v13-r3 #8）
tr(15, "死靈圖書館", "Necro Library", "頭目：骷髏法師", "Boss: skeleton mage", [SK, SW, SL, MD])
tr(16, "石魔雙壁", "Twin Golems", "頭目：小石魔", "Boss: golems", [GO, SH, AR, MD])
tr(17, "刺客夜襲", "Night Raid", "頭目：刺客", "Boss: assassins", [AS, GH, BM], boss=AS, boss_min=6)
tr(18, "貓窩", "Cat Den", "頭目：吸塵貓", "Boss: cats", [CAT, BM, SHP, SH])
# 混搭頭目
tr(19, "鐵桶陣", "Iron Barrel", "巫毒娃娃＋小石魔", "Voodoo + golems", [VD, GO, SH, MD])
tr(20, "切後排", "Backline Hunt", "幽靈＋刺客", "Ghosts + assassins", [GH, AS, SW])
tr(21, "控場煉獄", "Control Hell", "沙漏精靈＋孢子菇", "Sprite + spores", [HG, SP, AR, SH])
tr(22, "破盾潮", "Shieldbreaker Tide", "狂戰士＋騎兵＋鼓手", "Berserkers + riders + drums", [BS, CV, DR, SW])
tr(23, "不倒軍", "The Undying", "骷髏法師＋史萊姆", "Skeleton mage + slimes", [SK, SL, MD, SH], boss=SL, boss_min=6)
tr(24, "史萊姆海", "Slime Sea", "史萊姆＋投彈兵", "Slimes + bombers", [SL, BM, SH], boss=SL, boss_min=8)
tr(25, "吸塵連鎖", "Vacuum Chain", "吸塵貓＋爆爆羊", "Cats + boom sheep", [CAT, SHP, AR])
# 規則變形
tr(26, "窮兵", "Lean Purse", "雙方 60 金", "60 gold each", ALL, budget=60)
tr(27, "前壓陣線", "Forward Line", "雙方部署縱深 7.5 格", "Both sides deploy 7.5 cells deep", ALL, depth=7500)   # 規則縱深只能 6～7.5 格（v13-r2 測試）
tr(28, "技能對決", "Skill Duel", "雙方都有護盾和隕石", "Both sides: shield + meteor", ALL, cmd=(1 << AEGIS) | (1 << METEOR))
tr(29, "一種兩隻", "Two of a Kind", "每種兵最多 2 隻", "Max 2 per unit type", [SW, SH, AR, CV, AS, SP, MM, GH, VD, CAT], type_cap=2)

if __name__ == "__main__":
    assert len(T) == 20
    json.dump(T, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(T), "specs")
