extends RefCounted
## ════════════════════════════════════════════════════════════════════
##  《落子無悔》兵種數值表 —— 要調平衡只改這個檔案
## ════════════════════════════════════════════════════════════════════
## 單位換算（全部整數，才能保證兩台電腦算出一樣的結果）：
##   距離：1000 ＝ 1 格        例：reach 700 ＝ 0.7 格
##   時間：1 tick ＝ 1/20 秒   例：cd 20 ＝ 1 秒攻擊一次
##   速度：千分之一格／tick     例：speed 60 ＝ 每秒 1.2 格（60×20÷1000）
##   倍率：寫成「分子／分母」   例：NUM 5、DEN 2 ＝ ×2.5
## 改完跑：cd game && godot --headless --path . --script res://tools/balance.gd

enum { SWORD, SHIELD, ARCHER, CAVALRY, ASSASSIN, PIKE, BOMBER, MEDIC, DRUMMER, BERSERKER }

## 規則版本：改了戰鬥規則（不是只改數值）就要升版；重播與陣型代碼會帶這個版本。
const RULES_VERSION := "1.3.0"     # 1.3.0：第四輪新增五種兵（長槍兵、投彈兵、醫者、鼓手、狂戰士）；1.2.0：繞翼狀態機、途經點離邊、騎兵追擊遲滯
const RULES_VERSION_INT := 10300

const COUNT := 10
const CLASSIC := 5      # 經典 5 種（編號 0～4）；第四輪新兵是 5～9
const NAMES := ["劍士", "盾兵", "弓箭手", "騎兵", "刺客", "長槍兵", "投彈兵", "醫者", "鼓手", "狂戰士"]
const BLURB := [
	"破盾、被刺客打會反擊",
	"正面擋箭、頂住衝鋒、拒馬（打騎兵×2）、嘲諷近戰",
	"遠程拋射、優先射現形刺客（傷害×1.5）",
	"直衝 3 格後重擊、皮甲（箭傷減半）、繞過盾兵找弓手",
	"開場潛行、背刺×2、絆馬",
	"長柄 1.3 格、隔著前排出手、拒騎",
	"拋火罐範圍傷害、無視舉盾、被貼身只能敲人",
	"補附近血最少的友軍、友軍在時不出手",
	"附近友軍攻速提升、友軍在時不出手",
	"打中盾兵／長槍兵讓它破陣（嘲諷、舉盾、拒騎失效）",
]

# ─── 基本數值 ───
#   cost  ＝ 價錢（金）
#   hp    ＝ 血量
#   atk   ＝ 每次攻擊傷害
#   cd    ＝ 攻擊間隔（tick；20＝1 秒）
#   reach ＝ 攻擊距離（中心到中心；1000＝1 格）
#   speed ＝ 移動速度（千分之一格／tick；50＝每秒 1 格）
const STATS := [
	{"cost": 5, "hp": 250, "atk": 10, "cd": 20, "reach": 700, "speed": 60},   # 劍士
	{"cost": 5, "hp": 450, "atk": 6, "cd": 24, "reach": 700, "speed": 45},    # 盾兵
	{"cost": 4, "hp": 150, "atk": 12, "cd": 24, "reach": 6000, "speed": 50},  # 弓箭手
	{"cost": 7, "hp": 350, "atk": 14, "cd": 22, "reach": 750, "speed": 120},  # 騎兵
	{"cost": 6, "hp": 175, "atk": 20, "cd": 16, "reach": 700, "speed": 90},   # 刺客
	{"cost": 5, "hp": 260, "atk": 10, "cd": 22, "reach": 1300, "speed": 50},  # 長槍兵
	{"cost": 6, "hp": 150, "atk": 16, "cd": 40, "reach": 5500, "speed": 45},  # 投彈兵（丟彈；被貼身改敲人見下方）
	{"cost": 6, "hp": 180, "atk": 3, "cd": 24, "reach": 700, "speed": 50},    # 醫者（攻擊只在全隊剩支援兵時用）
	{"cost": 5, "hp": 200, "atk": 3, "cd": 24, "reach": 700, "speed": 50},    # 鼓手（同上）
	{"cost": 6, "hp": 300, "atk": 11, "cd": 20, "reach": 700, "speed": 60},   # 狂戰士
]

# ─── 劍士 ───
const BREAKER_NUM := 3          # 破盾：打盾兵的傷害 ×3/2
const BREAKER_DEN := 2
const COUNTER_PCT := 100        # 反擊：被刺客打到立刻回砍，傷害＝劍士攻擊的 100%

# ─── 盾兵 ───
const BLOCK_NUM := 1            # 舉盾：正面被弓箭射中，傷害 ×1/4
const BLOCK_DEN := 4
const STUN_TICKS := 20          # 頂住：正面被衝鋒的騎兵暈 20 tick（1 秒）
const TAUNT_RANGE := 2000       # 嘲諷：2 格內的近戰敵人優先打盾兵
const ANTICAV_NUM := 2          # 拒馬：盾兵打騎兵 ×2/1
const ANTICAV_DEN := 1

# ─── 弓箭手 ───
const ALERT_NUM := 3            # 警覺：射刺客 ×3/2
const ALERT_DEN := 2

# ─── 騎兵 ───
const CHARGE_NEED := 3000       # 衝鋒：連續直行 3 格後的第一擊
const CHARGE_NUM := 5           # 衝鋒傷害 ×5/2
const CHARGE_DEN := 2
const KNOCKBACK := 500          # 衝鋒擊退 0.5 格
const FLANK_DETECT := 1500      # 繞翼：衝向弓手的直線 1.5 格內有盾兵就繞
const FLANK_OFFSET := 2000      # 繞翼往上／下偏 2 格
const FLANK_EDGE_MARGIN := 250  # 途經點至少離上下邊界 EDGE＋0.25 格，避免貼牆和推擠互卡
const WP_REACHED := 400         # 離途經點 0.4 格內＝完成這次繞翼（永久，不會再回頭）
const CHASE_HYST := 150         # 騎兵追擊遲滯：超出攻擊距離才起步，追到 reach−0.15 格才停
const HIDE_ARROW_NUM := 1       # 皮甲：騎兵被弓箭射中 ×1/2
const HIDE_ARROW_DEN := 2

# ─── 刺客 ───
const STEALTH_TICKS := 40       # 潛行：開場 40 tick（2 秒）不能被指定、不碰撞
const BEHIND_DIST := 600        # 潛行時繞到目標背後 0.6 格的位置
const BACKSTAB_NUM := 2         # 背刺：從背後攻擊 ×2（無視舉盾）
const BACKSTAB_DEN := 1
const SLOW_TICKS := 20          # 絆馬：打到騎兵讓它減速 20 tick
const SLOW_NUM := 1             # 減速後速度 ×1/2
const SLOW_DEN := 2

# ─── 長槍兵（第四輪）───
const PIKE_ANTICAV_NUM := 2     # 長槍兵打騎兵 ×2
const PIKE_ANTICAV_DEN := 1
# 拒騎：騎兵從正面衝鋒打到長槍兵時，衝鋒倍率和擊退都不生效（衝鋒照樣消耗）

# ─── 投彈兵（第四輪）───
const BOMB_MIN := 1500          # 最短射程 1.5 格：最近的可見敵人比這近，這一 tick 就改敲人
const SPLASH_R := 900           # 爆炸半徑：主目標 0.9 格內的其他敵人吃波及
const SPLASH_DMG := 8           # 波及傷害
const SPLASH_MAX := 3           # 最多波及幾隻
const BOMB_SHIELD_NUM := 5      # 火罐專拆盾牆：主擊與波及打盾兵 ×5/2（第四輪平衡：沒有這條時投彈兵打不贏盾兵為主的陣）
const BOMB_SHIELD_DEN := 2
const BONK_ATK := 8             # 敲人：攻擊、距離、間隔
const BONK_REACH := 700
const BONK_CD := 24

# ─── 醫者（第四輪）───
const HEAL_AMT := 19            # 每次補血量（狂熱時減半）
const HEAL_CD := 30             # 補血間隔（tick），不吃任何加速
const HEAL_FIRST := 20          # 開戰後第一次補血前的等待
const HEAL_RANGE := 3000        # 補血距離
# 支援走位（醫者、鼓手）：跟隨點往自己底線退 1 格、離目的地 0.3 格內就停
const SUPPORT_BACK := 1000
const SUPPORT_STOP := 300

# ─── 鼓手（第四輪）───
const DRUM_RANGE := 2100        # 光環 2.1 格（含自己）
const DRUM_BONUS := 2           # 冷卻每 tick 多扣 2（不疊加；平常扣 4）
const DEC_CAP := 7              # 冷卻每 tick 扣除上限（平常 4／狂熱 5＋背水＋戰鼓）

# ─── 狂戰士（第四輪）───
const BREACH_TICKS := 60        # 破陣：打中盾兵／長槍兵後 3 秒內嘲諷、正面舉盾、拒騎失效（重複打中刷新）
const BREACH_SPREAD := 1000     # 破陣擴散：目標 1 格內的其他敵方盾兵／長槍兵一起破陣（劈開一段牆）
const BREACH_VULN_NUM := 3      # 破陣中受到的所有傷害 ×3/2（第四輪平衡：讓「替隊友開路」真的有用）
const BREACH_VULN_DEN := 2
const BERSERK_ARROW_NUM := 5    # 沒穿甲：被弓箭射中 ×5/4
const BERSERK_ARROW_DEN := 4
# 不被擊退：騎兵衝鋒的擊退對狂戰士無效

# ─── 全場規則 ───
const MATCH_TICKS := 1800       # 一局最長 90 秒
const FRENZY_TICK := 1200       # 60 秒起狂熱
const FRENZY_CD_RATE := 5       # 狂熱時冷卻每 tick 扣 5（平常 4）＝攻速 ×5/4
const ATTRITION_STEP_PCT := 2   # 狂熱耗損：第 k 次（k＝0～5，每 5 秒一次）扣 (k+1)×2% 滿血
const MIN_SEP := 450            # 兵與兵最小間距 0.45 格
const RALLY_RATIO_PCT := 60     # 背水（追趕機制）：自己的剩餘戰力 < 對方的這個百分比時觸發；0＝關閉。11/01 實驗 5 組後採用 60%／+2
const RALLY_CD_BONUS := 2       # 背水時冷卻每 tick 多扣幾：平常 4→6（攻速約 ×1.5）、狂熱 5→7（約 ×1.4）；實際間隔取整到 tick

static var _digest := ""

## 數值摘要：本檔所有常數的 SHA-256 前 16 碼。遊戲、AI、平衡工具、重播都記錄它，證明跑的是同一份數值。
static func data_digest() -> String:
	if _digest == "":
		var m: Dictionary = load("res://scripts/core/unit_defs.gd").get_script_constant_map()
		# 常數名稱是 StringName，直接排序是比記憶體位址、不是字母順序 → 先轉成 String 再排
		var pairs: Array = []
		for k in m:
			pairs.append([String(k), m[k]])
		pairs.sort_custom(func(a, b): return a[0] < b[0])
		var txt := ""
		for pr in pairs:
			txt += "%s=%s;" % [pr[0], var_to_str(pr[1])]
		_digest = txt.sha256_text().substr(0, 16)
	return _digest

## 每種兵一格的 0 陣列（取代到處寫死的 [0, 0, 0, 0, 0]）。
static func zeros() -> Array:
	var a: Array = []
	a.resize(COUNT)
	a.fill(0)
	return a

static func cost(t: int) -> int:
	return STATS[t]["cost"]

static func is_melee(t: int) -> bool:
	return t != ARCHER and t != BOMBER

## 支援兵（第四輪）：隊上還有戰鬥兵活著時不攻擊，只做支援走位。
static func is_support(t: int) -> bool:
	return t == MEDIC or t == DRUMMER

static func cheapest() -> int:
	var c := 999
	for s in STATS:
		c = mini(c, s["cost"])
	return c
