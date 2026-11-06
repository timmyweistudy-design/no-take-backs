extends RefCounted
## V1.1 D2：每日挑戰＋每週突變。純函式，不碰畫面（遊戲、測試共用）。
## 不改模擬：只用現有規則參數（預算、隻數、每種上限、卡池、地圖、縱深、局長、雙方手動技能）＋AI 用固定種子組敵陣。
## 日期用 UTC 日數，跨時區同一天同一題。紀錄鍵＝日數＋VER：AI 或這份產生器一改就升 VER（測試 test_daily_v11 釘住幾天的敵陣，改了會紅）。

const VER := 1
const MUTATORS := 8
const KEEP_DAYS := 10          # 存檔只留最近幾天的最佳紀錄
const CMD = preload("res://scripts/core/cmd_defs.gd")
const Presets = preload("res://scripts/game/presets.gd")
const MapDefs = preload("res://scripts/core/map_defs.gd")
const AI = preload("res://scripts/core/ai_army.gd")

static func today() -> int:
	return int(Time.get_unix_time_from_system()) / 86400

## 這一天的題目規格。mut＝這週的突變（每 7 天換一個），map／style 每天換。
static func spec(day: int) -> Dictionary:
	var mut := posmod(day / 7, MUTATORS)
	var map_id := 3 if mut == 3 else posmod(day * 5 + 1, 6)
	return {"day": day, "key": "%d-v%d" % [day, VER], "mut": mut, "map": map_id, "style": posmod(day * 7 + 3, 5),
		"level": 1, "seed": 90000 + posmod(day * 2654435761, 1000003)}

static func pool_of(types: Array) -> int:
	var p := 0
	for t in types:
		p |= 1 << int(t)
	return p

## 把突變套到一組（已經是自由部署、單局的）規則上。r＝RuleSet。
static func apply(r, sp: Dictionary) -> void:
	r.map_id = int(sp["map"])
	r.map_size = 1
	r.ai_style = int(sp["style"])
	r.ai_level = int(sp["level"])
	r.ai_pool_same = false
	r.rounds = 1
	r.preset = "custom"
	var kingdom := (1 << 10) - 1
	var fantasy := ((1 << 20) - 1) & ~kingdom
	var pool := kingdom
	match int(sp["mut"]):
		0:   # 貼臉肉搏：近戰卡池、最深縱深、60 秒
			pool = pool_of([0, 1, 3, 4, 5, 7, 8, 9])
			r.depth = 7500
			r.ticks = 1200
		1:   # 精兵演武：只能 8 隻、每種 1 隻、高預算
			r.unit_cap = 8
			r.type_cap = 1
			r.budget = [140, 140]
		2:   # 人海戰術：40 隻、只有便宜的兵
			pool = pool_of([0, 1, 2, 5, 8])
			r.unit_cap = 40
		3:   # 禁魔死鬥：冰原、不開技能（map 已在 spec 固定）
			pass
		4:   # 百家爭鳴：每種 1 隻、預算 150
			r.type_cap = 1
			r.budget = [150, 150]
		5:   # 閃電決戰：60 秒、雙方技能全開（護盾、戰吼、隕石）
			r.ticks = 1200
			var m5 := (1 << CMD.AEGIS) | (1 << CMD.WARCRY) | (1 << CMD.METEOR)
			r.cmd_mask = [m5, m5]
		6:   # 孤軍深入：最深縱深、低預算、每種最多 2 隻
			r.depth = 7500
			r.budget = [70, 70]
			r.type_cap = 2
		7:   # 神仙打架：奇幻卡池、高預算、隻數少、技能全開
			pool = fantasy
			r.budget = [150, 150]
			r.unit_cap = 12
			var m7 := (1 << CMD.AEGIS) | (1 << CMD.HEAL) | (1 << CMD.METEOR)
			r.cmd_mask = [m7, m7]
	r.pool = [pool, pool]

## 成績比較：剩餘戰力高的好，一樣就花得少的好。rec＝[剩餘%, 花費]。
static func better(a: Array, b: Array) -> bool:
	if b.is_empty():
		return true
	return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1]))

## 記一場（贏了才記）。回傳 true＝新紀錄。best＝存檔的 daily_best（會被修改、只留最近 KEEP_DAYS 天）。
static func record(best: Dictionary, sp: Dictionary, rem: int, spent: int) -> bool:
	var k: String = sp["key"]
	var cur: Array = best.get(k, [])
	var nw := better([rem, spent], cur)
	if nw:
		best[k] = [rem, spent]
	var keys: Array = best.keys()
	keys.sort_custom(func(a, b): return int(str(a).get_slice("-", 0)) > int(str(b).get_slice("-", 0)))
	for i in range(KEEP_DAYS, keys.size()):
		best.erase(keys[i])
	return nw


## 這一天的完整規則（自由部署、16×9、單局；再套突變）。mask＝能用的兵種（正式版全開）。
static func make_rules(sp: Dictionary, mask: int):
	var r = Presets.make("standard", "ai", mask)
	r.deploy = "free"
	r.spacing = 800
	r.depth = 6000
	r.fullfield = 0
	var s: Array = MapDefs.SIZE_SUGGEST[1]
	r.budget = [int(s[0]), int(s[0])]
	r.unit_cap = int(s[1])
	r.ticks = int(s[2])
	apply(r, sp)
	return r

## 這一天的敵陣：普通 AI＋固定種子，跟遊戲流程無關（不吃玩家陣型、不吃全域亂數），跨機器一樣。
static func enemy(sp: Dictionary, r):
	var g := RandomNumberGenerator.new()
	g.seed = int(sp["seed"])
	var p1: int = r.pool_of(1)
	if r.ai_style != 0:
		p1 = AI.style_pool(p1, r.ai_style, g)
	return AI.build(1, r.budget_of(1), g, -1, p1, r)["army"]
