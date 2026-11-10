extends RefCounted
## V1.6 #10 裂隙模式：每週用種子抽 3 個「彼此相容」的異變疊在一起打 AI。只用現有規則參數，不改模擬（娛樂徽章）。
## 每個異變有一個類別標籤，同類別只取一個（例如高預算和低預算不會同時出現）。
const Daily = preload("res://scripts/game/daily.gd")
const CMD = preload("res://scripts/core/cmd_defs.gd")
const AI = preload("res://scripts/core/ai_army.gd")

const VER := 1
## [字串鍵, 類別]
const ANOMS := [["rf_deep", "depth"], ["rf_short", "ticks"], ["rf_rich", "budget"], ["rf_poor", "budget"],
	["rf_elite", "cap"], ["rf_horde", "cap"], ["rf_solo", "type"], ["rf_skills", "cmd"], ["rf_fantasy", "pool"],
	["rf_terrain", "map"], ["rf_foe_rich", "foe"], ["rf_long", "ticks"]]
const PICK := 3

static func week() -> int:
	return int(Time.get_unix_time_from_system()) / 86400 / 7

## 這一週的異變（固定種子；同類別不重複；套上去規則不合法的跳過）
static func picks(wk: int, mask: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77000 + wk * 7919
	var order: Array = range(ANOMS.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var out: Array = []
	var tags := {}
	for k in order:
		if out.size() >= PICK:
			break
		var tg: String = ANOMS[k][1]
		if tags.has(tg):
			continue
		var trial: Array = out + [k]
		if not make_rules(trial, mask, wk).validate().is_empty():
			continue
		out.append(k)
		tags[tg] = true
	out.sort()
	return out

static func make_rules(ps: Array, mask: int, wk: int):
	var sp := {"day": wk * 7, "key": "", "mut": 3, "map": 0, "style": posmod(wk * 3 + 1, 5), "level": 1, "seed": 0}
	var r = Daily.make_rules(sp, mask)   # 基底：自由部署、16×9、單局、平原（突變 3＝不加料）
	r.cmd_mask = [0, 0]
	var kingdom := (1 << 10) - 1
	for k in ps:
		match str(ANOMS[k][0]):
			"rf_deep":
				r.depth = 7500
			"rf_short":
				r.ticks = 1200
			"rf_long":
				r.ticks = 2400
			"rf_rich":
				r.budget = [150, 150]
			"rf_poor":
				r.budget = [70, 70]
			"rf_elite":
				r.unit_cap = 10
			"rf_horde":
				r.unit_cap = 40
			"rf_solo":
				r.type_cap = 1
			"rf_skills":
				var m := (1 << CMD.AEGIS) | (1 << CMD.WARCRY) | (1 << CMD.METEOR)
				r.cmd_mask = [m, m]
			"rf_fantasy":
				var f := ((1 << 20) - 1) & ~kingdom
				r.pool = [f & mask, f & mask]
			"rf_terrain":
				r.map_id = 1 + posmod(wk, 5)
			"rf_foe_rich":
				r.budget = [int(r.budget[0]), int(r.budget[1]) + 20]
	return r

static func enemy(r, wk: int):
	var g := RandomNumberGenerator.new()
	g.seed = 88000 + wk * 104729
	return AI.build(1, r.budget_of(1), g, -1, r.pool_of(1), r)["army"]

static func key(wk: int) -> String:
	return "%d-v%d" % [wk, VER]
