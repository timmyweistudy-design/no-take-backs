extends RefCounted
## 手動技能（第十二輪）：玩家戰鬥中按下的全隊技能。純資料、全整數。
## 名字和說明在 data/strings.csv（cmd_0～4、cmd_d_0～4），要改名只改那裡，再跑 tools/gen/build_font.py。
## 新增技能：這裡加常數、battle_sim._cmd_apply 加效果、_cmd_ai_wants 加 AI 時機、strings.csv 加兩行。

const AEGIS := 0    # 全員護盾
const WARCRY := 1   # 戰吼
const HEAL := 2     # 治癒之雨
const METEOR := 3   # 隕石
const FREEZE := 4   # 冰封
const COUNT := 5
const ICONS := ["shield", "swords", "heart", "star", "slow"]

const MAX_SLOTS := 3            # 一邊最多帶幾種
const USES := [1, 2, 3]         # 每種可用次數
const CD_TICKS := [200, 400, 600]   # 同一種的冷卻（tick）
const POWERS := [50, 100, 150]  # 效果強度 %
const DEFAULT_MASK := (1 << AEGIS) | (1 << METEOR)
const DEFAULT_USES := 1
const DEFAULT_CD := 400
const DEFAULT_POWER := 100
const START_TICKS := 60         # 開場 3 秒後才能用，先看清楚局勢

const AEGIS_PCT := 30           # 護盾＝最大血量的 %
const AEGIS_TICKS := 100
const WAR_TICKS := 100
const WAR_BONUS := 2            # 攻擊冷卻每 tick 多扣（平常扣 4）
const HEAL_PCT := 25
const METEOR_DMG := 90
const METEOR_R := 1800
const FREEZE_TICKS := 30

## 這個強度下的傷害、血量比例（整數）。
static func scaled(v: int, power: int) -> int:
	return v * power / 100

## 說明文字要填的數字（只給畫面用，模擬不會呼叫）。
static func desc_args(i: int, power: int) -> Array:
	match i:
		AEGIS:
			return [scaled(AEGIS_PCT, power), AEGIS_TICKS / 20]
		WARCRY:
			return [WAR_BONUS * 100 / 4, scaled(WAR_TICKS, power) / 20]
		HEAL:
			return [scaled(HEAL_PCT, power)]
		METEOR:
			return [scaled(METEOR_DMG, power)]
		FREEZE:
			return ["%.1f" % (scaled(FREEZE_TICKS, power) / 20.0)]
	return []

static func count_of(mask: int) -> int:
	var n := 0
	for i in COUNT:
		if (mask >> i) & 1 == 1:
			n += 1
	return n

static func list_of(mask: int) -> Array:
	var out: Array = []
	for i in COUNT:
		if (mask >> i) & 1 == 1:
			out.append(i)
	return out
