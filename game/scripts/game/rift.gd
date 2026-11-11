extends RefCounted
## V1.6 #10 裂隙模式：每週用種子抽 3 個「彼此相容」的異變疊在一起打 AI。只用現有規則參數，不改模擬（娛樂徽章）。
## 每個異變有一個類別標籤，同類別只取一個（例如高預算和低預算不會同時出現）。
const Daily = preload("res://scripts/game/daily.gd")
const CMD = preload("res://scripts/core/cmd_defs.gd")
const AI = preload("res://scripts/core/ai_army.gd")

const VER := 2   # V1.6.1 N5：加了「不同時出現」的組合，同一週抽到的可能不同 → 升版（紀錄鍵分開）
## V1.6.1 N5：AI 代理量測（tools/balance/v161_metrics.gd --what=rift，26 週×24 場）時間到比例 40～70% 的組合，不同時出現。
## 「每種一隻」配上「大軍」「窮」「地形」，或「奇幻」配「地形」「大軍」：雙方磨到時間到。
const BAD := [["rf_solo", "rf_horde"], ["rf_solo", "rf_poor"], ["rf_solo", "rf_terrain"], ["rf_fantasy", "rf_terrain"], ["rf_fantasy", "rf_horde"]]

static func clash(ps: Array, k: int) -> bool:
	var a: String = ANOMS[k][0]
	for j in ps:
		var b: String = ANOMS[j][0]
		for bp in BAD:
			if (bp[0] == a and bp[1] == b) or (bp[0] == b and bp[1] == a):
				return true
	return false
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
		if tags.has(tg) or clash(out, k):
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

## V1.6.1 A12：紀錄留最近 n 週（鍵＝「週-v版本」，依週數排序留最大的 n 個）
static func keep_recent(best: Dictionary, n: int) -> Dictionary:
	var wks := weeks_of(best)
	var keep: Array = wks.slice(0, n)
	var out := {}
	for k in best:
		if int(str(k).get_slice("-", 0)) in keep:
			out[k] = best[k]   # 同一週不同版本（v1／v2）一起留（Codex v161-i2 #4：依週數保留）
	return out

## 紀錄裡有哪些週（不同版本算同一週），新的在前
static func weeks_of(best: Dictionary) -> Array:
	var w := {}
	for k in best:
		w[int(str(k).get_slice("-", 0))] = true
	var out: Array = w.keys()
	out.sort()
	out.reverse()
	return out
