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

enum { SWORD, SHIELD, ARCHER, CAVALRY, ASSASSIN }

## 規則版本：改了戰鬥規則（不是只改數值）就要升版；重播與陣型代碼會帶這個版本。
const RULES_VERSION := "1.1.0"
const RULES_VERSION_INT := 10100

const COUNT := 5
const NAMES := ["劍士", "盾兵", "弓箭手", "騎兵", "刺客"]
const BLURB := [
	"破盾、被刺客打會反擊",
	"正面擋箭、頂住衝鋒、拒馬（打騎兵×2）、嘲諷近戰",
	"遠程拋射、優先射現形刺客（傷害×1.5）",
	"直衝 3 格後重擊、皮甲（箭傷減半）、繞過盾兵找弓手",
	"開場潛行、背刺×2、絆馬",
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
		var keys := m.keys()
		keys.sort()
		var txt := ""
		for k in keys:
			txt += "%s=%s;" % [k, var_to_str(m[k])]
		_digest = txt.sha256_text().substr(0, 16)
	return _digest

static func cost(t: int) -> int:
	return STATS[t]["cost"]

static func is_melee(t: int) -> bool:
	return t != ARCHER

static func cheapest() -> int:
	var c := 999
	for s in STATS:
		c = mini(c, s["cost"])
	return c
