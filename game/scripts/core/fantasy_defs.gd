extends RefCounted
## 第八輪奇幻兵團的數值與常數。獨立成一個檔案：unit_defs.gd 的常數決定舊場次的數值摘要，一個都不能動。
## 兵種編號 10～19 可以擺；20、21 是戰鬥中才生出來的。

const FIRST := 10
const TOTAL := 20               # 可以擺的兵種總數
const DRAW_TOTAL := 22          # 含生出來的小史萊姆、骷髏（圖集要畫）
const ROSTER_MAX := 10          # 一局每邊最多幾種兵（出戰名單）

const SPORE := 10
const SHEEP := 11
const MIMIC := 12
const SLIME := 13
const GHOST := 14
const DOLL := 15
const SPRITE := 16
const BONE := 17
const CAT := 18
const GOLEM := 19
const MINI_SLIME := 20
const SKELETON := 21

const NAMES := ["孢子菇", "爆爆羊", "寶箱怪", "史萊姆", "幽靈", "巫毒娃娃", "沙漏精靈", "骷髏法師", "吸塵貓", "小石魔", "小史萊姆", "骷髏"]
const STATS := [
	{"cost": 5, "hp": 360, "atk": 9, "cd": 20, "reach": 2200, "speed": 0},    # 孢子菇：atk＝毒傷、cd＝毒傷間隔、reach＝毒圈
	{"cost": 4, "hp": 110, "atk": 55, "cd": 20, "reach": 500, "speed": 110},  # 爆爆羊：atk＝爆炸傷害；碰到就炸
	{"cost": 5, "hp": 340, "atk": 15, "cd": 22, "reach": 700, "speed": 45},   # 寶箱怪
	{"cost": 5, "hp": 240, "atk": 9, "cd": 24, "reach": 700, "speed": 45},    # 史萊姆
	{"cost": 6, "hp": 200, "atk": 15, "cd": 20, "reach": 700, "speed": 85},   # 幽靈
	{"cost": 5, "hp": 280, "atk": 6, "cd": 24, "reach": 700, "speed": 40},    # 巫毒娃娃
	{"cost": 5, "hp": 180, "atk": 3, "cd": 24, "reach": 700, "speed": 50},    # 沙漏精靈（支援）
	{"cost": 6, "hp": 170, "atk": 8, "cd": 24, "reach": 4000, "speed": 45},   # 骷髏法師
	{"cost": 5, "hp": 260, "atk": 12, "cd": 22, "reach": 700, "speed": 50},   # 吸塵貓
	{"cost": 9, "hp": 820, "atk": 24, "cd": 36, "reach": 800, "speed": 30},   # 小石魔
	{"cost": 0, "hp": 85, "atk": 5, "cd": 24, "reach": 700, "speed": 45},     # 小史萊姆（戰力 0：時間到不灌水）
	{"cost": 0, "hp": 130, "atk": 8, "cd": 24, "reach": 700, "speed": 50},    # 骷髏（hp 依屍體重算）
]
## 一隊的硬上限：擋單兵種全買，也決定生兵配額。
const HARD_CAP := {SPORE: 6, SHEEP: 8, MIMIC: 6, SLIME: 8, GHOST: 8, DOLL: 4, SPRITE: 3, BONE: 3, CAT: 3, GOLEM: 3}
## 奇襲兵：不算戰鬥兵，要另外帶主力。
const RAID := [SPORE, SHEEP, MIMIC]

# 孢子菇
const SPORE_DMG := 9           # 圖鑑顯示用；實際值在 STATS
const SPORE_SLOW_PCT := 70      # 圈內移速 ×70%
# 爆爆羊
const BLAST_R := 1500           # 撞上爆炸半徑，只傷敵
const DEATH_BLAST_R := 1200     # 半路被打死的爆炸半徑，友敵都傷
const BLAST_CAP := 2            # 一隻單位一 tick 最多吃幾次羊爆
# 寶箱怪
const MIMIC_TRIGGER := 1500     # 敵兵進這個距離就現身
const BITE_DMG := 120
const BITE_HEAL := 60
# 史萊姆
const SLIME_KIDS := 2
const SLIME_OFFSET := 350
# 幽靈
const GHOST_MELEE_NUM := 5      # 受近戰 ×5/4
const GHOST_MELEE_DEN := 4
# 巫毒娃娃
const DOLL_LANE := 1500         # 同列走廊半寬
const DOLL_REBIND := 60         # 對方死後 3 秒重綁
# 沙漏精靈
const SPRITE_R := 2500
const SPRITE_LOW_PCT := 35
const SPRITE_NEED := 2          # 範圍內至少幾隻殘血才放
const SPRITE_STUN := 50         # 敵兵暈 2.5 秒
const SPRITE_GUARD := 50        # 友軍減傷 2.5 秒
const WINDUP := 20              # 大招前搖 1 秒
# 骷髏法師
const BONE_CD := 70             # 每 3.5 秒
const BONE_R := 5000           # 法師本來就站在 4 格外，3 格碰不到前排的屍體
const BONE_KIDS := 3
const BONE_HP_PCT := 50
const BONE_HP_CAP := 110
# 吸塵貓
const CAT_CD := 120             # 每 6 秒
const CAT_R := 3500
const CAT_FRONT := 1000         # 拉向身前 1 格
const CAT_PULL := 1200          # 每隻最多拉 1.2 格
const CAT_PULL_TICKS := 12      # 分 12 tick 拉完（畫面看得到被吸過去）；這段時間不能出手
# 小石魔
const GOLEM_CD := 100           # 每 5 秒
const GOLEM_R := 1200
const GOLEM_KNOCK := 800
const ROCK_R := 1500
const ROCK_TICKS := 400
const ROCK_SLOW_PCT := 60       # 碎石區移速 ×60%
const SKILLS := ["poison", "blast", "bite", "split", "ghost", "voodoo", "timestop", "raise", "vacuum", "stomp"]
const FIRST_CD := 40            # 大招開場等 2 秒
